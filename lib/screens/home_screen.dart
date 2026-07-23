import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/download_provider.dart';
import '../providers/history_provider.dart';
import '../services/download_service.dart';
import '../widgets/index.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuad);
    _animCtrl.forward();
    context.read<DownloadProvider>().loadPlatforms();
    context.read<HistoryProvider>().load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String? _detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('tiktok.com') || u.contains('vm.tiktok')) return 'TikTok';
    if (u.contains('instagram.com') || u.contains('instagr.am')) return 'Instagram';
    if (u.contains('facebook.com') || u.contains('fb.com') || u.contains('fb.watch')) return 'Facebook';
    if (u.contains('twitter.com') || u.contains('x.com')) return 'Twitter';
    if (u.contains('youtube.com') || u.contains('youtu.be')) return 'YouTube';
    if (u.contains('capcut.com')) return 'CapCut';
    if (u.contains('threads.net')) return 'Threads';
    if (u.contains('pinterest.com')) return 'Pinterest';
    if (u.contains('reddit.com')) return 'Reddit';
    return null;
  }

  Future<void> _download() async {
    if (!_formKey.currentState!.validate()) return;
    final url = _urlCtrl.text.trim();
    final dp = context.read<DownloadProvider>();

    final ok = await dp.download(url);
    if (!mounted) return;

    if (ok && dp.result != null) {
      _urlCtrl.clear();
      _showResult(dp.result!);
    } else if (dp.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dp.error!),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showLogResult(DownloadResult result) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => ChangeNotifierProvider.value(
          value: context.read<DownloadProvider>(),
          child: ResultScreen(result: result),
        ),
        transitionsBuilder: (_, a1, _, child) =>
            SlideTransition(position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutQuad)),
              child: FadeTransition(opacity: a1, child: child),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _showResult(DownloadResult result) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => ChangeNotifierProvider.value(
          value: context.read<DownloadProvider>(),
          child: ResultScreen(result: result),
        ),
        transitionsBuilder: (_, a1, _, child) =>
            SlideTransition(position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutQuad)),
              child: FadeTransition(opacity: a1, child: child),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DownloadProvider>();
    final platform =
        _urlCtrl.text.isNotEmpty ? _detectPlatform(_urlCtrl.text.trim()) : null;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── Header ──
                const GradientHeader(text: 'KiAPP\nDownloader'),
                const SizedBox(height: 8),
                Text(
                  'Tempel link video, download gratis!',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),

                // ── Quota badge ──
                if (dp.remainingQuota != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: dp.remainingQuota! <= 5
                                ? AppTheme.error.withOpacity(0.2)
                                : AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: dp.remainingQuota! <= 5
                                  ? AppTheme.error.withOpacity(0.5)
                                  : AppTheme.primary.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                dp.remainingQuota! <= 5
                                    ? Icons.warning_amber_rounded
                                    : Icons.download_for_offline_rounded,
                                size: 16,
                                color: dp.remainingQuota! <= 5
                                    ? AppTheme.error
                                    : AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sisa kuota: ${dp.remainingQuota}',
                                style: TextStyle(
                                  color: dp.remainingQuota! <= 5
                                      ? AppTheme.error
                                      : AppTheme.primaryLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── URL Glass Card ──
                GlassCard(
                  radius: 20,
                  blur: 30,
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _urlCtrl,
                          decoration: InputDecoration(
                            labelText: 'Tempel URL',
                            hintText: 'https://tiktok.com/...',
                            prefixIcon:
                                const Icon(Icons.link_rounded, color: AppTheme.primaryLight),
                            suffixIcon: _urlCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Color(0xFF8888A0)),
                                    onPressed: () {
                                      _urlCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Masukkan URL';
                            if (!v.trim().startsWith('http')) {
                              return 'URL harus diawali http:// atau https://';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        if (platform != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 16, color: AppTheme.success),
                                const SizedBox(width: 6),
                                Text(
                                  '$platform terdeteksi',
                                  style: const TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        GlowButton(
                          onPressed: dp.status == DownloadStatus.loading
                              ? null
                              : _download,
                          height: 54,
                          child: dp.status == DownloadStatus.loading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Memproses...'),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded),
                                    SizedBox(width: 10),
                                    Text('Download'),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // ── Platform Grid ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Platform Didukung',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('9 platform', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    PlatformChip('TikTok', Icons.music_note),
                    PlatformChip('Instagram', Icons.camera_alt),
                    PlatformChip('Facebook', Icons.facebook),
                    PlatformChip('Twitter', Icons.alternate_email),
                    PlatformChip('YouTube', Icons.play_circle),
                    PlatformChip('CapCut', Icons.content_cut),
                    PlatformChip('Threads', Icons.chat),
                    PlatformChip('Pinterest', Icons.push_pin),
                    PlatformChip('Reddit', Icons.reddit),
                  ],
                ),
                const SizedBox(height: 36),

                // ── History Carousel ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Riwayat Download',
                        style: Theme.of(context).textTheme.titleLarge),
                    if (context.watch<HistoryProvider>().items.isNotEmpty)
                      Text('${context.watch<HistoryProvider>().items.length} item',
                          style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 12),
                _HistoryCarousel(),

                // ── Aktivitas Log ──
                const SizedBox(height: 28),
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text('Aktivitas', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 12),
                _ActivityLog(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ── History Carousel ──
class _HistoryCarousel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hp = context.watch<HistoryProvider>();
    final items = hp.items;

    if (hp.loading) {
      return const SizedBox(
        height: 140,
        child: Center(child: AppLoadingIndicator()),
      );
    }

    if (items.isEmpty) {
      return GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 20, color: AppTheme.primaryLight.withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Text('Belum ada riwayat download',
                style: TextStyle(color: AppTheme.primaryLight.withValues(alpha: 0.4))),
          ],
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 8),
        itemCount: items.length > 5 ? 5 : items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () {
              // Buka download screen dengan URL tsb
            },
            child: _HistoryCarouselCard(item: item),
          );
        },
      ),
    );
  }
}

