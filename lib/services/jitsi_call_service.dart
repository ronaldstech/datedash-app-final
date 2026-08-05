import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class JitsiCallService {
  static const String serverBase = 'https://meet.ffmuc.net';

  Uri buildRoomUri({
    required String roomName,
    required bool isVideo,
  }) {
    final sanitizedRoom = Uri.encodeComponent(roomName.trim());
    final config = isVideo
        ? 'config.prejoinPageEnabled=false'
        : 'config.prejoinPageEnabled=false&config.startWithVideoMuted=true';
    return Uri.parse('$serverBase/$sanitizedRoom#$config');
  }

  Future<bool> launchRoom({
    required String roomName,
    required bool isVideo,
  }) async {
    final uri = buildRoomUri(roomName: roomName, isVideo: isVideo);
    try {
      if (!await canLaunchUrl(uri)) {
        return false;
      }
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Error launching Jitsi room: $error');
      return false;
    }
  }
}
