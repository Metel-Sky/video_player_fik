import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../player/player_controller.dart';
import '../services/open_file_service.dart';
import 'player_controls.dart';
import 'playlist_side_panel.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  var _showControls = true;
  var _dragging = false;
  Timer? _hideTimer;
  StreamSubscription<List<String>>? _openSub;

  PlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onController);
    _openSub = OpenFileService.stream.listen((paths) {
      OpenFileService.openedExternally = true;
      controller.openPaths(paths);
    });
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _openSub?.cancel();
    controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (controller.playing) {
        setState(() => _showControls = false);
      }
    });
  }

  void _revealControls() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _scheduleHide();
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp4',
        'mkv',
        'mov',
        'avi',
        'webm',
        'm4v',
        'wmv',
        'flv',
        'ts',
        'm2ts',
        'mpg',
        'mpeg',
        'ogv',
        '3gp',
      ],
    );
    final path = result?.files.single.path;
    if (path != null) {
      await controller.openFile(path);
    }
  }

  Future<void> _openFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Folder',
    );
    if (path != null) {
      await controller.openFolder(path);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      controller.playPause();
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (HardwareKeyboard.instance.isMetaPressed) {
        controller.playPrevious();
      } else {
        controller.seekBy(const Duration(seconds: -5));
      }
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (HardwareKeyboard.instance.isMetaPressed) {
        controller.playNext();
      } else {
        controller.seekBy(const Duration(seconds: 5));
      }
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP &&
        HardwareKeyboard.instance.isMetaPressed) {
      // handled via menu usually; keep as fallback
      controller.togglePlaylistVisible();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final content = DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        final paths = detail.files.map((f) => f.path).where((path) {
          return FileSystemEntity.isDirectorySync(path) ||
              File(path).existsSync();
        }).toList();
        await controller.openPaths(paths);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _revealControls(),
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PlayerVideoArea(
                      controller: controller,
                      showControls: _showControls,
                      onVideoTap: () {
                        controller.playPause();
                        _revealControls();
                      },
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: controller.playlistVisible ? 280 : 0,
                    child: ClipRect(
                      child: controller.playlistVisible
                          ? PlaylistSidePanel(controller: controller)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              if (_dragging)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.blueAccent.withValues(alpha: 0.18),
                    child: const Center(
                      child: Text(
                        'Drop video or folder',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Open File…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onSelected: _openFile,
            ),
            PlatformMenuItem(
              label: 'Open Folder…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
                shift: true,
              ),
              onSelected: _openFolder,
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: controller.playlistVisible
                  ? 'Hide Playlist'
                  : 'Show Playlist',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyL,
                meta: true,
              ),
              onSelected: controller.togglePlaylistVisible,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Playback',
          menus: [
            PlatformMenuItem(
              label: 'Play/Pause',
              shortcut: const SingleActivator(LogicalKeyboardKey.space),
              onSelected: controller.playPause,
            ),
            PlatformMenuItem(
              label: 'Back 5 Seconds',
              shortcut: const SingleActivator(LogicalKeyboardKey.arrowLeft),
              onSelected: () =>
                  controller.seekBy(const Duration(seconds: -5)),
            ),
            PlatformMenuItem(
              label: 'Forward 5 Seconds',
              shortcut: const SingleActivator(LogicalKeyboardKey.arrowRight),
              onSelected: () =>
                  controller.seekBy(const Duration(seconds: 5)),
            ),
            PlatformMenuItem(
              label: 'Previous Video',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.arrowLeft,
                meta: true,
              ),
              onSelected: controller.playPrevious,
            ),
            PlatformMenuItem(
              label: 'Next Video',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.arrowRight,
                meta: true,
              ),
              onSelected: controller.playNext,
            ),
            PlatformMenuItem(
              label: 'Toggle Subtitles',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
              ),
              onSelected: controller.toggleSubtitles,
            ),
          ],
        ),
      ],
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: content,
      ),
    );
  }
}
