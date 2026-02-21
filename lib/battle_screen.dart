// lib/battle_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, SystemChrome, DeviceOrientation;
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/rogue/rogue_hub_screen.dart';
import 'package:animal_warfare/rogue/biome_select_screen.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/loot_item.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/elemental_type.dart'; // Added
import 'package:animal_warfare/models/move.dart'; // Added
import 'package:animal_warfare/models/status_effect.dart'; // Added for overlay
import 'dart:math' as math;
import 'dart:async';

class BattleScreen extends StatelessWidget {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  final String biomeName;
  final List<CapturedOrganism>? playerTeam;
  final String? battleTitle;
  final bool isArenaBattle;
  final List<CapturedOrganism>? opponentTeam;
  final bool isRogueMode;

  const BattleScreen({
    super.key,
    required this.playerOrganism,
    required this.opponentOrganism,
    required this.biomeName,
    this.playerTeam,
    this.battleTitle,
    this.isArenaBattle = false,
    this.opponentTeam,
    this.isRogueMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BattleManager(
        playerOrganism,
        opponentOrganism,
        biomeName: biomeName,
        team: playerTeam,
        opponentTeam: opponentTeam,
        isArenaBattle: isArenaBattle,
        isRogueMode: isRogueMode,
        initialPlayerIndex: isRogueMode
            ? Provider.of<UserState>(
                context,
                listen: false,
              ).currentUser?.rogueLikeState.currentPlayerIndex
            : null,
      ),
      child: BattleScreenContent(
        biomeName: biomeName,
        opponentName: opponentOrganism.baseOrganism.name,
        battleTitle: battleTitle,
        isArenaBattle: isArenaBattle,
        isRogueMode: isRogueMode,
      ),
    );
  }
}

class BattleScreenContent extends StatefulWidget {
  final String biomeName;
  final String opponentName;
  final String? battleTitle;
  final bool isArenaBattle;
  final bool isRogueMode;

  const BattleScreenContent({
    super.key,
    required this.biomeName,
    required this.opponentName,
    this.battleTitle,
    this.isArenaBattle = false,
    this.isRogueMode = false,
  });

  @override
  State<BattleScreenContent> createState() => _BattleScreenContentState();
}

