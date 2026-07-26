class ApiConfig {
  // Ganti dengan IP/domain backend-mu
  static const String baseUrl = 'http://api.kiaapp.fyas.my.id';

  static const String signup = '$baseUrl/api/auth/signup';
  static const String signin = '$baseUrl/api/auth/signin';
  static const String me = '$baseUrl/api/auth/me';
  static const String refreshKey = '$baseUrl/api/auth/refresh-key';
  static const String changePassword = '$baseUrl/api/auth/change-password';
  static const String download = '$baseUrl/api/download';
  static const String platforms = '$baseUrl/api/download/platforms';
  static const String history = '$baseUrl/api/history';
  static const String leaderboard = '$baseUrl/api/leaderboard';

  // Storage (R2) endpoints
  static const String storageStatus = '$baseUrl/api/storage/status';
  static const String storageAvatar = '$baseUrl/api/storage/avatar';
  static const String storageMedia = '$baseUrl/api/storage/media';

  static const Duration timeout = Duration(seconds: 30);
}
