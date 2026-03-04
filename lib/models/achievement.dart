// lib/models/achievement.dart

class Achievement {
  final String title;
  final String description;

  // Rarity-based fields (Used for existing logic, e.g., "Collect 10 Common")
  final String requiredRarity;
  final int requiredCount;

  // NEW: Specific Organism/Group fields (Used for new custom logic)
  final List<String>
  requiredOrganisms; // List of specific organism names, e.g., ['African Lion']
  final int
  requiredSpecificCount; // Required number from the list, e.g., 1 or 5
  final int requiredFloor; // NEW: Floor reached in Rogue-like mode
  final String tier; // NEW: Medal tier (bronze, silver, gold)
  final String? imagePath; // NEW: Path to the achievement medal image

  Achievement({
    required this.title,
    required this.description,
    this.requiredRarity = '',
    this.requiredCount = 0,
    // NEW FIELDS
    this.requiredOrganisms = const [],
    this.requiredSpecificCount = 0,
    this.requiredFloor = 0,
    this.tier = 'bronze',
    this.imagePath,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      title: json['title'] as String? ?? 'Unnamed Achievement',
      description: json['description'] as String? ?? 'No description provided.',
      requiredRarity: json['requiredRarity'] as String? ?? '',
      requiredCount: json['requiredCount'] as int? ?? 0,
      // NEW: Safely deserialize new fields
      requiredOrganisms:
          (json['requiredOrganisms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      requiredSpecificCount: json['requiredSpecificCount'] as int? ?? 0,
      requiredFloor: json['requiredFloor'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'bronze',
      imagePath: json['imagePath'] as String?,
    );
  }
}
