import 'dart:math';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/talisman.dart';

mixin AbilityHelpers {
  // Required properties/methods from BattleManager
  WeatherEffect get currentWeather;
  set currentWeather(WeatherEffect value);
  TerrainEffect get currentTerrain;
  set currentTerrain(TerrainEffect value);
  int get weatherTurnsLeft;
  set weatherTurnsLeft(int value);
  int get terrainTurnsLeft;
  set terrainTurnsLeft(int value);

  void addToLog(String message);
  void notifyListeners();

  Future<void> notifyAbilityTrigger(BattleOrganism user, Ability ability);
  Future<void> applyStatChange(
    BattleOrganism target,
    String stat,
    int value, {
    BattleOrganism? source,
  });
  Future<void> applyStatusEffect(
    BattleOrganism target,
    StatusEffectType type, {
    int chance,
    int? duration,
  });

  // Condition checking
  bool _checkAbilityCondition(
    BattleOrganism org,
    List<String> conditions, {
    bool isCrit = false,
    bool isContact = false,
    String? moveType,
    Weather? weather,
  }) {
    for (final cond in conditions) {
      if (cond == 'crit' && !isCrit) return false;
      if (cond == 'contact' && !isContact) return false;
      if (cond == 'full_hp' && org.health < org.maxHealth) return false;
      if (cond == 'hp_below_50' && org.health >= org.maxHealth * 0.5) {
        return false;
      }
      if (cond == 'hp_below_30' && org.health >= org.maxHealth * 0.3) {
        return false;
      }
      if (cond == 'statused' && org.statusEffects.isEmpty) return false;

      if (cond.startsWith('weather_')) {
        final reqWeather = cond.replaceFirst('weather_', '');
        if (currentWeather.weather.toString().split('.').last != reqWeather) {
          return false;
        }
      }

      if (cond.startsWith('type_') && moveType != null) {
        final reqType = cond.replaceFirst('type_', '');
        if (moveType != reqType) return false;
      }
    }
    return true;
  }

  // Trigger abilities
  Future<void> _triggerAbilities(
    BattleOrganism org,
    AbilityTrigger trigger, {
    BattleOrganism? target,
    Move? move,
    bool isCrit = false,
    bool isContact = false,
  }) async {
    for (final ab in org.abilities) {
      if (ab.trigger != trigger) continue;

      final moveType = move?.type.toString().split('.').last;
      if (!_checkAbilityCondition(
        org,
        ab.conditions,
        isCrit: isCrit,
        isContact: isContact,
        moveType: moveType,
        weather: currentWeather.weather,
      )) {
        continue;
      }

      if (ab.chance < 1.0 && Random().nextDouble() > ab.chance) {
        continue;
      }

      await _applyAbilityEffect(org, ab, target: target, move: move);
    }
  }

  // Apply ability effect
  Future<void> _applyAbilityEffect(
    BattleOrganism org,
    Ability ability, {
    BattleOrganism? target,
    Move? move,
  }) async {
    await notifyAbilityTrigger(org, ability);

    switch (ability.effectType) {
      case AbilityEffectType.statChange:
        final targetOrg = target ?? org;
        await applyStatChange(
          targetOrg,
          ability.targetStat,
          ability.magnitude.round(),
          source: org,
        );
        break;

      case AbilityEffectType.statusChange:
        final targetOrg = target ?? org;
        final statusType = parseStatusType(ability.value);
        if (statusType != null) {
          await applyStatusEffect(
            targetOrg,
            statusType,
            chance: (ability.chance * 100).round(),
            duration: null, // Allow default duration logic
          );
        }
        break;

      case AbilityEffectType.weatherChange:
        await setWeatherHelper(ability.value, org);
        break;

      case AbilityEffectType.terrainChange:
        await setTerrainHelper(ability.value);
        break;

      default:
        break;
    }
  }

  StatusEffectType? parseStatusType(String name) {
    final map = {
      'poison': StatusEffectType.poison,
      'burn': StatusEffectType.burn,
      'paralysis': StatusEffectType.paralysis,
      'freeze': StatusEffectType.freeze,
      'sleep': StatusEffectType.sleep,
      'confusion': StatusEffectType.confusion,
      'blind': StatusEffectType.blind,
      'bleed': StatusEffectType.bleed,
      'regen': StatusEffectType.regen,
      'vulnerable': StatusEffectType.vulnerable,
      'stun': StatusEffectType.stun,
      'fear': StatusEffectType.fear,
      'marked': StatusEffectType.marked,
      'stealth': StatusEffectType.stealth,
    };
    return map[name.toLowerCase()];
  }

  int getWeatherDuration(BattleOrganism org, Weather w) {
    if (org.organism.equippedTalisman != null && !org.talismanConsumed) {
      for (final effect in org.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.weatherDuration &&
            effect.stat != null) {
          final stats = effect.stat!.split(',');
          final weatherName = w.name.toLowerCase();
          if (stats.any((s) => s.trim().toLowerCase() == weatherName)) {
            return effect.magnitude.toInt();
          }
        }
      }
    }
    return 5;
  }

  Future<void> setWeatherHelper(
    String weatherName, [
    BattleOrganism? org,
  ]) async {
    final weatherMap = {
      'sunny': Weather.sunny,
      'rain': Weather.rain,
      'sandstorm': Weather.sandstorm,
      'snowstorm': Weather.snowstorm,
      'hail': Weather.hail,
      'fog': Weather.fog,
      'windstorm': Weather.windstorm,
      'thunderstorm': Weather.thunderstorm,
    };

    final weather = weatherMap[weatherName.toLowerCase()];
    if (weather != null) {
      // Don't reset if already active and has turns left
      if (currentWeather.weather == weather && weatherTurnsLeft > 0) {
        return;
      }

      final duration = org != null ? getWeatherDuration(org, weather) : 5;
      currentWeather = WeatherEffect(weather: weather, duration: duration);
      weatherTurnsLeft = duration; // Sync turns left
      addToLog(currentWeather.description);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }
  }

  Future<void> setTerrainHelper(String terrainName) async {
    final terrainMap = {
      'electric': Terrain.electric,
      'grassy': Terrain.grassy,
      'misty': Terrain.misty,
      'psychic': Terrain.psychic,
    };

    final terrain = terrainMap[terrainName.toLowerCase()];
    if (terrain != null) {
      // Don't reset if already active and has turns left
      if (currentTerrain.terrain == terrain && terrainTurnsLeft > 0) {
        return;
      }

      currentTerrain = TerrainEffect(terrain: terrain, duration: 5);
      terrainTurnsLeft = 5; // Sync turns left
      addToLog(currentTerrain.description);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }
  }
}
