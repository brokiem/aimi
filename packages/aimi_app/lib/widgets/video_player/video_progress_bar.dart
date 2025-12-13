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
  bool _isHovering = false;
  double? _hoverValue; // 0.0 to 1.0
  bool _isDragging = false;
  OverlayEntry? _tooltipOverlay;
  Duration? _dragDuration;

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _showTooltip(BuildContext context, Offset position, Duration time) {
    _removeTooltip();
    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx.clamp(0, MediaQuery.of(context).size.width - 50),
        top: position.dy - 40,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(formatDuration(time), style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_tooltipOverlay!);
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
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
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) {
            setState(() {
              _isHovering = false;
              _hoverValue = null;
            });
            _removeTooltip();
          },
          onHover: (event) {
            final box = context.findRenderObject() as RenderBox;
            final localPos = box.globalToLocal(event.position);
            final value = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
            setState(() => _hoverValue = value);

            final hoverDuration = Duration(milliseconds: (value * widget.duration.inMilliseconds).toInt());
            final hoverPosition = Offset(localPos.dx, box.size.height / 2);
            final globalPos = box.localToGlobal(hoverPosition);
            _showTooltip(context, globalPos, hoverDuration);
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onHorizontalDragStart: (details) {
              setState(() {
                _isDragging = true;
                _dragDuration = _durationFromDx(details.localPosition.dx, constraints.maxWidth);
              });
              widget.onDragStart?.call(widget.position);
              widget.onDragUpdate?.call(_dragDuration!);

              // Show tooltip
              final box = context.findRenderObject() as RenderBox;
              final hoverPosition = Offset(details.localPosition.dx, box.size.height / 2);
              final globalPos = box.localToGlobal(hoverPosition);
              _showTooltip(context, globalPos, _dragDuration!);
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragDuration = _durationFromDx(details.localPosition.dx, constraints.maxWidth);
                final value = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                _hoverValue = value;
              });
              widget.onDragUpdate?.call(_dragDuration!);

              // Update tooltip
              final box = context.findRenderObject() as RenderBox;
              final hoverPosition = Offset(details.localPosition.dx, box.size.height / 2);
              final globalPos = box.localToGlobal(hoverPosition);
              _showTooltip(context, globalPos, _dragDuration!);
            },
            onHorizontalDragEnd: (details) {
              if (_dragDuration != null) {
                widget.onSeek(_dragDuration!);
              }
              setState(() {
                _isDragging = false;
                _dragDuration = null;
              });
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
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 4), // Visual bar height
                  painter: _ProgressBarPainter(
                    position: _dragDuration ?? widget.position,
                    duration: widget.duration,
                    buffer: widget.buffer,
                    hoverValue: _hoverValue,
                    isHovering: _isHovering || _isDragging,
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

  @override
  void paint(Canvas canvas, Size size) {
    if (duration.inMilliseconds == 0) return;

    final double totalMs = duration.inMilliseconds.toDouble();
    final double positionValue = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final double bufferValue = (buffer.inMilliseconds / totalMs).clamp(0.0, 1.0);

    final Paint bgPaint = Paint()..color = backgroundColor;
    final Paint bufferPaint = Paint()..color = bufferedColor;
    final Paint progressPaint = Paint()..color = progressColor;
    final Paint hoverPaint = Paint()..color = hoverColor;

    final RRect fullRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );

    // 1. Draw Background
    canvas.drawRRect(fullRRect, bgPaint);

    // Clip further drawing to the rounded rectangle to ensure corners are rounded.
    canvas.clipRRect(fullRRect);

    // 2. Draw Buffer
    final double bufferWidth = size.width * bufferValue;
    final Rect bufferRect = Rect.fromLTWH(0, 0, bufferWidth, size.height);
    canvas.drawRect(bufferRect, bufferPaint);

    // 3. Draw Hover (Gray highlight)
    if (isHovering && hoverValue != null) {
      final double hoverWidth = size.width * hoverValue!;
      if (hoverValue! > positionValue) {
        final Rect hoverRect = Rect.fromLTWH(0, 0, hoverWidth, size.height);
        canvas.drawRect(hoverRect, hoverPaint);
      }
    }

    // 4. Draw Progress
    final double progressWidth = size.width * positionValue;
    final Rect progressRect = Rect.fromLTWH(0, 0, progressWidth, size.height);
    canvas.drawRect(progressRect, progressPaint);

    // 5. Draw Thumb (Circle)
    if (isHovering && hoverValue != null) {
      final double thumbX = size.width * hoverValue!;
      final double thumbRadius = 6.0;
      canvas.drawCircle(Offset(thumbX, size.height / 2), thumbRadius, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return position != oldDelegate.position ||
        duration != oldDelegate.duration ||
        buffer != oldDelegate.buffer ||
        hoverValue != oldDelegate.hoverValue ||
        isHovering != oldDelegate.isHovering;
  }
}
