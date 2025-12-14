import 'package:flutter/material.dart';

import '../models/anime.dart';
import '../models/anime_episode.dart';
import 'anime_provider_content.dart';

class AnimeProviderSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          _SheetHeader(
            title: anime.title.romaji ?? anime.title.english ?? 'Unknown',
            episodeCount: getEpisodeCount(currentProvider),
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: AnimeProviderContent(
              anime: anime,
              availableProviders: availableProviders,
              currentProvider: currentProvider,
              getEpisodes: getEpisodes,
              isProviderLoading: isProviderLoading,
              getEpisodeCount: getEpisodeCount,
              onProviderSelected: onProviderSelected,
              errorMessage: errorMessage,
              onRetry: onRetry,
              onEpisodeTap: onEpisodeTap,
              scrollController: scrollController,
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
