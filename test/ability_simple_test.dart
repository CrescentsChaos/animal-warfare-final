import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel(
    'xyz.luan/audioplayers',
  ).setMockMethodCallHandler((methodCall) async => null);
  const MethodChannel(
    'xyz.luan/audioplayers.global',
  ).setMockMethodCallHandler((methodCall) async => null);
  const MethodChannel(
    'plugins.flutter.io/shared_preferences',
  ).setMockMethodCallHandler((methodCall) async => {});
  const MethodChannel(
    'plugins.flutter.io/path_provider',
  ).setMockMethodCallHandler((methodCall) async => '.');

  group('New Abilities Tests', () {
    late BattleManager bm;
    late BattleOrganism player;

    Organism createBase(String abilities) {
      return Organism(
        name: 'Test',
        scientificName: 'Testus',
        habitat: 'Test',
        drops: 'Test',
        health: 100,
        attack: 100,
        defense: 100,
        power: 100,
        resistance: 100,
        speed: 100,
        abilities: abilities,
        category: 'Test',
        moves: '',
        sprite: '',
        rarity: 'Common',
        description: '',
      );
    }

    test(
      'Abyss Dweller prevents Stun status',
      () async {
        print('Running: Abyss Dweller prevents Stun status');
        final base = createBase('Abyss Dweller');
        final playerOrg = CapturedOrganism.spawn(base);
        final opponentOrg = CapturedOrganism.spawn(base);
        bm = BattleManager(playerOrg, opponentOrg);
        player = bm.player;

        await bm.testApplyStatusEffect(player, StatusEffectType.stun);
        expect(
          player.statusEffects.any((se) => se.type == StatusEffectType.stun),
          isFalse,
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Abyss Dweller prevents forced switch',
      () async {
        print('Running: Abyss Dweller prevents forced switch');
        final base = createBase('Abyss Dweller');
        final playerOrg = CapturedOrganism.spawn(base);
        final opponentOrg = CapturedOrganism.spawn(base);
        bm = BattleManager(playerOrg, opponentOrg);
        player = bm.player;

        bm.playerTeam.add(CapturedOrganism.spawn(base));

        final whirlwind = Move(
          name: 'Whirlwind',
          description: 'Forces switch.',
          baseDamage: 0,
          effects: [
            const MoveEffect(
              type: MoveEffectType.forceSwitch,
              target: 'opponent',
            ),
          ],
          category: MoveCategory.status,
        );

        await bm.testApplyMoveEffect(
          bm.opponent,
          player,
          whirlwind.effects,
          whirlwind,
        );
        expect(bm.currentPlayerIndex, 0);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Echolocation protects accuracy from being lowered',
      () async {
        print('Running: Echolocation protects accuracy from being lowered');
        final base = createBase('Echolocation');
        final playerOrg = CapturedOrganism.spawn(base);
        final opponentOrg = CapturedOrganism.spawn(base);
        bm = BattleManager(playerOrg, opponentOrg);
        player = bm.player;

        await bm.testApplyStatChange(player, 'accuracy', -1);
        expect(player.accuracyStage, 0);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Echolocation allows accuracy to be raised',
      () async {
        print('Running: Echolocation allows accuracy to be raised');
        final base = createBase('Echolocation');
        final playerOrg = CapturedOrganism.spawn(base);
        final opponentOrg = CapturedOrganism.spawn(base);
        bm = BattleManager(playerOrg, opponentOrg);
        player = bm.player;

        await bm.testApplyStatChange(player, 'accuracy', 1);
        expect(player.accuracyStage, 1);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
