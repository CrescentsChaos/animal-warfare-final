// lib/models/talisman.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

enum TalismanEffectType {
  // Legacy stat boost types
  attackBoost,
  defenseBoost,
  speedBoost,
  healthBoost,
  damageMultiplier,
  resistanceBoost,
  powerBoost,
  resistanceStatBoost,
  critBoost,

  // New Pokemon-style effect types
  statBoost, // Generic stat boost (replaces specific ones above eventually)
  damageBoost, // Replaces damageMultiplier
  onTurnHeal, // Leftovers-style healing
  choiceLock, // Choice Band/Specs/Scarf
  oneHitSave, // Focus Sash
  recoilDamage, // Life Orb recoil
  blockStatusMoves, // Assault Vest
  weaknessBoost, // Weakness Policy
  lifesteal, // Shell Bell
  contactDamage, // Rocky Helmet
  conditionalHeal, // Black Sludge
  selfStatus, // Flame Orb, Toxic Orb
  categoryDamageBoost, // Muscle Band, Wise Glasses
  flinchChance, // King's Rock
  // Accuracy/Speed
  wideLens, // +10% accuracy
  zoomLens, // +20% accuracy when moving second
  quickClaw, // 20% chance to move first
  // Air Balloon / Terrain immunity
  airBalloon, // Immune to Earth-type moves, pops when hit
  // White Herb
  whiteHerb, // Restore lowered stats once
  // Berries (consumed on use)
  berryHealPercent, // Sitrus Berry: heal % HP when HP < threshold
  berryHealFlat, // Oran Berry: heal flat HP when HP < threshold
  berryCureStatus, // Lum/Rawst/Cheri etc: cure specific/all status
  berryStatBoost, // Salac/Petaya/Liechi: +1 stat stage when HP < threshold
  berryCritBoost, // Lansat Berry: crit boost when HP < threshold
  berryEnigma, // Enigma Berry: heal on super-effective hit
  berryJaboca, // Jaboca/Rowap Berry: damage attacker when hit by physical/special
  powerHerb, // Bypass charging turn once
  berryTypeResist, // Reduce damage from super-effective hit of specific type
  weatherDuration, // Extend weather duration (Damp Rock, etc.)
  gemBoost, // 1.5x damage for specific type, single use
  drainBoost, // Big Root: increase healing from drain moves
  bindingBandBoost, // Binding Band: increase trapping damage
  missStatBoost, // Blunder Policy: +2 speed on miss
  priorityLowHp, // Custap Berry: move first at low HP once
  hazardImmunity, // Heavy-Duty Boots: immune to hazards
}

class TalismanEffect {
  final TalismanEffectType type;
  final double magnitude;
  final String? stat; // For stat-specific effects (e.g., "attack", "speed")
  final String? condition; // For conditional effects
  final String? category; // For move category effects (physical/special)
  final String? status; // For status effects
  final double threshold; // For berry HP-threshold effects (e.g. 0.5 = 50% HP)
  final String?
  curesStatus; // For berry_cure_status: "all", "burn", "poison", etc.

  const TalismanEffect({
    required this.type,
    required this.magnitude,
    this.stat,
    this.condition,
    this.category,
    this.status,
    this.threshold = 0.0,
    this.curesStatus,
  });

  factory TalismanEffect.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    TalismanEffectType type;

    // Map string to enum
    switch (typeStr) {
      case 'stat_boost':
        type = TalismanEffectType.statBoost;
        break;
      case 'damage_boost':
        type = TalismanEffectType.damageBoost;
        break;
      case 'resistance_boost':
        type = TalismanEffectType.resistanceBoost;
        break;
      case 'crit_boost':
        type = TalismanEffectType.critBoost;
        break;
      case 'on_turn_heal':
        type = TalismanEffectType.onTurnHeal;
        break;
      case 'choice_lock':
        type = TalismanEffectType.choiceLock;
        break;
      case 'one_hit_save':
        type = TalismanEffectType.oneHitSave;
        break;
      case 'recoil_damage':
        type = TalismanEffectType.recoilDamage;
        break;
      case 'block_status_moves':
        type = TalismanEffectType.blockStatusMoves;
        break;
      case 'weakness_boost':
        type = TalismanEffectType.weaknessBoost;
        break;
      case 'lifesteal':
        type = TalismanEffectType.lifesteal;
        break;
      case 'contact_damage':
        type = TalismanEffectType.contactDamage;
        break;
      case 'conditional_heal':
        type = TalismanEffectType.conditionalHeal;
        break;
      case 'self_status':
        type = TalismanEffectType.selfStatus;
        break;
      case 'category_damage_boost':
        type = TalismanEffectType.categoryDamageBoost;
        break;
      case 'flinch_chance':
        type = TalismanEffectType.flinchChance;
        break;
      case 'wide_lens':
        type = TalismanEffectType.wideLens;
        break;
      case 'zoom_lens':
        type = TalismanEffectType.zoomLens;
        break;
      case 'quick_claw':
        type = TalismanEffectType.quickClaw;
        break;
      case 'air_balloon':
        type = TalismanEffectType.airBalloon;
        break;
      case 'white_herb':
        type = TalismanEffectType.whiteHerb;
        break;
      case 'berry_heal_percent':
        type = TalismanEffectType.berryHealPercent;
        break;
      case 'berry_heal_flat':
        type = TalismanEffectType.berryHealFlat;
        break;
      case 'berry_cure_status':
        type = TalismanEffectType.berryCureStatus;
        break;
      case 'berry_stat_boost':
        type = TalismanEffectType.berryStatBoost;
        break;
      case 'berry_crit_boost':
        type = TalismanEffectType.berryCritBoost;
        break;
      case 'berry_enigma':
        type = TalismanEffectType.berryEnigma;
        break;
      case 'berry_jaboca':
        type = TalismanEffectType.berryJaboca;
        break;
      case 'power_herb':
        type = TalismanEffectType.powerHerb;
        break;
      case 'berry_type_resist':
        type = TalismanEffectType.berryTypeResist;
        break;
      case 'weather_duration':
        type = TalismanEffectType.weatherDuration;
        break;
      case 'gem_boost':
        type = TalismanEffectType.gemBoost;
        break;
      case 'drain_boost':
        type = TalismanEffectType.drainBoost;
        break;
      case 'binding_band_boost':
        type = TalismanEffectType.bindingBandBoost;
        break;
      case 'miss_stat_boost':
        type = TalismanEffectType.missStatBoost;
        break;
      case 'priority_low_hp':
        type = TalismanEffectType.priorityLowHp;
        break;
      case 'hazard_immunity':
        type = TalismanEffectType.hazardImmunity;
        break;
      default:
        type = TalismanEffectType.statBoost; // Fallback
    }

