// lib/models/ability.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

enum AbilityTrigger {
  none,
  onEntry,
  onCalculateStat,
  onDamageTaken,
  onDamageDealt,
  onStatLoss,
  onCalculateDamage,
  onCalculatePriority,
  onStatusAttempt,
  onTurnEnd,
}

enum AbilityEffectType {
  none,
  statChange, // Self or Target stat change
  statusChange, // Self or Target status
  weatherChange,
  terrainChange,
  damageMultiplier,
  statMultiplier,
  priorityBoost,
  typeChange,
  preventStatLoss,
  preventStatus,
  preventCrit,
  wakeUpFaster,
}

class Ability {
  final String name;
  final String description;
  final AbilityTrigger trigger;
  final AbilityEffectType effectType;

  // Generic parameters for different effect types
  final String targetStat; // e.g., 'attack', 'defense', 'speed'
  final double magnitude; // Multiplier (e.g., 2.0) or stat stages (e.g., -1)
  final double chance; // 0.0 to 1.0
  final List<String> conditions; // e.g., 'at_full_hp', 'contact', 'poisoned'
  final String value; // e.g., 'rain', 'flying', status name

  const Ability({
    required this.name,
    required this.description,
    this.trigger = AbilityTrigger.none,
    this.effectType = AbilityEffectType.none,
    this.targetStat = '',
    this.magnitude = 1.0,
    this.chance = 1.0,
    this.conditions = const [],
    this.value = '',
  });

  factory Ability.fromJson(Map<String, dynamic> json) {
    return Ability(
      name: json['name'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      trigger: AbilityTrigger.values.firstWhere(
        (e) => e.toString().split('.').last == json['trigger'],
        orElse: () => AbilityTrigger.none,
      ),
      effectType: AbilityEffectType.values.firstWhere(
        (e) => e.toString().split('.').last == json['effectType'],
        orElse: () => AbilityEffectType.none,
      ),
      targetStat: json['targetStat'] as String? ?? '',
      magnitude: (json['magnitude'] as num?)?.toDouble() ?? 1.0,
      chance: (json['chance'] as num?)?.toDouble() ?? 1.0,
      conditions: (json['conditions'] as List<dynamic>?)?.cast<String>() ?? [],
      value: json['value'] as String? ?? '',
    );
  }

  static List<Ability> _allAbilities = [];
  static List<Ability> get allAbilities => _allAbilities;

  static final Map<String, Ability> _byName = {};

  /// Loads abilities from the JSON asset file.
  static Future<void> loadFromJson() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/abilities.json',
      );
      final data = json.decode(response);
      if (data is List) {
        _allAbilities = data
            .map((a) => Ability.fromJson(a as Map<String, dynamic>))
            .toList();
        _byName.clear();
        for (final a in _allAbilities) {
          _byName[a.name.toLowerCase()] = a;
        }
        debugPrint('Loaded ${_allAbilities.length} abilities from JSON.');
      }
    } catch (e) {
      debugPrint('Error loading abilities from JSON: $e');
    }
  }

  static Ability? findByName(String name) {
    return _byName[name.toLowerCase()];
  }
}
