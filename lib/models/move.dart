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

import 'package:animal_warfare/models/elemental_type.dart';

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
}

enum MoveCategory { physical, special, status }

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

  // Versatility fields
  final String
  damageStat; // 'attack', 'defense', 'speed', 'power', 'resistance'
  final String
  multiplierCondition; // 'target_poisoned', 'target_damaged', 'user_charged'
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
    this.type = ElementalType.normal, // Default
    this.stamina = defaultStamina, // Default stamina
    this.category = MoveCategory.physical, // Default
    this.damageStat =
        '', // Default empty (will be derived from category if empty)
    this.multiplierCondition = '',
    this.conditionalMultiplier = 1.0,
    this.failIfTargetNotAttacking = false,
    this.customUsageText,
    bool? isContact,
  }) : isContact =
           isContact ?? (category == MoveCategory.physical && baseDamage > 0);

  final bool isContact;

  // Compatibility getter
  MoveEffect get effect => effects.isNotEmpty
      ? effects.first
      : const MoveEffect(type: MoveEffectType.none);

  // Helper for multi-turn moves
  bool get isMultiTurn => effects.any(
    (e) =>
        e.type == MoveEffectType.charge ||
        e.type == MoveEffectType.recharge ||
        e.type == MoveEffectType.semiInvulnerable,
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
          ? ElementalType.values.firstWhere(
              (e) => e.toString().split('.').last == json['type'],
              orElse: () => ElementalType.normal,
            )
          : ElementalType.normal,
      stamina: json['stamina'] as int? ?? defaultStamina,
      category: category,
      damageStat:
          json['damageStat'] as String? ??
          (category == MoveCategory.special ? 'power' : 'attack'),
      multiplierCondition: json['multiplierCondition'] as String? ?? '',
      conditionalMultiplier:
          (json['conditionalMultiplier'] as num?)?.toDouble() ?? 1.0,
      failIfTargetNotAttacking:
          json['failIfTargetNotAttacking'] as bool? ?? false,
      customUsageText: json['customUsageText'] as String?,
      isContact: json['isContact'] as bool?,
    );
  }

  // FIX: Make the static list private and use a helper function to access it.
  static const List<Move> _allMoves = [
    Move(
      name: 'Death Roll',
      description:
          'The user grabs the target and spins violently, tearing and crushing at the same time.',
      baseDamage: 80,
      type: ElementalType.aquatic,
      stamina: 5,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'defense',
          value: -1,
          chance: 40,
        ),
      ],
    ),
    Move(
      name: 'Scratch',
      description: 'A basic attack.',
      baseDamage: 10,
      type: ElementalType.normal,
      stamina: 35,
      accuracy: 100,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Headbutt',
      description: 'A basic attack.',
      baseDamage: 70,
      type: ElementalType.normal,
      stamina: 15,
      accuracy: 90,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Stomp',
      description: 'A basic attack.',
      baseDamage: 65,
      type: ElementalType.normal,
      stamina: 25,
      accuracy: 95,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Claw Swipe',
      description: 'A basic attack.',
      baseDamage: 20,
      type: ElementalType.normal,
      stamina: 30,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Crabhammer',
      description: 'A basic attack.',
      baseDamage: 90,
      type: ElementalType.aquatic,
      stamina: 10,
      accuracy: 90,
      category: MoveCategory.physical,
      critRate: 1,
      effects: [],
    ),
    Move(
      name: 'Kick',
      description: 'A basic attack.',
      baseDamage: 20,
      type: ElementalType.normal,
      stamina: 30,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Vice Grip',
      description: 'A basic attack.',
      baseDamage: 55,
      type: ElementalType.normal,
      stamina: 30,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Slash',
      description: 'A basic attack.',
      baseDamage: 30,
      type: ElementalType.normal,
      critRate: 1,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Peck',
      description: 'A basic attack.',
      baseDamage: 10,
      type: ElementalType.flying,
      stamina: 35,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Wing Flap',
      description: 'A basic attack.',
      baseDamage: 15,
      type: ElementalType.flying,
      stamina: 35,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Piercing Beak',
      description: 'A strong peck attack.',
      baseDamage: 40,
      type: ElementalType.flying,
      critRate: 1,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Dive',
      description: 'A strong wing attack.',
      baseDamage: 50,
      type: ElementalType.flying,
      stamina: 10,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 30),
      ],
    ),
    Move(
      name: 'Sonic Slash',
      description: 'A strong wing attack.',
      baseDamage: 70,
      type: ElementalType.flying,
      stamina: 5,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 30),
      ],
    ),
    Move(
      name: 'Glide',
      description: 'A strong wing attack.',
      baseDamage: 40,
      type: ElementalType.flying,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 20),
      ],
    ),
    Move(
      name: 'Venom Sting',
      description: 'May poison the foe.',
      baseDamage: 8,
      type: ElementalType.venomous,
      stamina: 25,
      category: MoveCategory.special,
      effects: [
        MoveEffect(type: MoveEffectType.statusPoison, value: 3, chance: 30),
      ],
    ),
    Move(
      name: 'Chomp',
      description: 'A basic attack.',
      baseDamage: 30,
      type: ElementalType.aquatic,
      stamina: 25,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Venomous Fang',
      description: 'May poison the foe.',
      baseDamage: 55,
      type: ElementalType.venomous,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusPoison, value: 3, chance: 50),
      ],
    ),
    Move(
      name: 'Withdraw',
      description: 'Raises the user\'s defense.',
      baseDamage: 0,
      type: ElementalType.armored,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'defense',
          value: 1,
        ),
      ],
    ),
    Move(
      name: 'Titan\'s Wake',
      description:
          'Creates a massive displacement wave that slows all enemies.',
      baseDamage: 90,
      accuracy: 100,
      type: ElementalType.giant,
      stamina: 10,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'speed',
          value: -2,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Vortex Suction',
      description:
          'The user opens its massive mouth to create a vacuum. Deals damage and restores HP.',
      baseDamage: 65,
      accuracy: 95,
      type: ElementalType.aquatic,
      stamina: 15,
      category:
          MoveCategory.special, // Whale sharks "pull" water rather than biting
      drainPercent: 0.5, // Heals half the damage dealt
      effects: [
        MoveEffect(
          type: MoveEffectType.statusMarked,
          target: 'opponent',
          chance: 30,
        ),
      ],
    ),
    Move(
      name: 'Denticle Armor',
      description:
          'The user flexes its sandpaper-thick skin, boosting defense and punishing contact.',
      baseDamage: 0,
      type: ElementalType.armored,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'defense',
          value: 2,
        ),
        MoveEffect(
          type: MoveEffectType.statusRegen,
          target: 'self',
          value: 3, // Regens HP for 3 turns
        ),
      ],
    ),
    Move(
      name: 'Colossal Tail Sweep',
      description: 'A slow but devastating swing of the massive caudal fin.',
      baseDamage: 100,
      accuracy: 80,
      type: ElementalType.giant,
      stamina: 12,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStun,
          target: 'opponent',
          value: 1,
          chance: 40,
        ),
      ],
    ),
    // White Rhinoceros Moveset
    Move(
      name: 'Wide-Track Juggernaut',
      description:
          'A massive, straight-line charge. Damage scales with the user\'s Defense.',
      baseDamage: 130,
      accuracy: 90,
      type: ElementalType.giant,
      stamina: 5,
      category: MoveCategory.physical,
      damageStat: 'defense', // Uses the Rhino's 130 Defense instead of Attack
      effects: [
        MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 30),
      ],
    ),
    Move(
      name: 'Mud Armor',
      description: 'Coats the body in thick mud to boost protection.',
      baseDamage: 0,
      type: ElementalType.armored,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'defense',
          value: 2,
        ),
      ],
    ),
    Move(
      name: 'Hook-Lip Gore',
      description:
          'A surgical strike with the front horn. High critical-hit ratio.',
      baseDamage: 95,
      accuracy: 100,
      type: ElementalType.predator,
      stamina: 10,
      category: MoveCategory.physical,
      critRate: 2, // 50% Critical Hit rate
      effects: [
        MoveEffect(type: MoveEffectType.statusBleed, value: 2, chance: 40),
      ],
    ),
    Move(
      name: 'Blind Charge',
      description:
          'A reckless dash at anything that moves. High damage but hurts the user.',
      baseDamage: 110,
      accuracy: 85,
      type: ElementalType.giant,
      stamina: 10,
      recoilPercent: 0.25, // 25% recoil damage
      category: MoveCategory.physical,
    ),
    Move(
      name: 'Scary Face',
      description:
          'A terrifying glare that halts the opponent in their tracks.',
      baseDamage: 0,
      type: ElementalType.predator,
      stamina: 15,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusFear,
          target: 'opponent',
          value: 2,
        ),
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'speed',
          value: -2,
        ),
      ],
    ),
    Move(
      name: 'Relic Echo',
      description:
          'A ghostly call from the ancient past. Ignores the target\'s stat changes.',
      baseDamage: 80,
      accuracy: 100, // Never misses in jungle terrain
      type: ElementalType.normal,
      stamina: 10,
      category: MoveCategory.special,
      damageStat: 'power',
      effects: [
        MoveEffect(
          type: MoveEffectType.statusConfusion,
          target: 'opponent',
          value: 2,
          chance: 30,
        ),
      ],
    ),
    Move(
      name: 'Jungle Song',
      description:
          'Emits a high-pitched vocalization that lulls the foe to sleep.',
      baseDamage: 0,
      accuracy: 60,
      type: ElementalType.social,
      stamina: 8,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusSleep,
          target: 'opponent',
          value: 2,
        ),
      ],
    ),
    Move(
      name: 'Horn Leech',
      description: 'A specialized browsing strike that restores health.',
      baseDamage: 75,
      type: ElementalType.parasite, // Uses the drain logic from your code
      stamina: 10,
      drainPercent: 0.5, // Heals half of damage dealt
      category: MoveCategory.physical,
    ),
    Move(
      name: 'Resonating Honk',
      description: 'Amplifies sound through the casque to disorient the foe.',
      baseDamage: 85,
      accuracy: 100,
      type: ElementalType.social,
      stamina: 10,
      category: MoveCategory.special,
      effects: [
        MoveEffect(type: MoveEffectType.statusConfusion, value: 2, chance: 30),
      ],
    ),
    Move(
      name: 'Sealed Nest Protection',
      description: 'Recalls the nesting habit to temporarily boost defenses.',
      baseDamage: 0,
      type: ElementalType.armored,
      stamina: 20,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'defense',
          value: 2,
        ),
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'spDef',
          value: 2,
        ),
      ],
    ),
    // ⭐ Signature Move
    Move(
      name: 'Casque Cannonade',
      description:
          'A focused blast of sonic energy. Ignores the target\'s Defense.',
      baseDamage: 100,
      accuracy: 95,
      type: ElementalType.giant,
      stamina: 15,
      category: MoveCategory.special,
      damageStat: 'power',
    ),
    Move(
      name: 'Head Bob Display',
      description: 'A rhythmic dominance display that intimidates the foe.',
      baseDamage: 0,
      type: ElementalType.social,
      stamina: 12,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'attack',
          value: -2,
        ),
      ],
    ),
    // ⭐ Signature Move
    Move(
      name: 'Pseudo-Horn Skewer',
      description: 'Drives the bony horn-scales into the target.',
      baseDamage: 90,
      accuracy: 100,
      type: ElementalType.armored,
      stamina: 12,
      category: MoveCategory.physical,
      critRate: 2, // High crit due to the focused pressure of the horn
    ),
    Move(
      name: 'Territorial Roar',
      description:
          'A wide-mouthed threat display that strikes fear into the foe.',
      baseDamage: 0,
      type: ElementalType.social,
      stamina: 15,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusFear,
          target: 'opponent',
          value: 2,
        ),
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'attack',
          value: -2,
        ),
      ],
    ),
    Move(
      name: 'Submerge',
      description: 'Dives underwater to dodge attacks and hydrate.',
      baseDamage: 0,
      type: ElementalType.aquatic,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStealth,
          target: 'self',
          value: 1,
        ),
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'defense',
          value: 1,
        ),
      ],
    ),
    // ⭐ Signature Move
    Move(
      name: 'Megamouth Chomp',
      description: 'A 180-degree jaw snap with 2,000 PSI of force.',
      baseDamage: 120,
      accuracy: 85,
      type: ElementalType.predator,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusBleed, value: 3, chance: 50),
        MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 20),
      ],
    ),
    Move(
      name: 'Slick Skin',
      description: 'Secretes a "blood sweat" that makes the user hard to grab.',
      baseDamage: 0,
      type: ElementalType.normal,
      stamina: 12,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'speed',
          value: 2,
        ),
        // Makes the user immune to 'Grip' or 'Bleed' for 2 turns
      ],
    ),
    // ⭐ Signature Move
    Move(
      name: 'Shadow Wallower',
      description:
          'Vanishes into the muddy forest floor before striking from behind.',
      baseDamage: 85,
      accuracy: 95,
      type: ElementalType.agile,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStealth,
          target: 'self',
          value: 1,
        ),
      ],
      // Damage is doubled if the user is already in 'Stealth' (handled in battle_manager.dart)
    ),
    Move(
      name: 'Scent Lock',
      description:
          'Uses the tongue to lock onto the target\'s chemical trail. Target takes 1.2x damage.',
      baseDamage: 0,
      type: ElementalType.agile,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusMarked,
          target: 'opponent',
          chance: 100,
          value: 2, // Duration of the mark
        ),
      ],
    ),
    Move(
      name: 'Septic Bite',
      description: 'A deep, jagged bite that causes intense bleeding.',
      baseDamage: 110,
      accuracy: 85,
      type: ElementalType.predator,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusBleed,
          target: 'opponent',
          value: 4, // Higher duration for the Komodo
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Arboreal Ambush',
      description:
          'Strikes from the canopy, entering stealth and dealing high damage.',
      baseDamage: 85,
      accuracy: 100,
      type: ElementalType.agile,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStealth,
          target: 'self',
          value:
              1, // Sets up for the 2.0x Stealth damage multiplier on next turn
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Wide Gape',
      description:
          'Displays its massive square lip to intimidate the opponent.',
      baseDamage: 0,
      type: ElementalType.social,
      stamina: 15,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'attack',
          value: -1,
        ),
      ],
    ),
    Move(
      name: 'Filter Feed',
      description:
          'The user filters the surrounding water for nutrients, clearing status and healing.',
      baseDamage: 0,
      type: ElementalType.aquatic,
      stamina: 8,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.heal,
          target: 'self',
          value: 40, // Heals 40% of Max HP
        ),
      ],
    ),
    Move(
      name: 'Depth Pressure',
      description:
          'Uses the weight of the ocean to crush the foe. Damage scales with Defense.',
      baseDamage: 80,
      accuracy: 100,
      type: ElementalType.aquatic,
      stamina: 15,
      category: MoveCategory.physical,
      damageStat: 'defense', // Uses the whale's 120 Defense for damage
      effects: [],
    ),
    Move(
      name: 'Abyssal Breach',
      description:
          'The whale leaps and crashes down. Power increases if the user has high HP.',
      baseDamage: 120,
      accuracy: 85,
      type: ElementalType.aquatic,
      stamina: 5,
      category: MoveCategory.physical,
      multiplierCondition:
          'user_high_hp', // You can implement this logic in your battle engine
      conditionalMultiplier: 1.5,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStun,
          target: 'opponent',
          value: 1,
          chance: 30,
        ),
      ],
    ),
    Move(
      name: 'Event Horizon Gulp',
      description: 'The ultimate apex move. Swallows weakened foes whole.',
      baseDamage: 200, // Extreme damage placeholder for OHKO feel
      accuracy: 30,
      type: ElementalType.predator,
      stamina: 5,
      category: MoveCategory.physical,
      customUsageText: 'The whale creates a massive vacuum suction!',
      effects: [
        MoveEffect(
          type: MoveEffectType.recharge, // Must rest after such a huge move
        ),
      ],
    ),
    Move(
      name: 'Deep Meditation',
      description:
          'The whale enters a trance, boosting defenses and regenerating.',
      baseDamage: 0,
      type: ElementalType.aquatic,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.multiStatChange,
          stat: 'defense:1,resistance:1',
        ),
        MoveEffect(
          type: MoveEffectType.statusRegen,
          target: 'self',
          value: 5, // Duration for regen
        ),
      ],
    ),
    Move(
      name: 'Blubber Shield',
      description: 'Sacrifices health to create a massive protective barrier.',
      baseDamage: 0,
      type: ElementalType.armored,
      stamina: 5,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.protect,
          hpCostPercent: 0.25, // Consumes 25% of that huge 200 HP pool
        ),
      ],
    ),
    Move(
      name: 'Infrasonic Blast',
      description:
          'A sound so loud it vibrates internal organs, causing confusion.',
      baseDamage: 70,
      accuracy: 100,
      type: ElementalType.social, // Fitting for whale song
      stamina: 10,
      category: MoveCategory.special,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusConfusion,
          target: 'opponent',
          value: 3,
          chance: 50,
        ),
      ],
    ),
    Move(
      name: 'Tail Whip',
      description: 'Lowers the opponent\'s defense.',
      baseDamage: 10,
      type: ElementalType.agile,
      stamina: 25,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'defense',
          value: -1,
        ),
      ],
    ),
    Move(
      name: 'Jet Ram',
      description: 'A high-speed tackle using jet propulsion. High crit rate.',
      baseDamage: 60,
      type: ElementalType.agile,
      stamina: 15,
      category: MoveCategory.physical,
      critRate: 1, // 12.5% crit rate
    ),
    Move(
      name: 'Barbed Tentacle',
      description:
          'Strikes with hooked tentacles. May make the target vulnerable.',
      baseDamage: 55,
      type: ElementalType.aquatic,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusVulnerable,
          target: 'opponent',
          value: 2,
          chance: 30,
        ),
      ],
    ),
    Move(
      name: 'Ink Cloud',
      description: 'Sprays thick ink to hide and confuse the opponent.',
      baseDamage: 0,
      type: ElementalType.agile,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusBlind,
          target: 'opponent',
          value: 2,
          chance: 100,
        ),
        MoveEffect(
          type: MoveEffectType.statusStealth,
          target: 'self',
          value: 1,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Strobe Flash',
      description: 'Rapidly shifts skin colors to daze and stun the target.',
      baseDamage: 20,
      type: ElementalType.aquatic,
      stamina: 15,
      category: MoveCategory.special,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStun,
          target: 'opponent',
          value: 1,
          chance: 70,
        ),
      ],
    ),
    Move(
      name: 'Paralyzing Sting',
      description: 'Stinging cells that may paralyze the foe.',
      baseDamage: 35,
      type: ElementalType.venomous,
      stamina: 20,
      category: MoveCategory.special,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusParalysis,
          target: 'opponent',
          value: 3,
          chance: 50,
        ),
      ],
    ),
    Move(
      name: 'Biolume Flare',
      description: 'A sudden burst of light that may blind the foe.',
      baseDamage: 60,
      type: ElementalType.aquatic,
      stamina: 15,
      category: MoveCategory.special,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusBlind,
          target: 'opponent',
          value: 1,
          chance: 30,
        ),
      ],
    ),
    Move(
      name: 'Drifting Tentacles',
      description: 'Sets a stinging field that makes opponents vulnerable.',
      baseDamage: 0,
      type: ElementalType.venomous,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusVulnerable,
          target: 'opponent',
          value: 3,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Osmosis',
      description: 'Absorbs nutrients from the water to heal the user.',
      baseDamage: 0,
      type: ElementalType.aquatic,
      stamina: 5,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.heal,
          target: 'self',
          value: 33,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Hypnotic Ripple',
      description: 'Mesmerizes the target, lowering their mental resistance.',
      baseDamage: 20,
      type: ElementalType.aquatic,
      stamina: 20,
      category: MoveCategory.special,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'resistance',
          value: -1,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Tentacle Snap',
      description: 'A lightning-fast grab with tentacles that hits first.',
      baseDamage: 40,
      type: ElementalType.agile,
      stamina: 20,
      priority: 1, // Moves first
      category: MoveCategory.physical,
    ),
    Move(
      name: 'Hiss',
      description: 'Lowers the opponent\'s attack.',
      baseDamage: 0,
      type: ElementalType.venomous,
      stamina: 25,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'attack',
          value: -1,
        ),
      ],
    ),
    Move(
      name: 'Predatory Circle',
      description: 'Lowers the opponent\'s defense.',
      baseDamage: 0,
      type: ElementalType.predator,
      stamina: 25,
      category: MoveCategory.status,
      effects: [
        MoveEffect(type: MoveEffectType.statusFear, value: 2, chance: 90),
      ],
    ),
    Move(
      name: 'Cavitation Strike',
      description: 'Lowers the opponent\'s defense.',
      baseDamage: 90,
      type: ElementalType.agile,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'defense',
          value: -1,
          chance: 20,
        ),
      ],
    ),
    Move(
      name: 'Hibernate',
      description: 'A healing nap.',
      baseDamage: 0,
      type: ElementalType.burrowing,
      stamina: 5,
      category: MoveCategory.status,
      effects: [
        MoveEffect(type: MoveEffectType.heal, target: 'self', value: 50),
      ],
    ),
    Move(
      name: 'Tackle',
      description: 'A full-body charge.',
      baseDamage: 35,
      accuracy: 95,
      type: ElementalType.giant,
      stamina: 35,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Pounce',
      description: 'User pounces at the foe.',
      baseDamage: 60,
      accuracy: 85,
      type: ElementalType.predator,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Bite',
      description: 'Bites with vicious fangs.',
      baseDamage: 40,
      type: ElementalType.predator,
      stamina: 25,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusBleed, value: 1, chance: 10),
      ],
    ),
    Move(
      name: 'Hide',
      description: 'User gain stealth.',
      baseDamage: 0,
      type: ElementalType.predator,
      stamina: 25,
      category: MoveCategory.status,
      effects: [MoveEffect(type: MoveEffectType.statusStealth, chance: 80)],
    ),
    Move(
      name: 'Varanid Rake',
      description: 'Bites with vicious fangs.',
      baseDamage: 30,
      type: ElementalType.predator,
      stamina: 25,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusBleed, value: 1, chance: 70),
      ],
    ),
    Move(
      name: 'Crunch',
      description: 'Bites with vicious fangs.',
      baseDamage: 60,
      type: ElementalType.predator,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusBleed, value: 1, chance: 30),
      ],
    ),
    Move(
      name: 'Water Gun',
      description: 'Squirts water to attack.',
      baseDamage: 40,
      type: ElementalType.aquatic,
      stamina: 25,
      category: MoveCategory.special,
      effects: [],
    ),
    Move(
      name: 'Ember',
      description: 'May burn the foe.',
      baseDamage: 40,
      type: ElementalType.normal,
      stamina: 20,
      category: MoveCategory.special,
      effects: [
        MoveEffect(type: MoveEffectType.statusBurn, value: 3, chance: 15),
      ],
    ),
    Move(
      name: 'Thunder Shock',
      description: 'May paralyze the foe.',
      baseDamage: 40,
      type: ElementalType.normal,
      stamina: 20,
      category: MoveCategory.special,
      effects: [
        MoveEffect(type: MoveEffectType.statusParalysis, value: 3, chance: 15),
      ],
    ),
    Move(
      name: 'Sing',
      description: 'Lulls the foe to sleep.',
      baseDamage: 0,
      accuracy: 55,
      type: ElementalType.social,
      stamina: 15,
      category: MoveCategory.status,
      effects: [
        MoveEffect(type: MoveEffectType.statusSleep, value: 3, chance: 100),
      ],
    ),
    Move(
      name: 'Rain Dance',
      description: 'Summons rain.',
      baseDamage: 0,
      type: ElementalType.aquatic,
      stamina: 5,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.weather,
          target: 'field',
          stat: 'rain',
          value: 5,
        ),
      ],
    ),
    Move(
      name: 'Sunny Day',
      description: 'Summons harsh sunlight.',
      baseDamage: 0,
      type: ElementalType.normal,
      stamina: 5,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.weather,
          target: 'field',
          stat: 'sun',
          value: 5,
        ),
      ],
    ),
    Move(
      name: 'Quick Attack',
      description: 'Strikes first.',
      baseDamage: 40,
      priority: 1,
      type: ElementalType.agile,
      stamina: 30,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Bullet Punch',
      description: 'Strikes first.',
      baseDamage: 40,
      priority: 1,
      type: ElementalType.agile,
      stamina: 30,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Dash',
      description: 'Strikes first.',
      baseDamage: 50,
      priority: 1,
      type: ElementalType.agile,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Apex Ravage',
      description:
          'A devastating series of bites. Always causes heavy bleeding.',
      baseDamage: 120,
      accuracy: 85,
      type: ElementalType.predator,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusBleed,
          target: 'opponent',
          value: 4,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Double Slap',
      description: 'Hits 2-5 times.',
      baseDamage: 15,
      minHits: 2,
      maxHits: 5,
      type: ElementalType.social,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Camoflauge',
      description: 'Blends into the landscape. Grants Stealth.',
      baseDamage: 0,
      type: ElementalType.agile,
      stamina: 15,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStealth,
          target: 'self',
          value: 1,
        ),
      ],
    ),
    Move(
      name: 'Shadow Throat-Grip',
      description: 'A lethal strike from the shadows. High Critical-Hit ratio.',
      baseDamage: 90,
      accuracy: 95,
      type: ElementalType.predator,
      stamina: 18,
      category: MoveCategory.physical,
      critRate: 2, // Combined with Stealth 2.0x, this can 1-shot opponents
    ),
    Move(
      name: 'King\'s Command',
      description:
          'A roar that freezes the hearts of enemies. Applies Fear and Marks the target.',
      baseDamage: 0,
      type: ElementalType.social,
      stamina: 20,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusFear,
          target: 'opponent',
          value: 2,
        ),
        MoveEffect(
          type: MoveEffectType.statusMarked,
          target: 'opponent',
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Jungle Pounce',
      description:
          'A stealthy leap from the brush. Guarantees a critical hit if the user is in Stealth.',
      baseDamage: 90,
      accuracy: 100,
      type: ElementalType.predator,
      stamina: 12,
      category: MoveCategory.physical,
      critRate: 2, // Doubles crit chance
    ),
    Move(
      name: 'Gigantism Crush',
      description:
          'A heavy strike that scales with the user\'s massive weight.',
      baseDamage: 130,
      accuracy: 80,
      type: ElementalType.giant,
      stamina: 25,
      category: MoveCategory.physical,
      damageStat: 'attack',
    ),
    Move(
      name: 'Skull-Piercer',
      description: 'An eerie, blinding attack that confuses the target.',
      baseDamage: 90,
      accuracy: 100,
      type: ElementalType.predator,
      stamina: 15,
      category: MoveCategory.physical,
      // Logic: In battle_manager, ignore defender's defense stat
    ),
    Move(
      name: 'Savannah Sweep',
      description: 'A sweeping claw attack that hits the legs, lowering Speed.',
      baseDamage: 75,
      accuracy: 100,
      type: ElementalType.agile,
      stamina: 10,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'speed',
          value: -1,
        ),
      ],
    ),
    Move(
      name: 'Frost-Leap',
      description:
          'Strikes from a frozen ledge. Chance to freeze or stun the foe.',
      baseDamage: 85,
      accuracy: 100,
      type: ElementalType.agile,
      stamina: 12,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStun,
          target: 'opponent',
          value: 1,
          chance: 30,
        ),
      ],
    ),
    Move(
      name: 'Tree-Drag Takedown',
      description:
          'Pokes the target into a vulnerable state by dragging them into the canopy.',
      baseDamage: 80,
      accuracy: 95,
      type: ElementalType.predator,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusVulnerable,
          target: 'opponent',
          value: 2,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Atlas Roar',
      description:
          'An ancient roar that boosts the user\'s confidence while weakening others.',
      baseDamage: 0,
      type: ElementalType.social,
      stamina: 20,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'self',
          stat: 'defense',
          value: 2,
        ),
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'attack',
          value: -2,
        ),
      ],
    ),
    Move(
      name: 'Midnight Eviscerate',
      description: 'An eerie, blinding attack that confuses the target.',
      baseDamage: 85,
      accuracy: 100,
      type: ElementalType.agile,
      stamina: 12,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusBleed,
          target: 'opponent',
          value: 3,
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Spectral Strike',
      description: 'An eerie, blinding attack that confuses the target.',
      baseDamage: 85,
      accuracy: 95,
      type: ElementalType.normal,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusConfusion,
          target: 'opponent',
          value: 2,
          chance: 40,
        ),
      ],
    ),
    Move(
      name: 'Tundra Smash',
      description:
          'Uses massive body weight to crush the foe. High chance to Stun.',
      baseDamage: 110,
      accuracy: 85,
      type: ElementalType.giant,
      stamina: 18,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusStun,
          target: 'opponent',
          value: 1,
          chance: 50,
        ),
      ],
    ),
    Move(
      name: 'Overdrive Sprint',
      description:
          'Uses extreme acceleration to strike before the opponent can react',
      baseDamage: 80,
      accuracy: 100,
      type: ElementalType.agile,
      stamina: 15,
      category: MoveCategory.physical,
      priority: 1,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusMarked,
          target: 'opponent',
          chance: 30,
        ),
      ],
    ),
    Move(
      name: 'Drain Punch',
      description: 'Heals half damage dealt.',
      baseDamage: 75,
      drainPercent: 0.5,
      type: ElementalType.parasite,
      stamina: 10,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Constrict',
      description: 'Traps and crushes the foe, dealing damage over time.',
      baseDamage: 35,
      accuracy: 90,
      type: ElementalType.predator,
      stamina: 20,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 30),
        MoveEffect(
          type: MoveEffectType.statusVulnerable,
          value: 2,
          chance: 100,
        ),
      ],
    ),

    Move(
      name: 'Crush Grip',
      description:
          'A heavy strike that scales with the user\'s massive weight.',
      baseDamage: 100,
      accuracy: 100,
      type: ElementalType.giant,
      stamina: 10,
      category: MoveCategory.physical,
      damageStat: 'attack',
    ),

    Move(
      name: 'Coil',
      description:
          'The user gathers its body, boosting Attack, Defense, and Accuracy.',
      baseDamage: 0,
      type: ElementalType.predator,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.multiStatChange,
          stat:
              'attack:1,defense:1,accuracy:1', // Accuracy is handled via stat string
        ),
      ],
    ),
    Move(
      name: 'Guillotine Snap',
      description:
          'The user lies perfectly still, then snaps its beak with bone-crushing force. This move deals massive damage and has a high critical-hit ratio.',
      baseDamage: 130,
      priority: -1,
      type: ElementalType.aquatic,
      stamina: 5,
      category: MoveCategory.physical,
      critRate: 1,
      accuracy: 85,
    ),
    Move(
      name: 'Take Down',
      description: 'Hurts user.',
      baseDamage: 90,
      recoilPercent: 0.25,
      type: ElementalType.giant,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Slash',
      description: 'High crit rate.',
      baseDamage: 70,
      critRate: 1,
      type: ElementalType.predator,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [],
    ),
    Move(
      name: 'Confuse Ray',
      description: 'Confuses the foe.',
      baseDamage: 0,
      type: ElementalType.normal,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(type: MoveEffectType.statusConfusion, value: 3, chance: 100),
      ],
    ),
    Move(
      name: 'Glare',
      description: 'Stuns the foe.',
      baseDamage: 0,
      type: ElementalType.predator,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 100),
      ],
    ),
    Move(
      name: 'Poison Jab',
      description: 'Damage + Poison.',
      baseDamage: 80,
      type: ElementalType.venomous,
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.statusPoison, value: 3, chance: 30),
      ],
    ),
    Move(
      name: 'Giga Drain',
      description:
          'A nutrient-draining attack. The user\'s HP is restored by half the damage taken by the target.',
      baseDamage: 75,
      drainPercent: 0.5,
      type: ElementalType.parasite,
      stamina: 10,
      category: MoveCategory.special,
      effects: [],
    ),
    Move(
      name: 'Dig',
      description:
          'The user burrows into the ground, then attacks on the next turn.',
      baseDamage: 80,
      type: ElementalType.burrowing,
      stamina: 10,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(type: MoveEffectType.semiInvulnerable, stat: 'underground'),
      ],
    ),
    Move(
      name: 'Rest',
      description:
          'The user goes to sleep for two turns. This fully restores the user\'s HP.',
      baseDamage: 0,
      type: ElementalType.normal,
      stamina: 5,
      category: MoveCategory.status,
      effects: [
        MoveEffect(type: MoveEffectType.heal, target: 'self', value: 999),
      ],
    ),
    Move(
      name: 'Protect',
      description:
          'Enables the user to evade all attacks. Its chance of failing rises if it is used in succession.',
      baseDamage: 0,
      type: ElementalType.normal,
      stamina: 10,
      category: MoveCategory.status,
      effects: [MoveEffect(type: MoveEffectType.protect)],
    ),
    Move(
      name: 'Sucker Punch',
      description:
          'This move enables the user to attack first. This move fails if the target is not preparing an attack.',
      baseDamage: 70,
      priority: 1,
      type: ElementalType.predator,
      stamina: 5,
      category: MoveCategory.physical,
      failIfTargetNotAttacking: true,
      effects: [],
    ),
    Move(
      name: 'Shell Smash',
      description:
          'The user shatters its shell, which sharply raises Attack and Speed but lowers Defense.',
      baseDamage: 0,
      type: ElementalType.armored,
      stamina: 15,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.multiStatChange,
          stat: 'attack:2,power:2,speed:2,defense:-1,resistance:-1',
        ),
      ],
    ),
    Move(
      name: 'Ancient Power',
      description:
          'The user attacks with a prehistoric power. This may also raise all the user\'s stats at once.',
      baseDamage: 60,
      type: ElementalType.normal,
      stamina: 5,
      category: MoveCategory.special,
      effects: [
        MoveEffect(
          type: MoveEffectType.statChangeChance,
          stat: 'attack:1,defense:1,speed:1,power:1,resistance:1',
          chance: 10,
        ),
      ],
    ),
    Move(
      name: 'Assurance',
      description:
          'If the target has already taken some damage in the same turn, this move\'s power is doubled.',
      baseDamage: 60,
      type: ElementalType.normal,
      stamina: 10,
      category: MoveCategory.physical,
      multiplierCondition: 'target_damaged',
      conditionalMultiplier: 2.0,
      effects: [],
    ),
    Move(
      name: 'Baneful Bunker',
      description:
          'In addition to protecting the user from attacks, this move also poisons any attacker that makes direct contact.',
      baseDamage: 0,
      type: ElementalType.venomous,
      stamina: 10,
      category: MoveCategory.status,
      effects: [MoveEffect(type: MoveEffectType.protect, stat: 'poison')],
    ),
    Move(
      name: 'Barb Barrage',
      description:
          'The user launches countless toxic spikes to inflict damage. This may also poison the target.',
      baseDamage: 60,
      type: ElementalType.venomous,
      stamina: 10,
      category: MoveCategory.special,
      effects: [MoveEffect(type: MoveEffectType.statusPoison, chance: 30)],
      multiplierCondition: 'target_poisoned',
      conditionalMultiplier: 2.0,
    ),
    Move(
      name: 'Belly Drum',
      description:
          'The user maximizes its Attack stat in exchange for HP equal to half its max HP.',
      baseDamage: 0,
      type: ElementalType.social,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.multiStatChange,
          stat: 'attack:6',
          hpCostPercent: 0.5,
        ),
      ],
    ),
    Move(
      name: 'Hyper Beam',
      description:
          'The target is attacked with a powerful beam. The user can\'t move on the next turn.',
      baseDamage: 150,
      type: ElementalType.normal,
      stamina: 5,
      category: MoveCategory.special,
      effects: [MoveEffect(type: MoveEffectType.recharge)],
    ),
    Move(
      name: 'Geomancy',
      description:
          'The user absorbs energy and sharply raises its stats on the next turn.',
      baseDamage: 0,
      type: ElementalType.social,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.charge,
          stat: 'attack:2,defense:2,speed:2',
        ),
      ],
    ),
    Move(
      name: 'Body Press',
      description:
          'The user attacks by slamming its body into the target. The higher its Defense, the more damage it can inflict.',
      baseDamage: 80,
      type: ElementalType.armored,
      stamina: 10,
      category: MoveCategory.physical,
      damageStat: 'defense',
      effects: [],
    ),
    Move(
      name: 'Bulk Up',
      description:
          'The user tenses its muscles to bulk up its body, raising both Attack and Defense stats.',
      baseDamage: 0,
      type: ElementalType.normal,
      stamina: 20,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.multiStatChange,
          stat: 'attack:1,defense:1',
        ),
      ],
    ),
    Move(
      name: 'Crippling Bite',
      description:
          'A deep, jagged bite that causes heavy bleeding and hampers the foe\'s movement.',
      baseDamage: 70,
      accuracy: 70,
      type: ElementalType.predator, // Fits the "Bite/Crunch" theme
      stamina: 15,
      category: MoveCategory.physical,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusBleed,
          value: 3, // Standard bleed severity/duration
          chance: 100,
        ),
        MoveEffect(
          type: MoveEffectType.statChange,
          target: 'opponent',
          stat: 'speed',
          value: -1,
          chance: 50,
        ),
      ],
    ),
    Move(
      name: 'Intimidate',
      description:
          'The user intimidates the foe, instilling Fear and reducing its stats by 10% for 2 turns.',
      baseDamage: 0,
      type: ElementalType.predator,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusFear,
          target: 'opponent',
          chance: 100,
        ),
      ],
    ),
    Move(
      name: 'Hunter\'s Mark',
      description:
          'The user marks the target. The target takes 20% extra damage for 2 turns.',
      baseDamage: 0,
      type: ElementalType.agile,
      stamina: 10,
      category: MoveCategory.status,
      effects: [
        MoveEffect(
          type: MoveEffectType.statusMarked,
          target: 'opponent',
          chance: 100,
        ),
      ],
    ),
  ];

  // 💡 FIX: Add public static getter to allow access to the private list.
  static List<Move> get allMoves => _allMoves;

  /// Find a move by name in the predefined list.
  static Move? findByName(String name) {
    final trimmedName = name.trim().toLowerCase();
    try {
      return _allMoves.firstWhere((m) => m.name.toLowerCase() == trimmedName);
    } catch (_) {
      return null;
    }
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
