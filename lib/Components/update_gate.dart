import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/remote_config.dart';
import '../api/share_links.dart';
import '../navigation.dart';
import '../l10n/l10n.dart';

/// Stops an old build once it is no longer supported, having said so first.
///
/// The APK is sideloaded, so nothing updates itself — a build stays on a phone
/// until somebody chooses to replace it. When a release has to reach people,
/// this is what asks, and then insists.
///
/// A Play install is the exception and is asked the same question but sent
/// somewhere else: see [UpdateChannel]. Play updates itself, and an app that
/// hands its Play users an APK is breaking store policy as well as offering
/// them a file they cannot install.
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
///  * **It is never a dead end.** The blocking screen offers the download and
///    a retry. A screen that only says "update required" with no working
///    button is indistinguishable from the app being broken.
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
    unawaited(RemoteConfig.instance.load().then((_) {
      if (mounted) setState(() {});
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

  /// How this build stands against the configured floor.
  _GateState get _state {
    final build = _build;
    final cfg = RemoteConfig.instance;
    if (build == null) return _GateState.clear;
    if (cfg.updateMode == 'off') return _GateState.clear;
    if (cfg.minSupportedBuild <= 0) return _GateState.clear;
    if (build >= cfg.minSupportedBuild) return _GateState.clear;

    // Below the floor. In notify mode that is as far as it goes.
    if (cfg.updateMode == 'notify') return _GateState.warn;

    final deadline = cfg.blocksAt;
    if (deadline == null) return _GateState.warn;
    return cfg.serverNow.isBefore(deadline) ? _GateState.warn : _GateState.blocked;
  }


  Future<void> _download() => openUpdateDestination();

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == _GateState.blocked) {
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

enum _GateState { clear, warn, blocked }

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
          child: Text(channel == UpdateChannel.play
              ? l10n.updateOpenStore
              : l10n.updateDownload),
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

  final VoidCallback onDownload;
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
                    child: Text(channel == UpdateChannel.play
                        ? l10n.updateOpenStore
                        : l10n.updateDownload),
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


/// Offer the countdown, once, if this build is on notice.
///
/// Deliberately not fired from UpdateGate.build. The dialog is a route on the
/// app's Navigator, and at launch the splash finishes with
/// pushNamedAndRemoveUntil(..., (_) => false) — which removes every route,
/// including a dialog pushed a moment earlier. So it is offered *after* the
/// splash has decided the app's root, exactly like a shared link or a tapped
/// notification, and on resume where nothing is about to clear the stack.
///
/// Once per session: a launch should mention it, and by the next launch the
/// deadline is closer than it was.
Future<void> maybeWarnAboutUpdate() async {
  if (_warnedThisSession) return;

  final cfg = RemoteConfig.instance;
  if (cfg.updateMode == 'off') return;
  if (cfg.minSupportedBuild <= 0) return;

  final build = await currentBuildNumber();
  if (build == null || build >= cfg.minSupportedBuild) return;

  // Past the deadline the gate itself is showing, and this would be a dialog
  // over the top of it saying the same thing less firmly.
  final deadline = cfg.blocksAt;
  if (cfg.updateMode == 'block' &&
      deadline != null &&
      !cfg.serverNow.isBefore(deadline)) {
    return;
  }

  // Resolved before the navigator is looked up, so nothing is awaited between
  // finding it and using its context. Both reads are cached after first call,
  // so this costs nothing on the resume path.
  final channel = await currentUpdateChannel();

  final navigator = rootNavigatorKey.currentState;
  if (navigator == null || !navigator.mounted) return;
  _warnedThisSession = true;

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

bool _warnedThisSession = false;

/// This build's own details, read once and remembered.
///
/// One read rather than one per question: the build number and where the
/// install came from are both on the same object, and the platform channel is
/// not free.
PackageInfo? _cachedInfo;
bool _infoRead = false;

Future<PackageInfo?> _packageInfo() async {
  if (_infoRead) return _cachedInfo;
  try {
    _cachedInfo = await PackageInfo.fromPlatform();
  } catch (_) {
    // Left null. Every caller below treats that as "assume the build most
    // people have", which is the sideload.
  }
  _infoRead = true;
  return _cachedInfo;
}

Future<int?> currentBuildNumber() async {
  final info = await _packageInfo();
  // Unknown build means no gate; guessing would risk locking out a phone we
  // cannot even identify.
  if (info == null) return null;
  return int.tryParse(info.buildNumber);
}

/// Google Play's own package name, as the installer API reports it.
const String _playStorePackage = 'com.android.vending';

/// How this copy of the app arrived, which decides where "update" should send
/// it.
///
/// Not cosmetic. Play's Device and Network Abuse policy forbids an app
/// distributing its own updates around the store it was installed from, and
/// the download page hands out an APK — so pointing a Play install at it is
/// both the wrong destination for the user and a policy problem for the
/// listing. It is also simply broken: a Play build and a sideloaded build
/// carry different signatures, so the APK cannot install over the Play one
/// even if somebody tries.
///
/// Anything that is not Play is treated as a sideload. A sideload reports the
/// installer's own package, or nothing at all when it came through adb, and
/// the sideload is what the entire installed base is today — so it is the
/// right answer when the question cannot be answered.
enum UpdateChannel { play, sideload }

Future<UpdateChannel> currentUpdateChannel() async {
  final info = await _packageInfo();
  return info?.installerStore == _playStorePackage
      ? UpdateChannel.play
      : UpdateChannel.sideload;
}

/// Send this install wherever its update actually lives.
Future<void> openUpdateDestination() async {
  final info = await _packageInfo();
  if (info?.installerStore == _playStorePackage) {
    // market:// opens the Play app straight on the listing. The https form is
    // the fallback for the rare device that has Play as an installer but no
    // Play app to handle the scheme.
    //
    // The package name comes from the package itself rather than a constant,
    // for the same reason the build number does: it cannot then drift from
    // what was actually shipped.
    final id = info!.packageName;
    if (await _tryLaunch(Uri.parse('market://details?id=$id'))) return;
    await _tryLaunch(
      Uri.parse('https://play.google.com/store/apps/details?id=$id'),
    );
    // Deliberately no fall-through to the download page. If both of those
    // failed there is no browser and no Play app on this phone, and handing a
    // Play install an APK it cannot install over itself would be worse than
    // the button doing nothing. The blocking screen still offers retry.
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
