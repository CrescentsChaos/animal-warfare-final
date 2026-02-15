// lib/battle_tab_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/battle_manager.dart'; // Import BattleResult
import 'dart:convert';
import 'dart:math';

class BattleTabScreen extends StatefulWidget {
  const BattleTabScreen({super.key});

  @override
  State<BattleTabScreen> createState() => _BattleTabScreenState();
}

class _BattleTabScreenState extends State<BattleTabScreen> {
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganisms();
  }

  Future<void> _loadOrganisms() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      final List<dynamic> data = json.decode(response);
      setState(() {
        _allOrganisms = data.map((json) => Organism.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading organisms: $e')));
      }
    }
  }

  List<CapturedOrganism> _generateRandomTeam({bool withTalismans = false}) {
    if (_allOrganisms.isEmpty) return [];

    final random = Random();
    final List<CapturedOrganism> team = [];

    for (int i = 0; i < 5; i++) {
      final randomOrganism =
          _allOrganisms[random.nextInt(_allOrganisms.length)];
      final captured = CapturedOrganism.spawn(randomOrganism);

      // Randomly assign talisman if requested
      // Randomly assign talisman if requested (100% chance for opponents now)
      if (withTalismans) {
        if (Talisman.allTalismans.isNotEmpty) {
          final randomTalisman = Talisman
              .allTalismans[random.nextInt(Talisman.allTalismans.length)];
          team.add(captured.copyWith(equippedTalisman: randomTalisman));
        } else {
          team.add(captured);
        }
      } else {
        team.add(captured);
      }
    }

    return team;
  }

  void _startBattle({
    required List<CapturedOrganism> playerTeam,
    required List<CapturedOrganism> opponentTeam,
    required String battleTitle,
  }) async {
    if (playerTeam.isEmpty || opponentTeam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate teams!')),
      );
      return;
    }

    // Pick first animal from each team as the initial fighters
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerTeam[0],
          opponentOrganism: opponentTeam[0],
          biomeName: 'Battle Arena',
          playerTeam: playerTeam,
          opponentTeam: opponentTeam,
          battleTitle: battleTitle,
          isArenaBattle: true,
        ),
      ),
    );

    // Handle battle result if needed
    if (result != null && mounted) {
      if (battleTitle == 'Rogue-like' && result == BattleResult.win) {
        // This is handled by BattleScreen usually, but we refresh just in case
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Battle ended: $result')));
    }
  }

  void _startRogueLike(UserState userState) async {
    final user = userState.currentUser;
    if (user == null) return;

    if (user.rogueLikeState.isActive) {
      // Continue existing run
      final playerTeam = user.rogueLikeState.team;
      var opponentTeam = user.rogueLikeState.opponentTeam ?? [];
      if (opponentTeam.isEmpty) {
        opponentTeam = _generateRandomTeam(withTalismans: true);
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BattleScreen(
            playerOrganism: playerTeam[0],
            opponentOrganism: opponentTeam[0],
            biomeName: user.rogueLikeState.currentBiome ?? 'Forest',
            playerTeam: playerTeam,
            opponentTeam: opponentTeam,
            battleTitle: 'Rogue Floor ${user.rogueLikeState.floor}',
            isArenaBattle: true,
            isRogueMode: true,
          ),
        ),
      );
    } else {
      // Start new run
      // Start new run with random starter
      await userState.startRogueRun(); // Generates random starter

      if (!mounted) return;

      // Refresh user reference to get the new rogue state
      final updatedUser = userState.currentUser;
      if (updatedUser == null || !updatedUser.rogueLikeState.isActive) return;

      final playerTeam = updatedUser.rogueLikeState.team;
      final opponentTeam =
          updatedUser.rogueLikeState.opponentTeam ??
          _generateRandomTeam(withTalismans: true);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BattleScreen(
            playerOrganism: playerTeam[0],
            opponentOrganism: opponentTeam[0],
            biomeName: updatedUser.rogueLikeState.currentBiome ?? 'Forest',
            playerTeam: playerTeam,
            opponentTeam: opponentTeam,
            battleTitle: 'Rogue Floor 1',
            isArenaBattle: false,
            isRogueMode: true,
          ),
        ),
      );
    }
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    VoidCallback? onSecondaryAction,
    String? secondaryActionLabel,
  }) {
    return Card(
      elevation: 8,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.highlightColor, width: 3),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.highlightColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'PressStart2P',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (onSecondaryAction != null &&
                  secondaryActionLabel != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onSecondaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  child: Text(
                    secondaryActionLabel,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResetRun(BuildContext context, UserState userState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.primaryButtonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.highlightColor, width: 2),
        ),
        title: const Text(
          'RESET RUN?',
          style: TextStyle(
            color: AppColors.highlightColor,
            fontFamily: 'PressStart2P',
            fontSize: 16,
          ),
        ),
        content: const Text(
          'This will delete your current Roguelike progress and team forever. Are you sure?',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'PressStart2P',
            fontSize: 10,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await userState.endRogueRun();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Roguelike run reset!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'RESET',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.secondaryButtonColor,
        appBar: AppBar(
          title: const Text(
            'BATTLE',
            style: TextStyle(fontFamily: 'PressStart2P'),
          ),
          backgroundColor: AppColors.primaryButtonColor,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.highlightColor),
        ),
      );
    }

    final userState = Provider.of<UserState>(context);
    final user = userState.currentUser;

    return Scaffold(
      backgroundColor: AppColors.secondaryButtonColor,
      appBar: AppBar(
        title: const Text(
          'BATTLE ARENA',
          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
        ),
        backgroundColor: AppColors.primaryButtonColor,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.secondaryButtonColor,
              AppColors.primaryButtonColor.withOpacity(0.3),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SELECT MODE',
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'PressStart2P',
                    color: AppColors.highlightColor,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // vs AI Mode
                _buildModeCard(
                  title: 'VS AI',
                  description:
                      'Battle with your team against a randomized AI team with items!',
                  icon: Icons.psychology,
                  color: AppColors.primaryButtonColor.withOpacity(0.8),
                  onTap: () {
                    if (user == null || user.battleTeam.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please configure your battle team first!',
                          ),
                        ),
                      );
                      return;
                    }

                    final playerTeam = user.teamOrganisms;
                    final aiTeam = _generateRandomTeam(withTalismans: true);

                    _startBattle(
                      playerTeam: playerTeam,
                      opponentTeam: aiTeam,
                      battleTitle: 'vs AI',
                    );
                  },
                ),

                const SizedBox(height: 24),

                if (user != null)
                  _buildModeCard(
                    title: user.rogueLikeState.isActive
                        ? 'ROGUE: FLOOR ${user.rogueLikeState.floor}'
                        : 'ROGUE-LIKE',
                    description: user.rogueLikeState.isActive
                        ? 'CONTINUE: Resume your high-stakes run!'
                        : 'START: Randomized floors. Permadeath. High rewards! Record: Floor ${user.rogueLikeState.highestFloor}',
                    icon: Icons.vignette,
                    color: const Color(0xFF4B0082).withOpacity(0.8), // Indigo
                    onTap: () => _startRogueLike(userState),
                    onSecondaryAction: user.rogueLikeState.isActive
                        ? () => _confirmResetRun(context, userState)
                        : null,
                    secondaryActionLabel: 'RESET RUN',
                  ),

                if (user != null) const SizedBox(height: 24),

                // Randoms Mode
                _buildModeCard(
                  title: 'RANDOMS',
                  description:
                      'Both teams are completely randomized. Pure chaos!',
                  icon: Icons.shuffle,
                  color: const Color(0xFF8B0000).withOpacity(0.8),
                  onTap: () {
                    final playerTeam = _generateRandomTeam(withTalismans: true);
                    final aiTeam = _generateRandomTeam(withTalismans: true);

                    _startBattle(
                      playerTeam: playerTeam,
                      opponentTeam: aiTeam,
                      battleTitle: 'Randoms',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
