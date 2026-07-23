import 'dart:convert';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

/// Store khusus GitHub Releases.
/// Mengambil daftar release dari repo GitHub, mencari versi tertinggi,
/// lalu meresolve URL download APK dari assets release.
class GitHubReleasesStore extends UpgraderStore {
  final String owner;
  final String repo;

  GitHubReleasesStore({required this.owner, required this.repo});

  @override
  Future<UpgraderVersionInfo> getVersionInfo({
    required UpgraderState state,
    required Version installedVersion,
    required String? country,
    required String? language,
  }) async {
    try {
      final releases = await _fetchReleases(state);
      if (releases.isEmpty) {
        return UpgraderVersionInfo(installedVersion: installedVersion);
      }

      final best = _findBestRelease(releases);
      if (best == null) {
        return UpgraderVersionInfo(installedVersion: installedVersion);
      }

      final apkUrl = _resolveApkUrl(releases, best.tagName);

      return UpgraderVersionInfo(
        installedVersion: installedVersion,
        appStoreVersion: best.version,
        appStoreListingURL: apkUrl ?? best.htmlUrl,
        releaseNotes: best.releaseNotes,
      );
    } catch (e) {
      // Gagal total — silent, biar upgrader ga nampilin apa-apa
      return UpgraderVersionInfo(installedVersion: installedVersion);
    }
  }

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  /// Fetch semua releases (published) dari GitHub API.
  Future<List<Map<String, dynamic>>> _fetchReleases(
    UpgraderState state,
  ) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/releases',
    );
    final response = await state.client.get(
      uri,
      headers: {
        ...?state.clientHeaders,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': '$owner/$repo',
      },
    );

    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body);
    if (body is! List) return [];

    return body.cast<Map<String, dynamic>>();
  }

  /// Cari release dengan tag version tertinggi.
  _ReleaseInfo? _findBestRelease(List<Map<String, dynamic>> releases) {
    _ReleaseInfo? best;

    for (final r in releases) {
      final tagName = r['tag_name'] as String? ?? '';
      final version = _parseTagVersion(tagName);
      if (version == null) continue;

      if (best == null || version > best.version) {
        best = _ReleaseInfo(
          tagName: tagName,
          version: version,
          htmlUrl: r['html_url'] as String?,
          releaseNotes: r['body'] as String?,
        );
      }
    }

    return best;
  }

  /// Parse version dari tag name (support format: v1.2.3, v1.2.3+build.456).
  Version? _parseTagVersion(String tag) {
    final raw = tag.replaceFirst(RegExp(r'^v'), '').split('+').first;
    try {
      return Version.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Cari asset APK dari release terbaik.
  /// Prioritas: arm64-v8a → APK pertama → AAB → fallback null.
  String? _resolveApkUrl(
    List<Map<String, dynamic>> releases,
    String bestTag,
  ) {
    final release = releases.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r?['tag_name'] == bestTag,
      orElse: () => null,
    );
    if (release == null) return null;

    final assets = (release['assets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (assets.isEmpty) return null;

    // Prioritas 1: arm64-v8a APK
    for (final a in assets) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      if (name.contains('arm64-v8a') && name.endsWith('.apk')) {
        return a['browser_download_url'] as String?;
      }
    }

    // Prioritas 2: APK apa pun
    for (final a in assets) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        return a['browser_download_url'] as String?;
      }
    }

    // Prioritas 3: AAB
    for (final a in assets) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.aab')) {
        return a['browser_download_url'] as String?;
      }
    }

    return null;
  }
}

/// Data class hasil parsing release.
class _ReleaseInfo {
  final String tagName;
  final Version version;
  final String? htmlUrl;
  final String? releaseNotes;

  _ReleaseInfo({
    required this.tagName,
    required this.version,
    this.htmlUrl,
    this.releaseNotes,
  });
}
