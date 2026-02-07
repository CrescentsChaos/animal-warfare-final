// lib/models/move.dart
// Defines the structure for an animal's attack

import 'dart:math';

// Enum for the type of effect a move can apply
enum MoveEffectType {
  none,
  statusPoison, // Applies a damage-over-time status
  statusSleep,  // Prevents action for a turn
  statChange,   // Changes an attacker's or defender's stat
  heal,         // Restores HP
}

// Model for the effect component of a Move
class MoveEffect {
  final MoveEffectType type;
  final String target; // 'self', 'opponent'
  final String stat;   // e.g., 'attack', 'defense', only for statChange
  final int value;     // The magnitude of the change (e.g., stat boost level or damage/heal amount)
  
  const MoveEffect({
    required this.type,
    this.target = 'opponent',
    this.stat = '',
    this.value = 0,
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
    );
  }
}

class Move {
  final String name;
  final String description;
  final int baseDamage;
  final int accuracy; // 0 to 100
  final MoveEffect effect;
  
  const Move({
    required this.name,
    required this.description,
    required this.baseDamage,
    this.accuracy = 100,
    this.effect = const MoveEffect(type: MoveEffectType.none),
  });

  // Constructor for loading Move from JSON
  factory Move.fromJson(Map<String, dynamic> json) {
    return Move(
      name: json['name'] as String,
      description: json['description'] as String,
      baseDamage: json['baseDamage'] as int,
      accuracy: json['accuracy'] as int? ?? 100,
      effect: json['effect'] != null
          ? MoveEffect.fromJson(json['effect'] as Map<String, dynamic>)
          : const MoveEffect(type: MoveEffectType.none),
    );
  }
  
  // FIX: Make the static list private and use a helper function to access it.
  static const List<Move> _allMoves = [
    Move(name: 'Scratch', description: 'A basic attack.', baseDamage: 10,),
    Move(name: 'Venom Sting', description: 'May poison the foe.', baseDamage: 8,
      effect: MoveEffect(type: MoveEffectType.statusPoison, value: 3), // 3 turns of poison
    ),
    Move(name: 'Hunker Down', description: 'Raises the user\'s defense.', baseDamage: 0,
      effect: MoveEffect(type: MoveEffectType.statChange, target: 'self', stat: 'defense', value: 1), // +1 Defense stage
    ),
    Move(name: 'Hibernate', description: 'A healing nap.', baseDamage: 0,
      effect: MoveEffect(type: MoveEffectType.heal, target: 'self', value: 20), // Heals 20 HP
    ),
    // Add more moves here as constants
  ];
  
  // 💡 FIX: Add public static getter to allow access to the private list.
  static List<Move> get allMoves => _allMoves;
  
  /// Find a move by name in the predefined list.
  static Move? findByName(String name) {
    try {
      return _allMoves.firstWhere((m) => m.name.toLowerCase() == name.toLowerCase());
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
    );
  }
}