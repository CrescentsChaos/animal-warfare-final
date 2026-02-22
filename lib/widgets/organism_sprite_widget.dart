// lib/widgets/organism_sprite_widget.dart
import 'package:flutter/material.dart';

/// A utility function to display an image (from network OR asset) as a solid-colored silhouette.
Widget buildSilhouetteSprite({
  required String imageUrl,
  required Color silhouetteColor,
  // Added optional organismName, though the path determination is done by the caller.
  String? organismName,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  // NEW LOGIC: Determine if the image should be loaded from a network or local asset
  final isNetworkImage =
      imageUrl.startsWith('http') || imageUrl.startsWith('https');

  // Common error widget
  final errorWidget = Container(
    width: width,
    height: height,
    color: Colors.grey.shade800,
    child: const Icon(Icons.broken_image, color: Colors.white),
  );

  // Function to create the base Image widget (either network or asset)
  Widget createImageWidget() {
    if (isNetworkImage) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        // Loading builder for network images
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: silhouetteColor,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    } else {
      // Use Image.asset for local files (like 'assets/sprites/...')
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        // Use the error builder to handle cases where the local asset path is incorrect/missing
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    }
  }

  // Apply the ColorFilter to the resulting Image widget
  return ColorFiltered(
    // The ColorFilter.mode constructor is used to blend a single color
    // with the child widget (your image).
    colorFilter: ColorFilter.mode(
      silhouetteColor,
      // BlendMode.srcIn uses the alpha channel of the image (the source)
      // and replaces the color with the filter color, creating a perfect silhouette.
      BlendMode.srcIn,
    ),
    child: createImageWidget(),
  );
}
