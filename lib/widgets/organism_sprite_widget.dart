// lib/widgets/organism_sprite_widget.dart
import 'package:flutter/material.dart';

/// A utility function to display an image (from network OR asset) as a solid-colored silhouette.
/// Now supports an optional outline effect.
Widget buildSilhouetteSprite({
  required String imageUrl,
  Color? silhouetteColor,
  Color? outlineColor,
  double outlineWidth = 1.0,
  String? organismName,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  final isNetworkImage =
      imageUrl.startsWith('http') || imageUrl.startsWith('https');

  final errorWidget = Container(
    width: width,
    height: height,
    color: Colors.grey.shade800,
    child: const Icon(Icons.broken_image, color: Colors.white),
  );

  Widget createImageWidget({Color? colorOverride}) {
    final image = isNetworkImage
        ? Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  color: colorOverride ?? silhouetteColor ?? Colors.white,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => errorWidget,
          )
        : Image.asset(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => errorWidget,
          );

    if (colorOverride != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(colorOverride, BlendMode.srcIn),
        child: image,
      );
    }
    return image;
  }

  final Widget mainSprite = silhouetteColor != null
      ? ColorFiltered(
          colorFilter: ColorFilter.mode(silhouetteColor, BlendMode.srcIn),
          child: createImageWidget(),
        )
      : createImageWidget();

  if (outlineColor == null) {
    return mainSprite;
  }

  // Implementation of outline using a stack of shifted silhouettes
  return Stack(
    alignment: Alignment.center,
    children: [
      // Draw the outline in 8 directions using translate for better centering
      Transform.translate(
        offset: Offset(-outlineWidth, -outlineWidth),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      Transform.translate(
        offset: Offset(outlineWidth, -outlineWidth),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      Transform.translate(
        offset: Offset(-outlineWidth, outlineWidth),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      Transform.translate(
        offset: Offset(outlineWidth, outlineWidth),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      Transform.translate(
        offset: Offset(-outlineWidth, 0),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      Transform.translate(
        offset: Offset(outlineWidth, 0),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      Transform.translate(
        offset: Offset(0, -outlineWidth),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      Transform.translate(
        offset: Offset(0, outlineWidth),
        child: createImageWidget(colorOverride: outlineColor),
      ),
      // The actual sprite
      mainSprite,
    ],
  );
}
