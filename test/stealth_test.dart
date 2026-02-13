import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/move.dart';

void main() {
  group('Stealth and Camouflage Carapace Tests', () {
    final baseOrganism = Organism(
      name: 'TestAnimal',
      scientificName: 'Testus Animalus',
      habitat: 'Plain',
      drops: 'Meat',
      health: 100,
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      speed: 100,
      abilities: '',
      category: 'Test',
      moves: 'Scratch',
      sprite: 'test.png',
      rarity: 'Common',
      description: 'Test',
      types: ['normal'],
    );

    CapturedOrganism createCaptured(String name, {String abilities = ''}) {
      return CapturedOrganism(
        baseOrganism: baseOrganism.copyWith(name: name, abilities: abilities),
        individualValues: {
          'health': 31,
          'attack': 31,
          'defense': 31,
          'power': 31,
          'resistance': 31,
          'speed': 31,
        },
        currentHealth: 100,
        level: 50,
      );
    }

    test('Stealth provides 2x damage dealt', () {
      final playerCap = createCaptured('Player');
      final opponentCap = createCaptured('Opponent');
      final manager = BattleManager(playerCap, opponentCap);

      final scratch = Move.findOrCreate('Scratch');

      // Calculate damage without stealth
      final damageNormal = manager.calculateDamage(
        manager.player,
        manager.opponent,
        scratch,
      );

      // Add stealth to player
      manager.player.addStatusEffect(
        const StatusEffect(type: StatusEffectType.stealth),
      );

      // Calculate damage with stealth
      final damageStealth = manager.calculateDamage(
        manager.player,
        manager.opponent,
        scratch,
      );

      expect(damageStealth.damage > damageNormal.damage * 1.5, true);
    });

    test('Stealth provides 2x damage taken', () {
      final playerCap = createCaptured('Player');
      final opponentCap = createCaptured('Opponent');
      final manager = BattleManager(playerCap, opponentCap);

      final scratch = Move.findOrCreate('Scratch');

      // Calculate damage without stealth
      final damageNormal = manager.calculateDamage(
        manager.opponent,
        manager.player,
        scratch,
      );

      // Add stealth to player
      manager.player.addStatusEffect(
        const StatusEffect(type: StatusEffectType.stealth),
      );

      // Calculate damage with stealth
      final damageStealth = manager.calculateDamage(
        manager.opponent,
        manager.player,
        scratch,
      );

      expect(damageStealth.damage > damageNormal.damage * 1.5, true);
    });

    test('Camouflage Carapace applies Stealth in Swamp', () async {
      final playerCap = createCaptured(
        'Player',
        abilities: 'Camouflage Carapace',
      );
      final opponentCap = createCaptured('Opponent');

      // Initializing BattleManager triggers _initializeSequence and _checkEntranceAbility
      final manager = BattleManager(playerCap, opponentCap, biomeName: 'Swamp');

      // Wait for async initialization (BattleManager intro 3s + ability trigger 3s)
      await Future.delayed(const Duration(milliseconds: 7000));

      expect(
        manager.player.statusEffects.any(
          (se) => se.type == StatusEffectType.stealth,
        ),
        true,
      );
    });

    test('Camouflage Carapace does NOT apply Stealth in Plains', () async {
      final playerCap = createCaptured(
        'Player',
        abilities: 'Camouflage Carapace',
      );
      final opponentCap = createCaptured('Opponent');

      final manager = BattleManager(
        playerCap,
        opponentCap,
        biomeName: 'Plains',
      );

      // Wait for async initialization
      await Future.delayed(const Duration(milliseconds: 7000));

      expect(
        manager.player.statusEffects.any(
          (se) => se.type == StatusEffectType.stealth,
        ),
        false,
      );
    });
  });
}
