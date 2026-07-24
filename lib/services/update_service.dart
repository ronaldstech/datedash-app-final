import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });
}

class UpdateService {
  static const String _defaultDownloadUrl =
      'https://unimarket-mw.com/snellum/snellum.apk';

  /// Returns [AppUpdateInfo] if an update is available, otherwise null.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final latestVersion = (data['latest_version'] ?? '').toString().trim();
      final downloadUrl =
          (data['download_url'] ?? _defaultDownloadUrl).toString().trim();
      final releaseNotes =
          (data['release_notes'] ?? 'Bug fixes and improvements.')
              .toString()
              .trim();
      // Handle force_update stored as bool OR as string "true"
      final rawForce = data['force_update'];
      final forceUpdate =
          rawForce == true || rawForce?.toString().toLowerCase() == 'true';

      if (latestVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      debugPrint('UpdateService: comparing remote: "$latestVersion" with local: "$currentVersion"');

      if (_isNewer(latestVersion, currentVersion)) {
        return AppUpdateInfo(
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          forceUpdate: forceUpdate,
        );
      }
      return null;
    } catch (e) {
      debugPrint('UpdateService: Error checking for update: $e');
      return null;
    }
  }

  /// Returns true if [remote] version is strictly greater than [current].
  bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (int i = 0; i < 3; i++) {
      if (r.semVer[i] > c.semVer[i]) return true;
      if (r.semVer[i] < c.semVer[i]) return false;
    }
    return r.build > c.build;
  }

  _Version _parse(String version) {
    final plusSplit = version.split('+');
    final semVerStr = plusSplit[0];
    final buildStr = plusSplit.length > 1 ? plusSplit[1] : '';

    final semVerParts = semVerStr.split('.').map((e) {
      return int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }).toList();
    while (semVerParts.length < 3) {
      semVerParts.add(0);
    }

    final build = int.tryParse(buildStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return _Version(semVerParts, build);
  }
}

class _Version {
  final List<int> semVer;
  final int build;

  _Version(this.semVer, this.build);
}
