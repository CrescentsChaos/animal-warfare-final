import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/talisman.dart';

void main() {
  final base = Organism(
    name: 'Test',
    health: 50,
    attack: 50,
    defense: 50,
    power: 50,
    resistance: 50,
    speed: 50,
    habitat: 'Forest',
    moves: 'Scratch',
    description: 'Test',
    rarity: 'Common',
  );

  final org = CapturedOrganism.spawn(base);
  final talisman = Talisman(
    id: 'test_item',
    name: 'Test Item',
    description: 'Test',
  );

  final withTalisman = org.copyWith(equippedTalisman: talisman);
  print('Equipped: ${withTalisman.equippedTalisman?.id}');

  final unequipped = withTalisman.copyWith(clearTalisman: true);
  print(
    'Unequipped (clearTalisman: true): ${unequipped.equippedTalisman == null}',
  );

  final keptTalisman = withTalisman.copyWith(currentHealth: 10);
  print(
    'Kept Talisman (no flag): ${keptTalisman.equippedTalisman?.id == 'test_item'}',
  );
}
