import 'package:dio/dio.dart';
import 'dart:io';
import 'download_service.dart';
import 'download_location_service.dart';

class FileService {
  final Dio _dio = Dio();
  final DownloadLocationService _locationService;

  FileService(this._locationService);

  /// Download media ke folder pilihan user.
  /// [mediaType] dipakai buat nentuin extension fallback.
  /// Return path file yang sudah di-download.
  Future<String> downloadToDevice(
    String url, {
    String? fileName,
    String? mediaType,
  }) async {
    final downloadDir = await _locationService.getDownloadDirectory();

    final ext = _resolveExtension(url, mediaType: mediaType);
    final name = fileName ??
        'sosmed_${DateTime.now().millisecondsSinceEpoch}';
    final path = '${downloadDir.path}/$name$ext';

    await _dio.download(url, path);
    return path;
  }

  /// Resolve extension dari URL + fallback berdasarkan type.
  String _resolveExtension(String url, {String? mediaType}) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final ext = path.split('.').last;
      if (ext.length <= 5 && !ext.contains('/') && ext.isNotEmpty) {
        return '.$ext';
      }
    } catch (_) {}

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
