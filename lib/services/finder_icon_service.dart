import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Writes a custom Finder icon so WebM files show a video frame in the desktop.
class FinderIconService {
  FinderIconService._();

  static const _channel = MethodChannel('fik_player/finder_icons');

  static Future<void> applyIfWebM(String videoPath, Uint8List jpeg) async {
    if (!videoPath.toLowerCase().endsWith('.webm')) return;
    if (jpeg.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('setFileIcon', {
        'path': videoPath,
        'jpeg': jpeg,
      });
    } catch (e, st) {
      debugPrint('Finder icon failed: $e\n$st');
    }
  }
}
