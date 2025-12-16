import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
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
  bool _isLoadingEpisode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel ??= VideoPlayerViewModel(
      sources: widget.sources,
      episodeTitle: widget.episodeTitle,
      animeTitle: widget.animeTitle,
      watchHistoryService: context.read<WatchHistoryService?>(),
      preferencesService: context.read<PreferencesService?>(),
      thumbnailService: context.read<ThumbnailService?>(),
      animeId: widget.animeId,
      episodeId: widget.episodeId,
      episodeNumber: widget.episodeNumber,
      streamProviderName: widget.streamProviderName,
      metadataProviderName: widget.metadataProviderName,
    );
  }

  @override
  void dispose() {
    _viewModel?.saveThumbnail();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _onEpisodeTap(AnimeEpisode episode) async {
    final viewModel = _viewModel;
    if (viewModel == null || _isLoadingEpisode) return;

    setState(() => _isLoadingEpisode = true);

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
      if (mounted) setState(() => _isLoadingEpisode = false);
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
              child: _buildEpisodeList(
                onTap: (ep) async {
                  Navigator.pop(context);
                  await _onEpisodeTap(ep);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeList({required Future<void> Function(AnimeEpisode) onTap}) {
    return ListenableBuilder(
      listenable: widget.detailViewModel,
      builder: (context, _) => AnimeProviderContent(
        anime: widget.detailViewModel.anime,
        availableProviders: widget.detailViewModel.availableProviders,
        currentProvider: widget.detailViewModel.currentProviderName,
        getEpisodes: (p) => widget.detailViewModel.getEpisodesForProvider(p) ?? [],
        isProviderLoading: widget.detailViewModel.isProviderLoading,
        getEpisodeCount: widget.detailViewModel.getEpisodeCountForProvider,
        onProviderSelected: widget.detailViewModel.switchProvider,
        errorMessage: widget.detailViewModel.errorMessage,
        onRetry: () => widget.detailViewModel.loadAnime(forceRefresh: true),
        onEpisodeTap: onTap,
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
              return SafeArea(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildVideoPlayer(viewModel, showEpisodesButton: false, bottomSafeArea: false),
                    ),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: _buildEpisodeList(onTap: _onEpisodeTap),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Center(child: _buildVideoPlayer(viewModel, showEpisodesButton: true));
            }
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(
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
        // Buffering/Stall indicator using combined stream
        StreamBuilder<bool>(
          stream: Rx.merge([
            viewModel.player.stream.buffering,
            viewModel.stallStream,
          ]).map((_) => viewModel.player.state.buffering || viewModel.isStalled),
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
    );
  }

  void _showSettings(BuildContext context) {
    final viewModel = _viewModel!;
    final player = viewModel.player;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamBuilder<_SettingsData>(
        stream: Rx.combineLatest3(
          player.stream.tracks,
          player.stream.track,
          player.stream.rate,
          (tracks, track, rate) => _SettingsData(tracks, track, rate),
        ),
        initialData: _SettingsData(player.state.tracks, player.state.track, player.state.rate),
        builder: (context, snapshot) {
          final data = snapshot.data!;
          return VideoSettingsSheet(
            sources: viewModel.sources,
            currentSource: viewModel.currentSource,
            onQualitySelected: viewModel.changeQuality,
            playbackSpeed: data.rate,
            onPlaybackSpeedSelected: viewModel.setPlaybackSpeed,
            tracks: data.tracks,
            selectedTrack: data.track,
            externalSubtitles: viewModel.externalSubtitles,
            onVideoTrackSelected: viewModel.setVideoTrack,
            onAudioTrackSelected: viewModel.setAudioTrack,
            onSubtitleTrackSelected: viewModel.setSubtitleTrack,
          );
        },
      ),
    );
  }
}

/// Data class for combining settings streams
class _SettingsData {
  final Tracks tracks;
  final Track track;
  final double rate;

  const _SettingsData(this.tracks, this.track, this.rate);
}
