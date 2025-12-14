import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/video_feedback.dart';
import 'video_progress_bar.dart';
import 'video_shortcut_feedback.dart';

// Keyboard shortcut constants
const _kSeekDuration = Duration(seconds: 5);
const _kVolumeStep = 10.0;

class VideoPlayerControls extends StatefulWidget {
  final VideoController controller;
  final String videoTitle;
  final VoidCallback onBack;
  final VoidCallback onSettingsPressed;
  final Stream<VideoFeedbackEvent> feedbackStream;
  final VoidCallback? onShowEpisodes;
  final bool bottomSafeArea;

  const VideoPlayerControls({
    super.key,
    required this.controller,
    required this.videoTitle,
    required this.onBack,
    required this.onSettingsPressed,
    required this.feedbackStream,
    this.onShowEpisodes,
    this.bottomSafeArea = true,
  });

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> with SingleTickerProviderStateMixin {
  bool _showControls = false;
  Timer? _hideTimer;
  bool _isFullscreen = false;
  double _lastVolume = 100.0;
  Duration? _draggingPosition;

  late AnimationController _playPauseAnimController;
  late FocusNode _focusNode;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<VideoFeedbackEvent>? _feedbackSubscription;

  // Internal feedback state (for fullscreen support)
  Widget? _feedbackIcon;
  String? _feedbackLabel;
  bool _feedbackVisible = false;
  Timer? _feedbackTimer;

  // Seek amount for double-tap gestures
  static const _seekDuration = Duration(seconds: 10);
  static const _doubleTapZoneRatio = 0.35;
  static const _doubleTapTimeout = Duration(milliseconds: 300);

  // For manual double-tap detection (avoids gesture arena delay)
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  bool get _isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _playPauseAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _focusNode = FocusNode();

    final player = widget.controller.player;
    if (player.state.playing) {
      _playPauseAnimController.forward();
      _startHideTimer();
    } else {
      _showControls = true;
    }

    _lastVolume = player.state.volume;
    if (_lastVolume == 0) _lastVolume = 100.0;

    // Store subscription for proper disposal
    _playingSubscription = player.stream.playing.listen((playing) {
      if (mounted) {
        if (playing) {
          _playPauseAnimController.forward();
          _startHideTimer();
        } else {
          _playPauseAnimController.reverse();
          setState(() => _showControls = true);
          _cancelHideTimer();
        }
      }
    });

    // Listen to feedback events from stream passed in widget
    _feedbackSubscription = widget.feedbackStream.listen(_handleFeedbackEvent);
  }

