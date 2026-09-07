import 'dart:async';

import 'package:in_app_update/in_app_update.dart';

import 'app_info.dart';

/// What a Play update attempt came to.
enum PlayUpdateOutcome {
  /// Play's sheet was shown and the user accepted; the download is under way.
  started,

  /// Play has no update to offer (yet) — the store has not propagated the new
  /// build, or the device is not eligible.
  notAvailable,

  /// Play's sheet was shown and the user said no.
  declined,

  /// Play could not be asked at all: not a Play install, an emulator, a debug
  /// build, web, iOS. The caller falls back to its own dialog.
  unavailable,
}

/// Google Play's in-app update flows, wrapped so nothing else imports the
/// plugin and every call is safe to make on a phone where it cannot work.
///
/// The plugin throws on any copy that did not come from Play, on emulators
/// without a Play-installed app, and on debug builds. None of those is an
/// error worth propagating into the update gate — they are all "ask the user
/// our own way instead" — so every method here catches and reports.
class PlayUpdates {
  PlayUpdates._();

  static bool get supported => AppInfo.isPlayInstall;

  /// Null when Play cannot answer. Never throws.
  static Future<AppUpdateInfo?> check() async {
    if (!supported) return null;
    try {
      return await InAppUpdate.checkForUpdate();
    } catch (_) {
      return null;
    }
  }

  /// Flexible flow: Play shows its own sheet, the download continues in the
  /// background, and [installStatus] reports when it is ready to install.
  static Future<PlayUpdateOutcome> startFlexible([AppUpdateInfo? info]) async {
    info ??= await check();
    if (info == null) return PlayUpdateOutcome.unavailable;
    if (info.updateAvailability != UpdateAvailability.updateAvailable ||
        !info.flexibleUpdateAllowed) {
      return PlayUpdateOutcome.notAvailable;
    }
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      return switch (result) {
        AppUpdateResult.success => PlayUpdateOutcome.started,
        AppUpdateResult.userDeniedUpdate => PlayUpdateOutcome.declined,
        _ => PlayUpdateOutcome.unavailable,
      };
    } catch (_) {
      return PlayUpdateOutcome.unavailable;
    }
  }

  /// Immediate flow, for the blocked state: Play takes over the screen until
  /// the update is installed. False means "fall back to the store link".
  static Future<bool> performImmediate() async {
    final info = await check();
    if (info == null ||
        info.updateAvailability != UpdateAvailability.updateAvailable ||
        !info.immediateUpdateAllowed) {
      return false;
    }
    try {
      return await InAppUpdate.performImmediateUpdate() == AppUpdateResult.success;
    } catch (_) {
      return false;
    }
  }

  /// True when a flexible download finished earlier — while the app was in the
  /// background, or before a restart — and is waiting to be installed.
  static Future<bool> hasDownloadedUpdate() async {
    final info = await check();
    return info?.installStatus == InstallStatus.downloaded;
  }

  /// Install a downloaded flexible update. Restarts the app.
  static Future<void> complete() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }

  /// Progress of a flexible download. Empty when Play is not involved.
  static Stream<InstallStatus> get installStatus {
    if (!supported) return const Stream.empty();
    try {
      return InAppUpdate.installUpdateListener;
    } catch (_) {
      return const Stream.empty();
    }
  }
}
