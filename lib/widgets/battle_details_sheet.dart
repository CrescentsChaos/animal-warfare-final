import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/widgets/anidex_details_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/widgets/type_matchup_sheet.dart';
import 'package:animal_warfare/widgets/item_icon.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/double_battle_manager.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';

class BattleDetailsSheet extends StatelessWidget {
  final BattleOrganism bo;
  final bool isPlayer;

  const BattleDetailsSheet({
    super.key,
    required this.bo,
    required this.isPlayer,
  });

  static Future<void> show(
    BuildContext context,
    BattleOrganism bo,
    bool isPlayer,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BattleDetailsSheet(bo: bo, isPlayer: isPlayer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    final org = bo.organism.baseOrganism;

    // Anidex Checks
    // Identity info (Name, Image, Types, Matchups) is always visible during battle
    bool isDiscovered = true;
    final stats = user?.speciesStats[org.name];
    bool isCaptured = (stats != null && stats['captured'] == 1);

    // If it's the player's own animal, everything is revealed
    if (isPlayer) {
      isDiscovered = true;
      isCaptured = true;
    }

    final Color themeColor = _getTypeColor(bo.types.first);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Stack(
              children: [
                // Top gradient glow
                Positioned(
                  top: -100,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 250,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          themeColor.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        radius: 1.2,
                      ),
                    ),
                  ),
                ),
                ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header Area (Sprite & Basic Info)
                    _buildHeader(
                      context,
                      org,
                      isDiscovered,
                      isCaptured,
                      themeColor,
                    ),

                    const SizedBox(height: 32),

                    // Combat Intel Section
                    _buildSectionHeader('COMBAT INTEL', themeColor),
                    const SizedBox(height: 16),
                    _buildCombatStats(org, isCaptured, themeColor),

                    const SizedBox(height: 32),

                    // Status Effects & Battle State
                    _buildSectionHeader('CONDITION', themeColor),
                    const SizedBox(height: 16),
                    _buildBattleStatus(context, themeColor),

                    const SizedBox(height: 32),

                    // Loadout (Ability & Item)
                    _buildSectionHeader('LOADOUT', themeColor),
                    const SizedBox(height: 16),
                    _buildLoadout(org, isCaptured, themeColor),

                    const SizedBox(height: 32),

                    // Arsenal (Moves)
                    _buildSectionHeader('ARSENAL', themeColor),
                    const SizedBox(height: 16),
                    _buildMoves(org, isCaptured, themeColor),

                    const SizedBox(height: 32),

                    // Description (Mission Brief)
                    _buildSectionHeader('DESCRIPTION', themeColor),
                    const SizedBox(height: 12),
                    Text(
                      isDiscovered
                          ? org.description
                          : 'DATA ENCRYPTED. FIELD IDENTIFICATION REQUIRED.',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Organism org,
    bool discovered,
    bool captured,
    Color themeColor,
  ) {
    // Tera Type Display
    Widget? teraIcon;
    if (bo.organism.teraType != null) {
      teraIcon = Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getTypeColor(bo.organism.teraType!).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getTypeColor(bo.organism.teraType!).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getTypeColor(
                bo.organism.teraType!,
              ).withValues(alpha: 0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 10),
            const SizedBox(width: 4),
            Text(
              bo.organism.teraType!.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                fontFamily: 'PressStart2P',
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Sprite with glow
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: Center(
            child: OrganismSpriteDisplay(
              organism: org,
              isDiscovered: discovered,
              isCaptured: captured,
              silhouetteColor: Colors.black,
              height: 80,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        discovered
                            ? (bo.organism.nickname ?? org.name.toUpperCase())
                            : '???',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (discovered && teraIcon != null) teraIcon,
                ],
              ),
              if (discovered && bo.organism.nickname != null)
                Text(
                  'Species: ${org.name.toUpperCase()} • HP: ${bo.health.round()}/${bo.maxHealth}',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                )
              else if (discovered)
                Text(
                  'HP: ${bo.health.round()}/${bo.maxHealth}',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 8),
              if (discovered)
                Wrap(
                  spacing: 6,
                  children: bo.types
                      .map((type) => _buildTypeTag(type))
                      .toList(),
                )
              else
                Text(
                  'LV. ${bo.level} • HP: ${bo.health.round()}/${bo.maxHealth}',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              if (discovered) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => TypeMatchupSheet.show(context, bo.types),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: themeColor,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'VIEW MATCHUPS',
                          style: GoogleFonts.outfit(
                            color: themeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeTag(ElementalType type) {
    final color = _getTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            type.iconPath,
            width: 16,
            height: 16,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Text(
            type.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontFamily: 'PressStart2P',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color themeColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: themeColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            color: themeColor.withValues(alpha: 0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCombatStats(Organism org, bool captured, Color themeColor) {
    if (!captured && !isPlayer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.white24, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'FIELD STATS ENCRYPTED. CAPTURE SPECIMEN TO REVEAL BASE DATA.',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Base stats at current level (no ability/stage modifiers)
    final baseAtk = bo.organism.effectiveAttack;
    final baseDef = bo.organism.effectiveDefense;
    final basePwr = bo.organism.effectivePower;
    final baseRes = bo.organism.effectiveResistance;
    final baseSpd = bo.organism.effectiveSpeed;

    return Column(
      children: [
        _buildStatRow(
          'HEALTH',
          bo.maxHealth,
          bo.maxHealth,
          500,
          AppColors.statHealthColor,
        ),
        _buildStatRow(
          'ATTACK',
          isPlayer ? bo.currentAttack : baseAtk,
          baseAtk,
          200,
          AppColors.statAttackColor,
        ),
        _buildStatRow(
          'DEFENSE',
          isPlayer ? bo.currentDefense : baseDef,
          baseDef,
          200,
          AppColors.statDefenseColor,
        ),
        _buildStatRow(
          'POWER',
          isPlayer ? bo.currentPower : basePwr,
          basePwr,
          200,
          AppColors.statPowerColor,
        ),
        _buildStatRow(
          'RESISTANCE',
          isPlayer ? bo.currentResistance : baseRes,
          baseRes,
          200,
          AppColors.statResistanceStatColor,
        ),
        _buildStatRow(
          'SPEED',
          isPlayer ? bo.currentSpeed : baseSpd,
          baseSpd,
          200,
          AppColors.statSpeedColor,
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    int value,
    int baseValue,
    int max,
    Color color,
  ) {
    final perc = (value / max).clamp(0.0, 1.0);
    Color valueColor = Colors.white;
    if (value > baseValue) {
      valueColor = Colors.greenAccent;
    } else if (value < baseValue) {
      valueColor = Colors.redAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: valueColor,
                  fontSize: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: perc,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleStatus(BuildContext context, Color themeColor) {
    final hpRatio = bo.maxHealth > 0 ? bo.health / bo.maxHealth : 0.0;

    // Collect Field Effects

    // Attempt to get manager from context
    BattleManager? bm;
    DoubleBattleManager? dbm;
    try {
      bm = context.read<BattleManager>();
    } catch (_) {}
    try {
      dbm = context.read<DoubleBattleManager>();
    } catch (_) {}

    final List<Map<String, dynamic>> activeField = [];

    if (bm != null) {
      if (bm.currentWeather.weather != Weather.none) {
        activeField.add({
          'name': bm.currentWeather.weather.name.toUpperCase(),
          'turns': 0,
          'icon': bm.currentWeather.weather.iconPath,
          'color': Colors.blueAccent,
        });
      }
      if (bm.currentTerrain.terrain != Terrain.none) {
        activeField.add({
          'name': bm.currentTerrain.terrain.name.toUpperCase(),
          'turns': 0,
          'icon': bm.currentTerrain.terrain.iconPath,
          'color': Colors.greenAccent,
        });
      }

      if (bm.trickRoomTurns > 0) {
        activeField.add({
          'name': 'TRICK ROOM',
          'turns': bm.trickRoomTurns,
          'icon': 'assets/icon/trick_room.png',
          'color': Colors.purpleAccent,
        });
      }

      final isPlayerSide = isPlayer;
      if (isPlayerSide) {
        if (bm.playerReflectTurns > 0) {
          activeField.add({
            'name': 'REFLECT',
            'turns': bm.playerReflectTurns,
            'icon': 'assets/icon/reflect.png',
            'color': Colors.greenAccent,
          });
        }
        if (bm.playerLightScreenTurns > 0) {
          activeField.add({
            'name': 'LIGHT SCREEN',
            'turns': bm.playerLightScreenTurns,
            'icon': 'assets/icon/light_screen.png',
            'color': Colors.greenAccent,
          });
        }
        if (bm.playerSafeguardTurns > 0) {
          activeField.add({
            'name': 'SAFEGUARD',
            'turns': bm.playerSafeguardTurns,
            'icon': 'assets/icon/safeguard.png',
            'color': Colors.greenAccent,
          });
        }
        if (bm.playerTailwindTurns > 0) {
          activeField.add({
            'name': 'TAILWIND',
            'turns': bm.playerTailwindTurns,
            'icon': 'assets/icon/tailwind.png',
            'color': Colors.greenAccent,
          });
        }
        if (bm.playerAuroraVeilTurns > 0) {
          activeField.add({
            'name': 'AURORA VEIL',
            'turns': bm.playerAuroraVeilTurns,
            'icon': 'assets/icon/aurora_veil.png',
            'color': Colors.greenAccent,
          });
        }
      } else {
        if (bm.opponentReflectTurns > 0) {
          activeField.add({
            'name': 'REFLECT',
            'turns': bm.opponentReflectTurns,
            'icon': 'assets/icon/reflect.png',
            'color': Colors.redAccent,
          });
        }
        if (bm.opponentLightScreenTurns > 0) {
          activeField.add({
            'name': 'LIGHT SCREEN',
            'turns': bm.opponentLightScreenTurns,
            'icon': 'assets/icon/light_screen.png',
            'color': Colors.redAccent,
          });
        }
        if (bm.opponentSafeguardTurns > 0) {
          activeField.add({
            'name': 'SAFEGUARD',
            'turns': bm.opponentSafeguardTurns,
            'icon': 'assets/icon/safeguard.png',
            'color': Colors.redAccent,
          });
        }
        if (bm.opponentTailwindTurns > 0) {
          activeField.add({
            'name': 'TAILWIND',
            'turns': bm.opponentTailwindTurns,
            'icon': 'assets/icon/tailwind.png',
            'color': Colors.redAccent,
          });
        }
        if (bm.opponentAuroraVeilTurns > 0) {
          activeField.add({
            'name': 'AURORA VEIL',
            'turns': bm.opponentAuroraVeilTurns,
            'icon': 'assets/icon/aurora_veil.png',
            'color': Colors.redAccent,
          });
        }
      }
    } else if (dbm != null) {
      if (dbm.currentWeather.weather != Weather.none) {
        activeField.add({
          'name': dbm.currentWeather.weather.name.toUpperCase(),
          'turns': 0,
          'icon': dbm.currentWeather.weather.iconPath,
          'color': Colors.blueAccent,
        });
      }
      if (dbm.currentTerrain.terrain != Terrain.none) {
        activeField.add({
          'name': dbm.currentTerrain.terrain.name.toUpperCase(),
          'turns': 0,
          'icon': dbm.currentTerrain.terrain.iconPath,
          'color': Colors.greenAccent,
        });
      }

      if (dbm.trickRoomTurns > 0) {
        activeField.add({
          'name': 'TRICK ROOM',
          'turns': dbm.trickRoomTurns,
          'icon': 'assets/icon/trick_room.png',
          'color': Colors.purpleAccent,
        });
      }

      final isPlayerSide = isPlayer;
      if (isPlayerSide) {
        if (dbm.playerReflectTurns > 0) {
          activeField.add({
            'name': 'REFLECT',
            'turns': dbm.playerReflectTurns,
            'icon': 'assets/icon/reflect.png',
            'color': Colors.greenAccent,
          });
        }
        if (dbm.playerLightScreenTurns > 0) {
          activeField.add({
            'name': 'LIGHT SCREEN',
            'turns': dbm.playerLightScreenTurns,
            'icon': 'assets/icon/light_screen.png',
            'color': Colors.greenAccent,
          });
        }
        if (dbm.playerSafeguardTurns > 0) {
          activeField.add({
            'name': 'SAFEGUARD',
            'turns': dbm.playerSafeguardTurns,
            'icon': 'assets/icon/safeguard.png',
            'color': Colors.greenAccent,
          });
        }
        if (dbm.playerTailwindTurns > 0) {
          activeField.add({
            'name': 'TAILWIND',
            'turns': dbm.playerTailwindTurns,
            'icon': 'assets/icon/tailwind.png',
            'color': Colors.greenAccent,
          });
        }
        if (dbm.playerAuroraVeilTurns > 0) {
          activeField.add({
            'name': 'AURORA VEIL',
            'turns': dbm.playerAuroraVeilTurns,
            'icon': 'assets/icon/aurora_veil.png',
            'color': Colors.greenAccent,
          });
        }
      } else {
        if (dbm.opponentReflectTurns > 0) {
          activeField.add({
            'name': 'REFLECT',
            'turns': dbm.opponentReflectTurns,
            'icon': 'assets/icon/reflect.png',
            'color': Colors.redAccent,
          });
        }
        if (dbm.opponentLightScreenTurns > 0) {
          activeField.add({
            'name': 'LIGHT SCREEN',
            'turns': dbm.opponentLightScreenTurns,
            'icon': 'assets/icon/light_screen.png',
            'color': Colors.redAccent,
          });
        }
        if (dbm.opponentSafeguardTurns > 0) {
          activeField.add({
            'name': 'SAFEGUARD',
            'turns': dbm.opponentSafeguardTurns,
            'icon': 'assets/icon/safeguard.png',
            'color': Colors.redAccent,
          });
        }
        if (dbm.opponentTailwindTurns > 0) {
          activeField.add({
            'name': 'TAILWIND',
            'turns': dbm.opponentTailwindTurns,
            'icon': 'assets/icon/tailwind.png',
            'color': Colors.redAccent,
          });
        }
        if (dbm.opponentAuroraVeilTurns > 0) {
          activeField.add({
            'name': 'AURORA VEIL',
            'turns': dbm.opponentAuroraVeilTurns,
            'icon': 'assets/icon/aurora_veil.png',
            'color': Colors.redAccent,
          });
        }
      }
    }

    return Column(
      children: [
        // Current HP (Numbers hidden for opponent as per user request)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'VITALITY',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPlayer)
              Text(
                '${bo.health}/${bo.maxHealth}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  color: Colors.white70,
                  fontSize: 8,
                ),
              )
            else
              Text(
                '${(hpRatio * 100).toInt()}%',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: hpRatio,
            minHeight: 12,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            color: _getHpColor(hpRatio),
          ),
        ),
        const SizedBox(height: 20),

        // Status Effects
        if (bo.statusEffects.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bo.statusEffects
                .map((se) => _buildStatusTag(se))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Field Status
        if (activeField.isNotEmpty) ...[
          const Row(
            children: [
              Text(
                'FIELD STATUS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeField.map((f) => _buildFieldStatusTag(f)).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Stat Stages
        _buildStatModifiers(themeColor),
      ],
    );
  }

  Widget _buildFieldStatusTag(Map<String, dynamic> f) {
    final Color color = f['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            f['icon'],
            width: 14,
            height: 14,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.help, size: 14, color: Colors.white24),
          ),
          const SizedBox(width: 8),
          Text(
            f['name'],
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'PressStart2P',
            ),
          ),
          if (f['turns'] > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${f['turns']}T',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontFamily: 'PressStart2P',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusTag(StatusEffect se) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: se.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: se.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            se.name.toUpperCase(),
            style: TextStyle(
              color: se.color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            se.description,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStatModifiers(Color themeColor) {
    final List<MapEntry<String, int>> stages = [
      MapEntry('ATK', bo.attackStage),
      MapEntry('DEF', bo.defenseStage),
      MapEntry('PWR', bo.powerStage),
      MapEntry('RES', bo.resistanceStage),
      MapEntry('SPD', bo.speedStage),
      MapEntry('ACC', bo.accuracyStage),
      MapEntry('EVA', bo.evasionStage),
    ].where((e) => e.value != 0).toList();

    if (stages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BATTLE MODIFIERS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stages.map((e) {
            final color = e.value > 0 ? Colors.greenAccent : Colors.redAccent;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.value > 0 ? '+' : ''}${e.value}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getHpColor(double ratio) {
    if (ratio > 0.5) return const Color(0xFF4CAF50);
    if (ratio > 0.2) return Colors.orange;
    return Colors.red;
  }

  Color _getTypeColor(ElementalType type) {
    switch (type) {
      case ElementalType.basic:
        return const Color(0xFFA8A878);
      case ElementalType.flying:
        return const Color(0xFFA890F0);
      case ElementalType.aquatic:
        return const Color(0xFF6890F0);
      case ElementalType.earth:
        return const Color(0xFFE0C068);
      case ElementalType.cryo:
        return const Color(0xFF98D8D8);
      case ElementalType.toxic:
        return const Color(0xFFA040A0);
      case ElementalType.rock:
        return const Color(0xFFB8A038);
      case ElementalType.arthropod:
        return const Color(0xFFA8B820);
      case ElementalType.electric:
        return const Color(0xFFF8D030);
      case ElementalType.spectral:
        return const Color(0xFF705898);
      case ElementalType.martial:
        return const Color(0xFFC03028);
      case ElementalType.blaze:
        return const Color(0xFFF08030);
      case ElementalType.grass:
        return const Color(0xFF78C850);
      case ElementalType.mystic:
        return const Color(0xFFF85888);
      case ElementalType.darkness:
        return const Color(0xFF705848);
      case ElementalType.drake:
        return const Color(0xFF7038F8);
      case ElementalType.metal:
        return const Color(0xFFB8B8D0);
      case ElementalType.aura:
        return const Color(0xFFD4E157);
      case ElementalType.sound:
        return const Color(0xFF9C27B0);
      case ElementalType.holy:
        return const Color(0xFFFFD700);
    }
  }

  // _getTypeIcon was used for old IconData icons - removing in favor of direct Image.asset usage

  Widget _buildLoadout(Organism org, bool captured, Color themeColor) {
    if (!captured && !isPlayer) {
      return _buildLockedSection('ABILITY & ITEM DATA ENCRYPTED');
    }

    return Column(
      children: [
        _buildInfoTile(
          'ABILITY',
          bo.abilities.isNotEmpty
              ? bo.abilities.first.name.toUpperCase()
              : 'NONE',
          bo.abilities.isNotEmpty
              ? bo.abilities.first.description
              : 'NO ABILITY DETECTED.',
          Icon(Icons.auto_awesome_outlined, color: themeColor, size: 24),
          themeColor,
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          'HELD ITEM',
          bo.organism.equippedTalisman?.name.toUpperCase() ?? 'NONE',
          bo.organism.equippedTalisman?.description ?? 'NO HELD ITEM DETECTED.',
          bo.organism.equippedTalisman != null
              ? ItemIcon(itemName: bo.organism.equippedTalisman!.name, size: 24)
              : Icon(Icons.inventory_2_outlined, color: themeColor, size: 24),
          themeColor,
        ),
      ],
    );
  }

  Widget _buildMoves(Organism org, bool captured, Color themeColor) {
    final moves = bo.organism.selectedMoveNames
        .map((name) => Move.findByName(name))
        .whereType<Move>()
        .where((move) {
          if (isPlayer || captured) return true;
          return bo.revealedMoves.contains(move.name);
        })
        .toList();

    if (moves.isEmpty && !isPlayer && !captured) {
      return _buildLockedSection('NO MOVES REVEALED YET.');
    }

    return Column(
      children: moves.map((move) {
        final currentStamina = bo.organism.moveStamina[move.name] ?? 0;
        final maxStamina = move.stamina;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTypeColor(move.type).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    move.type.iconPath,
                    width: 18,
                    height: 18,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.category,
                      color: _getTypeColor(move.type),
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        move.name.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${move.category.name.toUpperCase()} | PWR: ${move.baseDamage} | STAMINA: $currentStamina/$maxStamina',
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        move.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoTile(
    String label,
    String title,
    String subtitle,
    Widget iconWidget,
    Color themeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(width: 32, height: 32, child: Center(child: iconWidget)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    color: themeColor.withValues(alpha: 0.6),
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedSection(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white24, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
