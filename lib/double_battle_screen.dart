import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/double_battle_manager.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/widgets/terrain_overlay.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/game/move_animations.dart' as anims;
import 'package:animal_warfare/widgets/battle_details_sheet.dart';

class DoubleBattleScreen extends StatelessWidget {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  final String biomeName;
  final List<CapturedOrganism> playerTeam;
  final List<CapturedOrganism> opponentTeam;
  final String battleTitle;
  final bool isArenaBattle;
  final bool isRogueMode;
  final dynamic opponentArchetype; // TeamArchetype but avoiding import issues
  final bool shouldPersistResults;

  const DoubleBattleScreen({
    super.key,
    required this.playerOrganism,
    required this.opponentOrganism,
    required this.biomeName,
    required this.playerTeam,
    required this.opponentTeam,
    required this.battleTitle,
    this.isArenaBattle = false,
    this.isRogueMode = false,
    this.opponentArchetype,
    this.shouldPersistResults = true,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DoubleBattleManager(
        playerTeam: playerTeam,
        opponentTeam: opponentTeam,
        isArenaBattle: isArenaBattle,
        isRogueMode: false,
        opponentArchetype: opponentArchetype,
      ),
      child: DoubleBattleScreenContent(
        biomeName: biomeName,
        battleTitle: battleTitle,
        isArenaBattle: isArenaBattle,
        isRogueMode: isRogueMode,
      ),
    );
  }
}

class DoubleBattleScreenContent extends StatefulWidget {
  final String biomeName;
  final String? battleTitle;
  final bool isArenaBattle;
  final bool isRogueMode;

  const DoubleBattleScreenContent({
    super.key,
    required this.biomeName,
    this.battleTitle,
    this.isArenaBattle = false,
    this.isRogueMode = false,
  });

  @override
  State<DoubleBattleScreenContent> createState() =>
      _DoubleBattleScreenContentState();
}

