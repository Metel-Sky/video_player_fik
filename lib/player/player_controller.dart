import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../playlist/folder_playlist.dart';
import '../playlist/playlist_item.dart';
import '../playlist/thumbnail_service.dart';
import '../utils/natural_sort.dart';
import '../utils/video_extensions.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({ThumbnailService? thumbnails})
      : thumbnailService = thumbnails ?? ThumbnailService() {
    player = Player();
    videoController = VideoController(player);
    _subs.add(player.stream.playing.listen((value) {
      playing = value;
      notifyListeners();
    }));
    _subs.add(player.stream.position.listen((value) {
      position = value;
      notifyListeners();
    }));
    _subs.add(player.stream.duration.listen((value) {
      duration = value;
      notifyListeners();
    }));
    _subs.add(player.stream.tracks.listen((tracks) {
      _availableSubtitles = tracks.subtitle
          .where((t) => t.id != 'no' && t.id != 'auto')
          .toList();
      notifyListeners();
    }));
    _subs.add(player.stream.completed.listen((done) {
      if (!done || _ignoreCompleted) return;
      if (hasNext) {
        unawaited(playNext());
      }
    }));
    _subs.add(player.stream.volume.listen((value) {
      volume = value;
      notifyListeners();
    }));
    thumbnailService.addListener(_onThumbReady);
  }

  late final Player player;
  late final VideoController videoController;
  final ThumbnailService thumbnailService;

  final _subs = <StreamSubscription<dynamic>>[];
  var _ignoreCompleted = false;

  List<PlaylistItem> playlist = [];
  int currentIndex = -1;
  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playlistVisible = true;
  bool subtitlesEnabled = true;
  bool seekPreviewEnabled = true;
  bool hasSubtitles = false;
  double volume = 100;
  bool muted = false;
  double _volumeBeforeMute = 100;
  List<SubtitleTrack> _availableSubtitles = [];

  String? get currentPath =>
      currentIndex >= 0 && currentIndex < playlist.length
          ? playlist[currentIndex].path
          : null;

  String? get currentTitle =>
      currentIndex >= 0 && currentIndex < playlist.length
          ? playlist[currentIndex].title
          : null;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    playlistVisible = prefs.getBool('playlist_visible') ?? true;
    subtitlesEnabled = prefs.getBool('subtitles_enabled') ?? true;
    seekPreviewEnabled = prefs.getBool('seek_preview_enabled') ?? true;
    volume = prefs.getDouble('volume') ?? 100;
    muted = prefs.getBool('muted') ?? false;
    _volumeBeforeMute = volume <= 0 ? 100 : volume;
    await player.setVolume(muted ? 0 : volume);
    notifyListeners();
  }

  Future<void> restoreLastFolder() async {
    final prefs = await SharedPreferences.getInstance();
    final folder = prefs.getString('last_folder');
    if (folder == null || folder.isEmpty) return;
    final dir = Directory(folder);
    if (!dir.existsSync()) return;
    final items = scanFolderForVideos(folder);
    await _setPlaylist(
      items,
      startIndex: items.isEmpty ? -1 : 0,
      autoplay: false,
    );
  }

  Future<void> _rememberFolder(String folderPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_folder', folderPath);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('playlist_visible', playlistVisible);
    await prefs.setBool('subtitles_enabled', subtitlesEnabled);
    await prefs.setBool('seek_preview_enabled', seekPreviewEnabled);
    await prefs.setDouble('volume', muted ? _volumeBeforeMute : volume);
    await prefs.setBool('muted', muted);
  }

  void _onThumbReady(String path, String thumbPath) {
    final index = playlist.indexWhere((item) => item.path == path);
    if (index < 0) return;
    playlist[index] = playlist[index].copyWith(thumbPath: thumbPath);
    notifyListeners();
  }

  Future<void> openFolder(String folderPath) async {
    final items = scanFolderForVideos(folderPath);
    await _setPlaylist(items, startIndex: items.isEmpty ? -1 : 0);
    await _rememberFolder(folderPath);
  }

  Future<void> openFile(String filePath) async {
    if (!isVideoPath(filePath) && !FileSystemEntity.isDirectorySync(filePath)) {
      return;
    }
    if (FileSystemEntity.isDirectorySync(filePath)) {
      await openFolder(filePath);
      return;
    }
    final items = playlistForFile(filePath);
    var index = indexOfPath(items, filePath);
    if (index < 0 && isVideoPath(filePath)) {
      items.insert(
        0,
        PlaylistItem(path: filePath, title: p.basename(filePath)),
      );
      index = 0;
    }
    await _setPlaylist(items, startIndex: index < 0 ? 0 : index);
    await _rememberFolder(p.dirname(filePath));
  }

  Future<void> openPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final first = paths.first;
    if (paths.length == 1) {
      await openFile(first);
      return;
    }
    final videos = paths.where(isVideoPath).toList()
      ..sort((a, b) => naturalCompare(p.basename(a), p.basename(b)));
    if (videos.isEmpty) {
      await openFile(first);
      return;
    }
    final items = videos
        .map((path) => PlaylistItem(path: path, title: p.basename(path)))
        .toList();
    await _setPlaylist(items, startIndex: 0);
    await _rememberFolder(p.dirname(videos.first));
  }

  Future<void> _setPlaylist(
    List<PlaylistItem> items, {
    required int startIndex,
    bool autoplay = true,
  }) async {
    playlist = List<PlaylistItem>.from(items);
    currentIndex = startIndex;
    // Paint playlist UI immediately; don't wait for thumbs / demux.
    notifyListeners();

    unawaited(_hydrateThumbnails());

    if (currentIndex >= 0 && currentIndex < playlist.length) {
      try {
        await _playIndex(currentIndex, autoplay: autoplay);
      } catch (e, st) {
        debugPrint('Failed to open media: $e\n$st');
      }
    } else {
      try {
        await player.stop();
      } catch (_) {}
      hasSubtitles = false;
      await windowManager.setTitle('Fik Player');
      notifyListeners();
    }
  }

  Future<void> _hydrateThumbnails() async {
    try {
      for (var i = 0; i < playlist.length; i++) {
        final cached = await thumbnailService.cachedPathFor(playlist[i].path);
        if (cached != null) {
          playlist[i] = playlist[i].copyWith(thumbPath: cached);
        }
      }
      notifyListeners();
      // Defer generation so first open isn't competing with many Players.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (playlist.isEmpty) return;
      thumbnailService.enqueueAll(playlist.map((e) => e.path));
    } catch (e, st) {
      debugPrint('Thumbnail hydrate failed: $e\n$st');
    }
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= playlist.length) return;
    await _playIndex(index);
  }

  /// Renames the video file (and matching sidecar subtitles) on disk.
  /// [newFileName] is the visible basename, with or without extension.
  /// Returns an error message, or null on success.
  Future<String?> renamePlaylistItem(int index, String newFileName) async {
    if (index < 0 || index >= playlist.length) return 'Video not found';

    final item = playlist[index];
    final oldPath = item.path;
    final dir = p.dirname(oldPath);
    final oldExt = p.extension(oldPath);
    var name = newFileName.trim();
    if (name.isEmpty) return 'Name cannot be empty';
    if (name.contains('/') || name.contains('\\') || name.contains('\u0000')) {
      return 'Name contains invalid characters';
    }
    if (name == '.' || name == '..') return 'Invalid name';
    if (p.extension(name).isEmpty && oldExt.isNotEmpty) {
      name = '$name$oldExt';
    }

    final newPath = p.join(dir, name);
    if (p.equals(oldPath, newPath)) return null;
    if (File(newPath).existsSync()) {
      return 'A file with this name already exists';
    }

    final wasCurrent = index == currentIndex;
    final wasPlaying = playing;
    final resumeAt = position;

    Future<void> closeForRename() async {
      try {
        await player.stop();
      } catch (_) {}
    }

    Future<void> doRename() async {
      await File(oldPath).rename(newPath);
      _renameSidecarSubtitles(oldPath, newPath);
    }

    try {
      try {
        await doRename();
      } on FileSystemException {
        if (!wasCurrent) rethrow;
        await closeForRename();
        await doRename();
      }
    } on FileSystemException catch (e) {
      if (wasCurrent) {
        try {
          await _playIndex(index, autoplay: wasPlaying);
          if (resumeAt > Duration.zero) await player.seek(resumeAt);
        } catch (_) {}
      }
      return e.message.isEmpty ? 'Could not rename the file' : e.message;
    } catch (e) {
      return e.toString();
    }

    playlist[index] = item.copyWith(
      path: newPath,
      title: p.basename(newPath),
    );
    playlist.sort((a, b) => naturalCompare(a.title, b.title));
    currentIndex = playlist.indexWhere(
      (entry) => p.equals(entry.path, newPath),
    );
    notifyListeners();

    if (wasCurrent && currentIndex >= 0) {
      try {
        await _playIndex(currentIndex, autoplay: wasPlaying);
        if (resumeAt > Duration.zero) await player.seek(resumeAt);
      } catch (e, st) {
        debugPrint('Failed to reopen renamed media: $e\n$st');
      }
    }

    return null;
  }

  void _renameSidecarSubtitles(String oldVideoPath, String newVideoPath) {
    final dir = p.dirname(oldVideoPath);
    final oldStem = p.basenameWithoutExtension(oldVideoPath);
    final newStem = p.basenameWithoutExtension(newVideoPath);
    for (final ext in const ['.srt', '.vtt', '.ass', '.ssa']) {
      final from = File(p.join(dir, '$oldStem$ext'));
      if (!from.existsSync()) continue;
      final to = p.join(dir, '$newStem$ext');
      if (File(to).existsSync()) continue;
      try {
        from.renameSync(to);
      } catch (_) {}
    }
  }

  bool get hasPrevious => currentIndex > 0;

  bool get hasNext =>
      currentIndex >= 0 && currentIndex < playlist.length - 1;

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    await _playIndex(currentIndex - 1);
  }

  Future<void> playNext() async {
    if (!hasNext) return;
    await _playIndex(currentIndex + 1);
  }

  Future<void> _playIndex(int index, {bool autoplay = true}) async {
    _ignoreCompleted = true;
    currentIndex = index;
    final item = playlist[index];
    try {
      await player.open(Media(item.path), play: autoplay);
      await windowManager.setTitle(item.title);
      await _applySubtitlesForCurrent();
      notifyListeners();
    } finally {
      // Drop EOF from the previous file that can arrive during open().
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _ignoreCompleted = false;
      });
    }
  }

  Future<void> playPause() async {
    await player.playOrPause();
  }

  Future<void> seekBy(Duration delta) async {
    var target = position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await player.seek(target);
  }

  Future<void> seekTo(Duration value) async {
    await player.seek(value);
  }

  Future<void> togglePlaylistVisible() async {
    playlistVisible = !playlistVisible;
    notifyListeners();
    await _persist();
  }

  Future<void> setPlaylistVisible(bool value) async {
    if (playlistVisible == value) return;
    playlistVisible = value;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleSubtitles() async {
    subtitlesEnabled = !subtitlesEnabled;
    await _applySubtitleTrack();
    notifyListeners();
    await _persist();
  }

  Future<void> toggleSeekPreview() async {
    seekPreviewEnabled = !seekPreviewEnabled;
    notifyListeners();
    await _persist();
  }

  Future<void> setVolume(double value, {bool persist = false}) async {
    final next = value.clamp(0, 100).toDouble();
    volume = next;
    if (next > 0) {
      muted = false;
      _volumeBeforeMute = next;
    } else {
      muted = true;
    }
    await player.setVolume(muted ? 0 : next);
    notifyListeners();
    if (persist) await _persist();
  }

  Future<void> toggleMute() async {
    if (muted) {
      muted = false;
      final restore = _volumeBeforeMute <= 0 ? 100.0 : _volumeBeforeMute;
      volume = restore;
      await player.setVolume(restore);
    } else {
      _volumeBeforeMute = volume <= 0 ? 100 : volume;
      muted = true;
      await player.setVolume(0);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _applySubtitlesForCurrent() async {
    final path = currentPath;
    if (path == null) {
      hasSubtitles = false;
      return;
    }

    // Wait for embedded tracks to populate.
    for (var i = 0; i < 20; i++) {
      if (player.state.tracks.subtitle.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    _availableSubtitles = player.state.tracks.subtitle
        .where((t) => t.id != 'no' && t.id != 'auto')
        .toList();

    final external = _findExternalSubtitle(path);
    if (external != null) {
      await player.setSubtitleTrack(
        SubtitleTrack.uri(Uri.file(external).toString()),
      );
      hasSubtitles = true;
    } else {
      hasSubtitles = _availableSubtitles.isNotEmpty;
      if (hasSubtitles && subtitlesEnabled) {
        await player.setSubtitleTrack(SubtitleTrack.auto());
      }
    }

    await _applySubtitleTrack();
  }

  String? _findExternalSubtitle(String videoPath) {
    final dir = p.dirname(videoPath);
    final stem = p.basenameWithoutExtension(videoPath);
    for (final ext in const ['.srt', '.vtt', '.ass', '.ssa']) {
      final candidate = p.join(dir, '$stem$ext');
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  Future<void> _applySubtitleTrack() async {
    if (!subtitlesEnabled) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    final path = currentPath;
    if (path == null) return;

    final external = _findExternalSubtitle(path);
    if (external != null) {
      await player.setSubtitleTrack(
        SubtitleTrack.uri(Uri.file(external).toString()),
      );
      hasSubtitles = true;
      return;
    }

    if (_availableSubtitles.isNotEmpty) {
      await player.setSubtitleTrack(SubtitleTrack.auto());
      hasSubtitles = true;
    } else {
      hasSubtitles = false;
    }
  }

  @override
  void dispose() {
    thumbnailService.removeListener(_onThumbReady);
    for (final sub in _subs) {
      sub.cancel();
    }
    player.dispose();
    super.dispose();
  }
}
