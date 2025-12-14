import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/streaming_source.dart';
import '../models/video_feedback.dart';
import '../models/watch_history_entry.dart';
import '../services/preferences_service.dart';
import '../services/thumbnail_service.dart';
import '../services/watch_history_service.dart';

class VideoPlayerViewModel extends ChangeNotifier {
  List<StreamingSource> _sources;

  List<StreamingSource> get sources => _sources;

  String _episodeTitle;

  String get episodeTitle => _episodeTitle;

  final String animeTitle;

  // Watch history tracking
  final WatchHistoryService? _watchHistoryService;
  final PreferencesService? _preferencesService;
  final ThumbnailService? _thumbnailService;
  final int? animeId;

  String? _episodeId;

  String? get episodeId => _episodeId;

  String? _episodeNumber;

  String? get episodeNumber => _episodeNumber;

  String? _streamProviderName;

  String? get streamProviderName => _streamProviderName;

  final String? metadataProviderName;

  late final Player player;
  late final VideoController controller;

  int _currentSourceIndex = 0;
  bool _isDisposed = false;

  // Feedback stream
  final _feedbackController = StreamController<VideoFeedbackEvent>.broadcast();

  Stream<VideoFeedbackEvent> get feedbackStream => _feedbackController.stream;

  // Progress tracking
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<double>? _volumeSubscription;
  Timer? _volumeSaveDebounce;
  Duration _lastSavedPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  static const _saveInterval = Duration(seconds: 10);
  DateTime? _lastSaveTime;

  VideoPlayerViewModel({
    required List<StreamingSource> sources,
    required String episodeTitle,
    this.animeTitle = '',
    WatchHistoryService? watchHistoryService,
    PreferencesService? preferencesService,
    ThumbnailService? thumbnailService,
    this.animeId,
    String? episodeId,
    String? episodeNumber,
    String? streamProviderName,
    this.metadataProviderName,
  }) : _sources = sources,
       _episodeTitle = episodeTitle,
       _episodeId = episodeId,
       _episodeNumber = episodeNumber,
       _streamProviderName = streamProviderName,
       _watchHistoryService = watchHistoryService,
       _preferencesService = preferencesService,
       _thumbnailService = thumbnailService {
    _initialize();
  }

  Future<void> _initialize() async {
    player = Player(
      configuration: PlayerConfiguration(
        title: _getTitle(),
        ready: () {
          debugPrint('Player initialization complete');
        },
      ),
    );

    controller = VideoController(player);

    // Track duration changes
    _durationSubscription = player.stream.duration.listen((duration) {
      _currentDuration = duration;
    });

    // Track position for saving progress
    _positionSubscription = player.stream.position.listen(_onPositionChanged);

    if (sources.isNotEmpty) {
      _currentSourceIndex = _getBestQualityIndex();
      await _loadSource(sources[_currentSourceIndex]);

      // Load saved position after source is loaded
      await _loadSavedPosition();
    }

    // Restore volume
    await _loadSavedVolume();

    // Listen to volume changes
    _volumeSubscription = player.stream.volume.listen((volume) {
      if (_isDisposed) return;

      _volumeSaveDebounce?.cancel();
      _volumeSaveDebounce = Timer(const Duration(seconds: 1), () {
        _saveVolume(volume);
      });
    });
  }

  void _onPositionChanged(Duration position) {
    if (_isDisposed) return;

    final now = DateTime.now();
    final timeSinceLastSave = _lastSaveTime != null ? now.difference(_lastSaveTime!) : _saveInterval;

    // Save progress every 10 seconds of playback
    if (timeSinceLastSave >= _saveInterval && position != _lastSavedPosition && position.inSeconds > 0) {
      _saveProgress(position);
      _lastSavedPosition = position;
      _lastSaveTime = now;
    }
  }

