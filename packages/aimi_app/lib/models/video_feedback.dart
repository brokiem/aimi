enum FeedbackType { quality, speed, audio, subtitle }

class VideoFeedbackEvent {
  final FeedbackType type;
  final String label;

  VideoFeedbackEvent(this.type, this.label);
}
