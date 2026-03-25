// ignore_for_file: avoid_print
// lib/models/move.dart
// Defines the structure for an animal's attack.
//
// ═══════════════════════════════════════════════════════════════════════════════
// TEMPLATE: How to add a new move with damage and/or effects
// ═══════════════════════════════════════════════════════════════════════════════
// Add a new entry to the _allMoves list below. Match the name exactly to your
// Organisms.json "moves" field (e.g. "Pounce,Scratch,Bite,Tail Whip").
//
// 1) Pure damage (no effect):
//    Move(name: 'Pounce', description: 'Leap at the foe.', baseDamage: 25, accuracy: 95),
//
// 2) Damage + poison (Status Effect):
//    Move(name: 'Venom Sting', description: 'May poison.', baseDamage: 12, accuracy: 90,
//      effects: [MoveEffect(type: MoveEffectType.statusPoison, target: 'opponent', value: 3)]), // Value is duration or severity
//
// 3) Stat Change (Raise your defense):
//    Move(name: 'Harden', description: 'Raises defense.', baseDamage: 0,
//      effects: [MoveEffect(type: MoveEffectType.statChange, target: 'self', stat: 'defense', value: 1)]),
//
// 4) Weather Change:
//    Move(name: 'Rain Dance', description: 'Summons rain.', baseDamage: 0,
//      effects: [MoveEffect(type: MoveEffectType.weather, target: 'field', stat: 'rain', value: 5)]),
//
// 5) Terrain Change:
//    Move(name: 'Electric Terrain', description: 'Electrifies ground.', baseDamage: 0,
//      effects: [MoveEffect(type: MoveEffectType.terrain, target: 'field', stat: 'electric', value: 5)]),
//
// Effect types: none, statusPoison, statusSleep, statusBurn, statusParalysis, statChange, heal, weather, terrain.
//
// 6) Complex Mechanics:
//    Move(name: 'Quick Attack', description: 'Strikes first.', baseDamage: 40, priority: 1),
//    Move(name: 'Double Slap', description: 'Hits 2-5 times.', baseDamage: 15, minHits: 2, maxHits: 5),
//    Move(name: 'Drain Punch', description: 'Heals half damage dealt.', baseDamage: 75, drainPercent: 0.5),
//    Move(name: 'Take Down', description: 'Hurts user.', baseDamage: 90, recoilPercent: 0.25),
//    Move(name: 'Slash', description: 'High crit rate.', baseDamage: 70, critRate: 1),
//
// Effect types: ... statusBleed, statusConfusion, statusBlind, statusRegen, statusVulnerable, statusStun ...
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:animal_warfare/models/weather.dart';

// Enum for the type of effect a move can apply
enum MoveEffectType {
  none,
  statusPoison,
  statusSleep,
  statusBurn,
  statusParalysis,
  statusFreeze,
  statChange,
  heal,
  weather, // Changes Weather
  terrain, // Changes Terrain
  // New Effect Types
  statusBleed,
  statusConfusion,
  statusBlind,
  statusRegen,
  statusVulnerable,
  statusStun,
  statusFear,
  statusMarked,
  statusStealth,
  // New Effect Types for Complex Moves
  multiStatChange,
  recharge,
  charge,
  protect,
  semiInvulnerable,
  statChangeChance,
  forceSwitch,
  setHazard,
  forceSwitchSelf, // Teleport
  damageAndSwitchSelf, // U-turn
  cureTeamStatus, // Aromatherapy
  changeType, // Soak
  setScreen, // Reflect, Light Screen, etc
  trickRoom,
  tailwind,
  perishSong,
  finalGambit,
  substitute,
  rollout,
  iceBall,
  defenseCurl,
  futureSight,
  metronome,
  acupressure,
  assist,
  copycat,
  magnitude,
  trapIndices,
  clamping,
  defog,
  throatChop,
  filletAway,
  falseSwipe,
  belch,
  moveFirstBoost,
  weightDamage,
  hpRatioDamage,
  flailDamage,
  happinessDamage,
  gigatonHammer,
  glaiveRush,
  weightOpponentDamage,
  grassyGlide,
  gravity,
  gyroBallDamage,
  skullBash,
  healingWish,
  wish,
  healBlock,
  hexDamage,
  highJumpKick,
  jungleHealing,
  lastResort,
  memento,
  meteorBeam,
  mindBlown,
  miracleEye,
  counter,
  mirrorCoat,
  payDay,
  shellTrap,
  weatherBall,
  hiddenPower,
  multiAttack,
  judgement,
  thrash,
  statusCurse,
  fixedDamage,
  levelDamage,
  psywave,
  sleepTalk,
  snore,
  magicCoat,
  teraBlast,
  safeguard,
  growth,
  rapidSpin,
  thief,
  iceSpinner,
  stockpile,
  swallow,
  spitUp,
  payback,
}

