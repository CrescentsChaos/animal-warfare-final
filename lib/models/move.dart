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
//      effect: MoveEffect(type: MoveEffectType.statusPoison, target: 'opponent', value: 3)), // Value is duration or severity
//
// 3) Stat Change (Raise your defense):
//    Move(name: 'Harden', description: 'Raises defense.', baseDamage: 0,
//      effect: MoveEffect(type: MoveEffectType.statChange, target: 'self', stat: 'defense', value: 1)),
//
// 4) Weather Change:
//    Move(name: 'Rain Dance', description: 'Summons rain.', baseDamage: 0,
//      effect: MoveEffect(type: MoveEffectType.weather, target: 'field', stat: 'rain', value: 5)),
//
// 5) Terrain Change:
//    Move(name: 'Electric Terrain', description: 'Electrifies ground.', baseDamage: 0,
//      effect: MoveEffect(type: MoveEffectType.terrain, target: 'field', stat: 'electric', value: 5)),
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
  weather,      // Changes Weather
  terrain,      // Changes Terrain
  // New Effect Types
  statusBleed,
  statusConfusion,
  statusBlind,
  statusRegen,
  statusVulnerable,
  statusStun,
  // New Effect Types for Complex Moves
  multiStatChange,
  recharge,
  charge,
  protect,
  semiInvulnerable,
  statChangeChance,
}

enum MoveCategory {
  physical,
  special,
  status,
}

// Model for the effect component of a Move
class MoveEffect {
  final MoveEffectType type;
  final String target; // 'self', 'opponent', 'field'
  final String stat;   // e.g., 'attack', 'defense', 'rain', 'electric'
  final int value;     // Magnitude, duration, or probability
  final int chance;    // Probability (0-100)
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
        orElse: () => MoveEffectType.none
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
  final MoveEffect effect;
  final int priority; // Higher goes first
  final int critRate; // 0=4%, 1=12.5%, 2=50%, 3+=100%
  final double drainPercent; // % of damage heals user
  final double recoilPercent; // % of damage hurts user
  final int minHits; // For multi-hit moves
  final int maxHits;
  final ElementalType type; // NEW: Elemental Type of the move
  final int stamina; // NEW: PP equivalent
  final MoveCategory category; // NEW: physical, special, status
  
  // Versatility fields
  final String damageStat; // 'attack', 'defense', 'speed', 'power', 'resistance'
  final String multiplierCondition; // 'target_poisoned', 'target_damaged', 'user_charged'
  final double conditionalMultiplier;
  final bool failIfTargetNotAttacking;

  static const int defaultStamina = 20;

  const Move({
    required this.name,
    required this.description,
    required this.baseDamage,
    this.accuracy = 100,
    this.effect = const MoveEffect(type: MoveEffectType.none),
    this.priority = 0,
    this.critRate = 0,
    this.drainPercent = 0.0,
    this.recoilPercent = 0.0,
    this.minHits = 1,
    this.maxHits = 1,
    this.type = ElementalType.normal, // Default
    this.stamina = defaultStamina, // Default stamina
    this.category = MoveCategory.physical, // Default
    this.damageStat = '', // Default empty (will be derived from category if empty)
    this.multiplierCondition = '',
    this.conditionalMultiplier = 1.0,
    this.failIfTargetNotAttacking = false,
    bool? isContact,
  }) : isContact = isContact ?? (category == MoveCategory.physical && baseDamage > 0);

  final bool isContact;

  // Helper for multi-turn moves
  bool get isMultiTurn => effect.type == MoveEffectType.charge || effect.type == MoveEffectType.recharge || effect.type == MoveEffectType.semiInvulnerable;