  Future<void> _loadSavedPosition() async {
    if (_watchHistoryService == null || animeId == null || episodeId == null || streamProviderName == null) {
      return;
    }

    final result = await _watchHistoryService.getResumePosition(
      providerName: streamProviderName!,
      animeId: animeId!,
      episodeId: episodeId!,
      episodeNumber: episodeNumber,
    );

    final targetPosition = result.position;
    final isCrossProvider = result.isCrossProvider;
    final matchDurationMs = result.matchDurationMs;

    if (targetPosition != Duration.zero && !_isDisposed) {
      // Wait for the player to be ready with duration
      StreamSubscription<Duration>? sub;
      sub = player.stream.duration.listen((duration) {
        if (duration != Duration.zero) {
          bool shouldSeek = true;

          // If it's a cross-provider match, verify duration similarity
          if (isCrossProvider && matchDurationMs != null) {
            final difference = (duration.inMilliseconds - matchDurationMs).abs();
            // Allow 60 seconds difference (60,000 ms)
            if (difference > 60000) {
              shouldSeek = false;
              debugPrint('Cross-provider sync skipped: Duration mismatch ($difference ms)');
            }
          }

          if (shouldSeek) {
            // Don't seek if we're near the end (> 98% watched)
            if (targetPosition < duration * 0.98) {
              player.seek(targetPosition);
              debugPrint('Resumed playback at ${targetPosition.inSeconds}s${isCrossProvider ? ' (synced)' : ''}');
            }
          }
          sub?.cancel();
        }
      });
    }
  }

  Future<void> _saveProgress(Duration position) async {
    if (_watchHistoryService == null ||
        animeId == null ||
        episodeId == null ||
        episodeNumber == null ||
        streamProviderName == null ||
        metadataProviderName == null) {
      return;
    }

    final entry = WatchHistoryEntry(
      animeId: animeId!,
      episodeId: episodeId!,
      episodeNumber: episodeNumber!,
      streamProviderName: streamProviderName!,
      metadataProviderName: metadataProviderName!,
      positionMs: position.inMilliseconds,
      durationMs: _currentDuration.inMilliseconds,
      lastWatched: DateTime.now(),
      animeTitle: animeTitle.isNotEmpty ? animeTitle : null,
      episodeTitle: episodeTitle.isNotEmpty ? episodeTitle : null,
    );

    await _watchHistoryService.saveProgress(entry);
  }

  String _getTitle() {
    if (animeTitle.isNotEmpty && episodeTitle.isNotEmpty) {
      return '$animeTitle - $episodeTitle';
    }
    return episodeTitle.isNotEmpty ? episodeTitle : 'Video Player';
  }

  int _getBestQualityIndex() {
    int bestIndex = 0;
    int bestQuality = 0;

    for (int i = 0; i < sources.length; i++) {
      // Extract number from "1080p", "720p" etc.
      final qualityString = sources[i].quality.replaceAll(RegExp(r'[^\d]'), '');
      final quality = int.tryParse(qualityString) ?? 0;

      if (quality > bestQuality) {
        bestQuality = quality;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  Future<void> _loadSource(StreamingSource source) async {
    if (_isDisposed) return;

    // Auto-select tracks by default
    await player.setVideoTrack(VideoTrack.auto());
    await player.setAudioTrack(AudioTrack.auto());
    await player.setSubtitleTrack(SubtitleTrack.no()); // Start with no subtitles

    // Build external subtitle tracks from source
    final List<SubtitleTrack> externalSubs = source.subtitles
        .map((s) => SubtitleTrack.uri(s.url, title: s.label, language: s.language))
        .toList();

    // Open media
    await player.open(Media(source.url));

    // Store external subtitles for later access
    if (externalSubs.isNotEmpty) {
      _externalSubtitles = externalSubs;
      notifyListeners();
    }

    // Auto-select preferred tracks after a short delay to let player initialize
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        _selectPreferredSubtitle();
        _selectPreferredAudio();
      }
    });
  }

