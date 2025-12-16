import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:rxdart/rxdart.dart';

import '../models/streaming_source.dart';
import '../models/video_feedback.dart';
import '../models/watch_history_entry.dart';
import '../services/preferences_service.dart';
import '../services/thumbnail_service.dart';
import '../services/watch_history_service.dart';

/// ViewModel for video playback with watch history, quality switching,
/// and track selection support.
class VideoPlayerViewModel extends ChangeNotifier {
  late final Player player;
  late final VideoController controller;

  List<StreamingSource> _sources;

  List<StreamingSource> get sources => _sources;

  String _episodeTitle;

  String get episodeTitle => _episodeTitle;

  final String animeTitle;
  final int? animeId;
  final String? metadataProviderName;

  String? _episodeId;

  String? get episodeId => _episodeId;

  String? _episodeNumber;

  String? get episodeNumber => _episodeNumber;

  String? _streamProviderName;

  String? get streamProviderName => _streamProviderName;

  int _currentSourceIndex = 0;

  StreamingSource get currentSource => sources[_currentSourceIndex];

  List<SubtitleTrack> _externalSubtitles = [];

  List<SubtitleTrack> get externalSubtitles => _externalSubtitles;

  final WatchHistoryService? _watchHistoryService;
  final PreferencesService? _preferencesService;
  final ThumbnailService? _thumbnailService;

  final _feedbackController = StreamController<VideoFeedbackEvent>.broadcast();

  Stream<VideoFeedbackEvent> get feedbackStream => _feedbackController.stream;

  Duration _lastPosition = Duration.zero;
  final _stallSubject = BehaviorSubject<bool>.seeded(false);

  Stream<bool> get stallStream => _stallSubject.stream;

  bool get isStalled => _stallSubject.value;

  bool _isDisposed = false;
  bool _isSavingThumbnail = false;
  bool _pendingDispose = false;

  Duration _lastSavedPosition = Duration.zero;
  DateTime? _lastSaveTime;
  static const _saveInterval = Duration(seconds: 5);

