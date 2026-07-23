import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'download_service.dart';

class FileService {
  final Dio _dio = Dio();

  /// Download media ke direktori download publik.
  /// [mediaType] dipakai buat nentuin extension fallback (video→.mp4, audio→.mp3, image→.jpg).
  /// Return path file yang sudah di-download.
  Future<String> downloadToDevice(
    String url, {
    String? fileName,
    String? mediaType,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/Downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final ext = _resolveExtension(url, mediaType: mediaType);
    final name = fileName ??
        'sosmed_${DateTime.now().millisecondsSinceEpoch}';
    final path = '${downloadDir.path}/$name$ext';

    await _dio.download(url, path);
    return path;
  }

  /// Resolve extension dari URL + fallback berdasarkan type.
  String _resolveExtension(String url, {String? mediaType}) {
    // Coba dari URL path
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final ext = path.split('.').last;
      if (ext.length <= 5 && !ext.contains('/') && ext.isNotEmpty) {
        return '.$ext';
      }
    } catch (_) {}

    // Fallback berdasarkan type
    switch (mediaType) {
      case 'video':
        return '.mp4';
      case 'audio':
        return '.mp3';
      case 'image':
        return '.jpg';
      default:
        return '.mp4';
    }
  }
}
