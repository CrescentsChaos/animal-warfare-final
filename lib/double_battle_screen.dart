// lib/double_battle_screen.dart
//
// UI screen for the 2v2 Doubles battle format.
// Two sprites per side, dual HP bars, slot-by-slot move selection, and target
// selection dialog for single-target moves.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:provider/provider.dart';
import 'package:animal_warfare/game/double_battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';

// ════════════════════════════════════════════════════════════
// Type color helper
// ════════════════════════════════════════════════════════════

Color _typeColor(ElementalType t) {
  switch (t) {
    case ElementalType.blaze:
      return const Color(0xFFFF6F00);
    case ElementalType.aquatic:
      return const Color(0xFF0288D1);
    case ElementalType.electric:
      return const Color(0xFFFDD835);
    case ElementalType.grass:
      return const Color(0xFF388E3C);
    case ElementalType.earth:
      return const Color(0xFF8D6E63);
    case ElementalType.cryo:
      return const Color(0xFF80DEEA);
    case ElementalType.rock:
      return const Color(0xFF9E9E9E);
    case ElementalType.flying:
      return const Color(0xFF90CAF9);
    case ElementalType.toxic:
      return const Color(0xFF7B1FA2);
    case ElementalType.darkness:
      return const Color(0xFF37474F);
    case ElementalType.metal:
      return const Color(0xFF546E7A);
    case ElementalType.martial:
      return const Color(0xFFBF360C);
    case ElementalType.mystic:
      return const Color(0xFFE91E63);
    case ElementalType.spectral:
      return const Color(0xFF7E57C2);
    case ElementalType.drake:
      return const Color(0xFF4A148C);
    case ElementalType.aura:
      return const Color(0xFFF48FB1);
    case ElementalType.arthropod:
      return const Color(0xFF827717);
    case ElementalType.sound:
      return const Color(0xFF00BCD4);
    default:
      return const Color(0xFF78909C);
  }
}

// ════════════════════════════════════════════════════════════
// Entry widget
// ════════════════════════════════════════════════════════════

class DoubleBattleScreen extends StatelessWidget {
  final List<CapturedOrganism> playerTeam;
  final List<CapturedOrganism> opponentTeam;
  final String biomeName;
  final String? battleTitle;
  final TeamArchetype? opponentArchetype;

  const DoubleBattleScreen({
    super.key,
    required this.playerTeam,
    required this.opponentTeam,
    required this.biomeName,
    this.battleTitle,
    this.opponentArchetype,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DoubleBattleManager(
        playerTeam: playerTeam,
        opponentTeam: opponentTeam,
        opponentArchetype: opponentArchetype,
      ),
      child: _DoubleBattleView(biomeName: biomeName, battleTitle: battleTitle),
    );
  }

  static Color getBiomePrimaryColor(String biome) {
    final b = biome.toLowerCase();
    if (b.contains('swamp')) return const Color(0xFF2BB900);
    if (b.contains('desert')) return const Color(0xFFD4A017);
    if (b.contains('forest')) return const Color(0xFF2E7D32);
    if (b.contains('ocean') || b.contains('lake'))
      return const Color(0xFF0277BD);
    if (b.contains('mountain')) return const Color(0xFF757575);
    if (b.contains('ice') || b.contains('tundra'))
      return const Color(0xFF80DEEA);
    if (b.contains('volcan')) return const Color(0xFFD32F2F);
    return const Color(0xFF2BB900); // Default
  }

  static Color getBiomeSecondaryColor(String biome) {
    return const Color(0xFF161B22); // Consistent dark grey
  }

  static Color getBiomeThemeColor(String biome) {
    final b = biome.toLowerCase();
    if (b.contains('swamp')) return const Color(0xFF4ADE80);
    if (b.contains('desert')) return const Color(0xFFFFD700);
    if (b.contains('forest')) return const Color(0xFF81C784);
    if (b.contains('ocean') || b.contains('lake'))
      return const Color(0xFFB3E5FC);
    if (b.contains('ice') || b.contains('tundra'))
      return const Color(0xFFE0F7FA);
    if (b.contains('volcan')) return const Color(0xFFFF8A65);
    return const Color(0xFF4ADE80);
  }

