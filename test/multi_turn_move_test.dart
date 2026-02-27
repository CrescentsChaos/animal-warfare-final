import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock audio channels to prevent errors in tests
  const MethodChannel(
    'xyz.luan/audioplayers',
  ).setMockMethodCallHandler((call) async => null);
  const MethodChannel(
    'xyz.luan/audioplayers.global',
  ).setMockMethodCallHandler((call) async => null);

  final base = Organism(
    name: 'Test',
    scientificName: 'Testus testus',
    habitat: 'Forest',
    drops: '',
    attack: 80,
    defense: 50,
    power: 80,
    resistance: 50,
    health: 200,
    speed: 100,
    abilities: '',
    category: 'Test',
    moves: 'Peck',
    sprite: '',
    rarity: 'Common',
    description: 'Test',
  );

  // Create Fly move for testing (non-const to allow list)
  final flyMove = Move(
    name: 'Fly',
    description: 'Flies up on the first turn, then strikes on the second.',
    baseDamage: 90,
    type: ElementalType.flying,
    effects: [
      const MoveEffect(type: MoveEffectType.semiInvulnerable, stat: 'airborne'),
    ],
  );

  final scratchMove = Move(
    name: 'Scratch',
    description: 'Scratches the foe.',
    baseDamage: 40,
    type: ElementalType.basic,
    isContact: true,
  );

  group('Multi-Turn Move (Fly) Tests', () {
    BattleManager makeManager() {
      final playerOrg = CapturedOrganism.spawn(base);
      playerOrg.moveStamina['Fly'] = 15;
      final opponentOrg = CapturedOrganism.spawn(base);
      opponentOrg.moveStamina['Scratch'] = 15;

      final manager = BattleManager(playerOrg, opponentOrg, isTesting: true);
      manager.currentState = BattleState.waitingForInput;
      manager.playerMoves = [flyMove];
      manager.opponentMoves = [scratchMove];
      return manager;
    }

    test(
      'Turn 1: Fly charge phase sets chargingMove and isInvulnerable',
      () async {
        final manager = makeManager();

        // Turn 1: Should go into charge phase
        await manager.processPlayerAction(flyMove);

        final allLogs = manager.turnHistory
            .expand((t) => t.logEntries)
            .join(' | ');

        expect(
          manager.player.chargingMove,
          isNotNull,
          reason: 'Player should be in charging state after turn 1',
        );
        expect(manager.player.chargingMove!.name, equals('Fly'));
        expect(
          manager.player.isInvulnerable,
          isTrue,
          reason: 'Player should be invulnerable while charging Fly',
        );
        expect(
          allLogs,
          contains('flew up high'),
          reason: 'Should log the "flew up high" charge message',
        );
      },
    );

    test(
      'Turn 2: Fly attack phase clears chargingMove and invulnerability',
      () async {
        final manager = makeManager();

        // Turn 1: Charge phase
        await manager.processPlayerAction(flyMove);
        expect(
          manager.player.chargingMove,
          isNotNull,
          reason: 'Should be charging after turn 1',
        );

        // Turn 2: Attack phase -
        manager.currentState = BattleState.waitingForInput;
        await manager.processPlayerAction(flyMove);

        expect(
          manager.player.chargingMove,
          isNull,
          reason: 'ChargingMove should be cleared after attack on turn 2',
        );
        expect(
          manager.player.isInvulnerable,
          isFalse,
          reason: 'Should not be invulnerable after completing the attack',
        );

        final allLogs = manager.turnHistory
            .expand((t) => t.logEntries)
            .join(' | ');

        // The attack turn should add "used Fly!" in logs
        expect(
          allLogs,
          contains('used Fly!'),
          reason: 'Should have attack log entry for Fly on turn 2',
        );
      },
    );

    test(
      'Fly does NOT re-enter charge phase on second button press (no infinite loop)',
      () async {
        final manager = makeManager();

        // Turn 1: Charge
        await manager.processPlayerAction(flyMove);

        // Count charge messages before turn 2
        final logsBefore = manager.turnHistory
            .expand((t) => t.logEntries)
            .toList();
        final chargeCountBefore = logsBefore
            .where((l) => l.contains('flew up high'))
            .length;
        expect(
          chargeCountBefore,
          equals(1),
          reason: 'Should have exactly 1 charge message after turn 1',
        );

        // Turn 2: Attack (NOT another charge)
        manager.currentState = BattleState.waitingForInput;
        await manager.processPlayerAction(flyMove);

        final logsAfter = manager.turnHistory
            .expand((t) => t.logEntries)
            .toList();
        final chargeCountAfter = logsAfter
            .where((l) => l.contains('flew up high'))
            .length;

        // Should still only have 1 "flew up high" message — not 2
        expect(
          chargeCountAfter,
          equals(chargeCountBefore),
          reason:
              'Turn 2 should NOT add another "flew up high" — it should attack instead',
        );
      },
    );
  });
}
