import 'dart:math';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/double_battle_manager.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/widgets/terrain_overlay.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/game/move_animations.dart' as anims;
import 'package:provider/provider.dart';

class DoubleBattleScreen extends StatelessWidget {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  final String biomeName;
  final List<CapturedOrganism> playerTeam;
  final List<CapturedOrganism> opponentTeam;
  final String battleTitle;
  final bool isArenaBattle;
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
      ),
    );
  }
}

class DoubleBattleScreenContent extends StatefulWidget {
  final String biomeName;
  final String? battleTitle;
  final bool isArenaBattle;

  const DoubleBattleScreenContent({
    super.key,
    required this.biomeName,
    this.battleTitle,
    this.isArenaBattle = false,
  });

  @override
  State<DoubleBattleScreenContent> createState() => _DoubleBattleScreenContentState();
}

class _DoubleBattleScreenContentState extends State<DoubleBattleScreenContent> with TickerProviderStateMixin {
  // Selection state
  Move? _selectedMove;
  
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = Provider.of<DoubleBattleManager>(context, listen: false);
      _setupListeners(manager);
    });
  }

  void _setupListeners(DoubleBattleManager manager) {
    manager.onAttack = (attacker, targets, move) {
      if (!mounted) return;
      setState(() {
        _screenShakeX = (Random().nextDouble() - 0.5) * 10;
        _screenShakeY = (Random().nextDouble() - 0.5) * 10;
        
        final animId = 'move_anim_${_moveAnimIdCounter++}';
        final animData = anims.MoveAnimData(
          id: animId,
          move: move,
          isPlayerAttacking: attacker.isPlayer,
          attackerSlot: attacker.slotIndex,
          targetSlots: targets.map((t) => t.slotIndex).toList(),
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
    };
  }

  String _getAssetPath(String biome) {
    String name = biome.toLowerCase();
    if (name.contains('swamp')) return 'assets/biomes/swamp.png';
    if (name.contains('desert')) return 'assets/biomes/desert.png';
    if (name.contains('snow')) return 'assets/biomes/snow.png';
    if (name.contains('volcan')) return 'assets/biomes/volcano.png';
    if (name.contains('mountain')) return 'assets/biomes/mountain.png';
    if (name.contains('ocean')) return 'assets/biomes/ocean.png';
    return 'assets/biomes/forest.png';
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<DoubleBattleManager>(context);

    return Scaffold(
      body: Transform.translate(
        offset: Offset(_screenShakeX, _screenShakeY),
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                _getAssetPath(widget.biomeName),
                fit: BoxFit.cover,
              ),
            ),
            
            // Overlays
            WeatherOverlay(weather: manager.currentWeather.weather),
            TerrainOverlay(terrain: manager.currentTerrain.terrain),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(manager),
                  const Spacer(),
                  _buildParticipantArea(manager),
                  const Spacer(),
                  _buildUIControls(manager),
                ],
              ),
            ),
            
            // Target Picker Overlay
            if (_selectedMove != null)
              _buildTargetPickerOverlay(manager),

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

  Widget _buildHeader(DoubleBattleManager manager) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black45,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.battleTitle ?? 'DOUBLE BATTLE',
            style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white),
          ),
          Text(
            'TURN ${manager.currentTurn}',
            style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantArea(DoubleBattleManager manager) {
    return Column(
      children: [
        _buildDualOpponentStatus(manager),
        const SizedBox(height: 30),
        _buildDualPlayerStatus(manager),
      ],
    );
  }

  Widget _buildDualOpponentStatus(DoubleBattleManager manager) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (manager.opponentSlot1 != null) _buildHPBox(manager.opponentSlot1!),
            if (manager.opponentSlot2 != null) _buildHPBox(manager.opponentSlot2!),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (manager.opponentSlot1 != null) 
              CompositedTransformTarget(link: _opponent1Link, child: _buildSprite(manager.opponentSlot1!, isOpponent: true)),
            if (manager.opponentSlot2 != null) 
              CompositedTransformTarget(link: _opponent2Link, child: _buildSprite(manager.opponentSlot2!, isOpponent: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildDualPlayerStatus(DoubleBattleManager manager) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (manager.playerSlot1 != null) 
              CompositedTransformTarget(link: _player1Link, child: _buildSprite(manager.playerSlot1!, isOpponent: false)),
            if (manager.playerSlot2 != null) 
              CompositedTransformTarget(link: _player2Link, child: _buildSprite(manager.playerSlot2!, isOpponent: false)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (manager.playerSlot1 != null) _buildHPBox(manager.playerSlot1!),
            if (manager.playerSlot2 != null) _buildHPBox(manager.playerSlot2!),
          ],
        ),
      ],
    );
  }

  Widget _buildHPBox(BattleOrganism org) {
    final ratio = org.health / org.maxHealth;
    final color = ratio > 0.5 ? Colors.green : (ratio > 0.2 ? Colors.orange : Colors.red);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            org.name.toUpperCase(),
            style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${org.health.toInt()} / ${org.maxHealth}',
            style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSprite(BattleOrganism org, {required bool isOpponent}) {
    return Container(
      width: 130,
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: -15), // Enhanced overlap
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            org.organism.baseOrganism.sprite,
            fit: BoxFit.contain,
          ),
          if (org.isProtected)
            const Icon(Icons.shield, color: Colors.blueAccent, size: 40),
        ],
      ),
    );
  }

  Widget _buildUIControls(DoubleBattleManager manager) {
    bool showInput = manager.currentState == DoubleBattleState.selectingForSlot1 ||
                     manager.currentState == DoubleBattleState.selectingForSlot2;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.white10, width: 2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              reverse: true, // Always show latest logs
              child: Text(
                manager.battleLog,
                style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white, height: 1.6),
              ),
            ),
          ),
          if (showInput && _selectedMove == null)
            _buildActionGrid(manager),
        ],
      ),
    );
  }

  Widget _buildActionGrid(DoubleBattleManager manager) {
    final org = (manager.currentState == DoubleBattleState.selectingForSlot1) 
        ? manager.playerSlot1! 
        : manager.playerSlot2!;
    final moves = manager.getMovesFor(org);

    return Column(
      children: [
        const Divider(color: Colors.white10),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'CHOOSE FOR ${org.name.toUpperCase()}',
            style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.amberAccent),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: moves.map((m) => _buildMoveButton(manager, m)).toList(),
        ),
      ],
    );
  }

  Widget _buildMoveButton(DoubleBattleManager manager, Move move) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onMoveSelected(move, manager),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: move.type.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: move.type.color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Center(
            child: Text(
              move.name.toUpperCase(),
              style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
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
      if (move.doublesTarget == MoveTarget.bothOpponents) target = DoubleTarget.allOpponents;
      if (move.doublesTarget == MoveTarget.allAdjacent) target = DoubleTarget.allOpponents;
      if (move.doublesTarget == MoveTarget.self) target = (manager.currentState == DoubleBattleState.selectingForSlot1) ? DoubleTarget.playerSlot1 : DoubleTarget.playerSlot2;
      
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
              style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (manager.opponentSlot1 != null) 
                  _buildTargetButton('OPP 1', DoubleTarget.opponentSlot1, manager),
                const SizedBox(width: 20),
                if (manager.opponentSlot2 != null) 
                  _buildTargetButton('OPP 2', DoubleTarget.opponentSlot2, manager),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (manager.playerSlot1 != null) 
                  _buildTargetButton('ALLY 1', DoubleTarget.playerSlot1, manager),
                const SizedBox(width: 20),
                if (manager.playerSlot2 != null) 
                  _buildTargetButton('ALLY 2', DoubleTarget.playerSlot2, manager),
              ],
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => setState(() => _selectedMove = null),
              child: Text('CANCEL', style: GoogleFonts.pressStart2p(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetButton(String label, DoubleTarget target, DoubleBattleManager manager) {
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
      child: Text(label, style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
    );
  }
}
