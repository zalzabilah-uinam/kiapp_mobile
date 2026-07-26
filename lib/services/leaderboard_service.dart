import '../config/api_config.dart';
import 'api_client.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String? fullName;
  final String? username;
  final String? avatarUrl;
  final int totalDownloads;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.fullName,
    required this.username,
    required this.avatarUrl,
    required this.totalDownloads,
  });

  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (username != null && username!.isNotEmpty) return '@$username';
    // fallback supaya tetep ada identifier walau profil belum di-set
    return 'User ${userId.substring(0, 8)}';
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] ?? '').toString(),
      fullName: json['fullName'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      totalDownloads: (json['totalDownloads'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardSnapshot {
  final List<LeaderboardEntry> entries;
  final int totalUsers;
  final int? currentUserRank;
  final int currentUserTotal;

  LeaderboardSnapshot({
    required this.entries,
    required this.totalUsers,
    this.currentUserRank,
    this.currentUserTotal = 0,
  });

  factory LeaderboardSnapshot.fromJson(Map<String, dynamic> json) {
    final list = (json['leaderboard'] as List? ?? const [])
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final me = json['currentUser'] as Map<String, dynamic>?;
    return LeaderboardSnapshot(
      entries: list,
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      currentUserRank: (me?['rank'] as num?)?.toInt(),
      currentUserTotal: (me?['totalDownloads'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardService {
  final ApiClient _client;
  LeaderboardService(this._client);

  Future<LeaderboardSnapshot> getTop({int limit = 50}) async {
    final resp = await _client.get(
      '${ApiConfig.leaderboard}?limit=$limit',
    );
    return LeaderboardSnapshot.fromJson(resp['data'] as Map<String, dynamic>);
  }
}
