import '../config/api_config.dart';
import 'api_client.dart';

class AuthResult {
  final String userId;
  final String email;
  final String apiKey;
  final String? fullName;
  final String? avatarUrl;

  AuthResult({
    required this.userId,
    required this.email,
    required this.apiKey,
    this.fullName,
    this.avatarUrl,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return AuthResult(
      userId: (user['id'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      fullName: user['fullName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
    );
  }
}

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<AuthResult> signup({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (fullName != null && fullName.isNotEmpty) body['fullName'] = fullName;

    final resp = await _client.post(ApiConfig.signup, body: body);
    return AuthResult.fromJson(resp['data'] as Map<String, dynamic>);
  }

  Future<AuthResult> signin({
    required String email,
    required String password,
  }) async {
    final resp = await _client.post(ApiConfig.signin, body: {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(resp['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final resp = await _client.get(ApiConfig.me);
    return resp['data'] as Map<String, dynamic>;
  }

  Future<String> refreshKey() async {
    final resp = await _client.post(ApiConfig.refreshKey);
    return resp['data']['apiKey'] as String;
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final resp = await _client.post(ApiConfig.changePassword, body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    return resp['message'] as String? ?? 'Password berhasil diperbarui';
  }
}
