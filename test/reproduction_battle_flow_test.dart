import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper to create a dummy organism
  CapturedOrganism createDummy({
    required String name,
    int health = 100,
    int speed = 10,
    List<String> moves = const ['Tackle'],
  }) {
    final base = Organism(
      name: name,
      scientificName: 'Testus',
      habitat: 'Lab',
      drops: '',
      attack: 10,
      defense: 10,
      power: 10,
      resistance: 10,
      health: 100,
      speed: speed,
      abilities: '',
      category: 'Test',
      moves: moves.join(','),
      sprite: '',
      rarity: 'Common',
      description: '',
      types: ['normal'],
    );

    return CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 0,
        'attack': 0,
        'defense': 0,
        'power': 0,
        'resistance': 0,
        'speed': 0,
      },
      currentHealth: health,
      selectedMoveNames: moves,
      nature: const Nature(
        name: 'Hardy',
        increasedStat: NatureStat.attack,
        decreasedStat: NatureStat.attack, // Neutral
      ),
    );
  }

  group('Battle Flow Reproduction Tests', () {
    test('Player switch after faint should consume turn and reset state', () async {
      final player1 = createDummy(
        name: 'Fainter',
        health: 0,
      ); // Already fainted for setup
      final player2 = createDummy(name: 'Fresh', health: 100);
      final opponent = createDummy(name: 'Opponent', health: 100);

      final bm = BattleManager(
        player1,
        opponent,
        team: [player1, player2],
        isArenaBattle: false,
      );

      // Simulate battle start and skip intro
      bm.currentState = BattleState.waitingForPlayerSwitch;

      // Expected initial state for forced switch
      expect(bm.currentState, BattleState.waitingForPlayerSwitch);
      expect(bm.currentPlayerIndex, 0);

      // Perform the switch
      await bm.switchAnimal(1);

      // CHECK FOR BUG 1: Attack after faint
      // If bug exists: isResumingTurn might be true, or it might stay in waitingForInput without turn increment
      // Correct behavior: Finish turn -> New Turn -> WaitingForInput

      // We expect the turn to have advanced (or at least processed the "switch" as the action)
      // Actually, standard logic: Faint -> Switch -> "What will X do?" (Beginning of NEW turn)
      // The bug description says "player should not get the chance choose attack on that turn".
      // This implies that currently, after switching, they can attack immediately in the SAME turn cycle.

      // If fixed, the 'switch' action effectively ends the "faint turn" loop if it was pending,
      // or simply sets up the Fresh animal for a NEW turn #2.
      // Let's check if the turn counter incremented.
      // Initial turn is 1.

      // In the current buggy implementation, `isResumingTurn` is likely set to true,
      // which allows `processPlayerAction` to run immediately if we were to call it,
      // or keeps us in the same turn index.

      // Verifying state
      expect(
        bm.currentPlayerIndex,
        1,
        reason: "Player should have switched to index 1",
      );
      expect(bm.player.organism.name, 'Fresh');

      // Vital Checks
      expect(
        bm.isResumingTurn,
        isFalse,
        reason: "Should NOT be resuming old turn after faint switch",
      );
      // If we are "resuming", it implies we are still in the same turn bucket.
    });

    test('Arena Opponent switch should not softlock UI', () async {
      final player = createDummy(name: 'Player', health: 100);
      final opp1 = createDummy(name: 'Opp1', health: 0); // Faints immediately
      final opp2 = createDummy(name: 'Opp2', health: 100);

      final bm = BattleManager(
        player,
        opp1,
        team: [player],
        opponentTeam: [opp1, opp2],
        isArenaBattle: true,
      );

      // Setup state where opponent just fainted and is switching
      // Manually trigger the end check or simulate the flow
      bm.currentState =
          BattleState.playerTurn; // Simulate during player turn end

      // We need to trigger `_checkBattleEnd` which calls `_switchOpponentTo`
      // But `_checkBattleEnd` is private. We can trigger it via a dummy move execution or
      // by inspecting `currentState` after a manually induced state change.

      // Let's simulate the loop in `processPlayerAction` where it checks battle end.
      // Since we can't call private methods easily, we'll use `processPlayerAction`
      // with a dummy move that kills the opponent.

      // Heal opponent first to ensure we control the kill
      bm.opponent.health = 10;

      final killMove = Move(
        name: 'Kill',
        type: ElementalType.normal,
        category: MoveCategory.physical,
        baseDamage: 1000, // One shot
        accuracy: 100,
        pp: 10,
        description: '',
        stamina: 10,
        effects: [],
      );

      bm.currentState = BattleState.waitingForInput;

      // ACT
      await bm.processPlayerAction(killMove);

      // CHECK FOR BUG 2: Softlock
      // If bug exists: currentState might remain stuck or return early without resetting to waitingForInput
      // because `opponentJustSwitched` logic returns early.

      expect(
        bm.opponent.organism.name,
        'Opp2',
        reason: "Opponent should have switched to Opp2",
      );
      expect(
        bm.currentState,
        BattleState.waitingForInput,
        reason: "State should return to waitingForInput after opponent switch",
      );

      // The softlock usually happens because the code returns early and doesn't reach `_finalizeTurn`
      // or doesn't clear `opponentJustSwitched` correctly for the next UI render interaction.
    });
  });
}
