import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// This build's own details, read once and remembered.
///
/// One read rather than one per question: the build number and where the
/// install came from are both on the same object, and the platform channel is
/// not free. Warmed in main() so the very first API request already carries
/// the build headers.
class AppInfo {
  AppInfo._();

  static PackageInfo? _info;
  static bool _read = false;

  /// Synchronous snapshot for hot paths (request headers). Null until [warm].
  static PackageInfo? get cached => _info;

  static Future<PackageInfo?> packageInfo() async {
    if (_read) return _info;
    try {
      _info = await PackageInfo.fromPlatform();
    } catch (_) {
      // Left null. Callers treat that as "unknown build": no gate, no headers.
    }
    _read = true;
    return _info;
  }

  static Future<void> warm() => packageInfo();

  /// Unknown build means no gate; guessing would risk locking out a phone we
  /// cannot even identify.
  static Future<int?> buildNumber() async {
    final info = await packageInfo();
    if (info == null) return null;
    return int.tryParse(info.buildNumber);
  }

  static String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => defaultTargetPlatform.name,
    };
  }

  /// Google Play's own package name, as the installer API reports it.
  static const String playStorePackage = 'com.android.vending';

  /// Whether this copy came from Google Play. Anything else — adb, a file, a
  /// third-party store — is treated as a sideload.
  static bool get isPlayInstall =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _info?.installerStore == playStorePackage;
}
