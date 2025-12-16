import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AnimeCover extends StatelessWidget {
  final String pictureUrl;
  final double width;
  final double height;

  const AnimeCover({super.key, required this.pictureUrl, this.width = 202, this.height = 285});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: pictureUrl,
          height: height,
          width: width,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey[800]),
          errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.error)),
        ),
      ),
    );
  }
}
