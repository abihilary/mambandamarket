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
    if (mounted) setState(() => _build = parsed);
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


  Future<void> _download() async {
    await launchUrl(
      Uri.parse('${ShareLinks.siteBase}/download'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == _GateState.blocked) {
      // Replaces the app rather than covering it: there is nothing behind this
      // worth reaching, and a dismissible "blocking" screen is not one.
      return _BlockedScreen(onDownload: _download, onRetry: _retry);
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
  const _CountdownDialog({required this.remaining, required this.onDownload});

  final Duration? remaining;
  final VoidCallback onDownload;

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
        FilledButton(onPressed: onDownload, child: Text(l10n.updateDownload)),
      ],
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen({required this.onDownload, required this.onRetry});

  final VoidCallback onDownload;
  final Future<void> Function() onRetry;

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
                    child: Text(l10n.updateDownload),
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

  final navigator = rootNavigatorKey.currentState;
  if (navigator == null || !navigator.mounted) return;
  _warnedThisSession = true;

  final left = deadline?.difference(cfg.serverNow);
  await showDialog<void>(
    context: navigator.context,
    builder: (ctx) => _CountdownDialog(
      remaining: left != null && !left.isNegative ? left : null,
      onDownload: () {
        Navigator.pop(ctx);
        unawaited(launchUrl(
          Uri.parse('${ShareLinks.siteBase}/download'),
          mode: LaunchMode.externalApplication,
        ));
      },
    ),
  );
}

bool _warnedThisSession = false;

/// This build's number, read once and remembered.
int? _cachedBuild;
bool _buildRead = false;

Future<int?> currentBuildNumber() async {
  if (_buildRead) return _cachedBuild;
  try {
    final info = await PackageInfo.fromPlatform();
    _cachedBuild = int.tryParse(info.buildNumber);
  } catch (_) {
    // Unknown build means no gate; guessing would risk locking out a phone we
    // cannot even identify.
  }
  _buildRead = true;
  return _cachedBuild;
}