enum MoveCategory { physical, special, status }

/// Controls how many targets a move hits in doubles.
/// [single] — targets one slot (default).
/// [multiple] — hits all opponents simultaneously (75 % damage each).
enum MoveTargetCount { single, multiple }

extension MoveCategoryExtension on MoveCategory {
  Color get color {
    switch (this) {
      case MoveCategory.physical:
        return const Color(0xFFFF4444); // Red-Orange
      case MoveCategory.special:
        return const Color(0xFF4488FF); // Blue
      case MoveCategory.status:
        return Colors.white70; // Off-white/Gray
    }
  }
}

// Model for the effect component of a Move
class MoveEffect {
  final MoveEffectType type;
  final String target; // 'self', 'opponent', 'field'
  final String stat; // e.g., 'attack', 'defense', 'rain', 'electric'
  final int value; // Magnitude, duration, or probability
  final int chance; // Probability (0-100)
  final double hpCostPercent; // % of user's max HP to consume

  const MoveEffect({
    required this.type,
    this.target = 'opponent',
    this.stat = '',
    this.value = 0,
    this.chance = 100,
    this.hpCostPercent = 0.0,
  });

  // Constructor for loading effects from JSON
  factory MoveEffect.fromJson(Map<String, dynamic> json) {
    return MoveEffect(
      type: MoveEffectType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MoveEffectType.none,
      ),
      target: json['target'] as String? ?? 'opponent',
      stat: json['stat'] as String? ?? '',
      value: json['value'] as int? ?? 0,
      chance: json['chance'] as int? ?? 100,
      hpCostPercent: (json['hpCostPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Helper to map string stat to Weather enum
  Weather get weather {
    switch (stat.toLowerCase()) {
      case 'rain':
        return Weather.rain;
      case 'sun':
      case 'sunny':
        return Weather.sunny;
      case 'sandstorm':
        return Weather.sandstorm;
      case 'hail':
      case 'snow':
      case 'snowstorm':
        return Weather.hail;
      default:
        return Weather.none;
    }
  }
}

class Move {
  final String name;
  final String description;
  final int baseDamage;
  final int accuracy; // 0 to 100
  final List<MoveEffect> effects;
  final int priority; // Higher goes first
  final int critRate; // 0=4%, 1=12.5%, 2=50%, 3+=100%
  final double drainPercent; // % of damage heals user
  final double recoilPercent; // % of damage hurts user
  final int minHits; // For multi-hit moves
  final int maxHits;
  final ElementalType type; // NEW: Elemental Type of the move
  final int stamina; // NEW: PP equivalent
  final MoveCategory category; // NEW: physical, special, status
  final String? customUsageText; // Custom text when using the move
  final MoveTargetCount targetCount; // single (default) or multiple
  final String?
  animationType; // NEW: Animation type flag (e.g., 'blob', 'slash', 'brave_bird')

  final bool isPunch;
  final bool isBite;

  final bool isSelfDestruct;
  final bool isContact;
  final bool isPowder;
  final bool isPulse;
  final bool isBallBomb;
  final bool isAura;

  // Audio fields
  final String? soundEffect; // Optional path to sound effect file
  final String? battleMusic; // Optional path to custom battle music

  // Versatility fields
  final String
  damageStat; // 'attack', 'defense', 'speed', 'power', 'resistance'
  final String
  multiplierCondition; // 'target_poisoned', 'target_damaged', 'user_charged'
  final String targetDefenseStat; // 'defense', 'resistance', 'speed', etc.
  final double conditionalMultiplier;
  final bool failIfTargetNotAttacking;

  static const int defaultStamina = 20;

  const Move({
    required this.name,
    required this.description,
    required this.baseDamage,
    this.accuracy = 100,
    this.effects = const [],
    this.priority = 0,
    this.critRate = 0,
    this.drainPercent = 0.0,
    this.recoilPercent = 0.0,
    this.minHits = 1,
    this.maxHits = 1,
    this.type = ElementalType.basic, // Default
    this.stamina = defaultStamina, // Default stamina
    this.category = MoveCategory.physical, // Default
    this.damageStat =
        '', // Default empty (will be derived from category if empty)
    this.targetDefenseStat =
        '', // Default empty (will be derived from category if empty)
    this.multiplierCondition = '',
    this.conditionalMultiplier = 1.0,
    this.failIfTargetNotAttacking = false,
    this.customUsageText,
    this.soundEffect,
    this.battleMusic,
    this.targetCount = MoveTargetCount.single,
    this.animationType,
    this.isPunch = false,
    this.isBite = false,

    this.isSelfDestruct = false,
    this.isPowder = false,
    this.isPulse = false,
    this.isBallBomb = false,
    this.isAura = false,
    bool? isContact,
  }) : isContact =
           isContact ?? (category == MoveCategory.physical && baseDamage > 0);

  // Compatibility getter
  MoveEffect get effect => effects.isNotEmpty
      ? effects.first
      : const MoveEffect(type: MoveEffectType.none);

  // Helper for multi-turn moves
  bool get isMultiTurn => effects.any(
    (e) =>
        e.type == MoveEffectType.charge ||
        e.type == MoveEffectType.recharge ||
        e.type == MoveEffectType.semiInvulnerable ||
        e.type == MoveEffectType.meteorBeam ||
        e.type == MoveEffectType.skullBash,
  );

  // Constructor for loading Move from JSON
  factory Move.fromJson(Map<String, dynamic> json) {
    final baseDamage = json['baseDamage'] as int? ?? 0;
    final categoryStr = json['category'] as String?;
    final category = categoryStr != null
        ? MoveCategory.values.firstWhere(
            (e) => e.toString().split('.').last == categoryStr,
            orElse: () => MoveCategory.physical,
          )
        : (baseDamage > 0 ? MoveCategory.physical : MoveCategory.status);

    // Handle both single 'effect' and multiple 'effects' in JSON
    List<MoveEffect> effectsList = [];
    if (json['effects'] != null) {
      effectsList = (json['effects'] as List)
          .map((e) => MoveEffect.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['effect'] != null) {
      effectsList = [
        MoveEffect.fromJson(json['effect'] as Map<String, dynamic>),
      ];
    }

    return Move(
      name: json['name'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      baseDamage: baseDamage,
      accuracy: json['accuracy'] as int? ?? 100,
      effects: effectsList,
      priority: json['priority'] as int? ?? 0,
      critRate: json['critRate'] as int? ?? 0,
      drainPercent: (json['drainPercent'] as num?)?.toDouble() ?? 0.0,
      recoilPercent: (json['recoilPercent'] as num?)?.toDouble() ?? 0.0,
      minHits: json['minHits'] as int? ?? 1,
      maxHits: json['maxHits'] as int? ?? 1,
      type: json['type'] != null
          ? ElementalTypeX.fromString(json['type'] as String)
          : ElementalType.basic,
      stamina: json['stamina'] as int? ?? defaultStamina,
      category: category,
      damageStat:
          json['damageStat'] as String? ??
          (category == MoveCategory.special ? 'power' : 'attack'),
      targetDefenseStat:
          json['targetDefenseStat'] as String? ??
          (category == MoveCategory.special ? 'resistance' : 'defense'),
      multiplierCondition: json['multiplierCondition'] as String? ?? '',
      conditionalMultiplier:
          (json['conditionalMultiplier'] as num?)?.toDouble() ?? 1.0,
      failIfTargetNotAttacking:
          json['failIfTargetNotAttacking'] as bool? ?? false,
      customUsageText: json['customUsageText'] as String?,
      soundEffect: json['soundEffect'] as String?,
      battleMusic: json['battleMusic'] as String?,
      isContact: json['isContact'] as bool?,
      isPunch: json['isPunch'] as bool? ?? false,
      isBite: json['isBite'] as bool? ?? false,

      isPowder:
          json['isPowder'] as bool? ??
          (json['name'] == 'Spore' ||
              json['name'].toString().contains('Powder')),
      isSelfDestruct:
          json['isSelfDestruct'] as bool? ??
          (json['name'] == 'Self-Destruct' ||
              json['name'] == 'Explosion' ||
              json['name'] == 'Mind Blown' ||
              json['name'] == 'Misty Explosion' ||
              effectsList.any(
                (e) =>
                    e.type == MoveEffectType.finalGambit ||
                    e.type == MoveEffectType.memento,
              )),
      targetCount: json['targetCount'] != null
          ? MoveTargetCount.values.firstWhere(
              (e) => e.toString().split('.').last == json['targetCount'],
              orElse: () => MoveTargetCount.single,
            )
          : MoveTargetCount.single,
      animationType: json['animationType'] as String?,
      isPulse: json['isPulse'] as bool? ?? false,
      isBallBomb: json['isBallBomb'] as bool? ?? false,
      isAura: json['isAura'] as bool? ?? false,
    );
  }

  Move copyWith({
    String? name,
    String? description,
    int? baseDamage,
    int? accuracy,
    List<MoveEffect>? effects,
    int? priority,
    int? critRate,
    double? drainPercent,
    double? recoilPercent,
    int? minHits,
    int? maxHits,
    ElementalType? type,
    int? stamina,
    MoveCategory? category,
    String? customUsageText,
    MoveTargetCount? targetCount,
    String? soundEffect,
    String? battleMusic,
    String? damageStat,
    String? multiplierCondition,
    String? targetDefenseStat,
    double? conditionalMultiplier,
    bool? failIfTargetNotAttacking,
    bool? isPunch,
    bool? isBite,
    bool? isSelfDestruct,
    bool? isContact,
    bool? isPowder,
    bool? isPulse,
    bool? isBallBomb,
    bool? isAura,
    String? animationType,
  }) {
    return Move(
      name: name ?? this.name,
      description: description ?? this.description,
      baseDamage: baseDamage ?? this.baseDamage,
      accuracy: accuracy ?? this.accuracy,
      effects: effects ?? this.effects,
      priority: priority ?? this.priority,
      critRate: critRate ?? this.critRate,
      drainPercent: drainPercent ?? this.drainPercent,
      recoilPercent: recoilPercent ?? this.recoilPercent,
      minHits: minHits ?? this.minHits,
      maxHits: maxHits ?? this.maxHits,
      type: type ?? this.type,
      stamina: stamina ?? this.stamina,
      category: category ?? this.category,
      customUsageText: customUsageText ?? this.customUsageText,
      targetCount: targetCount ?? this.targetCount,
      soundEffect: soundEffect ?? this.soundEffect,
      battleMusic: battleMusic ?? this.battleMusic,
      damageStat: damageStat ?? this.damageStat,
      multiplierCondition: multiplierCondition ?? this.multiplierCondition,
      targetDefenseStat: targetDefenseStat ?? this.targetDefenseStat,
      conditionalMultiplier:
          conditionalMultiplier ?? this.conditionalMultiplier,
      failIfTargetNotAttacking:
          failIfTargetNotAttacking ?? this.failIfTargetNotAttacking,
      isPunch: isPunch ?? this.isPunch,
      isBite: isBite ?? this.isBite,
      isSelfDestruct: isSelfDestruct ?? this.isSelfDestruct,
      isContact: isContact ?? this.isContact,
      isPowder: isPowder ?? this.isPowder,
      isPulse: isPulse ?? this.isPulse,
      isBallBomb: isBallBomb ?? this.isBallBomb,
      isAura: isAura ?? this.isAura,
      animationType: animationType ?? this.animationType,
    );
  }

  static List<Move> _allMoves = [];
  static List<Move> get allMoves => _allMoves;

  static final Map<String, Move> _byName = {};

  /// Loads moves from the JSON asset file.
  static Future<void> loadFromJson() async {
    try {
      final String response = await rootBundle.loadString('assets/moves.json');
      final data = json.decode(response);
      if (data is List) {
        _allMoves = data
            .map((m) => Move.fromJson(m as Map<String, dynamic>))
            .toList();
        _byName.clear();
        for (final m in _allMoves) {
          _byName[m.name.toLowerCase()] = m;
        }
        print('Loaded ${_allMoves.length} moves from JSON.');
      }
    } catch (e) {
      print('Error loading moves from JSON: $e');
    }
  }

  static Move? findByName(String name) {
    final lowerName = name.trim().toLowerCase();
    if (_byName.containsKey(lowerName)) return _byName[lowerName];
    // Fallback for tests or dynamic moves
    try {
      return _allMoves.firstWhere((m) => m.name.toLowerCase() == lowerName);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void addTestMove(Move move) {
    _byName[move.name.toLowerCase()] = move;
  }

  /// Create a move by name. If not in the predefined list, returns a move with
  /// that name and random base damage (for DB moves not yet defined).
  static Move findOrCreate(String name, [Random? random]) {
    final existing = findByName(name);
    if (existing != null) return existing;
    final rng = random ?? Random();
    final baseDamage = 5 + rng.nextInt(21); // 5–25 placeholder damage
    return Move(
      name: name.trim().isEmpty ? 'Struggle' : name.trim(),
      description: 'A natural attack.',
      baseDamage: baseDamage,
      accuracy: 85 + rng.nextInt(16), // 85–100
      stamina: defaultStamina,
    );
  }
}
