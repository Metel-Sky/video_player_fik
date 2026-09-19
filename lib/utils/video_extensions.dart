const videoExtensions = <String>{
  '.mp4',
  '.mkv',
  '.mov',
  '.avi',
  '.webm',
  '.m4v',
  '.wmv',
  '.flv',
  '.ts',
  '.m2ts',
  '.mpg',
  '.mpeg',
  '.ogv',
  '.3gp',
};

bool isVideoPath(String path) {
  final lower = path.toLowerCase();
  return videoExtensions.any(lower.endsWith);
}
