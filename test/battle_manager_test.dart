import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:flutter/foundation.dart';

void main() {
  testWidgets('Battle ends if player faints after failed net attempt', (
    WidgetTester tester,
  ) async {
    final base = Organism(
      name: 'Test',
      scientificName: 'Test',
      habitat: 'Test',
      drops: '',
      attack: 100, // Strong attack to ensure knockout
      defense: 10,
      power: 10,
      resistance: 10,
      health: 100,
      speed: 10,
      abilities: '',
      category: 'Test',
      moves: 'Bite',
      sprite: '',
      rarity: 'Common',
      description: '',
      types: ['normal'],
    );

    final bite = Move.findByName('Bite');
    debugPrint(
      'TEST: Bite found: ${bite != null}, damage: ${bite?.baseDamage}',
    );

    final playerOrg = CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 0,
        'attack': 0,
        'defense': 0,
        'power': 0,
        'resistance': 0,
        'speed': 0,
      },
      currentHealth: 1, // Very low HP
      selectedMoveNames: ['Bite'],
      nature: const Nature(
        name: 'Hardy',
        increasedStat: NatureStat.attack,
        decreasedStat: NatureStat.attack,
      ),
    );

    final opponentOrg = CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      },
      currentHealth: 100,
      selectedMoveNames: ['Bite'],
      nature: const Nature(
        name: 'Hardy',
        increasedStat: NatureStat.attack,
        decreasedStat: NatureStat.attack,
      ),
    );

    bool captureFailedAndPlayerFainted = false;
    BattleResult? finalResult;
    BattleState finalState = BattleState.waitingForInput;

    for (int i = 0; i < 20; i++) {
      playerOrg.currentHealth = 1;

      final bm = BattleManager(
        playerOrg,
        opponentOrg,
        team: [playerOrg],
        biomeName: 'Forest', // Optional but helps logic
      );

      // 1. Wait for initialization sequence to finish
      // Introductory period is ~3s + 3s = 6s.
      await tester.pump(const Duration(seconds: 10));

      if (bm.currentState != BattleState.waitingForInput) {
        debugPrint(
          'Iteration $i: Initialization FAILED. state=${bm.currentState}',
        );
        continue;
      }

      final future = bm.attemptCapture();

      await tester.pump(const Duration(seconds: 1)); // Net throw
      await tester.pump(
        const Duration(seconds: 2),
      ); // Result message / Opponent turn start (1200ms)
      await tester.pump(
        const Duration(seconds: 10),
      ); // Opponent move execution (2500ms + 3000ms)
      await tester.pump(const Duration(seconds: 10)); // Finalization

      await future;

      debugPrint(
        'Iteration $i: state=${bm.currentState}, result=${bm.result}, playerHP=${bm.player.health}',
      );

      if (bm.result == BattleResult.loss) {
        captureFailedAndPlayerFainted = true;
        finalResult = bm.result;
        finalState = bm.currentState;
        break;
      }

      if (bm.result == BattleResult.capture) {
        debugPrint('Iteration $i: Captured Successfully!');
        continue;
      }
    }

    expect(
      captureFailedAndPlayerFainted,
      isTrue,
      reason: "Should eventually fail capture and get knocked out by opponent",
    );
    expect(finalState, BattleState.battleEnd);
    expect(finalResult, BattleResult.loss);
  });

  testWidgets('Battle ends if player faints after failed run attempt', (
    WidgetTester tester,
  ) async {
    final base = Organism(
      name: 'Test',
      scientificName: 'Test',
      habitat: 'Test',
      drops: '',
      attack: 100,
      defense: 10,
      power: 10,
      resistance: 10,
      health: 100,
      speed: 1, // Slow player
      abilities: '',
      category: 'Test',
      moves: 'Bite',
      sprite: '',
      rarity: 'Common',
      description: '',
      types: ['normal'],
    );

    final playerOrg = CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 0,
        'attack': 0,
        'defense': 0,
        'power': 0,
        'resistance': 0,
        'speed': 0,
      },
      currentHealth: 1,
      selectedMoveNames: ['Bite'],
    );

    final opponentOrg = CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      },
      currentHealth: 100,
      selectedMoveNames: ['Bite'],
    );

    bool runFailedAndPlayerFainted = false;
    BattleResult? finalResult;
    BattleState finalState = BattleState.waitingForInput;

    for (int i = 0; i < 20; i++) {
      playerOrg.currentHealth = 1;

      final bm = BattleManager(
        playerOrg,
        opponentOrg,
        team: [playerOrg],
        biomeName: 'Forest',
      );

      await tester.pump(const Duration(seconds: 10));

      if (bm.currentState != BattleState.waitingForInput) {
        debugPrint(
          'Run Iteration $i: Initialization FAILED. state=${bm.currentState}',
        );
        continue;
      }

      final future = bm.attemptRun();

      await tester.pump(const Duration(seconds: 1)); // Attempt run
      await tester.pump(
        const Duration(seconds: 2),
      ); // Fail message / Opponent turn start
      await tester.pump(const Duration(seconds: 10)); // Opponent move execution
      await tester.pump(const Duration(seconds: 10)); // Finalization

      await future;

      debugPrint(
        'Run Iteration $i: state=${bm.currentState}, result=${bm.result}, playerHP=${bm.player.health}',
      );

      if (bm.result == BattleResult.loss) {
        runFailedAndPlayerFainted = true;
        finalResult = bm.result;
        finalState = bm.currentState;
        break;
      }
    }

    expect(runFailedAndPlayerFainted, isTrue);
    expect(finalState, BattleState.battleEnd);
    expect(finalResult, BattleResult.loss);
  });
}
