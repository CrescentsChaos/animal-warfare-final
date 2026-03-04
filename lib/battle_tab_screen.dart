import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/rogue/rogue_starter_select_screen.dart';
import 'package:animal_warfare/rogue/rogue_hub_screen.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/double_battle_screen.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/archetype_teams.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/ranked_screen.dart';
import 'package:google_fonts/google_fonts.dart';
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

    if (mounted && battleTitle != 'Rogue-like') {
      for (final organism in playerTeam) {
        organism.currentHealth = organism.maxHealth;
        organism.restoreAllStamina();
      }
    }

    if (result != null && mounted) {}
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

    final effectivePlayerTeam = playerTeam
        .map(
          (o) =>
              o.copyWith(level: 50, currentHealth: o.getMaxHealth(atLevel: 50)),
        )
        .toList();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DoubleBattleScreen(
          playerTeam: effectivePlayerTeam,
          opponentTeam: opponentTeam,
          biomeName: 'Rainforest',
          battleTitle: 'Random Doubles',
          opponentArchetype: opponentRes.archetype,
        ),
      ),
    );

    if (mounted) {
      for (final organism in playerTeam) {
        organism.currentHealth = organism.maxHealth;
        organism.restoreAllStamina();
      }
    }
  }

  void _startRogueLike(UserState userState) async {
    final user = userState.currentUser;
    if (user == null) return;

    if (user.rogueLikeState.isActive) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const RogueHubScreen()));
    } else {
      final firstBiome = userState.getRandomBiome();
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => RogueStarterSelectScreen(biome: firstBiome),
        ),
      );

      if (success == true && mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const RogueHubScreen()));
      }
    }
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required Color accentColor,
    VoidCallback? onSecondaryAction,
    String? secondaryActionLabel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: accentColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 28, color: accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (onSecondaryAction != null &&
                          secondaryActionLabel != null) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: onSecondaryAction,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              secondaryActionLabel,
                              style: GoogleFonts.inter(
                                color: AppColors.dangerLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: accentColor.withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmResetRun(BuildContext context, UserState userState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'RESET RUN?',
          style: TextStyle(
            color: AppColors.dangerLight,
            fontFamily: 'PressStart2P',
            fontSize: 14,
          ),
        ),
        content: Text(
          'This will permanently delete your current Roguelike progress and team. Are you sure?',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Reset',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('BATTLE')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final userState = Provider.of<UserState>(context);
    final user = userState.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BATTLE ARENA'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Text(
            'Select Mode',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // VS AI
          _buildModeCard(
            title: 'VS AI',
            description: 'Battle your team against a smart AI with items.',
            icon: Icons.psychology_rounded,
            accentColor: AppColors.primary,
            onTap: () {
              if (user == null || user.battleTeam.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configure your battle team first!'),
                  ),
                );
                return;
              }
              final aiRes = _generateRandomTeam(withTalismans: true);
              _startBattle(
                playerTeam: user.teamOrganisms,
                opponentTeam: aiRes.team,
                battleTitle: 'vs AI',
                opponentArchetype: aiRes.archetype,
              );
            },
          ),

          // Rogue-like
          if (user != null)
            _buildModeCard(
              title: user.rogueLikeState.isActive
                  ? 'ROGUE: FLOOR ${user.rogueLikeState.floor}'
                  : 'ROGUE-LIKE',
              description: user.rogueLikeState.isActive
                  ? 'Resume your high-stakes run!'
                  : 'Randomized floors. Permadeath. High rewards!\nRecord: Floor ${user.rogueLikeState.highestFloor}',
              icon: Icons.vignette_rounded,
              accentColor: const Color(0xFF9C27B0),
              onTap: () => _startRogueLike(userState),
              onSecondaryAction: user.rogueLikeState.isActive
                  ? () => _confirmResetRun(context, userState)
                  : null,
              secondaryActionLabel: 'Reset Run',
            ),

          // Randoms
          _buildModeCard(
            title: 'Randoms',
            description: 'Both teams are fully randomized. Pure chaos!',
            icon: Icons.shuffle_rounded,
            accentColor: const Color(0xFFEF5350),
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

          // Doubles
          _buildModeCard(
            title: 'Doubles Random',
            description: '2v2! Use spread moves and master doubles strategy.',
            icon: Icons.group_rounded,
            accentColor: const Color(0xFF26A69A),
            onTap: _startDoublesBattle,
          ),

          // Rankings
          _buildModeCard(
            title: 'Rankings',
            description: 'Check win rates & global ranks for every species.',
            icon: Icons.emoji_events_rounded,
            accentColor: const Color(0xFFFFB300),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RankedScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
