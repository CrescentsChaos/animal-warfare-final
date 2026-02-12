// lib/battle_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemChrome, DeviceOrientation;
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/loot_item.dart';
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

  const BattleScreen({
    super.key,
    required this.playerOrganism,
    required this.opponentOrganism,
    required this.biomeName,
    this.playerTeam,
    this.battleTitle,
    this.isArenaBattle = false,
    this.opponentTeam,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BattleManager(playerOrganism, opponentOrganism, biomeName: biomeName, team: playerTeam, opponentTeam: opponentTeam, isArenaBattle: isArenaBattle),
      child: BattleScreenContent(
        biomeName: biomeName,
        opponentName: opponentOrganism.baseOrganism.name,
        battleTitle: battleTitle,
        isArenaBattle: isArenaBattle,
      ),
    );
  }
}

class BattleScreenContent extends StatefulWidget {
  final String biomeName;
  final String opponentName;
  final String? battleTitle;
  final bool isArenaBattle;

  const BattleScreenContent({super.key, required this.biomeName, required this.opponentName, this.battleTitle, this.isArenaBattle = false});

  @override
  State<BattleScreenContent> createState() => _BattleScreenContentState();
}

class _BattleScreenContentState extends State<BattleScreenContent> with TickerProviderStateMixin {
  late AnimationController _playerShakeController;
  late AnimationController _opponentShakeController;
  late Animation<double> _playerShakeAnimation;
  late Animation<double> _opponentShakeAnimation;
  bool _isSwitchDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _playerShakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _opponentShakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    
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
      bm.onAttack = _onAttack;
      bm.onVictory = _onVictory;
    });
  }

  @override
  void dispose() {
    _playerShakeController.dispose();
    _opponentShakeController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onAttack(BattleOrganism attacker) {
    if (!mounted) return;
    
    final bm = Provider.of<BattleManager>(context, listen: false);
    
    if (attacker == bm.player) { // Player attacks
       _playerShakeController.forward(from: 0);
    } else { // Opponent attacks
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
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  String _getAssetPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
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
            color: AppColors.secondaryButtonColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: AppColors.highlightColor, width: 2),
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryButtonColor.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BATTLE LOG',
                      style: AppTextStyles.headline(context, baseSize: 14, color: AppColors.highlightColor),
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
                                color: AppColors.highlightColor, 
                                fontSize: 12, 
                                fontFamily: 'PressStart2P',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Log Entries for this turn (Chronological)
                        ...turn.logEntries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        )),
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
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryButtonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.highlightColor, width: 2),
        ),
        title: Text(
          'SELECT ANIMAL',
          style: AppTextStyles.headline(context, baseSize: 14, color: AppColors.highlightColor),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: bm.playerTeam.length,
            itemBuilder: (context, index) {
              final animal = bm.playerTeam[index];
              final isCurrent = index == bm.currentPlayerIndex;
              final isFainted = animal.currentHealth <= 0;

              return GestureDetector(
                onLongPressStart: (_) {
                  // Show animal details on long press
                  final battleOrg = BattleOrganism(animal);
                  _showOrganismInfo(context, battleOrg);
                },
                child: ListTile(
                  enabled: !isCurrent && !isFainted,
                  leading: Opacity(
                  opacity: isFainted ? 0.5 : 1.0,
                  child: Image.asset(
                    'assets/sprites/${animal.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                    width: 40,
                    errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: Colors.white),
                  ),
                ),
                title: Text(
                  animal.name,
                  style: TextStyle(
                    color: isCurrent ? AppColors.highlightColor : (isFainted ? Colors.grey : Colors.white),
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
                subtitle: Text(
                  'HP: ${animal.currentHealth}/${animal.maxHealth}',
                  style: TextStyle(
                    color: isFainted ? Colors.red : Colors.green,
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                  ),
                ),
                trailing: isCurrent 
                  ? const Icon(Icons.check_circle, color: AppColors.highlightColor) 
                  : (isFainted ? const Text('FAINTED', style: TextStyle(color: Colors.red, fontSize: 8, fontFamily: 'PressStart2P')) : null),
                  onTap: (!isCurrent && !isFainted) ? () {
                    Navigator.pop(ctx);
                    bm.switchAnimal(index);
                  } : null,
                ),
              );
            },
          ),
        ),
        actions: [
          if (bm.currentState != BattleState.waitingForPlayerSwitch)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white70, fontFamily: 'PressStart2P', fontSize: 10)),
            ),
        ],
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

    if (battleManager.currentState == BattleState.waitingForPlayerSwitch && !_isSwitchDialogShowing) {
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
                                  if (widget.isArenaBattle) _buildOpponentTeamIndicator(context, battleManager),
                                  const SizedBox(height: 2),
                                  AnimatedBuilder(
                                    animation: _opponentShakeAnimation,
                                    builder: (context, child) => Transform.translate(
                                      offset: Offset(_opponentShakeAnimation.value, 0),
                                      child: child,
                                    ),
                                    child: _buildOpponentStatus(context, battleManager.opponent, overlayColor, isNarrow),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedBuilder(
                                    animation: _playerShakeAnimation,
                                    builder: (context, child) => Transform.translate(
                                      offset: Offset(_playerShakeAnimation.value, 0),
                                      child: child,
                                    ),
                                    child: _buildPlayerStatus(context, battleManager.player, overlayColor, isNarrow),
                                  ),
                                ],
                              ),
                            ),
                            // Right side: Logs and Controls
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  if (battleManager.currentState == BattleState.waitingForInput) ...[
                                    _buildMessageBox(context, battleManager.battleLog, isNarrow, expanded: false),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _buildActionControls(context, battleManager, overlayColor, isNarrow),
                                      ),
                                    ),
                                  ] else
                                    Expanded(child: _buildMessageBox(context, battleManager.battleLog, isNarrow, expanded: true)),
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
                    if (widget.isArenaBattle) _buildOpponentTeamIndicator(context, battleManager),
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
                            child: _buildOpponentStatus(context, battleManager.opponent, overlayColor, isNarrow),
                          ),
                          const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: _playerShakeAnimation,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(_playerShakeAnimation.value, 0),
                              child: child,
                            ),
                            child: _buildPlayerStatus(context, battleManager.player, overlayColor, isNarrow),
                          ),
                          const SizedBox(height: 1),
                          if (battleManager.currentState == BattleState.waitingForInput) ...[
                            _buildMessageBox(context, battleManager.battleLog, isNarrow, expanded: false),
                            _buildActionControls(context, battleManager, overlayColor, isNarrow),
                          ] else
                            Expanded(child: _buildMessageBox(context, battleManager.battleLog, isNarrow, expanded: true)),
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
            _AbilityPopUp(notification: battleManager.currentAbilityNotify!),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BattleManager battleManager, Color overlayColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.battleTitle ?? 'Wild Encounter',
            style: AppTextStyles.headline(context, baseSize: 12, color: AppColors.highlightColor),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _toggleOrientation,
                icon: const Icon(Icons.screen_rotation),
                color: AppColors.highlightColor,
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
                color: AppColors.highlightColor,
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
    if (bm.currentWeather.weather == Weather.none && bm.currentTerrain.terrain == Terrain.none) {
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
              bm.currentWeather.weather.toString().split('.').last.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 10),
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
              bm.currentTerrain.terrain.toString().split('.').last.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildOpponentTeamIndicator(BuildContext context, BattleManager bm) {
    if (!widget.isArenaBattle || bm.opponentTeam.isEmpty) return const SizedBox.shrink();
    
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
                    color: isCurrent ? AppColors.highlightColor : Colors.white30,
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

  Widget _buildOpponentStatus(BuildContext context, BattleOrganism organism, Color barColor, bool isNarrow) {
    final base = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final spriteSize = isLandscape 
        ? (isNarrow ? 90.0 : 110.0) 
        : (isNarrow ? 130.0 : 150.0);

    final statusBox = Container(
      constraints: BoxConstraints(maxWidth: isNarrow ? 160 : 200),
      padding: EdgeInsets.all(isNarrow ? 6 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlightColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(2, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              base.name,
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
              tween: Tween<double>(begin: hpRatio.clamp(0.0, 1.0), end: hpRatio.clamp(0.0, 1.0)),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                color: value > 0.5 ? const Color(0xFF4CAF50) : (value > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[800],
                minHeight: isNarrow ? 8 : 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HP: ${organism.health}/$maxHp',
              style: TextStyle(color: Colors.white70, fontSize: isNarrow ? 8 : 10, fontFamily: 'PressStart2P'),
            ),
          ),
          if (organism.statusEffect.type != StatusEffectType.none)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: organism.statusEffect.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                organism.statusEffect.name.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
          Flexible(child: statusBox),
          const SizedBox(width: 8),
          _BattleSprite(
            organism: organism, 
            size: spriteSize,
            onLongPress: () => _showOrganismInfo(context, organism),
            mirror: false, // Mirrored from previous State
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatus(BuildContext context, BattleOrganism organism, Color barColor, bool isNarrow) {
    final base = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final spriteSize = isLandscape 
        ? (isNarrow ? 100.0 : 120.0) 
        : (isNarrow ? 140.0 : 170.0);

    final statusBox = Container(
      constraints: BoxConstraints(maxWidth: isNarrow ? 160 : 200),
      padding: EdgeInsets.all(isNarrow ? 6 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlightColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(2, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              base.name,
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
              tween: Tween<double>(begin: hpRatio.clamp(0.0, 1.0), end: hpRatio.clamp(0.0, 1.0)),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                color: value > 0.5 ? const Color(0xFF4CAF50) : (value > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[800],
                minHeight: isNarrow ? 8 : 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HP: ${organism.health}/$maxHp',
              style: TextStyle(color: Colors.white70, fontSize: isNarrow ? 8 : 10, fontFamily: 'PressStart2P'),
            ),
          ),
          if (organism.statusEffect.type != StatusEffectType.none)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: organism.statusEffect.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                organism.statusEffect.name.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
          _BattleSprite(
            organism: organism, 
            size: spriteSize,
            onLongPress: () => _showOrganismInfo(context, organism),
            mirror: true, // Mirrored from previous State
          ),
          const SizedBox(width: 8),
          Flexible(child: statusBox),
        ],
      ),
    );
  }

  void _showOrganismInfo(BuildContext context, BattleOrganism bo) {
    final base = bo.organism.baseOrganism;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryButtonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.highlightColor, width: 2),
        ),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryButtonColor.withOpacity(0.8), AppColors.secondaryButtonColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Text(
            base.name,
            style: const TextStyle(
              color: AppColors.highlightColor, 
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
                    child: Text('CATEGORY: ', style: TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: base.category.toUpperCase().split(',').map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryButtonColor.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.highlightColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            cat.trim(),
                            style: const TextStyle(
                              color: AppColors.highlightColor,
                              fontSize: 9,
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
                    const Text('HP', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'PressStart2P')),
                    Text(
                      '${bo.health}/${bo.maxHealth}',
                      style: const TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'PressStart2P', fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              // Stat Boosts
              const Text(
                'STAT BOOSTS',
                style: TextStyle(color: AppColors.highlightColor, fontSize: 9, fontFamily: 'PressStart2P'),
              ),
              const SizedBox(height: 6),
              _buildStatRow('ATK', bo.attackStage > 0 ? '+${bo.attackStage}' : '${bo.attackStage}', Colors.orange),
              _buildStatRow('DEF', bo.defenseStage > 0 ? '+${bo.defenseStage}' : '${bo.defenseStage}', Colors.blue),
              _buildStatRow('PWR', bo.powerStage > 0 ? '+${bo.powerStage}' : '${bo.powerStage}', Colors.purple),
              _buildStatRow('RES', bo.resistanceStage > 0 ? '+${bo.resistanceStage}' : '${bo.resistanceStage}', Colors.deepOrange),
              _buildStatRow('SPD', bo.speedStage > 0 ? '+${bo.speedStage}' : '${bo.speedStage}', Colors.yellow),
              
              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),
              
              // Status
              Row(
                children: [
                  const Text('STATUS: ', style: TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'PressStart2P')),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bo.statusEffect.type == StatusEffectType.none ? Colors.grey.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bo.statusEffect.type == StatusEffectType.none ? "NONE" : bo.statusEffect.name.toUpperCase(),
                      style: TextStyle(
                        color: bo.statusEffect.type == StatusEffectType.none ? Colors.white70 : Colors.redAccent,
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),
              
              // Abilities
              const Text(
                'ABILITIES',
                style: TextStyle(color: AppColors.highlightColor, fontSize: 9, fontFamily: 'PressStart2P'),
              ),
              const SizedBox(height: 6),
              ...bo.abilities.map((ab) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ab.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'PressStart2P', fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ab.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 9, height: 1.5),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryButtonColor.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('OK', style: TextStyle(color: AppColors.highlightColor, fontFamily: 'PressStart2P', fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'PressStart2P')),
          Text(value, style: TextStyle(color: color, fontSize: 10, fontFamily: 'PressStart2P', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMessageBox(BuildContext context, String message, bool isNarrow, {bool expanded = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: isNarrow ? 4 : 8),
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 10 : 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.highlightColor, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.chat_bubble_outline, color: AppColors.highlightColor, size: isNarrow ? 16 : 20),
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

  Widget _buildActionControls(BuildContext context, BattleManager battleManager, Color overlayColor, bool isNarrow) {
    return Container(
      margin: EdgeInsets.fromLTRB(isNarrow ? 8 : 12, 0, isNarrow ? 8 : 12, isNarrow ? 4 : 6),
      padding: EdgeInsets.all(isNarrow ? 8 : 10),
      decoration: BoxDecoration(
        color: overlayColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlightColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(
            'What will ${battleManager.player.organism.baseOrganism.name} do?',
            style: TextStyle(color: AppColors.highlightColor, fontSize: isNarrow ? 9 : 10, fontFamily: 'PressStart2P'),
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
                : (MediaQuery.of(context).orientation == Orientation.landscape ? 4.2 : 3.6),
            children: battleManager.playerMoves.map((move) {
              return ElevatedButton(
                onPressed: () => battleManager.processPlayerAction(move),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButtonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.highlightColor),
                  ),
                  elevation: 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        move.name,
                        style: TextStyle(fontSize: isNarrow ? 8 : 10, fontFamily: 'PressStart2P'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${battleManager.playerOrganism.moveStamina[move.name] ?? 0}/${move.stamina}',
                        style: TextStyle(
                          fontSize: isNarrow ? 7 : 9,
                          fontFamily: 'PressStart2P',
                          color: (battleManager.playerOrganism.moveStamina[move.name] ?? 0) > 0 
                              ? Colors.white70 
                              : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: battleManager.attemptCapture,
                  icon: Icon(Icons.catching_pokemon, size: isNarrow ? 14 : 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const Text('Net', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 4 : 8, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSwitchDialog(context, battleManager),
                  icon: Icon(Icons.swap_horiz, size: isNarrow ? 14 : 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const Text('Switch', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 4 : 8, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    child: const Text('Run', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 4 : 8, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _handleBattleEnd(
    BuildContext context,
    BattleManager battleManager,
    UserState userState,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Handle capture - add organism to collection
      if (battleManager.result == BattleResult.capture) {
        final wildOpponent = battleManager.opponent.organism;
        final newCapturedInstance = wildOpponent.copyWith(
          currentHealth: wildOpponent.maxHealth, // Heal to full on capture
        );
        userState.addCapturedOrganism(newCapturedInstance);
      }
      
      // Handle loss - remove player's creature (death mechanic) ONLY in wild battles
      if (battleManager.result == BattleResult.loss && !widget.isArenaBattle) {
        final deadCreature = battleManager.player.organism;
        userState.removeCapturedOrganism(deadCreature);
      }

      // Arena battle prize money
      if (widget.isArenaBattle && battleManager.result == BattleResult.win) {
        userState.addMoney(1000);
      }

      final bool battleResult = battleManager.result == BattleResult.capture;
      
      // Get proper title text
      String titleText;
      switch (battleManager.result) {
        case BattleResult.win:
          titleText = 'VICTORY!';
          break;
        case BattleResult.loss:
          titleText = 'DEFEAT!';
          break;
        case BattleResult.capture:
          titleText = 'CAPTURED!';
          break;
        case BattleResult.fled:
          titleText = 'ESCAPED!';
          break;
        default:
          titleText = 'BATTLE END';
      }

      final String? lootId = battleManager.droppedLoot;
      final String? lootName = lootId != null ? LootItem.findById(lootId)?.name : null;
      
      // Handle loot drop
      if (battleManager.result == BattleResult.win && lootId != null) {
        userState.addLoot(lootId, 1);
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(titleText),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                battleManager.result == BattleResult.capture
                    ? 'You successfully captured the ${battleManager.opponent.organism.baseOrganism.name}!'
                    : battleManager.result == BattleResult.win
                        ? 'You defeated the wild encounter!'
                        : battleManager.result == BattleResult.fled
                            ? 'You ran away safely!'
                            : 'Your ${battleManager.player.organism.baseOrganism.name} has died in battle...',
                style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
              ),
              if (battleManager.result == BattleResult.win && lootName != null) ...[
                const SizedBox(height: 16),
                Text(
                  'LOOT DROPPED:',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: Colors.yellow[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.inventory_2, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      lootName,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(battleManager.result); // Return the enum
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
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
  });

  @override
  State<_BattleSprite> createState() => _BattleSpriteState();
}

class _BattleSpriteState extends State<_BattleSprite> {
  String? _imageSourceType;
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
  }

  @override
  void didUpdateWidget(_BattleSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.organism.organism.baseOrganism.name != oldWidget.organism.organism.baseOrganism.name ||
        widget.organism.organism.baseOrganism.sprite != oldWidget.organism.organism.baseOrganism.sprite) {
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
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final imageWidget = _imageSourceType == 'local'
        ? Image.asset(_imagePath, width: size, height: size, fit: BoxFit.contain)
        : Image.network(
            _imagePath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, color: Colors.white54, size: 40),
          );

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: size,
        height: size,
        child: widget.mirror 
            ? Transform.flip(
                flipX: true,
                child: imageWidget,
              )
            : imageWidget,
      ),
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;
  
  const TypewriterText(this.text, {super.key, this.style, this.speed = const Duration(milliseconds: 50)});

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
          if (_timer?.isActive != true && _displayedText.length < widget.text.length) {
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

  const _AbilityPopUp({required this.notification});

  @override
  State<_AbilityPopUp> createState() => _AbilityPopUpState();
}

class _AbilityPopUpState extends State<_AbilityPopUp> with SingleTickerProviderStateMixin {
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
      begin: widget.notification.isPlayer ? -200.0 : 200.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.notification.isPlayer 
          ? MediaQuery.of(context).size.height * 0.7
          : MediaQuery.of(context).size.height * 0.25,
      left: widget.notification.isPlayer ? 0 : null,
      right: widget.notification.isPlayer ? null : 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.translate(
              offset: Offset(_slideAnimation.value, 0),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            border: Border.all(color: AppColors.highlightColor, width: 2),
            borderRadius: BorderRadius.horizontal(
              left: widget.notification.isPlayer ? Radius.zero : const Radius.circular(20),
              right: widget.notification.isPlayer ? const Radius.circular(20) : Radius.zero,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: widget.notification.isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
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
                style: const TextStyle(
                  color: AppColors.highlightColor,
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
