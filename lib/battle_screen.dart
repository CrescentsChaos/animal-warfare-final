// lib/battle_screen.dart

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, SystemChrome, DeviceOrientation;
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/rogue/biome_select_screen.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/loot_item.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/models/elemental_type.dart'; // Added
import 'package:animal_warfare/models/move.dart'; // Added
import 'package:animal_warfare/models/status_effect.dart'; // Added for overlay
import 'dart:math' as math;
import 'dart:async';
import 'package:animal_warfare/widgets/capture_overlay.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/widgets/terrain_overlay.dart';
import 'package:animal_warfare/widgets/item_icon.dart';
import 'package:animal_warfare/widgets/anidex_details_sheet.dart';
import 'package:animal_warfare/widgets/type_matchup_sheet.dart';

class BattleScreen extends StatelessWidget {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  final String biomeName;
  final List<CapturedOrganism>? playerTeam;
  final String? battleTitle;
  final bool isArenaBattle;
  final List<CapturedOrganism>? opponentTeam;
  final bool isRogueMode;
  final TeamArchetype? opponentArchetype;
  final String? timeOfDay;
  final bool startAsleep;

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
    this.opponentArchetype,
    this.timeOfDay,
    this.startAsleep = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final userState = Provider.of<UserState>(context, listen: false);
        return BattleManager(
          playerOrganism,
          opponentOrganism,
          biomeName: biomeName,
          team: playerTeam,
          opponentTeam: opponentTeam,
          isArenaBattle: isArenaBattle,
          isRogueMode: isRogueMode,
          opponentArchetype: opponentArchetype,
          accountLevel: userState.currentUser?.accountLevel ?? 100,
          initialPlayerIndex: isRogueMode
              ? userState.currentUser?.rogueLikeState.currentPlayerIndex
              : null,
          startAsleep: startAsleep,
        );
      },
      child: BattleScreenContent(
        biomeName: biomeName,
        opponentName: opponentOrganism.baseOrganism.name,
        battleTitle: battleTitle,
        isArenaBattle: isArenaBattle,
        isRogueMode: isRogueMode,
        timeOfDay: timeOfDay,
        opponentFullTeam: opponentTeam,
        startAsleep: startAsleep,
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
  final String? timeOfDay;

  /// Full opponent team for winrate recording (arena battles)
  final List<CapturedOrganism>? opponentFullTeam;
  final bool startAsleep;

  const BattleScreenContent({
    super.key,
    required this.biomeName,
    required this.opponentName,
    this.battleTitle,
    this.isArenaBattle = false,
    this.isRogueMode = false,
    this.timeOfDay,
    this.opponentFullTeam,
    this.startAsleep = false,
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
  bool _isHandlingBattleEnd = false;
  CapturedOrganism? _pendingRogueCapture;
  BattleManager? _battleManager;
  final LayerLink _playerLink = LayerLink();
  final LayerLink _opponentLink = LayerLink();
  final List<_IndicatorData> _indicators = [];

  // Move animation tracking
  final List<_MoveAnimData> _moveAnims = [];
  int _moveAnimIdCounter = 0;
  double _screenShakeX = 0;
  double _screenShakeY = 0;
  AnimationController? _screenShakeController;
  Animation<double>? _screenShakeXAnim;
  Animation<double>? _screenShakeYAnim;

  Map<String, dynamic> _cumulativeXPResults = {};

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
      bm.onDamage = _onDamage;
      bm.onHeal = _onHeal;
      bm.onStatChange = _onStatChange;
      bm.onVictory = _onVictory;
      bm.onOpponentFainted = _onOpponentFainted;

      // Sync rogue state mid-battle
      if (widget.isRogueMode) {
        bm.addListener(_syncRogueState);
      }
      bm.addListener(_handleStateTriggers);
    });
  }

  void _handleStateTriggers() {
    if (!mounted) return;
    final bm = Provider.of<BattleManager>(context, listen: false);

    if (bm.currentState == BattleState.choosingLead &&
        !_isSwitchDialogShowing) {
      _showPartyScreen(
        context,
        bm,
        title: 'CHOOSE YOUR LEAD!',
        isForced: true,
        isLeadSelection: true,
      );
    } else if (bm.currentState == BattleState.waitingForPlayerSwitch &&
        !_isSwitchDialogShowing) {
      _showPartyScreen(context, bm, isForced: true);
    } else if (bm.currentState == BattleState.battleEnd) {
      final userState = Provider.of<UserState>(context, listen: false);
      _handleBattleEnd(context, bm, userState);
    }
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
    if (_battleManager != null) {
      if (widget.isRogueMode) {
        _battleManager!.removeListener(_syncRogueState);
      }
      _battleManager!.removeListener(_handleStateTriggers);
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

  // Moves that trigger full-screen shake instead of/in addition to sprite shake
  static const _screenShakeMoves = {
    'earthquake',
    'magnitude',
    'bulldoze',
    'stomping tantrum',
    'fissure',
    'land\'s wrath',
    'high horsepower',
    'precipice blades',
    'thousand arrows',
  };

  void _onAttack(BattleOrganism attacker, Move move) {
    if (!mounted) return;

    final bm = Provider.of<BattleManager>(context, listen: false);
    final isPlayerAttacking = attacker == bm.player;
    final isScreenShake = _screenShakeMoves.contains(move.name.toLowerCase());

    // Attacker sprite shake
    if (isPlayerAttacking) {
      _playerShakeController.forward(from: 0);
    } else {
      _opponentShakeController.forward(from: 0);
    }

    // Full-screen shake for ground moves
    if (isScreenShake) {
      _runScreenShake();
    }

    // Spawn move animation overlay
    final id = ++_moveAnimIdCounter;
    setState(() {
      _moveAnims.add(
        _MoveAnimData(id: id, move: move, isPlayerAttacking: isPlayerAttacking),
      );
    });

    // Remove after animation completes
    final duration = isScreenShake
        ? const Duration(milliseconds: 2000)
        : const Duration(milliseconds: 4000);
    Future.delayed(duration, () {
      if (mounted) {
        setState(() => _moveAnims.removeWhere((a) => a.id == id));
      }
    });
  }

  void _runScreenShake() {
    _screenShakeController?.dispose();
    _screenShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final rand = Random();
    _screenShakeXAnim = TweenSequence<double>([
      for (int i = 0; i < 6; i++) ...[
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: (rand.nextDouble() * 16 - 8)),
          weight: 1,
        ),
      ],
    ]).animate(_screenShakeController!);
    _screenShakeYAnim = TweenSequence<double>([
      for (int i = 0; i < 6; i++) ...[
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: (rand.nextDouble() * 14 - 7)),
          weight: 1,
        ),
      ],
    ]).animate(_screenShakeController!);
    _screenShakeController!.addListener(() {
      if (mounted) {
        setState(() {
          _screenShakeX = _screenShakeXAnim?.value ?? 0;
          _screenShakeY = _screenShakeYAnim?.value ?? 0;
        });
      }
    });
    _screenShakeController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _screenShakeX = 0;
          _screenShakeY = 0;
        });
      }
    });
    _screenShakeController!.forward(from: 0);
  }

  void _onDamage(BattleOrganism target, int amount) {
    if (!mounted) return;
    _addIndicator("-$amount", Colors.redAccent, target.isPlayer);
  }

  void _onHeal(BattleOrganism target, int amount) {
    if (!mounted) return;
    _addIndicator("+$amount", Colors.greenAccent, target.isPlayer);
  }

  void _onStatChange(BattleOrganism target, String stat, int value) {
    if (!mounted) return;
    final direction = value > 0 ? "↑" : "↓";
    final color = value > 0 ? Colors.cyanAccent : Colors.orangeAccent;
    final absVal = value.abs();
    final bonus = absVal > 1 ? (absVal == 2 ? "!!" : "!!!") : "";
    _addIndicator(
      "${stat.toUpperCase()} $direction$bonus",
      color,
      target.isPlayer,
    );
  }

  void _addIndicator(String text, Color color, bool isPlayer) {
    final id = DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000);
    setState(() {
      _indicators.add(
        _IndicatorData(id: id, text: text, color: color, isPlayer: isPlayer),
      );
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _indicators.removeWhere((i) => i.id == id);
        });
      }
    });
  }

  void _onVictory() {
    if (!mounted) return;
    // Quest progress shifted to encounter phase in initState
  }

  Future<void> _onOpponentFainted(
    BattleOrganism killer,
    BattleOrganism victim,
  ) async {
    if (!mounted) return;
    final userState = Provider.of<UserState>(context, listen: false);
    final bm = Provider.of<BattleManager>(context, listen: false);

    // Award XP
    int? levelCap;
    if (widget.isRogueMode) {
      final rogue = userState.currentUser?.rogueLikeState;
      if (rogue != null) {
        levelCap = rogue.floor * 5;
      }
    }

    if (!widget.isArenaBattle) {
      final results = await userState.awardBattleXP(
        defeatedLevel: victim.level,
        killerId: killer.organism.id,
        teamIds: bm.playerTeam.map((o) => o.id).toList(),
        levelCap: levelCap,
      );

      if (!mounted) return;

      // Award KV (Kill Values) to the killer animal
      if (killer.isPlayer) {
        await userState.awardKV(
          killer.organism.id,
          victim.organism.baseOrganism,
        );
      }
      if (!mounted) return;

      setState(() {
        // Merge results
        _cumulativeXPResults['gainedAnimalXP'] =
            (_cumulativeXPResults['gainedAnimalXP'] ?? 0) +
            (results['gainedAnimalXP'] ?? 0);
        _cumulativeXPResults['gainedAccountXP'] =
            (_cumulativeXPResults['gainedAccountXP'] ?? 0) +
            (results['gainedAccountXP'] ?? 0);

        if (results['accountLeveledUp'] == true) {
          _cumulativeXPResults['accountLeveledUp'] = true;
        }

        final animalLeveledUp =
            results['animalLeveledUp'] as Map<String, bool>? ?? {};
        final cumulativeLeveledUp =
            _cumulativeXPResults['animalLeveledUp'] as Map<String, bool>? ?? {};

        animalLeveledUp.forEach((id, leveled) {
          if (leveled) cumulativeLeveledUp[id] = true;
        });
        _cumulativeXPResults['animalLeveledUp'] = cumulativeLeveledUp;

        // Immediately refresh stats for the active animal if it leveled up
        final freshUser = userState.currentUser;
        if (freshUser != null) {
          // Update all animals in the BattleManager's team list with fresh data
          for (int i = 0; i < bm.playerTeam.length; i++) {
            final oldId = bm.playerTeam[i].id;
            try {
              final freshOrg = widget.isRogueMode
                  ? freshUser.rogueLikeState.team.firstWhere(
                      (o) => o.id == oldId,
                    )
                  : freshUser.capturedOrganisms.firstWhere(
                      (o) => o.id == oldId,
                    );
              bm.playerTeam[i] = freshOrg;

              // If this is the currently active animal, sync its BattleOrganism wrapper
              if (bm.player.organism.id == oldId) {
                bm.player.organism = freshOrg;
                bm.player.recalculateStats();
              }
            } catch (_) {
              // Animal might not be in the team anymore or some other shift
            }
          }
        }
      });

      // Notify user of level up in log
      final animalLeveledUp =
          results['animalLeveledUp'] as Map<String, bool>? ?? {};
      animalLeveledUp.forEach((id, leveled) {
        if (leveled) {
          final org = bm.playerTeam.firstWhere((o) => o.id == id);
          bm.addToLog(
            '${org.baseOrganism.name} leveled up to Lvl ${org.level}!',
          );
        }
      });
    }
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
    final themeColor = _getBiomeThemeColor();
    final primaryColor = _getBiomePrimaryColor();
    final secondaryColor = _getBiomeSecondaryColor();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: isNarrow ? 0.7 : 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: secondaryColor.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // HandleBar for DraggableSheet
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history_edu,
                              color: themeColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'BATTLE LOG',
                              style:
                                  AppTextStyles.headline(
                                    context,
                                    baseSize: 16,
                                    color: Colors.white,
                                  ).copyWith(
                                    letterSpacing: 2.0,
                                    shadows: [
                                      Shadow(
                                        color: themeColor.withValues(
                                          alpha: 0.8,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      // Reverse order of turns (Latest turn first)
                      itemCount: battleManager.turnHistory.length,
                      itemBuilder: (_, i) {
                        final turnIndex =
                            battleManager.turnHistory.length - 1 - i;
                        final turn = battleManager.turnHistory[turnIndex];

                        if (turn.logEntries.isEmpty)
                          return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Turn Header with Gradient Underscore
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: themeColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'TURN ${turn.turnNumber}',
                                      style: TextStyle(
                                        color: themeColor,
                                        fontSize: 10,
                                        fontFamily: 'PressStart2P',
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            themeColor.withValues(alpha: 0.5),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Log Entries for this turn (Chronological)
                            ...turn.logEntries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.black.withValues(alpha: 0.2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Icon(
                                          Icons.arrow_right,
                                          size: 16,
                                          color: themeColor.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          entry,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                            fontSize: isNarrow ? 10 : 11,
                                            fontFamily: 'PressStart2P',
                                            height: 1.6,
                                            shadows: [
                                              const Shadow(
                                                color: Colors.black,
                                                offset: Offset(1, 1),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
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
        ),
      ),
    );
  }

  Widget _buildXPBar(CapturedOrganism org) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'XP',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                fontFamily: 'PressStart2P',
              ),
            ),
            Text(
              '${(org.xpRatio * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 7,
                fontFamily: 'PressStart2P',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: org.xpRatio,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Future<void> _showPartyScreen(
    BuildContext context,
    BattleManager bm, {
    String title = 'SELECT ANIMAL',
    bool isForced = false,
    bool isLeadSelection = false,
  }) {
    _isSwitchDialogShowing = true;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isForced,
      enableDrag: !isForced,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => PopScope(
        canPop: !isForced,
        onPopInvoked: (_) {
          _isSwitchDialogShowing = false;
        },
        child: _PartyScreenDialog(
          bm: bm,
          title: title,
          isForced: isForced,
          isLeadSelection: isLeadSelection,
          themeColor: _getBiomeThemeColor(),
          primaryColor: _getBiomePrimaryColor(),
          onDismiss: () => _isSwitchDialogShowing = false,
          onShowSummary: (bo) {
            _showOrganismInfo(context, bo, bm: bm, isPlayer: true);
          },
          onSelect: (index) {
            Navigator.pop(ctx);
            _isSwitchDialogShowing = false;
            if (isLeadSelection) {
              bm.setLeadAnimal(index);
            } else {
              bm.switchAnimal(index);
            }
          },
        ),
      ),
    ).whenComplete(() => _isSwitchDialogShowing = false);
  }

  // Keep for compatibility but redirect to new screen
  Future<void> _showSwitchDialog(BuildContext context, BattleManager bm) {
    return _showPartyScreen(
      context,
      bm,
      isForced: bm.currentState == BattleState.waitingForPlayerSwitch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final battleManager = Provider.of<BattleManager>(context);
    final userState = Provider.of<UserState>(context, listen: false);
    final isNarrow = MediaQuery.sizeOf(context).width < 400;

    // Moved _handleBattleEnd to _handleStateTriggers (listener) to avoid build-phase side effects.

    final overlayColor = Colors.black.withValues(alpha: 0.55);

    // Initialize/Update listener
    battleManager.onAttack = _onAttack;
    battleManager.onDamage = _onDamage;
    battleManager.onHeal = _onHeal;
    battleManager.onStatChange = _onStatChange;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If in waiting for input and it's an exploration fight, act as run
        if (battleManager.currentState == BattleState.waitingForInput &&
            !widget.isArenaBattle &&
            !widget.isRogueMode) {
          await battleManager.attemptRun();
        }
      },
      child: Scaffold(
        body: Transform.translate(
          offset: Offset(_screenShakeX, _screenShakeY),
          child: Stack(
            children: [
              StreamBuilder<GameTime>(
                stream: TimeService().timeStream,
                builder: (context, snapshot) {
                  final hour = TimeService().currentGameTime.hour;
                  final timeOfDay = (hour >= 6 && hour < 18)
                      ? 'day'
                      : (hour >= 18 && hour < 21 ? 'evening' : 'night');

                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(_getAssetPath(widget.biomeName)),
                        fit: BoxFit.cover,
                        colorFilter: timeOfDay == 'day'
                            ? ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.35),
                                BlendMode.darken,
                              )
                            : ColorFilter.mode(
                                timeOfDay == 'evening'
                                    ? Colors.orangeAccent.withValues(alpha: 0.3)
                                    : Colors.indigo[900]!.withValues(
                                        alpha: 0.5,
                                      ),
                                BlendMode.darken,
                              ),
                      ),
                    ),
                  );
                },
              ),
              if (battleManager.trickRoomTurns > 0) const _TrickRoomOverlay(),
              // Weather Overlay
              WeatherOverlay(weather: battleManager.currentWeather.weather),
              // Terrain Overlay
              if (battleManager.currentTerrain.terrain != Terrain.none)
                TerrainOverlay(terrain: battleManager.currentTerrain.terrain),
              // Tailwind Overlay
              TailwindOverlay(
                isActive:
                    battleManager.playerTailwindTurns > 0 ||
                    battleManager.opponentTailwindTurns > 0,
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
                                      _buildFieldEffects(
                                        context,
                                        battleManager,
                                      ),
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
                                          battleManager.opponentHazards,
                                          battleManager,
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
                                          battleManager.playerHazards,
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
                                  battleManager.opponentHazards,
                                  battleManager,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                                  battleManager.playerHazards,
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
              if (battleManager.isCapturing)
                CaptureNetOverlay(
                  shakeCount: battleManager.captureShakeCount,
                  isSuccess: battleManager.result == BattleResult.capture,
                  isFailed:
                      battleManager.result == null &&
                      battleManager.currentState == BattleState.opponentTurn,
                  link: _opponentLink,
                  onComplete: () {},
                ),
              // Floating Indicators
              ..._indicators.map(
                (ind) => _FloatingIndicatorWidget(
                  key: ValueKey(ind.id),
                  data: ind,
                  link: ind.isPlayer ? _playerLink : _opponentLink,
                ),
              ),
              // Move Animation Overlays
              ..._moveAnims.map(
                (anim) => _MoveAnimationOverlay(
                  key: ValueKey(anim.id),
                  data: anim,
                  playerLink: _playerLink,
                  opponentLink: _opponentLink,
                  getTypeColor: _getTypeColor,
                ),
              ),
            ],
          ),
        ),
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
              Row(
                children: [
                  Text(
                    widget.battleTitle ?? 'Wild Encounter',
                    style: AppTextStyles.headline(
                      context,
                      baseSize: 12,
                      color: _getBiomeThemeColor(),
                    ),
                  ),
                  if (widget.startAsleep) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.lightBlueAccent,
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.nights_stay,
                            color: Colors.lightBlueAccent,
                            size: 10,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'OFF-TIME',
                            style: TextStyle(
                              color: Colors.lightBlueAccent,
                              fontFamily: 'PressStart2P',
                              fontSize: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
    final hasGlobal =
        bm.currentWeather.weather != Weather.none ||
        bm.currentTerrain.terrain != Terrain.none ||
        bm.trickRoomTurns > 0;

    final hasPlayerSide =
        bm.playerTailwindTurns > 0 ||
        bm.playerReflectTurns > 0 ||
        bm.playerLightScreenTurns > 0 ||
        bm.playerAuroraVeilTurns > 0;

    final hasOpponentSide =
        bm.opponentTailwindTurns > 0 ||
        bm.opponentReflectTurns > 0 ||
        bm.opponentLightScreenTurns > 0 ||
        bm.opponentAuroraVeilTurns > 0;

    if (!hasGlobal && !hasPlayerSide && !hasOpponentSide) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasGlobal)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (bm.currentWeather.weather != Weather.none)
                    _buildWeatherIndicator(bm.currentWeather.weather),
                  if (bm.currentTerrain.terrain != Terrain.none)
                    _buildTerrainIndicator(bm.currentTerrain.terrain),
                  if (bm.trickRoomTurns > 0)
                    _buildEffectIndicator(
                      'TRICK ROOM (${bm.trickRoomTurns})',
                      Colors.deepPurple.shade700,
                      Icons.architecture,
                    ),
                ],
              ),
            ),
          if (hasPlayerSide || hasOpponentSide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 2,
                    children: [
                      if (bm.playerTailwindTurns > 0)
                        _buildEffectIndicator(
                          'TWIND (${bm.playerTailwindTurns})',
                          Colors.lightBlue,
                          Icons.air,
                        ),
                      if (bm.playerReflectTurns > 0)
                        _buildEffectIndicator(
                          'REFL (${bm.playerReflectTurns})',
                          Colors.orange,
                          Icons.shield,
                        ),
                      if (bm.playerLightScreenTurns > 0)
                        _buildEffectIndicator(
                          'L.SCR (${bm.playerLightScreenTurns})',
                          Colors.yellow.shade700,
                          Icons.wb_sunny,
                        ),
                      if (bm.playerAuroraVeilTurns > 0)
                        _buildEffectIndicator(
                          'AURV (${bm.playerAuroraVeilTurns})',
                          Colors.cyan,
                          Icons.star,
                        ),
                    ],
                  ),
                ),
                if (hasPlayerSide && hasOpponentSide)
                  Container(
                    width: 1,
                    height: 16,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 2,
                    children: [
                      if (bm.opponentTailwindTurns > 0)
                        _buildEffectIndicator(
                          'FOE TWIND (${bm.opponentTailwindTurns})',
                          Colors.lightBlue.shade800,
                          Icons.air,
                        ),
                      if (bm.opponentReflectTurns > 0)
                        _buildEffectIndicator(
                          'FOE REFL (${bm.opponentReflectTurns})',
                          Colors.orange.shade800,
                          Icons.shield,
                        ),
                      if (bm.opponentLightScreenTurns > 0)
                        _buildEffectIndicator(
                          'FOE L.SCR (${bm.opponentLightScreenTurns})',
                          Colors.yellow.shade900,
                          Icons.wb_sunny,
                        ),
                      if (bm.opponentAuroraVeilTurns > 0)
                        _buildEffectIndicator(
                          'FOE AURV (${bm.opponentAuroraVeilTurns})',
                          Colors.cyan.shade800,
                          Icons.star,
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherIndicator(Weather weather) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white70),
      ),
      child: Text(
        weather.toString().split('.').last.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'PressStart2P',
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _buildTerrainIndicator(Terrain terrain) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white70),
      ),
      child: Text(
        terrain.toString().split('.').last.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'PressStart2P',
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _buildEffectIndicator(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 9),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 8.5,
            ),
          ),
        ],
      ),
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
    List<String> hazards, // Added
    BattleManager bm, // Added
  ) {
    final displayLevel = widget.isArenaBattle ? 50 : organism.organism.level;
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
            color: Colors.black.withValues(alpha: 0.4),
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
              '${base.name} LV.$displayLevel',
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
                  ItemIcon(
                    itemName: organism.organism.equippedTalisman!.name,
                    size: 14,
                  ),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final inAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                );
                final outAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInBack,
                );

                if (child.key == ValueKey(organism.organism.id)) {
                  // Switch In
                  return ScaleTransition(
                    scale: inAnimation,
                    child: FadeTransition(opacity: inAnimation, child: child),
                  );
                } else {
                  // Switch Out
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(outAnimation),
                    child: FadeTransition(opacity: outAnimation, child: child),
                  );
                }
              },
              child: _BattleSprite(
                key: ValueKey(organism.organism.id),
                organism: organism,
                size: spriteSize,
                hideAnimal:
                    bm.result == BattleResult.capture && !bm.isCapturing,
                onLongPress: () =>
                    _showOrganismInfo(context, organism, isPlayer: false),
                mirror: false, // Mirrored from previous State
                biomeName: widget.biomeName,
                hazards: hazards,
              ),
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
    List<String> hazards, // Added
  ) {
    final base = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final spriteSize = isLandscape
        ? (isNarrow ? 100.0 : 120.0)
        : (isNarrow ? 140.0 : 170.0);

    final displayLevel = widget.isArenaBattle ? 50 : organism.organism.level;

    final statusBox = Container(
      constraints: BoxConstraints(maxWidth: isNarrow ? 160 : 200),
      padding: EdgeInsets.all(isNarrow ? 6 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBiomeThemeColor(), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
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
              '${base.name} LV.$displayLevel',
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
                  ItemIcon(
                    itemName: organism.organism.equippedTalisman!.name,
                    size: 14,
                  ),
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
          if (!widget.isArenaBattle) ...[
            const SizedBox(height: 6),
            _buildXPBar(organism.organism),
          ],
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final inAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                );
                final outAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInBack,
                );

                if (child.key == ValueKey(organism.organism.id)) {
                  // Switch In
                  return ScaleTransition(
                    scale: inAnimation,
                    child: FadeTransition(opacity: inAnimation, child: child),
                  );
                } else {
                  // Switch Out
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(outAnimation),
                    child: FadeTransition(opacity: outAnimation, child: child),
                  );
                }
              },
              child: _BattleSprite(
                key: ValueKey(organism.organism.id),
                organism: organism,
                size: spriteSize,
                onLongPress: () =>
                    _showOrganismInfo(context, organism, isPlayer: true),
                mirror: true,
                biomeName: widget.biomeName,
                hazards: hazards,
              ),
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
                _getBiomePrimaryColor().withValues(alpha: 0.8),
                _getBiomeSecondaryColor(),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Text(
            bo.displayName,
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
                      children: bo.displayCategory.toUpperCase().split(',').map(
                        (cat) {
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
                                  color: Colors.black.withValues(alpha: 0.3),
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
                        },
                      ).toList(),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 2,
                              offset: const Offset(1, 1),
                            ),
                          ],
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
                      isPlayer
                          ? bo.organism.nature.name.toUpperCase()
                          : 'UNKNOWN',
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
              if (!isPlayer)
                Padding(
                  padding: const EdgeInsets.only(left: 48.0, bottom: 4.0),
                  child: Text(
                    'EST. RANGE: ${((CapturedOrganism.calculateStat('speed', base.speed, 0, level: bo.organism.level)) * 0.9).round()} - ${((CapturedOrganism.calculateStat('speed', base.speed, 31, level: bo.organism.level)) * 1.1).round()}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 7,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
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
                        color: Colors.grey.withValues(alpha: 0.3),
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
                      const SizedBox(width: 8),
                      const Text(
                        'HELD ITEM: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      ItemIcon(
                        itemName: bo.organism.equippedTalisman!.name,
                        size: 16,
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
              if (!isPlayer) ...[
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
                if ((battleManager
                        .battleStats[bo.organism.id]
                        ?.revealedMoves
                        .isEmpty ??
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
                  ...battleManager.battleStats[bo.organism.id]!.revealedMoves
                      .map((moveName) {
                        final move = Move.findByName(moveName);
                        final curStam = bo.organism.moveStamina[moveName] ?? 0;
                        final maxStam = move?.stamina ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                moveName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontFamily: 'PressStart2P',
                                ),
                              ),
                              Text(
                                '$curStam/$maxStam',
                                style: TextStyle(
                                  color: curStam == 0
                                      ? Colors.red
                                      : (curStam < maxStam / 2
                                            ? Colors.orange
                                            : Colors.white70),
                                  fontSize: 8,
                                  fontFamily: 'PressStart2P',
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
              ] else ...[
                // Player Moves
                const SizedBox(height: 10),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
                Text(
                  'MOVES',
                  style: TextStyle(
                    color: _getBiomeThemeColor(),
                    fontSize: 9,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                const SizedBox(height: 6),
                ...bo.organism.selectedMoveNames.map((moveName) {
                  final move = Move.findByName(moveName);
                  final displayType = move != null
                      ? (bm?.getDisplayType(bo, move) ?? move.type)
                      : ElementalType.basic;
                  final curStam = bo.organism.moveStamina[moveName] ?? 0;
                  final maxStam = move?.stamina ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              moveName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontFamily: 'PressStart2P',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(displayType),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                displayType.name.toUpperCase().substring(0, 3),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 6,
                                  fontFamily: 'PressStart2P',
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
                            fontSize: 8,
                            fontFamily: 'PressStart2P',
                          ),
                        ),
                      ],
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
              if (!isPlayer && !bo.isAbilityRevealed)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '???',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'PressStart2P',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
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
            onPressed: () {
              Navigator.pop(ctx);
              AnidexDetailsSheet.show(
                context,
                bo.organism.baseOrganism,
                capturedOverride: bo.organism,
                showScaledStats: true,
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: const BorderSide(color: Colors.orange),
            ),
            child: const Text(
              'ANIDEX',
              style: TextStyle(
                color: Colors.orange,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              TypeMatchupSheet.show(
                context,
                bo.organism.baseOrganism.elementalTypes,
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: const BorderSide(color: AppColors.highlightColor),
            ),
            child: const Text(
              'MATCHUP',
              style: TextStyle(
                color: AppColors.highlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: _getBiomePrimaryColor().withValues(alpha: 0.3),
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
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getBiomeThemeColor(), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
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
              bm.getDisplayType(bm.player, move).name.toUpperCase(),
              _getTypeColor(bm.getDisplayType(bm.player, move)),
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
    final bool isTurnLocked =
        battleManager.player.mustRecharge ||
        battleManager.player.chargingMove != null ||
        battleManager.player.semiInvulnerable != null ||
        battleManager.player.isInvulnerable ||
        battleManager.isProcessing;

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
            color: Colors.black.withValues(alpha: 0.4),
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
          if (battleManager.player.mustRecharge ||
              battleManager.player.chargingMove != null ||
              battleManager.player.semiInvulnerable != null)
            SizedBox(
              width: double.infinity,
              height: isNarrow ? 60 : 80,
              child: ElevatedButton(
                onPressed: () {
                  final move =
                      battleManager.player.chargingMove ??
                      battleManager.playerMoves[0];
                  battleManager.processPlayerAction(move);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getBiomeThemeColor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  elevation: 4,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      battleManager.player.mustRecharge
                          ? 'RECHARGE'
                          : 'CONTINUE',
                      style: TextStyle(
                        fontSize: isNarrow ? 12 : 16,
                        fontFamily: 'PressStart2P',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (battleManager.player.chargingMove != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        battleManager.player.chargingMove!.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: isNarrow ? 8 : 10,
                          fontFamily: 'PressStart2P',
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
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
              children:
                  (battleManager.getValidMoves(battleManager.player).isEmpty
                          ? [Move.findOrCreate('Struggle')]
                          : battleManager.playerMoves)
                      .map((move) {
                        final displayType = battleManager.getDisplayType(
                          battleManager.player,
                          move,
                        );
                        final typeColor = _getTypeColor(displayType);
                        final effectiveness = _calculateMoveEffectiveness(
                          move,
                          battleManager.opponent,
                        );
                        final effectivenessText = _getEffectivenessText(
                          effectiveness,
                        );
                        final categoryText = move.category
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase();

                        final validMoves = battleManager.getValidMoves(
                          battleManager.player,
                        );
                        final isValid = validMoves.any(
                          (m) => m.name == move.name,
                        );

                        final isSuggested =
                            battleManager.suggestedMoveName == move.name;
                        return ElevatedButton(
                          onPressed: !isValid
                              ? null
                              : () => battleManager.processPlayerAction(move),
                          onLongPress: () => _showMoveDetails(
                            context,
                            move,
                            _getBiomeThemeColor(),
                            battleManager,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !isValid
                                ? Colors.grey[700]
                                : typeColor,
                            foregroundColor: !isValid
                                ? Colors.white24
                                : Colors.white,
                            padding: const EdgeInsets.all(4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: !isValid
                                    ? Colors.grey.withValues(alpha: 0.3)
                                    : (isSuggested
                                          ? Colors.yellowAccent
                                          : Colors.white.withValues(
                                              alpha: 0.5,
                                            )),
                                width: isSuggested ? 3 : 2,
                              ),
                            ),
                            elevation: isSuggested ? 12 : (!isValid ? 0 : 2),
                            shadowColor: isSuggested
                                ? Colors.yellowAccent
                                : Colors.black,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Type Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        displayType.name
                                            .toUpperCase()
                                            .substring(0, 3),
                                        style: const TextStyle(
                                          fontSize: 6,
                                          fontFamily: 'PressStart2P',
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
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
                                        categoryText.substring(
                                          0,
                                          4,
                                        ), // PHYS, SPEC, STAT
                                        style: const TextStyle(
                                          fontSize: 6, // Very small
                                          fontFamily: 'PressStart2P',
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    // Stamina
                                    Text(
                                      move.isTitanizeMove
                                          ? '99/99'
                                          : '${battleManager.playerOrganism.moveStamina[move.name] ?? 0}/${move.stamina}',
                                      style: TextStyle(
                                        fontSize: isNarrow ? 7 : 8,
                                        fontFamily: 'PressStart2P',
                                        color:
                                            (move.isTitanizeMove ||
                                                (battleManager
                                                            .playerOrganism
                                                            .moveStamina[move
                                                            .name] ??
                                                        0) >
                                                    0)
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
                      })
                      .toList(),
            ),
          // ============================================================
          // GIMMICK BUTTONS: Titanize and Prismorph
          // ============================================================
          Builder(
            builder: (context) {
              final bm = battleManager;
              final p = bm.player;
              final canTitanize =
                  !p.hasTitanizedThisBattle &&
                  !p.hasPrismorphedThisBattle &&
                  !bm.isProcessing;
              final canPrismorph =
                  !bm.playerPrismorphUsed &&
                  !p.hasPrismorphedThisBattle &&
                  p.organism.teraType != null &&
                  !bm.isProcessing;
              // If gimmick is done AND not currently active, hide entirely
              if (!canTitanize &&
                  !p.isTitanized &&
                  !canPrismorph &&
                  !p.isPrismorphed) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    if (canTitanize || p.isTitanized)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Text('⚡', style: TextStyle(fontSize: 16)),
                          label: Text(
                            p.isTitanized
                                ? 'TITANIZED (${p.titanizeTurnsLeft})'
                                : 'TITANIZE',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: isNarrow ? 7 : 9,
                            ),
                          ),
                          onPressed: canTitanize
                              ? () => bm.activateTitanize(isPlayer: true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.isTitanized
                                ? const Color(0xFFCC0000)
                                : const Color(0xFF880000),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(
                              0xFFCC0000,
                            ).withValues(alpha: 0.5),
                            disabledForegroundColor: Colors.white54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: p.isTitanized
                                    ? Colors.redAccent
                                    : Colors.red.withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if ((canTitanize || p.isTitanized) &&
                        (canPrismorph || p.isPrismorphed))
                      const SizedBox(width: 4),
                    if (canPrismorph || p.isPrismorphed)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Text(
                            '💎',
                            style: TextStyle(fontSize: 16),
                          ),
                          label: Text(
                            p.isPrismorphed
                                ? 'PRISMORPH [${p.organism.teraType?.name ?? '?'}]'
                                : 'PRISMORPH',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: isNarrow ? 7 : 9,
                            ),
                          ),
                          onPressed: canPrismorph
                              ? () => bm.activatePrismorph(isPlayer: true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.isPrismorphed
                                ? const Color(0xFF7B00D4)
                                : const Color(0xFF4A0080),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(
                              0xFF7B00D4,
                            ).withValues(alpha: 0.5),
                            disabledForegroundColor: Colors.white54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: p.isPrismorphed
                                    ? Colors.purpleAccent
                                    : Colors.purple.withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (!battleManager.isArenaBattle) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isTurnLocked
                        ? null
                        : () => _showNetMenu(context, battleManager, userState),
                    icon: Icon(Icons.grid_on, size: isNarrow ? 14 : 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Net (${_getTotalNetCount(userState)})',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTurnLocked
                          ? Colors.grey[700]
                          : Colors.blue.shade700,
                      foregroundColor: isTurnLocked
                          ? Colors.white54
                          : Colors.white,
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
                    onPressed: isTurnLocked
                        ? null
                        : () => _showReleaseDialog(
                            context,
                            battleManager,
                            userState,
                          ),
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
                      backgroundColor: isTurnLocked
                          ? Colors.grey[700]
                          : Colors.orange.shade800,
                      foregroundColor: isTurnLocked
                          ? Colors.white54
                          : Colors.white,
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
                  onPressed: isTurnLocked
                      ? null
                      : () => _showSwitchDialog(context, battleManager),
                  icon: Icon(Icons.swap_horiz, size: isNarrow ? 14 : 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const Text(
                      'Switch',
                      style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTurnLocked
                        ? Colors.grey[700]
                        : Colors.green.shade700,
                    foregroundColor: isTurnLocked
                        ? Colors.white54
                        : Colors.white,
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
                  onPressed: isTurnLocked
                      ? null
                      : (widget.isArenaBattle || widget.isRogueMode)
                      ? () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1A1A2E),
                              title: const Text(
                                'FORFEIT?',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                              content: const Text(
                                'Give up and take a loss?',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  color: Colors.white70,
                                  fontSize: 9,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 8,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'FORFEIT',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 8,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await battleManager.forfeit();
                          }
                        }
                      : battleManager.attemptRun,
                  icon: Icon(
                    (widget.isArenaBattle || widget.isRogueMode)
                        ? Icons.flag
                        : Icons.directions_run,
                    size: isNarrow ? 14 : 18,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      (widget.isArenaBattle || widget.isRogueMode)
                          ? 'Forfeit'
                          : 'Run',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTurnLocked
                        ? Colors.grey[700]
                        : Colors.red.shade700,
                    foregroundColor: isTurnLocked
                        ? Colors.white54
                        : Colors.white,
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
      try {
        if (!mounted) {
          _isHandlingBattleEnd = false;
          return;
        }

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
            // Award XP on capture
            await _onOpponentFainted(
              battleManager.player,
              battleManager.opponent,
            );
          }
        }

        // Handle death mechanic for non-Arena, non-Rogue battles
        if (!widget.isArenaBattle && !widget.isRogueMode) {
          final playerTeam = List<CapturedOrganism>.from(
            battleManager.playerTeam,
          );
          for (final org in playerTeam) {
            if (org.currentHealth <= 0) {
              await userState.removeCapturedOrganism(org);
            }
          }
        }

        // Rogue-like specific progression
        if (widget.isRogueMode) {
          if (battleManager.result == BattleResult.win ||
              battleManager.result == BattleResult.capture) {
            // Perma-death: Remove any fainted animals from the team
            final currentTeam =
                userState.currentUser?.rogueLikeState.team ?? [];
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
          }
        }

        // Arena battle prize money (not for rogue mode usually, or different rewards)
        Map<String, dynamic> xpResults =
            _cumulativeXPResults; // Use cumulative results
        if (!widget.isRogueMode) {
          // Fully heal team after battle in exploration/arena
          await userState.fullyHealTeam();

          if (battleManager.result == BattleResult.win ||
              battleManager.result == BattleResult.capture) {
            // XP is now awarded via onOpponentFainted callback

            if (widget.isArenaBattle) {
              moneyEarned = 1000;
              await userState.addMoney(moneyEarned);
            } else {
              // Wild battle prize money
              moneyEarned = _calculateWildMoneyReward(
                battleManager.opponent.organism.baseOrganism,
              );
            }

            // Amulet Coin
            bool hasAmuletCoin = battleManager.playerTeam.any(
              (org) =>
                  org.equippedTalisman != null &&
                  org.equippedTalisman!.name == 'Amulet Coin',
            );
            if (hasAmuletCoin) {
              moneyEarned *= 2;
            }

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

        // Record match results for winrate system (for all decisive outcomes)
        final decisiveResult = battleManager.result;
        if (decisiveResult == BattleResult.win ||
            decisiveResult == BattleResult.capture ||
            decisiveResult == BattleResult.loss) {
          final playerSpecies = battleManager.playerTeam
              .map((o) => o.baseOrganism.name)
              .toList();
          final opponentSpecies = widget.opponentFullTeam != null
              ? widget.opponentFullTeam!
                    .map((o) => o.baseOrganism.name)
                    .toList()
              : [battleManager.opponent.organism.baseOrganism.name];
          final playerWon = decisiveResult != BattleResult.loss;
          unawaited(
            userState.recordMatchResults(
              playerSpecies: playerSpecies,
              opponentSpecies: opponentSpecies,
              playerWon: playerWon,
            ),
          );
        }

        // Show result dialog
        if (_pendingRogueCapture != null &&
            battleManager.result != BattleResult.loss) {
          _showCaptureReplaceDialog(context, _pendingRogueCapture!, userState);
        } else {
          _showBattleResultDialog(
            context,
            battleManager,
            moneyEarned,
            lootName,
            userState,
            xpResults: xpResults,
          );
        }
      } catch (e) {
        debugPrint('Error during battle end handling: $e');
        // Safety fallback to ensure the UI doesn't stay stuck
        if (mounted) {
          _showBattleResultDialog(context, battleManager, 0, null, userState);
        }
      } finally {
        _isHandlingBattleEnd = false;
      }
    });
  }

  void _showBattleResultDialog(
    BuildContext context,
    BattleManager battleManager,
    int moneyEarned,
    String? lootName,
    UserState userState, {
    Map<String, dynamic> xpResults = const {},
  }) {
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
        xpResults: xpResults,
        isRogueMode: widget.isRogueMode,
        rogueFloor: userState.currentUser?.rogueLikeState.floor,
        onConfirm: () async {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          Navigator.of(ctx).pop();

          if (widget.isRogueMode &&
              (battleManager.result == BattleResult.loss ||
                  battleManager.result == BattleResult.fled)) {
            // Roguelike defeat/forfeit: clean up and go to Arena menu

            // FIX: Use a single pushAndRemoveUntil to reset the stack stably BEFORE ending the run.
            // Chaining multiple pushes on a cleaning context causes soft-locks (black screens).
            // By navigating first, the underlying RogueHubScreen isn't suddenly left without a Rogue state.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => const MainScreen()),
              (route) => false,
            );

            await userState.endRogueRun();
          } else if ((battleManager.result == BattleResult.win ||
                  battleManager.result == BattleResult.capture) &&
              widget.isRogueMode) {
            final rogue = userState.currentUser!.rogueLikeState;

            // Navigator logic:
            if (rogue.encounterIndex >= 5) {
              // Boss/Floor completed -> Choose next biome
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (ctx) => const BiomeSelectScreen()),
              );
            } else {
              // Normal battle completed -> Return to Rogue Hub
              Navigator.of(context).pop();
            }
          } else {
            // Normal exploration or other modes
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

  int _getTotalNetCount(UserState userState) {
    final inv = widget.isRogueMode
        ? (userState.currentUser?.rogueLikeState.inventory ?? {})
        : (userState.currentUser?.inventory ?? {});
    return (inv['capture_net'] ?? 0) +
        (inv['great_net'] ?? 0) +
        (inv['ultra_net'] ?? 0);
  }

  void _showNetMenu(
    BuildContext context,
    BattleManager bm,
    UserState userState,
  ) {
    final inv = widget.isRogueMode
        ? (userState.currentUser?.rogueLikeState.inventory ?? {})
        : (userState.currentUser?.inventory ?? {});
    final nets = [
      {
        'id': 'capture_net',
        'name': 'Capture Net',
        'count': inv['capture_net'] ?? 0,
        'color': Colors.blue,
      },
      {
        'id': 'great_net',
        'name': 'Great Net',
        'count': inv['great_net'] ?? 0,
        'color': Colors.purple,
      },
      {
        'id': 'ultra_net',
        'name': 'Ultra Net',
        'count': inv['ultra_net'] ?? 0,
        'color': Colors.orange,
      },
    ].where((n) => (n['count'] as int) > 0).toList();

    if (nets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no nets! Buy some at the shop.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getBiomeSecondaryColor().withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: _getBiomeThemeColor(), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SELECT CAPTURE ITEM',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: _getBiomeThemeColor(),
              ),
            ),
            const SizedBox(height: 16),
            ...nets
                .map(
                  (net) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (widget.isRogueMode) {
                          userState.addRogueLoot(net['id'] as String, -1);
                        } else {
                          userState.addLoot(net['id'] as String, -1);
                        }
                        bm.attemptCapture(netId: net['id'] as String);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: net['color'] as Color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            net['name'] as String,
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'x${net['count']}',
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ],
        ),
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
        color: Colors.cyan.shade900.withValues(alpha: 0.5),
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
        hazards: const [],
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
  final Map<String, dynamic> xpResults;

  final int? rogueFloor;
  final bool isRogueMode;

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
    this.xpResults = const {},
    this.rogueFloor,
    required this.isRogueMode,
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
        color: Colors.black.withValues(alpha: 0.3),
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

  Widget _buildSummaryCard(BuildContext context, CapturedOrganism org) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _buildSmallSprite(org),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  org.baseOrganism.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'LV.${org.level}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSprite(CapturedOrganism org) {
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ChangeNotifierProvider.value(
        value: battleManager,
        child: _BattleSprite(
          organism: BattleOrganism(org, isRogueMode: true),
          size: 32,
          biomeName: 'Forest',
          hazards: const [],
        ),
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
              child: ChangeNotifierProvider.value(
                value: battleManager,
                child: _BattleSprite(
                  organism: BattleOrganism(mvp!, isRogueMode: true),
                  size: 80,
                  biomeName: 'forest',
                  hazards: const [],
                ),
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
        description = battleManager.isArenaBattle
            ? 'Your $playerName was defeated in battle.'
            : 'Your $playerName was defeated in battle...';
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
      content: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
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
              if (moneyEarned > 0 ||
                  lootName != null ||
                  xpResults.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      if (xpResults.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.stars,
                              color: Colors.blueAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+${xpResults['gainedAccountXP']} ACCOUNT XP',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontFamily: 'PressStart2P',
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        if (xpResults['accountLeveledUp'] == true)
                          const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              'ACCOUNT LEVEL UP!',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontFamily: 'PressStart2P',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'TEAM PROGRESS',
                          style: TextStyle(
                            color: Colors.greenAccent.withValues(alpha: 0.8),
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...battleManager.playerTeam.map((org) {
                          final gainedXP =
                              (xpResults['gainedAnimalXP'] as int? ?? 0);
                          final id = org.id;
                          final killerId = xpResults['killerId'] as String?;

                          // Calculate this specific animal's share
                          // Note: In awardBattleXP, killer gets full, others half.
                          int animalShare = (id == killerId)
                              ? gainedXP
                              : (gainedXP / 2).floor();

                          return _XPResultRow(
                            organism: org,
                            gainedXP: animalShare,
                            didLevelUp:
                                (xpResults['animalLeveledUp']
                                    as Map<String, bool>?)?[id] ??
                                false,
                          );
                        }),
                      ],
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
              if (isRogueMode && result == BattleResult.loss) ...[
                const Divider(color: Colors.white24, height: 24),
                const Text(
                  'FINAL PARTY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 12),
                ...battleManager.playerTeam.map(
                  (org) => _buildSummaryCard(context, org),
                ),
                const SizedBox(height: 16),
                Text(
                  'FLOOR REACHED: $rogueFloor',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          children: [
            if (isRogueMode && result == BattleResult.loss)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showStats(context),
                  icon: const Icon(Icons.analytics, size: 16),
                  label: const Text(
                    'BATTLE STATS',
                    style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
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
                side: BorderSide(color: titleColor.withValues(alpha: 0.5)),
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

class _XPResultRow extends StatefulWidget {
  final CapturedOrganism organism;
  final int gainedXP;
  final bool didLevelUp;

  const _XPResultRow({
    required this.organism,
    required this.gainedXP,
    required this.didLevelUp,
  });

  @override
  State<_XPResultRow> createState() => _XPResultRowState();
}

class _XPResultRowState extends State<_XPResultRow>
    with TickerProviderStateMixin {
  late double _startRatio;
  late double _endRatio;
  late int _startLevel;
  late int _endLevel;
  late AnimationController _xpController;
  late Animation<double> _xpAnimation;
  late AnimationController _levelUpController;

  @override
  void initState() {
    super.initState();
    _startLevel = widget.didLevelUp
        ? widget.organism.level - 1
        : widget.organism.level;
    _endLevel = widget.organism.level;

    // Estimate start ratio
    // Current XP = level^3
    final int currentLevelXPThreshold = _startLevel * _startLevel * _startLevel;
    final int nextLevelXPThreshold =
        (_startLevel + 1) * (_startLevel + 1) * (_startLevel + 1);
    final int xpInRange = math.max(
      0,
      widget.organism.xp - widget.gainedXP - currentLevelXPThreshold,
    );
    final int neededForLevel = nextLevelXPThreshold - currentLevelXPThreshold;

    _startRatio = (xpInRange / neededForLevel).clamp(0.0, 1.0);
    _endRatio = widget.didLevelUp ? 1.0 : widget.organism.xpRatio;

    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _xpAnimation = Tween<double>(begin: _startRatio, end: _endRatio).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeOutCubic),
    );

    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _xpController.forward().then((_) {
      if (widget.didLevelUp) {
        _levelUpController.forward();
      }
    });
  }

  @override
  void dispose() {
    _xpController.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.organism.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                ),
              ),
              Row(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                      CurvedAnimation(
                        parent: _levelUpController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Text(
                      'LV $_endLevel',
                      style: TextStyle(
                        color: widget.didLevelUp
                            ? Colors.yellowAccent
                            : Colors.white70,
                        fontFamily: 'PressStart2P',
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              // Background
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Progress Bar
              AnimatedBuilder(
                animation: _xpAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    widthFactor: _xpAnimation.value,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.blueAccent.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (widget.didLevelUp)
            FadeTransition(
              opacity: _levelUpController,
              child: const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'LEVEL UP!',
                  style: TextStyle(
                    color: Colors.yellowAccent,
                    fontFamily: 'PressStart2P',
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BattleSprite extends StatefulWidget {
  final BattleOrganism organism;
  final double size;
  final VoidCallback? onLongPress;
  final bool mirror;
  final String biomeName;
  final List<String> hazards;
  final bool hideAnimal; // Added

  const _BattleSprite({
    super.key,
    required this.organism,
    required this.size,
    this.onLongPress,
    this.mirror = false,
    required this.biomeName,
    required this.hazards,
    this.hideAnimal = false, // Added
  });

  @override
  State<_BattleSprite> createState() => _BattleSpriteState();
}

class _BattleSpriteState extends State<_BattleSprite>
    with TickerProviderStateMixin {
  String? _imageSourceType;
  late String _imagePath;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

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

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BattleSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.organism.displayBaseName != oldWidget.organism.displayBaseName ||
        widget.organism.displaySprite != oldWidget.organism.displaySprite) {
      _determineImageSource();
      _entryController.reset();
      _entryController.forward();
    }
  }

  String _getLocalPath() {
    final fileName = widget.organism.displayBaseName
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
          _imagePath = widget.organism.displaySprite;
        });
      }
    }
  }

  Widget _buildHazards() {
    if (widget.hazards.isEmpty) return const SizedBox.shrink();

    // Group hazards by type
    final hazardCounts = <String, int>{};
    for (final h in widget.hazards) {
      hazardCounts[h] = (hazardCounts[h] ?? 0) + 1;
    }

    final children = <Widget>[];

    for (final entry in hazardCounts.entries) {
      final hazard = entry.key;
      final count = entry.value;

      String assetPath = '';
      if (hazard == 'stealth_rock')
        assetPath = 'assets/stealth_rock.png';
      else if (hazard == 'spikes')
        assetPath = 'assets/spikes.png';
      else if (hazard == 'toxic_spikes')
        assetPath = 'assets/toxic_spikes.png';
      else if (hazard == 'sticky_web')
        assetPath = 'assets/sticky_web.png';

      if (assetPath.isEmpty) continue;

      // Render stack of sprites for stackable hazards
      for (int i = 0; i < count; i++) {
        // Offset each layer slightly to the top-right
        final double offset = i * 4.0;
        children.add(
          Positioned(
            top: -offset,
            left: offset,
            width: widget.size,
            height: widget.size,
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
        );
      }

      // Add a count badge if count > 1
      if (count > 1) {
        children.add(
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Text(
                'x$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily:
                      'PressStart2P', // Use game font if possible or monospace
                ),
              ),
            ),
          ),
        );
      }
    }

    return Stack(clipBehavior: Clip.none, children: children);
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
    final spriteOutlineColor = Colors.black.withValues(alpha: 0.8);
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
    final isSubstituteActive = bo.substituteHealth > 0;

    // Primary status overlay (first non-none status)
    final overlayStatus = bo.statusEffects.isNotEmpty
        ? bo.statusEffects.firstWhere(
            (se) => se.type != StatusEffectType.none,
            orElse: () => const StatusEffect(type: StatusEffectType.none),
          )
        : const StatusEffect(type: StatusEffectType.none);
    final overlayPath = overlayStatus.overlayAssetPath;

    // Prepare grayscaled or normal sprite
    Widget processedSprite = enhancedImage;
    if (isSubstituteActive) {
      processedSprite = ColorFiltered(
        // Grayscale matrix
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
        child: enhancedImage,
      );
    }

    // Gimmick Visuals
    // Gimmick Visuals (Shaders/Tints only, scaling handled in group)
    if (bo.isTitanized) {
      processedSprite = Stack(
        alignment: Alignment.center,
        children: [
          processedSprite,
          // Red shimmer overlay
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x44FF1111), // Translucent red
                BlendMode.srcATop,
              ),
              child: processedSprite,
            ),
          ),
        ],
      );
    }
    // Prismorph: rainbow/crystal shimmer overlay
    else if (bo.isPrismorphed) {
      final baseSprite = processedSprite;
      processedSprite = Stack(
        alignment: Alignment.center,
        children: [
          baseSprite,
          // Prismatic shimmer (animated gradient overlay)
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
                      stops: [0.0, _pulseAnimation.value.clamp(0.0, 1.0), 1.0],
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

    // Sprite and outline layers — hidden or faded based on state
    final Widget spriteLayer = (isInvulnerable || widget.hideAnimal)
        ? SizedBox(width: size, height: size)
        : (hasStealth
              ? Opacity(opacity: 0.35, child: processedSprite)
              : processedSprite);

    final Widget outlineLayer = (isInvulnerable || widget.hideAnimal)
        ? const SizedBox.shrink()
        : (hasStealth
              ? Opacity(opacity: 0.35, child: outlineImage)
              : outlineImage);

    final isTitanized = bo.isTitanized;
    final titanScale = isTitanized ? 2.0 : 1.0;
    final titanYOffset = isTitanized ? -size * 0.25 : 0.0;

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
                        border: Border.all(
                          color: platformOutlineColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            platformColor,
                            platformColor.withValues(alpha: 0.92),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Outline and Sprite Group (Scaled Together)
            AnimatedBuilder(
              animation: Listenable.merge([
                _bounceController,
                _entryController,
              ]),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value + titanYOffset),
                  child: Transform.scale(
                    scale: _entryAnimation.value * titanScale,
                    child: Stack(
                      children: [
                        // Outline Layer
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

                        // Sprite Layer — hidden when invulnerable, faded when stealthed
                        spriteLayer,
                      ],
                    ),
                  ),
                );
              },
            ),

            // Status overlay image — shown on top of sprite when statused
            if (!isInvulnerable && overlayPath != null)
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, titanYOffset),
                  child: Transform.scale(
                    scale: titanScale,
                    child: Image.asset(
                      overlayPath,
                      fit: BoxFit.contain,
                      opacity: const AlwaysStoppedAnimation(0.85),
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

            // Hazards on TOP
            _buildHazards(),

            // Protection Screens Overlay
            _ScreenShieldOverlay(organism: widget.organism, size: size),
          ],
        ),
      ),
    );
  }
}

class _ScreenShieldOverlay extends StatefulWidget {
  final BattleOrganism organism;
  final double size;
  const _ScreenShieldOverlay({required this.organism, required this.size});

  @override
  State<_ScreenShieldOverlay> createState() => _ScreenShieldOverlayState();
}

class _ScreenShieldOverlayState extends State<_ScreenShieldOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bm = Provider.of<BattleManager>(context);
    final isPlayer = widget.organism.isPlayer;

    final hasReflect = isPlayer
        ? bm.playerReflectTurns > 0
        : bm.opponentReflectTurns > 0;
    final hasLightScreen = isPlayer
        ? bm.playerLightScreenTurns > 0
        : bm.opponentLightScreenTurns > 0;
    final hasAuroraVeil = isPlayer
        ? bm.playerAuroraVeilTurns > 0
        : bm.opponentAuroraVeilTurns > 0;

    if (!hasReflect && !hasLightScreen && !hasAuroraVeil)
      return const SizedBox.shrink();

    final List<Widget> shields = [];

    if (hasAuroraVeil) {
      shields.add(
        CustomPaint(
          painter: _ShieldPainter(
            color: Colors.cyanAccent.withValues(alpha: 0.75),
            progress: _controller.value,
            scale: 1.1,
          ),
        ),
      );
    }
    if (hasReflect) {
      shields.add(
        CustomPaint(
          painter: _ShieldPainter(
            color: Colors.orangeAccent.withValues(alpha: 0.75),
            progress: _controller.value,
            offset: hasAuroraVeil ? 2.0 : 0.0,
          ),
        ),
      );
    }
    if (hasLightScreen) {
      shields.add(
        CustomPaint(
          painter: _ShieldPainter(
            color: Colors.yellowAccent.withValues(alpha: 0.75),
            progress: _controller.value,
            scale: hasReflect || hasAuroraVeil ? 0.9 : 1.0,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned.fill(child: Stack(children: shields));
      },
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  final double progress;

  final double scale;
  final double offset;

  _ShieldPainter({
    required this.color,
    required this.progress,
    this.scale = 1.0,
    this.offset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(
        alpha: color.a * (0.6 + 0.4 * math.sin(progress * 2 * math.pi)),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    final centerX = size.width / 2 + offset;
    final centerY = size.height / 2 + offset;
    final radius = size.width * 0.48 * scale;

    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3;
      double x = centerX + radius * math.cos(angle);
      double y = centerY + radius * math.sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();

    canvas.drawPath(path, paint);

    final fillPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) => true;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              border: Border.all(color: widget.themeColor, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
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
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.notification.abilityName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.themeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PressStart2P',
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndicatorData {
  final int id;
  final String text;
  final Color color;
  final bool isPlayer;

  _IndicatorData({
    required this.id,
    required this.text,
    required this.color,
    required this.isPlayer,
  });
}

class _FloatingIndicatorWidget extends StatefulWidget {
  final _IndicatorData data;
  final LayerLink link;

  const _FloatingIndicatorWidget({
    super.key,
    required this.data,
    required this.link,
  });

  @override
  State<_FloatingIndicatorWidget> createState() =>
      _FloatingIndicatorWidgetState();
}

class _FloatingIndicatorWidgetState extends State<_FloatingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _positionAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -60), // Float upwards
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
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
              offset: _positionAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.data.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.data.color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'PressStart2P',
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrickRoomOverlay extends StatefulWidget {
  const _TrickRoomOverlay();

  @override
  State<_TrickRoomOverlay> createState() => _TrickRoomOverlayState();
}

class _TrickRoomOverlayState extends State<_TrickRoomOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
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
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.deepPurple.withValues(
                    alpha: 0.2 + _controller.value * 0.2,
                  ),
                  Colors.deepPurple.withValues(
                    alpha: 0.5 + _controller.value * 0.3,
                  ),
                ],
                center: Alignment.center,
                radius: 1.2,
              ),
            ),
            child: CustomPaint(
              painter: _TrickRoomPainter(progress: _controller.value),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _TrickRoomPainter extends CustomPainter {
  final double progress;

  _TrickRoomPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.2 + progress * 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.deepPurple.withValues(alpha: 0.1),
    );

    final step = 50.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrickRoomPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================
// GBA-Style Party Screen Dialog
// ============================================================

class _PartyScreenDialog extends StatelessWidget {
  final BattleManager bm;
  final String title;
  final bool isForced;
  final bool isLeadSelection;
  final Color themeColor;
  final Color primaryColor;
  final VoidCallback onDismiss;
  final void Function(int index) onSelect;
  final void Function(BattleOrganism bo) onShowSummary;

  const _PartyScreenDialog({
    required this.bm,
    required this.title,
    required this.isForced,
    required this.isLeadSelection,
    required this.themeColor,
    required this.primaryColor,
    required this.onDismiss,
    required this.onSelect,
    required this.onShowSummary,
  });

  @override
  Widget build(BuildContext context) {
    final team = bm.playerTeam;
    final currentIndex = bm.currentPlayerIndex;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: themeColor.withValues(alpha: 0.8), width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: themeColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Party grid — 2 columns
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: team.length,
            itemBuilder: (context, index) {
              final animal = team[index];
              final bo = BattleOrganism(animal, isRogueMode: bm.isRogueMode);
              final isCurrent = index == currentIndex && !isLeadSelection;
              final isFainted = bo.health <= 0;
              final hpRatio = (bo.health / bo.maxHealth).clamp(0.0, 1.0);
              final hpColor = hpRatio > 0.5
                  ? const Color(0xFF4CAF50)
                  : hpRatio > 0.2
                  ? Colors.orange
                  : Colors.red;
              final canSelect = !isFainted && (!isCurrent || isLeadSelection);

              String? statusLabel;
              Color statusColor = Colors.red;
              if (isFainted) {
                statusLabel = 'FNT';
                statusColor = const Color(0xFFB00020);
              } else if (animal.statusEffects.isNotEmpty) {
                final se = animal.statusEffects.first;
                statusLabel = se.name.toUpperCase().substring(
                  0,
                  math.min(3, se.name.length),
                );
                statusColor = se.color;
              }

              return GestureDetector(
                onTap: () {
                  _showSelectionMenu(context, bo, index, canSelect);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isFainted
                        ? const Color(0xFF2A2A2A)
                        : isCurrent
                        ? primaryColor.withValues(alpha: 0.35)
                        : const Color(0xFF2C4A2C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrent
                          ? themeColor
                          : canSelect
                          ? Colors.white24
                          : Colors.white12,
                      width: isCurrent ? 2 : 1,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Opacity(
                    opacity: isFainted ? 0.55 : 1.0,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/sprites/${animal.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", '_')}.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.pets,
                              color: Colors.white54,
                              size: 36,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        animal.name,
                                        style: TextStyle(
                                          fontFamily: 'PressStart2P',
                                          fontSize: 7.5,
                                          color: isFainted
                                              ? Colors.white38
                                              : Colors.white,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (statusLabel != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: const TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 6,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (animal.teraType != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'PRISM:',
                                          style: TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 6,
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
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          child: Text(
                                            animal.teraType!.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontFamily: 'PressStart2P',
                                              fontSize: 5,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: hpRatio,
                                    backgroundColor: Colors.grey[800],
                                    color: hpColor,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${bo.health}/ ${bo.maxHealth}',
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 6.5,
                                    color: isFainted
                                        ? Colors.white30
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // Bottom prompt bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A0F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(Icons.catching_pokemon, color: themeColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLeadSelection ? 'Choose your lead!' : 'Choose a Pokémon.',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (!isForced)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDismiss();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      backgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showSelectionMenu(
    BuildContext context,
    BattleOrganism bo,
    int index,
    bool canSelect,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bo.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                label: 'SUMMARY',
                icon: Icons.info_outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  onShowSummary(bo);
                },
              ),
              const SizedBox(height: 8),
              _buildMenuButton(
                context,
                label: isLeadSelection ? 'CHOOSE LEAD' : 'SEND OUT',
                icon: Icons.flash_on,
                enabled: canSelect,
                onPressed: () {
                  Navigator.pop(ctx);
                  onSelect(index);
                },
              ),
              const SizedBox(height: 8),
              _buildMenuButton(
                context,
                label: 'CANCEL',
                icon: Icons.close,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 14, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C2C2C),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
// ----------------------------------------------------------------
// MOVE ANIMATION SYSTEM
// ----------------------------------------------------------------

/// Holds the data needed to render one move-attack animation overlay.
class _MoveAnimData {
  final int id;
  final Move move;
  final bool isPlayerAttacking;

  const _MoveAnimData({
    required this.id,
    required this.move,
    required this.isPlayerAttacking,
  });
}

/// Renders a move-specific visual effect overlaid on the battle screen.
/// Each (MoveCategory × ElementalType) pair has its own unique shape/motion.
class _MoveAnimationOverlay extends StatefulWidget {
  final _MoveAnimData data;
  final LayerLink playerLink;
  final LayerLink opponentLink;
  final Color Function(ElementalType) getTypeColor;

  const _MoveAnimationOverlay({
    super.key,
    required this.data,
    required this.playerLink,
    required this.opponentLink,
    required this.getTypeColor,
  });

  @override
  State<_MoveAnimationOverlay> createState() => _MoveAnimationOverlayState();
}

class _MoveAnimationOverlayState extends State<_MoveAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..forward();
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.data.move;
    final isPlayer = widget.data.isPlayerAttacking;
    // The ATTACKER link is used as the origin, target receives the hit
    final attackerLink = isPlayer ? widget.playerLink : widget.opponentLink;
    final targetLink = isPlayer ? widget.opponentLink : widget.playerLink;
    final color = widget.getTypeColor(move.type);

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return Stack(
          children: [
            // Attacker flash (brief glow at origin)
            CompositedTransformFollower(
              link: attackerLink,
              showWhenUnlinked: false,
              followerAnchor: Alignment.center,
              targetAnchor: Alignment.center,
              child: Opacity(
                opacity: (1.0 - _progress.value * 2).clamp(0.0, 1.0),
                child: _buildAttackerGlow(color, move.type, move.category),
              ),
            ),
            // Target hit effect
            CompositedTransformFollower(
              link: targetLink,
              showWhenUnlinked: false,
              followerAnchor: Alignment.center,
              targetAnchor: Alignment.center,
              child: _buildTargetEffect(
                color,
                move.type,
                move.category,
                _progress.value,
                isPlayer,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttackerGlow(Color color, ElementalType type, MoveCategory cat) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _GlowPainter(color: color, intensity: 0.8)),
    );
  }

  Widget _buildTargetEffect(
    Color color,
    ElementalType type,
    MoveCategory cat,
    double progress,
    bool isPlayer,
  ) {
    final size = 160.0;
    // Flip horizontally if the target is the opponent (so projectiles face the right direction)
    final flipX = !isPlayer; // effects point toward the target

    switch (cat) {
      case MoveCategory.physical:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _PhysicalHitPainter(
              type: type,
              color: color,
              progress: progress,
              flip: flipX,
            ),
          ),
        );
      case MoveCategory.special:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SpecialHitPainter(
              type: type,
              color: color,
              progress: progress,
              flip: flipX,
            ),
          ),
        );
      case MoveCategory.status:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _StatusEffectPainter(
              type: type,
              color: color,
              progress: progress,
            ),
          ),
        );
    }
  }
}

// ----------------------------------------------------------------
// Glow painter for attacker charge-up
// ----------------------------------------------------------------
class _GlowPainter extends CustomPainter {
  final Color color;
  final double intensity;
  _GlowPainter({required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: intensity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 50));
    canvas.drawCircle(center, 50, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.intensity != intensity;
}

// ----------------------------------------------------------------
// Physical Hit Painter — unique shape per elemental type
// ----------------------------------------------------------------
class _PhysicalHitPainter extends CustomPainter {
  final ElementalType type;
  final Color color;
  final double progress; // 0.0 → 1.0
  final bool flip;

  _PhysicalHitPainter({
    required this.type,
    required this.color,
    required this.progress,
    required this.flip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = progress;
    final fade = (1.0 - p).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      // Basic — plain X-slash slashes
      case ElementalType.basic:
        paint.color = color.withValues(alpha: fade);
        paint.strokeWidth = 6 * (1 - p * 0.5);
        paint.style = PaintingStyle.stroke;
        _drawSlash(canvas, cx, cy, 50 * p, paint);
        break;

      // Flying — feather-arc sweep
      case ElementalType.flying:
        paint.color = color.withValues(alpha: fade);
        final r = 55.0 * p;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          -pi / 4,
          pi * 1.2 * p,
          false,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
        // Feather tip circles
        for (int i = 0; i < 4; i++) {
          final angle = -pi / 4 + (pi * 1.2 * p) * i / 3;
          final dx = cx + cos(angle) * r;
          final dy = cy + sin(angle) * r;
          canvas.drawCircle(
            Offset(dx, dy),
            5 * fade,
            Paint()..color = color.withValues(alpha: fade * 0.8),
          );
        }
        break;

      // Aquatic — wave slash
      case ElementalType.aquatic:
        final path = Path();
        path.moveTo(cx - 50 * p, cy);
        for (int i = 0; i <= 30; i++) {
          final t = i / 30;
          final x = cx - 50 * p + t * 100 * p;
          final y = cy + sin(t * pi * 2) * 15 * fade;
          path.lineTo(x, y);
        }
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = color.withValues(alpha: fade),
        );
        break;

      // Earth — impact shockwave ring
      case ElementalType.earth:
        for (int i = 0; i < 3; i++) {
          final r = (30 + i * 12) * p;
          canvas.drawCircle(
            Offset(cx, cy),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.0 - i
              ..color = color.withValues(alpha: fade * (1.0 - i * 0.25)),
          );
        }
        // Ground crack lines
        paint.color = color.withValues(alpha: fade);
        paint.strokeWidth = 3;
        paint.style = PaintingStyle.stroke;
        for (int i = 0; i < 6; i++) {
          final angle = pi * 2 * i / 6 + p * 0.5;
          canvas.drawLine(
            Offset(cx, cy),
            Offset(cx + cos(angle) * 50 * p, cy + sin(angle) * 50 * p),
            paint,
          );
        }
        break;

      // Cryo — ice shard burst
      case ElementalType.cryo:
        for (int i = 0; i < 8; i++) {
          final angle = pi * 2 * i / 8;
          final len = 45 * p;
          final tip = Offset(cx + cos(angle) * len, cy + sin(angle) * len);
          final base1 = Offset(
            cx + cos(angle + 0.35) * 8,
            cy + sin(angle + 0.35) * 8,
          );
          final base2 = Offset(
            cx + cos(angle - 0.35) * 8,
            cy + sin(angle - 0.35) * 8,
          );
          final path = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(base1.dx, base1.dy)
            ..lineTo(base2.dx, base2.dy)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = color.withValues(alpha: fade * 0.9),
          );
        }
        break;

      // Toxic — splat blob
      case ElementalType.toxic:
        final r = 40.0 * p;
        paint.color = color.withValues(alpha: fade * 0.85);
        canvas.drawCircle(Offset(cx, cy), r, paint);
        // Droplets
        for (int i = 0; i < 5; i++) {
          final angle = pi * 2 * i / 5;
          final dr = r * 1.4;
          canvas.drawCircle(
            Offset(cx + cos(angle) * dr, cy + sin(angle) * dr),
            8 * p * fade,
            Paint()..color = color.withValues(alpha: fade * 0.6),
          );
        }
        break;

      // Rock — boulder chunks
      case ElementalType.rock:
        final rand = Random(42);
        for (int i = 0; i < 8; i++) {
          final angle = pi * 2 * i / 8 + rand.nextDouble();
          final dist = 15 + rand.nextDouble() * 35 * p;
          final bx = cx + cos(angle) * dist;
          final by = cy + sin(angle) * dist;
          final rect = Rect.fromCenter(
            center: Offset(bx, by),
            width: (8 + rand.nextDouble() * 8) * (1 - p * 0.3),
            height: (8 + rand.nextDouble() * 8) * (1 - p * 0.3),
          );
          canvas.drawRect(rect, Paint()..color = color.withValues(alpha: fade));
        }
        break;

      // Arthropod — claw marks (3 downward slashes)
      case ElementalType.arthropod:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        for (int i = -1; i <= 1; i++) {
          paint.color = color.withValues(alpha: fade);
          final ox = cx + i * 18.0;
          canvas.drawLine(
            Offset(ox - 10, cy - 35 * p),
            Offset(ox + 10, cy + 35 * p),
            paint,
          );
        }
        break;

      // Electric — lightning bolt
      case ElementalType.electric:
        final path = Path();
        path.moveTo(cx - 10, cy - 50 * p);
        path.lineTo(cx + 8, cy - 5 * p);
        path.lineTo(cx - 8, cy + 5 * p);
        path.lineTo(cx + 10, cy + 50 * p);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeJoin = StrokeJoin.round
            ..color = color.withValues(alpha: fade),
        );
        // Inner bright core
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: fade * 0.8),
        );
        break;

      // Darkness — void spiral
      case ElementalType.darkness:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        for (int i = 0; i < 3; i++) {
          final r2 = (20 + i * 12) * p;
          paint.color = color.withValues(alpha: fade * (1 - i * 0.2));
          final sweepAngle = pi * 2 * p;
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r2),
            -pi / 2 + i * pi / 3,
            sweepAngle,
            false,
            paint,
          );
        }
        // Dark shroud
        canvas.drawCircle(
          Offset(cx, cy),
          40 * p,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: fade * 0.3),
        );
        break;

      // Martial — impact stars + ring
      case ElementalType.martial:
        // Ring
        canvas.drawCircle(
          Offset(cx, cy),
          55 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = color.withValues(alpha: fade),
        );
        // 5-pointed star
        _drawStar(
          canvas,
          Offset(cx, cy),
          40 * p,
          5,
          color.withValues(alpha: fade),
        );
        break;

      // Blaze — fire burst
      case ElementalType.blaze:
        final rand2 = Random(12);
        for (int i = 0; i < 10; i++) {
          final angle = pi * 2 * rand2.nextDouble();
          final len = (20 + rand2.nextDouble() * 40) * p;
          final path = Path();
          path.moveTo(cx, cy);
          path.lineTo(cx + cos(angle) * len, cy + sin(angle) * len);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 + rand2.nextDouble() * 4
              ..color = color.withValues(alpha: fade * 0.9),
          );
        }
        // Core glow
        canvas.drawCircle(
          Offset(cx, cy),
          18 * p,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.white.withValues(alpha: fade * 0.6),
        );
        break;

      // Grass — leaf fan
      case ElementalType.grass:
        for (int i = 0; i < 6; i++) {
          final angle = pi * 2 * i / 6;
          final len = 50 * p;
          final ctrl = Offset(
            cx + cos(angle + 0.4) * len * 0.6,
            cy + sin(angle + 0.4) * len * 0.6,
          );
          final end = Offset(cx + cos(angle) * len, cy + sin(angle) * len);
          final path = Path()
            ..moveTo(cx, cy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = color.withValues(alpha: fade * 0.9),
          );
        }
        break;

      // Mystic — energy sigil rings
      case ElementalType.mystic:
        for (int i = 0; i < 4; i++) {
          final r3 = (10 + i * 12) * p;
          canvas.drawCircle(
            Offset(
              cx + cos(pi / 4 + i) * 10 * p,
              cy + sin(pi / 4 + i) * 10 * p,
            ),
            r3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fade * (0.6 + i * 0.1)),
          );
        }
        break;

      // Spectral — ghostly wisp
      case ElementalType.spectral:
        for (int i = 0; i < 3; i++) {
          final ox = cx + (i - 1) * 20.0;
          final r4 = (25 + i * 8) * p;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(ox, cy),
              width: r4,
              height: r4 * 1.5,
            ),
            Paint()
              ..style = PaintingStyle.fill
              ..color = color.withValues(alpha: fade * (0.4 - i * 0.05)),
          );
        }
        break;

      // Drake — dragon claw + breath
      case ElementalType.drake:
        // Three wide claw marks
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
        for (int i = -1; i <= 1; i++) {
          paint.color = color.withValues(alpha: fade);
          final ox = cx + i * 22.0;
          canvas.drawLine(
            Offset(ox - 15, cy - 40 * p),
            Offset(ox + 15, cy + 40 * p),
            paint,
          );
        }
        // Breath glow
        canvas.drawCircle(
          Offset(cx, cy),
          30 * p,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: fade * 0.4),
        );
        break;

      // Metal — gear/gear-spike burst
      case ElementalType.metal:
        _drawStar(
          canvas,
          Offset(cx, cy),
          50 * p,
          6,
          color.withValues(alpha: fade * 0.8),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          15 * p,
          Paint()..color = Colors.white.withValues(alpha: fade * 0.9),
        );
        break;

      // Aura — pulsing concentric rings
      case ElementalType.aura:
        for (int i = 0; i < 4; i++) {
          final r5 = (15 + i * 14) * p;
          canvas.drawCircle(
            Offset(cx, cy),
            r5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fade * (0.9 - i * 0.15)),
          );
        }
        break;

      // Sound — expanding sound wave arcs
      case ElementalType.sound:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        for (int i = 0; i < 5; i++) {
          final r6 = (15 + i * 16) * p;
          paint.color = color.withValues(alpha: fade * (1 - i * 0.15));
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r6),
            -pi * 0.7,
            pi * 1.4,
            false,
            paint,
          );
        }
        break;

      // Holy — radiant cross + halo
      case ElementalType.holy:
        // Halo
        canvas.drawCircle(
          Offset(cx, cy),
          50 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = color.withValues(alpha: fade),
        );
        // Radiant cross
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.white.withValues(alpha: fade);
        canvas.drawLine(
          Offset(cx, cy - 50 * p),
          Offset(cx, cy + 50 * p),
          paint,
        );
        canvas.drawLine(
          Offset(cx - 50 * p, cy),
          Offset(cx + 50 * p, cy),
          paint,
        );
        break;
    }
  }

  void _drawSlash(
    Canvas canvas,
    double cx,
    double cy,
    double len,
    Paint paint,
  ) {
    canvas.drawLine(
      Offset(cx - len, cy - len),
      Offset(cx + len, cy + len),
      paint,
    );
    canvas.drawLine(
      Offset(cx + len, cy - len),
      Offset(cx - len, cy + len),
      paint,
    );
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double radius,
    int points,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -pi / 2 + pi * i / points;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PhysicalHitPainter old) => old.progress != progress;
}

// ----------------------------------------------------------------
// Special Hit Painter — projectile shapes per type
// ----------------------------------------------------------------
class _SpecialHitPainter extends CustomPainter {
  final ElementalType type;
  final Color color;
  final double progress;
  final bool flip;

  _SpecialHitPainter({
    required this.type,
    required this.color,
    required this.progress,
    required this.flip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = progress;
    final fade = (1.0 - p).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;

    // Phases: 0-0.5 = projectile travels, 0.5-1.0 = impact explosion
    final travelPhase = (p * 2).clamp(0.0, 1.0);
    final impactPhase = ((p - 0.5) * 2).clamp(0.0, 1.0);

    switch (type) {
      // Basic — orb projectile
      case ElementalType.basic:
        _drawOrb(canvas, cx, cy, travelPhase, impactPhase, color, fade);
        break;

      // Flying — wind dart
      case ElementalType.flying:
        _drawWindDart(canvas, cx, cy, travelPhase, impactPhase, color, fade);
        break;

      // Aquatic — water bubble
      case ElementalType.aquatic:
        final bx = cx - 60 + travelPhase * 60;
        final by = cy;
        final r = 18 * (1 - impactPhase * 0.7);
        canvas.drawCircle(
          Offset(bx, by),
          r,
          paint..color = color.withValues(alpha: fade * 0.85),
        );
        canvas.drawCircle(
          Offset(bx, by),
          r * 0.6,
          Paint()..color = Colors.white.withValues(alpha: fade * 0.4),
        );
        if (impactPhase > 0) {
          // Splash
          for (int i = 0; i < 6; i++) {
            final angle = pi * 2 * i / 6;
            final dist = impactPhase * 40;
            canvas.drawCircle(
              Offset(cx + cos(angle) * dist, cy + sin(angle) * dist),
              5 * (1 - impactPhase),
              Paint()..color = color.withValues(alpha: fade * 0.7),
            );
          }
        }
        break;

      // Earth — boulder projectile
      case ElementalType.earth:
        final bx = cx - 60 + travelPhase * 60;
        final by = cy + travelPhase * 5;
        if (impactPhase == 0) {
          final rect = Rect.fromCenter(
            center: Offset(bx, by),
            width: 28,
            height: 24,
          );
          canvas.drawRect(rect, paint..color = color.withValues(alpha: fade));
        } else {
          // Fragment explosion
          final rand = Random(7);
          for (int i = 0; i < 8; i++) {
            final angle = pi * 2 * rand.nextDouble();
            final dist = impactPhase * 45 * rand.nextDouble();
            final frag = Rect.fromCenter(
              center: Offset(cx + cos(angle) * dist, cy + sin(angle) * dist),
              width: 8 * (1 - impactPhase),
              height: 8 * (1 - impactPhase),
            );
            canvas.drawRect(
              frag,
              Paint()..color = color.withValues(alpha: fade),
            );
          }
        }
        break;

      // Cryo — ice shard spear
      case ElementalType.cryo:
        final bx = cx - 60 + travelPhase * 55;
        final by = cy;
        final shardPath = Path()
          ..moveTo(bx + 24, by)
          ..lineTo(bx, by - 8)
          ..lineTo(bx - 8, by)
          ..lineTo(bx, by + 8)
          ..close();
        canvas.drawPath(
          shardPath,
          paint..color = color.withValues(alpha: fade * 0.9),
        );
        canvas.drawPath(
          shardPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: fade * 0.5),
        );
        if (impactPhase > 0) {
          for (int i = 0; i < 6; i++) {
            final angle = pi * 2 * i / 6;
            final len = impactPhase * 40;
            canvas.drawLine(
              Offset(cx, cy),
              Offset(cx + cos(angle) * len, cy + sin(angle) * len),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = color.withValues(alpha: fade * 0.8),
            );
          }
        }
        break;

      // Toxic — poison cloud
      case ElementalType.toxic:
        final bx = cx - 60 + travelPhase * 60;
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(bx + i * 8.0, cy - i * 5.0),
            (12 + i * 5) * (1 - p * 0.3),
            Paint()..color = color.withValues(alpha: fade * (0.7 - i * 0.15)),
          );
        }
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            Paint()..color = color.withValues(alpha: fade * 0.35),
          );
        }
        break;

      // Rock — stone lob (parabolic)
      case ElementalType.rock:
        final bx = cx - 60 + travelPhase * 60;
        final by = cy - sin(travelPhase * pi) * 30;
        canvas.drawCircle(
          Offset(bx, by),
          14,
          paint..color = color.withValues(alpha: fade),
        );
        if (impactPhase > 0) {
          // Dust cloud
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 40,
            Paint()..color = color.withValues(alpha: fade * 0.3),
          );
        }
        break;

      // Arthropod — stinger dart
      case ElementalType.arthropod:
        final bx = cx - 65 + travelPhase * 65;
        final path = Path()
          ..moveTo(bx + 20, cy)
          ..lineTo(bx, cy - 6)
          ..lineTo(bx - 5, cy)
          ..lineTo(bx, cy + 6)
          ..close();
        canvas.drawPath(path, paint..color = color.withValues(alpha: fade));
        break;

      // Electric — lightning bolt projectile
      case ElementalType.electric:
        final bx = cx - 60 + travelPhase * 55;
        final zap = Path()
          ..moveTo(bx, cy - 20)
          ..lineTo(bx + 12, cy - 2)
          ..lineTo(bx + 4, cy + 2)
          ..lineTo(bx + 16, cy + 20);
        canvas.drawPath(
          zap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = color.withValues(alpha: fade),
        );
        canvas.drawPath(
          zap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white.withValues(alpha: fade * 0.9),
        );
        if (impactPhase > 0) {
          for (int i = 0; i < 8; i++) {
            final angle = pi * 2 * i / 8;
            final len = impactPhase * 40;
            canvas.drawLine(
              Offset(cx, cy),
              Offset(cx + cos(angle) * len, cy + sin(angle) * len),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = color.withValues(alpha: fade * 0.9),
            );
          }
        }
        break;

      // Darkness — shadow orb
      case ElementalType.darkness:
        final bx = cx - 60 + travelPhase * 60;
        canvas.drawCircle(
          Offset(bx, cy),
          20,
          paint..color = color.withValues(alpha: fade * 0.9),
        );
        canvas.drawCircle(
          Offset(bx - 5, cy - 5),
          8,
          Paint()..color = Colors.deepPurple.withValues(alpha: fade * 0.5),
        );
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 55,
            Paint()..color = color.withValues(alpha: fade * 0.25),
          );
        }
        break;

      // Martial — ki blast
      case ElementalType.martial:
        _drawOrb(canvas, cx, cy, travelPhase, impactPhase, color, fade);
        break;

      // Blaze — fireball
      case ElementalType.blaze:
        final bx = cx - 70 + travelPhase * 65;
        canvas.drawCircle(
          Offset(bx, cy),
          20 - travelPhase * 4,
          paint..color = color.withValues(alpha: fade),
        );
        canvas.drawCircle(
          Offset(bx, cy),
          10 - travelPhase * 3,
          Paint()..color = Colors.yellow.withValues(alpha: fade * 0.8),
        );
        // Flame trail
        final trailCells = 4;
        for (int i = 1; i <= trailCells; i++) {
          final tx = bx - i * 12.0;
          canvas.drawCircle(
            Offset(tx, cy),
            (8 - i * 1.5) * (1 - travelPhase * 0.5),
            Paint()..color = color.withValues(alpha: fade * (0.6 - i * 0.1)),
          );
        }
        if (impactPhase > 0) {
          // Explosion
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            paint..color = color.withValues(alpha: fade * 0.5),
          );
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 30,
            Paint()..color = Colors.yellow.withValues(alpha: fade * 0.7),
          );
        }
        break;

      // Grass — razor leaf
      case ElementalType.grass:
        final bx = cx - 60 + travelPhase * 60;
        final leafPath = Path()
          ..moveTo(bx, cy - 14)
          ..quadraticBezierTo(bx + 20, cy, bx, cy + 14)
          ..quadraticBezierTo(bx - 20, cy, bx, cy - 14);
        canvas.drawPath(leafPath, paint..color = color.withValues(alpha: fade));
        canvas.drawLine(
          Offset(bx - 10, cy),
          Offset(bx + 10, cy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: fade * 0.5),
        );
        break;

      // Mystic — arcane missile
      case ElementalType.mystic:
        final bx = cx - 65 + travelPhase * 65;
        // Spiral trail
        for (int i = 0; i < 5; i++) {
          final tx = bx - i * 14.0;
          final angle = i * 1.2;
          canvas.drawCircle(
            Offset(tx + cos(angle) * 8, cy + sin(angle) * 8),
            (10 - i * 1.5),
            Paint()..color = color.withValues(alpha: fade * (0.8 - i * 0.1)),
          );
        }
        if (impactPhase > 0) {
          for (int i = 0; i < 6; i++) {
            final angle = pi * 2 * i / 6;
            canvas.drawCircle(
              Offset(
                cx + cos(angle) * impactPhase * 45,
                cy + sin(angle) * impactPhase * 45,
              ),
              8 * (1 - impactPhase),
              Paint()..color = color.withValues(alpha: fade * 0.9),
            );
          }
        }
        break;

      // Spectral — spectral beam
      case ElementalType.spectral:
        final bx = cx - 70 + travelPhase * 65;
        for (int i = 0; i < 3; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(bx - i * 8.0, cy + (i - 1) * 6.0),
              width: 20.0,
              height: 30.0,
            ),
            Paint()..color = color.withValues(alpha: fade * (0.7 - i * 0.15)),
          );
        }
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            Paint()..color = color.withValues(alpha: fade * 0.3),
          );
        }
        break;

      // Drake — dragon beam
      case ElementalType.drake:
        // Beam
        final beamRect = Rect.fromLTWH(
          cx - 65 * (1 - travelPhase),
          cy - 8,
          65 * travelPhase,
          16,
        );
        canvas.drawRect(
          beamRect,
          paint..color = color.withValues(alpha: fade * 0.85),
        );
        // Core
        canvas.drawRect(
          Rect.fromLTWH(beamRect.left, cy - 4, beamRect.width, 8),
          Paint()..color = Colors.white.withValues(alpha: fade * 0.5),
        );
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 55,
            paint..color = color.withValues(alpha: fade * 0.5),
          );
        }
        break;

      // Metal — spinning gear projectile
      case ElementalType.metal:
        final bx = cx - 60 + travelPhase * 60;
        canvas.save();
        canvas.translate(bx, cy);
        canvas.rotate(travelPhase * pi * 3);
        _drawStarOnCanvas(
          canvas,
          Offset.zero,
          18,
          6,
          color.withValues(alpha: fade * 0.9),
        );
        canvas.restore();
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 45,
            paint..color = color.withValues(alpha: fade * 0.4),
          );
        }
        break;

      // Aura — aura pulse orb
      case ElementalType.aura:
        final bx = cx - 65 + travelPhase * 65;
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(bx, cy),
            (18 - i * 4) * (0.8 + sin(travelPhase * pi * 4 + i) * 0.2),
            Paint()..color = color.withValues(alpha: fade * (0.9 - i * 0.2)),
          );
        }
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            paint..color = color.withValues(alpha: fade * 0.4),
          );
        }
        break;

      // Sound — sonic ring
      case ElementalType.sound:
        final bx = cx - 65 + travelPhase * 65;
        for (int i = 0; i < 4; i++) {
          canvas.drawCircle(
            Offset(bx, cy),
            (8 + i * 10).toDouble() * travelPhase,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fade * (0.9 - i * 0.15)),
          );
        }
        if (impactPhase > 0) {
          for (int i = 0; i < 5; i++) {
            final r = (10 + i * 15) * impactPhase;
            canvas.drawCircle(
              Offset(cx, cy),
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = color.withValues(alpha: fade * (0.8 - i * 0.12)),
            );
          }
        }
        break;

      // Holy — holy beam
      case ElementalType.holy:
        final beamW = travelPhase * 65;
        final beamRect = Rect.fromLTWH(cx - beamW, cy - 10, beamW, 20);
        canvas.drawRect(
          beamRect,
          paint..color = color.withValues(alpha: fade * 0.6),
        );
        canvas.drawRect(
          Rect.fromLTWH(cx - beamW, cy - 4, beamW, 8),
          Paint()..color = Colors.white.withValues(alpha: fade * 0.8),
        );
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 55,
            paint..color = color.withValues(alpha: fade * 0.5),
          );
          // Cross burst
          canvas.drawLine(
            Offset(cx - impactPhase * 50, cy),
            Offset(cx + impactPhase * 50, cy),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.white.withValues(alpha: fade * 0.8),
          );
          canvas.drawLine(
            Offset(cx, cy - impactPhase * 50),
            Offset(cx, cy + impactPhase * 50),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.white.withValues(alpha: fade * 0.8),
          );
        }
        break;
    }
  }

  void _drawOrb(
    Canvas canvas,
    double cx,
    double cy,
    double travel,
    double impact,
    Color color,
    double fade,
  ) {
    final bx = cx - 60 + travel * 60;
    canvas.drawCircle(
      Offset(bx, cy),
      18 * (1 - impact * 0.6),
      Paint()..color = color.withValues(alpha: fade * 0.9),
    );
    canvas.drawCircle(
      Offset(bx, cy),
      10 * (1 - impact * 0.6),
      Paint()..color = Colors.white.withValues(alpha: fade * 0.5),
    );
    if (impact > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        impact * 50,
        Paint()..color = color.withValues(alpha: fade * 0.4),
      );
    }
  }

  void _drawWindDart(
    Canvas canvas,
    double cx,
    double cy,
    double travel,
    double impact,
    Color color,
    double fade,
  ) {
    final bx = cx - 65 + travel * 65;
    final path = Path()
      ..moveTo(bx + 24, cy)
      ..lineTo(bx, cy - 6)
      ..lineTo(bx - 16, cy)
      ..lineTo(bx, cy + 6)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: fade * 0.85),
    );
    if (impact > 0) {
      for (int i = 0; i < 6; i++) {
        final angle = pi * 2 * i / 6;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(angle) * impact * 45, cy + sin(angle) * impact * 45),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color.withValues(alpha: fade * 0.8),
        );
      }
    }
  }

  void _drawStarOnCanvas(
    Canvas canvas,
    Offset center,
    double radius,
    int points,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -pi / 2 + pi * i / points;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpecialHitPainter old) => old.progress != progress;
}

