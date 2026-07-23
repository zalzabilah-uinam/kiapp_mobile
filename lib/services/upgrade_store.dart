import 'dart:convert';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

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
    final uri = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/releases/latest',
    );
    final response = await state.client.get(
      uri,
      headers: {
        ...?state.clientHeaders,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': '$owner/$repo',
      },
    );

    if (response.statusCode != 200) {
      return UpgraderVersionInfo(installedVersion: installedVersion);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String;
    final versionStr = tagName.replaceFirst(RegExp(r'^v'), '');
    // Ambil versi sebelum + bila ada (contoh: 1.0.0+build.1)
    final cleanVersion = versionStr.split('+').first;
    final releaseUrl = data['html_url'] as String;
    final releaseNotes = data['body'] as String?;

    return UpgraderVersionInfo(
      installedVersion: installedVersion,
      appStoreVersion: Version.parse(cleanVersion),
      appStoreListingURL: releaseUrl,
      releaseNotes: releaseNotes,
    );
  }
}
