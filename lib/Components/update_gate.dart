import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart' show InstallStatus;
import 'package:url_launcher/url_launcher.dart';

import '../api/app_info.dart';
import '../api/play_updates.dart';
import '../api/remote_config.dart';
import '../api/share_links.dart';
import '../api/update_policy.dart';
import '../navigation.dart';
import '../l10n/l10n.dart';

/// Keeps installed copies current: suggests a newer build, and stops an old
/// one once it is no longer supported — having said so first.
///
/// Two numbers from RemoteConfig drive it. `latest_build` moves every release
/// and produces a *nudge*: on a Play install, Google's own in-app update sheet;
/// anywhere else, our dialog with a link to the store page. "Later" is
/// remembered per build for three days. `min_supported_build` moves rarely
/// and produces the *gate*: a warning with a countdown, then a screen that
/// replaces the app once the deadline passes.
///
/// Wrapped around the whole app through MaterialApp.builder rather than placed
/// on a screen, so it covers every route including one opened from a shared
/// link or a notification. It re-checks on resume, so a phone left open past
/// the deadline does not stay usable indefinitely.
///
/// The rules it will not break:
///
///  * **It fails open.** Everything comes from RemoteConfig, which returns its
///    cache and never throws. An unreachable API therefore means "no gate",
///    never "everybody out" — a gate that depends on our own uptime turns a
///    brief API problem into every phone bricking at once, with no way back
///    except fixing the API.
///  * **It defaults to nothing.** mode 'off' and a floor of 0 ship inert.
///  * **It is never a dead end.** The blocking screen offers the update and
///    a retry. A screen that only says "update required" with no working
///    button is indistinguishable from the app being broken.
///  * **Play is asked first, never trusted alone.** Every call into Play's
///    update API is guarded; when it cannot answer, the dialog does.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  /// This build's number, from the package rather than a constant, so it
  /// cannot drift from what was actually shipped.
  int? _build;

  /// Where this copy came from, which decides where the update button points
  /// and what it is allowed to say.
  UpdateChannel _channel = UpdateChannel.sideload;

  /// Drives the countdown text. One minute is enough for a deadline measured
  /// in days or hours, and cheap.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readBuild();
    RemoteConfig.instance.revision.addListener(_onConfigChanged);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    RemoteConfig.instance.revision.removeListener(_onConfigChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // A phone left open for a week would otherwise never learn that the
    // deadline has passed, or that an admin has lifted it.
    unawaited(RemoteConfig.instance.load().then((_) async {
      if (mounted) setState(() {});
      // A flexible download that finished while we were in the background is
      // sitting there waiting; Play's own guidance is to offer the restart on
      // resume rather than wait for the next launch.
      if (await PlayUpdates.hasDownloadedUpdate()) {
        offerRestart();
        return;
      }
      // No splash is about to clear the stack here, so this is safe to offer
      // directly.
      unawaited(maybeWarnAboutUpdate());
    }));
  }

  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _readBuild() async {
    final parsed = await currentBuildNumber();
    final channel = await currentUpdateChannel();
    if (mounted) {
      setState(() {
        _build = parsed;
        _channel = channel;
      });
    }
  }

  /// How this build stands. The widget only acts on [UpdateDecision.blocked];
  /// warnings and nudges are dialogs offered from [maybeWarnAboutUpdate].
  UpdateDecision get _decision {
    final cfg = RemoteConfig.instance;
    return decideUpdate(
      build: _build,
      mode: cfg.updateMode,
      latestBuild: cfg.latestBuild,
      minSupportedBuild: cfg.minSupportedBuild,
      blocksAt: cfg.blocksAt,
      serverNow: cfg.serverNow,
      snoozedBuild: null,
      snoozedAt: null,
      now: DateTime.now().toUtc(),
    );
  }

  /// The blocked screen's button. A Play install gets Play's immediate flow —
  /// the update installs without leaving the app — and falls back to the store
  /// page when Play cannot run it.
  Future<void> _download() async {
    if (_channel == UpdateChannel.play && await PlayUpdates.performImmediate()) {
      return;
    }
    await openUpdateDestination();
  }

  @override
  Widget build(BuildContext context) {
    // Web is always current after a deploy; there is nothing to install.
    if (!kIsWeb && _decision == UpdateDecision.blocked) {
      // Replaces the app rather than covering it: there is nothing behind this
      // worth reaching, and a dismissible "blocking" screen is not one.
      return _BlockedScreen(
        onDownload: _download,
        onRetry: _retry,
        channel: _channel,
      );
    }

    // The warning is a dialog rather than something laid over the app.
    //
    // A Stack here does not work: the child arriving through
    // MaterialApp.builder is the Navigator, and a second Stack child alongside
    // it builds — the banner's build method runs — but never paints. The
    // blocking screen above has no such trouble because it *replaces* the
    // child instead of sitting beside it. Rather than fight that, the warning
    // goes through the Navigator's own overlay, which is the same route every
    // other dialog in the app already takes.
    return widget.child;
  }

  Future<void> _retry() async {
    await RemoteConfig.instance.load();
    if (mounted) setState(() {});
  }
}

