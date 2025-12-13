import 'package:aimi_app/models/anime.dart';
import 'package:flutter/material.dart';

class MobileAnimeInfo extends StatelessWidget {
  final Anime anime;

  const MobileAnimeInfo({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    // Define the data points we want to show
    final infoItems = [
      ('Format', anime.format ?? "N/A"),
      ('Episodes', '${anime.episodes ?? "N/A"}'),
      ('Status', anime.status),
      ('Score', '${anime.averageScore ?? "N/A"}%'),
      ('Season', "${anime.season ?? '?'} ${anime.seasonYear ?? ''}"),
      ('Duration', "${anime.duration ?? '?'} min"),
      ('Source', anime.source ?? "N/A"),
      ('Start Date', _formatDate(anime.startDate)),
      ('End Date', _formatDate(anime.endDate)),
      ('Studios', anime.studios.map((e) => e.name).join(', ')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.5, // Wide and short cells
            crossAxisSpacing: 16,
            mainAxisSpacing: 8,
          ),
          itemCount: infoItems.length,
          itemBuilder: (context, index) {
            final item = infoItems[index];
            return _buildInfoTile(context, item.$1, item.$2);
          },
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    // Assuming date is a simple string or object we can stringify for now based on existing usage
    // If it requires complex parsing based on the model, we can adjust.
    // Looking at existing AnimeInfoCard, it does simple interpolation.
    if (date == null) return "?";
    return date.toString();
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    if (value.isEmpty || value == '?' || value == 'null') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(value, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
