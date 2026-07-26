import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/history_provider.dart';
import '../widgets/index.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animCtrl.forward();
      context.read<HistoryProvider>().load();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<HistoryProvider>().load();

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Hapus Semua History'),
        content: const Text('Yakin ingin menghapus semua history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<HistoryProvider>().clear();
            },
            child: const Text('Hapus', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hp = context.watch<HistoryProvider>();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const GradientHeader(text: 'History'),
                  if (hp.items.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_sweep,
                            color: AppTheme.error, size: 22),
                        onPressed: _confirmDeleteAll,
                        tooltip: 'Hapus semua',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Riwayat download kamu',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: hp.loading
                  ? const AppLoadingIndicator()
                  : hp.items.isEmpty
                      ? const EmptyState(
                          icon: Icons.history,
                          title: 'Belum ada history',
                          subtitle: 'Download video akan muncul di sini',
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: AppTheme.primaryLight,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: hp.items.length,
                            itemBuilder: (_, i) => StaggeredFade(
                              index: i,
                              controller: _animCtrl,
                              child: _HistoryCard(item: hp.items[i], provider: hp),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final dynamic item;
  final HistoryProvider provider;

  const _HistoryCard({required this.item, required this.provider});

  IconData get platformIcon {
    final p = item.platform as String;
    if (p == 'tiktok') return Icons.music_note;
    if (p == 'instagram') return Icons.camera_alt;
    if (p == 'facebook') return Icons.facebook;
    if (p == 'twitter') return Icons.alternate_email;
    if (p == 'youtube') return Icons.play_circle;
    if (p == 'capcut') return Icons.content_cut;
    if (p == 'threads') return Icons.chat_bubble_outline;
    return Icons.link;
  }

  @override
  Widget build(BuildContext context) {
    final date =
        '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year.toString().substring(2)} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppTheme.error),
      ),
      onDismissed: (_) => provider.delete(item.id),
      child: GlassCard(
        dark: true,
        radius: 16,
        margin: const EdgeInsets.only(bottom: 10),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
                  // Thumb
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.thumbnail != null &&
                            item.thumbnail.toString().isNotEmpty
                        ? Image.network(
                            item.thumbnail,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _platformBadge(context),
                          )
                        : _platformBadge(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.toString().isNotEmpty
                              ? item.title
                              : 'No title',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(platformIcon,
                                size: 12, color: AppTheme.primaryLight),
                            const SizedBox(width: 4),
                            Text(item.platform.toString(),
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: Color(0xFF555570),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(date,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFF555570), size: 22),
                ],
              ),
            ),
          ),
        );
      }

  Widget _platformBadge(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(platformIcon, color: Colors.white, size: 22),
    );
  }
}
