import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioService.isTesting = true;

    // Register clamping move
    Move.addTestMove(
      const Move(
        name: 'Clamp Attack',
        baseDamage: 35,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Traps opponent',
        accuracy: 100,
        effects: [
          MoveEffect(
            type: MoveEffectType.clamping,
            chance: 100,
            value: 4,
          ),
        ],
      ),
    );

    // Register stun move
    Move.addTestMove(
      const Move(
        name: 'Stun Strike',
        baseDamage: 20,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Stuns opponent',
        accuracy: 100,
        effects: [
          MoveEffect(
            type: MoveEffectType.statusStun,
            chance: 100,
            value: 1,
          ),
        ],
      ),
    );
  });

  Organism createTestOrganism({int speed = 100, String name = 'Test'}) {
    return Organism(
      name: name,
      scientificName: 'Testus',
      habitat: 'Test',
      drops: '',
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      health: 100,
      speed: speed,
      abilities: 'None',
      category: 'Test',
      moves: 'Clamp Attack,Stun Strike',
      sprite: '',
      rarity: 'Common',
      description: '',
      weight: 1.0,
      types: ['basic'],
    );
  }

  CapturedOrganism createCaptured(Organism base, List<String> moves) {
    return CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      },
      currentHealth: 200,
      level: 50,
      selectedMoveNames: moves,
    );
  }

  group('Clamping and Stun Mechanics Tests', () {
    test('Clamped target cannot switch out, and is freed if clamp user is not active', () async {
      final basePlayer = createTestOrganism(name: 'PlayerOrg');
      final baseOpponent = createTestOrganism(name: 'OpponentOrg');

      final playerOrg = createCaptured(basePlayer, ['Clamp Attack']);
      final opponentOrg = createCaptured(baseOpponent, ['Clamp Attack']);

      final manager = BattleManager(playerOrg, opponentOrg, isTesting: true);

      // Force team list setting
      manager.playerTeam.clear();
      manager.playerTeam.addAll([playerOrg, createCaptured(basePlayer, ['Clamp Attack'])]);
      manager.opponentTeam.clear();
      manager.opponentTeam.addAll([opponentOrg, createCaptured(baseOpponent, ['Clamp Attack'])]);

      // 1. Apply clamping to opponent
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Clamp Attack')!,
      );

      expect(manager.opponent.clampingTurns, greaterThan(0));
      expect(manager.opponent.clampedBy, manager.player);
      expect(manager.opponent.isTrapped, true);

      // 2. Switch player animal out
      await manager.switchAnimal(1);

      // Clamping should be removed because the clamp user (player) is no longer active
      expect(manager.opponent.clampingTurns, 0);
      expect(manager.opponent.clampedBy, isNull);
      expect(manager.opponent.isTrapped, false);
    });

    test('Stun is blocked if target is faster than attacker', () async {
      // Attacker speed = 50, Target speed = 150
      final slowAttackerBase = createTestOrganism(speed: 50, name: 'Slow');
      final fastTargetBase = createTestOrganism(speed: 150, name: 'Fast');

      final slowAttacker = createCaptured(slowAttackerBase, ['Stun Strike']);
      final fastTarget = createCaptured(fastTargetBase, ['Stun Strike']);

      final manager = BattleManager(slowAttacker, fastTarget, isTesting: true);

      // Attempt stun on the faster target
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Stun Strike')!,
      );

      // Fast target should NOT be stunned because it's faster
      final hasStun = manager.opponent.statusEffects.any((se) => se.type == StatusEffectType.stun);
      expect(hasStun, false);
    });

    test('Stun is applied if target is slower than attacker', () async {
      // Attacker speed = 150, Target speed = 50
      final fastAttackerBase = createTestOrganism(speed: 150, name: 'Fast');
      final slowTargetBase = createTestOrganism(speed: 50, name: 'Slow');

      final fastAttacker = createCaptured(fastAttackerBase, ['Stun Strike']);
      final slowTarget = createCaptured(slowTargetBase, ['Stun Strike']);

      final manager = BattleManager(fastAttacker, slowTarget, isTesting: true);

      // Attempt stun on the slower target
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Stun Strike')!,
      );

      // Slow target SHOULD be stunned because it's slower
      final hasStun = manager.opponent.statusEffects.any((se) => se.type == StatusEffectType.stun);
      expect(hasStun, true);
    });
  });
}
