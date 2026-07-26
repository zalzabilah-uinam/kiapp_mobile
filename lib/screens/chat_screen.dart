import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../widgets/index.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _service;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _nextCursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = context.read<ChatService>();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 120 &&
        !_loadingMore &&
        _hasMore) {
      _loadOlder();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.fetchMessages(limit: 50);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat pesan: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final page = await _service.fetchMessages(limit: 50);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      // silent on pull-to-refresh
    }
  }

  Future<void> _loadOlder() async {
    if (_nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final cursorDate = DateTime.tryParse(_nextCursor!) ?? DateTime.now();
      final page = await _service.fetchMessages(
        limit: 50,
        before: cursorDate,
      );
      if (!mounted) return;
      setState(() {
        // Older messages prepend (server returns chronological asc).
        _messages.insertAll(0, page.messages);
        _nextCursor = page.nextCursor ?? _nextCursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await _service.send(text);
      if (!mounted) return;
      setState(() {
        _messages.add(msg);
        _inputCtrl.clear();
        _sending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim: $e')),
      );
    }
  }

  void _jumpToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmDelete(ChatMessage msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Hapus pesan?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Pesan akan disembunyikan dari chat untuk semua orang.',
          style: TextStyle(color: Color(0xFFB0B0C8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteMessage(msg.id);
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == msg.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppTheme.primaryLight,
                child: _buildBody(auth),
              ),
            ),
            _Composer(
              controller: _inputCtrl,
              focusNode: _inputFocus,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AuthProvider auth) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryLight),
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          GlassCard(
            dark: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error),
                    SizedBox(width: 10),
                    Text('Gagal memuat chat',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFB0B0C8), fontSize: 13)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _loadInitial,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba lagi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryLight,
                    side: BorderSide(
                        color: AppTheme.primaryLight.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(40),
        children: const [
          SizedBox(height: 80),
          _EmptyState(),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_loadingMore ? 1 : 0),
      itemBuilder: (ctx, idx) {
        if (idx == 0 && _loadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryLight),
              ),
            ),
          );
        }
        final i = _loadingMore ? idx - 1 : idx;
        final msg = _messages[i];
        return _MessageBubble(
          message: msg,
          isMe: msg.userId == auth.userId,
          onLongPress: msg.userId == auth.userId
              ? () => _confirmDelete(msg)
              : null,
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: GradientHeader(text: 'Chat Global'),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_rounded,
                    size: 14, color: AppTheme.primaryLight),
                SizedBox(width: 6),
                Text('Live',
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onLongPress;
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.onLongPress,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('dd/MM HH:mm').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppTheme.primary : AppTheme.darkCard;
    final textColor = Colors.white;
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          );

    final avatar = _BubbleAvatar(
      url: message.avatarUrl,
      fallbackText: message.displayName,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  avatar,
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 2),
                          child: Text(
                            message.displayName,
                            style: const TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: radius,
                          border: !isMe
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                )
                              : null,
                        ),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                        child: Text(
                          _formatTime(message.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF6F6F88),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  avatar,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar 32x32 untuk chat bubble — image network dengan fallback initial.
class _BubbleAvatar extends StatelessWidget {
  final String? url;
  final String fallbackText;
  const _BubbleAvatar({required this.url, required this.fallbackText});

  @override
  Widget build(BuildContext context) {
    final initial = fallbackText.isNotEmpty
        ? fallbackText.characters.first.toUpperCase()
        : '?';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: (url == null || url!.isEmpty) ? AppTheme.primaryGradient : null,
        color: (url == null || url!.isEmpty) ? null : const Color(0xFF2A2A3E),
        shape: BoxShape.circle,
        image: (url != null && url!.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(url!),
                fit: BoxFit.cover,
                onError: (_, _) {},
              )
            : null,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      alignment: Alignment.center,
      child: (url == null || url!.isEmpty)
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Tulis pesan...',
                    hintStyle: TextStyle(color: Color(0xFF6F6F88)),
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(sending: sending, onTap: onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onTap;
  const _SendButton({required this.sending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: sending ? null : AppTheme.primaryGradient,
          color: sending ? const Color(0xFF2A2A3E) : null,
          shape: BoxShape.circle,
          boxShadow: sending
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: sending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primaryLight,
                ),
              )
            : const Icon(Icons.send_rounded,
                color: Colors.white, size: 22),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      dark: true,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: const [
          Icon(Icons.chat_bubble_outline_rounded,
              color: AppTheme.primaryLight, size: 48),
          SizedBox(height: 12),
          Text('Belum ada pesan',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'Jadilah yang pertama ngobrol di komunitas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8888A0), fontSize: 13),
          ),
        ],
      ),
    );
  }
}