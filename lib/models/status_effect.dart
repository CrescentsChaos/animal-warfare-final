// lib/models/status_effect.dart
import 'package:flutter/material.dart';

enum StatusEffectType {
  none,
  poison,
  burn,
  sleep,
  paralysis,
  freeze,
  bleed, // DoT, heavy
  confusion, // Chance to hit self
  blind, // Lower accuracy
  regen, // Heal over time
  vulnerable, // Take extra damage
  stun, // Skip turn (1 turn usually)
  fear, // Reduces all stats by 10%
  marked, // Takes 20% extra damage
}

class StatusEffect {
  final StatusEffectType type;
  final int duration; // -1 for indefinite

  const StatusEffect({required this.type, this.duration = -1});

  Map<String, dynamic> toJson() => {'type': type.name, 'duration': duration};

  factory StatusEffect.fromJson(Map<String, dynamic> json) {
    return StatusEffect(
      type: StatusEffectType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StatusEffectType.none,
      ),
      duration: json['duration'] as int? ?? -1,
    );
  }

  StatusEffect copyWith({StatusEffectType? type, int? duration}) {
    return StatusEffect(
      type: type ?? this.type,
      duration: duration ?? this.duration,
    );
  }

  String get name {
    switch (type) {
      case StatusEffectType.poison:
        return 'Poison';
      case StatusEffectType.burn:
        return 'Burn';
      case StatusEffectType.sleep:
        return 'Sleep';
      case StatusEffectType.paralysis:
        return 'Paralysis';
      case StatusEffectType.freeze:
        return 'Freeze';
      case StatusEffectType.bleed:
        return 'Bleed';
      case StatusEffectType.confusion:
        return 'Confusion';
      case StatusEffectType.blind:
        return 'Blind';
      case StatusEffectType.regen:
        return 'Regen';
      case StatusEffectType.vulnerable:
        return 'Vulnerable';
      case StatusEffectType.stun:
        return 'Stunned';
      case StatusEffectType.fear:
        return 'Fear';
      case StatusEffectType.marked:
        return 'Marked';
      default:
        return 'None';
    }
  }

  String get startMessage {
    switch (type) {
      case StatusEffectType.poison:
        return 'was poisoned!';
      case StatusEffectType.burn:
        return 'was burned!';
      case StatusEffectType.sleep:
        return 'fell asleep!';
      case StatusEffectType.paralysis:
        return 'is paralyzed! It may be unable to move!';
      case StatusEffectType.freeze:
        return 'was frozen solid!';
      case StatusEffectType.bleed:
        return 'is bleeding profusely!';
      case StatusEffectType.confusion:
        return 'became confused!';
      case StatusEffectType.blind:
        return 'was blinded!';
      case StatusEffectType.regen:
        return 'started regenerating health!';
      case StatusEffectType.vulnerable:
        return 'became vulnerable to attacks!';
      case StatusEffectType.stun:
        return 'was stunned!';
      case StatusEffectType.fear:
        return 'is trembling with fear!';
      case StatusEffectType.marked:
        return 'was marked for death!';
      default:
        return '';
    }
  }

  Color get color {
    switch (type) {
      case StatusEffectType.poison:
        return Colors.purple;
      case StatusEffectType.burn:
        return Colors.deepOrange;
      case StatusEffectType.sleep:
        return Colors.lightBlue;
      case StatusEffectType.paralysis:
        return Colors.amber;
      case StatusEffectType.freeze:
        return Colors.cyan;
      case StatusEffectType.bleed:
        return Colors.red[900]!;
      case StatusEffectType.confusion:
        return Colors.purpleAccent;
      case StatusEffectType.blind:
        return Colors.grey;
      case StatusEffectType.regen:
        return Colors.green;
      case StatusEffectType.vulnerable:
        return Colors.pink;
      case StatusEffectType.stun:
        return Colors.brown;
      case StatusEffectType.fear:
        return Colors.indigo;
      case StatusEffectType.marked:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String get description {
    switch (type) {
      case StatusEffectType.poison:
        return 'Takes 12.5% max HP damage each turn.';
      case StatusEffectType.burn:
        return 'Takes 6% max HP damage each turn and physical damage is halved.';
      case StatusEffectType.sleep:
        return 'Cannot move for 2-5 turns.';
      case StatusEffectType.paralysis:
        return 'Speed is reduced by 75% and may fail to move.';
      case StatusEffectType.freeze:
        return 'Cannot move until thawed.';
      case StatusEffectType.bleed:
        return 'Takes 12.5% max HP damage each turn.';
      case StatusEffectType.confusion:
        return 'May hit itself instead of attacking.';
      case StatusEffectType.blind:
        return 'Accuracy is reduced by 25%.';
      case StatusEffectType.regen:
        return 'Restores 6% max HP each turn.';
      case StatusEffectType.vulnerable:
        return 'Takes increased damage from attacks.';
      case StatusEffectType.stun:
        return 'Cannot move for 1 turn.';
      case StatusEffectType.fear:
        return 'All stats are reduced by 10%.';
      case StatusEffectType.marked:
        return 'Takes 20% extra damage for 2 turns.';
      default:
        return 'No current effect.';
    }
  }
}
