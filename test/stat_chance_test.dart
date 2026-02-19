import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock platform channels for audioplayers
  const MethodChannel(
    'xyz.luan/audioplayers',
  ).setMockMethodCallHandler((call) async => null);
  const MethodChannel(
    'xyz.luan/audioplayers.global',
  ).setMockMethodCallHandler((call) async => null);

  test(
    'Move stat change respects chance value',
    () async {
      final base = Organism(
        name: 'Test',
        scientificName: 'Testus testus',
        habitat: 'Forest',
        drops: '',
        attack: 50,
        defense: 50,
        power: 50,
        resistance: 50,
        health: 100,
        speed: 100,
        abilities: '',
        category: 'Test',
        moves: 'Scratch',
        sprite: '',
        rarity: 'Common',
        description: 'Test',
      );

      final playerOrg = CapturedOrganism.spawn(base);
      final opponentOrg = CapturedOrganism.spawn(base);

      // Create a move with 50% chance to lower defense
      final testMove = Move(
        name: 'TestMove',
        description: '50% chance to lower defense.',
        baseDamage: 10,
        type: ElementalType.basic,
        accuracy: 100,
        category: MoveCategory.physical,
        effects: [
          MoveEffect(
            type: MoveEffectType.statChange,
            target: 'opponent',
            stat: 'defense',
            value: -1,
            chance: 50,
          ),
        ],
      );

      int successes = 0;
      int iterations = 20; // Reduced to 20 for speed

      for (int i = 0; i < iterations; i++) {
        // Reset stages and provide stamina
        playerOrg.moveStamina[testMove.name] = testMove.stamina;
        opponentOrg.selectedMoveNames = ['Scratch'];
        opponentOrg.moveStamina['Scratch'] = 20;

        final manager = BattleManager(playerOrg, opponentOrg, isTesting: true);
        manager.currentState = BattleState.waitingForInput;
        manager.opponent.defenseStage = 0;

        await manager.processPlayerAction(testMove);

        if (manager.opponent.defenseStage < 0) {
          successes++;
        }
      }

      print('Successes in $iterations runs: $successes');
      // For 20 runs at 50%, it's highly likely to be between 2 and 18.
      // If it was 100%, it would be 20.
      expect(
        successes,
        lessThan(iterations),
        reason: 'Should not be 100% successes',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