class _DoubleBattleScreenContentState extends State<DoubleBattleScreenContent>
    with TickerProviderStateMixin {
  // Selection state
  Move? _selectedMove;
  final List<int> _selectedLeadIndices = [];

  // Animation/Feedback state
  double _screenShakeX = 0;
  double _screenShakeY = 0;

  // Animation links
  final LayerLink _player1Link = LayerLink();
  final LayerLink _player2Link = LayerLink();
  final LayerLink _opponent1Link = LayerLink();
  final LayerLink _opponent2Link = LayerLink();

  // Animation state
  final List<anims.MoveAnimData> _moveAnims = [];
  int _moveAnimIdCounter = 0;

  bool _isFastMode = false;

  Color _getBiomeThemeColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) {
      return const Color.fromARGB(255, 1, 177, 53);
    }
    if (biome.contains('desert') || biome.contains('savanna')) {
      return const Color(0xFFFFD740);
    }
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra')) {
      return const Color(0xFF40C4FF);
    }
    if (biome.contains('volcan')) return const Color(0xFFFF5252);
    if (biome.contains('mountain')) return const Color(0xFF90A4AE);
    if (biome.contains('jungle') || biome.contains('jungle')) {
      return const Color(0xFF69F0AE);
    }
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river')) {
      return const Color(0xFF448AFF);
    }
    return const Color(0xFFDAA520);
  }

  Color _getBiomePrimaryColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) return const Color(0xFF2BB900);
    if (biome.contains('desert') || biome.contains('savanna')) {
      return const Color(0xFFFFC107);
    }
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra')) {
      return const Color(0xFF00B0FF);
    }
    if (biome.contains('volcan')) return const Color(0xFFD32F2F);
    if (biome.contains('mountain')) return const Color(0xFF607D8B);
    if (biome.contains('jungle') || biome.contains('jungle')) {
      return const Color(0xFF388E3C);
    }
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river')) {
      return const Color(0xFF1976D2);
    }
    return const Color(0xFF38761D);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = Provider.of<DoubleBattleManager>(context, listen: false);
      _setupListeners(manager);
    });
  }

  void _setupListeners(DoubleBattleManager manager) {
    manager.onAttack = (attacker, move, target) {
      if (!mounted) return;
      setState(() {
        _screenShakeX = (Random().nextDouble() - 0.5) * 10;
        _screenShakeY = (Random().nextDouble() - 0.5) * 10;

        final animId = _moveAnimIdCounter++;
        final animData = anims.MoveAnimData(
          id: animId,
          move: move,
          isPlayerAttacking: attacker.isPlayer,
          attackerSlot: attacker.slotIndex,
          targetSlots: [target.slotIndex],
        );

        _moveAnims.add(animData);

        // Auto-remove animation after duration
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            setState(() {
              _moveAnims.removeWhere((a) => a.id == animId);
            });
          }
        });
      });

      // Reset screen shake after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _screenShakeX = 0;
            _screenShakeY = 0;
          });
        }
      });
    };
  }

  String _getBiomePlatform() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) return 'swamp';
    if (biome.contains('jungle') || biome.contains('forest')) return 'jungle';
    if (biome.contains('desert')) return 'sand';
    if (biome.contains('snow') || biome.contains('ice')) return 'ice';
    if (biome.contains('volcan') || biome.contains('magma')) return 'magma';
    if (biome.contains('ocean') || biome.contains('water')) return 'water';
    if (biome.contains('mountain') || biome.contains('cave')) return 'dirt';
    if (biome.contains('arena')) return 'default';
    return 'default';
  }

  String _getAssetPath(String biomeName) {
    // 1. Clean raw string & Handle multiple biomes - Take the first one
    var name = biomeName;
    if (name.contains(',')) {
      name = name.split(',')[0];
    }

    // 2. basicize
    name = name.trim().toLowerCase();

    // 3. Overrides/Fallbacks
    if (name == 'jungle') return 'assets/biomes/jungle-bg.png';
    if (name == 'rainforest') {
      return 'assets/biomes/rainforest-bg.png';
    }
    if (name == 'plains') return 'assets/biomes/savanna-bg.png';

    // 4. Asset formatting
    final fileName = name.replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<DoubleBattleManager>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Transform.translate(
        offset: Offset(_screenShakeX, _screenShakeY),
        child: Stack(
          children: [
            // Background Layer
            Positioned.fill(
              child: Image.asset(
                _getAssetPath(widget.biomeName),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),

            // Overlays
            WeatherOverlay(weather: manager.currentWeather.weather),
            TerrainOverlay(terrain: manager.currentTerrain.terrain),

            // Action UI & Participants
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, manager),
                  _buildFieldEffects(manager),
                  Expanded(child: _buildParticipantArea(manager)),
                  _buildUIControls(manager),
                ],
              ),
            ),

            // Lead Selection Overlay
            if (manager.currentState == DoubleBattleState.selectingLeads)
              _buildLeadSelectionUI(manager),

            // Target Picker Overlay
            if (_selectedMove != null) _buildTargetPickerOverlay(manager),

            // Move Animations Overlay
            ..._moveAnims.map(
              (anim) => anims.MoveAnimationOverlay(
                key: ValueKey(anim.id),
                data: anim,
                player1Link: _player1Link,
                player2Link: _player2Link,
                opponent1Link: _opponent1Link,
                opponent2Link: _opponent2Link,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DoubleBattleManager manager) {
    final userState = Provider.of<UserState>(context, listen: false);
    final rogueState = userState.currentUser?.rogueLikeState;
    final themeColor = _getBiomeThemeColor();
    final primaryColor = _getBiomePrimaryColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: themeColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Battle Title / Mode
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.battleTitle ?? 'DOUBLE BATTLE',
                      style: AppTextStyles.headline(context, baseSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isRogueMode && rogueState != null)
                      Text(
                        'Floor ${rogueState.floor} • Encounter ${rogueState.encounterIndex + 1} • ${rogueState.currentBiome}',
                        style: AppTextStyles.small(context, color: themeColor),
                      ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.history, color: themeColor, size: 20),
                    onPressed: () => _showBattleLogDialog(context, manager),
                    tooltip: 'Battle Log',
                  ),
                  IconButton(
                    icon: Icon(Icons.help_outline, color: themeColor, size: 20),
                    onPressed: () => _showHelp(context),
                    tooltip: 'Battle Help',
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, color: themeColor, size: 20),
                    onPressed: () => _showSettings(context),
                    tooltip: 'Settings',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.flag_outlined,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _confirmForfeit(context, manager),
                    tooltip: 'Forfeit',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldEffects(DoubleBattleManager manager) {
    List<Widget> effects = [];

    // Weather & Terrain
    effects.add(_buildWeatherIndicator(manager));
    effects.add(_buildTerrainIndicator(manager));

    // Player Effects
    if (manager.playerReflectTurns > 0) {
      effects.add(
        _buildFieldEffectIcon('Reflect', manager.playerReflectTurns, true),
      );
    }
    if (manager.playerLightScreenTurns > 0) {
      effects.add(
        _buildFieldEffectIcon(
          'Light Screen',
          manager.playerLightScreenTurns,
          true,
        ),
      );
    }
    if (manager.playerSafeguardTurns > 0) {
      effects.add(
        _buildFieldEffectIcon('Safeguard', manager.playerSafeguardTurns, true),
      );
    }
    if (manager.playerTailwindTurns > 0) {
      effects.add(
        _buildFieldEffectIcon('Tailwind', manager.playerTailwindTurns, true),
      );
    }
    if (manager.playerAuroraVeilTurns > 0) {
      effects.add(
        _buildFieldEffectIcon(
          'Aurora Veil',
          manager.playerAuroraVeilTurns,
          true,
        ),
      );
    }

    // Opponent Effects
    if (manager.opponentReflectTurns > 0) {
      effects.add(
        _buildFieldEffectIcon('Reflect', manager.opponentReflectTurns, false),
      );
    }
    if (manager.opponentLightScreenTurns > 0) {
      effects.add(
        _buildFieldEffectIcon(
          'Light Screen',
          manager.opponentLightScreenTurns,
          false,
        ),
      );
    }
    if (manager.opponentSafeguardTurns > 0) {
      effects.add(
        _buildFieldEffectIcon(
          'Safeguard',
          manager.opponentSafeguardTurns,
          false,
        ),
      );
    }
    if (manager.opponentTailwindTurns > 0) {
      effects.add(
        _buildFieldEffectIcon('Tailwind', manager.opponentTailwindTurns, false),
      );
    }
    if (manager.opponentAuroraVeilTurns > 0) {
      effects.add(
        _buildFieldEffectIcon(
          'Aurora Veil',
          manager.opponentAuroraVeilTurns,
          false,
        ),
      );
    }

    // Global Effects
    if (manager.trickRoomTurns > 0) {
      effects.add(
        _buildFieldEffectIcon('Trick Room', manager.trickRoomTurns, true),
      );
    }
    if (manager.gravityTurns > 0) {
      effects.add(_buildFieldEffectIcon('Gravity', manager.gravityTurns, true));
    }

    effects.removeWhere((w) => w is SizedBox);

    if (effects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: effects,
      ),
    );
  }

  Widget _buildFieldEffectIcon(String name, int turns, bool isPlayer) {
    final themeColor = _getBiomeThemeColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: isPlayer ? Colors.cyanAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 4),
          Text(
            '$name ($turns)',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherIndicator(DoubleBattleManager manager) {
    final weather = manager.currentWeather;
    if (weather.weather == Weather.none) return const SizedBox.shrink();
    return _buildFieldEffectIcon(weather.weather.name, weather.duration, true);
  }

  Widget _buildTerrainIndicator(DoubleBattleManager manager) {
    final terrain = manager.currentTerrain;
    if (terrain.terrain == Terrain.none) return const SizedBox.shrink();
    return _buildFieldEffectIcon(terrain.terrain.name, terrain.duration, true);
  }

  Widget _buildParticipantArea(DoubleBattleManager manager) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isNarrow = width < 400;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // === 3D PERSPECTIVE FLOOR ===

            // === OPPONENT HP BARS (Top) ===
            // Opponent 1 HP - top left
            if (manager.opponentSlot1 != null)
              Positioned(
                top: 0,
                left: isNarrow ? 4 : 8,
                child: GestureDetector(
                  onTap: () => _showAnimalDetails(manager.opponentSlot1!),
                  child: _buildCompactHPBar(
                    manager.opponentSlot1!,
                    isOpponent: true,
                    alignRight: false,
                    teamList: manager.opponentTeam,
                    isNarrow: isNarrow,
                  ),
                ),
              ),
            // Opponent 2 HP - top right
            if (manager.opponentSlot2 != null)
              Positioned(
                top: 0,
                right: isNarrow ? 4 : 8,
                child: GestureDetector(
                  onTap: () => _showAnimalDetails(manager.opponentSlot2!),
                  child: _buildCompactHPBar(
                    manager.opponentSlot2!,
                    isOpponent: true,
                    alignRight: true,
                    teamList: manager.opponentTeam,
                    isNarrow: isNarrow,
                  ),
                ),
              ),

            // === OPPONENT SPRITES (Back Row - smaller, higher) ===
            // Opponent 1 sprite - center-left, back
            if (manager.opponentSlot1 != null)
              Positioned(
                top: height * 0.18,
                left: width * 0.12,
                child: _buildBattlefieldSprite(
                  manager.opponentSlot1!,
                  _opponent1Link,
                  isOpponent: true,
                  scale: isNarrow ? 0.65 : 0.75,
                ),
              ),
            // Opponent 2 sprite - center-right, back
            if (manager.opponentSlot2 != null)
              Positioned(
                top: height * 0.14,
                right: width * 0.12,
                child: _buildBattlefieldSprite(
                  manager.opponentSlot2!,
                  _opponent2Link,
                  isOpponent: true,
                  scale: isNarrow ? 0.65 : 0.75,
                ),
              ),

            // === PLAYER SPRITES (Front Row - larger, lower) ===
            // Player 1 sprite - left, front
            if (manager.playerSlot1 != null)
              Positioned(
                bottom: height * 0.22,
                left: width * 0.02,
                child: _buildBattlefieldSprite(
                  manager.playerSlot1!,
                  _player1Link,
                  isOpponent: false,
                  scale: isNarrow ? 0.85 : 1.0,
                ),
              ),
            // Player 2 sprite - right, front
            if (manager.playerSlot2 != null)
              Positioned(
                bottom: height * 0.26,
                right: width * 0.02,
                child: _buildBattlefieldSprite(
                  manager.playerSlot2!,
                  _player2Link,
                  isOpponent: false,
                  scale: isNarrow ? 0.85 : 1.0,
                ),
              ),

            // === PLAYER HP BARS (Bottom) ===
            // Player 1 HP - bottom left
            if (manager.playerSlot1 != null)
              Positioned(
                bottom: 0,
                left: isNarrow ? 4 : 8,
                child: GestureDetector(
                  onTap: () => _showAnimalDetails(manager.playerSlot1!),
                  child: _buildCompactHPBar(
                    manager.playerSlot1!,
                    isOpponent: false,
                    alignRight: false,
                    teamList: manager.playerTeam,
                    isNarrow: isNarrow,
                  ),
                ),
              ),
            // Player 2 HP - bottom right
            if (manager.playerSlot2 != null)
              Positioned(
                bottom: 0,
                right: isNarrow ? 4 : 8,
                child: GestureDetector(
                  onTap: () => _showAnimalDetails(manager.playerSlot2!),
                  child: _buildCompactHPBar(
                    manager.playerSlot2!,
                    isOpponent: false,
                    alignRight: true,
                    teamList: manager.playerTeam,
                    isNarrow: isNarrow,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Builds an HP bar panel like Pokemon's separated HP boxes.
  /// Opponents show name/level + HP bar only (no numbers).
  /// Players show name/level + HP bar + HP numbers + team balls.
  Widget _buildCompactHPBar(
    BattleOrganism org, {
    required bool isOpponent,
    required bool alignRight,
    required List<CapturedOrganism> teamList,
    required bool isNarrow,
  }) {
    final maxHp = org.maxHealth;
    final hpRatio = maxHp > 0 ? org.health / maxHp : 0.0;
    final themeColor = _getBiomeThemeColor();
    final barWidth = isNarrow ? 140.0 : 165.0;

    return Container(
      width: barWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          end: alignRight ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: alignRight ? const Radius.circular(16) : Radius.zero,
          topRight: alignRight ? Radius.zero : const Radius.circular(16),
          bottomLeft: alignRight ? const Radius.circular(16) : const Radius.circular(4),
          bottomRight: alignRight ? const Radius.circular(4) : const Radius.circular(16),
        ),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name + Level row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!alignRight) ...[
                // Type icons for left-aligned
                ...org.types.take(2).map((t) => Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Image.asset(
                    t.iconPath,
                    width: 14,
                    height: 14,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.circle, color: t.color, size: 10),
                  ),
                )),
              ],
              Flexible(
                child: Text(
                  org.organism.displayName.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isNarrow ? 7 : 9,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Lv${org.organism.level}',
                style: TextStyle(
                  color: themeColor,
                  fontSize: isNarrow ? 6 : 7,
                  fontFamily: 'PressStart2P',
                ),
              ),
              if (alignRight) ...[
                const SizedBox(width: 3),
                ...org.types.take(2).map((t) => Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Image.asset(
                    t.iconPath,
                    width: 14,
                    height: 14,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.circle, color: t.color, size: 10),
                  ),
                )),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // HP label + bar
          Row(
            children: [
              Text(
                'HP',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 6,
                  fontFamily: 'PressStart2P',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    tween: Tween<double>(begin: hpRatio, end: hpRatio),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        value > 0.5
                            ? const Color(0xFF4CAF50)
                            : (value > 0.2 ? Colors.orange : Colors.red),
                      ),
                      minHeight: isNarrow ? 6 : 8,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Player HP numbers (opponents don't show exact numbers)
          if (!isOpponent) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${org.health.round()} / ${org.maxHealth}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isNarrow ? 6 : 7,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ],

          // Status effects
          if (org.statusEffects.isNotEmpty) ...[
            const SizedBox(height: 3),
            Wrap(
              spacing: 3,
              runSpacing: 2,
              alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
              children: org.statusEffects
                  .map(
                    (se) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: se.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        se.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          // Team ball indicators
          const SizedBox(height: 4),
          _buildTeamBalls(teamList, isOpponent),
        ],
      ),
    );
  }

  /// Pokeball-style team indicators showing alive/fainted/empty status
  Widget _buildTeamBalls(List<CapturedOrganism> team, bool isOpponent) {
    final maxSlots = team.length.clamp(0, 6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxSlots, (i) {
        final org = team[i];
        final isFainted = org.currentHealth <= 0;
        final Color ballColor;
        final Color borderColor;

        if (isFainted) {
          ballColor = Colors.red.shade900;
          borderColor = Colors.red.shade700;
        } else {
          ballColor = const Color(0xFF4CAF50);
          borderColor = Colors.green.shade300;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ballColor,
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: ballColor.withValues(alpha: 0.5),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Builds a sprite on a platform with shadow, used in the battlefield.
  Widget _buildBattlefieldSprite(
    BattleOrganism org,
    LayerLink link, {
    required bool isOpponent,
    double scale = 1.0,
  }) {
    final platformPath = 'assets/platforms/${_getBiomePlatform()}.png';
    final spriteSize = 110.0 * scale;
    final platformWidth = 140.0 * scale;
    final platformHeight = 40.0 * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sprite
        CompositedTransformTarget(
          link: link,
          child: GestureDetector(
            onTap: () => _showAnimalDetails(org),
            child: SizedBox(
              width: spriteSize,
              height: spriteSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/sprites/${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.help, color: Colors.white24, size: 50),
                  ),
                  if (org.health <= 0)
                    Container(
                      color: Colors.black54,
                      child: const Icon(Icons.close, color: Colors.red, size: 36),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Platform image
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(0.3),
          child: Image.asset(
            platformPath,
            width: platformWidth,
            height: platformHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildFallbackPlatform(platformWidth, platformHeight),
          ),
        ),
      ],
    );
  }

  /// Fallback elliptical platform when asset is missing
  Widget _buildFallbackPlatform(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width / 2),
        gradient: RadialGradient(
          colors: [
            _getBiomePrimaryColor().withValues(alpha: 0.6),
            _getBiomePrimaryColor().withValues(alpha: 0.2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }


  Widget _buildUIControls(DoubleBattleManager manager) {
    bool showInput =
        manager.currentState == DoubleBattleState.selectingForSlot1 ||
        manager.currentState == DoubleBattleState.selectingForSlot2;

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.0),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _buildMessageBox(
                context,
                manager.battleLog,
                false,
                expanded: !showInput,
              ),
            ),
            if (showInput && _selectedMove == null)
              _buildActionControls(
                context,
                manager,
                _getBiomeThemeColor(),
                false,
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBox(
    BuildContext context,
    String message,
    bool isNarrow, {
    bool expanded = false,
  }) {
    return GestureDetector(
      onLongPress: () => setState(() => _isFastMode = true),
      onLongPressEnd: (_) => setState(() => _isFastMode = false),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 8 : 12,
          vertical: isNarrow ? 4 : 8,
        ),
        child: Container(
          padding: EdgeInsets.all(isNarrow ? 10 : 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFastMode ? Colors.yellowAccent : _getBiomeThemeColor(),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(
                  255,
                  0,
                  0,
                  0,
                ).withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: _getBiomeThemeColor(),
                  size: isNarrow ? 16 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: expanded ? null : (isNarrow ? 50 : 70),
                  width: double.infinity,
                  alignment: Alignment.topLeft,
                  child: SingleChildScrollView(
                    reverse: false,
                    child: _TypewriterText(
                      message,
                      speed: Duration(milliseconds: _isFastMode ? 17 : 50),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isNarrow ? 10 : 12,
                        fontFamily: 'PressStart2P',
                        height: 1.2,
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

  Widget _buildActionControls(
    BuildContext context,
    DoubleBattleManager bm,
    Color themeColor,
    bool isNarrow,
  ) {
    final org = (bm.currentState == DoubleBattleState.selectingForSlot1)
        ? bm.playerSlot1!
        : bm.playerSlot2!;
    final moves = bm.getMovesFor(org);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: themeColor.withValues(alpha: 0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'CHOOSE FOR ${org.name.toUpperCase()}',
                  style: TextStyle(
                    color: themeColor,
                    fontFamily: 'PressStart2P',
                    fontSize: isNarrow ? 8 : 10,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: themeColor.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: moves.map((m) {
                      return SizedBox(
                        width: isNarrow
                            ? (constraints.maxWidth - 4) / 2
                            : (constraints.maxWidth - 8) / 2,
                        height: 52,
                        child: _buildMoveButton(bm, m, isNarrow),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed:
                          bm.currentState == DoubleBattleState.executing ||
                              bm.isProcessing
                          ? null
                          : () => _showSwitchDialog(bm),
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      label: const Text(
                        'SWITCH ANIMAL',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: themeColor.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMoveButton(DoubleBattleManager bm, Move move, bool isNarrow) {
    final org = (bm.currentState == DoubleBattleState.selectingForSlot1)
        ? bm.playerSlot1!
        : bm.playerSlot2!;
    final isLocked =
        org.isChoiceLocked &&
        org.lockedMove != null &&
        move.name != org.lockedMove!.name;

    final typeColor = move.type.color;
    final categoryText = move.category.toString().split('.').last.toUpperCase();
    final pp = org.organism.moveStamina[move.name] ?? move.stamina;

    return ElevatedButton(
      onPressed: isLocked ? null : () => _onMoveSelected(move, bm),
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${move.name} - ${move.description}')),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isLocked ? Colors.grey[700] : typeColor,
        foregroundColor: isLocked ? Colors.white24 : Colors.white,
        padding: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isLocked
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        elevation: isLocked ? 0 : 2,
        shadowColor: Colors.black,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: Image.asset(
              move.type.iconPath,
              width: isNarrow ? 24 : 32,
              height: isNarrow ? 24 : 32,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    move.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: isNarrow ? 8 : 10,
                      fontFamily: 'PressStart2P',
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(color: Colors.black, offset: Offset(-1, -1)),
                        Shadow(color: Colors.black, offset: Offset(1, -1)),
                        Shadow(color: Colors.black, offset: Offset(1, 1)),
                        Shadow(color: Colors.black, offset: Offset(-1, 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: move.category.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        categoryText.substring(0, 4),
                        style: const TextStyle(
                          fontSize: 6,
                          fontFamily: 'PressStart2P',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '$pp/${move.stamina}',
                      style: TextStyle(
                        fontSize: isNarrow ? 6 : 8,
                        fontFamily: 'PressStart2P',
                        color: pp > 0 ? Colors.white : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onMoveSelected(Move move, DoubleBattleManager manager) {
    if (move.doublesTarget == MoveTarget.bothOpponents ||
        move.doublesTarget == MoveTarget.allAdjacent ||
        move.doublesTarget == MoveTarget.self ||
        move.doublesTarget == MoveTarget.allAllies ||
        move.doublesTarget == MoveTarget.field) {
      // Auto-target moves
      DoubleTarget target = DoubleTarget.opponentSlot1; // Fallback
      if (move.doublesTarget == MoveTarget.bothOpponents) {
        target = DoubleTarget.allOpponents;
      }
      if (move.doublesTarget == MoveTarget.allAdjacent) {
        target = DoubleTarget.allOpponents;
      }
      if (move.doublesTarget == MoveTarget.self) {
        target = (manager.currentState == DoubleBattleState.selectingForSlot1)
            ? DoubleTarget.playerSlot1
            : DoubleTarget.playerSlot2;
      }

      manager.submitAction(move, target);
    } else {
      // Single target selection required
      setState(() {
        _selectedMove = move;
      });
    }
  }

  Widget _buildTargetPickerOverlay(DoubleBattleManager manager) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SELECT TARGET FOR ${_selectedMove!.name.toUpperCase()}',
              style: GoogleFonts.pressStart2p(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (manager.opponentSlot1 != null)
                  _buildTargetButton(
                    'OPP 1',
                    DoubleTarget.opponentSlot1,
                    manager,
                  ),
                const SizedBox(width: 20),
                if (manager.opponentSlot2 != null)
                  _buildTargetButton(
                    'OPP 2',
                    DoubleTarget.opponentSlot2,
                    manager,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (manager.playerSlot1 != null)
                  _buildTargetButton(
                    'ALLY 1',
                    DoubleTarget.playerSlot1,
                    manager,
                  ),
                const SizedBox(width: 20),
                if (manager.playerSlot2 != null)
                  _buildTargetButton(
                    'ALLY 2',
                    DoubleTarget.playerSlot2,
                    manager,
                  ),
              ],
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => setState(() => _selectedMove = null),
              child: Text(
                'CANCEL',
                style: GoogleFonts.pressStart2p(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetButton(
    String label,
    DoubleTarget target,
    DoubleBattleManager manager,
  ) {
    return ElevatedButton(
      onPressed: () {
        manager.submitAction(_selectedMove!, target);
        setState(() {
          _selectedMove = null;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        side: const BorderSide(color: Colors.white60),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Text(
        label,
        style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          'Battle Help',
          style: AppTextStyles.headline(context, color: Colors.blueAccent),
        ),
        content: Text(
          '• Double Battles feature 2 animals per side.\n'
          '• You can target any of the 4 active participants.\n'
          '• Speed determines turn order for all 4 animals.\n'
          '• Some moves hit both opponents or all adjacent animals.',
          style: AppTextStyles.body(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'GOT IT',
              style: TextStyle(
                color: Colors.blueAccent,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    // Placeholder for now
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings not implemented for Double Battle yet.'),
      ),
    );
  }

  void _showAnimalDetails(BattleOrganism org) async {
    await BattleDetailsSheet.show(context, org, true);
  }

  void _showBattleLogDialog(BuildContext context, DoubleBattleManager manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.blueAccent),
            const SizedBox(width: 8),
            const Text(
              'BATTLE LOG',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: manager.turnHistory.length,
            itemBuilder: (context, i) {
              final turn = manager.turnHistory[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'TURN ${turn.turnNumber}',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                      ),
                    ),
                  ),
                  ...turn.logEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Text(
                        '• $entry',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white12),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                color: Colors.blueAccent,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmForfeit(BuildContext context, DoubleBattleManager manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'Forfeit?',
          style: TextStyle(
            color: Colors.redAccent,
            fontFamily: 'PressStart2P',
            fontSize: 14,
          ),
        ),
        content: const Text(
          'Are you sure you want to forfeit this battle? This will count as a loss.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white60,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return from battle screen
            },
            child: const Text(
              'FORFEIT',
              style: TextStyle(
                color: Colors.redAccent,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadSelectionUI(DoubleBattleManager manager) {
    final themeColor = _getBiomeThemeColor();
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              'CHOOSE 2 LEAD ANIMALS',
              style: TextStyle(
                color: themeColor,
                fontFamily: 'PressStart2P',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select exactly two animals to start the battle',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.8,
                ),
                itemCount: manager.playerTeam.length,
                itemBuilder: (context, i) {
                  final org = manager.playerTeam[i];
                  final isSelected = _selectedLeadIndices.contains(i);
                  final isDead = org.currentHealth <= 0;

                  return GestureDetector(
                    onTap: (isDead)
                        ? null
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedLeadIndices.remove(i);
                              } else {
                                if (_selectedLeadIndices.length < 2) {
                                  _selectedLeadIndices.add(i);
                                }
                              }
                            });
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themeColor.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? themeColor
                              : Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: isDead ? 0.4 : 1.0,
                            child: Image.asset(
                              'assets/sprites/${org.baseOrganism.name.toLowerCase().replaceAll(' ', '_')}.png',
                              height: 60,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.help_outline,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            org.baseOrganism.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDead ? Colors.white38 : Colors.white,
                              fontFamily: 'PressStart2P',
                              fontSize: 8,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'LV ${org.level}',
                            style: TextStyle(
                              color: themeColor.withValues(alpha: 0.8),
                              fontFamily: 'PressStart2P',
                              fontSize: 7,
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
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: _selectedLeadIndices.length == 2
                    ? () {
                        manager.selectLeads(
                          _selectedLeadIndices[0],
                          _selectedLeadIndices[1],
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'READY TO FIGHT!',
                  style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSwitchDialog(DoubleBattleManager manager) {
    final themeColor = _getBiomeThemeColor();
    final bench = manager.playerBench;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PICK REPLACEMENT',
                style: TextStyle(
                  color: themeColor,
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              if (bench.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'NO ANIMALS LEFT ON BENCH!',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: bench.length,
                    itemBuilder: (context, i) {
                      final teamIdx = bench[i];
                      final org = manager.playerTeam[teamIdx];
                      return ListTile(
                        leading: Image.asset(
                          'assets/sprites/${org.baseOrganism.name.toLowerCase().replaceAll(' ', '_')}.png',
                          width: 40,
                          errorBuilder: (_, _, _) => const Icon(Icons.help),
                        ),
                        title: Text(
                          org.baseOrganism.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                          ),
                        ),
                        subtitle: Text(
                          'LV ${org.level} HP ${org.currentHealth}/${org.maxHealth}',
                          style: TextStyle(
                            color: themeColor.withValues(alpha: 0.7),
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          manager.submitSwitch(teamIdx);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;

  const _TypewriterText(
    this.text, {
    this.style,
    this.speed = const Duration(milliseconds: 50),
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayedText = "";
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      if (widget.text.startsWith(oldWidget.text) && oldWidget.text.isNotEmpty) {
        if (_timer?.isActive != true &&
            _displayedText.length < widget.text.length) {
          _startTyping();
        }
      } else {
        _displayedText = "";
        _charIndex = 0;
        _startTyping();
      }
    }
  }

  void _startTyping() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_charIndex < widget.text.length) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}