  /// Select subtitle based on priority: user preference > English > Auto
  Future<void> _selectPreferredSubtitle() async {
    if (_externalSubtitles.isEmpty) return;

    // Get saved preference
    final savedPref = await _getSavedSubtitlePreference();

    SubtitleTrack? selectedTrack;

    // Priority 1: User's saved preference (match by title)
    if (savedPref != null) {
      selectedTrack = _externalSubtitles.where((s) => s.title == savedPref).firstOrNull;
    }

    // Priority 2: English subtitle
    selectedTrack ??= _externalSubtitles
        .where(
          (s) =>
              s.language?.toLowerCase() == 'en' ||
              s.language?.toLowerCase() == 'eng' ||
              (s.title?.toLowerCase().contains('english') ?? false),
        )
        .firstOrNull;

    // Priority 3: Fall back to first subtitle if nothing matches
    if (selectedTrack == null && _externalSubtitles.isNotEmpty) {
      selectedTrack = _externalSubtitles.first;
    }

    if (selectedTrack != null && !_isDisposed) {
      await player.setSubtitleTrack(selectedTrack);
      debugPrint('Auto-selected subtitle: ${selectedTrack.title}');
    }
  }

  Future<String?> _getSavedSubtitlePreference() async {
    return await _preferencesService?.get<String>(PrefKey.subtitlePreference);
  }

  Future<void> _saveSubtitlePreference(String? title) async {
    if (title == null) return;
    await _preferencesService?.set(PrefKey.subtitlePreference, title);
  }

  Future<String?> _getSavedAudioPreference() async {
    return await _preferencesService?.get<String>(PrefKey.audioPreference);
  }

  Future<void> _saveAudioPreference(String? title) async {
    if (title == null) return;
    await _preferencesService?.set(PrefKey.audioPreference, title);
  }

  /// Select audio based on priority: user preference > Auto
  Future<void> _selectPreferredAudio() async {
    final tracks = player.state.tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    if (tracks.isEmpty) return;

    final savedPref = await _getSavedAudioPreference();

    AudioTrack? selectedTrack;

    // Priority 1: User's saved preference (match by title)
    if (savedPref != null) {
      selectedTrack = tracks.where((t) => t.title == savedPref).firstOrNull;
    }

    // Priority 2: Auto (don't change if no preference found)
    if (selectedTrack != null && !_isDisposed) {
      await player.setAudioTrack(selectedTrack);
      debugPrint('Auto-selected audio: ${selectedTrack.title}');
    }
  }

  // External subtitles loaded from the stream source
  List<SubtitleTrack> _externalSubtitles = [];

  List<SubtitleTrack> get externalSubtitles => _externalSubtitles;

