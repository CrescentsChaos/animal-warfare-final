import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/models/nature.dart';

void main() {
  test('BattleOrganism scales to Level 50 when NOT in Rogue mode', () {
    final base = Organism(
      name: 'Test',
      scientificName: 'Test',
      habitat: 'Test',
      drops: '',
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      health: 100,
      speed: 100,
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
      level: 5, // Low level
      individualValues: {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      },
      currentHealth: 1,
      selectedMoveNames: ['Bite'],
      nature: const Nature(
        name: 'Hardy',
        increasedStat: NatureStat.attack,
        decreasedStat: NatureStat.attack,
      ),
    );

    // Expected HP at Level 50: ((100 + 15) * 2 * 50 / 50) + 10 + 50 = 230 + 60 = 290
    // Actually using formula: ((baseStat + (iv / 2).floor()) * 2 * levelMultiplier).floor() + statConstant + level
    // (100 + 15) * 2 * 1 + 10 + 50 = 230 + 10 + 50 = 290.

    // Expected Attack at Level 50: ((100 + 15) * 1) + 10 = 115 + 10 = 125.

    final bm = BattleManager(
      playerOrg,
      playerOrg, // Opponent same as player for simplicity
      isRogueMode: false,
    );

    expect(bm.player.maxHealth, 290);
    expect(bm.player.currentAttack, 125);
    expect(bm.player.health, 290); // Should be full health at scale
  });

  test('BattleOrganism respects level when IN Rogue mode', () {
    final base = Organism(
      name: 'Test',
      scientificName: 'Test',
      habitat: 'Test',
      drops: '',
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      health: 100,
      speed: 100,
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
      level: 5, // Low level
      individualValues: {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      },
      currentHealth: 1,
      selectedMoveNames: ['Bite'],
      nature: const Nature(
        name: 'Hardy',
        increasedStat: NatureStat.attack,
        decreasedStat: NatureStat.attack,
      ),
    );

    // Expected HP at Level 5: ((100 + 15) * 2 * 5 / 50) + 10 + 5 = (230 * 0.1) + 15 = 23 + 15 = 38
    // Expected Attack at Level 5: ((100 + 15) * 5 / 50) + 10 = (115 * 0.1) + 10 = 11 + 10 = 21

    final bm = BattleManager(playerOrg, playerOrg, isRogueMode: true);

    expect(bm.player.maxHealth, 38);
    expect(bm.player.currentAttack, 21);
    expect(bm.player.health, 1); // Should respect currentHealth in Rogue mode
  });
}
