// lib/battle_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/user_state.dart'; 

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
      create: (context) => BattleManager(playerOrganism, opponentOrganism),
      child: BattleScreenContent(biomeName: biomeName), 
    );
  }
}

class BattleScreenContent extends StatelessWidget {
  final String biomeName; 

  const BattleScreenContent({super.key, required this.biomeName}); 

  // Helper to get the background image path (assumes assets/biomes/[biome_name]-bg.png)
  String _getAssetPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  // Helper to get a semi-dark color for text readability on the background
  Color _getDarkenedBiomeColor(String biomeName) {
      switch (biomeName.toLowerCase()) {
        case 'swamp': return const Color(0xFF334C31);
        case 'savanna': return const Color(0xFF7A6142);
        case 'desert': return const Color(0xFF6B4527);
        default: return Colors.black.withOpacity(0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final battleManager = Provider.of<BattleManager>(context);
    final userState = Provider.of<UserState>(context, listen: false);

    if (battleManager.currentState == BattleState.battleEnd) {
      _handleBattleEnd(context, battleManager, userState);
    }
    
    final Color textColor = Colors.white;
    final Color overlayColor = _getDarkenedBiomeColor(biomeName).withOpacity(0.7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wild Encounter'),
        backgroundColor: overlayColor, 
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_getAssetPath(biomeName)), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4), 
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildOpponentStatus(battleManager.opponent, textColor, overlayColor),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: overlayColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                battleManager.battleLog, 
                style: TextStyle(fontSize: 16, color: textColor)
              ),
            ),
            const Spacer(),
            _buildPlayerStatus(battleManager.player, textColor, overlayColor),
            
            if (battleManager.currentState == BattleState.waitingForInput)
              _buildActionControls(context, battleManager, overlayColor),
          ],
        ),
      ),
    );
  }

  // --- UI Builders ---

  Widget _buildOpponentStatus(BattleOrganism organism, Color textColor, Color barColor) {
    final baseOrganismModel = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: textColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(baseOrganismModel.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              LinearProgressIndicator(
                value: hpRatio.clamp(0.0, 1.0),
                color: hpRatio > 0.5 ? Colors.green : (hpRatio > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[700],
                minHeight: 10,
              ),
              Text('HP: ${organism.health}/$maxHp', style: TextStyle(color: textColor)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Sprite
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            baseOrganismModel.sprite, 
            height: 100,
            width: 100,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => 
                Container(height: 100, width: 100, color: barColor, child: const Center(child: Text('?', style: TextStyle(color: Colors.white)))),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPlayerStatus(BattleOrganism organism, Color textColor, Color barColor) {
    final baseOrganismModel = organism.organism.baseOrganism;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            baseOrganismModel.sprite,
            height: 100,
            width: 100,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                Container(height: 100, width: 100, color: barColor, child: const Center(child: Text('?', style: TextStyle(color: Colors.white)))),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 150,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: textColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baseOrganismModel.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              LinearProgressIndicator(
                value: hpRatio.clamp(0.0, 1.0),
                color: hpRatio > 0.5 ? Colors.green : (hpRatio > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[700],
                minHeight: 10,
              ),
              Text('HP: ${organism.health}/$maxHp', style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionControls(BuildContext context, BattleManager battleManager, Color overlayColor) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: overlayColor.withOpacity(0.9), 
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          // Fight: show this organism's moves only
          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: battleManager.playerMoves.map((move) {
              return ElevatedButton(
                onPressed: () => battleManager.processPlayerAction(move),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(move.name, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 10),
          
          // 2. CAPTURE & RUN BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 5.0),
                  child: ElevatedButton(
                    onPressed: battleManager.attemptCapture,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('Capture', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 5.0),
                  child: ElevatedButton(
                    onPressed: battleManager.attemptRun,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Run', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Battle End Handler ---
  void _handleBattleEnd(
    BuildContext context, 
    BattleManager battleManager, 
    UserState userState,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (battleManager.result == BattleResult.capture) {
        // 1. Get the base Organism model
        final baseOrganismModel = battleManager.opponent.organism.baseOrganism; 

        // 2. 🚨 FIX: Create a new CapturedOrganism instance from the base Organism model
        // This satisfies the required parameter type for userState.addCapturedOrganism
        final newCapturedInstance = CapturedOrganism.spawn(baseOrganismModel);
        
        // 3. Pass the correctly typed object.
        userState.addCapturedOrganism(newCapturedInstance); 
      }
      
      final bool battleResult = battleManager.result == BattleResult.capture;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(battleManager.result.toString().toUpperCase()),
          content: Text(battleManager.battleLog),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Close dialog
                // Go back to BiomeDetailScreen with the result
                Navigator.of(context).pop(battleResult);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }
}