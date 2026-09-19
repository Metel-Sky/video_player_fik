import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../player/player_controller.dart';
import '../player/seek_preview_service.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.controller,
  });

  final PlayerController controller;

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SeekPreviewBar(controller: controller),
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_format(controller.position)} / ${_format(controller.duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: controller.muted ? 'Unmute' : 'Mute',
                      onPressed: controller.toggleMute,
                      icon: Icon(
                        controller.muted || controller.volume <= 0
                            ? Icons.volume_off
                            : controller.volume < 50
                                ? Icons.volume_down
                                : Icons.volume_up,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white38,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: controller.muted ? 0 : controller.volume,
                          max: 100,
                          onChanged: (value) => controller.setVolume(value),
                          onChangeEnd: (value) =>
                              controller.setVolume(value, persist: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous video',
                    onPressed: controller.hasPrevious
                        ? controller.playPrevious
                        : null,
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: controller.hasPrevious
                          ? Colors.white
                          : Colors.white24,
                      size: 30,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Back 5 seconds',
                    onPressed: () =>
                        controller.seekBy(const Duration(seconds: -5)),
                    icon: const Icon(
                      Icons.replay_5,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: controller.playing ? 'Pause' : 'Play',
                    onPressed: controller.playPause,
                    icon: Icon(
                      controller.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Forward 5 seconds',
                    onPressed: () =>
                        controller.seekBy(const Duration(seconds: 5)),
                    icon: const Icon(
                      Icons.forward_5,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next video',
                    onPressed:
                        controller.hasNext ? controller.playNext : null,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color:
                          controller.hasNext ? Colors.white : Colors.white24,
                      size: 30,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: controller.subtitlesEnabled
                          ? 'Subtitles on'
                          : 'Subtitles off',
                      onPressed: controller.toggleSubtitles,
                      icon: Icon(
                        Icons.subtitles,
                        color: controller.subtitlesEnabled
                            ? Colors.white
                            : Colors.white38,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: controller.seekPreviewEnabled
                          ? 'Seek preview on'
                          : 'Seek preview off',
                      onPressed: controller.toggleSeekPreview,
                      icon: Icon(
                        Icons.preview,
                        color: controller.seekPreviewEnabled
                            ? Colors.white
                            : Colors.white38,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: controller.playlistVisible
                          ? 'Hide playlist'
                          : 'Show playlist',
                      onPressed: controller.togglePlaylistVisible,
                      icon: Icon(
                        controller.playlistVisible
                            ? Icons.view_sidebar
                            : Icons.view_sidebar_outlined,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SeekPreviewBar extends StatefulWidget {
  const SeekPreviewBar({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<SeekPreviewBar> createState() => _SeekPreviewBarState();
}

class _SeekPreviewBarState extends State<SeekPreviewBar> {
  static const _previewWidth = 160.0;
  static const _previewHeight = 90.0;
  static const _frameStep = 20;

  final _previewService = SeekPreviewService();
  final _barKey = GlobalKey();

  var _hovering = false;
  var _hoverX = 0.0;
  var _barWidth = 1.0;
  Duration _hoverTime = Duration.zero;
  Uint8List? _previewBytes;
  Timer? _idleTimer;
  var _requestId = 0;

  PlayerController get controller => widget.controller;

  @override
  void didUpdateWidget(covariant SeekPreviewBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!controller.seekPreviewEnabled && _hovering) {
      _idleTimer?.cancel();
      setState(() {
        _hovering = false;
        _previewBytes = null;
      });
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    unawaited(_previewService.dispose());
    super.dispose();
  }

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Duration _timeForLocalX(double localX, double width) {
    final duration = controller.duration;
    if (duration <= Duration.zero || width <= 0) return Duration.zero;
    final ratio = (localX / width).clamp(0.0, 1.0);
    return Duration(
      milliseconds: (duration.inMilliseconds * ratio).round(),
    );
  }

  void _onHover(PointerEvent event) {
    if (!controller.seekPreviewEnabled) {
      if (_hovering) {
        _idleTimer?.cancel();
        setState(() {
          _hovering = false;
          _previewBytes = null;
        });
      }
      return;
    }

    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (controller.duration <= Duration.zero || controller.currentPath == null) {
      return;
    }

    final localX = event.localPosition.dx.clamp(0.0, box.size.width);
    final exact = _timeForLocalX(localX, box.size.width);

    setState(() {
      _hovering = true;
      _hoverX = localX;
      _barWidth = box.size.width;
      _hoverTime = exact;
    });

    final fps = fpsFromPlayer(controller.player);
    final movingTarget = quantizeToEveryNthFrame(exact, fps, _frameStep);
    unawaited(_requestPreview(movingTarget));

    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 140), () {
      // Mouse stopped: show the exact frame under the cursor.
      unawaited(_requestPreview(exact));
    });
  }

  void _onExit(PointerEvent event) {
    _idleTimer?.cancel();
    setState(() {
      _hovering = false;
      _previewBytes = null;
    });
  }

  Future<void> _requestPreview(Duration at) async {
    final path = controller.currentPath;
    if (path == null) return;
    final id = ++_requestId;
    final bytes = await _previewService.capture(path, at);
    if (!mounted || id != _requestId || bytes == null) return;
    setState(() => _previewBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = controller.duration.inMilliseconds;
    final positionMs = controller.position.inMilliseconds.clamp(
      0,
      durationMs > 0 ? durationMs : 0,
    );

    final previewLeft = (_hoverX - _previewWidth / 2)
        .clamp(0.0, (_barWidth - _previewWidth).clamp(0.0, double.infinity));

    return SizedBox(
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_hovering)
            Positioned(
              left: previewLeft,
              bottom: 36,
              child: _PreviewCard(
                bytes: _previewBytes,
                timeLabel: _format(_hoverTime),
                width: _previewWidth,
                height: _previewHeight,
              ),
            ),
          MouseRegion(
            onHover: _onHover,
            onExit: _onExit,
            child: SizedBox(
              key: _barKey,
              height: 28,
              width: double.infinity,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white38,
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: durationMs == 0 ? 0 : positionMs.toDouble(),
                  max: durationMs == 0 ? 1 : durationMs.toDouble(),
                  onChanged: durationMs == 0
                      ? null
                      : (value) {
                          controller.seekTo(
                            Duration(milliseconds: value.round()),
                          );
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.bytes,
    required this.timeLabel,
    required this.width,
    required this.height,
  });

  final Uint8List? bytes;
  final String timeLabel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes == null
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                )
              : Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          timeLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class PlayerVideoArea extends StatelessWidget {
  const PlayerVideoArea({
    super.key,
    required this.controller,
    required this.showControls,
    this.onVideoTap,
  });

  final PlayerController controller;
  final bool showControls;
  final VoidCallback? onVideoTap;

  @override
  Widget build(BuildContext context) {
    final hasMedia = controller.currentPath != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: hasMedia
              ? Video(
                  controller: controller.videoController,
                  controls: NoVideoControls,
                  subtitleViewConfiguration: const SubtitleViewConfiguration(
                    style: TextStyle(
                      height: 1.3,
                      fontSize: 36,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(1, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Open a file or folder to start',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '⌘O  file   ·   ⇧⌘O  folder',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (hasMedia)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onVideoTap,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !showControls,
            child: AnimatedOpacity(
              opacity: showControls ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                child: PlayerControls(controller: controller),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
