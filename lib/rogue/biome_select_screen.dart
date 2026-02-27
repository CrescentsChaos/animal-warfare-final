import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';

class BiomeSelectScreen extends StatefulWidget {
  const BiomeSelectScreen({super.key});

  @override
  State<BiomeSelectScreen> createState() => _BiomeSelectScreenState();
}

class _BiomeSelectScreenState extends State<BiomeSelectScreen> {
  late List<String> _options;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // generateBiomeOptions is synchronous — call directly to avoid
    // the one-frame CircularProgressIndicator flash ("ghost" state).
    final userState = Provider.of<UserState>(context, listen: false);
    _options = userState.generateBiomeOptions();
  }

  Future<void> _selectBiome(String biome) async {
    setState(() => _isLoading = true);
    final userState = Provider.of<UserState>(context, listen: false);

    await userState.advanceToNextFloor(biome);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'FLOOR CLEARED!',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    color: Colors.yellowAccent,
                    fontSize: 24,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.orange,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose the next region:',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _options.map((biome) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: _buildBiomeCard(biome),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBiomeCard(String biome) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _selectBiome(biome),
      child: Container(
        width: 140,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
          image: DecorationImage(
            image: AssetImage('assets/backgrounds/${biome.toLowerCase()}.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
            onError: (_, __) {}, // Fallback handled by color
          ),
          color: Colors.grey[800],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
            ),
          ),
          child: Center(
            child: Text(
              biome.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                color: Colors.white,
                fontSize: 14,
                shadows: [
                  Shadow(
                    blurRadius: 2,
                    color: Colors.black,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
