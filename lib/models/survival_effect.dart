import 'package:animal_warfare/services/weather_service.dart';

class SurvivalEffect {
  final String id;
  final String name;
  final EnvironmentalSeverity mitigatesSeverity;
  final double damageReductionMultiplier; // e.g., 0.5 reduces drain by half, 0.0 prevents it
  final DateTime expiresAt;

  SurvivalEffect({
    required this.id,
    required this.name,
    required this.mitigatesSeverity,
    this.damageReductionMultiplier = 0.0,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mitigatesSeverity': mitigatesSeverity.toString(),
        'damageReductionMultiplier': damageReductionMultiplier,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory SurvivalEffect.fromJson(Map<String, dynamic> json) {
    return SurvivalEffect(
      id: json['id'] as String,
      name: json['name'] as String,
      mitigatesSeverity: EnvironmentalSeverity.values.firstWhere(
        (e) => e.toString() == json['mitigatesSeverity'],
        orElse: () => EnvironmentalSeverity.comfortable,
      ),
      damageReductionMultiplier:
          (json['damageReductionMultiplier'] as num?)?.toDouble() ?? 0.0,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
