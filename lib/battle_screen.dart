// lib/battle_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/loot_item.dart';

class BattleScreen extends StatelessWidget {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  final String biomeName;

  const BattleScreen({
    super.key,
    required this.playerOrganism,
    required this.opponentOrganism,
    required this.biomeName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BattleManager(playerOrganism, opponentOrganism, biomeName: biomeName),
      child: BattleScreenContent(biomeName: biomeName),
    );
  }
}

class BattleScreenContent extends StatelessWidget {
  final String biomeName;

  const BattleScreenContent({super.key, required this.biomeName});

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

  @override
  Widget build(BuildContext context) {
    final battleManager = Provider.of<BattleManager>(context);
    final userState = Provider.of<UserState>(context, listen: false);
    final isNarrow = MediaQuery.sizeOf(context).width < 400;

    if (battleManager.currentState == BattleState.battleEnd) {
      _handleBattleEnd(context, battleManager, userState);
    }

    final overlayColor = Colors.black.withOpacity(0.55);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_getAssetPath(biomeName)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.35),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Wild Encounter',
                        style: AppTextStyles.headline(context, baseSize: 12, color: AppColors.highlightColor),
                      ),
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
                ),
                const SizedBox(height: 2),
                _buildFieldEffects(context, battleManager),
                const SizedBox(height: 2),

                Expanded(
                  child: Column(
                    children: [
                      _buildOpponentStatus(context, battleManager.opponent, overlayColor, isNarrow),
                      const SizedBox(height: 4),
                      _buildPlayerStatus(context, battleManager.player, overlayColor, isNarrow),
                      const SizedBox(height: 2),
                      _buildMessageBox(context, battleManager.battleLog, isNarrow),
                      if (battleManager.currentState == BattleState.waitingForInput)
                        _buildActionControls(context, battleManager, overlayColor, isNarrow),
                    ],
                  ),
                ),
              ],
            ),
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

  Widget _buildOpponentStatus(BuildContext context, BattleOrganism organism, Color barColor, bool isNarrow) {
    final base = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;
    final spriteSize = isNarrow ? 85.0 : 105.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: isNarrow ? 180 : 220),
                padding: EdgeInsets.all(isNarrow ? 8 : 10),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.highlightColor, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(2, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      base.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: isNarrow ? 10 : 12,
                        fontFamily: 'PressStart2P',
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: hpRatio.clamp(0.0, 1.0),
                        color: hpRatio > 0.5 ? const Color(0xFF4CAF50) : (hpRatio > 0.2 ? Colors.orange : Colors.red),
                        backgroundColor: Colors.grey[800],
                        minHeight: isNarrow ? 10 : 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HP: ${organism.health}/$maxHp',
                      style: TextStyle(color: Colors.white70, fontSize: isNarrow ? 8 : 10, fontFamily: 'PressStart2P'),
                    ),
                    if (organism.statusEffect.type != StatusEffectType.none)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          organism.statusEffect.name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _BattleSprite(
            organism: organism, 
            size: spriteSize,
            onLongPress: () => _showOrganismInfo(context, organism),
            mirror: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatus(BuildContext context, BattleOrganism organism, Color barColor, bool isNarrow) {
    final base = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;
    final spriteSize = isNarrow ? 95.0 : 115.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BattleSprite(
            organism: organism, 
            size: spriteSize,
            onLongPress: () => _showOrganismInfo(context, organism),
            mirror: true,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: isNarrow ? 180 : 220),
                padding: EdgeInsets.all(isNarrow ? 8 : 10),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.highlightColor, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(2, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      base.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: isNarrow ? 10 : 12,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: hpRatio.clamp(0.0, 1.0),
                        color: hpRatio > 0.5 ? const Color(0xFF4CAF50) : (hpRatio > 0.2 ? Colors.orange : Colors.red),
                        backgroundColor: Colors.grey[800],
                        minHeight: isNarrow ? 10 : 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HP: ${organism.health}/$maxHp',
                      style: TextStyle(color: Colors.white70, fontSize: isNarrow ? 8 : 10, fontFamily: 'PressStart2P'),
                    ),
                    if (organism.statusEffect.type != StatusEffectType.none)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          organism.statusEffect.name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
              
              // Ability
              const Text(
                'ABILITY',
                style: TextStyle(color: AppColors.highlightColor, fontSize: 9, fontFamily: 'PressStart2P'),
              ),
              const SizedBox(height: 6),
              Text(
                base.abilities.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'PressStart2P', fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                bo.ability?.description ?? 'No description available.',
                style: const TextStyle(color: Colors.white70, fontSize: 9, height: 1.5),
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'PressStart2P')),
          Text(value, style: TextStyle(color: color, fontSize: 10, fontFamily: 'PressStart2P', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMessageBox(BuildContext context, String message, bool isNarrow) {
    return Container(
      margin: EdgeInsets.all(isNarrow ? 2 : 4),
      padding: EdgeInsets.all(isNarrow ? 4 : 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlightColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline, color: AppColors.highlightColor, size: isNarrow ? 18 : 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: isNarrow ? 11 : 13,
                fontFamily: 'PressStart2P',
                height: 1.4,
              ),
            ),
          ),
        ],
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
          const SizedBox(height: 6),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: isNarrow ? 2.8 : 3.2,
            children: battleManager.playerMoves.map((move) {
              return ElevatedButton(
                onPressed: () => battleManager.processPlayerAction(move),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButtonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.highlightColor),
                  ),
                  elevation: 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      move.name,
                      style: TextStyle(fontSize: isNarrow ? 8 : 10, fontFamily: 'PressStart2P'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${battleManager.playerOrganism.moveStamina[move.name] ?? 0}/${move.stamina}',
                      style: TextStyle(
                        fontSize: isNarrow ? 7 : 9,
                        fontFamily: 'PressStart2P',
                        color: (battleManager.playerOrganism.moveStamina[move.name] ?? 0) > 0 
                            ? Colors.white70 
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: battleManager.attemptCapture,
                  icon: const Icon(Icons.catching_pokemon, size: 20),
                  label: const Text('Capture', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 8 : 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: battleManager.attemptRun,
                  icon: const Icon(Icons.directions_run, size: 20),
                  label: const Text('Run', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 8 : 10),
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
      
      // Handle loss - remove player's creature (death mechanic)
      if (battleManager.result == BattleResult.loss) {
        final deadCreature = battleManager.player.organism;
        userState.removeCapturedOrganism(deadCreature);
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          color: Colors.black.withOpacity(0.5),
          child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.highlightColor.withOpacity(0.5)),
          ),
          child: widget.mirror 
              ? Transform.flip(
                  flipX: true,
                  child: imageWidget,
                )
              : imageWidget,
        ),
      ),
    );
  }
}