  Future<void> changeQuality(int index) async {
    if (index == _currentSourceIndex || index < 0 || index >= sources.length) {
      return;
    }

    final currentPosition = player.state.position;
    final wasPlaying = player.state.playing;

    _currentSourceIndex = index;
    notifyListeners();

    // Emit feedback
    final qualityLabel = sources[index].quality;
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.quality, qualityLabel));

    await _loadSource(sources[index]);

    /// Wait for the source to buffer before seeking to the previous position.
    /// This prevents the player from resetting to the start on some platforms.
    await _waitForBufferingAndSeek(currentPosition, wasPlaying);
  }

  Future<void> _waitForBufferingAndSeek(Duration position, bool wasPlaying) async {
    // Determine if we need to wait for buffering (Android/Mobile specific usually)
    // We listen for the transition from buffering (true) -> buffering (false)
    bool hasBuffered = false;
    StreamSubscription<bool>? sub;

    // Completer to wrap the stream listener in a Future
    final completer = Completer<void>();

    sub = player.stream.buffering.listen((isBuffering) {
      if (isBuffering) {
        hasBuffered = true;
      } else if (hasBuffered) {
        // Buffering finished
        completer.complete();
        sub?.cancel();
      }
    });

    // Timeout safety: if buffering takes too long or never triggers (e.g. fast load), just seek.
    // 5 seconds timeout seems reasonable for a quality switch.
    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Timeout occurred, proceed anyway
      sub.cancel();
    }

    if (!_isDisposed) {
      await player.seek(position);
      if (wasPlaying) await player.play();
    }
  }

  StreamingSource get currentSource => sources[_currentSourceIndex];

  // Track Selection Wrappers
  Future<void> setVideoTrack(VideoTrack track) async {
    await player.setVideoTrack(track);

    // Emit feedback
    String label = track.title ?? 'Track ${track.id}';
    if (track.h != null) label = '${track.h}p';
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.quality, label));
  }

  Future<void> setAudioTrack(AudioTrack track) async {
    await player.setAudioTrack(track);

    // Save user's audio preference (by title for matching later)
    if (track.id != 'no' && track.id != 'auto') {
      _saveAudioPreference(track.title);
    }

    // Emit feedback
    final label = track.title ?? track.language ?? 'Track ${track.id}';
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.audio, label));
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    // Immediate feedback
    final label = track.title ?? track.language ?? 'Track ${track.id}';
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.subtitle, label));

    await player.setSubtitleTrack(track);

    // Save user's subtitle preference (by title for matching later)
    if (track.id != 'no' && track.id != 'auto') {
      _saveSubtitlePreference(track.title);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await player.setRate(speed);
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.speed, '${speed}x'));
  }

  Future<void> playEpisode({
    required String episodeId,
    required String episodeNumber,
    required String episodeTitle,
    required List<StreamingSource> sources,
    required String streamProviderName,
  }) async {
    if (_isDisposed) return;

    // Save progress for the current episode
    await _saveProgress(player.state.position);

    _episodeId = episodeId;
    _episodeNumber = episodeNumber;
    _episodeTitle = episodeTitle;
    _sources = sources;
    _streamProviderName = streamProviderName;
    _currentSourceIndex = 0;

    // Reset state
    _externalSubtitles = [];
    _lastSavedPosition = Duration.zero;
    _currentDuration = Duration.zero;
    _lastSaveTime = null;

    notifyListeners();

    if (_sources.isNotEmpty) {
      _currentSourceIndex = _getBestQualityIndex();
      await _loadSource(_sources[_currentSourceIndex]);
      await _loadSavedPosition();
    }
  }

  bool _isSavingThumbnail = false;
  bool _pendingDispose = false;

  @override
  void dispose() {
    // Save final position before disposing
    if (!_isDisposed && player.state.position.inSeconds > 0) {
      _saveProgress(player.state.position);
    }

    _isDisposed = true;
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _volumeSubscription?.cancel();
    _volumeSaveDebounce?.cancel();
    _feedbackController.close();

    // Only dispose player if we're not currently saving a thumbnail
    if (_isSavingThumbnail) {
      _pendingDispose = true;
    } else {
      player.dispose();
    }

    super.dispose();
  }

  /// Save current frame as episode thumbnail in background.
  /// This method is non-blocking and handles player lifecycle internally.
  Future<void> saveThumbnail() async {
    if (_thumbnailService == null || streamProviderName == null || animeId == null || episodeId == null) {
      return;
    }

    _isSavingThumbnail = true;

    try {
      // Capture screenshot from the video controller
      // Use JPEG for faster compression and less lag on exit
      final screenshot = await controller.player.screenshot(format: 'image/jpeg');
      if (screenshot != null) {
        await _thumbnailService.saveThumbnail(streamProviderName!, animeId!, episodeId!, screenshot);
        debugPrint('Saved episode thumbnail');
      }
    } catch (e) {
      debugPrint('Failed to save thumbnail: $e');
    } finally {
      _isSavingThumbnail = false;
      // If the viewmodel was disposed while we were saving, dispose the player now
      if (_pendingDispose) {
        player.dispose();
        debugPrint('Deferred player disposal complete');
      }
    }
  }

  Future<void> _loadSavedVolume() async {
    final savedVolume = await _preferencesService?.get<double>(PrefKey.videoVolume);
    if (savedVolume != null) {
      final volume = savedVolume.clamp(0.0, 100.0);
      await player.setVolume(volume);
    }
  }

  Future<void> _saveVolume(double volume) async {
    await _preferencesService?.set(PrefKey.videoVolume, volume);
  }
}
