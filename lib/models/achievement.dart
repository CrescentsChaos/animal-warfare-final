// lib/models/achievement.dart

class Achievement {
  final String title;
  final String description;
  
  // Rarity-based fields (Used for existing logic, e.g., "Collect 10 Common")
  final String requiredRarity; 
  final int requiredCount; 
  
  // NEW: Specific Organism/Group fields (Used for new custom logic)
  final List<String> requiredOrganisms; // List of specific organism names, e.g., ['African Lion']
  final int requiredSpecificCount;      // Required number from the list, e.g., 1 or 5

  Achievement({
    required this.title,
    required this.description,
    this.requiredRarity = '',
    this.requiredCount = 0,
    // NEW FIELDS
    this.requiredOrganisms = const [], 
    this.requiredSpecificCount = 0,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      title: json['title'] as String? ?? 'Unnamed Achievement',
      description: json['description'] as String? ?? 'No description provided.',
      requiredRarity: json['requiredRarity'] as String? ?? '',
      requiredCount: json['requiredCount'] as int? ?? 0,
      // NEW: Safely deserialize new fields
      requiredOrganisms: (json['requiredOrganisms'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      requiredSpecificCount: json['requiredSpecificCount'] as int? ?? 0,
    );
  }
}