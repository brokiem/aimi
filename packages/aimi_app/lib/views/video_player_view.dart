import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:side_sheet/side_sheet.dart';

import '../models/anime_episode.dart';
import '../models/streaming_source.dart';
import '../services/preferences_service.dart';
import '../services/thumbnail_service.dart';
import '../services/watch_history_service.dart';
import '../viewmodels/detail_viewmodel.dart';
import '../viewmodels/video_player_viewmodel.dart';
import '../widgets/anime_provider_content.dart';
import '../widgets/video_player/video_player_controls.dart';
import '../widgets/video_player/video_settings_sheet.dart';

class VideoPlayerView extends StatefulWidget {
  final List<StreamingSource> sources;
  final String episodeTitle;
  final String animeTitle;
  final DetailViewModel detailViewModel;

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
    required this.detailViewModel,
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

  bool _isLoadingEpisode = false;

  Future<void> _onEpisodeTap(AnimeEpisode episode) async {
    final viewModel = _viewModel;
    if (viewModel == null || _isLoadingEpisode) return; // Prevent multiple taps

    setState(() {
      _isLoadingEpisode = true;
    });

    try {
      await widget.detailViewModel.loadSources(episode);
      final sources = widget.detailViewModel.sources;

      if (!mounted) return;

      if (sources.isNotEmpty) {
        await viewModel.playEpisode(
          episodeId: episode.id,
          episodeNumber: episode.number.toString(),
          episodeTitle: 'Episode ${episode.number}',
          sources: sources,
          streamProviderName: widget.detailViewModel.currentProviderName,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sources found for this episode.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load episode: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEpisode = false;
        });
      }
    }
  }

  void _showEpisodesSheet() {
    SideSheet.right(
      context: context,
      width: (MediaQuery.of(context).size.width * 0.35).clamp(400.0, 600.0),
      sheetColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Episodes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.detailViewModel,
                builder: (context, _) {
                  return AnimeProviderContent(
                    anime: widget.detailViewModel.anime,
                    availableProviders: widget.detailViewModel.availableProviders,
                    currentProvider: widget.detailViewModel.currentProviderName,
                    getEpisodes: (p) => widget.detailViewModel.getEpisodesForProvider(p) ?? [],
                    isProviderLoading: widget.detailViewModel.isProviderLoading,
                    getEpisodeCount: widget.detailViewModel.getEpisodeCountForProvider,
                    onProviderSelected: (index) {
                      widget.detailViewModel.switchProvider(index);
                    },
                    errorMessage: widget.detailViewModel.errorMessage,
                    onRetry: () => widget.detailViewModel.loadAnime(forceRefresh: true),
                    onEpisodeTap: (episode) async {
                      Navigator.pop(context); // Close sheet
                      await _onEpisodeTap(episode);
                    },
                    // No scroll controller needed for SideSheet usually as Content handles it,
                    // or we pass null if it expects one.
                    // AnimeProviderContent usually has its own list view.
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        body: OrientationBuilder(
          builder: (context, orientation) {
            final isPortrait = orientation == Orientation.portrait;

            if (isPortrait) {
              // Mobile/Portrait Layout: Split View
              return SafeArea(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildVideoPlayer(context, viewModel, showEpisodesButton: false, bottomSafeArea: false),
                    ),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: ListenableBuilder(
                          listenable: widget.detailViewModel,
                          builder: (context, _) {
                            return AnimeProviderContent(
                              anime: widget.detailViewModel.anime,
                              availableProviders: widget.detailViewModel.availableProviders,
                              currentProvider: widget.detailViewModel.currentProviderName,
                              getEpisodes: (p) => widget.detailViewModel.getEpisodesForProvider(p) ?? [],
                              isProviderLoading: widget.detailViewModel.isProviderLoading,
                              getEpisodeCount: widget.detailViewModel.getEpisodeCountForProvider,
                              onProviderSelected: (index) {
                                widget.detailViewModel.switchProvider(index);
                              },
                              errorMessage: widget.detailViewModel.errorMessage,
                              onRetry: () => widget.detailViewModel.loadAnime(forceRefresh: true),
                              onEpisodeTap: _onEpisodeTap,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Desktop/Landscape Layout: Fullscreen with Overlay Sheet
              return Center(child: _buildVideoPlayer(context, viewModel, showEpisodesButton: true));
            }
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(
    BuildContext context,
    VideoPlayerViewModel viewModel, {
    required bool showEpisodesButton,
    bool bottomSafeArea = true,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Stack(
          children: [
            Video(
              controller: viewModel.controller,
              controls: (state) => VideoPlayerControls(
                controller: viewModel.controller,
                // Fix: Use viewModel.controller
                videoTitle: '${widget.animeTitle} - ${viewModel.episodeTitle}',
                onBack: () => Navigator.pop(context),
                onSettingsPressed: () => _showSettings(context),
                feedbackStream: viewModel.feedbackStream,
                onShowEpisodes: showEpisodesButton ? _showEpisodesSheet : null,
                bottomSafeArea: bottomSafeArea,
              ),
            ),
            if (_isLoadingEpisode)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        // Buffering/Stall indicator
        StreamBuilder<bool>(
          stream: viewModel.player.stream.buffering,
          builder: (context, snapshot) {
            final isBuffering = snapshot.data ?? false;
            return Selector<VideoPlayerViewModel, bool>(
              selector: (_, vm) => vm.isStalled,
              builder: (context, isStalled, _) {
                if (isBuffering || isStalled) {
                  return const SizedBox(
                    width: 75,
                    height: 75,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ],
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