  CompositeSubscription? _subscriptions;

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
        title: animeTitle.isNotEmpty && episodeTitle.isNotEmpty
            ? '$animeTitle - $episodeTitle'
            : episodeTitle.isNotEmpty
            ? episodeTitle
            : 'Video Player',
      ),
    );
    controller = VideoController(player);
    _subscriptions = CompositeSubscription();

    // Progress saving subscription
    _subscriptions!.add(player.stream.position.listen(_onPositionChanged));

    // Stall detection: check if position hasn't changed while playing & not buffering
    _subscriptions!.add(
      Rx.combineLatest3<bool, bool, Duration, bool>(
        player.stream.playing,
        player.stream.buffering,
        player.stream.position.throttleTime(const Duration(seconds: 1)),
        (playing, buffering, position) {
          final stalled = playing && !buffering && position == _lastPosition && position != Duration.zero;
          _lastPosition = position;
          return stalled;
        },
      ).distinct().listen((stalled) {
        if (_stallSubject.value != stalled) {
          _stallSubject.add(stalled);
          notifyListeners();
        }
      }),
    );

    // Load source, position, and volume
    if (sources.isNotEmpty) {
      _currentSourceIndex = _getBestQualityIndex();
      await _loadSource(sources[_currentSourceIndex]);
      await _loadSavedPosition();
    }
    await _loadSavedVolume();
  }

  int _getBestQualityIndex() {
    int bestIndex = 0, bestQuality = 0;
    for (int i = 0; i < sources.length; i++) {
      final quality = int.tryParse(sources[i].quality.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      if (quality > bestQuality) {
        bestQuality = quality;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<void> _loadSource(StreamingSource source) async {
    if (_isDisposed) return;

    await player.setVideoTrack(VideoTrack.auto());
    await player.setAudioTrack(AudioTrack.auto());
    await player.setSubtitleTrack(SubtitleTrack.no());

    _externalSubtitles = source.subtitles
        .map((s) => SubtitleTrack.uri(s.url, title: s.label, language: s.language))
        .toList();

    await player.open(Media(source.url));

    if (_externalSubtitles.isNotEmpty) notifyListeners();

    // Auto-select preferred tracks
    if (!_isDisposed) {
      _selectPreferredSubtitle();
      _selectPreferredAudio();
    }
  }

  Future<void> changeQuality(int index) async {
    if (index == _currentSourceIndex || index < 0 || index >= sources.length) {
      return;
    }

    final currentPosition = player.state.position;
    final wasPlaying = player.state.playing;

    _currentSourceIndex = index;
    notifyListeners();
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.quality, sources[index].quality));

    await _loadSource(sources[index]);
    await _waitForBufferAndSeek(currentPosition, wasPlaying);
  }

  Future<void> _waitForBufferAndSeek(Duration position, bool wasPlaying) async {
    try {
      // Wait for buffering to complete
      await player.stream.duration.where((duration) => duration > Duration.zero).first;
    } catch (_) {}

    if (!_isDisposed) {
      await player.seek(position);
      if (wasPlaying) await player.play();
    }
  }

  Future<void> setVideoTrack(VideoTrack track) async {
    await player.setVideoTrack(track);
    final label = track.h != null ? '${track.h}p' : (track.title ?? 'Track ${track.id}');
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.quality, label));
  }

  Future<void> setAudioTrack(AudioTrack track) async {
    await player.setAudioTrack(track);
    if (track.id != 'no' && track.id != 'auto') {
      _preferencesService?.set(PrefKey.audioPreference, track.title);
    }
    _feedbackController.add(
      VideoFeedbackEvent(FeedbackType.audio, track.title ?? track.language ?? 'Track ${track.id}'),
    );
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    _feedbackController.add(
      VideoFeedbackEvent(FeedbackType.subtitle, track.title ?? track.language ?? 'Track ${track.id}'),
    );
    await player.setSubtitleTrack(track);
    if (track.id != 'no' && track.id != 'auto') {
      _preferencesService?.set(PrefKey.subtitlePreference, track.title);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await player.setRate(speed);
    _feedbackController.add(VideoFeedbackEvent(FeedbackType.speed, '${speed}x'));
  }

  Future<void> _selectPreferredSubtitle() async {
    if (_externalSubtitles.isEmpty) return;
    final savedPref = await _preferencesService?.get<String>(PrefKey.subtitlePreference);

    SubtitleTrack? track = savedPref != null ? _externalSubtitles.where((s) => s.title == savedPref).firstOrNull : null;

    track ??= _externalSubtitles
        .where(
          (s) =>
              s.language?.toLowerCase() == 'en' ||
              s.language?.toLowerCase() == 'eng' ||
              (s.title?.toLowerCase().contains('english') ?? false),
        )
        .firstOrNull;

    track ??= _externalSubtitles.firstOrNull;

    if (track != null && !_isDisposed) {
      await player.setSubtitleTrack(track);
    }
  }

  Future<void> _selectPreferredAudio() async {
    final tracks = player.state.tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    if (tracks.isEmpty) return;

    final savedPref = await _preferencesService?.get<String>(PrefKey.audioPreference);
    final track = savedPref != null ? tracks.where((t) => t.title == savedPref).firstOrNull : null;

    if (track != null && !_isDisposed) {
      await player.setAudioTrack(track);
    }
  }

  void _onPositionChanged(Duration position) {
    if (_isDisposed || position.inSeconds <= 0) return;

    final now = DateTime.now();
    final elapsed = _lastSaveTime != null ? now.difference(_lastSaveTime!) : _saveInterval;

    if (elapsed >= _saveInterval && position != _lastSavedPosition) {
      _saveProgress(position);
      _lastSavedPosition = position;
      _lastSaveTime = now;
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

    await _watchHistoryService.saveProgress(
      WatchHistoryEntry(
        animeId: animeId!,
        episodeId: episodeId!,
        episodeNumber: episodeNumber!,
        streamProviderName: streamProviderName!,
        metadataProviderName: metadataProviderName!,
        positionMs: position.inMilliseconds,
        durationMs: player.state.duration.inMilliseconds,
        lastWatched: DateTime.now(),
        animeTitle: animeTitle.isNotEmpty ? animeTitle : null,
        episodeTitle: episodeTitle.isNotEmpty ? episodeTitle : null,
      ),
    );
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

    if (result.position == Duration.zero || _isDisposed) return;

    // Wait for duration to be available
    final duration = await player.stream.buffer
        .where((bufferDuration) => bufferDuration > Duration.zero)
        .first
        .then((_) => player.state.duration);

    // Validate cross-provider match
    if (result.isCrossProvider && result.matchDurationMs != null) {
      if ((duration.inMilliseconds - result.matchDurationMs!).abs() > 60000) {
        return;
      }
    }

    // Don't seek if near end (>99%)
    if (result.position < duration * 0.99) {
      await player.seek(result.position);
    }
  }

  Future<void> _loadSavedVolume() async {
    final volume = await _preferencesService?.get<double>(PrefKey.videoVolume);
    if (volume != null) await player.setVolume(volume.clamp(0.0, 100.0));
  }

  Future<void> playEpisode({
    required String episodeId,
    required String episodeNumber,
    required String episodeTitle,
    required List<StreamingSource> sources,
    required String streamProviderName,
  }) async {
    if (_isDisposed) return;

    await _saveProgress(player.state.position);

    _episodeId = episodeId;
    _episodeNumber = episodeNumber;
    _episodeTitle = episodeTitle;
    _sources = sources;
    _streamProviderName = streamProviderName;

    await player.stop();
    _externalSubtitles = [];
    _lastSavedPosition = Duration.zero;
    _lastSaveTime = null;

    notifyListeners();

    if (_sources.isNotEmpty) {
      _currentSourceIndex = _getBestQualityIndex();
      await _loadSource(_sources[_currentSourceIndex]);
      await _loadSavedPosition();
    }
  }

  Future<void> saveThumbnail() async {
    if (_thumbnailService == null || streamProviderName == null || animeId == null || episodeId == null) {
      return;
    }

    _isSavingThumbnail = true;
    try {
      final screenshot = await controller.player.screenshot(format: 'image/jpeg');
      if (screenshot != null) {
        await _thumbnailService.saveThumbnail(streamProviderName!, animeId!, episodeId!, screenshot);
      }
    } catch (e) {
      debugPrint('Failed to save thumbnail: $e');
    } finally {
      _isSavingThumbnail = false;
      if (_pendingDispose) player.dispose();
    }
  }

  @override
  void dispose() {
    if (!_isDisposed && player.state.position.inSeconds > 0) {
      _saveProgress(player.state.position);
    }
    // Save volume on dispose
    _preferencesService?.set(PrefKey.videoVolume, player.state.volume);

    _isDisposed = true;
    _subscriptions?.dispose();
    _stallSubject.close();
    _feedbackController.close();

    if (_isSavingThumbnail) {
      _pendingDispose = true;
    } else {
      player.dispose();
    }
    super.dispose();
  }
}
