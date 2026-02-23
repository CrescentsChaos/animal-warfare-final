import 'package:flutter/material.dart';

class ItemIcon extends StatelessWidget {
  final String itemName;
  final double size;

  const ItemIcon({super.key, required this.itemName, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    // Convert item name to file name format:
    // "Leftovers" -> "leftovers.png"
    // "Oran Berry" -> "oran-berry.png"
    final assetName = itemName.toLowerCase().replaceAll(' ', '-');
    final assetPath = 'assets/items/$assetName.png';

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback if image not found
        return Icon(Icons.help_outline, size: size, color: Colors.grey);
      },
    );
  }
}
