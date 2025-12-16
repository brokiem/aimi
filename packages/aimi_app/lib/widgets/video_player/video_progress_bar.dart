import 'package:aimi_app/utils/duration_formatter.dart';
import 'package:flutter/material.dart';

class VideoProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration>? onDragStart;
  final ValueChanged<Duration>? onDragUpdate;
  final ValueChanged<Duration>? onDragEnd;
  final Color? bufferedColor;
  final Color? progressColor;
  final Color? backgroundColor;
  final Color? hoverColor;

  const VideoProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.onSeek,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.bufferedColor,
    this.progressColor,
    this.backgroundColor,
    this.hoverColor,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  // Use ValueNotifiers to avoid rebuilding entire widget tree
  final ValueNotifier<bool> _isHovering = ValueNotifier(false);
  final ValueNotifier<double?> _hoverValue = ValueNotifier(null);
  final ValueNotifier<bool> _isDragging = ValueNotifier(false);
  final ValueNotifier<Duration?> _dragDuration = ValueNotifier(null);

  OverlayEntry? _tooltipOverlay;
  final ValueNotifier<Offset> _tooltipPosition = ValueNotifier(Offset.zero);
  final ValueNotifier<Duration> _tooltipDuration = ValueNotifier(Duration.zero);

  // Cache render box to avoid repeated lookups
  RenderBox? _cachedRenderBox;

  @override
  void dispose() {
    _removeTooltip();
    _isHovering.dispose();
    _hoverValue.dispose();
    _isDragging.dispose();
    _dragDuration.dispose();
    _tooltipPosition.dispose();
    _tooltipDuration.dispose();
    super.dispose();
  }

  RenderBox? _getRenderBox(BuildContext context) {
    _cachedRenderBox ??= context.findRenderObject() as RenderBox?;
    return _cachedRenderBox;
  }

  void _showOrUpdateTooltip(BuildContext context, Offset position, Duration time) {
    _tooltipPosition.value = position;
    _tooltipDuration.value = time;

    if (_tooltipOverlay != null) return; // Already showing, just update notifiers

    _tooltipOverlay = OverlayEntry(
      builder: (overlayContext) => ValueListenableBuilder<Offset>(
        valueListenable: _tooltipPosition,
        builder: (_, pos, __) => ValueListenableBuilder<Duration>(
          valueListenable: _tooltipDuration,
          builder: (_, dur, __) => Positioned(
            left: pos.dx.clamp(0, MediaQuery.of(overlayContext).size.width - 50),
            top: pos.dy - 45,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(formatDuration(dur), style: Theme.of(overlayContext).textTheme.bodySmall),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_tooltipOverlay!);
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay?.dispose();
    _tooltipOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final resolvedProgressColor = widget.progressColor ?? colorScheme.primary;
    final resolvedBackgroundColor = widget.backgroundColor ?? colorScheme.onSurface.withAlpha((255 * 0.24).round());
    final resolvedBufferedColor = widget.bufferedColor ?? colorScheme.onSurface.withAlpha((255 * 0.38).round());
    final resolvedHoverColor = widget.hoverColor ?? colorScheme.onSurface.withAlpha((255 * 0.60).round());

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reset cached render box when layout changes
        _cachedRenderBox = null;

        return MouseRegion(
          onEnter: (_) => _isHovering.value = true,
          onExit: (_) {
            _isHovering.value = false;
            _hoverValue.value = null;
            _removeTooltip();
          },
          onHover: (event) {
            final box = _getRenderBox(context);
            if (box == null) return;

            final localPos = box.globalToLocal(event.position);
            final value = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
            _hoverValue.value = value;

            final hoverDuration = Duration(milliseconds: (value * widget.duration.inMilliseconds).toInt());
            final hoverPosition = Offset(localPos.dx, box.size.height / 2);
            final globalPos = box.localToGlobal(hoverPosition);
            _showOrUpdateTooltip(context, globalPos, hoverDuration);
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onHorizontalDragStart: (details) {
              _isDragging.value = true;
              final duration = _durationFromDx(details.localPosition.dx, constraints.maxWidth);
              _dragDuration.value = duration;
              _hoverValue.value = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);

              widget.onDragStart?.call(widget.position);
              widget.onDragUpdate?.call(duration);

              final box = _getRenderBox(context);
              if (box != null) {
                final hoverPosition = Offset(details.localPosition.dx, box.size.height / 2);
                final globalPos = box.localToGlobal(hoverPosition);
                _showOrUpdateTooltip(context, globalPos, duration);
              }
            },
            onHorizontalDragUpdate: (details) {
              final duration = _durationFromDx(details.localPosition.dx, constraints.maxWidth);
              _dragDuration.value = duration;
              _hoverValue.value = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);

              widget.onDragUpdate?.call(duration);

              final box = _getRenderBox(context);
              if (box != null) {
                final hoverPosition = Offset(details.localPosition.dx, box.size.height / 2);
                final globalPos = box.localToGlobal(hoverPosition);
                _showOrUpdateTooltip(context, globalPos, duration);
              }
            },
            onHorizontalDragEnd: (details) {
              final duration = _dragDuration.value;
              if (duration != null) {
                widget.onSeek(duration);
              }
              _isDragging.value = false;
              _dragDuration.value = null;
              widget.onDragEnd?.call(widget.position);
              _removeTooltip();
            },
            onTapDown: (details) {
              final dur = _durationFromDx(details.localPosition.dx, constraints.maxWidth);
              widget.onSeek(dur);
            },
            child: Container(
              height: 20, // Hit target height
              color: Colors.transparent,
              child: Center(
                child: RepaintBoundary(
                  child: _ProgressBarWidget(
                    width: constraints.maxWidth,
                    position: widget.position,
                    duration: widget.duration,
                    buffer: widget.buffer,
                    hoverValueNotifier: _hoverValue,
                    isHoveringNotifier: _isHovering,
                    isDraggingNotifier: _isDragging,
                    dragDurationNotifier: _dragDuration,
                    bufferedColor: resolvedBufferedColor,
                    progressColor: resolvedProgressColor,
                    backgroundColor: resolvedBackgroundColor,
                    hoverColor: resolvedHoverColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Duration _durationFromDx(double dx, double width) {
    final value = (dx / width).clamp(0.0, 1.0);
    final ms = (value * widget.duration.inMilliseconds).toInt();
    return Duration(milliseconds: ms);
  }
}

/// Separate widget that listens to ValueNotifiers to minimize rebuilds
class _ProgressBarWidget extends StatelessWidget {
  final double width;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final ValueNotifier<double?> hoverValueNotifier;
  final ValueNotifier<bool> isHoveringNotifier;
  final ValueNotifier<bool> isDraggingNotifier;
  final ValueNotifier<Duration?> dragDurationNotifier;
  final Color bufferedColor;
  final Color progressColor;
  final Color backgroundColor;
  final Color hoverColor;

  const _ProgressBarWidget({
    required this.width,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.hoverValueNotifier,
    required this.isHoveringNotifier,
    required this.isDraggingNotifier,
    required this.dragDurationNotifier,
    required this.bufferedColor,
    required this.progressColor,
    required this.backgroundColor,
    required this.hoverColor,
  });

  @override
  Widget build(BuildContext context) {
    // Show indeterminate progress bar when duration is not yet loaded
    if (duration.inMilliseconds == 0) {
      return SizedBox(
        width: width,
        height: 4,
        child: LinearProgressIndicator(
          backgroundColor: backgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([hoverValueNotifier, isHoveringNotifier, isDraggingNotifier, dragDurationNotifier]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(width, 4), // Visual bar height
          painter: _ProgressBarPainter(
            position: dragDurationNotifier.value ?? position,
            duration: duration,
            buffer: buffer,
            hoverValue: hoverValueNotifier.value,
            isHovering: isHoveringNotifier.value || isDraggingNotifier.value,
            bufferedColor: bufferedColor,
            progressColor: progressColor,
            backgroundColor: backgroundColor,
            hoverColor: hoverColor,
          ),
        );
      },
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final double? hoverValue;
  final bool isHovering;

  final Color bufferedColor;
  final Color progressColor;
  final Color backgroundColor;
  final Color hoverColor;

  // Cache paints for reuse
  static final Map<Color, Paint> _paintCache = {};

  _ProgressBarPainter({
    required this.position,
    required this.duration,
    required this.buffer,
    required this.hoverValue,
    required this.isHovering,
    required this.bufferedColor,
    required this.progressColor,
    required this.backgroundColor,
    required this.hoverColor,
  });

  Paint _getPaint(Color color) {
    return _paintCache.putIfAbsent(color, () => Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double totalMs = duration.inMilliseconds.toDouble();
    final double positionValue = totalMs == 0 ? 0.0 : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final double bufferValue = totalMs == 0 ? 0.0 : (buffer.inMilliseconds / totalMs).clamp(0.0, 1.0);

    final bgPaint = _getPaint(backgroundColor);
    final bufferPaint = _getPaint(bufferedColor);
    final progressPaint = _getPaint(progressColor);
    final hoverPaint = _getPaint(hoverColor);

    final radius = Radius.circular(size.height / 2);
    final RRect fullRRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), radius);

    // 1. Draw Background
    canvas.drawRRect(fullRRect, bgPaint);

    // Save canvas state before clipping
    canvas.save();
    canvas.clipRRect(fullRRect);

    // 2. Draw Buffer
    final double bufferWidth = size.width * bufferValue;
    canvas.drawRect(Rect.fromLTWH(0, 0, bufferWidth, size.height), bufferPaint);

    // 3. Draw Hover (Gray highlight)
    if (isHovering && hoverValue != null && hoverValue! > positionValue) {
      final double hoverWidth = size.width * hoverValue!;
      canvas.drawRect(Rect.fromLTWH(0, 0, hoverWidth, size.height), hoverPaint);
    }

    // 4. Draw Progress
    final double progressWidth = size.width * positionValue;
    canvas.drawRect(Rect.fromLTWH(0, 0, progressWidth, size.height), progressPaint);

    // Restore canvas state
    canvas.restore();

    // 5. Draw Thumb (Circle) at progress position - outside clip to ensure full circle is visible
    final double thumbX = size.width * positionValue;
    canvas.drawCircle(Offset(thumbX, size.height / 2), 6.0, progressPaint);

    // 6. Draw Hover Thumb if hovering or dragging
    if (isHovering && hoverValue != null) {
      final double hoverThumbX = size.width * hoverValue!;
      canvas.drawCircle(Offset(hoverThumbX, size.height / 2), 6.0, hoverPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return position != oldDelegate.position ||
        duration != oldDelegate.duration ||
        buffer != oldDelegate.buffer ||
        hoverValue != oldDelegate.hoverValue ||
        isHovering != oldDelegate.isHovering ||
        bufferedColor != oldDelegate.bufferedColor ||
        progressColor != oldDelegate.progressColor ||
        backgroundColor != oldDelegate.backgroundColor ||
        hoverColor != oldDelegate.hoverColor;
  }
}