class _HistoryCarouselCard extends StatelessWidget {
  final dynamic item;
  const _HistoryCarouselCard({required this.item});

  IconData get _icon {
    final p = item.platform as String;
    if (p == 'tiktok') return Icons.music_note;
    if (p == 'instagram') return Icons.camera_alt;
    if (p == 'facebook') return Icons.facebook;
    if (p == 'twitter') return Icons.alternate_email;
    if (p == 'youtube') return Icons.play_circle;
    if (p == 'capcut') return Icons.content_cut;
    return Icons.link;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      dark: true,
      radius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumb
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: item.thumbnail != null && item.thumbnail.toString().isNotEmpty
                    ? Image.network(
                        item.thumbnail,
                        width: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallback(context),
                      )
                    : _fallback(context),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.toString().isNotEmpty ? item.title : 'No title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryLight),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_icon, size: 10, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        item.platform.toString(),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF8888A0)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Center(child: Icon(_icon, color: Colors.white, size: 28)),
    );
  }
}

/// ── Activity Log ──
class _ActivityLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DownloadProvider>();
    final logs = dp.logs;

    if (logs.isEmpty) {
      return GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 20, color: AppTheme.primaryLight.withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Text('Belum ada aktivitas download',
                style: TextStyle(color: AppTheme.primaryLight.withValues(alpha: 0.4))),
          ],
        ),
      );
    }

    return Column(
      children: logs.take(10).map((log) {
        final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            dark: true,
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: log.success
                        ? AppTheme.success.withOpacity(0.15)
                        : AppTheme.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    log.success ? Icons.check_circle : Icons.error,
                    color: log.success ? AppTheme.success : AppTheme.error,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.success ? 'Download selesai' : 'Download gagal',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.platform != null ? '${log.platform} • $time' : time,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8888A0)),
                      ),
                    ],
                  ),
                ),
                if (log.success)
                  GestureDetector(
                    onTap: () {
                      // Bisa buka hasil
                    },
                    child: const Icon(Icons.chevron_right, color: Color(0xFF8888A0), size: 20),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
