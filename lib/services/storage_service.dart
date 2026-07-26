import 'dart:io';
import 'dart:typed_data';
import '../config/api_config.dart';
import 'api_client.dart';

/// Hasil upload ke R2.
class UploadResult {
  final String key;
  final String? url;
  final String mimetype;
  final int size;

  UploadResult({
    required this.key,
    required this.url,
    required this.mimetype,
    required this.size,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      key: (json['key'] ?? '').toString(),
      url: json['url'] as String?,
      mimetype: (json['mimetype'] ?? '').toString(),
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class StorageService {
  final ApiClient _client;
  StorageService(this._client);

  /// Cek apakah R2 aktif di server.
  Future<bool> isEnabled() async {
    try {
      final resp = await _client.get(ApiConfig.storageStatus);
      return resp['data']?['enabled'] == true;
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Upload avatar langsung dari file (image picker).
  Future<UploadResult> uploadAvatarFromFile(File file) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = _imageMimeFromExt(ext);
    final filename = 'avatar.${ext.isEmpty ? 'jpg' : ext}';
    final resp = await _client.postMultipart(
      ApiConfig.storageAvatar,
      fileField: 'file',
      fileBytes: bytes,
      filename: filename,
      contentType: mime,
    );
    return UploadResult.fromJson(resp['data'] as Map<String, dynamic>);
  }

  /// Upload avatar dari bytes (mis. kamera / crop).
  Future<UploadResult> uploadAvatarFromBytes(Uint8List bytes, {String? mime, String? filename}) async {
    final resp = await _client.postMultipart(
      ApiConfig.storageAvatar,
      fileField: 'file',
      fileBytes: bytes,
      filename: filename ?? 'avatar.jpg',
      contentType: mime ?? 'image/jpeg',
    );
    return UploadResult.fromJson(resp['data'] as Map<String, dynamic>);
  }

  /// Hapus avatar (file di R2 + set profile.avatar_url = null).
  Future<void> deleteAvatar() async {
    await _client.delete(ApiConfig.storageAvatar);
  }

  /// Upload media generik (image/video/audio).
  Future<UploadResult> uploadMedia(File file, {String prefix = 'media'}) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = _guessMime(file.path);
    final resp = await _client.postMultipart(
      ApiConfig.storageMedia,
      fileField: 'file',
      fileBytes: bytes,
      filename: 'upload.${ext.isEmpty ? 'bin' : ext}',
      contentType: mime,
      fields: {'prefix': prefix},
    );
    return UploadResult.fromJson(resp['data'] as Map<String, dynamic>);
  }

  String _imageMimeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _guessMime(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    if (p.endsWith('.mp4')) return 'video/mp4';
    if (p.endsWith('.webm')) return 'video/webm';
    if (p.endsWith('.mov')) return 'video/quicktime';
    if (p.endsWith('.mp3')) return 'audio/mpeg';
    if (p.endsWith('.m4a')) return 'audio/mp4';
    if (p.endsWith('.aac')) return 'audio/aac';
    return 'image/jpeg';
  }
}
