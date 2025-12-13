import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/streaming_source.dart';
import '../services/preferences_service.dart';
import '../services/thumbnail_service.dart';
import '../services/watch_history_service.dart';
import '../viewmodels/video_player_view_model.dart';
import '../widgets/video_player/video_player_controls.dart';
import '../widgets/video_player/video_settings_sheet.dart';

class VideoPlayerView extends StatefulWidget {
  final List<StreamingSource> sources;
  final String episodeTitle;
  final String animeTitle;

  // Watch history tracking identifiers
  final int? animeId;
  final String? episodeId;
  final String? episodeNumber;
  final String? streamProviderName;
  final String? metadataProviderName;

  const VideoPlayerView({
    super.key,
    required this.sources,
    required this.episodeTitle,
    this.animeTitle = '',
    this.animeId,
    this.episodeId,
    this.episodeNumber,
    this.streamProviderName,
    this.metadataProviderName,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize viewModel only once, after context is available
    if (_viewModel == null) {
      // Get WatchHistoryService from context (it's registered as non-nullable)
      WatchHistoryService? watchHistoryService;
      try {
        watchHistoryService = context.read<WatchHistoryService>();
      } catch (e) {
        // Service not available, continue without it
        debugPrint('WatchHistoryService not available: $e');
      }

      // Get PreferencesService
      PreferencesService? preferencesService;
      try {
        preferencesService = context.read<PreferencesService>();
      } catch (e) {
        debugPrint('PreferencesService not available: $e');
      }

      // Get ThumbnailService
      ThumbnailService? thumbnailService;
      try {
        thumbnailService = context.read<ThumbnailService>();
      } catch (e) {
        debugPrint('ThumbnailService not available: $e');
      }

      _viewModel = VideoPlayerViewModel(
        sources: widget.sources,
        episodeTitle: widget.episodeTitle,
        animeTitle: widget.animeTitle,
        watchHistoryService: watchHistoryService,
        preferencesService: preferencesService,
        thumbnailService: thumbnailService,
        animeId: widget.animeId,
        episodeId: widget.episodeId,
        episodeNumber: widget.episodeNumber,
        streamProviderName: widget.streamProviderName,
        metadataProviderName: widget.metadataProviderName,
      );
    }
  }

  @override
  void dispose() {
    // Save thumbnail before disposing (fire and forget)
    _viewModel?.saveThumbnail();
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if viewModel isn't ready yet
    if (_viewModel == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final viewModel = _viewModel!;

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Video(
                controller: viewModel.controller,
                controls: (state) => VideoPlayerControls(
                  controller: viewModel.controller,
                  videoTitle: viewModel.episodeTitle,
                  onBack: () => Navigator.of(context).pop(),
                  onSettingsPressed: () => _showSettings(context),
                  feedbackStream: viewModel.feedbackStream,
                ),
              ),
              // Buffering indicator
              StreamBuilder<bool>(
                stream: viewModel.player.stream.buffering,
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return const SizedBox(
                      width: 75,
                      height: 75,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChangeNotifierProvider.value(
        value: _viewModel,
        child: Consumer<VideoPlayerViewModel>(
          builder: (context, viewModel, child) {
            final player = viewModel.player;

            // Use player.state for initial values (synchronous read)
            // This ensures we get current values immediately, not waiting for stream
            return StreamBuilder<Tracks>(
              stream: player.stream.tracks,
              initialData: player.state.tracks,
              builder: (context, snapshotTracks) {
                final tracks = snapshotTracks.data ?? player.state.tracks;

                return StreamBuilder<Track>(
                  stream: player.stream.track,
                  initialData: player.state.track,
                  builder: (context, snapshotTrack) {
                    final selectedTrack = snapshotTrack.data ?? player.state.track;

                    return StreamBuilder<double>(
                      stream: player.stream.rate,
                      initialData: player.state.rate,
                      builder: (context, snapshotRate) {
                        final rate = snapshotRate.data ?? player.state.rate;

                        return VideoSettingsSheet(
                          sources: viewModel.sources,
                          currentSource: viewModel.currentSource,
                          onQualitySelected: (index) => viewModel.changeQuality(index),
                          playbackSpeed: rate,
                          onPlaybackSpeedSelected: (speed) => viewModel.setPlaybackSpeed(speed),
                          tracks: tracks,
                          selectedTrack: selectedTrack,
                          externalSubtitles: viewModel.externalSubtitles,
                          onVideoTrackSelected: (track) => viewModel.setVideoTrack(track),
                          onAudioTrackSelected: (track) => viewModel.setAudioTrack(track),
                          onSubtitleTrackSelected: (track) => viewModel.setSubtitleTrack(track),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
