import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/natural_sort.dart';
import '../utils/video_extensions.dart';
import 'playlist_item.dart';

List<PlaylistItem> scanFolderForVideos(String folderPath) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return const [];
  }

  final items = <PlaylistItem>[];
  for (final entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path;
    if (!isVideoPath(path)) continue;
    items.add(
      PlaylistItem(
        path: path,
        title: p.basename(path),
      ),
    );
  }

  items.sort((a, b) => naturalCompare(a.title, b.title));
  return items;
}

List<PlaylistItem> playlistForFile(String filePath) {
  final folder = p.dirname(filePath);
  final items = scanFolderForVideos(folder);
  if (items.isEmpty && isVideoPath(filePath)) {
    return [
      PlaylistItem(path: filePath, title: p.basename(filePath)),
    ];
  }
  return items;
}

int indexOfPath(List<PlaylistItem> items, String filePath) {
  final normalized = p.normalize(filePath);
  return items.indexWhere((item) => p.normalize(item.path) == normalized);
}
