import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  String? _apiKey;
  final http.Client _client = http.Client();

  void setApiKey(String? key) => _apiKey = key;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // ignore: use_null_aware_elements
        if (_apiKey != null) 'X-API-Key': _apiKey!,
      };

  Future<Map<String, dynamic>> get(String url) async {
    final uri = Uri.parse(url);
    final resp = await _client.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    return _handle(resp);
  }

  Future<Map<String, dynamic>> post(String url, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse(url);
    final resp = await _client
        .post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConfig.timeout);
    return _handle(resp);
  }

  Future<Map<String, dynamic>> delete(String url) async {
    final uri = Uri.parse(url);
    final resp = await _client.delete(uri, headers: _headers).timeout(ApiConfig.timeout);
    return _handle(resp);
  }

  /// Multipart upload — untuk avatar & media.
  /// [fields] → field teks tambahan (mis. remoteUrl, prefix).
  Future<Map<String, dynamic>> postMultipart(
    String url, {
    required String fileField,
    required List<int> fileBytes,
    required String filename,
    String? contentType,
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse(url);
    final req = http.MultipartRequest('POST', uri);
    // API key di header
    if (_apiKey != null) req.headers['X-API-Key'] = _apiKey!;
    // Field teks
    if (fields != null) {
      req.fields.addAll(fields);
    }
    // File
    req.files.add(http.MultipartFile.fromBytes(
      fileField,
      fileBytes,
      filename: filename,
      contentType: contentType != null
          ? (contentType.startsWith('image/') || contentType.startsWith('video/') || contentType.startsWith('audio/')
              ? MediaType.parse(contentType)
              : null)
          : null,
    ));
    final streamed = await req.send().timeout(const Duration(minutes: 2));
    final resp = await http.Response.fromStream(streamed);
    return _handle(resp);
  }

  Map<String, dynamic> _handle(http.Response resp) {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return data;
    }
    final msg = data['message'] as String? ?? 'Terjadi kesalahan';
    throw ApiException(resp.statusCode, msg);
  }

  void dispose() => _client.close();
}
