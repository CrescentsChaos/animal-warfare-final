import 'package:flutter/material.dart';
import 'package:animal_warfare/theme.dart';

class PatchNotesScreen extends StatelessWidget {
  const PatchNotesScreen({super.key});

  static const Color secondaryButtonColor = AppColors.surface;
  static const Color highlightColor = AppColors.highlight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PATCH NOTES'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 16,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.8),
              BlendMode.darken,
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildVersionPadding('VERSION $kAppVersion (Current)'),
            _buildNote('• Removed cloud transition for smoother navigation'),
            _buildNote(
              '• Fixed text truncation/overlapping in Battle and Biome screens',
            ),
            _buildNote('• Improved UI responsiveness and layout scaling'),
            _buildNote('• Added haptic feedback and premium scroll physics'),
            _buildNote('• Centralized app version management'),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionPadding(String version) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        version,
        style: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
      ),
    );
  }
}