  // Constructor for loading Move from JSON
  factory Move.fromJson(Map<String, dynamic> json) {
    final baseDamage = json['baseDamage'] as int? ?? 0;
    final categoryStr = json['category'] as String?;
    final category = categoryStr != null 
        ? MoveCategory.values.firstWhere((e) => e.toString().split('.').last == categoryStr, orElse: () => MoveCategory.physical)
        : (baseDamage > 0 ? MoveCategory.physical : MoveCategory.status);

    return Move(
      name: json['name'] as String,
      description: json['description'] as String,
      baseDamage: baseDamage,
      accuracy: json['accuracy'] as int? ?? 100,
      effect: json['effect'] != null
          ? MoveEffect.fromJson(json['effect'] as Map<String, dynamic>)
          : const MoveEffect(type: MoveEffectType.none),
      priority: json['priority'] as int? ?? 0,
      critRate: json['critRate'] as int? ?? 0,
      drainPercent: (json['drainPercent'] as num?)?.toDouble() ?? 0.0,
      recoilPercent: (json['recoilPercent'] as num?)?.toDouble() ?? 0.0,
      minHits: json['minHits'] as int? ?? 1,
      maxHits: json['maxHits'] as int? ?? 1,
      type: json['type'] != null
          ? ElementalType.values.firstWhere(
              (e) => e.toString().split('.').last == json['type'],
              orElse: () => ElementalType.normal)
          : ElementalType.normal,
      stamina: json['stamina'] as int? ?? defaultStamina,
      category: category,
      damageStat: json['damageStat'] as String? ?? (category == MoveCategory.special ? 'power' : 'attack'),
      multiplierCondition: json['multiplierCondition'] as String? ?? '',
      conditionalMultiplier: (json['conditionalMultiplier'] as num?)?.toDouble() ?? 1.0,
      failIfTargetNotAttacking: json['failIfTargetNotAttacking'] as bool? ?? false,
      isContact: json['isContact'] as bool?,
    );
  }
  
