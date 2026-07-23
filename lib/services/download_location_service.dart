import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kelola folder download pilihan user.
/// Default: [getApplicationDocumentsDirectory]/Downloads
/// User bisa ganti lewat Settings → pilih folder via SAF (file_picker).
class DownloadLocationService extends ChangeNotifier {
  static const String _key = 'download_folder_uri';

  String? _customPath;
  bool _initialized = false;

  String? get customPath => _customPath;
  bool get hasCustomPath => _customPath != null && _customPath!.isNotEmpty;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _customPath = prefs.getString(_key);
    _initialized = true;
  }

  /// Dapetin folder download aktif (custom atau default).
  Future<Directory> getDownloadDirectory() async {
    await init();
    if (_customPath != null) {
      final dir = Directory(_customPath!);
      if (await dir.exists()) return dir;
    }
    // Fallback ke default
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/Downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Set folder custom dari path absolut.
  Future<void> setCustomPath(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _customPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
    notifyListeners();
  }

  /// Reset ke folder default (app docs/Downloads).
  Future<void> resetToDefault() async {
    _customPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }

  /// Buka folder download di file manager.
  /// Butuh [open_file_plus] atau platform channel.
  /// Return path folder saat ini.
  Future<String> getCurrentPath() async {
    final dir = await getDownloadDirectory();
    return dir.path;
  }
}
