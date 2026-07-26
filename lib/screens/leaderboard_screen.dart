import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/leaderboard_service.dart';
import '../widgets/index.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardService _service;
  LeaderboardSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = LeaderboardService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _service.getTop(limit: 50);
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat leaderboard: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primaryLight,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const GradientHeader(text: 'Leaderboard'),
                const SizedBox(height: 4),
                Text(
                  'Top user berdasarkan total download. Username bisa berubah, peringkat tetap milik user ID kamu.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_loading) const _LoadingBlock(),
                if (_error != null) _ErrorBlock(message: _error!, onRetry: _load),
                if (_snapshot != null && !_loading) ...[
                  if (_snapshot!.currentUserRank != null ||
                      _snapshot!.currentUserTotal > 0)
                    _CurrentUserCard(
                      rank: _snapshot!.currentUserRank,
                      total: _snapshot!.currentUserTotal,
                      fullName: auth.fullName,
                      email: auth.email,
                      avatarUrl: auth.avatarUrl,
                    ),
                  const SizedBox(height: 18),
                  if (_snapshot!.entries.isEmpty)
                    const _EmptyState()
                  else ...[
                    if (_snapshot!.entries.length >= 3)
                      _Podium(top3: _snapshot!.entries.take(3).toList()),
                    const SizedBox(height: 18),
                    Text('Peringkat Lengkap',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ..._snapshot!.entries
                        .where((e) => e.rank > 3)
                        .map((e) => _RankTile(
                              entry: e,
                              isMe: e.userId == auth.userId,
                            )),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryLight),
            SizedBox(height: 16),
            Text('Memuat leaderboard...',
                style: TextStyle(color: Color(0xFF8888A0))),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      dark: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.error),
              SizedBox(width: 10),
              Text('Gagal memuat',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(color: Color(0xFFB0B0C8), fontSize: 13)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryLight,
              side: BorderSide(
                  color: AppTheme.primaryLight.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentUserCard extends StatelessWidget {
  final int? rank;
  final int total;
  final String? fullName;
  final String? email;
  final String? avatarUrl;

  const _CurrentUserCard({
    required this.rank,
    required this.total,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final name = fullName?.isNotEmpty == true ? fullName! : (email ?? 'Kamu');
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _Avatar(url: avatarUrl, fallbackText: name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Peringkat Kamu',
                    style: TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(
                  rank != null ? '#$rank' : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    // Urutin kiri-ke-kanan: 2, 1, 3
    final order = <LeaderboardEntry>[];
    if (top3.length >= 2) order.add(top3[1]);
    if (top3.isNotEmpty) order.add(top3[0]);
    if (top3.length >= 3) order.add(top3[2]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: order.map((e) {
        final isFirst = e.rank == 1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                _Avatar(
                  url: e.avatarUrl,
                  fallbackText: e.displayName,
                  size: isFirst ? 64 : 52,
                ),
                const SizedBox(height: 8),
                Text(
                  e.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isFirst ? 13 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${e.totalDownloads}',
                    style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  height: isFirst ? 90 : 64,
                  decoration: BoxDecoration(
                    gradient: isFirst
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFD66B), Color(0xFFFF8A3D)],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              e.rank == 2
                                  ? const Color(0xFFB7C4FF)
                                  : const Color(0xFFE29D6F),
                              e.rank == 2
                                  ? const Color(0xFF6B7BD9)
                                  : const Color(0xFF9B5A3F),
                            ],
                          ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${e.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RankTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  const _RankTile({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        dark: true,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              alignment: Alignment.center,
              child: Text('#${entry.rank}',
                  style: TextStyle(
                    color: isMe ? AppTheme.primaryLight : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            const SizedBox(width: 6),
            _Avatar(
                url: entry.avatarUrl,
                fallbackText: entry.displayName,
                size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${entry.displayName} (Kamu)' : entry.displayName,
                    style: TextStyle(
                      color: isMe ? AppTheme.primaryLight : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ID ${entry.userId.substring(0, 8)}...',
                    style: const TextStyle(
                        color: Color(0xFF8888A0), fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.download_rounded,
                    color: AppTheme.primaryLight, size: 16),
                const SizedBox(width: 4),
                Text('${entry.totalDownloads}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
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
          Icon(Icons.emoji_events_rounded,
              color: AppTheme.primaryLight, size: 48),
          SizedBox(height: 12),
          Text('Belum ada data',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'User yang sudah mendownload akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8888A0), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String fallbackText;
  final double size;
  const _Avatar({
    required this.url,
    required this.fallbackText,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final initial = fallbackText.isNotEmpty
        ? fallbackText.characters.first.toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: url == null ? AppTheme.primaryGradient : null,
        color: url != null ? const Color(0xFF2A2A3E) : null,
        shape: BoxShape.circle,
        image: url != null
            ? DecorationImage(
                image: NetworkImage(url!),
                fit: BoxFit.cover,
                onError: (_, __) {},
              )
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
