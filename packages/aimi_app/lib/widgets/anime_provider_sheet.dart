import 'dart:async';
import 'dart:io';

import 'package:aimi_app/services/thumbnail_service.dart';
import 'package:aimi_app/services/watch_history_service.dart';
import 'package:aimi_app/widgets/common/error_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../models/anime.dart';
import '../models/anime_episode.dart';
import '../models/watch_history_entry.dart';

class AnimeProviderSheet extends StatefulWidget {
  final Anime anime;
  final List<String> availableProviders;
  final String currentProvider;
  final List<AnimeEpisode> Function(String) getEpisodes;
  final bool Function(String) isProviderLoading;
  final int Function(String) getEpisodeCount;
  final void Function(int) onProviderSelected;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Future<void> Function(AnimeEpisode) onEpisodeTap;
  final ScrollController? scrollController;

  const AnimeProviderSheet({
    super.key,
    required this.anime,
    required this.availableProviders,
    required this.currentProvider,
    required this.getEpisodes,
    required this.isProviderLoading,
    required this.getEpisodeCount,
    required this.onProviderSelected,
    this.errorMessage,
    required this.onRetry,
    required this.onEpisodeTap,
    this.scrollController,
  });

  @override
  State<AnimeProviderSheet> createState() => _AnimeProviderSheetState();
}

