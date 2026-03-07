import '../models/ability.dart';
import '../models/status_effect.dart';
import '../models/weather.dart';
import '../models/terrain.dart';
import 'battle_models.dart';

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
    BattleOrganism? source,
  });
}
