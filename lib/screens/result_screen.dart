import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:open_filex/open_filex.dart';
import '../config/theme.dart';
import '../services/download_service.dart';
import '../services/file_service.dart';
import '../services/download_location_service.dart';

// ignore_for_file: deprecated_member_use
import '../widgets/index.dart';

/// Grup media per tipe (video/audio/image) biar user bisa pilih kualitas dulu.
class _TypeGroup {
  final String type;
  final IconData icon;
  final String label;
  final List<MediaItem> items;
  int selectedIndex = 0;

  _TypeGroup({
    required this.type,
    required this.icon,
    required this.label,
    required this.items,
  });
}

class ResultScreen extends StatefulWidget {
  final DownloadResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final DownloadLocationService _locationService = DownloadLocationService();
  late final FileService _fileService = FileService(_locationService);
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _previewReady = false;
  String? _downloadMsg;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  /// Grup yang lagi didownload (key = type:index)
  String? _downloadingKey;

  List<_TypeGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuad);
    _animCtrl.forward();
    _buildGroups();
    _initPreview();
  }

  void _buildGroups() {
    final grouped = <String, List<MediaItem>>{};
    for (final m in widget.result.media) {
      grouped.putIfAbsent(m.type ?? 'other', () => []).add(m);
    }

    _groups = [];
    for (final entry in grouped.entries) {
      final t = entry.key;
      if (t == 'video') {
        _groups.add(_TypeGroup(
          type: t,
          icon: Icons.videocam_rounded,
          label: 'Video',
          items: entry.value,
        ));
      } else if (t == 'audio') {
        _groups.add(_TypeGroup(
          type: t,
          icon: Icons.audiotrack_rounded,
          label: 'Audio',
          items: entry.value,
        ));
      } else if (t == 'image') {
        _groups.add(_TypeGroup(
          type: t,
          icon: Icons.image_rounded,
          label: 'Gambar',
          items: entry.value,
        ));
      } else {
        _groups.add(_TypeGroup(
          type: t,
          icon: Icons.insert_drive_file_rounded,
          label: t,
          items: entry.value,
        ));
      }
    }
  }

  void _initPreview() {
    final video = widget.result.media.where((m) =>
        m.type == 'video' ||
        m.format?.contains('mp4') == true ||
        m.format?.contains('webm') == true).firstOrNull;

    if (video != null && video.url.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(video.url));
      _videoController!.initialize().then((_) {
        if (!mounted) return;
        final aspect = _videoController!.value.aspectRatio;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          aspectRatio: aspect > 0 ? aspect : 16 / 9,
          placeholder: Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight)),
          ),
          materialProgressColors: ChewieProgressColors(
            playedColor: AppTheme.primary,
            handleColor: AppTheme.primary,
            backgroundColor: Colors.white24,
          ),
        );
        setState(() => _previewReady = true);
      }).catchError((_) {
        setState(() => _previewReady = false);
      });
    }
  }

  Future<void> _downloadGroup(_TypeGroup group) async {
    final media = group.items[group.selectedIndex];
    final key = '${group.type}:${group.selectedIndex}';
    setState(() {
      _downloadingKey = key;
      _downloadMsg = null;
    });

    try {
      final path = await _fileService.downloadToDevice(
        media.url,
        fileName: 'sosmed_${DateTime.now().millisecondsSinceEpoch}',
        mediaType: media.type,
      );
      if (!mounted) return;
      setState(() {
        _downloadingKey = null;
        _downloadMsg = 'Tersimpan di folder download';
      });
      _openFile(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingKey = null;
        _downloadMsg = 'Gagal download: $e';
      });
    }
  }

  /// Buka file yang baru di-download via default app.
  void _openFile(String path) {
    OpenFilex.open(path).then((result) {
      if (!mounted) return;
      if (result.type != ResultType.done) {
        // Gagal buka file — kasih info aja
        setState(() {
          _downloadMsg = 'Tersimpan. Buka manual di folder download.';
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final firstVideo = result.media.where((m) =>
        m.type == 'video' ||
        m.format?.contains('mp4') == true ||
        m.format?.contains('webm') == true).firstOrNull;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.glassWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          title: const Text('Hasil Download',
              style: TextStyle(fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Preview ──
                if (firstVideo != null && _previewReady && _chewieController != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black,
                      ),
                      child: AspectRatio(
                        aspectRatio: _chewieController!.aspectRatio ?? 16 / 9,
                        child: Chewie(controller: _chewieController!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (firstVideo != null && !_previewReady) ...[
                  _buildThumbnail(result.thumbnail),
                  const SizedBox(height: 16),
                ],

                if (firstVideo == null && result.thumbnail != null && result.thumbnail!.isNotEmpty) ...[
                  _buildThumbnail(result.thumbnail),
                  const SizedBox(height: 16),
                ],

                // ── Title ──
                if (result.title.isNotEmpty) ...[
                  Text(result.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                ],

                // ── Grup Media ──
                ..._groups.map((group) => _buildGroupCard(group)),

                // ── Status message ──
                if (_downloadMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _downloadMsg!.contains('Gagal')
                          ? AppTheme.error.withValues(alpha: 0.15)
                          : AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _downloadMsg!.contains('Gagal')
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 18,
                          color: _downloadMsg!.contains('Gagal')
                              ? AppTheme.error
                              : AppTheme.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _downloadMsg!,
                            style: TextStyle(
                              fontSize: 13,
                              color: _downloadMsg!.contains('Gagal')
                                  ? AppTheme.error
                                  : AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(_TypeGroup group) {
    final isDownloading = _downloadingKey != null &&
        _downloadingKey!.startsWith('${group.type}:');
    final sel = group.items[group.selectedIndex];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        dark: true,
        radius: 16,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header grup ──
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(group.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  group.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (group.items.length > 1) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${group.items.length} opsi',
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // ── Chips kualitas ──
            if (group.items.length > 1)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.items.asMap().entries.map((e) {
                  final i = e.key;
                  final m = e.value;
                  final selected = group.selectedIndex == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => group.selectedIndex = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withValues(alpha: 0.25)
                            : AppTheme.glassWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : Colors.white.withValues(alpha: 0.1),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        _qualityLabel(m),
                        style: TextStyle(
                          color: selected ? AppTheme.primaryLight : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              // Cuma 1 item — tampilkan info
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _qualityLabel(group.items.first),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),

            const SizedBox(height: 14),

            // ── Info selected ──
            if (sel.format != null || sel.quality != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (sel.format != null)
                      _infoChip(sel.format!),
                    if (sel.format != null && sel.quality != null)
                      const SizedBox(width: 8),
                    if (sel.quality != null)
                      _infoChip(sel.quality!),
                  ],
                ),
              ),

            // ── Tombol download ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isDownloading ? null : () => _downloadGroup(group),
                icon: isDownloading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        group.type == 'audio' ? Icons.music_note : Icons.download,
                        size: 20,
                      ),
                label: Text(isDownloading ? 'Mengunduh...' : 'Unduh ${group.label} Ini'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: group.type == 'audio'
                      ? AppTheme.accent.withValues(alpha: 0.8)
                      : AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }

  String _qualityLabel(MediaItem m) {
    final parts = <String>[];
    if (m.quality != null && m.quality!.isNotEmpty) {
      parts.add(m.quality!.toUpperCase());
    }
    if (m.format != null && m.format!.isNotEmpty) {
      parts.add(m.format!);
    }
    if (m.width != null && m.height != null) {
      parts.add('${m.width}x${m.height}');
    }
    return parts.isNotEmpty ? parts.join(' · ') : 'Default';
  }

  Widget _buildThumbnail(String? url) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: AppTheme.glassCardDark(radius: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline,
              size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          Text('Preview tidak tersedia',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}
