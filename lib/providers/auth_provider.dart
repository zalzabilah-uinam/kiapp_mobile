import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final AuthService _authService;
  final StorageService _storageService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthStatus _status = AuthStatus.uninitialized;
  String? _userId;
  String? _email;
  String? _apiKey;
  String? _error;
  String? _fullName;
  String? _avatarUrl;

  AuthStatus get status => _status;
  String? get userId => _userId;
  String? get email => _email;
  String? get apiKey => _apiKey;
  String? get error => _error;
  String? get fullName => _fullName;
  String? get avatarUrl => _avatarUrl;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider(this._apiClient, this._authService, this._storageService);

  Future<void> tryAutoLogin() async {
    final key = await _storage.read(key: 'api_key');
    final savedUserId = await _storage.read(key: 'user_id');
    final savedEmail = await _storage.read(key: 'email');
    final savedName = await _storage.read(key: 'full_name');
    final savedAvatar = await _storage.read(key: 'avatar_url');

    if (key != null && key.isNotEmpty) {
      _apiKey = key;
      _apiClient.setApiKey(key);
      // Coba validasi key ke server biar tau masih valid
      try {
        final profile = await _authService.getProfile();
        final user = profile['user'] as Map<String, dynamic>?;
        _userId = user?['id'] as String? ?? savedUserId;
        _email = user?['email'] as String? ?? savedEmail;
        _fullName = user?['fullName'] as String? ?? savedName;
        _avatarUrl = user?['avatarUrl'] as String? ?? savedAvatar;
        await _persistProfile();
        _status = AuthStatus.authenticated;
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 404) {
          await _storage.delete(key: 'api_key');
          await _storage.delete(key: 'user_id');
          await _storage.delete(key: 'email');
          _apiKey = null;
          _apiClient.setApiKey(null);
          _status = AuthStatus.unauthenticated;
        } else if (e.statusCode == 500 || e.statusCode >= 502) {
          // Server error — jangan hapus key, simpan session dari storage aja
          _userId = savedUserId;
          _email = savedEmail;
          _fullName = savedName;
          _avatarUrl = savedAvatar;
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } catch (_) {
        // Error jaringan — jangan hapus key, pake data dari storage aja
        _userId = savedUserId;
        _email = savedEmail;
        _fullName = savedName;
        _avatarUrl = savedAvatar;
        _status = AuthStatus.authenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signup(String email, String password, {String? fullName}) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signup(email: email, password: password, fullName: fullName);
      await _saveSession(result.apiKey, result.userId, result.email,
          fullName: result.fullName, avatarUrl: result.avatarUrl);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Koneksi gagal. Periksa server.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signin(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signin(email: email, password: password);
      await _saveSession(result.apiKey, result.userId, result.email,
          fullName: result.fullName, avatarUrl: result.avatarUrl);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Koneksi gagal. Periksa server.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshKey() async {
    try {
      final newKey = await _authService.refreshKey();
      await _storage.write(key: 'api_key', value: newKey);
      _apiKey = newKey;
      _apiClient.setApiKey(newKey);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Refresh profile dari server (sync avatar & fullName).
  Future<void> refreshProfile() async {
    try {
      final profile = await _authService.getProfile();
      final user = profile['user'] as Map<String, dynamic>?;
      if (user != null) {
        _fullName = user['fullName'] as String? ?? _fullName;
        _avatarUrl = user['avatarUrl'] as String? ?? _avatarUrl;
        await _persistProfile();
        notifyListeners();
      }
    } catch (_) {
      // diamkan — best effort
    }
  }

  /// Ubah password akun. Return true jika sukses.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Gagal mengubah password';
      notifyListeners();
      return false;
    }
  }

  /// Upload avatar baru (file dari image_picker / kamera).
  /// Update state + persist ke local storage.
  Future<bool> updateAvatar(File file) async {
    try {
      final result = await _storageService.uploadAvatarFromFile(file);
      _avatarUrl = result.url;
      await _storage.write(key: 'avatar_url', value: result.url ?? '');
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal upload avatar: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hapus avatar (file di R2 + clear profile.avatar_url).
  Future<bool> removeAvatar() async {
    try {
      await _storageService.deleteAvatar();
      _avatarUrl = null;
      await _storage.delete(key: 'avatar_url');
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Gagal hapus avatar';
      notifyListeners();
      return false;
    }
  }

  Future<void> signout() async {
    await _storage.delete(key: 'api_key');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'email');
    await _storage.delete(key: 'full_name');
    await _storage.delete(key: 'avatar_url');
    _apiKey = null;
    _userId = null;
    _email = null;
    _fullName = null;
    _avatarUrl = null;
    _apiClient.setApiKey(null);
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _saveSession(
    String apiKey,
    String userId,
    String email, {
    String? fullName,
    String? avatarUrl,
  }) async {
    _apiKey = apiKey;
    _userId = userId;
    _email = email;
    _fullName = fullName;
    _avatarUrl = avatarUrl;
    _apiClient.setApiKey(apiKey);
    await _storage.write(key: 'api_key', value: apiKey);
    await _storage.write(key: 'user_id', value: userId);
    await _storage.write(key: 'email', value: email);
    await _persistProfile();
  }

  Future<void> _persistProfile() async {
    if (_fullName != null) {
      await _storage.write(key: 'full_name', value: _fullName!);
    }
    if (_avatarUrl != null) {
      await _storage.write(key: 'avatar_url', value: _avatarUrl!);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
