import 'dart:async';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Captures JPEG frames at a given timestamp without touching the main player.
class SeekPreviewService {
  Player? _player;
  VideoController? _videoController;
  String? _path;

  String? _queuedPath;
  Duration? _queuedAt;
  Future<Uint8List?>? _inFlight;

  Future<void> dispose() async {
    _queuedPath = null;
    _queuedAt = null;
    final player = _player;
    _player = null;
    _videoController = null;
    _path = null;
    if (player != null) {
      await player.dispose();
    }
  }

  Future<Uint8List?> capture(String path, Duration at) async {
    _queuedPath = path;
    _queuedAt = at < Duration.zero ? Duration.zero : at;

    while (true) {
      _inFlight ??= _drain();
      final result = await _inFlight!;
      if (_queuedAt == null) return result;
      // A newer hover target arrived after drain finished.
    }
  }

  Future<Uint8List?> _drain() async {
    Uint8List? latest;
    try {
      while (_queuedPath != null && _queuedAt != null) {
        final targetPath = _queuedPath!;
        final target = _queuedAt!;
        _queuedPath = null;
        _queuedAt = null;

        await _ensureOpen(targetPath);
        final player = _player;
        if (player == null) continue;

        final duration = player.state.duration;
        final clamped = duration > Duration.zero && target > duration
            ? duration
            : target;
        await player.seek(clamped);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final bytes = await player.screenshot(format: 'image/jpeg');
        if (bytes != null && bytes.isNotEmpty) {
          latest = bytes;
        }
      }
    } catch (_) {
      // Keep last successful frame if any.
    } finally {
      _inFlight = null;
    }
    return latest;
  }

  Future<void> _ensureOpen(String path) async {
    if (_player != null && _path == path) return;

    final old = _player;
    _player = null;
    _videoController = null;
    _path = null;
    if (old != null) {
      await old.dispose();
    }

    final player = Player();
    final controller = VideoController(player);
    _player = player;
    _videoController = controller;
    _path = path;

    await player.setVolume(0);
    await player.open(Media(path), play: false);

    for (var i = 0; i < 25; i++) {
      if (player.state.duration > Duration.zero || player.state.width != null) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    // Keep reference so the video pipeline stays warm for screenshots.
    // ignore: unnecessary_statements
    _videoController;
  }
}

Duration quantizeToEveryNthFrame(Duration time, double fps, int nth) {
  if (fps <= 0 || nth <= 0) return time;
  final frame = (time.inMicroseconds / 1e6 * fps).round();
  final snapped = (frame ~/ nth) * nth;
  final micros = (snapped / fps * 1e6).round();
  return Duration(microseconds: micros < 0 ? 0 : micros);
}

double fpsFromPlayer(Player player) {
  for (final track in player.state.tracks.video) {
    final fps = track.fps;
    if (fps != null && fps > 0) return fps;
  }
  return 30;
}
