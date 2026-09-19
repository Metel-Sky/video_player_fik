class PlaylistItem {
  PlaylistItem({
    required this.path,
    required this.title,
    this.thumbPath,
  });

  final String path;
  final String title;
  String? thumbPath;

  PlaylistItem copyWith({
    String? path,
    String? title,
    String? thumbPath,
  }) {
    return PlaylistItem(
      path: path ?? this.path,
      title: title ?? this.title,
      thumbPath: thumbPath ?? this.thumbPath,
    );
  }
}
