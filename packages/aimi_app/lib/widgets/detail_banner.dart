import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class DetailBanner extends StatelessWidget {
  final String pictureUrl;
  final double height;

  const DetailBanner({super.key, required this.pictureUrl, this.height = 280});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pictureUrl.isNotEmpty)
              Transform.scale(
                scale: 1.1,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: CachedNetworkImage(
                    imageUrl: pictureUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[800]),
                    errorWidget: (context, url, error) => Container(color: Colors.grey[800]),
                  ),
                ),
              )
            else
              Container(color: Colors.grey[800]),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.topLeft,
                  colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
