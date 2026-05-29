// lib/models/player_active_effect.dart

class PlayerActiveEffect {
  final String id; // The item ID that caused it, e.g. "epic_mammal_lure"
  final String name; // The display name of the lure/effect
  final String targetType; // "class", "order", or "subfamily"
  final String targetValue; // The value to match (e.g., "mammal", "carnivora")
  final double multiplier; // Encounter weight multiplier (e.g., 3.0)
  final DateTime expiresAt; // Absolute timestamp when this effect expires

  PlayerActiveEffect({
    required this.id,
    required this.name,
    required this.targetType,
    required this.targetValue,
    required this.multiplier,
    required this.expiresAt,
  });

  /// Check if the buff has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetType': targetType,
        'targetValue': targetValue,
        'multiplier': multiplier,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory PlayerActiveEffect.fromJson(Map<String, dynamic> json) {
    return PlayerActiveEffect(
      id: json['id'] as String,
      name: json['name'] as String,
      targetType: json['targetType'] as String,
      targetValue: json['targetValue'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
