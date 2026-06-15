import 'dart:io';

void main() async {
  final file = File('lib/game/battle_manager.dart');
  String content = await file.readAsString();

  content = content.replaceAll(
    'opponent = BattleOrganism(\n      opponentOrganism,\n      isRogueMode: isRogueMode,\n      isOpponent: true,\n      atLevel: isRogueMode ? opponentLevel : null,\n    );',
    'opponent = BattleOrganism(\n      opponentOrganism,\n      isRogueMode: isRogueMode,\n      isOpponent: true,\n      atLevel: isRogueMode ? opponentLevel : null,\n      biomeName: biomeName,\n    );'
  );
  
  content = content.replaceAll(
    'opponent = BattleOrganism(\n      this.opponentTeam[currentOpponentIndex],\n      isRogueMode: isRogueMode,\n      isOpponent: true,\n      atLevel: isRogueMode ? opponentLevel : null,\n    );',
    'opponent = BattleOrganism(\n      this.opponentTeam[currentOpponentIndex],\n      isRogueMode: isRogueMode,\n      isOpponent: true,\n      atLevel: isRogueMode ? opponentLevel : null,\n      biomeName: biomeName,\n    );'
  );

  content = content.replaceAll(
    'opponent = BattleOrganism(\n        opponentTeam[currentOpponentIndex],\n        isRogueMode: isRogueMode,\n        isOpponent: true,\n        atLevel: isRogueMode ? opponentLevel : null,\n      );',
    'opponent = BattleOrganism(\n        opponentTeam[currentOpponentIndex],\n        isRogueMode: isRogueMode,\n        isOpponent: true,\n        atLevel: isRogueMode ? opponentLevel : null,\n        biomeName: biomeName,\n      );'
  );

  content = content.replaceAll(
    'opponent = BattleOrganism(\n        opponentOrganism,\n        isRogueMode: isRogueMode,\n        isOpponent: true,\n        atLevel: isRogueMode ? opponentLevel : null,\n      );',
    'opponent = BattleOrganism(\n        opponentOrganism,\n        isRogueMode: isRogueMode,\n        isOpponent: true,\n        atLevel: isRogueMode ? opponentLevel : null,\n        biomeName: biomeName,\n      );'
  );

  content = content.replaceAll(
    'opponent = BattleOrganism(\n      opponentTeam[currentOpponentIndex],\n      isRogueMode: isRogueMode,\n      isOpponent: true,\n      atLevel: isRogueMode ? opponentLevel : null,\n    );',
    'opponent = BattleOrganism(\n      opponentTeam[currentOpponentIndex],\n      isRogueMode: isRogueMode,\n      isOpponent: true,\n      atLevel: isRogueMode ? opponentLevel : null,\n      biomeName: biomeName,\n    );'
  );

  content = content.replaceAll(
    'player = BattleOrganism(\n      playerOrganism,\n      isRogueMode: isRogueMode,\n      isOpponent: false,\n    );',
    'player = BattleOrganism(\n      playerOrganism,\n      isRogueMode: isRogueMode,\n      isOpponent: false,\n      biomeName: biomeName,\n    );'
  );

  await file.writeAsString(content);
  print('Done applying biomeName to BattleOrganism in battle_manager.dart');
}