/// Turns a duration into the coarsest unit that is still true.
///
/// "2 days" is more use than "1 day 22 hours", and under an hour the minutes
/// are what matter. Returns null when there is no deadline to describe.
String? formatRemaining(BuildContext context, Duration? left) {
  if (left == null) return null;
  final l10n = context.l10n;
  if (left.inDays >= 1) return l10n.updateInDays(left.inDays);
  if (left.inHours >= 1) return l10n.updateInHours(left.inHours);
  if (left.inMinutes >= 1) return l10n.updateInMinutes(left.inMinutes);
  return l10n.updateVerySoon;
}

/// The floor warning: this build is on notice, with a countdown when there is
/// a deadline.
class _CountdownDialog extends StatelessWidget {
  const _CountdownDialog({
    required this.remaining,
    required this.onDownload,
    required this.channel,
  });

  final Duration? remaining;
  final VoidCallback onDownload;
  final UpdateChannel channel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final left = formatRemaining(context, remaining);

    return AlertDialog(
      icon: const Icon(Icons.system_update),
      title: Text(
        left == null ? l10n.updateAvailableTitle : l10n.updateStopsIn(left),
        textAlign: TextAlign.center,
      ),
      content: Text(l10n.updateBannerBody, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.updateDismiss),
        ),
        FilledButton(
          onPressed: onDownload,
          child: Text(l10n.updateOpenStore),
        ),
      ],
    );
  }
}

/// The nudge: something newer exists, and this build is still fine.
///
/// Only ever shown when Play could not show its own sheet — a sideload, an
/// emulator, or a store that has not caught up with the config yet.
class _NudgeDialog extends StatelessWidget {
  const _NudgeDialog({
    required this.version,
    required this.channel,
    required this.onLater,
    required this.onUpdate,
  });

  final String version;
  final UpdateChannel channel;
  final VoidCallback onLater;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.system_update),
      title: Text(l10n.updateAvailableTitle, textAlign: TextAlign.center),
      content: Text(l10n.updateNudgeBody(version), textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: onLater, child: Text(l10n.updateLater)),
        FilledButton(
          onPressed: onUpdate,
          child: Text(l10n.updateOpenStore),
        ),
      ],
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen({
    required this.onDownload,
    required this.onRetry,
    required this.channel,
  });

  final Future<void> Function() onDownload;
  final Future<void> Function() onRetry;
  final UpdateChannel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // Its own Directionality/Localizations come from the MaterialApp above,
    // since this is inserted through builder rather than pushed as a route.
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  l10n.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onDownload,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.updateOpenStore),
                  ),
                ),
                const SizedBox(height: 10),
                // The way back if the block is wrong, or has just been lifted.
                // Without it the only remedy is reinstalling.
                TextButton(
                  onPressed: onRetry,
                  child: Text(l10n.updateRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Offer whatever the config says this build should hear, once per session.
///
/// Deliberately not fired from UpdateGate.build. The dialogs are routes on the
/// app's Navigator, and at launch the splash finishes with
/// pushNamedAndRemoveUntil(..., (_) => false) — which removes every route,
/// including a dialog pushed a moment earlier. So it is offered *after* the
/// splash has decided the app's root, exactly like a shared link or a tapped
/// notification, and on resume where nothing is about to clear the stack.
///
/// Once per session: a launch should mention it, and by the next launch the
/// deadline is closer than it was. The nudge additionally remembers "Later"
/// across launches — see [RemoteConfig.snoozeBuild].
Future<void> maybeWarnAboutUpdate() async {
  // The web build is whatever was last deployed; there is nothing to update.
  if (kIsWeb) return;
  if (_warnedThisSession) return;
  // Claimed before the first await: the splash and the gate's resume hook can
  // both arrive here within the same second at launch, and a flag set only
  // after an await lets both through.
  _warnedThisSession = true;

  final cfg = RemoteConfig.instance;
  final build = await currentBuildNumber();
  final snooze = await cfg.readSnooze();
  final decision = decideUpdate(
    build: build,
    mode: cfg.updateMode,
    latestBuild: cfg.latestBuild,
    minSupportedBuild: cfg.minSupportedBuild,
    blocksAt: cfg.blocksAt,
    serverNow: cfg.serverNow,
    snoozedBuild: snooze.build,
    snoozedAt: snooze.at,
    now: DateTime.now().toUtc(),
  );

  switch (decision) {
    case UpdateDecision.none:
      // Nothing to say now; a later resume may find a newer config.
      _warnedThisSession = false;
      return;
    case UpdateDecision.blocked:
      // The gate itself is showing; a dialog over it would say the same thing
      // less firmly.
      return;
    case UpdateDecision.warn:
      await _showCountdown(cfg);
    case UpdateDecision.nudge:
      await _showNudge(cfg);
  }
}

Future<void> _showCountdown(RemoteConfig cfg) async {
  // Resolved before the navigator is looked up, so nothing is awaited between
  // finding it and using its context. Both reads are cached after first call,
  // so this costs nothing on the resume path.
  final channel = await currentUpdateChannel();

  final navigator = rootNavigatorKey.currentState;
  if (navigator == null || !navigator.mounted) return;

  final deadline = cfg.blocksAt;
  final left = deadline?.difference(cfg.serverNow);
  await showDialog<void>(
    context: navigator.context,
    builder: (ctx) => _CountdownDialog(
      remaining: left != null && !left.isNegative ? left : null,
      channel: channel,
      onDownload: () {
        Navigator.pop(ctx);
        unawaited(openUpdateDestination());
      },
    ),
  );
}

Future<void> _showNudge(RemoteConfig cfg) async {
  final channel = await currentUpdateChannel();

  if (channel == UpdateChannel.play) {
    // Play's own sheet first. It downloads in the background and we offer the
    // restart when it is done, which is the experience every other Play app
    // gives — and Play, not us, decides whether this device may have it.
    final outcome = await PlayUpdates.startFlexible();
    switch (outcome) {
      case PlayUpdateOutcome.started:
        _listenForDownloaded();
        return;
      case PlayUpdateOutcome.declined:
        // "No" in Play's sheet is "Later" in ours.
        await cfg.snoozeBuild(cfg.latestBuild);
        return;
      case PlayUpdateOutcome.notAvailable:
      case PlayUpdateOutcome.unavailable:
        // The config is ahead of the store, or Play cannot be asked here.
        // Fall through to the dialog, which sends them to the listing.
        break;
    }
  }

  final navigator = rootNavigatorKey.currentState;
  if (navigator == null || !navigator.mounted) return;

  final result = await showDialog<bool>(
    context: navigator.context,
    builder: (ctx) => _NudgeDialog(
      version: cfg.latestVersion,
      channel: channel,
      onLater: () => Navigator.pop(ctx, false),
      onUpdate: () => Navigator.pop(ctx, true),
    ),
  );
  if (result == true) {
    unawaited(openUpdateDestination());
  } else {
    // Later, or dismissed by tapping outside: both mean "not now", and
    // neither should mean "ask again on the next launch".
    await cfg.snoozeBuild(cfg.latestBuild);
  }
}

StreamSubscription<InstallStatus>? _installSub;

/// Watch a flexible download and offer the restart when it lands.
void _listenForDownloaded() {
  _installSub?.cancel();
  _installSub = PlayUpdates.installStatus.listen((status) {
    if (status == InstallStatus.downloaded) {
      _installSub?.cancel();
      _installSub = null;
      offerRestart();
    }
  });
}

/// "Update downloaded — Restart", as a long-lived snackbar on whatever screen
/// is up. Restarting installs the flexible update.
void offerRestart() {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null || !navigator.mounted) return;
  final context = navigator.context;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l10n = context.l10n;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.updateDownloadedTitle),
      duration: const Duration(days: 1),
      action: SnackBarAction(
        label: l10n.updateRestart,
        onPressed: () => unawaited(PlayUpdates.complete()),
      ),
    ),
  );
}