  static void showOrganismInfo(
    BuildContext context,
    BattleOrganism bo, {
    DoubleBattleManager? bm,
    required Color primaryColor,
    required Color secondaryColor,
    required Color themeColor,
  }) {
    final base = bo.organism.baseOrganism;
    final isPlayer =
        bm != null &&
        (bm.playerSlot1 == bo ||
            bm.playerSlot2 == bo ||
            bm.playerTeam.any((p) => p == bo.organism));

    // We need to get biome colors if bm is available (it should be)
    // For now we'll use a default if we can't find a better way,
    // but the user wants "identical".
    // Since this is static, we can try to look up the biome name if we pass it,
    // or just use high-quality defaults.
    const primaryColor = Color(0xFF2BB900); // Default to Swamp-like
    const secondaryColor = Color(0xFF161B22);
    const themeColor = Color(0xFF4ADE80);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: secondaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: themeColor, width: 2),
        ),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor.withValues(alpha: 0.8), secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Text(
            base.name,
            style: const TextStyle(
              color: themeColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      'CATEGORY: ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: base.category.toUpperCase().split(',').map((
                        cat,
                      ) {
                        final typeStr = cat.trim().toLowerCase();
                        final type = ElementalType.values.firstWhere(
                          (e) => e.toString().split('.').last == typeStr,
                          orElse: () => ElementalType.basic,
                        );
                        final typeColor = _typeColor(type);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cat.trim().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontFamily: 'PressStart2P',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tera Type
              if (bo.organism.teraType != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    children: [
                      const Text(
                        'TERA TYPE: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bo.organism.teraType!.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          bo.organism.teraType!.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontFamily: 'PressStart2P',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Nature
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    const Text(
                      'NATURE: ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    Text(
                      bo.organism.nature.name.toUpperCase(),
                      style: const TextStyle(
                        color: themeColor,
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Ability
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ABILITY: ${bo.abilities.isNotEmpty ? bo.abilities.first.name.toUpperCase() : "NONE"}',
                      style: const TextStyle(
                        color: themeColor,
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (bo.abilities.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        bo.abilities.first.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontFamily: 'PressStart2P',
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // HP Section
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'HP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    Text(
                      '${bo.health}/${bo.maxHealth}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontFamily: 'PressStart2P',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Stats & Boosts
              const Text(
                'STATS & BOOSTS',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 9,
                  fontFamily: 'PressStart2P',
                ),
              ),
              const SizedBox(height: 6),
              _buildStatRow(
                'ATK',
                isPlayer ? '${bo.currentAttack}' : '???',
                bo.attackStage,
                Colors.orange,
              ),
              _buildStatRow(
                'DEF',
                isPlayer ? '${bo.currentDefense}' : '???',
                bo.defenseStage,
                Colors.blue,
              ),
              _buildStatRow(
                'PWR',
                isPlayer ? '${bo.currentPower}' : '???',
                bo.powerStage,
                Colors.purple,
              ),
              _buildStatRow(
                'RES',
                isPlayer ? '${bo.currentResistance}' : '???',
                bo.resistanceStage,
                Colors.teal,
              ),
              _buildStatRow(
                'SPD',
                isPlayer ? '${bo.currentSpeed}' : '???',
                bo.speedStage,
                Colors.yellow,
              ),

              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),

              // Status Effects
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STATUS: ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                  if (bo.statusEffects.isEmpty)
                    const Text(
                      "NONE",
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                      ),
                    )
                  else
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: bo.statusEffects
                            .map(
                              (se) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: se.color.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: se.color),
                                ),
                                child: Text(
                                  se.name.toUpperCase(),
                                  style: TextStyle(
                                    color: se.color,
                                    fontSize: 9,
                                    fontFamily: 'PressStart2P',
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),

              // Revealed Moves (Opponent Only)
              if (!isPlayer && bm != null) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
                const Text(
                  'REVEALED MOVES',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 9,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                const SizedBox(height: 6),
                if (bm.battleStats[bo.organism.id]?.revealedMoves.isEmpty ??
                    true)
                  const Text(
                    'NONE',
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 9,
                      fontFamily: 'PressStart2P',
                    ),
                  )
                else
                  ...bm.battleStats[bo.organism.id]!.revealedMoves.map((m) {
                    final move = Move.findByName(m);
                    final displayType = move != null
                        ? bm.getDisplayType(bo, move)
                        : ElementalType.basic;
                    final curStam = bo.organism.moveStamina[m] ?? 0;
                    final maxStam = move?.stamina ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                m.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontFamily: 'PressStart2P',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _typeColor(displayType),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  displayType.name.toUpperCase().substring(
                                    0,
                                    3,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 5,
                                    fontFamily: 'PressStart2P',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$curStam/$maxStam',
                            style: TextStyle(
                              color: curStam == 0
                                  ? Colors.red
                                  : (curStam < maxStam / 2
                                        ? Colors.orange
                                        : Colors.white70),
                              fontSize: 7,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ] else if (isPlayer) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
                const Text(
                  'MOVES',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 9,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                const SizedBox(height: 6),
                ...bo.organism.selectedMoveNames.map((m) {
                  final move = Move.findByName(m);
                  final displayType = move != null
                      ? bm.getDisplayType(bo, move)
                      : ElementalType.basic;
                  final curStam = bo.organism.moveStamina[m] ?? 0;
                  final maxStam = move?.stamina ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              m.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontFamily: 'PressStart2P',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _typeColor(displayType),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                displayType.name.toUpperCase().substring(0, 3),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 5,
                                  fontFamily: 'PressStart2P',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$curStam/$maxStam',
                          style: TextStyle(
                            color: curStam == 0
                                ? Colors.red
                                : (curStam < maxStam / 2
                                      ? Colors.orange
                                      : Colors.white70),
                            fontSize: 7,
                            fontFamily: 'PressStart2P',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: themeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatRow(
    String label,
    String value,
    int boost,
    Color color,
  ) {
    final boostStr = boost >= 0 ? '+$boost' : '$boost';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                boostStr,
                style: TextStyle(
                  color: boost > 0
                      ? Colors.green
                      : (boost < 0 ? Colors.red : Colors.white24),
                  fontSize: 8,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ],
          ),
          if (value != '???')
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontFamily: 'PressStart2P',
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Main View
// ════════════════════════════════════════════════════════════

class _DoubleBattleView extends StatefulWidget {
  final String biomeName;
  final String? battleTitle;
  const _DoubleBattleView({required this.biomeName, this.battleTitle});

  @override
  State<_DoubleBattleView> createState() => _DoubleBattleViewState();
}

class _DoubleBattleViewState extends State<_DoubleBattleView>
    with TickerProviderStateMixin {
  Move? _selectedMove;
  bool _isTargeting = false;
  bool _isSwitchDialogShowing = false;

  // Screen Shake Animations
  late AnimationController _screenShakeController;
  late Animation<double> _screenShakeAnimation;

  // Gimmick Banner State
  bool _showGimmickBanner = false;
  String? _activeGimmickType;
  BattleOrganism? _gimmickTarget;

  @override
  void initState() {
    super.initState();
    _screenShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _screenShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(_screenShakeController);

    // Set up DoubleBattleManager triggers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bm = context.read<DoubleBattleManager>();
      bm.addListener(_handleStateTriggers);
    });
  }

  @override
  void dispose() {
    final bm = context.read<DoubleBattleManager>();
    bm.removeListener(_handleStateTriggers);
    _screenShakeController.dispose();
    super.dispose();
  }

  void _handleStateTriggers() {
    if (!mounted) return;
    final bm = context.read<DoubleBattleManager>();

    // Handle pending gimmick activation (set by DoubleBattleManager, cleared here)
    if (bm.pendingGimmickType != null && bm.pendingGimmickTarget != null) {
      final type = bm.pendingGimmickType!;
      final target = bm.pendingGimmickTarget!;
      bm.pendingGimmickType = null;
      bm.pendingGimmickTarget = null;

      // SAFE LISTENER PATTERN: Wrap UI updates in a frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onGimmickActivation(target, type);
      });
    }
  }

  void _onGimmickActivation(BattleOrganism target, String type) {
    setState(() {
      _activeGimmickType = type;
      _gimmickTarget = target;
      _showGimmickBanner = true;
    });

    // Vibration feedback
    HapticFeedback.heavyImpact();

    // Trigger screen shake
    _screenShakeController.forward(from: 0);

    // Hide banner after duration
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showGimmickBanner = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bm = context.watch<DoubleBattleManager>();
    final themeColor = _getBiomeThemeColor();
    final primaryColor = _getBiomePrimaryColor();
    final bgPath = _getBiomeBackground();

    // Auto-show switch dialog if needed
    if (bm.currentState == DoubleBattleState.waitingForSwitch &&
        !_isSwitchDialogShowing) {
      _isSwitchDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSwitchDialog(context, bm).then((_) {
          if (mounted) {
            setState(() {
              _isSwitchDialogShowing = false;
            });
          }
        });
      });
    }

    return Scaffold(
      backgroundColor: Colors.black, // Pure black background behind everything
      body: AnimatedBuilder(
        animation: _screenShakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _screenShakeAnimation.value),
            child: child,
          );
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(bgPath),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.35),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Header integrated with background
                  _buildHeader(context, bm, themeColor),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // ── Opponent Rows ──
                          _buildRow(
                            context,
                            bm.opponentSlot1,
                            isPlayerSide: false,
                            isSecond: false,
                            target: DoubleTarget.opponentSlot1,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 32), // Offset
                            child: _buildRow(
                              context,
                              bm.opponentSlot2,
                              isPlayerSide: false,
                              isSecond: true,
                              target: DoubleTarget.opponentSlot2,
                              primaryColor: primaryColor,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Player Rows ──
                          _buildRow(
                            context,
                            bm.playerSlot1,
                            isPlayerSide: true,
                            isSecond: false,
                            target: DoubleTarget.playerSlot1,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 32), // Offset
                            child: _buildRow(
                              context,
                              bm.playerSlot2,
                              isPlayerSide: true,
                              isSecond: true,
                              target: DoubleTarget.playerSlot2,
                              primaryColor: primaryColor,
                            ),
                          ),

                          const SizedBox(height: 24),
                          _ActionPanel(
                            bm: bm,
                            biomeName: widget.biomeName,
                            onMoveSelected: _onMoveTapped,
                            onSwitchTapped: () =>
                                _showSwitchDialog(context, bm),
                            isTargeting: _isTargeting,
                            selectedMove: _selectedMove,
                            onCancelTargeting: () {
                              setState(() {
                                _isTargeting = false;
                                _selectedMove = null;
                              });
                            },
                          ),
                          // Padding at the bottom for navigation bar
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Gimmick Banner Overlay
            if (_showGimmickBanner)
              _GimmickBanner(
                type: _activeGimmickType ?? 'gimmick',
                targetName: _gimmickTarget?.name ?? '',
                color: _activeGimmickType == 'titanize'
                    ? Colors.redAccent
                    : _typeColor(
                        _gimmickTarget?.activeTeraType ?? ElementalType.basic,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  void _onMoveTapped(Move move, DoubleBattleManager bm) {
    // Set interactive targeting state
    setState(() {
      _selectedMove = move;
      _isTargeting = true;
    });
  }

  void _onTargetSelected(DoubleTarget target, DoubleBattleManager bm) {
    if (_selectedMove != null) {
      final finalTarget = _selectedMove!.targetCount == MoveTargetCount.multiple
          ? DoubleTarget.allOpponents
          : target;

      // Self-target restriction
      // Self-target restriction
      final isDamageMove = _selectedMove!.baseDamage > 0;
      final activeSlot = bm.currentState == DoubleBattleState.selectingForSlot1
          ? DoubleTarget.playerSlot1
          : DoubleTarget.playerSlot2;

      if (target == activeSlot) {
        // Allow self-targeting only for status moves that target self
        final isSelfBuff =
            !isDamageMove &&
            _selectedMove!.effects.any((e) => e.target == 'self');

        if (!isSelfBuff) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot target self with this move!',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }
      }

      bm.submitAction(_selectedMove!, finalTarget);
      setState(() {
        _isTargeting = false;
        _selectedMove = null;
      });
    }
  }

  Future<void> _showSwitchDialog(BuildContext context, DoubleBattleManager bm) {
    final themeColor = _getBiomeThemeColor();
    final secondaryColor = _getBiomeSecondaryColor();
    final isForced = bm.currentState == DoubleBattleState.waitingForSwitch;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isForced,
      enableDrag: !isForced,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PopScope(
        canPop: !isForced,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: themeColor, width: 2),
            ),
            child: Column(
              children: [
                // Header Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    isForced ? 'SELECT REPLACEMENT' : 'SELECT ANIMAL',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: bm.playerTeam.length,
                    itemBuilder: (context, index) {
                      final animal = bm.playerTeam[index];
                      final battleOrg = BattleOrganism(
                        animal,
                        isRogueMode: bm.isRogueMode,
                      );

                      final isOnField =
                          index == bm.playerIdx1 || index == bm.playerIdx2;
                      final isFainted = battleOrg.health <= 0;

                      return ListTile(
                        enabled: !isOnField && !isFainted,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        onLongPress: () {
                          DoubleBattleScreen.showOrganismInfo(
                            context,
                            battleOrg,
                            bm: bm,
                            themeColor: themeColor,
                            secondaryColor: secondaryColor,
                            primaryColor: _getBiomePrimaryColor(),
                          );
                        },
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOnField ? themeColor : Colors.white12,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Opacity(
                            opacity: isFainted ? 0.5 : 1.0,
                            child: Image.asset(
                              'assets/sprites/${animal.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.pets, color: Colors.white),
                            ),
                          ),
                        ),
                        title: Text(
                          animal.name.toUpperCase(),
                          style: TextStyle(
                            color: isOnField
                                ? themeColor
                                : (isFainted ? Colors.grey : Colors.white),
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'HP: ${battleOrg.health}/${battleOrg.maxHealth}',
                              style: TextStyle(
                                color: isFainted ? Colors.red : Colors.green,
                                fontFamily: 'PressStart2P',
                                fontSize: 8,
                              ),
                            ),
                            if (animal.teraType != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'TERA:',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 6.5,
                                      color: Colors.white60,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: animal.teraType!.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      animal.teraType!.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'PressStart2P',
                                        fontSize: 6,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (battleOrg.statusEffects.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  children: battleOrg.statusEffects
                                      .map(
                                        (e) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: e.color,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          child: Text(
                                            e.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 6,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                        trailing: isOnField
                            ? Icon(Icons.check_circle, color: themeColor)
                            : (isFainted
                                  ? const Text(
                                      'FAINTED',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 8,
                                        fontFamily: 'PressStart2P',
                                      ),
                                    )
                                  : null),
                        onTap: (!isOnField && !isFainted)
                            ? () {
                                Navigator.pop(ctx);
                                if (isForced) {
                                  bm.confirmSwitch(index, bm.switchNeededSlot!);
                                } else {
                                  bm.submitSwitch(index);
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
                if (!isForced)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getBiomeBackground() {
    // Sync with BattleScreen logic
    var name = widget.biomeName;
    if (name.contains(',')) {
      name = name.split(',')[0];
    }
    name = name.trim().toLowerCase();

    // Overrides/Fallbacks
    if (name == 'forest') return 'assets/biomes/jungle-bg.png';
    if (name == 'rain forest' || name == 'rainforest') {
      return 'assets/biomes/rainforest-bg.png';
    }
    if (name == 'grassland') return 'assets/biomes/savanna-bg.png';

    final fileName = name.replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  Color _getBiomeThemeColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) return const Color.fromARGB(255, 1, 177, 53);
    if (biome.contains('desert')) return const Color(0xFFFFD740);
    if (biome.contains('snow')) return const Color(0xFF40C4FF);
    if (biome.contains('volcan')) return const Color(0xFFFF5252);
    if (biome.contains('mountain')) return const Color(0xFF90A4AE);
    if (biome.contains('forest') || biome.contains('jungle'))
      return const Color(0xFF69F0AE);
    if (biome.contains('ocean')) return const Color(0xFF448AFF);
    return const Color(0xFFDAA520);
  }

  Color _getBiomePrimaryColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) return const Color(0xFF2BB900);
    if (biome.contains('desert')) return const Color(0xFFFFC107);
    if (biome.contains('snow')) return const Color(0xFF00B0FF);
    if (biome.contains('volcan')) return const Color(0xFFD32F2F);
    if (biome.contains('mountain')) return const Color(0xFF607D8B);
    if (biome.contains('forest')) return const Color(0xFF388E3C);
    if (biome.contains('ocean')) return const Color(0xFF1976D2);
    return const Color(0xFF38761D);
  }

  Color _getBiomeSecondaryColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) return const Color.fromARGB(255, 7, 58, 0);
    if (biome.contains('desert')) return const Color(0xFFFF6F00);
    if (biome.contains('snow')) return const Color(0xFF01579B);
    if (biome.contains('volcan')) return const Color(0xFFB71C1C);
    if (biome.contains('mountain')) return const Color(0xFF37474F);
    if (biome.contains('forest')) return const Color(0xFF1B5E20);
    if (biome.contains('ocean')) return const Color(0xFF0D47A1);
    return const Color(0xFF1E3F2A);
  }

  Widget _buildRow(
    BuildContext context,
    BattleOrganism? slot, {
    required bool isPlayerSide,
    required bool isSecond,
    required DoubleTarget target,
    required Color primaryColor,
  }) {
    if (slot == null) return const SizedBox.shrink();
    final bm = context.read<DoubleBattleManager>();

    final statusBox = Expanded(
      child: GestureDetector(
        onTap: _isTargeting ? () => _onTargetSelected(target, bm) : null,
        child: _HpBar(
          slot: slot,
          label: isPlayerSide
              ? 'MY ${isSecond ? 2 : 1}'
              : 'OPP ${isSecond ? 2 : 1}',
          isRight: !isPlayerSide,
          isClickable: _isTargeting,
          primaryColor: primaryColor,
        ),
      ),
    );

    final sprite = GestureDetector(
      onTap: _isTargeting ? () => _onTargetSelected(target, bm) : null,
      child: _SlotSprite(
        slot: slot,
        size: isPlayerSide ? 90 : 80,
        mirror: isPlayerSide,
        faded: isPlayerSide && _isSlotFaded(context, isSecond ? 2 : 1),
        isTargetable: _isTargeting,
        biomeName: widget.biomeName,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: isPlayerSide
            ? [sprite, const SizedBox(width: 12), statusBox]
            : [statusBox, const SizedBox(width: 12), sprite],
      ),
    );
  }

  bool _isSlotFaded(BuildContext context, int slotIdx) {
    final bm = context.read<DoubleBattleManager>();
    if (bm.currentState == DoubleBattleState.selectingForSlot1 && slotIdx == 2)
      return true;
    if (bm.currentState == DoubleBattleState.selectingForSlot2 && slotIdx == 1)
      return true;
    return false;
  }

  Widget _buildHeader(
    BuildContext context,
    DoubleBattleManager bm,
    Color themeColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.battleTitle?.toUpperCase() ?? 'RANDOM DOUBLES',
            style: AppTextStyles.headline(
              context,
              baseSize: 12,
              color: themeColor,
            ),
          ),
          Row(
            children: [
              Text(
                'TURN ${bm.currentTurn}',
                style: AppTextStyles.small(
                  context,
                  baseSize: 8,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showFullLog(context, bm),
                icon: const Icon(
                  Icons.menu_book,
                  color: Colors.white70,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullLog(BuildContext context, DoubleBattleManager bm) {
    final themeColor = _getBiomeThemeColor();
    final primaryColor = _getBiomePrimaryColor();
    final secondaryColor = _getBiomeSecondaryColor();
    final isNarrow = MediaQuery.sizeOf(context).width < 400;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: themeColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BATTLE LOG',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: bm.turnHistory.length,
                  itemBuilder: (_, i) {
                    final turnIndex = bm.turnHistory.length - 1 - i;
                    final turn = bm.turnHistory[turnIndex];

                    if (turn.logEntries.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(
                            child: Text(
                              '--- TURN ${turn.turnNumber} ---',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 12,
                                fontFamily: 'PressStart2P',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        ...turn.logEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(
                                entry,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isNarrow ? 10 : 12,
                                  fontFamily: 'PressStart2P',
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// HP Bar
// ════════════════════════════════════════════════════════════

class _HpBar extends StatelessWidget {
  final BattleOrganism? slot;
  final String label;
  final bool isRight;
  final bool isClickable;
  final Color primaryColor;

  const _HpBar({
    required this.slot,
    required this.label,
    required this.isRight,
    this.isClickable = false,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (slot == null) {
      return Container(
        height: 50,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '—',
            style: AppTextStyles.small(
              context,
              baseSize: 8,
              color: Colors.white30,
            ),
          ),
        ),
      );
    }

    final ratio = (slot!.health / slot!.maxHealth).clamp(0.0, 1.0);
    final hpPercent = (ratio * 100).toStringAsFixed(1);
    final barColor = ratio > 0.5
        ? const Color(0xFF4ADE80)
        : ratio > 0.2
        ? Colors.orange
        : Colors.red;

    return GestureDetector(
      onLongPress: () {
        final bm = context.read<DoubleBattleManager>();
        DoubleBattleScreen.showOrganismInfo(
          context,
          slot!,
          bm: bm,
          primaryColor: primaryColor,
          secondaryColor: const Color(0xFF161B22),
          themeColor: const Color(0xFF4ADE80),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isClickable ? const Color(0xFF4ADE80) : primaryColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
            if (isClickable)
              BoxShadow(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isRight
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                slot!.organism.baseOrganism.name.toUpperCase(),
                style: AppTextStyles.body(
                  context,
                  baseSize: 10,
                  color: Colors.white,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              tween: Tween<double>(begin: ratio, end: ratio),
              builder: (context, value, child) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  color: barColor,
                  backgroundColor: Colors.black54,
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'HP: ${slot!.health}/${slot!.maxHealth} ($hpPercent%)',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Colors.white70,
                ),
              ),
            ),
            if (slot!.statusEffects.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: isRight ? WrapAlignment.end : WrapAlignment.start,
                children: slot!.statusEffects
                    .map(
                      (se) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: se.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          se.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'PressStart2P',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Slot Sprite (lightweight, local+network)
// ════════════════════════════════════════════════════════════

class _SlotSprite extends StatefulWidget {
  final BattleOrganism? slot;
  final double size;
  final bool mirror;
  final bool faded;
  final bool isTargetable;
  final String biomeName;

  const _SlotSprite({
    required this.slot,
    required this.size,
    required this.mirror,
    required this.faded,
    this.isTargetable = false,
    required this.biomeName,
  });

  @override
  State<_SlotSprite> createState() => _SlotSpriteState();
}

class _SlotSpriteState extends State<_SlotSprite>
    with SingleTickerProviderStateMixin {
  String? _imagePath;
  bool _isLocal = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SlotSprite old) {
    super.didUpdateWidget(old);
    if (old.slot?.organism.id != widget.slot?.organism.id) {
      setState(() {
        _imagePath = null; // Fix lag: clear old sprite immediately
      });
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.slot == null) return;
    final name = widget.slot!.organism.baseOrganism.name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r"[^a-z0-9]"), '_') // Robust sanitization
        .replaceAll(RegExp(r"_+"), '_') // Collapse double underscores
        .trim();
    if (name.endsWith('_')) {
      // Remove trailing underscores if any
      // name = name.substring(0, name.length - 1);
    }
    final sanitizedName = name.endsWith('_')
        ? name.substring(0, name.length - 1)
        : name;

    final localPath = 'assets/sprites/$sanitizedName.png';
    try {
      await rootBundle.load(localPath);
      if (mounted) {
        setState(() {
          _imagePath = localPath;
          _isLocal = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _imagePath = widget.slot!.organism.baseOrganism.sprite;
          _isLocal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slot == null || widget.slot!.health <= 0) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: Icon(Icons.close, color: Colors.white24, size: 24),
        ),
      );
    }

    final size = widget.size;
    Widget img;
    if (_imagePath == null) {
      img = SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white38,
          ),
        ),
      );
    } else if (_isLocal) {
      img = Image.asset(
        _imagePath!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.pets, color: Colors.white54, size: size * 0.5),
      );
    } else {
      img = Image.network(
        _imagePath!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.pets, color: Colors.white54, size: size * 0.5),
      );
    }

    // Saturation Boost (1.3x)
    const double sat = 1.3;
    const List<double> matrix = <double>[
      0.2126 * (1 - sat) + sat,
      0.7152 * (1 - sat),
      0.0722 * (1 - sat),
      0,
      0,
      0.2126 * (1 - sat),
      0.7152 * (1 - sat) + sat,
      0.0722 * (1 - sat),
      0,
      0,
      0.2126 * (1 - sat),
      0.7152 * (1 - sat),
      0.0722 * (1 - sat) + sat,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    if (widget.mirror) img = Transform.flip(flipX: true, child: img);

    final enhancedImg = ColorFiltered(
      colorFilter: const ColorFilter.matrix(matrix),
      child: widget.faded ? Opacity(opacity: 0.4, child: img) : img,
    );

    final outlineImg = ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.8),
        BlendMode.srcIn,
      ),
      child:
          img, // img already contains the reflection if widget.mirror is true
    );

    const double outlineOffset = 1.0;

    final bo = widget.slot;
    Widget processedSprite = enhancedImg;

    if (bo != null) {
      // Substitute grayscaling
      if (bo.substituteHealth > 0) {
        processedSprite = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: enhancedImg,
        );
      }

      // Prismorph: rainbow/crystal shimmer overlay
      if (bo.isPrismorphed) {
        final baseSprite = processedSprite;
        processedSprite = Stack(
          alignment: Alignment.center,
          children: [
            baseSprite,
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: const [
                          Color(0x55FF00FF), // Magenta
                          Color(0x5500FFFF), // Cyan
                          Color(0x55FF00FF), // Magenta
                        ],
                        stops: [
                          0.0,
                          _pulseAnimation.value.clamp(0.0, 1.0),
                          1.0,
                        ],
                        tileMode: TileMode.mirror,
                      ).createShader(bounds);
                    },
                    child: baseSprite,
                  );
                },
              ),
            ),
          ],
        );
      }
    }

    final double titanScale = 1.0;
    final double titanYOffset = 0.0;

    return GestureDetector(
      onLongPress: () {
        // Trigger info dialog
        final bm = context.read<DoubleBattleManager>();
        DoubleBattleScreen.showOrganismInfo(
          context,
          widget.slot!,
          bm: bm,
          primaryColor: const Color(0xFF2BB900), // Fallback or pass down
          secondaryColor: const Color(0xFF161B22),
          themeColor: const Color(0xFF4ADE80),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isTargetable
                ? const Color(0xFF4ADE80)
                : Colors.transparent,
            width: widget.isTargetable ? 2 : 0,
          ),
          boxShadow: widget.isTargetable
              ? [
                  BoxShadow(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(bottom: -size * 0.05, child: _buildPlatform(size)),

            // Titan Group (Outline + Sprite)
            Transform.translate(
              offset: Offset(0, titanYOffset),
              child: Transform.scale(
                scale: titanScale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 4-way outline
                    Transform.translate(
                      offset: const Offset(-outlineOffset, -outlineOffset),
                      child: outlineImg,
                    ),
                    Transform.translate(
                      offset: const Offset(outlineOffset, -outlineOffset),
                      child: outlineImg,
                    ),
                    Transform.translate(
                      offset: const Offset(-outlineOffset, outlineOffset),
                      child: outlineImg,
                    ),
                    Transform.translate(
                      offset: const Offset(outlineOffset, outlineOffset),
                      child: outlineImg,
                    ),

                    processedSprite,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatform(double size) {
    Color platformColor;
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) {
      platformColor = const Color(0xFF4E342E);
    } else if (biome.contains('desert') || biome.contains('savanna')) {
      platformColor = const Color(0xFFE0C487);
    } else if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra')) {
      platformColor = const Color(0xFFE0F7FA);
    } else if (biome.contains('volcan')) {
      platformColor = const Color(0xFF3E2723);
    } else if (biome.contains('mountain')) {
      platformColor = const Color(0xFF757575);
    } else if (biome.contains('forest') || biome.contains('jungle')) {
      platformColor = const Color(0xFF2E7D32);
    } else if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake')) {
      platformColor = const Color(0xFF0277BD);
    } else {
      platformColor = const Color(0xFF8D6E63);
    }

    final outlineColor = HSLColor.fromColor(platformColor)
        .withLightness(
          (HSLColor.fromColor(platformColor).lightness - 0.2).clamp(0, 1),
        )
        .toColor();

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(1.1),
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: size * 1.3,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: outlineColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  platformColor.withValues(alpha: _pulseAnimation.value * 0.5),
                  platformColor.withValues(alpha: 0.9),
                ],
                stops: const [0.2, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Action Panel
// ════════════════════════════════════════════════════════════

class _ActionPanel extends StatelessWidget {
  final DoubleBattleManager bm;
  final String biomeName;
  final Function(Move, DoubleBattleManager) onMoveSelected;
  final VoidCallback onSwitchTapped;
  final bool isTargeting;
  final VoidCallback onCancelTargeting;
  final Move? selectedMove;

  const _ActionPanel({
    required this.bm,
    required this.biomeName,
    required this.onMoveSelected,
    required this.onSwitchTapped,
    required this.isTargeting,
    required this.onCancelTargeting,
    this.selectedMove,
  });

  @override
  Widget build(BuildContext context) {
    if (isTargeting) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              selectedMove?.targetCount == MoveTargetCount.multiple
                  ? 'SELECT ANY TARGET FOR AOE...'
                  : 'SELECT A TARGET FOR ${selectedMove?.name.toUpperCase()}...',
              style: AppTextStyles.small(
                context,
                baseSize: 8,
                color: const Color(0xFF4ADE80),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onCancelTargeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'CANCEL SELECTION',
                style: AppTextStyles.small(
                  context,
                  baseSize: 8,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Battle End ──
    if (bm.currentState == DoubleBattleState.battleEnd) {
      return _buildResultPanel(context, bm);
    }

    // ── Needs switch ──
    if (bm.currentState == DoubleBattleState.waitingForSwitch) {
      return _buildMessageBox(context, 'Select a replacement...');
    }

    // ── Executing ──
    if (bm.currentState == DoubleBattleState.executing) {
      return _buildMessageBox(context, bm.battleLog);
    }

    // ── Intro ──
    if (bm.currentState == DoubleBattleState.intro) {
      return _buildMessageBox(context, bm.battleLog);
    }

    // ── Move selection ──
    final BattleOrganism? selectingSlot =
        bm.currentState == DoubleBattleState.selectingForSlot1
        ? bm.playerSlot1
        : bm.playerSlot2;

    if (selectingSlot == null) {
      return _buildMessageBox(context, 'Waiting...');
    }

    final themeColor = DoubleBattleScreen.getBiomeThemeColor(biomeName);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Text(
              'What will ${selectingSlot.organism.baseOrganism.name.toUpperCase()} do?',
              style: AppTextStyles.body(
                context,
                baseSize: 10,
                color: themeColor,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // MOVE GRID
          _buildMoveGrid(context, selectingSlot, bm, themeColor),

          const SizedBox(height: 12),

          // GIMMICK BUTTONS
          _buildGimmickButtons(context, selectingSlot, bm, themeColor),

          const SizedBox(height: 8),
          // Switch button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: bm.isProcessing ? null : onSwitchTapped,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(
                'SWITCH',
                style: AppTextStyles.small(
                  context,
                  baseSize: 9,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white24, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGimmickButtons(
    BuildContext context,
    BattleOrganism slot,
    DoubleBattleManager bm,
    Color themeColor,
  ) {
    final canPrismorph =
        !bm.playerPrismorphUsed && !slot.hasPrismorphedThisBattle;

    final isPrismorphing = slot.isPrismorphed;

    if (!canPrismorph && !isPrismorphing) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (canPrismorph || isPrismorphing)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ElevatedButton(
                onPressed: canPrismorph
                    ? () {
                        bm.activatePrismorph(
                          isPlayer: true,
                          slotIdx:
                              bm.currentState ==
                                  DoubleBattleState.selectingForSlot1
                              ? 1
                              : 2,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrismorphing
                      ? Colors.cyan
                      : Colors.cyan.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isPrismorphing
                        ? const BorderSide(color: Colors.white, width: 2)
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  isPrismorphing
                      ? 'PRISMORPHED (${slot.activeTeraType?.name})'
                      : 'PRISMORPH',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMoveGrid(
    BuildContext context,
    BattleOrganism slot,
    DoubleBattleManager bm,
    Color themeColor,
  ) {
    final moves = _getMoves(slot);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: moves.length,
      itemBuilder: (context, i) {
        return _MoveButton(
          move: moves[i],
          organism: slot,
          onTap: () => onMoveSelected(moves[i], bm),
          bm: bm,
        );
      },
    );
  }

  List<Move> _getMoves(BattleOrganism slot) {
    return bm.getMovesFor(slot);
  }

  Widget _buildMessageBox(BuildContext context, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DoubleBattleScreen.getBiomeThemeColor(
            biomeName,
          ).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        msg.isNotEmpty ? msg.toUpperCase() : '...',
        style: AppTextStyles.body(
          context,
          baseSize: 11,
          color: Colors.white,
        ).copyWith(height: 1.5),
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget _buildResultPanel(BuildContext context, DoubleBattleManager bm) {
    final isWin = bm.result == DoubleBattleResult.win;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWin
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWin ? Colors.green : Colors.red, width: 2),
      ),
      child: Column(
        children: [
          Text(
            isWin ? 'VICTORY!' : 'DEFEATED...',
            style: AppTextStyles.headline(
              context,
              baseSize: 18,
              color: isWin ? Colors.green : Colors.red,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isWin ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'BACK TO MENU',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Move Button
// ════════════════════════════════════════════════════════════

class _MoveButton extends StatelessWidget {
  final Move move;
  final BattleOrganism organism;
  final DoubleBattleManager bm;
  final VoidCallback onTap;

  const _MoveButton({
    required this.move,
    required this.organism,
    required this.bm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayType = bm.getDisplayType(organism, move);
    final typeColor = _typeColor(displayType);
    final curStam = organism.organism.moveStamina[move.name] ?? 0;
    final maxStam = move.stamina;

    return GestureDetector(
      onTap: bm.isProcessing ? null : onTap,
      onLongPress: () => _showMoveDetails(
        context,
        move,
        displayType,
        const Color(0xFF4ADE80),
        bm,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              typeColor.withValues(alpha: 0.8),
              typeColor.withValues(alpha: 0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: typeColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: typeColor.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Move Name
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                move.name.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
            ),

            // Category & Stamina Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: move.category.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    move.category.name.toUpperCase().substring(0, 4),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 5,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Stamina
                Text(
                  '$curStam/$maxStam',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                    color: curStam > 0 ? Colors.white : Colors.redAccent,
                  ),
                ),
              ],
            ),

            // Type & Target Area
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayType.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 6,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (move.targetCount == MoveTargetCount.multiple)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade800,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'ALL',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 5,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveDetails(
    BuildContext context,
    Move move,
    ElementalType displayType,
    Color themeColor,
    DoubleBattleManager bm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeColor, width: 2),
        ),
        title: Text(
          move.name,
          style: TextStyle(
            color: themeColor,
            fontFamily: 'PressStart2P',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'TYPE:',
              displayType.name.toUpperCase(),
              _typeColor(displayType),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'CATEGORY:',
              '',
              Colors.white,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: move.category.color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  move.category.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'POWER:',
              move.baseDamage > 0 ? '${move.baseDamage}' : '-',
              Colors.white,
            ),
            const SizedBox(height: 8),
            _buildDetailRow('ACCURACY:', '${move.accuracy}%', Colors.white),
            const SizedBox(height: 8),
            _buildDetailRow('STAMINA:', '${move.stamina}', Colors.orange),
            const SizedBox(height: 12),
            Text(
              move.description,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'PressStart2P',
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CLOSE',
              style: TextStyle(
                color: themeColor,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color valueColor, {
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontFamily: 'PressStart2P',
            fontSize: 10,
          ),
        ),
        if (trailing != null)
          trailing
        else
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontFamily: 'PressStart2P',
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

class _GimmickBanner extends StatefulWidget {
  final String type;
  final String targetName;
  final Color color;

  const _GimmickBanner({
    required this.type,
    required this.targetName,
    required this.color,
  });

  @override
  State<_GimmickBanner> createState() => _GimmickBannerState();
}

class _GimmickBannerState extends State<_GimmickBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 20),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              color: Colors.black45,
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'PressStart2P',
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.targetName}!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'PressStart2P',
                          shadows: [
                            Shadow(color: widget.color, blurRadius: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
