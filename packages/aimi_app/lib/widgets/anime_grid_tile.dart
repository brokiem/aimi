import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anime.dart';
import '../services/settings_service.dart';
import '../utils/title_helper.dart';

/// A grid tile widget for displaying anime information.
///
/// Features:
/// - Anime cover image with hover effect
/// - Score badge with color coding (green/amber/red)
/// - Bottom overlay with format, episode count, and season
/// - Navigation to detail view on tap
class AnimeGridTile extends StatefulWidget {
  final Anime anime;
  final void Function(Anime) onTap;

  /// Optional prefix to make Hero tag unique across different views.
  final String? heroTagPrefix;

  const AnimeGridTile({super.key, required this.anime, required this.onTap, this.heroTagPrefix});

  @override
  State<AnimeGridTile> createState() => _AnimeGridTileState();
}

class _AnimeGridTileState extends State<AnimeGridTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    void onTap() {
      widget.onTap(widget.anime);
    }

    final anime = widget.anime;

    // Build info chips for the bottom overlay
    final List<String> infoItems = [];
    if (anime.format != null) {
      infoItems.add(_formatType(anime.format!));
    }
    if (anime.episodes != null) {
      infoItems.add('${anime.episodes} EP');
    }
    if (anime.season != null && anime.seasonYear != null) {
      infoItems.add('${_formatSeason(anime.season!)} ${anime.seasonYear}');
    }

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 202 / 285,
                child: Stack(
                  children: [
                    // Cover Image
                    _buildCoverImage(context),

                    // Score badge (top-left)
                    if (anime.averageScore != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getScoreColor(anime.averageScore!),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${anime.averageScore}%',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Bottom gradient overlay with info
                    if (infoItems.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                          child: Text(
                            infoItems.join(' • '),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                    // Hover overlay
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: _isHovered ? Colors.black.withValues(alpha: 0.1) : Colors.transparent,
                        ),
                      ),
                    ),

                    // Ripple
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Consumer<SettingsService>(
                builder: (context, settingsService, child) {
                  final preferredTitle = getPreferredTitle(widget.anime.title, settingsService.titleLanguagePreference);
                  return Text(
                    preferredTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _isHovered ? Theme.of(context).colorScheme.primary : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the cover image with optional Hero animation based on settings.
  Widget _buildCoverImage(BuildContext context) {
    final settingsService = context.read<SettingsService>();

    final imageWidget = CachedNetworkImage(
      imageUrl: widget.anime.coverImage.large,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error),
      ),
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
    );

    if (settingsService.enableHeroAnimation && widget.heroTagPrefix != null) {
      final tagPrefix = widget.heroTagPrefix;
      return Hero(tag: 'anime_cover_${tagPrefix}_${widget.anime.id}', child: imageWidget);
    }
    return imageWidget;
  }

  /// Returns a color based on the score (similar to Rotten Tomatoes)
  Color _getScoreColor(int score) {
    if (score >= 75) {
      return const Color(0xFF4CAF50); // Green for high scores
    } else if (score >= 60) {
      return const Color(0xFFFFC107); // Amber for medium scores
    } else {
      return const Color(0xFFF44336); // Red for low scores
    }
  }

  /// Formats the anime format type to a shorter display string
  String _formatType(String format) {
    switch (format.toUpperCase()) {
      case 'TV':
        return 'TV';
      case 'TV_SHORT':
        return 'Short';
      case 'MOVIE':
        return 'Movie';
      case 'SPECIAL':
        return 'Special';
      case 'OVA':
        return 'OVA';
      case 'ONA':
        return 'ONA';
      case 'MUSIC':
        return 'Music';
      default:
        return format;
    }
  }

  /// Formats the season to a short display string
  String _formatSeason(String season) {
    switch (season.toUpperCase()) {
      case 'WINTER':
        return 'Win';
      case 'SPRING':
        return 'Spr';
      case 'SUMMER':
        return 'Sum';
      case 'FALL':
        return 'Fall';
      default:
        return season;
    }
  }
}