  // FIX: Make the static list private and use a helper function to access it.
  static const List<Move> _allMoves = [
    Move(name: 'Death Roll', description: 'The user grabs the target and spins violently, tearing and crushing at the same time.', baseDamage: 80, type: ElementalType.aquatic, stamina: 5, category: MoveCategory.physical,
      effect: MoveEffect(type: MoveEffectType.statChange, target: 'opponent', stat: 'defense', value: -1, chance: 40),
    ),
    Move(name: 'Scratch', description: 'A basic attack.', baseDamage: 10, type: ElementalType.normal, stamina: 35, category: MoveCategory.physical),
    Move(name: 'Claw Swipe', description: 'A basic attack.', baseDamage: 20, type: ElementalType.normal, stamina: 30, category: MoveCategory.physical),
    Move(name: 'Kick', description: 'A basic attack.', baseDamage: 20, type: ElementalType.normal, stamina: 30, category: MoveCategory.physical),
    Move(name: 'Slash', description: 'A basic attack.', baseDamage: 30, type: ElementalType.normal, critRate: 1, stamina: 20, category: MoveCategory.physical),
    Move(name: 'Peck', description: 'A basic attack.', baseDamage: 10, type: ElementalType.flying, stamina: 35, category: MoveCategory.physical),
    Move(name: 'Wing Flap', description: 'A basic attack.', baseDamage: 15, type: ElementalType.flying, stamina: 35, category: MoveCategory.physical),
    Move(name: 'Piercing Beak', description: 'A strong peck attack.', baseDamage: 40, type: ElementalType.flying, critRate: 1, stamina: 15, category: MoveCategory.physical),
    Move(name: 'Dive', description: 'A strong wing attack.', baseDamage: 50, type: ElementalType.flying, stamina: 10, category: MoveCategory.physical, effect: MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 30),),
    Move(name: 'Sonic Slash', description: 'A strong wing attack.', baseDamage: 70, type: ElementalType.flying, stamina: 5, category: MoveCategory.physical, effect: MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 30),),
    Move(name: 'Glide', description: 'A strong wing attack.', baseDamage: 40, type: ElementalType.flying, stamina: 20, category: MoveCategory.physical, effect: MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 20),),
    Move(name: 'Venom Sting', description: 'May poison the foe.', baseDamage: 8, type: ElementalType.venomous, stamina: 25, category: MoveCategory.special, 
      effect: MoveEffect(type: MoveEffectType.statusPoison, value: 3, chance: 30), // 30% chance
    ),
    Move(name: 'Chomp', description: 'A basic attack.', baseDamage: 30, type: ElementalType.aquatic, stamina: 25, category: MoveCategory.physical),
    Move(name: 'Venomous Fang', description: 'May poison the foe.', baseDamage: 55, type: ElementalType.venomous, stamina: 15, category: MoveCategory.physical,
      effect: MoveEffect(type: MoveEffectType.statusPoison, value: 3, chance: 50), 
    ),
    Move(name: 'Hunker Down', description: 'Raises the user\'s defense.', baseDamage: 0, type: ElementalType.armored, stamina: 20, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.statChange, target: 'self', stat: 'defense', value: 1), // +1 Defense stage, 100% chance
    ),
    Move(name: 'Tail Whip', description: 'Lowers the opponent\'s defense.', baseDamage: 10, type: ElementalType.agile, stamina: 25, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.statChange, target: 'opponent', stat: 'defense', value: -1),
    ),
    Move(name: 'Hibernate', description: 'A healing nap.', baseDamage: 0, type: ElementalType.burrowing, stamina: 5, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.heal, target: 'self', value: 50), 
    ),
    // Basic Damage Moves
    Move(name: 'Tackle', description: 'A full-body charge.', baseDamage: 35, accuracy: 95, type: ElementalType.giant, stamina: 35, category: MoveCategory.physical),
    Move(name: 'Pounce', description: 'User pounces at the foe.', baseDamage: 60, accuracy: 85, type: ElementalType.predator, stamina: 15, category: MoveCategory.physical),
    Move(name: 'Bite', description: 'Bites with vicious fangs.', baseDamage: 40, type: ElementalType.predator, stamina: 25, category: MoveCategory.physical,
      effect: MoveEffect(type: MoveEffectType.statusBleed, value: 1, chance: 30),),
    Move(name: 'Crunch', description: 'Bites with vicious fangs.', baseDamage: 60, type: ElementalType.predator, stamina: 15, category: MoveCategory.physical,
      effect: MoveEffect(type: MoveEffectType.statusBleed, value: 1, chance: 30),),
    Move(name: 'Water Gun', description: 'Squirts water to attack.', baseDamage: 40, type: ElementalType.aquatic, stamina: 25, category: MoveCategory.special),
    
    // Status Effect Moves
    Move(name: 'Ember', description: 'May burn the foe.', baseDamage: 40, type: ElementalType.normal, stamina: 20, category: MoveCategory.special,
      effect: MoveEffect(type: MoveEffectType.statusBurn, value: 3, chance: 15), // 15% chance
    ),
    Move(name: 'Thunder Shock', description: 'May paralyze the foe.', baseDamage: 40, type: ElementalType.normal, stamina: 20, category: MoveCategory.special,
      effect: MoveEffect(type: MoveEffectType.statusParalysis, value: 3, chance: 15), 
    ),
    Move(name: 'Sing', description: 'Lulls the foe to sleep.', baseDamage: 0, accuracy: 55, type: ElementalType.social, stamina: 15, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.statusSleep, value: 3, chance: 100), // Guaranteed but low accuracy
    ),
    
    // Weather Moves
    Move(name: 'Rain Dance', description: 'Summons rain.', baseDamage: 0, type: ElementalType.aquatic, stamina: 5, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.weather, target: 'field', stat: 'rain', value: 5),
    ),
    Move(name: 'Sunny Day', description: 'Summons harsh sunlight.', baseDamage: 0, type: ElementalType.normal, stamina: 5, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.weather, target: 'field', stat: 'sun', value: 5),
    ),
 
    // COMPLEX MOVES
    Move(name: 'Quick Attack', description: 'Strikes first.', baseDamage: 40, priority: 1, type: ElementalType.agile, stamina: 30, category: MoveCategory.physical),
    Move(name: 'Double Slap', description: 'Hits 2-5 times.', baseDamage: 15, minHits: 2, maxHits: 5, type: ElementalType.social, stamina: 15, category: MoveCategory.physical),
    Move(name: 'Drain Punch', description: 'Heals half damage dealt.', baseDamage: 75, drainPercent: 0.5, type: ElementalType.parasite, stamina: 10, category: MoveCategory.physical),
    Move(name: 'Take Down', description: 'Hurts user.', baseDamage: 90, recoilPercent: 0.25, type: ElementalType.giant, stamina: 15, category: MoveCategory.physical),
    Move(name: 'Slash', description: 'High crit rate.', baseDamage: 70, critRate: 1, type: ElementalType.predator, stamina: 15, category: MoveCategory.physical),
    Move(name: 'Confuse Ray', description: 'Confuses the foe.', baseDamage: 0, type: ElementalType.normal, stamina: 10, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.statusConfusion, value: 3, chance: 100),
    ),
    Move(name: 'Glare', description: 'Stuns the foe.', baseDamage: 0, type: ElementalType.predator, stamina: 10, category: MoveCategory.status,
      effect: MoveEffect(type: MoveEffectType.statusStun, value: 1, chance: 100),
    ),
    Move(name: 'Poison Jab', description: 'Damage + Poison.', baseDamage: 80, type: ElementalType.venomous, stamina: 15, category: MoveCategory.physical,
      effect: MoveEffect(type: MoveEffectType.statusPoison, value: 3, chance: 30),
    ),
    
    // NEW COMPLEX MOVES
    Move(name: 'Giga Drain', description: 'A nutrient-draining attack. The user\'s HP is restored by half the damage taken by the target.', baseDamage: 75, drainPercent: 0.5, type: ElementalType.parasite, stamina: 10, category: MoveCategory.special),
    Move(name: 'Dig', description: 'The user burrows into the ground, then attacks on the next turn.', baseDamage: 80, type: ElementalType.burrowing, stamina: 10, category: MoveCategory.physical, effect: MoveEffect(type: MoveEffectType.semiInvulnerable, stat: 'underground')),
    Move(name: 'Rest', description: 'The user goes to sleep for two turns. This fully restores the user\'s HP.', baseDamage: 0, type: ElementalType.normal, stamina: 5, category: MoveCategory.status, effect: MoveEffect(type: MoveEffectType.heal, target: 'self', value: 999)), // Logic in BattleManager for Sleep
    Move(name: 'Protect', description: 'Enables the user to evade all attacks. Its chance of failing rises if it is used in succession.', baseDamage: 0, type: ElementalType.normal, stamina: 10, category: MoveCategory.status, effect: MoveEffect(type: MoveEffectType.protect)),
    Move(name: 'Sucker Punch', description: 'This move enables the user to attack first. This move fails if the target is not preparing an attack.', baseDamage: 70, priority: 1, type: ElementalType.predator, stamina: 5, category: MoveCategory.physical, failIfTargetNotAttacking: true),
    Move(name: 'Shell Smash', description: 'The user shatters its shell, which sharply raises Attack and Speed but lowers Defense.', baseDamage: 0, type: ElementalType.armored, stamina: 15, category: MoveCategory.status, effect: MoveEffect(type: MoveEffectType.multiStatChange, stat: 'attack:2,speed:2,defense:-1')),
    Move(name: 'Ancient Power', description: 'The user attacks with a prehistoric power. This may also raise all the user\'s stats at once.', baseDamage: 60, type: ElementalType.normal, stamina: 5, category: MoveCategory.special, effect: MoveEffect(type: MoveEffectType.statChangeChance, stat: 'attack:1,defense:1,speed:1', chance: 10)),
    Move(name: 'Assurance', description: 'If the target has already taken some damage in the same turn, this move\'s power is doubled.', baseDamage: 60, type: ElementalType.normal, stamina: 10, category: MoveCategory.physical, multiplierCondition: 'target_damaged', conditionalMultiplier: 2.0),
    Move(name: 'Baneful Bunker', description: 'In addition to protecting the user from attacks, this move also poisons any attacker that makes direct contact.', baseDamage: 0, type: ElementalType.venomous, stamina: 10, category: MoveCategory.status, effect: MoveEffect(type: MoveEffectType.protect, stat: 'poison')),
    Move(name: 'Barb Barrage', description: 'The user launches countless toxic spikes to inflict damage. This may also poison the target.', baseDamage: 60, type: ElementalType.venomous, stamina: 10, category: MoveCategory.special, effect: MoveEffect(type: MoveEffectType.statusPoison, chance: 30), multiplierCondition: 'target_poisoned', conditionalMultiplier: 2.0),
    Move(name: 'Belly Drum', description: 'The user maximizes its Attack stat in exchange for HP equal to half its max HP.', baseDamage: 0, type: ElementalType.social, stamina: 10, category: MoveCategory.status, effect: MoveEffect(type: MoveEffectType.multiStatChange, stat: 'attack:6', hpCostPercent: 0.5)),
    Move(name: 'Hyper Beam', description: 'The target is attacked with a powerful beam. The user can\'t move on the next turn.', baseDamage: 150, type: ElementalType.normal, stamina: 5, category: MoveCategory.special, effect: MoveEffect(type: MoveEffectType.recharge)),
    Move(name: 'Geomancy', description: 'The user absorbs energy and sharply raises its stats on the next turn.', baseDamage: 0, type: ElementalType.social, stamina: 10, category: MoveCategory.status, effect: MoveEffect(type: MoveEffectType.charge, stat: 'attack:2,defense:2,speed:2')),
    Move(name: 'Body Press', description: 'The user attacks by slamming its body into the target. The higher its Defense, the more damage it can inflict.', baseDamage: 80, type: ElementalType.armored, stamina: 10, category: MoveCategory.physical, damageStat: 'defense'),
    Move(name: 'Bulk Up', description: 'The user tenses its muscles to bulk up its body, raising both Attack and Defense stats.', baseDamage: 0, type: ElementalType.normal, stamina: 20, category: MoveCategory.status, effect: MoveEffect(type: MoveEffectType.multiStatChange, stat: 'attack:1,defense:1')),
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