import 'package:flutter/material.dart';

class PatchNotesScreen extends StatelessWidget {
  const PatchNotesScreen({super.key});

  static const Color secondaryButtonColor = Color(0xFF1E3F2A);
  static const Color highlightColor = Color(0xFFDAA520);

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
              Colors.black.withOpacity(0.8),
              BlendMode.darken,
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildVersionPadding('VERSION 0.1.2 (Current)'),
            _buildNote('• Added Audio Volume & Mute Controls'),
            _buildNote('• Added Contact Developer & Bug Report options'),
            _buildNote('• Implemented Patch Notes section'),

            const SizedBox(height: 30),
            _buildVersionPadding('VERSION 0.1.1'),
            _buildNote('• Fixed HP Scaling in Wild/Arena battles'),
            _buildNote('• Improved Battle Log precision (1 decimal place)'),
            _buildNote('• Optimized Battle Organism initialization'),
            _buildNote(
              '• Consolidated damage logging to remove double entries',
            ),

            const SizedBox(height: 30),
            _buildVersionPadding('VERSION 0.1.0'),
            _buildNote('• Initial release of Animal Warfare'),
            _buildNote('• 100+ Unique Organisms to discover'),
            _buildNote('• Turn-based battle system with status effects'),
            _buildNote('• Biome-based encounters'),
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
