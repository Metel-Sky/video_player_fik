import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../player/player_controller.dart';
import '../playlist/playlist_item.dart';

class PlaylistSidePanel extends StatefulWidget {
  const PlaylistSidePanel({
    super.key,
    required this.controller,
  });

  final PlayerController controller;

  @override
  State<PlaylistSidePanel> createState() => _PlaylistSidePanelState();
}

class _PlaylistSidePanelState extends State<PlaylistSidePanel> {
  final _renameController = TextEditingController();
  final _renameFocus = FocusNode();
  int? _editingIndex;
  var _ignoreFocusLoss = false;
  var _committing = false;

  PlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _renameFocus.addListener(_onRenameFocusChange);
    _renameFocus.onKeyEvent = _onRenameKey;
  }

  @override
  void dispose() {
    _renameFocus.removeListener(_onRenameFocusChange);
    _renameFocus.dispose();
    _renameController.dispose();
    super.dispose();
  }

  KeyEventResult _onRenameKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _cancelRename();
    return KeyEventResult.handled;
  }

  void _onRenameFocusChange() {
    if (_renameFocus.hasFocus || _ignoreFocusLoss || _editingIndex == null) {
      return;
    }
    unawaited(_commitRename());
  }

  void _startRename(int index, PlaylistItem item) {
    _ignoreFocusLoss = true;
    _renameController.text = item.title;
    _renameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: p.basenameWithoutExtension(item.title).length,
    );
    setState(() => _editingIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ignoreFocusLoss = false;
      _renameFocus.requestFocus();
    });
  }

  void _cancelRename() {
    _ignoreFocusLoss = true;
    _renameFocus.unfocus();
    setState(() => _editingIndex = null);
    _ignoreFocusLoss = false;
  }

  Future<void> _commitRename() async {
    final index = _editingIndex;
    if (index == null || _committing) return;
    _committing = true;
    _ignoreFocusLoss = true;
    final name = _renameController.text.trim();
    _renameFocus.unfocus();
    setState(() => _editingIndex = null);

    String? error;
    if (name.isNotEmpty) {
      error = await controller.renamePlaylistItem(index, name);
    }
    _committing = false;
    _ignoreFocusLoss = false;
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Path copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = controller.playlist;

    return Material(
      color: const Color(0xFF161616),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              'Playlist',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Open a folder to load videos',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = index == controller.currentIndex;
                      return _PlaylistTile(
                        item: item,
                        selected: selected,
                        editing: _editingIndex == index,
                        renameController: _renameController,
                        renameFocus: _renameFocus,
                        onTap: () => controller.playIndex(index),
                        onCopyPath: () => _copyPath(item.path),
                        onRename: () => _startRename(index, item),
                        onRenameSubmitted: _commitRename,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.item,
    required this.selected,
    required this.editing,
    required this.renameController,
    required this.renameFocus,
    required this.onTap,
    required this.onRename,
    required this.onCopyPath,
    required this.onRenameSubmitted,
  });

  final PlaylistItem item;
  final bool selected;
  final bool editing;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onCopyPath;
  final VoidCallback onRenameSubmitted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: editing ? null : onTap,
      child: Container(
        color: selected ? const Color(0xFF2A2A2A) : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
        child: Row(
          children: [
            _Thumb(path: item.thumbPath),
            const SizedBox(width: 10),
            Expanded(
              child: editing
                  ? TextField(
                      controller: renameController,
                      focusNode: renameFocus,
                      autofocus: true,
                      maxLines: 2,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      cursorColor: Colors.white70,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onRenameSubmitted(),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        filled: true,
                        fillColor: Color(0xFF0E0E0E),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                      ),
                    )
                  : Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
            ),
            _TileIconButton(
              tooltip: 'Rename',
              icon: Icons.drive_file_rename_outline,
              onPressed: editing ? onRenameSubmitted : onRename,
            ),
            _TileIconButton(
              tooltip: 'Copy path',
              icon: Icons.content_copy,
              onPressed: onCopyPath,
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIconButton extends StatelessWidget {
  const _TileIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: Colors.white54),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      splashRadius: 14,
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (path != null && File(path!).existsSync()) {
      child = Image.file(
        File(path!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
      );
    } else {
      child = const _ThumbPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(width: 72, height: 40, child: child),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2C2C2C),
      child: Center(
        child: Icon(Icons.movie_outlined, size: 18, color: Colors.white24),
      ),
    );
  }
}
