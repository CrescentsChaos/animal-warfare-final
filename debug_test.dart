import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel(
    'xyz.luan/audioplayers',
  ).setMockMethodCallHandler((call) async => null);
  const MethodChannel(
    'xyz.luan/audioplayers.global',
  ).setMockMethodCallHandler((call) async => null);

  print('Starting execution');
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

  final testMove = Move(
    name: 'TestMove',
    description: '50% chance.',
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

  playerOrg.moveStamina[testMove.name] = testMove.stamina;
  opponentOrg.selectedMoveNames = ['Scratch'];
  opponentOrg.moveStamina['Scratch'] = 20;

  final manager = BattleManager(playerOrg, opponentOrg, isTesting: true);
  manager.currentState = BattleState.waitingForInput;
  manager.opponent.defenseStage = 0;

  print('Calling processPlayerAction');
  final watch = Stopwatch()..start();
  await manager.processPlayerAction(testMove);
  watch.stop();

  print('Finished processPlayerAction in ${watch.elapsedMilliseconds} ms');
}
