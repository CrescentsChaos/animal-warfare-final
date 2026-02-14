import 'dart:math';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/game/battle_models.dart';

mixin AbilityHelpers {
  // Required properties/methods from BattleManager
  WeatherEffect get currentWeather;
  set currentWeather(WeatherEffect value);
  TerrainEffect get currentTerrain;
  set currentTerrain(TerrainEffect value);

  void _addToLog(String message);
  void notifyListeners();

  Future<void> _notifyAbilityTrigger(BattleOrganism user, Ability ability);
  Future<void> _applyStatChange(BattleOrganism target, String stat, int value);

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
      if (cond == 'hp_below_50' && org.health >= org.maxHealth * 0.5)
        return false;
      if (cond == 'hp_below_30' && org.health >= org.maxHealth * 0.3)
        return false;
      if (cond == 'statused' && org.statusEffects.isEmpty) return false;

      if (cond.startsWith('weather_')) {
        final reqWeather = cond.replaceFirst('weather_', '');
        if (currentWeather?.weather.toString().split('.').last != reqWeather)
          return false;
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
    int? damageDealt,
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
    await _notifyAbilityTrigger(org, ability);

    switch (ability.effectType) {
      case AbilityEffectType.statChange:
        final targetOrg = target ?? org;
        await _applyStatChange(
          targetOrg,
          ability.targetStat,
          ability.magnitude.round(),
        );
        break;

      case AbilityEffectType.statusChange:
        final targetOrg = target ?? org;
        final statusType = _parseStatusType(ability.value);
        if (statusType != null) {
          final status = StatusEffect(type: statusType, duration: 0);
          targetOrg.addStatusEffect(status);
          _addToLog('${targetOrg.organism.name} is ${ability.value}!');
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        break;

      case AbilityEffectType.weatherChange:
        await _setWeatherHelper(ability.value);
        break;

      case AbilityEffectType.terrainChange:
        await _setTerrainHelper(ability.value);
        break;

      default:
        break;
    }
  }

  StatusEffectType? _parseStatusType(String name) {
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

  Future<void> _setWeatherHelper(String weatherName) async {
    final weatherMap = {
      'heatwave': Weather.heatwave,
      'rain': Weather.rain,
      'sandstorm': Weather.sandstorm,
      'snow': Weather.snow,
      'blizzard': Weather.blizzard,
      'fog': Weather.fog,
      'windstorm': Weather.windstorm,
      'thunderstorm': Weather.thunderstorm,
    };

    final weather = weatherMap[weatherName.toLowerCase()];
    if (weather != null) {
      currentWeather = WeatherEffect(weather: weather, duration: 5);
      _addToLog(currentWeather.description);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }
  }

  Future<void> _setTerrainHelper(String terrainName) async {
    final terrainMap = {
      'electric': Terrain.electric,
      'grassy': Terrain.grassy,
      'misty': Terrain.misty,
      'psychic': Terrain.psychic,
    };

    final terrain = terrainMap[terrainName.toLowerCase()];
    if (terrain != null) {
      currentTerrain = TerrainEffect(terrain: terrain, duration: 5);
      _addToLog(currentTerrain.description);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }
  }
}
