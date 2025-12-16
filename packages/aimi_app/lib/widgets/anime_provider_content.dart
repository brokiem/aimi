import 'dart:async';
import 'dart:io';

import 'package:aimi_app/services/watch_history_service.dart';
import 'package:aimi_app/widgets/common/error_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../models/anime.dart';
import '../models/anime_episode.dart';
import '../models/watch_history_entry.dart';
import '../services/thumbnail_service.dart';

class AnimeProviderContent extends StatefulWidget {
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

  const AnimeProviderContent({
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
  State<AnimeProviderContent> createState() => _AnimeProviderContentState();
}

class _AnimeProviderContentState extends State<AnimeProviderContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  @override
  void didUpdateWidget(AnimeProviderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availableProviders.length != oldWidget.availableProviders.length) {
      _tabController.dispose();
      _initTabController();
    } else if (widget.currentProvider != oldWidget.currentProvider) {
      final index = widget.availableProviders.indexOf(widget.currentProvider);
      if (index != -1 && index != _tabController.index) {
        _tabController.animateTo(index);
      }
    }
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
    if (widget.availableProviders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        ProviderTabBar(
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
              return ProviderEpisodeList(
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
    );
  }
}

class ProviderTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> providers;
  final String currentProvider;
  final List<AnimeEpisode> Function(String) getEpisodes;
  final bool Function(String) isProviderLoading;
  final int Function(String) getEpisodeCount;

  const ProviderTabBar({
    super.key,
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

          return ProviderTab(providerName: provider, episodeCount: displayCount, isLoading: isLoading);
        }).toList(),
      ),
    );
  }
}

class ProviderTab extends StatelessWidget {
  final String providerName;
  final int episodeCount;
  final bool isLoading;

  const ProviderTab({super.key, required this.providerName, required this.episodeCount, required this.isLoading});

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
              width: 24,
              height: 24,
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

class ProviderEpisodeList extends StatefulWidget {
  final String providerName;
  final Anime anime;
  final List<AnimeEpisode> episodes;
  final bool isCurrentProvider;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Future<void> Function(AnimeEpisode) onEpisodeTap;
  final ScrollController? scrollController;

  const ProviderEpisodeList({
    super.key,
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
  State<ProviderEpisodeList> createState() => _ProviderEpisodeListState();
}

class _ProviderEpisodeListState extends State<ProviderEpisodeList> with AutomaticKeepAliveClientMixin {
  Map<String, WatchHistoryEntry> _watchProgress = {};
  bool _loadingWatchHistory = false;
  StreamSubscription<WatchHistoryEntry>? _progressSubscription;
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final watchHistoryService = context.read<WatchHistoryService>();
    _progressSubscription = watchHistoryService.onProgressUpdated.listen(_onProgressUpdated);
    // Initial load after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWatchHistory();
    });
  }

  @override
  void didUpdateWidget(ProviderEpisodeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if episodes changed (e.g., provider switch loaded new episodes)
    if (widget.episodes.length != oldWidget.episodes.length ||
        (widget.episodes.isNotEmpty &&
            oldWidget.episodes.isNotEmpty &&
            widget.episodes.first.id != oldWidget.episodes.first.id)) {
      _scheduleWatchHistoryLoad();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  /// Schedule a debounced watch history load to prevent multiple rapid calls.
  void _scheduleWatchHistoryLoad() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _loadWatchHistory();
    });
  }

  /// Handle progress updates from the stream.
  /// Matches by episode number for cross-provider sync.
  void _onProgressUpdated(WatchHistoryEntry entry) {
    if (entry.animeId != widget.anime.id) return;

    if (!mounted) return;

    // Find matching episode by number (cross-provider sync)
    // or by exact ID (same provider)
    String? matchingEpisodeId;
    for (final episode in widget.episodes) {
      if (entry.streamProviderName == widget.providerName && entry.episodeId == episode.id) {
        // Exact match (same provider, same ID)
        matchingEpisodeId = episode.id;
        break;
      } else if (entry.episodeNumber == episode.number) {
        // Cross-provider match (same episode number)
        matchingEpisodeId = episode.id;
        // Don't break - prefer exact match if found later
      }
    }

    if (matchingEpisodeId != null) {
      setState(() {
        _watchProgress[matchingEpisodeId!] = entry;
      });
    }
  }

  Future<void> _loadWatchHistory() async {
    if (_loadingWatchHistory) return;

    final episodes = widget.episodes;
    if (episodes.isEmpty) return;

    _loadingWatchHistory = true;

    try {
      final watchHistoryService = context.read<WatchHistoryService>();
      final Map<String, WatchHistoryEntry> progressMap = {};

      for (final episode in episodes) {
        // Try exact provider match first
        var entry = await watchHistoryService.getProgress(widget.providerName, widget.anime.id, episode.id);

        // Then try cross-provider sync by episode number
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
      if (mounted) {
        setState(() => _loadingWatchHistory = false);
      }
    }
  }

  Future<void> _handleEpisodeTap(AnimeEpisode episode) async {
    await widget.onEpisodeTap(episode);
    // Reload watch history after returning from video player
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final episodes = widget.episodes;
    final isLoading = widget.isLoading;

    if (episodes.isNotEmpty) {
      return EpisodeList(
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

    final isCurrent = widget.isCurrentProvider;
    final error = isCurrent ? widget.errorMessage : null;

    if (error != null) {
      return ErrorView(message: error, onRetry: isCurrent ? _retry : null);
    }

    return const Center(child: Text('No episodes available'));
  }
}

class EpisodeList extends StatelessWidget {
  final List<AnimeEpisode> episodes;
  final Map<String, WatchHistoryEntry> watchProgress;
  final Future<void> Function(AnimeEpisode) onEpisodeTap;
  final ScrollController? scrollController;
  final int animeId;
  final String providerName;
  final String? fallbackUrl;

  const EpisodeList({
    super.key,
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
          return EpisodeCard(
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

class EpisodeCard extends StatelessWidget {
  final AnimeEpisode episode;
  final WatchHistoryEntry? watchEntry;
  final VoidCallback onTap;
  final int animeId;
  final String providerName;
  final String? fallbackUrl;

  const EpisodeCard({
    super.key,
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
    final hasProgress = watchEntry != null && !isWatched && watchEntry!.progress > 0;

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
              EpisodeThumbnail(
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
                      const WatchedBadge()
                    else if (hasProgress)
                      ProgressBadge(entry: watchEntry!)
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

class EpisodeThumbnail extends StatelessWidget {
  final bool isWatched;
  final double? progress;
  final int animeId;
  final String episodeId;
  final String providerName;
  final String? fallbackUrl;

  const EpisodeThumbnail({
    super.key,
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
    final thumbnailService = context.read<ThumbnailService>();
    final hasProgress = progress != null && !isWatched && progress! > 0;

    return StreamBuilder<String>(
      stream: thumbnailService.onThumbnailUpdated,
      builder: (context, updateSnapshot) {
        final shouldReload = updateSnapshot.data == episodeId;

        return FutureBuilder<String?>(
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
                              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                            )
                          : null),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.play_circle_filled, size: 32, color: colorScheme.primary),

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
                  if (hasProgress)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Container(
                                  width: constraints.maxWidth * progress!,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: const Radius.circular(8),
                                      bottomRight: progress! >= 0.98 ? const Radius.circular(8) : Radius.zero,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
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

class WatchedBadge extends StatelessWidget {
  const WatchedBadge({super.key});

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

class ProgressBadge extends StatelessWidget {
  final WatchHistoryEntry entry;

  const ProgressBadge({super.key, required this.entry});

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
