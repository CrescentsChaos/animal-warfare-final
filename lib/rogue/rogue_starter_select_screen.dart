import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/data/biome_data.dart';
import 'package:animal_warfare/widgets/animal_summary_screen.dart';

class RogueStarterSelectScreen extends StatefulWidget {
  final String biome;

  const RogueStarterSelectScreen({super.key, required this.biome});

  @override
  State<RogueStarterSelectScreen> createState() =>
      _RogueStarterSelectScreenState();
}

class _RogueStarterSelectScreenState extends State<RogueStarterSelectScreen> {
  List<CapturedOrganism>? _options;
  int? _selectedIndex;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userState = Provider.of<UserState>(context, listen: false);
      setState(() {
        _options = userState.generateStarterOptions(widget.biome);
      });
    });
  }

  void _onStart() async {
    if (_selectedIndex == null || _options == null) return;
    setState(() => _isStarting = true);

    final userState = Provider.of<UserState>(context, listen: false);
    await userState.startRogueRun(
      starter: _options![_selectedIndex!],
      biome: widget.biome,
    );

    if (mounted) {
      Navigator.pop(context, true); // Success
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = BiomeData.colorFor(widget.biome);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [themeColor.withOpacity(0.3), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'CHOOSE YOUR STARTER',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'REGION: ${widget.biome.toUpperCase()}',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: themeColor,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 40),
              if (_options == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _options!.length,
                    itemBuilder: (context, index) {
                      final org = _options![index];
                      final isSelected = _selectedIndex == index;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? themeColor.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? themeColor : Colors.white10,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/sprites/${org.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                                width: 80,
                                height: 80,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.pets,
                                  size: 40,
                                  color: Colors.white24,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      org.baseOrganism.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'PressStart2P',
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      org.baseOrganism.types
                                          .join(' / ')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'PressStart2P',
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatRow(
                                      'HP',
                                      org.maxHealth,
                                      themeColor,
                                    ),
                                    _buildStatRow(
                                      'ATK',
                                      org.getAttack(),
                                      themeColor,
                                    ),
                                    _buildStatRow(
                                      'DEF',
                                      org.getDefense(),
                                      themeColor,
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: org.selectedMoveNames.map((
                                        move,
                                      ) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            move.toUpperCase(),
                                            style: const TextStyle(
                                              fontFamily: 'PressStart2P',
                                              color: Colors.white70,
                                              fontSize: 6,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (ctx) =>
                                                AnimalSummaryScreen(
                                                  captured: org,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Colors.orangeAccent,
                                      ),
                                      label: const Text(
                                        'SUMMARY',
                                        style: TextStyle(
                                          fontFamily: 'PressStart2P',
                                          fontSize: 8,
                                          color: Colors.orangeAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedIndex != null && !_isStarting
                        ? _onStart
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isStarting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'CONFIRM SELECTION',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                color: Colors.white24,
                fontSize: 8,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value / 100, // Normalized for visual
                backgroundColor: Colors.white10,
                color: color.withOpacity(0.8),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
