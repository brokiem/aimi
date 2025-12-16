import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anime.dart';

class AnimeCharactersCard extends StatelessWidget {
  final Anime anime;
  final bool showHeading;

  const AnimeCharactersCard({super.key, required this.anime, this.showHeading = true});

  @override
  Widget build(BuildContext context) {
    // Determine which field contains characters
    // In Anime model it is 'characters'
    final characters = anime.characters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading)
          Text('Characters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
              children: characters.map((character) {
                final voiceActor = character.voiceActors.isNotEmpty
                    ? character.voiceActors.firstWhere(
                        (va) => va.language == 'Japanese',
                        orElse: () => character.voiceActors.first,
                      )
                    : null;
                return _CharacterCard(character: character, voiceActor: voiceActor, width: cardWidth);
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, this.voiceActor, required this.width});

  final Character character;
  final VoiceActor? voiceActor;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Maintain aspect ratio similar to original (220x200 image height)
    final imageHeight = width * 0.91; // Approximately maintains the original proportions

    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: .antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: () => _showCharacterDialog(context),
          borderRadius: BorderRadius.circular(10),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CachedNetworkImage(
                    imageUrl: character.image ?? '',
                    width: double.infinity,
                    height: imageHeight,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[800]),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.grey[800], child: const Icon(Icons.error)),
                    imageBuilder: (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    character.name ?? '',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  if (voiceActor != null)
                    Row(
                      children: [
                        CachedNetworkImage(
                          imageUrl: voiceActor!.image,
                          width: 20,
                          height: 20,
                          fit: BoxFit.cover,
                          imageBuilder: (context, imageProvider) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            voiceActor!.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.secondaryFixedDim),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCharacterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          constraints: BoxConstraints(maxWidth: 360, minHeight: 280),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Character Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: character.image ?? '',
                              height: 200,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            character.name ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Character',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.secondaryFixedDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (voiceActor != null)
                      Flexible(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: voiceActor!.image,
                                height: 200,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              voiceActor!.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Voice Actor',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.secondaryFixedDim),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              ],
            ),
          ),
        );
      },
    );
  }
}
