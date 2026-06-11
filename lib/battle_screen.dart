// lib/battle_screen.dart

import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:animal_warfare/models/battle_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/rogue/biome_select_screen.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/game/move_animations.dart' as anims;
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/models/elemental_type.dart'; // Added
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/game/trainer_data.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:animal_warfare/widgets/capture_overlay.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/widgets/terrain_overlay.dart';
import 'package:animal_warfare/widgets/item_icon.dart';
import 'package:animal_warfare/widgets/battle_details_sheet.dart';
import 'package:animal_warfare/widgets/battle_sprite.dart';
import 'package:animal_warfare/models/battle_card.dart';

class BattleScreen extends StatelessWidget {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  final String biomeName;
  final List<CapturedOrganism>? playerTeam;
  final String? battleTitle;
  final bool isArenaBattle;
  final bool isTrainerBattle;
  final List<CapturedOrganism>? opponentTeam;
  final bool isRogueMode;
  final TeamArchetype? opponentArchetype;
  final String? timeOfDay;
  final bool startAsleep;
  final ui.Image? mapScreenshot;
  final String? encounterTileId;
  final bool shouldPersistResults;
  final TrainerInfo? trainerInfo;

  const BattleScreen({
    super.key,
    required this.playerOrganism,
    required this.opponentOrganism,
    required this.biomeName,
    this.playerTeam,
    this.battleTitle,
    this.isArenaBattle = false,
    this.isTrainerBattle = false,
    this.opponentTeam,
    this.isRogueMode = false,
    this.opponentArchetype,
    this.timeOfDay,
    this.startAsleep = false,
    this.mapScreenshot,
    this.encounterTileId,
    this.shouldPersistResults = true,
    this.trainerInfo,
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
          isTrainerBattle: isTrainerBattle,
          opponentArchetype: opponentArchetype,
          accountLevel: userState.currentUser?.accountLevel ?? 100,
          initialPlayerIndex: isRogueMode
              ? userState.currentUser?.rogueLikeState.currentPlayerIndex
              : null,
          startAsleep: startAsleep,
          trainerInfo: trainerInfo,
        );
      },
      child: BattleScreenContent(
        biomeName: biomeName,
        opponentName: opponentOrganism.baseOrganism.name,
        battleTitle: battleTitle,
        isArenaBattle: isArenaBattle,
        isRogueMode: isRogueMode,
        isTrainerBattle: isTrainerBattle,
        timeOfDay: timeOfDay,
        opponentFullTeam: opponentTeam,
        startAsleep: startAsleep,
        mapScreenshot: mapScreenshot,
        encounterTileId: encounterTileId,
        shouldPersistResults: shouldPersistResults,
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
  final bool isTrainerBattle;
  final String? timeOfDay;

  final List<CapturedOrganism>? opponentFullTeam;
  final bool startAsleep;
  final ui.Image? mapScreenshot;
  final String? encounterTileId;

  final bool shouldPersistResults;

  const BattleScreenContent({
    super.key,
    required this.biomeName,
    required this.opponentName,
    this.battleTitle,
    this.isArenaBattle = false,
    this.isRogueMode = false,
    this.isTrainerBattle = false,
    this.timeOfDay,
    this.opponentFullTeam,
    this.startAsleep = false,
    this.mapScreenshot,
    this.encounterTileId,
    this.shouldPersistResults = true,
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
    if (biome.contains('jungle') || biome.contains('jungle')) {
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
    if (biome.contains('jungle') || biome.contains('jungle')) {
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
    if (biome.contains('jungle') || biome.contains('jungle')) {
      return const Color(0xFF1B5E20); // Dark Green
    }
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river')) {
      return const Color(0xFF0D47A1); // Dark Blue
    }
    return const Color(0xFF1E3F2A); // Default Deep jungle Green
  }

  // Helper: Calculate effectiveness multiplier
  double _calculateMoveEffectiveness(Move move, BattleOrganism opponent) {
    if (move.category == MoveCategory.status) return 1.0;

    double multiplier = 1.0;
    for (final type in opponent.types) {
      multiplier *= TypeChart.getEffectiveness(move.type, type);
    }
    return multiplier;
  }

  // Helper: Get effectiveness text
  String _getEffectivenessText(double multiplier) {
    if (multiplier >= 3.9) return 'Extremely Effective!';
    if (multiplier > 1.1) return 'Super Effective!';
    if (multiplier == 0.0) return 'Immune';
    if (multiplier <= 0.26) return 'Barely Effective';
    if (multiplier < 0.9) return 'Not Effective';
    return '';
  }

  late AnimationController _playerShakeController;
  late AnimationController _opponentShakeController;
  late Animation<double> _playerShakeAnimation;
  late Animation<double> _opponentShakeAnimation;
  bool _isSwitchDialogShowing = false;
  bool _isDetailsSheetOpen = false;
  bool _isHandlingBattleEnd = false;
  bool _isFastMode = false; // Hold message box to speed up text 3x
  CapturedOrganism? _pendingRogueCapture;
  BattleManager? _battleManager;
  final LayerLink _playerLink = LayerLink();
  final LayerLink _opponentLink = LayerLink();
  final List<_IndicatorData> _indicators = [];

  // Card Animation state
  String? _animatingCardId;
  bool _animatingCardIsPlayer = false;

  void _onCardPlayed(String cardId, bool isPlayer) {
    if (!mounted) return;
    setState(() {
      _animatingCardId = cardId;
      _animatingCardIsPlayer = isPlayer;
    });
    AudioService.instance.playSound('audio/effects/card_play.mp3');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _animatingCardId = null;
        });
      }
    });
  }

  // Gimmick animation state
  String? _activeGimmickType;
  BattleOrganism? _gimmickTarget;
  bool _showGimmickBanner = false;

  // Move animation tracking
  final List<anims.MoveAnimData> _moveAnims = [];
  int _moveAnimIdCounter = 0;
  double _screenShakeX = 0;
  double _screenShakeY = 0;

  AnimationController? _screenShakeController;

  final GlobalKey<BattleSpriteState> _playerSpriteKey = GlobalKey();
  final GlobalKey<BattleSpriteState> _opponentSpriteKey = GlobalKey();
  Animation<double>? _screenShakeXAnim;
  Animation<double>? _screenShakeYAnim;

  final Map<String, dynamic> _cumulativeXPResults = {};

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer to handle app backgrounding
    WidgetsBinding.instance.addObserver(this);

    // Play battle music — randomly pick between the two available battle themes
    final rand = Random();
    final track = rand.nextBool()
        ? 'audio/battle_default.mp3'
        : 'audio/battle_default1.mp3';
    AudioService.instance.pushMusic(track);

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
      bm.onCardPlayed = _onCardPlayed;
      // Note: Gimmick activation is handled via pendingGimmickType state flag
      // which is read in _handleStateTriggers - no callback needed

      // Sync rogue state mid-battle
      if (widget.isRogueMode) {
        bm.addListener(_syncRogueState);
      }
      bm.addListener(_handleStateTriggers);

      // FIX: Trigger state check immediately after adding listener to prevent race conditions
      // (e.g. if bm.currentState is already in a triggered state)
      _handleStateTriggers();
    });
  }

  void _handleStateTriggers() {
    if (!mounted) return;
    final bm = Provider.of<BattleManager>(context, listen: false);

    // Handle pending gimmick activation (set by BattleManager, cleared here)
    if (bm.pendingGimmickType != null && bm.pendingGimmickTarget != null) {
      final type = bm.pendingGimmickType!;
      final target = bm.pendingGimmickTarget!;
      bm.pendingGimmickType = null;
      bm.pendingGimmickTarget = null;

      // SAFE LISTENER PATTERN: Wrap UI updates in a frame callback to avoid
      // "setState() or markNeedsBuild() called during build" errors.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onGimmickActivation(target, type);
      });
    }

    // Double-switch guard: set flag synchronously BEFORE opening dialog
    if (bm.currentState == BattleState.choosingLead &&
        !_isSwitchDialogShowing) {
      _isSwitchDialogShowing = true;
      _showPartyScreen(
        context,
        bm,
        title: 'CHOOSE YOUR LEAD!',
        isForced: true,
        isLeadSelection: true,
      );
    } else if (bm.currentState == BattleState.waitingForPlayerSwitch &&
        !_isSwitchDialogShowing) {
      _isSwitchDialogShowing = true;
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

    // FIX: Pop the music from the stack to resume the previous track (e.g. biome theme)
    AudioService.instance.popMusic();

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
        // App went to background (totally obscured) - pause audio
        AudioService.instance.pauseAll();
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
        anims.MoveAnimData(
          id: id,
          move: move,
          isPlayerAttacking: isPlayerAttacking,
        ),
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

  void _onGimmickActivation(BattleOrganism target, String type) {
    if (!mounted) return;

    // Set banner state immediately
    setState(() {
      _activeGimmickType = type;
      _gimmickTarget = target;
      _showGimmickBanner = true;
    });

    if (type == 'titanize') {
      // Schedule screen shakes for after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runScreenShake();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _runScreenShake();
        });
      });
    }

    // Hide banner after 2.5s
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showGimmickBanner = false;
        });
      }
    });

    // Clear active gimmick state after effect is done
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _activeGimmickType = null;
          _gimmickTarget = null;
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

    if (!widget.isArenaBattle) {
      final results = await userState.awardBattleXP(
        defeatedLevel: victim.level,
        killerId: killer.organism.id,
        teamIds: bm.playerTeam.map((o) => o.id).toList(),
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
    if (name == 'jungle') return 'assets/biomes/jungle-bg.png';
    if (name == 'rainforest' || name == 'rainforest') {
      return 'assets/biomes/rainforest-bg.png';
    }
    if (name == 'plains') return 'assets/biomes/savanna-bg.png';

    // 4. Asset formatting
    final fileName = name.replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  void _showBattleLog(BuildContext context, BattleManager battleManager) {
    final isNarrow = MediaQuery.sizeOf(context).width < 400;
    final themeColor = _getBiomeThemeColor();
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
                color: const Color(0xFF141414), // Darker, cleaner background
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: themeColor, width: 3),
                  left: BorderSide(color: themeColor, width: 3),
                  right: BorderSide(color: themeColor, width: 3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.15),
                    blurRadius: 30,
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
                      color: Colors.black.withValues(alpha: 0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: themeColor.withValues(alpha: 0.3),
                        ),
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
                                        color: secondaryColor.withValues(
                                          alpha: 0.95,
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
                                  color: Colors.white.withValues(alpha: 0.5),
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
                        vertical: 12,
                      ),
                      itemCount: battleManager.turnHistory.length,
                      itemBuilder: (_, i) {
                        final turnIndex =
                            battleManager.turnHistory.length - 1 - i;
                        final turn = battleManager.turnHistory[turnIndex];

                        if (turn.logEntries.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return _buildTurnLogGroup(
                          context,
                          turn,
                          themeColor,
                          isNarrow,
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

  Widget _buildTurnLogGroup(
    BuildContext context,
    BattleTurn turn,
    Color themeColor,
    bool isNarrow,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turn Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              border: Border(left: BorderSide(color: themeColor, width: 4)),
            ),
            child: Text(
              'TURN ${turn.turnNumber}',
              style: TextStyle(
                color: themeColor,
                fontFamily: 'PressStart2P',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Log Entries
          ...turn.logEntries.map(
            (entry) => _buildLogEntry(context, entry, themeColor, isNarrow),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(
    BuildContext context,
    String entry,
    Color themeColor,
    bool isNarrow,
  ) {
    // Determine entry style based on content
    Color accentColor = themeColor;
    IconData entryIcon = Icons.navigate_next;
    bool isHighlight = false;

    final lowerEntry = entry.toLowerCase();
    String? entryIconPath;
    if (lowerEntry.contains('critical hit')) {
      accentColor = Colors.redAccent;
      entryIconPath = 'assets/icon/power.png';
      isHighlight = true;
    } else if (lowerEntry.contains('super effective')) {
      accentColor = Colors.orangeAccent;
      entryIconPath = 'assets/icon/aura.png';
      isHighlight = true;
    } else if (lowerEntry.contains('not very effective')) {
      accentColor = Colors.blueGrey;
      entryIconPath = 'assets/icon/defense.png';
    } else if (lowerEntry.contains('fainted')) {
      accentColor = Colors.red;
      entryIconPath = 'assets/icon/spectral.png';
      isHighlight = true;
    } else if (lowerEntry.contains('uses')) {
      accentColor = themeColor;
      entryIconPath = 'assets/icon/attack.png';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: entryIconPath != null
                ? Image.asset(
                    entryIconPath,
                    color: accentColor,
                    width: 14,
                    height: 14,
                  )
                : Icon(entryIcon, color: accentColor, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry,
              style: TextStyle(
                color: isHighlight
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.85),
                fontSize: isNarrow ? 9 : 10,
                fontFamily: 'PressStart2P',
                height: 1.5,
                shadows: isHighlight
                    ? [
                        Shadow(
                          color: accentColor.withValues(alpha: 0.5),
                          offset: const Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ],
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
        onPopInvokedWithResult: (didPop, result) {
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
          onShowSummary: (bo) async {
            _isDetailsSheetOpen = true;
            await BattleDetailsSheet.show(context, bo, true);
            _isDetailsSheetOpen = false;
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Responsive breakpoints: compact <360, medium 360-480
    final isNarrow = screenWidth < 360;

    // Moved _handleBattleEnd to _handleStateTriggers (listener) to avoid build-phase side effects.

    final overlayColor = const Color.fromARGB(
      255,
      0,
      0,
      0,
    ).withValues(alpha: 0.5); //majority of black

    // Initialize/Update listener
    battleManager.onAttack = _onAttack;
    battleManager.onDamage = _onDamage;
    battleManager.onHeal = _onHeal;
    battleManager.onStatChange = (target, stat, value) {
      _onStatChange(target, stat, value);
      final spriteKey = target == battleManager.player
          ? _playerSpriteKey
          : _opponentSpriteKey;
      spriteKey.currentState?.showStatChange(value > 0);
    };

    return PopScope(
      canPop: battleManager.currentState == BattleState.battleEnd,
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
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (battleManager.isWaitingForDialogueClick) {
              battleManager.advanceDialogue();
            }
          },
          child: Transform.translate(
            offset: Offset(_screenShakeX, _screenShakeY),
            child: Stack(
              children: [
                // Background: use blurred map screenshot if available, else biome asset
                if (widget.mapScreenshot != null)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 1.5,
                        sigmaY: 1.5,
                        tileMode: TileMode.clamp,
                      ),
                      child: RawImage(
                        image: widget.mapScreenshot,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (widget.mapScreenshot != null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                if (widget.mapScreenshot == null)
                  StreamBuilder<GameTime>(
                    stream: TimeService().timeStream,
                    builder: (context, snapshot) {
                      //final hour = TimeService().currentGameTime.hour;
                      // final timeOfDay = (hour >= 6 && hour < 18)
                      //     ? 'day'
                      //     : (hour >= 18 && hour < 21 ? 'evening' : 'night');

                      return Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(_getAssetPath(widget.biomeName)),
                            fit: BoxFit.cover,
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
                  child: Stack(
                    children: [
                      // Portrait layout uses a Column with fixed bottom panel
                      OrientationBuilder(
                        builder: (context, orientation) {
                          final isLandscape =
                              orientation == Orientation.landscape;

                          if (isLandscape) {
                            return Column(
                              children: [
                                _buildHeader(
                                  context,
                                  battleManager,
                                  overlayColor,
                                ),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            const SizedBox(height: 2),
                                            AnimatedBuilder(
                                              animation:
                                                  _opponentShakeAnimation,
                                              builder: (context, child) =>
                                                  Transform.translate(
                                                    offset: Offset(
                                                      _opponentShakeAnimation
                                                          .value,
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
                                                spriteKey: _opponentSpriteKey,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            AnimatedBuilder(
                                              animation: _playerShakeAnimation,
                                              builder: (context, child) =>
                                                  Transform.translate(
                                                    offset: Offset(
                                                      _playerShakeAnimation
                                                          .value,
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
                                                battleManager,
                                                spriteKey: _playerSpriteKey,
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
                                            // Empty space where logs would be, leaving room for animations
                                            Expanded(child: const SizedBox()),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          // Portrait layout: split into battle field (top) + bottom panel (Expanded)
                          return Column(
                            children: [
                              // === BATTLE FIELD AREA (top, takes only needed height) ===
                              Flexible(
                                fit: FlexFit.loose,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildHeader(
                                        context,
                                        battleManager,
                                        overlayColor,
                                      ),
                                      const SizedBox(height: 2),
                                      const Divider(
                                        height: 1,
                                        color: Colors.white24,
                                      ),
                                      const SizedBox(height: 2),
                                      _buildFieldEffects(
                                        context,
                                        battleManager,
                                      ),
                                      const SizedBox(height: 2),
                                      // Participant area - takes min height
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Stack(
                                            clipBehavior: Clip.hardEdge,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  AnimatedBuilder(
                                                    animation:
                                                        _opponentShakeAnimation,
                                                    builder: (context, child) =>
                                                        Transform.translate(
                                                          offset: Offset(
                                                            _opponentShakeAnimation
                                                                .value,
                                                            0,
                                                          ),
                                                          child: child,
                                                        ),
                                                    child: _buildOpponentStatus(
                                                      context,
                                                      battleManager.opponent,
                                                      overlayColor,
                                                      isNarrow,
                                                      battleManager
                                                          .opponentHazards,
                                                      battleManager,
                                                      spriteKey:
                                                          _opponentSpriteKey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  AnimatedBuilder(
                                                    animation:
                                                        _playerShakeAnimation,
                                                    builder: (context, child) =>
                                                        Transform.translate(
                                                          offset: Offset(
                                                            _playerShakeAnimation
                                                                .value,
                                                            0,
                                                          ),
                                                          child: child,
                                                        ),
                                                    child: _buildPlayerStatus(
                                                      context,
                                                      battleManager.player,
                                                      overlayColor,
                                                      isNarrow,
                                                      battleManager
                                                          .playerHazards,
                                                      battleManager,
                                                      spriteKey:
                                                          _playerSpriteKey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // UI Panel - Expanded to fill remaining space (the "red spot")
                              Expanded(
                                child: SafeArea(
                                  top: false,
                                  child: Container(
                                    color: const Color.fromARGB(255, 255, 0, 0)
                                        .withValues(
                                          alpha: 0.0,
                                        ), //criminal background
                                    child: Column(
                                      children: [
                                        // Text log — Expanded to fill available space
                                        Expanded(
                                          child: _buildMessageBox(
                                            context,
                                            battleManager.battleLog,
                                            isNarrow,
                                            expanded: true,
                                          ),
                                        ),

                                        // Move controls — only during input
                                        if (battleManager.currentState ==
                                            BattleState.waitingForInput)
                                          _buildActionControls(
                                            context,
                                            battleManager,
                                            overlayColor,
                                            isNarrow,
                                            userState,
                                          ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Animations clipped to battle field only
                ..._moveAnims.map(
                  (anim) => anims.MoveAnimationOverlay(
                    key: ValueKey(anim.id),
                    data: anim,
                    player1Link: _playerLink,
                    player2Link: LayerLink(),
                    opponent1Link: _opponentLink,
                    opponent2Link: LayerLink(),
                  ),
                ),
                // Stat Change Indicators
                ..._indicators.map((indicator) {
                  return _FloatingIndicatorWidget(
                    key: ValueKey(indicator.id),
                    data: indicator,
                    link: indicator.isPlayer ? _playerLink : _opponentLink,
                  );
                }),
                // Ability Pop-up Overlay
                if (battleManager.currentAbilityNotify != null)
                  _AbilityPopUp(
                    notification: battleManager.currentAbilityNotify!,
                    themeColor: _getBiomeThemeColor(),
                    link: battleManager.currentAbilityNotify!.isPlayer
                        ? _playerLink
                        : _opponentLink,
                  ),
                if (_animatingCardId != null)
                  _CardPlayOverlay(
                    key: ValueKey(_animatingCardId!),
                    cardId: _animatingCardId!,
                    isPlayer: _animatingCardIsPlayer,
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
                // Gimmick Banner Overlay
                if (_showGimmickBanner)
                  _GimmickBanner(
                    type: _activeGimmickType ?? 'gimmick',
                    targetName: _gimmickTarget?.name ?? '',
                    color: _activeGimmickType == 'titanize'
                        ? Colors.redAccent
                        : (_gimmickTarget?.activeTeraType ??
                                  ElementalType.basic)
                              .color,
                  ),
              ],
            ),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      battleManager.trainerInfo != null
                          ? 'VS ${battleManager.trainerInfo!.displayName}'
                          : (widget.battleTitle ?? 'Wild Encounter'),
                      style: AppTextStyles.headline(
                        context,
                        baseSize: 12,
                        color: _getBiomeThemeColor(),
                      ),
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
                        color: Colors.blue.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(16),
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
                icon: Image.asset(
                  'assets/icon/map_tools.png',
                  width: 24,
                  height: 24,
                ),
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
                icon: Image.asset(
                  'assets/icon/animal_dex.png',
                  width: 24,
                  height: 24,
                ),
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
        bm.playerSafeguardTurns > 0 ||
        bm.playerAuroraVeilTurns > 0;

    final hasOpponentSide =
        bm.opponentTailwindTurns > 0 ||
        bm.opponentReflectTurns > 0 ||
        bm.opponentLightScreenTurns > 0 ||
        bm.opponentSafeguardTurns > 0 ||
        bm.opponentAuroraVeilTurns > 0;

    if (!hasGlobal && !hasPlayerSide && !hasOpponentSide) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: hasPlayerSide
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (bm.playerTailwindTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/tailwind.png',
                          turns: bm.playerTailwindTurns,
                          outlineColor: Colors.greenAccent,
                          tooltip: 'ALLY TAILWIND',
                        ),
                      if (bm.playerReflectTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/reflect.png',
                          turns: bm.playerReflectTurns,
                          outlineColor: Colors.greenAccent,
                          tooltip: 'ALLY REFLECT',
                        ),
                      if (bm.playerLightScreenTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/light_screen.png',
                          turns: bm.playerLightScreenTurns,
                          outlineColor: Colors.greenAccent,
                          tooltip: 'ALLY LIGHT SCREEN',
                        ),
                      if (bm.playerSafeguardTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/safeguard.png',
                          turns: bm.playerSafeguardTurns,
                          outlineColor: Colors.greenAccent,
                          tooltip: 'ALLY SAFEGUARD',
                        ),
                      if (bm.playerAuroraVeilTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/aurora_veil.png',
                          turns: bm.playerAuroraVeilTurns,
                          outlineColor: Colors.greenAccent,
                          tooltip: 'ALLY AURORA VEIL',
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          if (hasGlobal) ...[
            if (hasPlayerSide)
              Container(
                width: 1,
                height: 32,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (bm.currentWeather.weather != Weather.none)
                  _buildWeatherIndicator(
                    bm.currentWeather.weather,
                    bm.weatherTurnsLeft,
                  ),
                if (bm.currentTerrain.terrain != Terrain.none)
                  _buildTerrainIndicator(
                    bm.currentTerrain.terrain,
                    bm.terrainTurnsLeft,
                  ),
                if (bm.trickRoomTurns > 0)
                  _buildFieldEffectIcon(
                    iconPath: 'assets/icon/trick_room.png',
                    turns: bm.trickRoomTurns,
                    tooltip: 'TRICK ROOM',
                  ),
              ],
            ),
            if (hasOpponentSide)
              Container(
                width: 1,
                height: 32,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
          ] else if (hasPlayerSide && hasOpponentSide) ...[
            Container(
              width: 1,
              height: 32,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ],
          Expanded(
            child: hasOpponentSide
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (bm.opponentTailwindTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/tailwind.png',
                          turns: bm.opponentTailwindTurns,
                          outlineColor: Colors.redAccent,
                          tooltip: 'FOE TAILWIND',
                        ),
                      if (bm.opponentReflectTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/reflect.png',
                          turns: bm.opponentReflectTurns,
                          outlineColor: Colors.redAccent,
                          tooltip: 'FOE REFLECT',
                        ),
                      if (bm.opponentLightScreenTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/light_screen.png',
                          turns: bm.opponentLightScreenTurns,
                          outlineColor: Colors.redAccent,
                          tooltip: 'FOE LIGHT SCREEN',
                        ),
                      if (bm.opponentSafeguardTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/safeguard.png',
                          turns: bm.opponentSafeguardTurns,
                          outlineColor: Colors.redAccent,
                          tooltip: 'FOE SAFEGUARD',
                        ),
                      if (bm.opponentAuroraVeilTurns > 0)
                        _buildFieldEffectIcon(
                          iconPath: 'assets/icon/aurora_veil.png',
                          turns: bm.opponentAuroraVeilTurns,
                          outlineColor: Colors.redAccent,
                          tooltip: 'FOE AURORA VEIL',
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldEffectIcon({
    required String iconPath,
    required int turns,
    Color? outlineColor,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: outlineColor != null
                  ? Border.all(color: outlineColor, width: 2)
                  : Border.all(color: Colors.white24, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                iconPath,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          if (turns > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Text(
                  '$turns',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherIndicator(Weather weather, int turns) {
    if (weather == Weather.clear || weather == Weather.none) {
      return const SizedBox.shrink();
    }
    return _buildFieldEffectIcon(
      iconPath: weather.iconPath,
      turns: turns,
      tooltip: weather.name.toUpperCase(),
    );
  }

  Widget _buildTerrainIndicator(Terrain terrain, int turns) {
    if (terrain == Terrain.none) return const SizedBox.shrink();
    return _buildFieldEffectIcon(
      iconPath: terrain.iconPath,
      turns: turns,
      tooltip: terrain.name.toUpperCase(),
    );
  }

  Widget _buildOpponentTeamIndicator(BuildContext context, BattleManager bm) {
    if (!widget.isArenaBattle || bm.opponentTeam.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'OPP: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 6,
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
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorColor,
                  border: Border.all(
                    color: isCurrent ? Colors.white : Colors.white24,
                    width: isCurrent ? 1.5 : 0.5,
                  ),
                ),
                child: animal.currentHealth <= 0
                    ? const Icon(Icons.close, size: 6, color: Colors.white54)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlayerTeamIndicator(BuildContext context, BattleManager bm) {
    if (!widget.isArenaBattle || bm.playerTeam.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            'YOU: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 6,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(width: 4),
          ...List.generate(bm.playerTeam.length, (index) {
            final animal = bm.playerTeam[index];
            final isCurrent = index == bm.currentPlayerIndex;
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
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorColor,
                  border: Border.all(
                    color: isCurrent ? Colors.white : Colors.white24,
                    width: isCurrent ? 1.5 : 0.5,
                  ),
                ),
                child: animal.currentHealth <= 0
                    ? const Icon(Icons.close, size: 6, color: Colors.white54)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  // Removed _buildTeamIndicators — logic moved to status bars

  Widget _buildTypeIconColumn(
    List<ElementalType> types,
    BattleState currentState,
  ) {
    if (currentState == BattleState.choosingLead) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: types
          .map(
            (type) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10, width: 1.5),
                ),
                child: Tooltip(
                  message: type.name.toUpperCase(),
                  child: Image.asset(
                    type.iconPath,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.help_outline, color: type.color, size: 16),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildOpponentStatus(
    BuildContext context,
    BattleOrganism organism,
    Color barColor,
    bool isNarrow,
    List<String> hazards, // Added
    BattleManager bm, { // Added
    Key? spriteKey,
  }) {
    final displayLevel = widget.isArenaBattle ? 50 : organism.organism.level;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // Responsive: use fraction of screen for sprite size
    final screenW = MediaQuery.sizeOf(context).width;
    final spriteSize = isLandscape
        ? (isNarrow ? 80.0 : (screenW * 0.12).clamp(90.0, 120.0))
        : (isNarrow ? 110.0 : (screenW * 0.32).clamp(120.0, 160.0));

    final statusBox = Container(
      width: (MediaQuery.sizeOf(context).width * 0.45).clamp(150.0, 240.0),
      padding: EdgeInsets.all(isNarrow ? 5 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
              bm.currentState == BattleState.choosingLead &&
                      widget.isArenaBattle
                  ? '??? LV.??'
                  : '${organism.organism.displayName} LV.$displayLevel',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isNarrow ? 10 : 12,
                fontFamily: 'PressStart2P',
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(height: 4),
          // Team Preview Circles for Opponent
          _buildOpponentTeamIndicator(context, bm),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bm.currentState == BattleState.choosingLead &&
                      widget.isArenaBattle
                  ? 'HP: ???/??? (??.?%)'
                  : 'HP: ${organism.health.round()}/${organism.maxHealth} (${(hpRatio * 100).toStringAsFixed(1)}%)',
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
                            borderRadius: BorderRadius.circular(16),
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
          if (bm.opponentAnimalSent)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      _isDetailsSheetOpen = true;
                      await BattleDetailsSheet.show(context, organism, false);
                      _isDetailsSheetOpen = false;
                    },
                    child: statusBox,
                  ),
                  const SizedBox(width: 4),
                  _buildTypeIconColumn(organism.types, bm.currentState),
                ],
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 4),
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
              child: BattleSprite(
                key: spriteKey,
                organism: organism,
                size: spriteSize,
                hideAnimal:
                    (bm.currentState == BattleState.choosingLead &&
                        widget.isArenaBattle) ||
                    (bm.result == BattleResult.capture && !bm.isCapturing) ||
                    _moveAnims.any(
                      (anim) =>
                          anim.move.name.toLowerCase() == 'brave bird' &&
                          !anim.isPlayerAttacking,
                    ),
                onTap: () async {
                  _isDetailsSheetOpen = true;
                  await BattleDetailsSheet.show(context, organism, false);
                  _isDetailsSheetOpen = false;
                },
                mirror: false, // Mirrored from previous State
                biomeName: widget.biomeName,
                hazards: hazards,
                encounterTileId: widget.encounterTileId,
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
    List<String> hazards,
    BattleManager bm, {
    Key? spriteKey,
  }) {
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // Responsive: use fraction of screen for sprite size
    final screenW = MediaQuery.sizeOf(context).width;
    final spriteSize = isLandscape
        ? (isNarrow ? 90.0 : (screenW * 0.14).clamp(100.0, 130.0))
        : (isNarrow ? 120.0 : (screenW * 0.35).clamp(130.0, 170.0));

    final displayLevel = widget.isArenaBattle ? 50 : organism.organism.level;

    final statusBox = Container(
      width: (MediaQuery.sizeOf(context).width * 0.45).clamp(150.0, 240.0),
      padding: EdgeInsets.all(isNarrow ? 5 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
              bm.currentState == BattleState.choosingLead &&
                      widget.isArenaBattle
                  ? '??? LV.??'
                  : '${organism.organism.displayName} LV.$displayLevel',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isNarrow ? 10 : 12,
                fontFamily: 'PressStart2P',
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(height: 4),
          // Team Preview Circles for Player
          _buildPlayerTeamIndicator(context, bm),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bm.currentState == BattleState.choosingLead &&
                      widget.isArenaBattle
                  ? 'HP: ???/??? (??.?%)'
                  : 'HP: ${organism.health.round()}/${organism.maxHealth} (${(hpRatio * 100).toStringAsFixed(1)}%)',
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
                            borderRadius: BorderRadius.circular(16),
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
              child: BattleSprite(
                key: spriteKey,
                organism: organism,
                size: spriteSize,
                hideAnimal:
                    (bm.currentState == BattleState.choosingLead &&
                        widget.isArenaBattle) ||
                    _moveAnims.any(
                      (anim) =>
                          anim.move.name.toLowerCase() == 'brave bird' &&
                          anim.isPlayerAttacking,
                    ),
                onTap: () async {
                  _isDetailsSheetOpen = true;
                  await BattleDetailsSheet.show(context, organism, true);
                  _isDetailsSheetOpen = false;
                },
                mirror: true,
                biomeName: widget.biomeName,
                hazards: hazards,
                encounterTileId: widget.encounterTileId,
              ),
            ),
          ),
          if (bm.playerAnimalSent)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTypeIconColumn(organism.types, bm.currentState),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      _isDetailsSheetOpen = true;
                      await BattleDetailsSheet.show(context, organism, true);
                      _isDetailsSheetOpen = false;
                    },
                    child: statusBox,
                  ),
                ],
              ),
            )
          else
            const Spacer(),
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
    final battleManager = Provider.of<BattleManager>(context);
    final showCursor = battleManager.isWaitingForDialogueClick;

    Color textColor = Colors.white;
    if (battleManager.isTrainerBattle && battleManager.trainerInfo != null) {
      if (message.startsWith(battleManager.trainerInfo!.displayName)) {
        textColor = battleManager.trainerInfo!.gender == 'female'
            ? Colors.pinkAccent
            : Colors.blueAccent;
      }
    }

    return GestureDetector(
      onTap: () {
        if (battleManager.isWaitingForDialogueClick) {
          battleManager.advanceDialogue();
        } else {
          _showBattleLog(context, battleManager);
        }
      },
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
            color: const Color.fromARGB(
              255,
              0,
              0,
              0,
            ).withValues(alpha: 0.5), //foregound of box
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFastMode
                  ? Colors.yellowAccent
                  : _getBiomeThemeColor(), // yellow outline
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(
                  255,
                  0,
                  0,
                  0,
                ).withValues(alpha: 0.5), // shadow of foreground
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
                      speed: Duration(milliseconds: _isFastMode ? 5 : 20),
                      style: TextStyle(
                        color: textColor,
                        fontSize: isNarrow ? 10 : 12,
                        fontFamily: 'PressStart2P',
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              if (showCursor) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _TypewriterCursor(color: _getBiomeThemeColor()),
                ),
              ],
            ],
          ),
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
              bm.getDisplayType(bm.player, move).color,
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
                  borderRadius: BorderRadius.circular(16),
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
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.5,
            ), // action panel box shadow
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'What will ${battleManager.player.organism.displayName} do?',
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
                    borderRadius: BorderRadius.circular(16),
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
                          color: Colors.white.withValues(alpha: 0.5),
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
                  ? 2.2
                  : (MediaQuery.of(context).orientation == Orientation.landscape
                        ? 2.8
                        : 2.6),
              children:
                  (battleManager.getValidMoves(battleManager.player).isEmpty
                          ? [Move.findOrCreate('Struggle')]
                          : battleManager.playerMoves)
                      .map((move) {
                        final displayType = battleManager.getDisplayType(
                          battleManager.player,
                          move,
                        );
                        final typeColor = displayType.color;
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
                                    ? Colors.grey.withValues(alpha: 0.2)
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
                          child: Row(
                            children: [
                              // Type Icon Section
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white10,
                                    width: 1,
                                  ),
                                ),
                                child: Image.asset(
                                  displayType.iconPath,
                                  width: 32,
                                  height: 32,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Details Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Row 1: Move Name
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        move.name,
                                        style: TextStyle(
                                          fontSize: isNarrow ? 9 : 11,
                                          fontFamily: 'PressStart2P',
                                          fontWeight: FontWeight.bold,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black,
                                              offset: Offset(-1, -1),
                                            ),
                                            Shadow(
                                              color: Colors.black,
                                              offset: Offset(1, -1),
                                            ),
                                            Shadow(
                                              color: Colors.black,
                                              offset: Offset(1, 1),
                                            ),
                                            Shadow(
                                              color: Colors.black,
                                              offset: Offset(-1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Row 2: Category Badge & Stamina
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Category Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: move.category.color,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            categoryText.substring(0, 4),
                                            style: const TextStyle(
                                              fontSize: 6,
                                              fontFamily: 'PressStart2P',
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(-1, -1),
                                                ),
                                                Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(1, -1),
                                                ),
                                                Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(1, 1),
                                                ),
                                                Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(-1, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // PP Display
                                        Text(
                                          '${battleManager.playerOrganism.moveStamina[move.name] ?? 0}/${move.stamina}',
                                          style: TextStyle(
                                            fontSize: isNarrow ? 7 : 8,
                                            fontFamily: 'PressStart2P',
                                            color:
                                                ((battleManager
                                                            .playerOrganism
                                                            .moveStamina[move
                                                            .name] ??
                                                        0) >
                                                    0)
                                                ? Colors.white
                                                : Colors.redAccent,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black,
                                                offset: Offset(-1, -1),
                                              ),
                                              Shadow(
                                                color: Colors.black,
                                                offset: Offset(1, -1),
                                              ),
                                              Shadow(
                                                color: Colors.black,
                                                offset: Offset(1, 1),
                                              ),
                                              Shadow(
                                                color: Colors.black,
                                                offset: Offset(-1, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Row 3: Effectiveness (if applicable)
                                    if (move.category != MoveCategory.status &&
                                        effectivenessText.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (effectivenessText
                                                      .toLowerCase()
                                                      .contains('super'))
                                                  ? Colors.yellow.shade800
                                                  : Colors.grey.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: Border.all(
                                                color: Colors.white24,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              effectivenessText.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 6,
                                                fontFamily: 'PressStart2P',
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black,
                                                    offset: Offset(-1, -1),
                                                  ),
                                                  Shadow(
                                                    color: Colors.black,
                                                    offset: Offset(1, -1),
                                                  ),
                                                  Shadow(
                                                    color: Colors.black,
                                                    offset: Offset(1, 1),
                                                  ),
                                                  Shadow(
                                                    color: Colors.black,
                                                    offset: Offset(-1, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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

              // Team-wide usage
              final teamPrismorphUsed = bm.playerPrismorphUsed;

              // Participant-specific usage
              final participantPrismorphed = p.hasPrismorphedThisBattle;

              // Capability checks
              final isCapableOfPrismorph = p.organism.teraType != null;

              // Enablement logic
              final canEnablePrismorph =
                  !teamPrismorphUsed &&
                  !participantPrismorphed &&
                  isCapableOfPrismorph &&
                  !bm.isProcessing;

              return Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    if (isCapableOfPrismorph)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Image.asset(
                            p.organism.teraType!.iconPath,
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          label: Text(
                            p.isPrismorphed
                                ? 'PRISMORPHED [${p.organism.teraType?.name.toUpperCase() ?? '?'}]'
                                : (teamPrismorphUsed
                                      ? 'PRISMORPH USED'
                                      : 'PRISMORPH'),
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: isNarrow ? 6 : 8,
                            ),
                          ),
                          onPressed: canEnablePrismorph
                              ? () => bm.activatePrismorph(isPlayer: true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                p.isPrismorphed || teamPrismorphUsed
                                ? Colors.grey[800]
                                : p.organism.teraType!.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: canEnablePrismorph ? 8 : 0,
                            shadowColor: p.organism.teraType?.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: canEnablePrismorph
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.white10,
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
                    icon: Image.asset(
                      'assets/icon/bio_scanner.png',
                      width: isNarrow ? 14 : 18,
                      height: isNarrow ? 14 : 18,
                      color: isTurnLocked ? Colors.white24 : Colors.white,
                    ),
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
                    icon: Image.asset(
                      'assets/icon/animal_box.png',
                      width: isNarrow ? 14 : 18,
                      height: isNarrow ? 14 : 18,
                      color: isTurnLocked ? Colors.white24 : Colors.white,
                    ),
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
                  icon: Image.asset(
                    'assets/icon/speed.png',
                    width: isNarrow ? 14 : 18,
                    height: isNarrow ? 14 : 18,
                    color: isTurnLocked ? Colors.white24 : Colors.white,
                  ),
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
                  onPressed: (isTurnLocked ||
                          battleManager.playerUsedCardThisBattle ||
                          battleManager.playerEquippedCard == null)
                      ? null
                      : () {
                          battleManager.processPlayerCard(
                              battleManager.playerEquippedCard!);
                        },
                  icon: Icon(
                    Icons.style,
                    size: isNarrow ? 12 : 14,
                    color: (isTurnLocked ||
                            battleManager.playerUsedCardThisBattle ||
                            battleManager.playerEquippedCard == null)
                        ? Colors.white24
                        : Colors.white,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      battleManager.playerUsedCardThisBattle
                          ? 'Card Used'
                          : (battleManager.playerEquippedCard == null
                              ? 'No Card'
                              : 'Play Card'),
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isTurnLocked ||
                            battleManager.playerUsedCardThisBattle ||
                            battleManager.playerEquippedCard == null)
                        ? Colors.grey[700]
                        : Colors.purple.shade700,
                    foregroundColor: (isTurnLocked ||
                            battleManager.playerUsedCardThisBattle ||
                            battleManager.playerEquippedCard == null)
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
                      : (widget.isArenaBattle ||
                            widget.isRogueMode ||
                            widget.isTrainerBattle)
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
                    (widget.isArenaBattle ||
                            widget.isRogueMode ||
                            widget.isTrainerBattle)
                        ? Icons.flag
                        : Icons.directions_run,
                    size: isNarrow ? 14 : 18,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      (widget.isArenaBattle ||
                              widget.isRogueMode ||
                              widget.isTrainerBattle)
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
                  errorBuilder: (_, _, _) =>
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

    // Start fading out the battle music
    AudioService.instance.fadeOutMusic(
      duration: const Duration(milliseconds: 2000),
    );

    // Add delay to allow reading the final log message (shorter for fleeing)
    final delayMs = battleManager.result == BattleResult.fled ? 1000 : 2500;
    Future.delayed(Duration(milliseconds: delayMs), () async {
      try {
        if (!mounted) {
          _isHandlingBattleEnd = false;
          return;
        }

        int moneyEarned = 0;

        // Handle capture - add organism to collection
        if (battleManager.result == BattleResult.capture) {
          final newCapturedInstance = battleManager.opponent.organism;

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

        // Fainting animations for health 0 organisms
        if (battleManager.opponent.organism.currentHealth <= 0) {
          await _opponentSpriteKey.currentState?.faint();
        }
        if (battleManager.player.organism.currentHealth <= 0) {
          await _playerSpriteKey.currentState?.faint();
        }

        // Death mechanic removed — animals are no longer permanently lost after battle

        // Rogue-like specific progression
        if (widget.isRogueMode) {
          if (battleManager.result == BattleResult.win ||
              battleManager.result == BattleResult.capture) {
            // Perma-death removed in Rogue Mode as well
            final survivingTeam = List<CapturedOrganism>.from(
              userState.currentUser?.rogueLikeState.team ?? [],
            );

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

        // Record the post-battle state (HP, Stamina, Status) to persistence.
        // This ensures damage persists even if subsequent UserState operations reload from disk.
        if (!widget.isRogueMode && widget.shouldPersistResults) {
          await userState.updateTeamAfterBattle(battleManager.playerTeam);
        }

        // Arena battle prize money (not for rogue mode usually, or different rewards)
        Map<String, dynamic> xpResults =
            _cumulativeXPResults; // Use cumulative results
        if (!widget.isRogueMode) {
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

        final Map<String, int> droppedLoot = battleManager.droppedLoot;

        // Handle loot drop
        if (battleManager.result == BattleResult.win &&
            droppedLoot.isNotEmpty) {
          for (final entry in droppedLoot.entries) {
            final isCard = BattleCard.findById(entry.key) != null;
            if (isCard) {
              for (int i = 0; i < entry.value; i++) {
                await userState.addCardOrFragment(entry.key);
              }
            } else {
              await userState.addLoot(entry.key, entry.value);
            }
          }
        }

        if (!mounted) return;

        // Record match results for winrate system (for all decisive outcomes)
        final decisiveResult = battleManager.result;
        if (decisiveResult == BattleResult.win ||
            decisiveResult == BattleResult.capture ||
            decisiveResult == BattleResult.loss) {
          // --- Participation Filter ---
          // Only count animals that actual dealt OR took damage in the battle.
          final bStats = battleManager.battleStats;

          final playerSpeciesStats = <String, Map<String, int>>{};
          for (final org in battleManager.playerTeam) {
            final s = bStats[org.id];
            if (s != null &&
                (s.totalDamageDealt > 0 || s.totalDamageTaken > 0)) {
              final name = org.baseOrganism.name;
              final existing = playerSpeciesStats[name] ?? {};
              playerSpeciesStats[name] = {
                'damageDealt':
                    (existing['damageDealt'] ?? 0) + s.totalDamageDealt,
                'damageTaken':
                    (existing['damageTaken'] ?? 0) + s.totalDamageTaken,
                'kills': (existing['kills'] ?? 0) + s.totalKills,
              };
            }
          }

          final opponentSpeciesStats = <String, Map<String, int>>{};
          // Arena / Rogue: opponentFullTeam may be available
          final allOpponents =
              widget.opponentFullTeam ?? [battleManager.opponentOrganism];
          for (final org in allOpponents) {
            final s = bStats[org.id];
            if (s != null &&
                (s.totalDamageDealt > 0 || s.totalDamageTaken > 0)) {
              final name = org.baseOrganism.name;
              final existing = opponentSpeciesStats[name] ?? {};
              opponentSpeciesStats[name] = {
                'damageDealt':
                    (existing['damageDealt'] ?? 0) + s.totalDamageDealt,
                'damageTaken':
                    (existing['damageTaken'] ?? 0) + s.totalDamageTaken,
                'kills': (existing['kills'] ?? 0) + s.totalKills,
              };
            }
          }

          // If nothing was in bStats (e.g. very short fight), fall back to lead
          if (playerSpeciesStats.isEmpty) {
            playerSpeciesStats[battleManager
                .player
                .organism
                .baseOrganism
                .name] = {
              'damageDealt': 0,
              'damageTaken': 0,
              'kills': 0,
            };
          }
          if (opponentSpeciesStats.isEmpty) {
            opponentSpeciesStats[battleManager
                .opponent
                .organism
                .baseOrganism
                .name] = {
              'damageDealt': 0,
              'damageTaken': 0,
              'kills': 0,
            };
          }

          final playerWon = decisiveResult != BattleResult.loss;
          unawaited(
            userState.recordMatchResults(
              playerSpeciesStats: playerSpeciesStats,
              opponentSpeciesStats: opponentSpeciesStats,
              playerWon: playerWon,
            ),
          );
        }

        // Show result dialog
        if (!context.mounted) return;
        if (_pendingRogueCapture != null &&
            battleManager.result != BattleResult.loss) {
          _showCaptureReplaceDialog(context, _pendingRogueCapture!, userState);
        } else {
          _showBattleResultDialog(
            context,
            battleManager,
            moneyEarned,
            userState,
            xpResults: xpResults,
          );
        }
        _isHandlingBattleEnd = false; // Reset here
      } catch (e) {
        debugPrint('Error during battle end handling: $e');
        if (context.mounted) {
          _showBattleResultDialog(context, battleManager, 0, userState);
        }
        _isHandlingBattleEnd = false; // Reset here
      } finally {
        // Handled inside the async block
      }
    });
  }

  void _showBattleResultDialog(
    BuildContext context,
    BattleManager battleManager,
    int moneyEarned,
    UserState userState, {
    Map<String, dynamic> xpResults = const {},
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChangeNotifierProvider<BattleManager>.value(
        value: battleManager,
        child: _BattleResultDialog(
          battleManager: battleManager,
          result: battleManager.result!,
          opponentName: battleManager.opponent.organism.baseOrganism.name,
          playerName: battleManager.player.organism.baseOrganism.name,
          moneyEarned: moneyEarned,
          themeColor: _getBiomeThemeColor(),
          primaryColor: _getBiomePrimaryColor(),
          secondaryColor: _getBiomeSecondaryColor(),
          xpResults: xpResults,
          isRogueMode: widget.isRogueMode,
          rogueFloor: userState.currentUser?.rogueLikeState.floor,
          onConfirm: () async {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
            Navigator.of(ctx).pop();

            // FIX: If the animal details sheet is still open, pop it as well
            // so we don't get stuck on the BattleScreen beneath it.
            if (_isDetailsSheetOpen) {
              Navigator.of(context).pop();
            }

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
                  MaterialPageRoute(
                    builder: (ctx) => const BiomeSelectScreen(),
                  ),
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

          if (context.mounted) {
            // Show result dialog after replacement
            _showBattleResultDialog(
              context,
              Provider.of<BattleManager>(context, listen: false),
              0, // No money in rogue
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
          if (context.mounted) {
            // Show result dialog after discard
            _showBattleResultDialog(
              context,
              Provider.of<BattleManager>(context, listen: false),
              0,
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
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10, width: 1.5),
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
            ...nets.map(
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
                      borderRadius: BorderRadius.circular(16),
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
            ),
          ],
        ),
      ),
    );
  }

  void _showCardSelectionDialog(
    BuildContext context,
    BattleManager bm,
    UserState userState,
  ) {
    final unlockedCardIds = userState.currentUser?.unlockedCards ?? [];
    final unlockedCards = unlockedCardIds
        .map((id) => BattleCard.findById(id))
        .where((c) => c != null)
        .cast<BattleCard>()
        .toList();
    // No longer using screenWidth or isNarrow

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117), // sleek dark background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'BATTLE CARDS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: Colors.purple.shade300,
                  shadows: const [
                    Shadow(color: Colors.purpleAccent, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (unlockedCards.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No Battle Cards unlocked!\nDefeat animals or explore biomes to find them.',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: Colors.grey[400],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: unlockedCards.length,
                    itemBuilder: (context, index) {
                      final card = unlockedCards[index];

                      // Check requirements
                      bool hasOrganism = true;
                      if (card.requiredOrganism != null) {
                        hasOrganism = bm.playerTeam.any(
                          (co) => co.baseOrganism.name == card.requiredOrganism,
                        );
                      }

                      bool hasFamily = true;
                      if (card.requiredFamily != null) {
                        hasFamily = bm.playerTeam.any(
                          (co) => co.baseOrganism.family == card.requiredFamily,
                        );
                      }

                      bool isCorrectBiome = true;
                      if (card.requiredBiomes.isNotEmpty) {
                        isCorrectBiome = card.requiredBiomes.any(
                          (b) => (bm.biomeName ?? '').toLowerCase().contains(
                            b.toLowerCase(),
                          ),
                        );
                      }

                      final bool isEligible =
                          hasOrganism && hasFamily && isCorrectBiome;

                      return Card(
                        color: isEligible
                            ? const Color(0xFF161B22)
                            : const Color(0xFF0F141C),
                        elevation: isEligible ? 4 : 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isEligible
                                ? Colors.purple.withValues(alpha: 0.4)
                                : Colors.white10,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Image.asset(
                                      card.imagePath,
                                      errorBuilder: (ctx, err, stack) =>
                                          const Icon(
                                            Icons.style,
                                            color: Colors.purple,
                                            size: 24,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.name,
                                          style: TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 10,
                                            color: isEligible
                                                ? Colors.white
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          card.description,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isEligible
                                                ? Colors.grey[300]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              const SizedBox(height: 4),
                              // Requirements listing
                              if (card.requiredOrganism != null)
                                _buildRequirementRow(
                                  label:
                                      'Required Party Animal: ${card.requiredOrganism}',
                                  met: hasOrganism,
                                ),
                              if (card.requiredFamily != null)
                                _buildRequirementRow(
                                  label:
                                      'Required Family: ${card.requiredFamily}',
                                  met: hasFamily,
                                ),
                              if (card.requiredBiomes.isNotEmpty)
                                _buildRequirementRow(
                                  label:
                                      'Required Biome: ${card.requiredBiomes.join(", ")}',
                                  met: isCorrectBiome,
                                ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isEligible
                                      ? () {
                                          Navigator.pop(ctx);
                                          bm.processPlayerCard(card.id);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple[700],
                                    disabledBackgroundColor: Colors.grey[800],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    isEligible
                                        ? 'PLAY CARD'
                                        : 'REQUIREMENTS NOT MET',
                                    style: const TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildRequirementRow({required String label, required bool met}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.error_outline,
            color: met ? Colors.green : Colors.red,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: met ? Colors.green[300] : Colors.red[300],
              ),
            ),
          ),
        ],
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
          border: Border.all(color: Colors.black, width: 3),
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
        color: Colors.cyan.shade900.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
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
      child: BattleSprite(
        organism: BattleOrganism(org, isRogueMode: true),
        size: 40,
        biomeName: 'Jungle',
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

class _BattleResultDialog extends StatefulWidget {
  final BattleResult result;
  final String opponentName;
  final String playerName;
  final int moneyEarned;
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
    required this.onConfirm,
    required this.themeColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.battleManager,
    this.xpResults = const {},
    this.rogueFloor,
    required this.isRogueMode,
  });

  @override
  State<_BattleResultDialog> createState() => _BattleResultDialogState();
}

class _BattleResultDialogState extends State<_BattleResultDialog> {
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    final isVictory =
        widget.result == BattleResult.win ||
        widget.result == BattleResult.capture;
    if (isVictory) {
      AudioService.instance.playSound('audio/victory.mp3');
    } else {
      AudioService.instance.playSound('audio/defeat.mp3');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVictory =
        widget.result == BattleResult.win ||
        widget.result == BattleResult.capture;
    final mvpData = _calculateMvp();
    final mvpOrg = mvpData['organism'] as CapturedOrganism?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isVictory
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.redAccent.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isVictory ? Colors.amber : Colors.redAccent).withValues(
                alpha: 0.2,
              ),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isVictory),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (mvpOrg != null) ...[
                        _buildMvpSection(mvpOrg, mvpData['score'] as double),
                        const SizedBox(height: 20),
                      ],
                      _buildRewardsAndXpGrid(context),
                      const SizedBox(height: 20),
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isVictory) {
    String headerText;
    String subText;
    switch (widget.result) {
      case BattleResult.win:
        headerText = 'VICTORY';
        subText = 'BATTLE CONCLUDED';
        break;
      case BattleResult.capture:
        headerText = 'CAPTURED';
        subText = 'NEW COMPANION JOINED';
        break;
      case BattleResult.fled:
        headerText = 'FLED';
        subText = 'RETREATED SAFELY';
        break;
      case BattleResult.loss:
        headerText = 'DEFEAT';
        subText = 'STRATEGIZE AND RETURN';
        break;
    }

    final headerColor = isVictory
        ? Colors.amber
        : (widget.result == BattleResult.fled ? Colors.grey : Colors.redAccent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [headerColor.withValues(alpha: 0.3), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Text(
            headerText,
            style: GoogleFonts.orbitron(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: headerColor,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: headerColor.withValues(alpha: 0.5),
                  blurRadius: 15,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: const TextStyle(
              color: Colors.white54,
              fontFamily: 'PressStart2P',
              fontSize: 8,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMvpSection(CapturedOrganism org, double score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'MVP',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'SCORE: ${score.toInt()}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSmallSprite(org),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.baseOrganism.name.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LVL ${org.level} ${org.baseOrganism.rarity.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                      ),
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

  Widget _buildRewardsAndXpGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.xpResults.isNotEmpty) ...[
          const Text(
            'EXPERIENCE GAINED',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'PressStart2P',
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.battleManager.playerTeam
              .take(3)
              .map((org) => _buildXpProgressRow(org)),
          if (widget.battleManager.playerTeam.length > 3)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '...and others',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
        _buildRewardSection(),
      ],
    );
  }

  Widget _buildXpProgressRow(CapturedOrganism org) {
    return _XPResultRow(
      organism: org,
      gainedXP: (widget.xpResults['gainedAnimalXP'] as int? ?? 0),
      didLevelUp:
          (widget.xpResults['animalLeveledUp']
              as Map<String, bool>?)?[org.id] ??
          false,
    );
  }

  Widget _buildRewardSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REWARDS',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'PressStart2P',
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildRewardItem(
                Icons.monetization_on,
                '${widget.moneyEarned}',
                Colors.amber,
              ),
            ],
          ),
          if (widget.battleManager.droppedLoot.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: widget.battleManager.droppedLoot.entries.map((entry) {
                final String dropId = entry.key;
                final int count = entry.value;
                // Find actual name, fallback to raw string
                final talisman = Talisman.findById(dropId);
                final String dropName = talisman?.name ?? dropId;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/items/${dropName.toLowerCase().replaceAll(' ', '-')}.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.inventory_2,
                          color: Colors.purpleAccent,
                          size: 20,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${dropName.toUpperCase()} x$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewardItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'PressStart2P',
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final userState = Provider.of<UserState>(context, listen: false);

    return Column(
      children: [
        // Save Replay Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSaved
                ? null
                : () async {
                    final replay = BattleReplay.fromBattle(
                      widget.battleManager,
                    );
                    await userState.saveReplay(replay);
                    setState(() {
                      _isSaved = true;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Replay saved!')),
                      );
                    }
                  },
            icon: Icon(
              _isSaved ? Icons.check_circle_rounded : Icons.save_rounded,
              size: 16,
              color: _isSaved ? Colors.greenAccent : AppColors.primary,
            ),
            label: Text(
              _isSaved ? 'REPLAY SAVED' : 'SAVE REPLAY',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: _isSaved ? Colors.greenAccent : AppColors.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _isSaved
                    ? Colors.greenAccent.withValues(alpha: 0.5)
                    : AppColors.primary.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _showStats(context),
                child: const Text(
                  'VIEW STATS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: widget.onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.result == BattleResult.win
                      ? Colors.amber
                      : Colors.white24,
                  foregroundColor: widget.result == BattleResult.win
                      ? Colors.black
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateMvp() {
    CapturedOrganism? mvpOrg;
    String mvpSide = 'PLAYER';
    double maxScore = -1;

    final allParticipants = [
      ...widget.battleManager.playerTeam,
      ...widget.battleManager.opponentTeam,
    ];

    for (final org in allParticipants) {
      final stats = widget.battleManager.battleStats[org.id];
      if (stats == null) continue;

      // Only count if the animal actually contributed/fielded
      if (stats.totalDamageDealt == 0 &&
          stats.totalDamageTaken == 0 &&
          stats.totalKills == 0) {
        continue;
      }

      double score =
          stats.totalDamageDealt.toDouble() +
          (stats.totalKills * 150.0) -
          (stats.totalDamageTaken * 0.05);

      if (score > maxScore) {
        maxScore = score;
        mvpOrg = org;
        mvpSide = widget.battleManager.playerTeam.any((o) => o.id == org.id)
            ? 'YOUR TEAM'
            : 'OPPONENT';
      }
    }

    if (mvpOrg == null && widget.battleManager.playerTeam.isNotEmpty) {
      mvpOrg = widget.battleManager.playerTeam.first;
      mvpSide = 'YOUR TEAM';
    }

    return {'organism': mvpOrg, 'side': mvpSide, 'score': maxScore};
  }

  void _showStats(BuildContext context) {
    final mvpData = _calculateMvp();
    final mvpOrg = mvpData['organism'] as CapturedOrganism?;
    final mvpSide = mvpData['side'] as String;

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F), // Deep dark theme
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: widget.themeColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'BATTLE SUMMARY',
                        style: TextStyle(
                          color: widget.themeColor,
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: widget.themeColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Performance Overview',
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mvpOrg != null) ...[
                          _buildMvpSpotlight(mvpOrg, mvpSide),
                          const SizedBox(height: 24),
                        ],
                        _buildFancierStatsSection(
                          'YOUR TEAM',
                          widget.battleManager.playerTeam,
                          isPlayer: true,
                        ),
                        const SizedBox(height: 24),
                        _buildFancierStatsSection(
                          'OPPONENT TEAM',
                          widget.battleManager.opponentTeam,
                          isPlayer: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMvpSpotlight(CapturedOrganism org, String side) {
    final stats = widget.battleManager.battleStats[org.id] ?? BattleStats();
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber,
            Colors.amber.withValues(alpha: 0.1),
            Colors.amber,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
                Image.asset(
                  'assets/sprites/${org.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.star, color: Colors.amber, size: 40),
                ),
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'MVP',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    org.name.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    side.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 7,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMiniStat(
                        Icons.flash_on,
                        '${stats.totalDamageDealt}',
                        Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      _buildMiniStat(
                        Icons.close,
                        '${stats.totalKills}',
                        Colors.cyan,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: color.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildFancierStatsSection(
    String title,
    List<CapturedOrganism> team, {
    required bool isPlayer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: isPlayer ? widget.themeColor : Colors.redAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontFamily: 'PressStart2P',
                fontSize: 10,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...team.map((org) => _buildAnimalStatCard(org)),
      ],
    );
  }

  Widget _buildAnimalStatCard(CapturedOrganism org) {
    final stats = widget.battleManager.battleStats[org.id] ?? BattleStats();
    final bool revealedMoves = stats.revealedMoves.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Image.asset(
                    'assets/sprites/${org.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.pets, color: Colors.white24, size: 24),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: org.baseOrganism.elementalTypes.map((t) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getTypeColor(t),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.baseOrganism.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildComplexStat(
                          'DEALT',
                          stats.totalDamageDealt,
                          Colors.orangeAccent,
                        ),
                        _buildComplexStat(
                          'TAKEN',
                          stats.totalDamageTaken,
                          Colors.redAccent.withValues(
                            alpha: 0.7,
                          ), // partial match careful,
                        ),
                        _buildComplexStat(
                          'KILLS',
                          stats.totalKills,
                          Colors.lightBlueAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (revealedMoves) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: stats.revealedMoves.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    m.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 6,
                      color: Colors.white60,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComplexStat(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 6,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(ElementalType type) {
    switch (type) {
      case ElementalType.blaze:
        return Colors.red;
      case ElementalType.aquatic:
        return Colors.blue;
      case ElementalType.grass:
        return Colors.green;
      case ElementalType.electric:
        return Colors.yellow;
      case ElementalType.cryo:
        return Colors.cyanAccent;
      case ElementalType.martial:
        return Colors.orange;
      case ElementalType.toxic:
        return Colors.purple;
      case ElementalType.earth:
        return Colors.brown;
      case ElementalType.flying:
        return Colors.indigoAccent;
      case ElementalType.mystic:
        return Colors.pinkAccent;
      case ElementalType.arthropod:
        return Colors.lightGreen;
      case ElementalType.rock:
        return Colors.grey;
      case ElementalType.spectral:
        return Colors.purpleAccent;
      case ElementalType.drake:
        return Colors.indigo;
      case ElementalType.darkness:
        return Colors.black87;
      case ElementalType.metal:
        return Colors.blueGrey;
      case ElementalType.aura:
        return Colors.tealAccent;
      case ElementalType.sound:
        return Colors.deepPurpleAccent;
      case ElementalType.holy:
        return Colors.amber;
      case ElementalType.basic:
        return Colors.white70;
    }
  }

  Widget _buildSmallSprite(CapturedOrganism org) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/sprites/${org.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.pets, color: Colors.white12, size: 30),
          ),
        ),
      ),
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
      CurvedAnimation(parent: _xpController, curve: Curves.easeInOutCubic),
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
                  color: Colors.white.withValues(alpha: 0.5),
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
                            color: Colors.blueAccent.withValues(alpha: 0.2),
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
              color: Colors.black.withValues(alpha: 0.5),
              border: Border.all(color: Colors.white10, width: 1.5),
              borderRadius: BorderRadius.circular(16),
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

  late Animation<double> _scaleAnimation;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _positionAnimation = Tween<Offset>(
      begin: const Offset(0, 10),
      end: const Offset(0, -80), // Float upwards further
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.5,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    ]).animate(_controller);

    _wobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 5.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 25),
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
              offset:
                  _positionAnimation.value + Offset(_wobbleAnimation.value, 0),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.data.color.withValues(alpha: 0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.data.color.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            widget.data.text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'PressStart2P',
              shadows: [
                Shadow(
                  color: widget.data.color,
                  blurRadius: 2,
                  offset: const Offset(1, 1),
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
          final double pulseAlpha = 0.5 + (_controller.value * 0.5);
          return Opacity(
            opacity: pulseAlpha,
            child: Image.asset(
              'assets/move_effects/trick_room.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          );
        },
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.4),
          width: 2,
        ),
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
                        ? primaryColor.withValues(alpha: 0.3)
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
                              color: themeColor.withValues(alpha: 0.4),
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
                            errorBuilder: (_, _, _) => const Icon(
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
                    isLeadSelection ? 'Choose your lead!' : 'Choose an animal.',
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10, width: 1.5),
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
// Special Hit Painter — projectile shapes per type
// ----------------------------------------------------------------
// ignore: unused_element
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
// ignore: unused_element
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
                          color: widget.color.withValues(alpha: 0.9),
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.type.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'PressStart2P',
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${widget.targetName}!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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

// ─── TRAINER INTRO / DIALOGUE OVERLAY ───

// Blinking cursor widget for typewriter effect
class _TypewriterCursor extends StatefulWidget {
  final Color color;
  const _TypewriterCursor({required this.color});

  @override
  State<_TypewriterCursor> createState() => _TypewriterCursorState();
}

class _TypewriterCursorState extends State<_TypewriterCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) => Opacity(
        opacity: _blinkController.value,
        child: Icon(Icons.arrow_drop_down, color: widget.color, size: 16),
      ),
    );
  }
}

class _CardPlayOverlay extends StatefulWidget {
  final String cardId;
  final bool isPlayer;

  const _CardPlayOverlay({Key? key, required this.cardId, required this.isPlayer}) : super(key: key);

  @override
  State<_CardPlayOverlay> createState() => _CardPlayOverlayState();
}

class _CardPlayOverlayState extends State<_CardPlayOverlay> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _shimmerController;

  late Animation<double> _slideX;
  late Animation<double> _rotate;
  late Animation<double> _scale;
  late Animation<double> _glow;
  late Animation<double> _burstScale;
  late Animation<double> _exitOpacity;
  late Animation<double> _bgOpacity;
  late Animation<double> _shimmer;

  BattleCard? _card;

  @override
  void initState() {
    super.initState();

    _card = BattleCard.findById(widget.cardId);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final c = _controller;

    _bgOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.75).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.75), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    ]).animate(c);

    final double startX = widget.isPlayer ? -500.0 : 500.0;
    _slideX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: startX, end: 0.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 22),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 56),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -startX * 0.6).chain(CurveTween(curve: Curves.easeInCubic)), weight: 22),
    ]).animate(c);

    _rotate = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: widget.isPlayer ? -0.15 : 0.15, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 30),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: widget.isPlayer ? 0.08 : -0.08).chain(CurveTween(curve: Curves.easeInBack)), weight: 15),
    ]).animate(c);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.08).chain(CurveTween(curve: Curves.easeOutBack)), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 46),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12).chain(CurveTween(curve: Curves.easeOut)), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4).chain(CurveTween(curve: Curves.easeInBack)), weight: 10),
    ]).animate(c);

    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4).chain(CurveTween(curve: Curves.easeInOut)), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 24),
    ]).animate(c);

    _exitOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 85),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    ]).animate(c);

    _burstScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 76),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 2.5).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 2.5, end: 3.5).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
    ]).animate(c);

    _shimmer = CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut);

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 836), () {
      if (mounted) _shimmerController.repeat();
    });
    Future.delayed(const Duration(milliseconds: 2960), () {
      if (mounted) _shimmerController.stop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Color get _themeColor => widget.isPlayer ? const Color(0xFF4FC3F7) : const Color(0xFFEF5350);
  Color get _themeColorDark => widget.isPlayer ? const Color(0xFF0288D1) : const Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _shimmerController]),
      builder: (context, _) {
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred dark scrim
              Opacity(
                opacity: _bgOpacity.value,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ),

              // Radial burst ring
              if (_burstScale.value > 0)
                Center(
                  child: Opacity(
                    opacity: (1.0 - (_burstScale.value - 0.5) / 3.0).clamp(0.0, 0.5),
                    child: Transform.scale(
                      scale: _burstScale.value,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _themeColor, width: 3),
                          boxShadow: [BoxShadow(color: _themeColor.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10)],
                        ),
                      ),
                    ),
                  ),
                ),

              // The Card
              Center(
                child: Opacity(
                  opacity: _exitOpacity.value,
                  child: Transform.translate(
                    offset: Offset(_slideX.value, 0),
                    child: Transform.rotate(
                      angle: _rotate.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: _buildCardBody(card, screenSize),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardBody(BattleCard? card, Size screenSize) {
    final cardW = (screenSize.width * 0.72).clamp(240.0, 340.0);
    final cardH = cardW * 1.42;
    final glowIntensity = _glow.value;

    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _themeColor.withValues(alpha: glowIntensity * 0.9), blurRadius: 50, spreadRadius: 8),
          BoxShadow(color: _themeColor.withValues(alpha: glowIntensity * 0.5), blurRadius: 80, spreadRadius: 20),
          BoxShadow(color: Colors.white.withValues(alpha: glowIntensity * 0.15), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0A0A1A),
                    _themeColorDark.withValues(alpha: 0.35),
                    const Color(0xFF0A0A1A),
                  ],
                ),
              ),
            ),

            // Card artwork
            Positioned(
              top: cardH * 0.12,
              left: 10,
              right: 10,
              height: cardH * 0.55,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      card?.imagePath ?? 'assets/cards/${widget.cardId}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Icon(Icons.style_rounded, color: _themeColor, size: 64),
                        ),
                      ),
                    ),
                    // Bottom vignette on image
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                        ),
                      ),
                    ),
                    // Shimmer sweep
                    Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) {
                          final sweepPos = _shimmer.value;
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                            stops: [
                              (sweepPos - 0.15).clamp(0.0, 1.0),
                              sweepPos.clamp(0.0, 1.0),
                              (sweepPos + 0.15).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        child: Container(color: Colors.white.withValues(alpha: 0.01)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top header: player tag + ACTIVATED badge
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: cardH * 0.12,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_themeColorDark, _themeColor.withValues(alpha: 0.7)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        widget.isPlayer ? 'YOUR CARD' : 'OPPONENT CARD',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '⚡ ACTIVATED',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom: name + description panel (glassmorphic)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(color: _themeColor.withValues(alpha: 0.4 * glowIntensity), width: 1.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Card name
                        Text(
                          card?.name ?? widget.cardId.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            shadows: [Shadow(color: _themeColor, blurRadius: 12 * glowIntensity)],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_themeColor.withValues(alpha: 0.8), Colors.transparent],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          card?.description ?? 'A powerful card effect activates!',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 11,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Glowing border frame
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _themeColor.withValues(alpha: glowIntensity * 0.85),
                    width: 2.0,
                  ),
                ),
              ),
            ),

            // Corner accent dots
            ...[
              const Alignment(-1, -1),
              const Alignment(1, -1),
              const Alignment(-1, 1),
              const Alignment(1, 1),
            ].map((align) => Positioned.fill(
              child: Align(
                alignment: align,
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _themeColor.withValues(alpha: glowIntensity),
                    boxShadow: [BoxShadow(color: _themeColor, blurRadius: 6)],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
