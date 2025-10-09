// lib/models/achievement.dart

class Achievement {
  final String title;
  final String description;
  final String requiredRarity;
  final int requiredCount;

  Achievement({
    required this.title,
    required this.description,
    required this.requiredRarity,
    required this.requiredCount,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      title: json['title'] as String,
      description: json['description'] as String,
      requiredRarity: json['requiredRarity'] as String,
      requiredCount: json['requiredCount'] as int,
    );
  }
}