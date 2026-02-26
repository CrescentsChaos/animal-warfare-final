import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/double_battle_screen.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/archetype_teams.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'dart:convert';

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

  ArchetypeResult _generateRandomTeam({bool withTalismans = false}) {
    if (_allOrganisms.isEmpty) {
      return ArchetypeResult(archetype: null, archetypeName: 'Chaos', team: []);
    }

    return ArchetypeTeamBuilder.build(
      _allOrganisms,
      withTalismans: withTalismans,
      allowChaos: true,
    );
  }

  void _startBattle({
    required List<CapturedOrganism> playerTeam,
    required List<CapturedOrganism> opponentTeam,
    required String battleTitle,
    TeamArchetype? opponentArchetype,
  }) async {
    if (playerTeam.isEmpty || opponentTeam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate teams!')),
      );
      return;
    }

    // Arena auto-scaling: Scale player team to Level 50 if not Rogue
    List<CapturedOrganism> effectivePlayerTeam = playerTeam;
    if (battleTitle != 'Rogue-like' && !battleTitle.startsWith('Rogue Floor')) {
      effectivePlayerTeam = playerTeam
          .map(
            (o) => o.copyWith(
              level: 50,
              currentHealth: o.getMaxHealth(atLevel: 50),
            ),
          )
          .toList();
    }

    // Pick first animal from each team as the initial fighters
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: effectivePlayerTeam[0],
          opponentOrganism: opponentTeam[0],
          biomeName: 'Battle Arena',
          playerTeam: effectivePlayerTeam,
          opponentTeam: opponentTeam,
          battleTitle: battleTitle,
          isArenaBattle: true,
          opponentArchetype: opponentArchetype,
        ),
      ),
    );

    // Post-battle healing for non-Rogue modes
    if (mounted && battleTitle != 'Rogue-like') {
      for (final organism in playerTeam) {
        organism.currentHealth = organism.maxHealth;
        organism.restoreAllStamina();
      }
    }

    // Handle battle result if needed
    if (result != null && mounted) {
      if (battleTitle == 'Rogue-like' && result == BattleResult.win) {
        // This is handled by BattleScreen usually, but we refresh just in case
      }
    }
  }

  void _startDoublesBattle() async {
    final playerRes = _generateRandomTeam();
    final opponentRes = _generateRandomTeam(withTalismans: true);

    final playerTeam = playerRes.team;
    final opponentTeam = opponentRes.team;

    if (playerTeam.isEmpty || opponentTeam.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate teams!')),
        );
      }
      return;
    }

    // Arena auto-scaling: Scale player team to Level 50
    final effectivePlayerTeam = playerTeam
        .map(
          (o) =>
              o.copyWith(level: 50, currentHealth: o.getMaxHealth(atLevel: 50)),
        )
        .toList();

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DoubleBattleScreen(
          playerTeam: effectivePlayerTeam,
          opponentTeam: opponentTeam,
          biomeName: 'Rainforest', // Default biome for now
          battleTitle: 'Random Doubles',
          opponentArchetype: opponentRes.archetype,
        ),
      ),
    );

    // Post-battle healing for non-Rogue modes
    if (mounted) {
      for (final organism in playerTeam) {
        organism.currentHealth = organism.maxHealth;
        organism.restoreAllStamina();
      }
    }

    // Handle battle result if needed
    if (result != null && mounted) {}
  }

  void _startRogueLike(UserState userState) async {
    final user = userState.currentUser;
    if (user == null) return;

    if (user.rogueLikeState.isActive) {
      // Continue existing run
      final playerTeam = user.rogueLikeState.team;
      var opponentTeam = user.rogueLikeState.opponentTeam ?? [];
      TeamArchetype? archetype;
      if (opponentTeam.isEmpty) {
        final res = _generateRandomTeam(withTalismans: true);
        opponentTeam = res.team;
        archetype = res.archetype;
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
            opponentArchetype: archetype,
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
      final opponentRes = _generateRandomTeam(withTalismans: true);
      final opponentTeam =
          updatedUser.rogueLikeState.opponentTeam ?? opponentRes.team;
      final archetype = updatedUser.rogueLikeState.opponentTeam != null
          ? null
          : opponentRes.archetype;

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
            opponentArchetype: archetype,
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
                    final aiRes = _generateRandomTeam(withTalismans: true);

                    _startBattle(
                      playerTeam: playerTeam,
                      opponentTeam: aiRes.team,
                      battleTitle: 'vs AI',
                      opponentArchetype: aiRes.archetype,
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
                    final playerRes = _generateRandomTeam(withTalismans: true);
                    final aiRes = _generateRandomTeam(withTalismans: true);

                    _startBattle(
                      playerTeam: playerRes.team,
                      opponentTeam: aiRes.team,
                      battleTitle: 'Randoms',
                      opponentArchetype: aiRes.archetype,
                    );
                  },
                ),
                // Doubles Mode
                const SizedBox(height: 24),
                _buildModeCard(
                  title: 'Doubles Random',
                  description:
                      'Two vs two! Pick targets, use spread moves, and master doubles strategy!',
                  icon: Icons.group,
                  color: const Color(0xFF005C4B).withOpacity(0.9),
                  onTap: _startDoublesBattle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
