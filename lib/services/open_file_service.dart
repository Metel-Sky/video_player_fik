import 'dart:async';

import 'package:flutter/services.dart';

class OpenFileService {
  OpenFileService._();

  static const _channel = MethodChannel('fik_player/open_files');
  static final _controller = StreamController<List<String>>.broadcast();
  static var _initialized = false;

  /// True once any external open (Finder / Open With) was received.
  /// Prevents last-folder restore from overwriting a new file.
  static var openedExternally = false;

  static final List<String> _buffered = [];
  static var _draining = false;

  static Stream<List<String>> get stream => _controller.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFilesAvailable' || call.method == 'openFiles') {
        // Drain native queue whenever macOS signals a new open.
        unawaited(drainAndEmit());
      }
    });
  }

  static Future<List<String>> _pullNativePending() async {
    try {
      final pending =
          await _channel.invokeMethod<List<dynamic>>('getPendingFiles');
      if (pending == null || pending.isEmpty) return const [];
      return pending.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  static List<String> _unique(List<String> paths) {
    final unique = <String>[];
    final seen = <String>{};
    for (final path in paths) {
      if (seen.add(path)) unique.add(path);
    }
    return unique;
  }

  /// Drain native + local buffers and emit to listeners (or keep buffered).
  static Future<List<String>> drainAndEmit() async {
    if (_draining) return const [];
    _draining = true;
    try {
      final paths = _unique([
        ..._buffered,
        ...await _pullNativePending(),
      ]);
      _buffered.clear();

      if (paths.isEmpty) return const [];

      openedExternally = true;
      if (_controller.hasListener) {
        _controller.add(paths);
      } else {
        _buffered.addAll(paths);
      }
      return paths;
    } finally {
      _draining = false;
    }
  }

  /// For app startup: take any launch files without relying on stream listeners.
  static Future<List<String>> takeLaunchFiles() async {
    final paths = _unique([
      ..._buffered,
      ...await _pullNativePending(),
    ]);
    _buffered.clear();
    if (paths.isNotEmpty) {
      openedExternally = true;
    }
    return paths;
  }

  static Future<void> dispose() async {
    await _controller.close();
  }
}
