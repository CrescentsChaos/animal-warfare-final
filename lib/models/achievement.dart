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
  final int requiredQuizCorrect; // NEW: Total quiz questions correct
  final int requiredHardQuizCorrect; // NEW: Total Hard questions correct
  final int requiredGenusQuizCorrect; // NEW: Total Genus questions correct
  final int requiredQuizStreak; // NEW: Max streak reached in any quiz
  final int requiredEchoWave; // NEW: Max wave reached in The Echo
  final int requiredHabitatScore; // NEW: Max score reached in Habitat Sort
  final int requiredSilhouetteScore; // NEW: Max score reached in Silhouette Sprint
  final int requiredShowdownStreak; // NEW: Max streak reached in Stat Showdown
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
    this.requiredQuizCorrect = 0,
    this.requiredHardQuizCorrect = 0,
    this.requiredGenusQuizCorrect = 0,
    this.requiredQuizStreak = 0,
    this.requiredEchoWave = 0,
    this.requiredHabitatScore = 0,
    this.requiredSilhouetteScore = 0,
    this.requiredShowdownStreak = 0,
    this.tier = 'bronze',
    this.imagePath,
  });

  String get id => title;

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
      requiredQuizCorrect: json['requiredQuizCorrect'] as int? ?? 0,
      requiredHardQuizCorrect: json['requiredHardQuizCorrect'] as int? ?? 0,
      requiredGenusQuizCorrect: json['requiredGenusQuizCorrect'] as int? ?? 0,
      requiredQuizStreak: json['requiredQuizStreak'] as int? ?? 0,
      requiredEchoWave: json['requiredEchoWave'] as int? ?? 0,
      requiredHabitatScore: json['requiredHabitatScore'] as int? ?? 0,
      requiredSilhouetteScore: json['requiredSilhouetteScore'] as int? ?? 0,
      requiredShowdownStreak: json['requiredShowdownStreak'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'bronze',
      imagePath: json['imagePath'] as String?,
    );
  }

  factory Achievement.empty() {
    return Achievement(
      title: 'empty',
      description: '',
      requiredCount: 0,
    );
  }
}
