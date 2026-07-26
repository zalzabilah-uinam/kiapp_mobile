import '../config/api_config.dart';
import 'api_client.dart';

/// Satu pesan di chat global.
class ChatMessage {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? fullName;
  final String? username;
  final String? avatarUrl;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.fullName,
    this.username,
    this.avatarUrl,
  });

  /// Nama tampilan: full_name → username → fallback ke id.
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'User ${userId.substring(0, 8)}';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      fullName: json['fullName'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Hasil GET /api/chat/messages
class ChatPage {
  final List<ChatMessage> messages;
  final String? nextCursor;
  final bool hasMore;

  ChatPage({
    required this.messages,
    required this.nextCursor,
    required this.hasMore,
  });
}

class ChatService {
  final ApiClient _client;
  ChatService(this._client);

  /// Ambil pesan terbaru (atau yang lebih lama dari [before]).
  Future<ChatPage> fetchMessages({int limit = 50, DateTime? before}) async {
    final qp = <String, String>{'limit': '$limit'};
    if (before != null) qp['before'] = before.toUtc().toIso8601String();
    final uri = Uri.parse(ApiConfig.chatMessages).replace(queryParameters: qp);

    final resp = await _client.get(uri.toString());
    final data = resp['data'] as Map<String, dynamic>;
    final list = (data['messages'] as List? ?? const [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return ChatPage(
      messages: list,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  /// Kirim pesan baru.
  Future<ChatMessage> send(String content) async {
    final resp = await _client.post(
      ApiConfig.chatMessages,
      body: {'content': content},
    );
    return ChatMessage.fromJson(resp['data'] as Map<String, dynamic>);
  }

  /// Hapus pesan sendiri (soft delete).
  Future<void> deleteMessage(String id) async {
    await _client.delete('${ApiConfig.chatMessages}/$id');
  }
}