  @override
  void dispose() {
    _cancelHideTimer();
    _playingSubscription?.cancel();
    _feedbackSubscription?.cancel();
    _playPauseAnimController.dispose();
    _focusNode.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _handleFeedbackEvent(VideoFeedbackEvent event) {
    if (!mounted) return;

    IconData iconData;
    switch (event.type) {
      case FeedbackType.quality:
        iconData = Icons.high_quality;
        break;
      case FeedbackType.speed:
        iconData = Icons.speed;
        break;
      case FeedbackType.audio:
        iconData = Icons.audiotrack;
        break;
      case FeedbackType.subtitle:
        iconData = Icons.subtitles;
        break;
    }

    _showFeedback(Icon(iconData, color: Colors.white, size: 48), event.label);
  }

  /// Show feedback internally (works in fullscreen)
  void _showFeedback(Widget icon, [String? label]) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackIcon = icon;
      _feedbackLabel = label;
      _feedbackVisible = true;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _feedbackVisible = false);
      }
    });
  }

  /// Build seek icon for feedback
  Widget _buildSeekIcon({required bool isForward}) {
    return Icon(isForward ? Icons.forward_5 : Icons.replay_5, color: Colors.white, size: 48);
  }

  /// Handle keyboard shortcuts
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final player = widget.controller.player;
    final key = event.logicalKey;

    // Play/Pause
    if (key == LogicalKeyboardKey.space) {
      player.playOrPause();
      _showFeedback(Icon(player.state.playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 48));
      return KeyEventResult.handled;
    }

    // Mute/Unmute
    if (key == LogicalKeyboardKey.keyM) {
      final newVolume = player.state.volume > 0 ? 0.0 : 100.0;
      player.setVolume(newVolume);
      _showFeedback(Icon(newVolume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 48));
      return KeyEventResult.handled;
    }

    // Seek Left
    if (key == LogicalKeyboardKey.arrowLeft) {
      player.seek(player.state.position - _kSeekDuration);
      _showFeedback(_buildSeekIcon(isForward: false), '-${_kSeekDuration.inSeconds}s');
      return KeyEventResult.handled;
    }

    // Seek Right
    if (key == LogicalKeyboardKey.arrowRight) {
      player.seek(player.state.position + _kSeekDuration);
      _showFeedback(_buildSeekIcon(isForward: true), '+${_kSeekDuration.inSeconds}s');
      return KeyEventResult.handled;
    }

    // Volume Up
    if (key == LogicalKeyboardKey.arrowUp) {
      final newVol = (player.state.volume + _kVolumeStep).clamp(0.0, 100.0);
      player.setVolume(newVol);
      _showFeedback(const Icon(Icons.volume_up, color: Colors.white, size: 48), '${newVol.toInt()}%');
      return KeyEventResult.handled;
    }

    // Volume Down
    if (key == LogicalKeyboardKey.arrowDown) {
      final newVol = (player.state.volume - _kVolumeStep).clamp(0.0, 100.0);
      player.setVolume(newVol);
      _showFeedback(
        Icon(newVol == 0 ? Icons.volume_off : Icons.volume_down, color: Colors.white, size: 48),
        '${newVol.toInt()}%',
      );
      return KeyEventResult.handled;
    }

    // Escape fullscreen
    if (key == LogicalKeyboardKey.escape && _isFullscreen) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _startHideTimer({Duration duration = const Duration(milliseconds: 1500)}) {
    _cancelHideTimer();
    _hideTimer = Timer(duration, () {
      if (mounted && widget.controller.player.state.playing) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    } else {
      _cancelHideTimer();
    }
  }

  void _onUserInteraction() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    if (mounted) {
      toggleFullscreen(context);
      setState(() {
        _isFullscreen = !_isFullscreen;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  void _toggleMute() {
    final player = widget.controller.player;
    if (player.state.volume > 0) {
      _lastVolume = player.state.volume;
      player.setVolume(0);
    } else {
      player.setVolume(_lastVolume);
    }
    _onUserInteraction();
  }

  /// Seek backward and show feedback
  void _seekBackward() {
    final player = widget.controller.player;
    player.seek(player.state.position - _seekDuration);
    _showFeedback(const Icon(Icons.replay_10, color: Colors.white, size: 48), '-${_seekDuration.inSeconds}s');
  }

  /// Seek forward and show feedback
  void _seekForward() {
    final player = widget.controller.player;
    player.seek(player.state.position + _seekDuration);
    _showFeedback(const Icon(Icons.forward_10, color: Colors.white, size: 48), '+${_seekDuration.inSeconds}s');
  }

  /// Builds a play/pause feedback icon
  Widget _buildPlayPauseIcon(bool isPlaying) {
    return Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 48);
  }

  /// Unified tap handler with manual double-tap detection for immediate response
  void _handleTap(Offset tapPosition, Player player) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapTimeout &&
        _lastTapPosition != null &&
        (tapPosition - _lastTapPosition!).distance < 50;

    if (isDoubleTap && !_isDesktop) {
      // Double-tap on mobile: seek based on position
      _lastTapTime = null;
      _lastTapPosition = null;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;

      final width = box.size.width;
      final dx = tapPosition.dx;

      if (dx < width * _doubleTapZoneRatio) {
        _seekBackward();
      } else if (dx > width * (1 - _doubleTapZoneRatio)) {
        _seekForward();
      }
    } else {
      // Single tap
      _lastTapTime = now;
      _lastTapPosition = tapPosition;

      if (_isDesktop) {
        player.playOrPause();
        _showFeedback(_buildPlayPauseIcon(player.state.playing));
      } else {
        _toggleControls();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.controller.player;

    return MouseRegion(
      onEnter: (_) {
        if (_isDesktop) {
          setState(() => _showControls = true);
          _cancelHideTimer();
        }
      },
      onExit: (_) {
        if (_isDesktop) {
          // Hide immediately in 25ms
          _startHideTimer(duration: const Duration(milliseconds: 25));
        }
      },
      onHover: (_) {
        if (_isDesktop) {
          // Reset timer to 1.5s while moving
          _onUserInteraction();
        }
      },
      child: GestureDetector(
        onTapUp: (details) => _handleTap(details.localPosition, player),
        behavior: HitTestBehavior.translucent,
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) => _handleKeyEvent(event),
          child: Stack(
            children: [
              if (_showControls) Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.1))),
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Material(
                    color: Colors.transparent,
                    child: _isDesktop ? _buildDesktopLayout(context, player) : _buildMobileLayout(context, player),
                  ),
                ),
              ),
              // Internal feedback for fullscreen support
              Positioned.fill(
                child: Center(
                  child: VideoShortcutFeedback(visible: _feedbackVisible, icon: _feedbackIcon, label: _feedbackLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Player player) {
    return Column(
      children: [
        // Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.videoTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    _onUserInteraction();
                    widget.onSettingsPressed();
                  },
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Center Play/Pause
        Center(
          child: IconButton(
            iconSize: 64,
            icon: AnimatedIcon(icon: AnimatedIcons.play_pause, progress: _playPauseAnimController, color: Colors.white),
            onPressed: () {
              player.playOrPause();
              _onUserInteraction();
            },
          ),
        ),

        const Spacer(),

        // Bottom Bar (Mobile: Time & Fullscreen ABOVE seeker)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: widget.bottomSafeArea,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<Duration>(
                      stream: player.stream.position,
                      builder: (context, snapshot) {
                        final position = _draggingPosition ?? snapshot.data ?? Duration.zero;
                        final duration = player.state.duration;
                        return Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                ),
                StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = player.state.duration;
                    return StreamBuilder<Duration>(
                      stream: player.stream.buffer,
                      builder: (context, snapshotBuffer) {
                        final buffer = snapshotBuffer.data ?? Duration.zero;
                        return VideoProgressBar(
                          position: position,
                          duration: duration,
                          buffer: buffer,
                          onSeek: (pos) {
                            _onUserInteraction();
                            player.seek(pos);
                          },
                          onDragStart: (_) => _cancelHideTimer(),
                          onDragUpdate: (duration) => setState(() => _draggingPosition = duration),
                          onDragEnd: (_) {
                            setState(() => _draggingPosition = null);
                            _onUserInteraction();
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Player player) {
    return Column(
      children: [
        // Minimal Top Bar for Back button if needed, or just spacers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.videoTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Bottom Bar (Desktop: All buttons BELOW seeker)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<Duration>(
                stream: player.stream.position,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = player.state.duration;
                  return StreamBuilder<Duration>(
                    stream: player.stream.buffer,
                    builder: (context, snapshotBuffer) {
                      final buffer = snapshotBuffer.data ?? Duration.zero;
                      return VideoProgressBar(
                        position: position,
                        duration: duration,
                        buffer: buffer,
                        onSeek: (pos) {
                          _onUserInteraction();
                          player.seek(pos);
                        },
                        onDragStart: (_) => _cancelHideTimer(),
                        onDragUpdate: (duration) => setState(() => _draggingPosition = duration),
                        onDragEnd: (_) {
                          setState(() => _draggingPosition = null);
                          _onUserInteraction();
                        },
                      );
                    },
                  );
                },
              ),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(iconTheme: const IconThemeData(size: 28, color: Colors.white)), // Bigger buttons
                child: Row(
                  children: [
                    IconButton(
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _playPauseAnimController,
                        color: Colors.white,
                      ),
                      onPressed: player.playOrPause,
                    ),

                    // Volume Slider
                    _VolumeControl(
                      volumeStream: player.stream.volume,
                      onVolumeChanged: (val) {
                        _onUserInteraction();
                        player.setVolume(val);
                        if (val > 0) _lastVolume = val;
                      },
                      onMute: _toggleMute,
                    ),
                    const SizedBox(width: 16),
                    StreamBuilder<Duration>(
                      stream: player.stream.position,
                      builder: (context, snapshot) {
                        final position = _draggingPosition ?? snapshot.data ?? Duration.zero;
                        final duration = player.state.duration;
                        return Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        _onUserInteraction();
                        widget.onSettingsPressed();
                      },
                    ),
                    if (widget.onShowEpisodes != null)
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted, color: Colors.white), // or grid_view
                        tooltip: 'Episodes',
                        onPressed: () {
                          _onUserInteraction();
                          widget.onShowEpisodes!();
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VolumeControl extends StatefulWidget {
  final Stream<double> volumeStream;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMute;

  const _VolumeControl({required this.volumeStream, required this.onVolumeChanged, required this.onMute});

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _isHovering = false;
  bool _isDragging = false;

  void _onEnter(_) => setState(() => _isHovering = true);

  void _onExit(_) => setState(() => _isHovering = false);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: StreamBuilder<double>(
        stream: widget.volumeStream,
        builder: (context, snapshot) {
          final volume = snapshot.data ?? 100.0;
          final showSlider = _isHovering || _isDragging;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                onPressed: widget.onMute,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: showSlider ? 100 : 0,
                height: 40,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: 100,
                    minWidth: 100,
                    alignment: Alignment.centerLeft,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: volume.clamp(0.0, 100.0),
                        min: 0.0,
                        max: 100.0,
                        onChangeStart: (_) => setState(() => _isDragging = true),
                        onChangeEnd: (_) => setState(() => _isDragging = false),
                        onChanged: (val) {
                          if (!_isDragging) setState(() => _isDragging = true);
                          widget.onVolumeChanged(val);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