class _BattleScreenContentState extends State<BattleScreenContent>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Color _getBiomeThemeColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) {
      return const Color.fromARGB(255, 1, 177, 53); // Purple Accent
    }
    if (biome.contains('desert') || biome.contains('savanna')) {
      return const Color(0xFFFFD740); // Amber Accent
    }
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra')) {
      return const Color(0xFF40C4FF); // Light Blue Accent
    }
    if (biome.contains('volcan')) return const Color(0xFFFF5252); // Red Accent
    if (biome.contains('mountain')) return const Color(0xFF90A4AE); // Blue Grey
    if (biome.contains('forest') || biome.contains('jungle')) {
      return const Color(0xFF69F0AE); // Green Accent
    }
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river')) {
      return const Color(0xFF448AFF); // Blue Accent
    }
    return const Color(0xFFDAA520); // Default Goldenrod
  }

  Color _getBiomePrimaryColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) {
      return const Color(0xFF2BB900); // Purple (Actually Greenish Swamp)
    }
    if (biome.contains('desert') || biome.contains('savanna')) {
      return const Color(0xFFFFC107); // Amber
    }
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra')) {
      return const Color(0xFF00B0FF); // Light Blue
    }
    if (biome.contains('volcan')) return const Color(0xFFD32F2F); // Red
    if (biome.contains('mountain')) return const Color(0xFF607D8B); // Blue Grey
    if (biome.contains('forest') || biome.contains('jungle')) {
      return const Color(0xFF388E3C); // Green
    }
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river')) {
      return const Color(0xFF1976D2); // Blue
    }
    return const Color(0xFF38761D); // Default Jungle Green
  }

  Color _getBiomeSecondaryColor() {
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) {
      return const Color.fromARGB(255, 7, 58, 0); // details background
    }
    if (biome.contains('desert') || biome.contains('savanna')) {
      return const Color(0xFFFF6F00); // Dark Amber
    }
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra')) {
      return const Color(0xFF01579B); // Dark Blue
    }
    if (biome.contains('volcan')) return const Color(0xFFB71C1C); // Dark Red
    if (biome.contains('mountain')) {
      return const Color(0xFF37474F); // Dark Blue Grey
    }
    if (biome.contains('forest') || biome.contains('jungle')) {
      return const Color(0xFF1B5E20); // Dark Green
    }
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river')) {
      return const Color(0xFF0D47A1); // Dark Blue
    }
    return const Color(0xFF1E3F2A); // Default Deep Forest Green
  }

  // Helper: Get color for ElementalType
  Color _getTypeColor(ElementalType type) {
    switch (type) {
      case ElementalType.basic:
        return const Color.fromARGB(255, 168, 168, 130);
      case ElementalType.flying:
        return const Color(0xFFA98FF3);
      case ElementalType.aquatic:
        return const Color.fromARGB(255, 46, 60, 255);
      case ElementalType.earth:
        return const Color(0xFFE2BF65);
      case ElementalType.cryo:
        return const Color.fromARGB(255, 0, 247, 255);
      case ElementalType.toxic:
        return const Color(0xFFA33EA1);
      case ElementalType.rock:
        return const Color.fromARGB(255, 158, 97, 5);
      case ElementalType.arthropod:
        return const Color.fromARGB(255, 111, 207, 0);
      case ElementalType.electric:
        return const Color.fromARGB(255, 255, 251, 27);
      case ElementalType.spectral:
        return const Color.fromARGB(255, 91, 11, 240);
      case ElementalType.martial:
        return const Color.fromARGB(255, 160, 24, 0);
      case ElementalType.blaze:
        return const Color.fromARGB(255, 226, 72, 0);
      case ElementalType.grass:
        return const Color.fromARGB(255, 22, 131, 0);
      case ElementalType.mystic:
        return const Color.fromARGB(255, 255, 81, 162);
      case ElementalType.darkness:
        return const Color.fromARGB(255, 37, 36, 37);
      case ElementalType.drake:
        return const Color.fromARGB(255, 76, 0, 255);
      case ElementalType.metal:
        return const Color.fromARGB(255, 172, 168, 168);
      case ElementalType.aura:
        return const Color.fromARGB(255, 229, 255, 79);
      case ElementalType.sound:
        return const Color.fromARGB(255, 166, 70, 255);
      case ElementalType.holy:
        return const Color.fromARGB(255, 255, 208, 0);
    }
  }

  // Helper: Calculate effectiveness multiplier
  double _calculateMoveEffectiveness(Move move, BattleOrganism opponent) {
    if (move.category == MoveCategory.status) return 1.0;

    double multiplier = 1.0;
    for (final type in opponent.organism.baseOrganism.elementalTypes) {
      multiplier *= TypeChart.getEffectiveness(move.type, type);
    }
    return multiplier;
  }

  // Helper: Get effectiveness text
  String _getEffectivenessText(double multiplier) {
    if (multiplier > 1.0) return 'Super Effective!';
    if (multiplier == 0.0) return 'Immune';
    if (multiplier < 1.0) return 'Not Effective';
    return '';
  }

  late AnimationController _playerShakeController;
  late AnimationController _opponentShakeController;
  late Animation<double> _playerShakeAnimation;
  late Animation<double> _opponentShakeAnimation;
  bool _isSwitchDialogShowing = false;
  bool _isHandlingBattleEnd = false; // Prevents race condition
  CapturedOrganism? _pendingRogueCapture;
  BattleManager? _battleManager;
  final LayerLink _playerLink = LayerLink();
  final LayerLink _opponentLink = LayerLink();

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer to handle app backgrounding
    WidgetsBinding.instance.addObserver(this);

    _playerShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opponentShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final shakeTween = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]);

    _playerShakeAnimation = shakeTween.animate(_playerShakeController);
    _opponentShakeAnimation = shakeTween.animate(_opponentShakeController);

    // Set up BattleManager callbacks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final userState = Provider.of<UserState>(context, listen: false);
      // Trigger quest progress ON ENCOUNTER (as soon as battle starts)
      userState.updateQuestProgress(widget.opponentName);

      final bm = Provider.of<BattleManager>(context, listen: false);
      _battleManager = bm;
      bm.onAttack = _onAttack;
      bm.onVictory = _onVictory;

      // Sync rogue state mid-battle
      if (widget.isRogueMode) {
        bm.addListener(_syncRogueState);
      }
    });
  }

  void _syncRogueState() {
    if (!mounted || !widget.isRogueMode) return;
    final bm = Provider.of<BattleManager>(context, listen: false);

    // Only sync if in a stable state (waiting for input, waiting for switch, or battle end)
    // This prevents mid-turn abuse (save-scumming) and ensures state is clean.
    const stableStates = [
      BattleState.waitingForInput,
      BattleState.waitingForPlayerSwitch,
      BattleState.battleEnd,
    ];

    if (!stableStates.contains(bm.currentState)) return;

    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    // Update the rogue state with current team and opponent health/stamina/status
    final updatedState = user.rogueLikeState.copyWith(
      team: bm.playerTeam,
      opponentTeam: bm.opponentTeam,
      currentOpponentIndex: bm.currentOpponentIndex,
      currentPlayerIndex: bm.currentPlayerIndex,
    );
    userState.updateRogueRunState(updatedState);
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // FIX: Remove BattleManager listener to prevent state leaks or post-mortem syncs
    if (widget.isRogueMode && _battleManager != null) {
      _battleManager!.removeListener(_syncRogueState);
    }

    // FIX: Explicitly stop music when leaving the battle screen.
    // This prevents the battle music from persisting into the home screen
    // or next battle (which might not start its track immediately).
    AudioService.instance.stopMusic();

    _playerShakeController.dispose();
    _opponentShakeController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!mounted) return;

    final bm = Provider.of<BattleManager>(context, listen: false);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App went to background - pause audio
        bm.pauseAudio();
        break;
      case AppLifecycleState.resumed:
        // App came back to foreground - resume audio
        bm.resumeAudio();
        break;
      default:
        break;
    }
  }

  void _onAttack(BattleOrganism attacker) {
    if (!mounted) return;

    final bm = Provider.of<BattleManager>(context, listen: false);

    if (attacker == bm.player) {
      // Player attacks
      _playerShakeController.forward(from: 0);
    } else {
      // Opponent attacks
      _opponentShakeController.forward(from: 0);
    }
  }

  void _onVictory() {
    if (!mounted) return;
    // Quest progress shifted to encounter phase in initState
  }

  void _toggleOrientation() {
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
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
    if (name == 'forest') return 'assets/biomes/jungle-bg.png';
    if (name == 'rain forest' || name == 'rainforest') {
      return 'assets/biomes/rainforest-bg.png';
    }
    if (name == 'grassland') return 'assets/biomes/savanna-bg.png';

    // 4. Asset formatting
    final fileName = name.replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  void _showBattleLog(BuildContext context, BattleManager battleManager) {
    final isNarrow = MediaQuery.sizeOf(context).width < 400;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: isNarrow ? 0.7 : 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: _getBiomeSecondaryColor(),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: _getBiomeThemeColor(), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _getBiomePrimaryColor().withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BATTLE LOG',
                      style: AppTextStyles.headline(
                        context,
                        baseSize: 14,
                        color: _getBiomeThemeColor(),
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
                  // Reverse order of turns (Latest turn first)
                  itemCount: battleManager.turnHistory.length,
                  itemBuilder: (_, i) {
                    final turnIndex = battleManager.turnHistory.length - 1 - i;
                    final turn = battleManager.turnHistory[turnIndex];

                    if (turn.logEntries.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Turn Header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: Text(
                              '--- TURN ${turn.turnNumber} ---',
                              style: TextStyle(
                                color: _getBiomeThemeColor(),
                                fontSize: 12,
                                fontFamily: 'PressStart2P',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Log Entries for this turn (Chronological)
                        ...turn.logEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade800),
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

  Future<void> _showSwitchDialog(BuildContext context, BattleManager bm) {
    // START FIX: Prevent dismissal if switch is forced
    final bool isForced = bm.currentState == BattleState.waitingForPlayerSwitch;
    return showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (ctx) => PopScope(
        canPop: !isForced,
        child: AlertDialog(
          backgroundColor: _getBiomeSecondaryColor(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _getBiomeThemeColor(), width: 2),
          ),
          title: Text(
            'SELECT ANIMAL',
            style: AppTextStyles.headline(
              context,
              baseSize: 14,
              color: _getBiomeThemeColor(),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bm.playerTeam.length,
              itemBuilder: (context, index) {
                final animal = bm.playerTeam[index];
                final battleOrg = BattleOrganism(
                  animal,
                  isRogueMode: bm.isRogueMode,
                );
                final isCurrent = index == bm.currentPlayerIndex;
                final isFainted = battleOrg.health <= 0;

                return ListTile(
                  enabled: !isCurrent && !isFainted,
                  onLongPress: () {
                    // Show animal details on long press
                    _showOrganismInfo(
                      context,
                      battleOrg,
                      bm: bm,
                      isPlayer: true,
                    );
                  },
                  leading: Opacity(
                    opacity: isFainted ? 0.5 : 1.0,
                    child: Image.asset(
                      'assets/sprites/${animal.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                      width: 40,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.pets, color: Colors.white),
                    ),
                  ),
                  title: Text(
                    animal.name,
                    style: TextStyle(
                      color: isCurrent
                          ? _getBiomeThemeColor()
                          : (isFainted ? Colors.grey : Colors.white),
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                    ),
                  ),
                  subtitle: Text(
                    'HP: ${battleOrg.health}/${battleOrg.maxHealth}',
                    style: TextStyle(
                      color: isFainted ? Colors.red : Colors.green,
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                    ),
                  ),
                  trailing: isCurrent
                      ? Icon(Icons.check_circle, color: _getBiomeThemeColor())
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
                  onTap: (!isCurrent && !isFainted)
                      ? () {
                          Navigator.pop(ctx);
                          bm.switchAnimal(index);
                        }
                      : null,
                );
              },
            ),
          ),
          actions: [
            if (bm.currentState != BattleState.waitingForPlayerSwitch)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final battleManager = Provider.of<BattleManager>(context);
    final userState = Provider.of<UserState>(context, listen: false);
    final isNarrow = MediaQuery.sizeOf(context).width < 400;

    if (battleManager.currentState == BattleState.battleEnd) {
      _handleBattleEnd(context, battleManager, userState);
    }

    if (battleManager.currentState == BattleState.waitingForPlayerSwitch &&
        !_isSwitchDialogShowing) {
      _isSwitchDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSwitchDialog(context, battleManager).then((_) {
          _isSwitchDialogShowing = false;
        });
      });
    }

    final overlayColor = Colors.black.withOpacity(0.55);

    // Initialize/Update listener
    battleManager.onAttack = _onAttack;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_getAssetPath(widget.biomeName)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.35),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                if (isLandscape) {
                  return Column(
                    children: [
                      _buildHeader(context, battleManager, overlayColor),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left side: Animal Statuses and Sprites
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildFieldEffects(context, battleManager),
                                  if (widget.isArenaBattle)
                                    _buildOpponentTeamIndicator(
                                      context,
                                      battleManager,
                                    ),
                                  const SizedBox(height: 2),
                                  AnimatedBuilder(
                                    animation: _opponentShakeAnimation,
                                    builder: (context, child) =>
                                        Transform.translate(
                                          offset: Offset(
                                            _opponentShakeAnimation.value,
                                            0,
                                          ),
                                          child: child,
                                        ),
                                    child: _buildOpponentStatus(
                                      context,
                                      battleManager.opponent,
                                      overlayColor,
                                      isNarrow,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedBuilder(
                                    animation: _playerShakeAnimation,
                                    builder: (context, child) =>
                                        Transform.translate(
                                          offset: Offset(
                                            _playerShakeAnimation.value,
                                            0,
                                          ),
                                          child: child,
                                        ),
                                    child: _buildPlayerStatus(
                                      context,
                                      battleManager.player,
                                      overlayColor,
                                      isNarrow,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Right side: Logs and Controls
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  if (battleManager.currentState ==
                                      BattleState.waitingForInput) ...[
                                    _buildMessageBox(
                                      context,
                                      battleManager.battleLog,
                                      isNarrow,
                                      expanded: false,
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _buildActionControls(
                                          context,
                                          battleManager,
                                          overlayColor,
                                          isNarrow,
                                          userState,
                                        ),
                                      ),
                                    ),
                                  ] else
                                    Expanded(
                                      child: _buildMessageBox(
                                        context,
                                        battleManager.battleLog,
                                        isNarrow,
                                        expanded: true,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Portrait layout
                return Column(
                  children: [
                    _buildHeader(context, battleManager, overlayColor),
                    const SizedBox(height: 2),
                    _buildFieldEffects(context, battleManager),
                    if (widget.isArenaBattle)
                      _buildOpponentTeamIndicator(context, battleManager),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _opponentShakeAnimation,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(_opponentShakeAnimation.value, 0),
                              child: child,
                            ),
                            child: _buildOpponentStatus(
                              context,
                              battleManager.opponent,
                              overlayColor,
                              isNarrow,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: _playerShakeAnimation,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(_playerShakeAnimation.value, 0),
                              child: child,
                            ),
                            child: _buildPlayerStatus(
                              context,
                              battleManager.player,
                              overlayColor,
                              isNarrow,
                            ),
                          ),
                          const SizedBox(height: 1),
                          if (battleManager.currentState ==
                              BattleState.waitingForInput) ...[
                            _buildMessageBox(
                              context,
                              battleManager.battleLog,
                              isNarrow,
                              expanded: false,
                            ),
                            _buildActionControls(
                              context,
                              battleManager,
                              overlayColor,
                              isNarrow,
                              userState,
                            ),
                          ] else
                            Expanded(
                              child: _buildMessageBox(
                                context,
                                battleManager.battleLog,
                                isNarrow,
                                expanded: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Ability Pop-up Overlay
          if (battleManager.currentAbilityNotify != null)
            _AbilityPopUp(
              notification: battleManager.currentAbilityNotify!,
              themeColor: _getBiomeThemeColor(),
              link: battleManager.currentAbilityNotify!.isPlayer
                  ? _playerLink
                  : _opponentLink,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    BattleManager battleManager,
    Color overlayColor,
  ) {
    final userState = Provider.of<UserState>(context, listen: false);
    final rogueState = userState.currentUser?.rogueLikeState;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.battleTitle ?? 'Wild Encounter',
                style: AppTextStyles.headline(
                  context,
                  baseSize: 12,
                  color: _getBiomeThemeColor(),
                ),
              ),
              if (widget.isRogueMode && rogueState != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getBiomeThemeColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FLOOR ${rogueState.floor} - ${rogueState.encounterIndex + 1}/5',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: _toggleOrientation,
                icon: const Icon(Icons.screen_rotation),
                color: _getBiomeThemeColor(),
                tooltip: 'Rotate Screen',
                style: IconButton.styleFrom(
                  backgroundColor: overlayColor,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showBattleLog(context, battleManager),
                icon: const Icon(Icons.menu_book),
                color: _getBiomeThemeColor(),
                tooltip: 'Battle Log',
                style: IconButton.styleFrom(
                  backgroundColor: overlayColor,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldEffects(BuildContext context, BattleManager bm) {
    if (bm.currentWeather.weather == Weather.none &&
        bm.currentTerrain.terrain == Terrain.none) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (bm.currentWeather.weather != Weather.none)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white70),
            ),
            child: Text(
              bm.currentWeather.weather
                  .toString()
                  .split('.')
                  .last
                  .toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        if (bm.currentTerrain.terrain != Terrain.none)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white70),
            ),
            child: Text(
              bm.currentTerrain.terrain
                  .toString()
                  .split('.')
                  .last
                  .toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOpponentTeamIndicator(BuildContext context, BattleManager bm) {
    if (!widget.isArenaBattle || bm.opponentTeam.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            'OPP: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(width: 4),
          ...List.generate(bm.opponentTeam.length, (index) {
            final animal = bm.opponentTeam[index];
            final isCurrent = index == bm.currentOpponentIndex;
            final hpRatio = animal.currentHealth / animal.maxHealth;

            Color indicatorColor;
            if (animal.currentHealth <= 0) {
              indicatorColor = Colors.grey.shade700;
            } else if (hpRatio > 0.5) {
              indicatorColor = const Color(0xFF4CAF50); // Green
            } else if (hpRatio > 0.2) {
              indicatorColor = Colors.orange; // Yellow/Orange
            } else {
              indicatorColor = Colors.red; // Critical
            }

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorColor,
                  border: Border.all(
                    color: isCurrent ? _getBiomeThemeColor() : Colors.white30,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: animal.currentHealth <= 0
                    ? const Icon(Icons.close, size: 10, color: Colors.white54)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOpponentStatus(
    BuildContext context,
    BattleOrganism organism,
    Color barColor,
    bool isNarrow,
  ) {
    final base = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final spriteSize = isLandscape
        ? (isNarrow ? 90.0 : 110.0)
        : (isNarrow ? 130.0 : 150.0);

    final statusBox = Container(
      constraints: BoxConstraints(maxWidth: isNarrow ? 160 : 200),
      padding: EdgeInsets.all(isNarrow ? 6 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBiomeThemeColor(), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.isRogueMode
                  ? '${base.name} LV.${organism.organism.level}'
                  : base.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isNarrow ? 10 : 12,
                fontFamily: 'PressStart2P',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              tween: Tween<double>(
                begin: hpRatio.clamp(0.0, 1.0),
                end: hpRatio.clamp(0.0, 1.0),
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                color: value > 0.5
                    ? const Color(0xFF4CAF50)
                    : (value > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[800],
                minHeight: isNarrow ? 8 : 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HP: ${organism.health}/$maxHp (${(hpRatio * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isNarrow ? 8 : 10,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          if (organism.statusEffects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: organism.statusEffects
                    .map(
                      (se) => GestureDetector(
                        onLongPress: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${se.name}: ${se.description}'),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                              width: 250,
                            ),
                          );
                        },
                        child: Container(
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
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (organism.organism.equippedTalisman != null &&
              organism.isItemRevealed)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.stars, size: 10, color: Colors.yellowAccent),
                  if (organism.talismanConsumed)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        '(Used)',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () =>
                  _showOrganismInfo(context, organism, isPlayer: false),
              child: statusBox,
            ),
          ),
          const SizedBox(width: 8),
          CompositedTransformTarget(
            link: _opponentLink,
            child: _BattleSprite(
              organism: organism,
              size: spriteSize,
              onLongPress: () =>
                  _showOrganismInfo(context, organism, isPlayer: false),
              mirror: false, // Mirrored from previous State
              biomeName: widget.biomeName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatus(
    BuildContext context,
    BattleOrganism organism,
    Color barColor,
    bool isNarrow,
  ) {
    final base = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final spriteSize = isLandscape
        ? (isNarrow ? 100.0 : 120.0)
        : (isNarrow ? 140.0 : 170.0);

    final statusBox = Container(
      constraints: BoxConstraints(maxWidth: isNarrow ? 160 : 200),
      padding: EdgeInsets.all(isNarrow ? 6 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBiomeThemeColor(), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.isRogueMode
                  ? '${base.name} LV.${organism.organism.level}'
                  : base.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isNarrow ? 10 : 12,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              tween: Tween<double>(
                begin: hpRatio.clamp(0.0, 1.0),
                end: hpRatio.clamp(0.0, 1.0),
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                color: value > 0.5
                    ? const Color(0xFF4CAF50)
                    : (value > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[800],
                minHeight: isNarrow ? 8 : 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HP: ${organism.health}/$maxHp (${(hpRatio * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isNarrow ? 8 : 10,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          if (organism.statusEffects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: organism.statusEffects
                    .map(
                      (se) => GestureDetector(
                        onLongPress: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${se.name}: ${se.description}'),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                              width: 250,
                            ),
                          );
                        },
                        child: Container(
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
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (organism.organism.equippedTalisman != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, size: 10, color: Colors.yellowAccent),
                  if (organism.talismanConsumed)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        '(Used)',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CompositedTransformTarget(
            link: _playerLink,
            child: _BattleSprite(
              organism: organism,
              size: spriteSize,
              onLongPress: () =>
                  _showOrganismInfo(context, organism, isPlayer: true),
              mirror: true, // Mirrored from previous State
              biomeName: widget.biomeName,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: () =>
                  _showOrganismInfo(context, organism, isPlayer: true),
              child: statusBox,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrganismInfo(
    BuildContext context,
    BattleOrganism bo, {
    BattleManager? bm,
    bool isPlayer = false,
  }) {
    final base = bo.organism.baseOrganism;
    final battleManager =
        bm ?? Provider.of<BattleManager>(context, listen: false);
    final isPlayer =
        (bo == battleManager.player) ||
        battleManager.playerTeam.any((po) => po == bo.organism);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _getBiomeSecondaryColor(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _getBiomeThemeColor(), width: 2),
        ),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getBiomePrimaryColor().withOpacity(0.8),
                _getBiomeSecondaryColor(),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Text(
            base.name,
            style: TextStyle(
              color: _getBiomeThemeColor(),
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
                        final typeColor = _getTypeColor(type);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 2,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            cat.trim().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontFamily: 'PressStart2P',
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 1,
                                  offset: Offset(0.5, 0.5),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

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
                      style: TextStyle(
                        color: _getBiomeThemeColor(),
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // HP Section
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
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

              // Stat Boosts
              Text(
                'STATS & BOOSTS',
                style: TextStyle(
                  color: _getBiomeThemeColor(),
                  fontSize: 9,
                  fontFamily: 'PressStart2P',
                ),
              ),
              const SizedBox(height: 6),
              _buildStatRow(
                'ATK',
                isPlayer ? '${bo.currentAttack}' : '???',
                bo.attackStage >= 0
                    ? '+${bo.attackStage}'
                    : '${bo.attackStage}',
                const Color.fromARGB(255, 228, 1, 1),
              ),
              _buildStatRow(
                'DEF',
                isPlayer ? '${bo.currentDefense}' : '???',
                bo.defenseStage >= 0
                    ? '+${bo.defenseStage}'
                    : '${bo.defenseStage}',
                const Color.fromARGB(255, 209, 125, 0),
              ),
              _buildStatRow(
                'PWR',
                isPlayer ? '${bo.currentPower}' : '???',
                bo.powerStage >= 0 ? '+${bo.powerStage}' : '${bo.powerStage}',
                Colors.purple,
              ),
              _buildStatRow(
                'RES',
                isPlayer ? '${bo.currentResistance}' : '???',
                bo.resistanceStage >= 0
                    ? '+${bo.resistanceStage}'
                    : '${bo.resistanceStage}',
                const Color.fromARGB(255, 209, 212, 0),
              ),
              _buildStatRow(
                'SPD',
                isPlayer ? '${bo.currentSpeed}' : '???',
                bo.speedStage >= 0 ? '+${bo.speedStage}' : '${bo.speedStage}',
                const Color.fromARGB(255, 0, 188, 235),
              ),

              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "NONE",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: bo.statusEffects
                            .map(
                              (se) => GestureDetector(
                                onLongPress: () {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${se.name}: ${se.description}',
                                      ),
                                      duration: const Duration(seconds: 4),
                                      behavior: SnackBarBehavior.floating,
                                      width: 250,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: se.color.withOpacity(0.5),
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
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),

              // Held Item
              if (bo.organism.equippedTalisman != null &&
                  (isPlayer || bo.isItemRevealed))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stars,
                        color: Colors.yellowAccent,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'HELD ITEM: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bo.organism.equippedTalisman!.name,
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 9,
                            fontFamily: 'PressStart2P',
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (bo.organism.equippedTalisman != null &&
                  (isPlayer || bo.isItemRevealed))
                const SizedBox(height: 10),
              if (bo.organism.equippedTalisman != null &&
                  (isPlayer || bo.isItemRevealed))
                const Divider(color: Colors.white24, height: 1),
              if (bo.organism.equippedTalisman != null &&
                  (isPlayer || bo.isItemRevealed))
                const SizedBox(height: 10),

              // Revealed Moves (Opponent Only)
              if (!isPlayer && bm != null) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
                Text(
                  'REVEALED MOVES',
                  style: TextStyle(
                    color: _getBiomeThemeColor(),
                    fontSize: 9,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                const SizedBox(height: 6),
                if ((bm.battleStats[bo.organism.id]?.revealedMoves.isEmpty ??
                    true))
                  const Text(
                    'NONE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontFamily: 'PressStart2P',
                    ),
                  )
                else
                  ...bm.battleStats[bo.organism.id]!.revealedMoves.map((
                    moveName,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        moveName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
              ],

              // Abilities
              Text(
                'ABILITIES',
                style: TextStyle(
                  color: _getBiomeThemeColor(),
                  fontSize: 9,
                  fontFamily: 'PressStart2P',
                ),
              ),
              const SizedBox(height: 6),
              ...bo.abilities.map(
                (ab) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ab.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'PressStart2P',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ab.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: _getBiomePrimaryColor().withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'OK',
              style: TextStyle(
                color: _getBiomeThemeColor(),
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, String boost, Color color) {
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
              if (boost != '+0' && boost != '0')
                Text(
                  boost,
                  style: TextStyle(
                    color: boost.startsWith('+') ? Colors.green : Colors.red,
                    fontSize: 8,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              if (boost == '+0' || boost == '0')
                const Text(
                  '+0',
                  style: TextStyle(
                    color: Colors.white24,
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

  Widget _buildMessageBox(
    BuildContext context,
    String message,
    bool isNarrow, {
    bool expanded = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 12,
        vertical: isNarrow ? 4 : 8,
      ),
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 10 : 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getBiomeThemeColor(), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
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
                  child: TypewriterText(
                    message,
                    speed: const Duration(milliseconds: 50),
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

  void _showMoveDetails(
    BuildContext context,
    Move move,
    Color themeColor,
    BattleManager bm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _getBiomeSecondaryColor(),
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
              move.type.name.toUpperCase(),
              _getTypeColor(move.type),
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

  Widget _buildActionControls(
    BuildContext context,
    BattleManager battleManager,
    Color overlayColor,
    bool isNarrow,
    UserState userState,
  ) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isNarrow ? 8 : 12,
        0,
        isNarrow ? 8 : 12,
        isNarrow ? 4 : 6,
      ),
      padding: EdgeInsets.all(isNarrow ? 8 : 10),
      decoration: BoxDecoration(
        color: overlayColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBiomeThemeColor(), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'What will ${battleManager.player.organism.baseOrganism.name} do?',
            style: TextStyle(
              color: _getBiomeThemeColor(),
              fontSize: isNarrow ? 9 : 10,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(height: 4),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: isNarrow
                ? 3.4
                : (MediaQuery.of(context).orientation == Orientation.landscape
                      ? 4.2
                      : 3.6),
            children: battleManager.playerMoves.map((move) {
              final typeColor = _getTypeColor(move.type);
              final effectiveness = _calculateMoveEffectiveness(
                move,
                battleManager.opponent,
              );
              final effectivenessText = _getEffectivenessText(effectiveness);
              final categoryText = move.category
                  .toString()
                  .split('.')
                  .last
                  .toUpperCase();

              final isLocked =
                  battleManager.player.isChoiceLocked &&
                  battleManager.player.lockedMove != null &&
                  battleManager.player.lockedMove!.name != move.name;

              return ElevatedButton(
                onPressed: isLocked
                    ? null
                    : () => battleManager.processPlayerAction(move),
                onLongPress: () => _showMoveDetails(
                  context,
                  move,
                  _getBiomeThemeColor(),
                  battleManager,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocked ? Colors.grey[700] : typeColor,
                  foregroundColor: isLocked ? Colors.white24 : Colors.white,
                  padding: const EdgeInsets.all(4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isLocked
                          ? Colors.grey.withOpacity(0.3)
                          : Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  elevation: isLocked ? 0 : 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Move Name
                    Expanded(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          move.name,
                          style: TextStyle(
                            fontSize: isNarrow ? 9 : 11,
                            fontFamily: 'PressStart2P',
                            fontWeight: FontWeight.bold,
                            shadows: [
                              const Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Category & Stamina Row
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: move.category.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              categoryText.substring(0, 4), // PHYS, SPEC, STAT
                              style: const TextStyle(
                                fontSize: 6, // Very small
                                fontFamily: 'PressStart2P',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Stamina
                          Text(
                            '${battleManager.playerOrganism.moveStamina[move.name] ?? 0}/${move.stamina}',
                            style: TextStyle(
                              fontSize: isNarrow ? 7 : 8,
                              fontFamily: 'PressStart2P',
                              color:
                                  (battleManager.playerOrganism.moveStamina[move
                                              .name] ??
                                          0) >
                                      0
                                  ? Colors.white
                                  : Colors.redAccent,
                              shadows: [
                                const Shadow(
                                  blurRadius: 2,
                                  color: Colors.black54,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Effectiveness (if applicable)
                    if (move.category != MoveCategory.status &&
                        effectivenessText.isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              effectivenessText,
                              style: const TextStyle(
                                fontSize: 7,
                                fontFamily: 'PressStart2P',
                                color: Colors.yellowAccent,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(flex: 1),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (!battleManager.isArenaBattle) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: battleManager.attemptCapture,
                    icon: Icon(Icons.grid_on, size: isNarrow ? 14 : 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        'Net',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isNarrow ? 4 : 8,
                        horizontal: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (widget.isRogueMode) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showReleaseDialog(context, battleManager, userState),
                    icon: Icon(Icons.outbox, size: isNarrow ? 14 : 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        'Release',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isNarrow ? 4 : 8,
                        horizontal: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSwitchDialog(context, battleManager),
                  icon: Icon(Icons.swap_horiz, size: isNarrow ? 14 : 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const Text(
                      'Switch',
                      style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isNarrow ? 4 : 8,
                      horizontal: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: battleManager.attemptRun,
                  icon: Icon(Icons.directions_run, size: isNarrow ? 14 : 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const Text(
                      'Run',
                      style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isNarrow ? 4 : 8,
                      horizontal: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateWildMoneyReward(Organism opponent) {
    switch (opponent.rarity.toLowerCase()) {
      case 'common':
        return 50 + math.Random().nextInt(51); // 50-100
      case 'uncommon':
        return 150 + math.Random().nextInt(101); // 150-250
      case 'rare':
        return 400 + math.Random().nextInt(201); // 400-600
      case 'epic':
        return 1000 + math.Random().nextInt(501); // 1000-1500
      case 'legendary':
        return 3000 + math.Random().nextInt(2001); // 3000-5000
      case 'mythical':
        return 10000;
      default:
        return 50;
    }
  }

  void _showReleaseDialog(
    BuildContext context,
    BattleManager bm,
    UserState userState,
  ) {
    final runTeam = userState.currentUser?.rogueLikeState.team ?? [];
    if (runTeam.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one animal!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _getBiomeSecondaryColor(),
        title: Text(
          'RELEASE ANIMAL',
          style: TextStyle(
            color: _getBiomeThemeColor(),
            fontFamily: 'PressStart2P',
            fontSize: 12,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: runTeam.length,
            itemBuilder: (context, index) {
              final animal = runTeam[index];
              final isCurrent = animal.id == bm.player.organism.id;

              return ListTile(
                leading: Image.asset(
                  'assets/sprites/${animal.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                  width: 32,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.pets, color: Colors.white),
                ),
                title: Text(
                  animal.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
                trailing: isCurrent
                    ? const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 8,
                          fontFamily: 'PressStart2P',
                        ),
                      )
                    : const Icon(Icons.delete, color: Colors.red),
                onTap: isCurrent
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await userState.releaseFromRogueRun(index);
                      },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleBattleEnd(
    BuildContext context,
    BattleManager battleManager,
    UserState userState,
  ) {
    if (_isSwitchDialogShowing) return;
    if (_isHandlingBattleEnd) return; // FIX: Prevent duplicate execution
    _isHandlingBattleEnd = true;

    // Add delay to allow reading the final log message
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;

      int moneyEarned = 0;

      // Handle capture - add organism to collection
      if (battleManager.result == BattleResult.capture) {
        final wildOpponent = battleManager.opponent.organism;
        final newCapturedInstance = wildOpponent.copyWith(
          currentHealth: wildOpponent.maxHealth, // Heal to full on capture
        );
        newCapturedInstance.restoreAllStamina(); // Restore stamina on capture

        if (widget.isRogueMode) {
          final team = userState.currentUser?.rogueLikeState.team ?? [];
          if (team.length < 5) {
            await userState.captureForRogueRun(newCapturedInstance);
          } else {
            if (mounted) {
              setState(() {
                _pendingRogueCapture = newCapturedInstance;
              });
            }
          }
        } else {
          await userState.addCapturedOrganism(newCapturedInstance);
        }
      }

      // Handle loss - remove player's creature (death mechanic)
      // For Rogue-like mode, we remove from the Rogue run team
      // For basic wild battles, we remove from user collection
      if (battleManager.result == BattleResult.loss) {
        final deadCreature = battleManager.player.organism;
        if (widget.isRogueMode) {
          final runTeam = List<CapturedOrganism>.from(
            userState.currentUser?.rogueLikeState.team ?? [],
          );
          runTeam.removeWhere((co) => co.id == deadCreature.id);
          await userState.updateRogueTeam(runTeam);
        } else if (!widget.isArenaBattle) {
          await userState.removeCapturedOrganism(deadCreature);
        }
      }

      // Rogue-like specific progression
      if (widget.isRogueMode) {
        if (battleManager.result == BattleResult.win ||
            battleManager.result == BattleResult.capture) {
          // Perma-death: Remove any fainted animals from the team
          final currentTeam = userState.currentUser?.rogueLikeState.team ?? [];
          final List<CapturedOrganism> survivingTeam = currentTeam
              .where((o) => o.currentHealth > 0)
              .toList();

          // REORDER: Move the active animal (the one that finished the battle) to the lead position
          final activeOrg = battleManager.player.organism;
          final activeIndexInSurviving = survivingTeam.indexWhere(
            (o) => o.id == activeOrg.id,
          );
          if (activeIndexInSurviving > 0) {
            final active = survivingTeam.removeAt(activeIndexInSurviving);
            survivingTeam.insert(0, active);
          }

          // Update team (always update to ensure the lead animal order is persisted)
          await userState.updateRogueTeam(survivingTeam);

          // Increment encounter
          await userState.completeRogueEncounter();
        } else if (battleManager.result == BattleResult.loss) {
          // LOSS IN ROGUE-LIKE: Fully reset the run and release all animals in the team
          await userState.endRogueRun();
          // Note: endRogueRun clears the isActive flag and the team
        }
      }

      // Arena battle prize money (not for rogue mode usually, or different rewards)
      if (!widget.isRogueMode) {
        if (widget.isArenaBattle && battleManager.result == BattleResult.win) {
          moneyEarned = 1000;
          await userState.addMoney(moneyEarned);
        } else if (!widget.isArenaBattle &&
            battleManager.result == BattleResult.win) {
          // Wild battle prize money
          moneyEarned = _calculateWildMoneyReward(
            battleManager.opponent.organism.baseOrganism,
          );
          await userState.addMoney(moneyEarned);
        }
      }

      final String? lootId = battleManager.droppedLoot;
      final String? lootName = lootId != null
          ? LootItem.findById(lootId).name
          : null;

      // Handle loot drop
      if (battleManager.result == BattleResult.win && lootId != null) {
        await userState.addLoot(lootId, 1);
      }

      if (!mounted) return;

      // FIX: Defer result dialog if we have a pending rogue capture replacement
      if (_pendingRogueCapture != null) {
        _showCaptureReplaceDialog(context, _pendingRogueCapture!, userState);
      } else {
        _showBattleResultDialog(
          context,
          battleManager,
          moneyEarned,
          lootName,
          userState,
        );
      }
    });
  }

  void _showBattleResultDialog(
    BuildContext context,
    BattleManager battleManager,
    int moneyEarned,
    String? lootName,
    UserState userState,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BattleResultDialog(
        battleManager: battleManager,
        result: battleManager.result!,
        opponentName: battleManager.opponent.organism.baseOrganism.name,
        playerName: battleManager.player.organism.baseOrganism.name,
        moneyEarned: moneyEarned,
        lootName: lootName,
        themeColor: _getBiomeThemeColor(),
        primaryColor: _getBiomePrimaryColor(),
        secondaryColor: _getBiomeSecondaryColor(),
        onConfirm: () {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          Navigator.of(ctx).pop();

          if ((battleManager.result == BattleResult.win ||
                  battleManager.result == BattleResult.capture) &&
              widget.isRogueMode) {
            final rogue = userState.currentUser!.rogueLikeState;

            // Navigator logic:
            if (rogue.encounterIndex >= 5) {
              // 5th encounter completed -> index 5
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (ctx) => const BiomeSelectScreen()),
              );
            } else {
              // For non-boss battles, we go to the Hub
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (ctx) => const RogueHubScreen()),
              );
            }
          } else {
            Navigator.of(context).pop(battleManager.result);
          }
        },
      ),
    );
  }

  void _showCaptureReplaceDialog(
    BuildContext context,
    CapturedOrganism newCapture,
    UserState userState,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CaptureReplaceDialog(
        newCapture: newCapture,
        currentTeam: userState.currentUser?.rogueLikeState.team ?? [],
        themeColor: _getBiomeThemeColor(),
        primaryColor: _getBiomePrimaryColor(),
        secondaryColor: _getBiomeSecondaryColor(),
        onReplace: (index) async {
          await userState.replaceRogueTeamMember(index, newCapture);
          if (mounted) {
            setState(() {
              _pendingRogueCapture =
                  null; // Clear pending capture to prevent infinite loop
            });
          }
          if (ctx.mounted) Navigator.pop(ctx);

          if (mounted) {
            // Show result dialog after replacement
            _showBattleResultDialog(
              context,
              Provider.of<BattleManager>(context, listen: false),
              0, // No money in rogue
              null, // Loot handled separately or not needed to re-show
              userState,
            );
          }
        },
        onDiscard: () {
          if (mounted) {
            setState(() {
              _pendingRogueCapture =
                  null; // Clear pending capture to prevent infinite loop
            });
          }
          Navigator.pop(ctx);
          if (mounted) {
            // Show result dialog after discard
            _showBattleResultDialog(
              context,
              Provider.of<BattleManager>(context, listen: false),
              0,
              null,
              userState,
            );
          }
        },
      ),
    );
  }
}

class _CaptureReplaceDialog extends StatelessWidget {
  final CapturedOrganism newCapture;
  final List<CapturedOrganism> currentTeam;
  final Color themeColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Function(int) onReplace;
  final VoidCallback onDiscard;

  const _CaptureReplaceDialog({
    required this.newCapture,
    required this.currentTeam,
    required this.themeColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onReplace,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.highlightColor, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TEAM FULL!',
              style: TextStyle(
                color: AppColors.highlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 18,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose an animal to replace or discard the new capture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 8,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildNewCaptureCard(),
            const SizedBox(height: 10),
            const Icon(
              Icons.swap_vert,
              color: AppColors.highlightColor,
              size: 32,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currentTeam.length,
                itemBuilder: (context, index) {
                  return _buildReplaceCard(context, index);
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onDiscard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              child: const Text(
                'DISCARD NEW CAPTURE',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewCaptureCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.cyan.shade900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildSmallSprite(newCapture),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEW: ${newCapture.baseOrganism.name.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LV.${newCapture.level} ${newCapture.nature.name}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatGrid(newCapture),
        ],
      ),
    );
  }

  Widget _buildReplaceCard(BuildContext context, int index) {
    final member = currentTeam[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      child: InkWell(
        onTap: () => _confirmReplacement(context, index),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  _buildSmallSprite(member),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.baseOrganism.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'LV.${member.level} ${member.nature.name}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'PressStart2P',
                            fontSize: 7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_right, color: Colors.white24),
                ],
              ),
              const SizedBox(height: 8),
              _buildStatComparisonGrid(member),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallSprite(CapturedOrganism org) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _BattleSprite(
        organism: BattleOrganism(org, isRogueMode: true),
        size: 40,
        biomeName: 'Forest',
      ),
    );
  }

  Widget _buildStatGrid(CapturedOrganism org) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('HP', org.maxHealth),
        _buildStatItem('ATK', org.effectiveAttack),
        _buildStatItem('DEF', org.effectiveDefense),
        _buildStatItem('POW', org.effectivePower),
        _buildStatItem('RES', org.effectiveResistance),
        _buildStatItem('SPD', org.effectiveSpeed),
      ],
    );
  }

  Widget _buildStatComparisonGrid(CapturedOrganism member) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCompItem('HP', member.maxHealth, newCapture.maxHealth),
        _buildStatCompItem(
          'ATK',
          member.effectiveAttack,
          newCapture.effectiveAttack,
        ),
        _buildStatCompItem(
          'DEF',
          member.effectiveDefense,
          newCapture.effectiveDefense,
        ),
        _buildStatCompItem(
          'POW',
          member.effectivePower,
          newCapture.effectivePower,
        ),
        _buildStatCompItem(
          'RES',
          member.effectiveResistance,
          newCapture.effectiveResistance,
        ),
        _buildStatCompItem(
          'SPD',
          member.effectiveSpeed,
          newCapture.effectiveSpeed,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontFamily: 'PressStart2P',
            fontSize: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'PressStart2P',
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCompItem(String label, int current, int next) {
    final diff = next - current;
    Color diffColor = Colors.white70;
    if (diff > 0) diffColor = Colors.greenAccent;
    if (diff < 0) diffColor = Colors.redAccent;

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontFamily: 'PressStart2P',
            fontSize: 5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$current',
          style: TextStyle(
            color: diffColor,
            fontFamily: 'PressStart2P',
            fontSize: 7,
          ),
        ),
      ],
    );
  }

  void _confirmReplacement(BuildContext context, int index) {
    final member = currentTeam[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'REPLACE?',
          style: TextStyle(
            color: AppColors.highlightColor,
            fontFamily: 'PressStart2P',
            fontSize: 14,
          ),
        ),
        content: Text(
          'Really replace ${member.baseOrganism.name} with ${newCapture.baseOrganism.name}?',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'PressStart2P',
            fontSize: 9,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onReplace(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('REPLACE'),
          ),
        ],
      ),
    );
  }
}

class _BattleResultDialog extends StatelessWidget {
  final BattleResult result;
  final String opponentName;
  final String playerName;
  final int moneyEarned;
  final String? lootName;
  final VoidCallback onConfirm;
  final Color themeColor;
  final Color primaryColor;
  final Color secondaryColor;
  final BattleManager battleManager;

  const _BattleResultDialog({
    required this.result,
    required this.opponentName,
    required this.playerName,
    required this.moneyEarned,
    this.lootName,
    required this.onConfirm,
    required this.themeColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.battleManager,
  });

  void _showStats(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: secondaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeColor, width: 2),
        ),
        title: Text(
          'BATTLE STATS',
          style: TextStyle(
            color: themeColor,
            fontFamily: 'PressStart2P',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatsSection('PLAYER TEAM', battleManager.playerTeam),
                const SizedBox(height: 16),
                _buildStatsSection('OPPONENT TEAM', battleManager.opponentTeam),
              ],
            ),
          ),
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

  Widget _buildStatsSection(String title, List<CapturedOrganism> team) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'PressStart2P',
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        ...team.map((org) {
          final stats = battleManager.battleStats[org.id] ?? BattleStats();
          return _buildStatRow(
            org.name,
            stats.totalDamageDealt,
            stats.totalDamageTaken,
            battleManager.playerTeam.contains(org),
          );
        }),
      ],
    );
  }

  Widget _buildStatRow(String name, int dealt, int taken, bool isPlayer) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: TextStyle(
                color: isPlayer ? Colors.greenAccent : Colors.redAccent,
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'D:',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 7,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$dealt',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'T:',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 7,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$taken',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontFamily: 'PressStart2P',
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

  void _showMvp(BuildContext context) {
    CapturedOrganism? mvp;
    int maxDamage = -1;

    for (final org in battleManager.playerTeam) {
      final stats = battleManager.battleStats[org.id];
      if (stats != null && stats.totalDamageDealt > maxDamage) {
        maxDamage = stats.totalDamageDealt;
        mvp = org;
      }
    }

    if (mvp == null && battleManager.playerTeam.isNotEmpty) {
      mvp = battleManager.playerTeam.first;
    }

    if (mvp == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: secondaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.amber, width: 3),
        ),
        title: const Column(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 48),
            SizedBox(height: 8),
            Text(
              'MVP',
              style: TextStyle(
                color: Colors.amber,
                fontFamily: 'PressStart2P',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: _BattleSprite(
                organism: BattleOrganism(mvp!, isRogueMode: true),
                size: 80,
                biomeName: 'forest',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              mvp.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (maxDamage > 0)
              Text(
                'DAMAGE DEALT: $maxDamage',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                ),
              )
            else
              const Text(
                'PARTICIPATION MEDAL',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'NICE!',
              style: TextStyle(
                color: Colors.amber,
                fontFamily: 'PressStart2P',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String titleText;
    Color titleColor;
    String description;
    IconData mainIcon;

    switch (result) {
      case BattleResult.win:
        titleText = 'VICTORY!';
        titleColor = themeColor;
        description = 'You defeated the wild encounter!';
        mainIcon = Icons.emoji_events;
        break;
      case BattleResult.loss:
        titleText = 'DEFEAT!';
        titleColor = Colors.redAccent;
        description = 'Your $playerName has died in battle...';
        mainIcon = Icons.error;
        break;
      case BattleResult.capture:
        titleText = 'CAPTURED!';
        titleColor = Colors.cyanAccent;
        description = 'You successfully captured the $opponentName!';
        mainIcon = Icons.catching_pokemon;
        break;
      case BattleResult.fled:
        titleText = 'ESCAPED!';
        titleColor = Colors.grey;
        description = 'You ran away safely!';
        mainIcon = Icons.directions_run;
        break;
    }

    return AlertDialog(
      backgroundColor: secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: titleColor, width: 3),
      ),
      title: Column(
        children: [
          Icon(mainIcon, color: titleColor, size: 48),
          const SizedBox(height: 12),
          Text(
            titleText,
            style: TextStyle(
              color: titleColor,
              fontFamily: 'PressStart2P',
              fontSize: 20,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 10,
              height: 1.5,
            ),
          ),
          if (moneyEarned > 0 || lootName != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  if (moneyEarned > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.yellow,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+$moneyEarned GOLD',
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (lootName != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          color: Colors.purpleAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LOOT: $lootName',
                          style: const TextStyle(
                            color: Colors.purpleAccent,
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _showStats(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: themeColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'STATS',
                    style: TextStyle(
                      color: themeColor,
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showMvp(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'MVP',
                    style: TextStyle(
                      color: Colors.amber,
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                side: BorderSide(color: titleColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'CONTINUE',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BattleSprite extends StatefulWidget {
  final BattleOrganism organism;
  final double size;
  final VoidCallback? onLongPress;
  final bool mirror;

  const _BattleSprite({
    required this.organism,
    required this.size,
    this.onLongPress,
    this.mirror = false,
    required this.biomeName,
  });

  final String biomeName;

  @override
  State<_BattleSprite> createState() => _BattleSpriteState();
}

class _BattleSpriteState extends State<_BattleSprite>
    with SingleTickerProviderStateMixin {
  String? _imageSourceType;
  late String _imagePath;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BattleSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.organism.organism.baseOrganism.name !=
            oldWidget.organism.organism.baseOrganism.name ||
        widget.organism.organism.baseOrganism.sprite !=
            oldWidget.organism.organism.baseOrganism.sprite) {
      _determineImageSource();
    }
  }

  String _getLocalPath() {
    final fileName = widget.organism.organism.baseOrganism.name
        .toString()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll('-', '_');
    return 'assets/sprites/$fileName.png';
  }

  Future<void> _determineImageSource() async {
    final localPath = _getLocalPath();
    try {
      await rootBundle.load(localPath);
      if (mounted) {
        setState(() {
          _imageSourceType = 'local';
          _imagePath = localPath;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _imageSourceType = 'network';
          _imagePath = widget.organism.organism.baseOrganism.sprite;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (_imageSourceType == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final imageWidget = _imageSourceType == 'local'
        ? Image.asset(
            _imagePath,
            width: size,
            height: size,
            fit: BoxFit.contain,
          )
        : Image.network(
            _imagePath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.pets, color: Colors.white54, size: 40),
          );

    Color platformColor;
    final biome = widget.biomeName.toLowerCase();
    if (biome.contains('swamp')) {
      platformColor = const Color(0xFF4E342E); // Dark Brown
    } else if (biome.contains('desert') || biome.contains('savanna')) {
      platformColor = const Color(0xFFE0C487); // Sand/Dry Grass
    } else if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra')) {
      platformColor = const Color(0xFFE0F7FA); // Icy Blue
    } else if (biome.contains('volcan')) {
      platformColor = const Color(0xFF3E2723); // Dark Ash
    } else if (biome.contains('mountain')) {
      platformColor = const Color(0xFF757575); // Grey Rock
    } else if (biome.contains('forest') || biome.contains('jungle')) {
      platformColor = const Color(0xFF2E7D32); // Green
    } else if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river')) {
      platformColor = const Color(0xFF0277BD); // Deep Blue
    } else {
      platformColor = const Color(0xFF8D6E63); // Generic Dirt
    }

    // Darker complementary outline for PLATFORM
    final platformOutlineColor = HSLColor.fromColor(platformColor)
        .withLightness(
          (HSLColor.fromColor(platformColor).lightness - 0.2).clamp(0.0, 1.0),
        )
        .toColor();

    // Saturation Boost (1.3x) + Slight Contrast
    // Standard saturation matrix calculation
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

    final enhancedImage = ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Colors.transparent,
        BlendMode.multiply,
      ), // Basis
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(matrix),
        child: widget.mirror
            ? Transform.flip(flipX: true, child: imageWidget)
            : imageWidget,
      ),
    );

    // Sprite Outline Logic
    final spriteOutlineColor = Colors.black.withOpacity(0.8);
    const double outlineOffset = 1.0;

    final outlineImage = ColorFiltered(
      colorFilter: ColorFilter.mode(spriteOutlineColor, BlendMode.srcIn),
      child: widget.mirror
          ? Transform.flip(flipX: true, child: imageWidget)
          : imageWidget,
    );

    // --- Status / Visibility Logic ---
    final bo = widget.organism;
    final isInvulnerable = bo.isInvulnerable;
    final hasStealth = bo.statusEffects.any(
      (se) => se.type == StatusEffectType.stealth,
    );

    // Primary status overlay (first non-none status)
    final overlayStatus = bo.statusEffects.isNotEmpty
        ? bo.statusEffects.firstWhere(
            (se) => se.type != StatusEffectType.none,
            orElse: () => const StatusEffect(type: StatusEffectType.none),
          )
        : const StatusEffect(type: StatusEffectType.none);
    final overlayPath = overlayStatus.overlayAssetPath;

    // Sprite and outline layers — hidden or faded based on state
    final Widget spriteLayer = isInvulnerable
        ? SizedBox(width: size, height: size)
        : (hasStealth
              ? Opacity(opacity: 0.35, child: enhancedImage)
              : enhancedImage);

    final Widget outlineLayer = isInvulnerable
        ? const SizedBox.shrink()
        : (hasStealth
              ? Opacity(opacity: 0.35, child: outlineImage)
              : outlineImage);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // The Platform
            Positioned(
              bottom: -size * 0.05,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateX(
                    1.1,
                  ), // slightly less flattened rotation for visibility
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: size * 1.3, // Extended width
                      height: size * 0.9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, // Oval due to width > height
                        border: Border.all(
                          color: platformOutlineColor,
                          width: 3, // Thicker outline
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.8,
                          colors: [
                            platformColor.withOpacity(
                              _pulseAnimation.value * 0.5,
                            ), // Fading middle
                            platformColor.withOpacity(0.9), // Solid edge
                          ],
                          stops: const [0.2, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Outline Layers (4 directions) — hidden/faded based on state
            Transform.translate(
              offset: const Offset(-outlineOffset, -outlineOffset),
              child: outlineLayer,
            ),
            Transform.translate(
              offset: const Offset(outlineOffset, -outlineOffset),
              child: outlineLayer,
            ),
            Transform.translate(
              offset: const Offset(-outlineOffset, outlineOffset),
              child: outlineLayer,
            ),
            Transform.translate(
              offset: const Offset(outlineOffset, outlineOffset),
              child: outlineLayer,
            ),

            // The Sprite — hidden when invulnerable, faded when stealthed
            spriteLayer,

            // Status overlay image — shown on top of sprite when statused
            if (!isInvulnerable && overlayPath != null)
              Positioned.fill(
                child: Image.asset(
                  overlayPath,
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.85),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;

  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.speed = const Duration(milliseconds: 50),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
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

class _AbilityPopUp extends StatefulWidget {
  final AbilityNotification notification;
  final Color themeColor;
  final LayerLink link;

  const _AbilityPopUp({
    required this.notification,
    required this.themeColor,
    required this.link,
  });

  @override
  State<_AbilityPopUp> createState() => _AbilityPopUpState();
}

class _AbilityPopUpState extends State<_AbilityPopUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(
      begin: -20.0, // Smaller slide from below
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: widget.link,
      showWhenUnlinked: false,
      offset: Offset.zero,
      targetAnchor: Alignment.center,
      followerAnchor: Alignment.center,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            border: Border.all(color: widget.themeColor, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${widget.notification.animalName}'S",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.notification.abilityName.toUpperCase(),
                style: TextStyle(
                  color: widget.themeColor,
                  fontSize: 14,
                  fontFamily: 'PressStart2P',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
