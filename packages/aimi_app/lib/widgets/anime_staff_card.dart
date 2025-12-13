import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anime.dart';

class AnimeStaffCard extends StatelessWidget {
  final Anime anime;
  final bool showHeading;

  const AnimeStaffCard({super.key, required this.anime, this.showHeading = true});

  @override
  Widget build(BuildContext context) {
    final staff = anime.staff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading)
          Text('Staff', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (showHeading) const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate how many cards can fit in a row
            // Original card width was ~220, we'll use 200 as ideal width
            const idealCardWidth = 140.0;
            const spacing = 12.0;
            final availableWidth = constraints.maxWidth;

            // Calculate number of columns
            int columns = (availableWidth / (idealCardWidth + spacing)).floor();
            columns = columns < 1 ? 1 : columns;

            // Calculate actual card width to fill the space
            final cardWidth = (availableWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: staff.map((staffMember) {
                return _StaffCard(staffMember: staffMember, width: cardWidth);
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staffMember, required this.width});

  final Staff staffMember;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Maintain aspect ratio similar to original (220x200 image height)
    final imageHeight = width * 0.91; // Approximately maintains the original proportions

    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: staffMember.image,
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[800]),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey[800], child: const Icon(Icons.error)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                staffMember.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                staffMember.role,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.secondaryFixedDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
