import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/download_service.dart';
import '../services/notification_service.dart';

enum DownloadStatus { idle, loading, success, error }

class DownloadLog {
  final String id;
  final String url;
  final String title;
  final String? platform;
  final bool success;
  final String? errorMessage;
  final DateTime timestamp;

  DownloadLog({
    required this.id,
    required this.url,
    required this.title,
    this.platform,
    required this.success,
    this.errorMessage,
    required this.timestamp,
  });
}

class DownloadProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final DownloadService _downloadService;
  final NotificationService _notifService = NotificationService();
  int _notifIdCounter = 100;

  DownloadStatus _status = DownloadStatus.idle;
  DownloadResult? _result;
  List<String> _platforms = [];
  String? _error;
  String _currentUrl = '';
  int? _remainingQuota;

  // Activity logs — riwayat aktivitas di session ini
  final List<DownloadLog> _logs = [];

  DownloadStatus get status => _status;
  DownloadResult? get result => _result;
  List<String> get platforms => _platforms;
  String? get error => _error;
  String get currentUrl => _currentUrl;
  int? get remainingQuota => _remainingQuota;
  List<DownloadLog> get logs => List.unmodifiable(_logs);

  // Listener yang dipanggil setiap kali download sukses.
  // Dipakai HistoryProvider untuk auto-refresh list.
  final List<VoidCallback> _onSuccessListeners = [];

  void addOnSuccessListener(VoidCallback listener) {
    _onSuccessListeners.add(listener);
  }

  void removeOnSuccessListener(VoidCallback listener) {
    _onSuccessListeners.remove(listener);
  }

  DownloadProvider(this._apiClient) {
    _downloadService = DownloadService(_apiClient);
  }

  void setUrl(String url) => _currentUrl = url;

  Future<void> loadPlatforms() async {
    try {
      final (list, remaining) = await _downloadService.getPlatforms();
      _platforms = list;
      if (remaining != null) _remainingQuota = remaining;
      notifyListeners();
    } catch (_) {}
  }

  /// Re-fetch sisa kuota tanpa mengubah list platform.
  /// Dipakai setelah top-up sukses supaya badge UI sync.
  Future<void> refreshQuota() async {
    try {
      final (_, remaining) = await _downloadService.getPlatforms();
      if (remaining != null) {
        _remainingQuota = remaining;
        notifyListeners();
      }
    } catch (_) {
      // best-effort
    }
  }

  /// Download berjalan async — UI gak nunggu.
  /// Navigasi tetep bebas, pas selesai muncul notif.
  Future<bool> download(String url, {bool saveToHistory = true}) async {
    _status = DownloadStatus.loading;
    _result = null;
    _error = null;
    _currentUrl = url;
    notifyListeners();

    try {
      // Jalan di background
      _result = await _downloadService.download(url, saveToHistory: saveToHistory);
      _remainingQuota = _result?.downloadsRemaining;
      _status = DownloadStatus.success;

      // Trigger history refresh listeners
      for (final cb in List<VoidCallback>.from(_onSuccessListeners)) {
        cb();
      }

      // Notif lokal
      final platform = _detectPlatform(url);
      _logs.insert(0, DownloadLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: _result?.title.isNotEmpty == true ? _result!.title : url,
        platform: platform,
        success: true,
        timestamp: DateTime.now(),
      ));
      unawaited(_notifService.showDownloadComplete(
        id: _notifIdCounter++,
        title: _result?.title.isNotEmpty == true ? _result!.title : 'Download selesai',
        platform: platform,
      ));

      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = DownloadStatus.error;

      _logs.insert(0, DownloadLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: url,
        success: false,
        errorMessage: e.message,
        timestamp: DateTime.now(),
      ));
      unawaited(_notifService.showError(
        id: _notifIdCounter++,
        message: e.message,
      ));

      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal terhubung ke server';
      _status = DownloadStatus.error;

      _logs.insert(0, DownloadLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: url,
        success: false,
        errorMessage: 'Jaringan error',
        timestamp: DateTime.now(),
      ));
      unawaited(_notifService.showError(
        id: _notifIdCounter++,
        message: 'Gagal terhubung ke server',
      ));

      notifyListeners();
      return false;
    }
  }

  void reset() {
    _status = DownloadStatus.idle;
    _result = null;
    _error = null;
    _currentUrl = '';
    _remainingQuota = null;
    notifyListeners();
  }

  String? _detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('tiktok.com') || u.contains('vm.tiktok')) return 'TikTok';
    if (u.contains('instagram.com') || u.contains('instagr.am')) return 'Instagram';
    if (u.contains('facebook.com') || u.contains('fb.com') || u.contains('fb.watch')) return 'Facebook';
    if (u.contains('twitter.com') || u.contains('x.com')) return 'Twitter';
    if (u.contains('youtube.com') || u.contains('youtu.be')) return 'YouTube';
    if (u.contains('capcut.com')) return 'CapCut';
    if (u.contains('threads.net') || u.contains('threads.com')) return 'Threads';
    return null;
  }
}
