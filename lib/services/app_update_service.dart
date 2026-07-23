import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'upgrade_store.dart';

/// Service layer untuk sistem update aplikasi berbasis upgrader.
///
/// Flow:
///   1. Panggil [createUpgrader] untuk dapetin konfigurasi [Upgrader].
///   2. Bungkus root widget dengan [UpgradeAlert] pake [buildUpgradeAlert].
///   3. Waktu user klik "Update Now", otomatis buka URL download APK.
class AppUpdateService {
  AppUpdateService._(); // singleton

  static final _instance = AppUpdateService._();
  factory AppUpdateService() => _instance;

  Upgrader? _upgrader;

  /// Buat konfigurasi [Upgrader] untuk GitHub Releases.
  Upgrader createUpgrader({
    required String owner,
    required String repo,
    bool debugLogging = false,
    bool debugDisplayAlways = false,
  }) {
    _upgrader = Upgrader(
      storeController: UpgraderStoreController(
        onAndroid: () => GitHubReleasesStore(owner: owner, repo: repo),
      ),
      debugLogging: debugLogging,
      debugDisplayAlways: debugDisplayAlways,
      durationUntilAlertAgain: const Duration(days: 1),
    );
    return _upgrader!;
  }

  /// Dapatkan instance [Upgrader] yang sudah dibuat.
  Upgrader get upgrader {
    assert(_upgrader != null, 'Panggil createUpgrader() dulu');
    return _upgrader!;
  }

  /// Bungkus [child] widget dengan [UpgradeAlert].
  /// [onUpdateOverride] opsional, jika ingin handle klik "Update Now" sendiri.
  Widget buildUpgradeAlert({
    required Widget child,
    VoidCallback? onUpdateOverride,
  }) {
    assert(_upgrader != null, 'Panggil createUpgrader() dulu');

    return UpgradeAlert(
      upgrader: _upgrader!,
      onUpdate: () {
        if (onUpdateOverride != null) {
          onUpdateOverride();
          return false;
        }
        _handleUpdate();
        return false; // skip default sendUserToAppStore
      },
      child: child,
    );
  }

  /// Handler default "Update Now": buka URL download APK di browser.
  void _handleUpdate() {
    final url = _upgrader?.versionInfo?.appStoreListingURL;
    if (url != null && url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