class _AnimeProviderSheetState extends State<AnimeProviderSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  void _initTabController() {
    _tabController = TabController(
      length: widget.availableProviders.length,
      vsync: this,
      initialIndex: widget.availableProviders
          .indexOf(widget.currentProvider)
          .clamp(0, widget.availableProviders.length - 1),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      widget.onProviderSelected(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          _SheetHeader(
            title: widget.anime.title.romaji ?? widget.anime.title.english ?? 'Unknown',
            episodeCount: widget.getEpisodeCount(widget.currentProvider),
            onClose: () => Navigator.of(context).pop(),
          ),
          _ProviderTabBar(
            controller: _tabController,
            providers: widget.availableProviders,
            currentProvider: widget.currentProvider,
            getEpisodes: widget.getEpisodes,
            isProviderLoading: widget.isProviderLoading,
            getEpisodeCount: widget.getEpisodeCount,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.availableProviders.map((provider) {
                final isCurrent = provider == widget.currentProvider;
                return _ProviderEpisodeList(
                  providerName: provider,
                  anime: widget.anime,
                  episodes: widget.getEpisodes(provider),
                  isCurrentProvider: isCurrent,
                  isLoading: widget.isProviderLoading(provider),
                  errorMessage: isCurrent ? widget.errorMessage : null,
                  onRetry: widget.onRetry,
                  onEpisodeTap: widget.onEpisodeTap,
                  scrollController: isCurrent ? widget.scrollController : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final int episodeCount;
  final VoidCallback onClose;

  const _SheetHeader({required this.title, required this.episodeCount, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.movie_creation_outlined, color: colorScheme.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Episode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurface),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _ProviderTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> providers;
  final String currentProvider;
  final List<AnimeEpisode> Function(String) getEpisodes;
  final bool Function(String) isProviderLoading;
  final int Function(String) getEpisodeCount;

  const _ProviderTabBar({
    required this.controller,
    required this.providers,
    required this.currentProvider,
    required this.getEpisodes,
    required this.isProviderLoading,
    required this.getEpisodeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 1)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        tabs: providers.map((provider) {
          final count = getEpisodeCount(provider);
          final isCurrentProvider = provider == currentProvider;
          final isLoading = isProviderLoading(provider);

          // Show current episode count if this is the active provider
          final displayCount = isCurrentProvider ? getEpisodes(provider).length : count;

          return _ProviderTab(providerName: provider, episodeCount: displayCount, isLoading: isLoading);
        }).toList(),
      ),
    );
  }
}

class _ProviderTab extends StatelessWidget {
  final String providerName;
  final int episodeCount;
  final bool isLoading;

  const _ProviderTab({required this.providerName, required this.episodeCount, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tab(
      child: Row(
        children: [
          Text(providerName),
          if (isLoading && episodeCount == 0) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
            ),
          ] else if (episodeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Text(
                '$episodeCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderEpisodeList extends StatefulWidget {
  final String providerName;
  final Anime anime;
  final List<AnimeEpisode> episodes;
  final bool isCurrentProvider;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Future<void> Function(AnimeEpisode) onEpisodeTap;
  final ScrollController? scrollController;

  const _ProviderEpisodeList({
    required this.providerName,
    required this.anime,
    required this.episodes,
    required this.isCurrentProvider,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
    required this.onEpisodeTap,
    this.scrollController,
  });

  @override
  State<_ProviderEpisodeList> createState() => _ProviderEpisodeListState();
}

class _ProviderEpisodeListState extends State<_ProviderEpisodeList> {
  Map<String, WatchHistoryEntry> _watchProgress = {};
  bool _loadingWatchHistory = false;
  StreamSubscription<WatchHistoryEntry>? _progressSubscription;
  List<AnimeEpisode>? _lastEpisodes;

  @override
  void initState() {
    super.initState();
    final watchHistoryService = context.read<WatchHistoryService>();
    _progressSubscription = watchHistoryService.onProgressUpdated.listen(_onProgressUpdated);
    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWatchHistory();
    });
  }

  @override
  void didUpdateWidget(_ProviderEpisodeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if scrolling became active or other inputs changed drastically
    // Usually episodes update via VM listener below, but we need to check if episodes changed
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _onProgressUpdated(WatchHistoryEntry entry) {
    if (entry.animeId != widget.anime.id) return;
    if (entry.streamProviderName != widget.providerName) return;

    if (mounted) {
      setState(() {
        _watchProgress[entry.episodeId] = entry;
      });
    }
  }

  Future<void> _loadWatchHistory() async {
    if (_loadingWatchHistory) return;

    final episodes = widget.episodes;

    if (episodes.isEmpty) return;

    setState(() => _loadingWatchHistory = true);

    try {
      final watchHistoryService = context.read<WatchHistoryService>();
      final Map<String, WatchHistoryEntry> progressMap = {};

      for (final episode in episodes) {
        var entry = await watchHistoryService.getProgress(widget.providerName, widget.anime.id, episode.id);

        final syncedEntry = await watchHistoryService.findLatestProgress(widget.anime.id, episode.number);

        if (syncedEntry != null) {
          if (entry == null || syncedEntry.lastWatched.isAfter(entry.lastWatched)) {
            bool durationMatch = true;
            if (episode.duration != null && episode.duration! > 0) {
              final diff = (syncedEntry.durationMs - episode.duration!).abs();
              if (diff > 60000) {
                durationMatch = false;
              }
            }

            if (durationMatch) {
              entry = syncedEntry;
            }
          }
        }

        if (entry != null) {
          progressMap[episode.id] = entry;
        }
      }

      if (mounted) {
        setState(() {
          _watchProgress = progressMap;
          _loadingWatchHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingWatchHistory = false);
    }
  }

  Future<void> _handleEpisodeTap(AnimeEpisode episode) async {
    await widget.onEpisodeTap(episode);
    if (mounted) {
      _loadingWatchHistory = false;
      await _loadWatchHistory();
    }
  }

  void _retry() {
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final episodes = widget.episodes;
    final isLoading = widget.isLoading;

    // Reload history if episodes list instance changed and is valid
    if (episodes != _lastEpisodes) {
      _lastEpisodes = episodes;
      if (episodes.isNotEmpty && !_loadingWatchHistory) {
        Future.microtask(_loadWatchHistory);
      }
    }

    // Determine error state: if not loading and default episodes are null (fetch failed) or empty?
    // VM returns null if never fetched/failed and not cached. returns [] if empty result.
    // If episodes is null, it means we probably haven't loaded it successfully or it's loading.

    // We should trust the caching state.
    // If loading, show loader usually. But if we have cached data, we show that (optimistic).

    // Logic:
    // If (episodes != null && episodes.isNotEmpty) -> Show List even if loading (refreshing)
    // If (isLoading) -> Show Loading (if no episodes)
    // If (episodes == null || episodes.isEmpty) -> Show Error/Empty

    if (episodes.isNotEmpty) {
      // Check if we need to load history for these new episodes
      // Simple check: if map is empty but we have episodes, load history
      if (_watchProgress.isEmpty && !_loadingWatchHistory) {
        // Using a microtask to avoid setState during build
        Future.microtask(_loadWatchHistory);
      }

      return _EpisodeList(
        episodes: episodes,
        watchProgress: _watchProgress,
        onEpisodeTap: _handleEpisodeTap,
        scrollController: widget.scrollController,
        animeId: widget.anime.id,
        providerName: widget.providerName,
        fallbackUrl: widget.anime.coverImage.large,
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // If not loading and no episodes -> Error or Empty.
    // We can differentiate based on VM error message or just generic
    // Use VM errorMessage only if it pertains to THIS provider?
    // VM errorMessage is single-slot.

    final isCurrent = widget.isCurrentProvider;
    final error = isCurrent ? widget.errorMessage : null;

    if (episodes.isEmpty) {
      return const Center(child: Text('No episodes available'));
    }

    return ErrorView(
      message: error ?? 'Failed to load',
      onRetry: isCurrent ? _retry : null, // Only retry if active or provide way to retry specific
    );
  }
}

class _EpisodeList extends StatelessWidget {
  final List<AnimeEpisode> episodes;
  final Map<String, WatchHistoryEntry> watchProgress;
  final Future<void> Function(AnimeEpisode) onEpisodeTap;
  final ScrollController? scrollController;
  final int animeId;
  final String providerName;
  final String? fallbackUrl;

  const _EpisodeList({
    required this.episodes,
    required this.watchProgress,
    required this.onEpisodeTap,
    this.scrollController,
    required this.animeId,
    required this.providerName,
    this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPrimaryScrollController(
      animationFactory: const ChromiumEaseInOut(),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: episodes.length,
        itemBuilder: (context, index) {
          final episode = episodes[index];
          final entry = watchProgress[episode.id];
          return _EpisodeCard(
            episode: episode,
            animeId: animeId,
            providerName: providerName,
            watchEntry: entry,
            fallbackUrl: fallbackUrl,
            onTap: () => onEpisodeTap(episode),
          );
        },
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final AnimeEpisode episode;
  final WatchHistoryEntry? watchEntry;
  final VoidCallback onTap;
  final int animeId;
  final String providerName;
  final String? fallbackUrl;

  const _EpisodeCard({
    required this.episode,
    this.watchEntry,
    required this.onTap,
    required this.animeId,
    required this.providerName,
    this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isWatched = watchEntry?.isCompleted ?? false;
    final hasProgress = watchEntry != null && !isWatched && watchEntry!.progress > 0.05;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              _EpisodeThumbnail(
                isWatched: isWatched,
                progress: hasProgress ? watchEntry!.progress : null,
                animeId: animeId,
                episodeId: episode.id,
                providerName: providerName,
                fallbackUrl: fallbackUrl,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode ${episode.number}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isWatched)
                      const _WatchedBadge()
                    else if (hasProgress)
                      _ProgressBadge(entry: watchEntry!)
                    else
                      Text(
                        'Tap to play',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeThumbnail extends StatelessWidget {
  final bool isWatched;
  final double? progress;
  final int animeId;
  final String episodeId;
  final String providerName;
  final String? fallbackUrl;

  const _EpisodeThumbnail({
    required this.isWatched,
    this.progress,
    required this.animeId,
    required this.episodeId,
    required this.providerName,
    this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Assuming ThumbnailService and File are available via imports
    // import 'package:provider/provider.dart';
    // import 'dart:io';
    final thumbnailService = context.read<ThumbnailService>();
    final hasProgress = progress != null && !isWatched && progress! > 0.05;

    // Listen for thumbnail updates
    return StreamBuilder<String>(
      stream: thumbnailService.onThumbnailUpdated,
      builder: (context, updateSnapshot) {
        // Reload if update matches our episode
        final shouldReload = updateSnapshot.data == episodeId;

        return FutureBuilder<String?>(
          // Use key to force reload when notified
          key: shouldReload ? UniqueKey() : null,
          future: thumbnailService.getThumbnail(providerName, animeId, episodeId),
          builder: (context, snapshot) {
            final thumbnailPath = snapshot.data;

            return Container(
              width: 120,
              height: 68,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                image: thumbnailPath != null
                    ? DecorationImage(image: FileImage(File(thumbnailPath)), fit: BoxFit.cover)
                    : (fallbackUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(fallbackUrl!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.5), // Darker overlay
                                BlendMode.darken,
                              ),
                            )
                          : null),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Play icon
                  Icon(
                    Icons.play_circle_filled,
                    size: 32,
                    color: colorScheme.primary, // Primary color
                  ),

                  if (isWatched)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 12, color: colorScheme.onPrimary),
                      ),
                    ),
                  // Progress bar at bottom
                  if (hasProgress)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary, // Primary color
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WatchedBadge extends StatelessWidget {
  const _WatchedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            'Watched',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final WatchHistoryEntry entry;

  const _ProgressBadge({required this.entry});

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m left';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s left';
    } else {
      return '${seconds}s left';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final remaining = entry.duration - entry.position;
    final progressPercent = (entry.progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 12, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            '$progressPercent% • ${_formatDuration(remaining)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