    return TalismanEffect(
      type: type,
      magnitude: (json['magnitude'] as num).toDouble(),
      stat: json['stat'] as String?,
      condition: json['condition'] as String?,
      category: json['category'] as String?,
      status: json['status'] as String?,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      curesStatus: json['curesStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'type': type.toString().split('.').last,
      'magnitude': magnitude,
    };
    if (stat != null) data['stat'] = stat;
    if (condition != null) data['condition'] = condition;
    if (category != null) data['category'] = category;
    if (status != null) data['status'] = status;
    if (threshold > 0) data['threshold'] = threshold;
    if (curesStatus != null) data['curesStatus'] = curesStatus;
    return data;
  }
}

class Talisman {
  final String id;
  final String name;
  final String description;
  final List<TalismanEffect> effects;

  const Talisman({
    required this.id,
    required this.name,
    required this.description,
    required this.effects,
  });

  String get spritePath =>
      'assets/items/${name.toLowerCase().replaceAll(' ', '-')}.png';

  // Loaded talismans list
  static List<Talisman> allTalismans = [];
  static final Map<String, Talisman> _byId = {};

  // Load talismans from JSON
  static Future<void> loadFromJson() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/talismans.json',
      );
      final List<dynamic> data = json.decode(response);
      allTalismans = data.map((json) => Talisman.fromJson(json)).toList();
      _byId.clear();
      for (final t in allTalismans) {
        _byId[t.id] = t;
      }
    } catch (e) {
      print('Error loading talismans: $e');
      // Fallback to empty list or hardcoded defaults
      allTalismans = [];
      _byId.clear();
    }
  }

  static Talisman? findByName(String name) {
    try {
      return allTalismans.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  factory Talisman.fromJson(Map<String, dynamic> json) {
    final effectsJson = json['effects'];
    if (effectsJson == null || effectsJson is! List) {
      // If no effects list, try to lookup by ID or return default
      return findById(json['id'] as String? ?? '') ??
          const Talisman(
            id: 'none',
            name: 'None',
            description: 'No talisman equipped',
            effects: [],
          );
    }

    final effects = effectsJson
        .map((e) => TalismanEffect.fromJson(e as Map<String, dynamic>))
        .toList();

    return Talisman(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      effects: effects,
    );
  }

  static Talisman? findById(String id) {
    return _byId[id];
  }

  Map<String, dynamic> toJson() => {'id': id};

  // For backward compatibility with old save files that only stored 'id'
  factory Talisman.fromJsonWithId(Map<String, dynamic> json) {
    return findById(json['id'] as String) ??
        // Fallback to first talisman if ID not found
        (allTalismans.isNotEmpty
            ? allTalismans[0]
            : const Talisman(
                id: 'none',
                name: 'None',
                description: 'No talisman equipped',
                effects: [],
              ));
  }

  // Helper getter for backward compatibility
  TalismanEffect get effect => effects.isNotEmpty
      ? effects.first
      : const TalismanEffect(
          type: TalismanEffectType.statBoost,
          magnitude: 1.0,
        );

  // Returns true if this talisman is a berry (single-use)
  bool get isBerry => effects.any(
    (e) =>
        e.type == TalismanEffectType.berryHealPercent ||
        e.type == TalismanEffectType.berryHealFlat ||
        e.type == TalismanEffectType.berryCureStatus ||
        e.type == TalismanEffectType.berryStatBoost ||
        e.type == TalismanEffectType.berryCritBoost ||
        e.type == TalismanEffectType.berryEnigma ||
        e.type == TalismanEffectType.berryJaboca,
  );

  // Returns true if this talisman is a single-use item
  bool get isSingleUse =>
      isBerry ||
      effects.any(
        (e) =>
            e.type == TalismanEffectType.whiteHerb ||
            e.type == TalismanEffectType.quickClaw ||
            e.type == TalismanEffectType.powerHerb ||
            e.type == TalismanEffectType.berryTypeResist ||
            e.type == TalismanEffectType.gemBoost,
      );
}