bool _warnedThisSession = false;

Future<int?> currentBuildNumber() => AppInfo.buildNumber();

/// How this copy of the app arrived, which decides where "update" should send
/// it.
///
/// Not cosmetic. A Play install gets Play's own update flows, and its store
/// page as the fallback; anything else is sent to the download page, which
/// now explains the store and how to get in during closed testing. The two
/// carry different signatures, so a Play build can never be updated by
/// anything the site could offer anyway.
///
/// Anything that is not Play is treated as a sideload. A sideload reports the
/// installer's own package, or nothing at all when it came through adb, and
/// that is the right answer when the question cannot be answered.
enum UpdateChannel { play, sideload }

Future<UpdateChannel> currentUpdateChannel() async {
  await AppInfo.packageInfo();
  return AppInfo.isPlayInstall ? UpdateChannel.play : UpdateChannel.sideload;
}

/// Send this install to the update: the Google Play listing, whatever the
/// install channel.
///
/// The store is where the app lives now. A sideloaded copy used to be sent to
/// the site's download page because that page handed out the APK; it hands
/// out the Play link today, so going through it is one hop for nothing — and
/// an old cached copy of that page still offered a file. Play first, the site
/// only when this phone can open neither the Play app nor a browser to the
/// listing, which leaves it with nothing better.
Future<void> openUpdateDestination() async {
  final info = await AppInfo.packageInfo();
  // The package name comes from the package itself rather than a constant,
  // for the same reason the build number does: it cannot then drift from what
  // was actually shipped.
  final id = info?.packageName ?? 'com.mabanda.mambandamarket';
  // market:// opens the Play app straight on the listing; the https form is
  // the fallback for a phone with no Play app to handle the scheme.
  if (await _tryLaunch(Uri.parse('market://details?id=$id'))) return;
  if (await _tryLaunch(
    Uri.parse('https://play.google.com/store/apps/details?id=$id'),
  )) {
    return;
  }
  await _tryLaunch(Uri.parse('${ShareLinks.siteBase}/download'));
}

/// launchUrl throws when nothing can handle the scheme, which is a normal
/// answer here rather than an error worth propagating into the gate.
Future<bool> _tryLaunch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
