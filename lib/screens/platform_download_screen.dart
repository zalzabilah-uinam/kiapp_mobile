import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/download_provider.dart';
import '../providers/history_provider.dart';
import '../services/download_service.dart';
import '../widgets/index.dart';
import 'result_screen.dart';

/// Dedicated download screen per platform.
/// Dipakai dari HomeScreen ketika user tap salah satu PlatformChip.
/// Sama fungsinya dengan input URL di Home, tapi lebih visual
/// (icon + gradient per platform) supaya user paham lagi di screen mana.
class PlatformDownloadScreen extends StatefulWidget {
  final String platform;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const PlatformDownloadScreen({
    super.key,
    required this.platform,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  @override
  State<PlatformDownloadScreen> createState() => _PlatformDownloadScreenState();
}

class _PlatformDownloadScreenState extends State<PlatformDownloadScreen> {
  final _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (!_formKey.currentState!.validate()) return;
    final url = _urlCtrl.text.trim();

    final dp = context.read<DownloadProvider>();
    final hp = context.read<HistoryProvider>();

    final ok = await dp.download(url);
    if (!mounted) return;

    if (ok && dp.result != null) {
      _urlCtrl.clear();
      hp.load();
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

  void _showResult(DownloadResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<DownloadProvider>(),
          child: ResultScreen(result: result),
        ),
      ),
    );
  }

  String get _hintText {
    switch (widget.platform) {
      case 'tiktok':
        return 'https://www.tiktok.com/@user/video/...';
      case 'instagram':
        return 'https://www.instagram.com/reel/...';
      case 'facebook':
        return 'https://www.facebook.com/watch/...';
      case 'twitter':
        return 'https://x.com/user/status/...';
      case 'youtube':
        return 'https://www.youtube.com/watch?v=...';
      case 'capcut':
        return 'https://www.capcut.com/t/...';
      case 'threads':
        return 'https://www.threads.net/@user/post/...';
      case 'pinterest':
        return 'https://www.pinterest.com/pin/...';
      default:
        return 'https://...';
    }
  }

  String get _describe {
    switch (widget.platform) {
      case 'tiktok':
        return 'Video TikTok tanpa watermark';
      case 'instagram':
        return 'Reels, foto & video Instagram';
      case 'facebook':
        return 'Video Facebook (HD kalau tersedia)';
      case 'twitter':
        return 'Video & GIF Twitter / X';
      case 'youtube':
        return 'Video YouTube dengan pilih kualitas';
      case 'capcut':
        return 'Template CapCut';
      case 'threads':
        return 'Postingan Threads';
      case 'pinterest':
        return 'Pin Pinterest video / gambar';
      default:
        return 'Download dari ${widget.label}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DownloadProvider>();
    final loading = dp.status == DownloadStatus.loading;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Hero card with platform icon ──
                GlassCard(
                  radius: 24,
                  blur: 30,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: widget.gradient.first.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _describe,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB0B0C8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── URL Input ──
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
                            labelText: 'Tempel URL ${widget.label}',
                            hintText: _hintText,
                            prefixIcon: Icon(
                              Icons.link_rounded,
                              color: AppTheme.primaryLight,
                            ),
                            suffixIcon: _urlCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Color(0xFF8888A0),
                                    ),
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
                            if (v == null || v.trim().isEmpty) {
                              return 'Masukkan URL';
                            }
                            if (!v.trim().startsWith('http')) {
                              return 'URL harus diawali http:// atau https://';
                            }
                            // Validasi host harusnyut sesuai platform
                            final lower = v.toLowerCase();
                            final ok = _hostMatches(lower);
                            if (!ok) {
                              return 'URL sepertinya bukan dari ${widget.label}';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        GlowButton(
                          onPressed: loading ? null : _download,
                          height: 54,
                          child: loading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Memproses...'),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(widget.icon),
                                    const SizedBox(width: 10),
                                    const Text('Download'),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Tips ──
                GlassCard(
                  dark: true,
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Buka ${widget.label}, cari video/post yang ingin di-download, '
                          'tap Bagikan → Salin Tautan, lalu paste di atas.',
                          style: const TextStyle(
                            color: Color(0xFFB0B0C8),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hostMatches(String lower) {
    switch (widget.platform) {
      case 'tiktok':
        return lower.contains('tiktok.com') || lower.contains('vm.tiktok');
      case 'instagram':
        return lower.contains('instagram.com') || lower.contains('instagr.am');
      case 'facebook':
        return lower.contains('facebook.com') ||
            lower.contains('fb.com') ||
            lower.contains('fb.watch');
      case 'twitter':
        return lower.contains('twitter.com') ||
            lower.contains('x.com') ||
            lower.contains('t.co');
      case 'youtube':
        return lower.contains('youtube.com') || lower.contains('youtu.be');
      case 'capcut':
        return lower.contains('capcut.com');
      case 'threads':
        return lower.contains('threads.net') || lower.contains('threads.com');
      case 'pinterest':
        return lower.contains('pinterest.com') || lower.contains('pin.it');
      default:
        return true;
    }
  }
}