// ----------------------------------------------------------------
// Status Effect Painter — aura/buff animations per type
// ----------------------------------------------------------------
class _StatusEffectPainter extends CustomPainter {
  final ElementalType type;
  final Color color;
  final double progress;

  _StatusEffectPainter({
    required this.type,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = progress;
    // Status animations: rise upward + fade
    final fadeOut = (1.0 - p).clamp(0.0, 1.0);
    final riseY = cy - p * 40;
    final paint = Paint();

    switch (type) {
      case ElementalType.toxic:
        // Dripping bubbles
        for (int i = 0; i < 5; i++) {
          final angle = pi * 2 * i / 5;
          final ox = cx + cos(angle) * 35;
          final oy = riseY + sin(angle) * 20;
          canvas.drawCircle(
            Offset(ox, oy),
            8 + i * 2.0,
            paint..color = color.withValues(alpha: fadeOut * 0.7),
          );
        }
        break;

      case ElementalType.blaze:
        // Rising embers
        final rand = Random(3);
        for (int i = 0; i < 8; i++) {
          final ox = cx + (rand.nextDouble() - 0.5) * 60;
          final oy = riseY - i * 8.0 + rand.nextDouble() * 10;
          canvas.drawCircle(
            Offset(ox, oy),
            3 + rand.nextDouble() * 4,
            paint..color = color.withValues(alpha: fadeOut * 0.8),
          );
        }
        break;

      case ElementalType.cryo:
        // Snowflake descend
        for (int i = 0; i < 6; i++) {
          final angle = pi * 2 * i / 6;
          final len = 30 + sin(p * pi) * 15;
          canvas.drawLine(
            Offset(cx, riseY),
            Offset(cx + cos(angle) * len, riseY + sin(angle) * len),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = color.withValues(alpha: fadeOut),
          );
          // Mini cross
          canvas.drawLine(
            Offset(cx + cos(angle) * len * 0.6, riseY + sin(angle) * len * 0.6),
            Offset(
              cx + cos(angle) * len * 0.6 + cos(angle + pi / 2) * 8,
              riseY + sin(angle) * len * 0.6 + sin(angle + pi / 2) * 8,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color.withValues(alpha: fadeOut * 0.7),
          );
        }
        break;

      case ElementalType.electric:
        // Jolts
        for (int i = 0; i < 4; i++) {
          final ox = cx + (i - 1.5) * 20.0;
          final path = Path()
            ..moveTo(ox - 4, riseY - 25)
            ..lineTo(ox + 4, riseY)
            ..lineTo(ox - 4, riseY + 5)
            ..lineTo(ox + 4, riseY + 25);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fadeOut),
          );
        }
        break;

      case ElementalType.darkness:
        // Dark swirling wisps
        for (int i = 0; i < 4; i++) {
          final angle = p * pi * 2 + i * pi / 2;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx + cos(angle) * 25, riseY + sin(angle) * 15),
              width: 20,
              height: 30,
            ),
            paint..color = color.withValues(alpha: fadeOut * 0.5),
          );
        }
        break;

      case ElementalType.holy:
        // Rising sparks
        for (int i = 0; i < 6; i++) {
          final angle = pi * 2 * i / 6;
          final dist = 30 + sin(p * pi) * 20;
          canvas.drawCircle(
            Offset(cx + cos(angle) * dist, riseY + sin(angle) * dist * 0.4),
            5 * fadeOut,
            paint..color = color.withValues(alpha: fadeOut),
          );
        }
        break;

      case ElementalType.grass:
        // Leaves swirling up
        final rand2 = Random(9);
        for (int i = 0; i < 6; i++) {
          final angle = p * pi * 3 + i * pi / 3;
          final dist = 20 + rand2.nextDouble() * 25;
          final lx = cx + cos(angle) * dist;
          final ly = riseY + sin(angle) * dist * 0.5;
          final leafPath = Path()
            ..moveTo(lx, ly - 8)
            ..quadraticBezierTo(lx + 8, ly, lx, ly + 8)
            ..quadraticBezierTo(lx - 8, ly, lx, ly - 8);
          canvas.drawPath(
            leafPath,
            paint..color = color.withValues(alpha: fadeOut * 0.8),
          );
        }
        break;

      case ElementalType.spectral:
        // Ghostly orbs
        for (int i = 0; i < 3; i++) {
          final angle = p * pi * 2 + i * pi * 2 / 3;
          canvas.drawCircle(
            Offset(cx + cos(angle) * 30, riseY + sin(angle) * 20),
            12 * fadeOut,
            paint..color = color.withValues(alpha: fadeOut * 0.6),
          );
        }
        break;

      case ElementalType.aura:
        // Pulsing rings
        for (int i = 0; i < 3; i++) {
          final r = (20 + i * 15) * (0.7 + sin(p * pi * 2) * 0.3);
          canvas.drawCircle(
            Offset(cx, riseY + 10),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fadeOut * (0.9 - i * 0.2)),
          );
        }
        break;

      case ElementalType.mystic:
        // Sigil spirals
        for (int i = 0; i < 12; i++) {
          final angle = pi * 2 * i / 12;
          final r = 35 * (0.5 + p * 0.5);
          canvas.drawCircle(
            Offset(
              cx + cos(angle + p * pi * 2) * r,
              riseY + sin(angle + p * pi * 2) * r * 0.5,
            ),
            4,
            paint..color = color.withValues(alpha: fadeOut * 0.8),
          );
        }
        break;

      default:
        // Generic: expanding rings
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(cx, riseY),
            (20 + i * 15) * p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = color.withValues(alpha: fadeOut * (0.8 - i * 0.2)),
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_StatusEffectPainter old) => old.progress != progress;
}
