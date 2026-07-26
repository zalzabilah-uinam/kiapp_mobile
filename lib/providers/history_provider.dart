import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/history_service.dart';
import 'download_provider.dart';

class HistoryProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final HistoryService _historyService;

  List<HistoryItem> _items = [];
  bool _loading = false;
  String? _error;

  List<HistoryItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;

  HistoryProvider(this._apiClient) {
    _historyService = HistoryService(_apiClient);
  }

  /// Auto-refresh setiap ada download sukses.
  /// Pasang listener di constructor atau dari parent.
  void bindAutoRefresh(DownloadProvider downloadProvider) {
    downloadProvider.addOnSuccessListener(() => load());
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _historyService.getHistory();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Gagal memuat history';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    try {
      await _historyService.deleteHistory(id);
      _items.removeWhere((e) => e.id == id);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    try {
      await _historyService.clearHistory();
      _items.clear();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }
}
