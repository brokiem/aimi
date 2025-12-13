import 'package:flutter/material.dart';

/// Displays visual feedback for video player shortcuts.
///
/// Shows an icon inside a circular background at the center,
/// with an optional text label displayed below.
/// Includes a bounce (scale) animation when becoming visible.
class VideoShortcutFeedback extends StatefulWidget {
  /// The icon to display inside the circle.
  final Widget? icon;

  /// Optional label text to display below the circle.
  final String? label;

  /// Whether the feedback is currently visible.
  final bool visible;

  // Pre-computed colors for performance
  static const _overlayColor = Color(0x99000000); // 60% opacity black

  const VideoShortcutFeedback({super.key, this.icon, this.label, required this.visible});

  @override
  State<VideoShortcutFeedback> createState() => _VideoShortcutFeedbackState();
}

class _VideoShortcutFeedbackState extends State<VideoShortcutFeedback> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    // Bounce effect: subtle overshoot and settle
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.08), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.visible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant VideoShortcutFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Restart animation if content changed while visible (for new feedback)
    final contentChanged = widget.icon != oldWidget.icon || widget.label != oldWidget.label;

    if (widget.visible && contentChanged) {
      // New feedback triggered - restart bounce from beginning
      _controller.forward(from: 0.0);
    } else if (widget.visible && !oldWidget.visible) {
      // Just became visible
      _controller.forward(from: 0.0);
    } else if (!widget.visible && oldWidget.visible) {
      // Hiding
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular icon container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: VideoShortcutFeedback._overlayColor, shape: BoxShape.circle),
              child: widget.icon ?? const SizedBox.shrink(),
            ),

            // Label below the circle
            if (widget.label != null && widget.label!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: VideoShortcutFeedback._overlayColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.label!,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
