import 'package:cached_network_image/cached_network_image.dart'; // Added this import for CachedNetworkImageProvider
import 'package:flutter/material.dart';

import '../models/anime.dart';

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

  const AnimeGridTile({super.key, required this.anime, required this.onTap});

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

    return MouseRegion(
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
              child: Material(
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Stack(
                  children: [
                    Ink.image(
                      image: CachedNetworkImageProvider(widget.anime.coverImage.large),
                      fit: BoxFit.cover,
                      child: InkWell(onTap: onTap),
                    ),
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                          child: Text(
                            infoItems.join(' • '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    // Hover overlay
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        color: _isHovered ? Colors.black.withValues(alpha: 0.1) : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.anime.title.english ?? widget.anime.title.romaji ?? widget.anime.title.native,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: _isHovered ? Theme.of(context).colorScheme.primary : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
