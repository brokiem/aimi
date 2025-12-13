import 'package:flutter/material.dart';

import '../models/anime.dart';

class AnimeInfoCard extends StatelessWidget {
  final Anime anime;

  const AnimeInfoCard({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...[
                ('Format', anime.format ?? "N/A"),
                ('Episodes', '${anime.episodes ?? "N/A"}'),
                ('Status', anime.status),
                ('Aired', "${anime.startDate ?? '?'} to ${anime.endDate ?? '?'}"),
                ('Season', "${anime.season ?? '?'} ${anime.seasonYear ?? ''}"),
                ('Studios', anime.studios.map((e) => e.name).join(', ')),
                ('Duration', "${anime.duration ?? '?'} min. per ep."),
                ('Source', anime.source ?? "N/A"),
                ('Genres', anime.genres.join(', ')),
              ].map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        e.$2,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
