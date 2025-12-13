import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/anime.dart';

class AnimeHeader extends StatefulWidget {
  final Anime anime;

  const AnimeHeader({super.key, required this.anime});

  @override
  State<AnimeHeader> createState() => _AnimeHeaderState();
}

class _AnimeHeaderState extends State<AnimeHeader> {
  bool _isExpanded = false;
  bool _isOverflowing = false;
  final int _maxLines = 6;

  @override
  Widget build(BuildContext context) {
    final descriptionStyle = GoogleFonts.inter(
      fontSize: 14,
      height: 1.5,
      color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((255 * 0.8).round()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.anime.title.english ?? widget.anime.title.romaji ?? '',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final textPainter = TextPainter(
              text: TextSpan(text: widget.anime.description, style: descriptionStyle),
              maxLines: _maxLines,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _isOverflowing != textPainter.didExceedMaxLines) {
                setState(() {
                  _isOverflowing = textPainter.didExceedMaxLines;
                });
              }
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.anime.description,
                  maxLines: _isExpanded ? null : _maxLines,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                  style: descriptionStyle,
                ),
                if (_isOverflowing)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Text(
                      _isExpanded ? 'Read less' : 'Read more',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
