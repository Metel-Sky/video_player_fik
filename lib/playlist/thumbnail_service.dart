import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/finder_icon_service.dart';

class ThumbnailService {
  ThumbnailService();

  Directory? _cacheDir;
  final _queue = <String>[];
  var _busy = false;
  final _listeners = <void Function(String path, String thumbPath)>[];

  void addListener(void Function(String path, String thumbPath) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(String path, String thumbPath) listener) {
    _listeners.remove(listener);
  }

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'thumbnails'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  String _cacheKey(String videoPath) {
    return sha1.convert(utf8.encode(videoPath)).toString();
  }

  Future<String?> cachedPathFor(String videoPath) async {
    final dir = await _ensureCacheDir();
    final file = File(p.join(dir.path, '${_cacheKey(videoPath)}.jpg'));
    if (await file.exists()) return file.path;
    return null;
  }

  void enqueue(String videoPath) {
    if (_queue.contains(videoPath)) return;
    _queue.add(videoPath);
    _drain();
  }

  void enqueueAll(Iterable<String> paths) {
    for (final path in paths) {
      enqueue(path);
    }
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final path = _queue.removeAt(0);
        final existing = await cachedPathFor(path);
        if (existing != null) {
          _notify(path, existing);
          try {
            final bytes = await File(existing).readAsBytes();
            await FinderIconService.applyIfWebM(path, bytes);
          } catch (_) {}
          continue;
        }
        final generated = await _generate(path);
        if (generated != null) {
          _notify(path, generated);
        }
      }
    } finally {
      _busy = false;
    }
  }

  void _notify(String path, String thumbPath) {
    for (final listener in List.of(_listeners)) {
      listener(path, thumbPath);
    }
  }

  Future<String?> _generate(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) return null;

    final dir = await _ensureCacheDir();
    final outPath = p.join(dir.path, '${_cacheKey(videoPath)}.jpg');
    final player = Player();
    final controller = VideoController(player);

    try {
      await player.setVolume(0);
      await player.open(Media(videoPath), play: false);

      // Wait briefly for demux / first frame readiness.
      for (var i = 0; i < 30; i++) {
        if (player.state.duration > Duration.zero ||
            player.state.width != null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final duration = player.state.duration;
      final seekTo = duration > const Duration(seconds: 2)
          ? const Duration(seconds: 1)
          : Duration.zero;
      if (seekTo > Duration.zero) {
        await player.seek(seekTo);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      // Touch controller so video pipeline is warm.
      // ignore: unnecessary_statements
      controller;

      final bytes = await player.screenshot(format: 'image/jpeg');
      if (bytes == null || bytes.isEmpty) return null;

      await File(outPath).writeAsBytes(bytes, flush: true);
      await FinderIconService.applyIfWebM(videoPath, bytes);
      return outPath;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }
}
