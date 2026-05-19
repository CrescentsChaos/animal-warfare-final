// lib/game/trainer_data.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Represents a generated trainer with a title, name, sprite, and dialogue pool.
class TrainerInfo {
  final String title;
  final String name;
  final String sprite; // filename inside assets/npc/
  final String gender; // 'male' or 'female'
  final List<String> introDialogue;
  final List<String> midBattleDialogue;
  final List<String> defeatDialogue;
  final List<String> biomeExclusive; // empty = appears anywhere
  final String? preferredClass;
  final String? preferredType;

  const TrainerInfo({
    required this.title,
    required this.name,
    required this.sprite,
    required this.gender,
    required this.introDialogue,
    required this.midBattleDialogue,
    required this.defeatDialogue,
    this.biomeExclusive = const [],
    this.preferredClass,
    this.preferredType,
  });

  /// Full display name, e.g. "Youngster Joey"
  String get displayName => '$title $name';

  /// Full sprite asset path
  String get spritePath => 'assets/npc/$sprite';

  /// Pick a random intro line.
  String randomIntro([Random? rng]) {
    final r = rng ?? Random();
    return introDialogue[r.nextInt(introDialogue.length)];
  }

  /// Pick a random mid-battle line.
  String randomMidBattle([Random? rng]) {
    final r = rng ?? Random();
    return midBattleDialogue[r.nextInt(midBattleDialogue.length)];
  }

  /// Pick a random defeat line.
  String randomDefeat([Random? rng]) {
    final r = rng ?? Random();
    return defeatDialogue[r.nextInt(defeatDialogue.length)];
  }

  /// Whether this trainer is biome-exclusive.
  bool get isBiomeExclusive => biomeExclusive.isNotEmpty;

  /// Whether this trainer can appear in the given biome.
  bool matchesBiome(String biomeName) {
    if (biomeExclusive.isEmpty) return true; // universal trainer
    return biomeExclusive.any(
      (b) => biomeName.toLowerCase().contains(b.toLowerCase()),
    );
  }
}

/// Loads trainer definitions from assets/trainers.json and generates
/// random TrainerInfo instances for trainer battles.
class TrainerDataLoader {
  static Map<String, dynamic>? _data;
  static final Random _rng = Random();

  /// Load the JSON file. Call once at startup.
  static Future<void> loadData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/trainers.json');
      _data = json.decode(jsonStr) as Map<String, dynamic>;
      debugPrint('TrainerDataLoader: Loaded trainer data successfully.');
    } catch (e, stack) {
      debugPrint('TrainerDataLoader Error: $e');
      debugPrint(stack.toString());
      _data = {};
    }
  }

  /// Generate a random trainer. Optionally constrain by gender and/or biome.
  /// When a biome is provided, there's a 40% chance a biome-exclusive trainer
  /// is chosen (if one exists for that biome). Otherwise a universal trainer is picked.
  static TrainerInfo generateRandom({String? gender, String? biome, Random? rng}) {
    final r = rng ?? _rng;

    if (_data == null || _data!.isEmpty) {
      return _fallbackTrainer();
    }

    // Pick gender
    final chosenGender = gender ?? (r.nextBool() ? 'male' : 'female');
    final genderData = _data![chosenGender] as Map<String, dynamic>?;
    if (genderData == null) return _fallbackTrainer();

    final titles = genderData['titles'] as List<dynamic>? ?? [];
    if (titles.isEmpty) return _fallbackTrainer();

    // If biome provided, try to pick a biome-exclusive trainer (40% chance)
    Map<String, dynamic>? titleEntry;
    if (biome != null && r.nextDouble() < 0.4) {
      final biomeMatches = titles.where((t) {
        final biomes = (t as Map<String, dynamic>)['biome_exclusive'] as List<dynamic>?;
        if (biomes == null || biomes.isEmpty) return false;
        return biomes.any((b) => biome.toLowerCase().contains((b as String).toLowerCase()));
      }).toList();
      if (biomeMatches.isNotEmpty) {
        titleEntry = biomeMatches[r.nextInt(biomeMatches.length)] as Map<String, dynamic>;
      }
    }

    // Fallback to any trainer
    titleEntry ??= titles[r.nextInt(titles.length)] as Map<String, dynamic>;
    final title = titleEntry['title'] as String? ?? 'Trainer';
    
    // Check for multiple sprites
    String sprite = 'gentleman.webp';
    final spritesList = titleEntry['sprites'] as List<dynamic>?;
    if (spritesList != null && spritesList.isNotEmpty) {
      sprite = spritesList[r.nextInt(spritesList.length)] as String;
    } else if (titleEntry['sprite'] != null) {
      sprite = titleEntry['sprite'] as String;
    }
    
    final names = (titleEntry['names'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        ['???'];
    final introDialogue = (titleEntry['intro_dialogue'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        ['...'];
    final midBattleDialogue =
        (titleEntry['mid_battle_dialogue'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            ['...'];
    final defeatDialogue = (titleEntry['defeat_dialogue'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        ['...'];

    // Pick random name
    final name = names[r.nextInt(names.length)];

    return TrainerInfo(
      title: title,
      name: name,
      sprite: sprite,
      gender: chosenGender,
      introDialogue: introDialogue,
      midBattleDialogue: midBattleDialogue,
      defeatDialogue: defeatDialogue,
      biomeExclusive: (titleEntry['biome_exclusive'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      preferredClass: titleEntry['preferred_class'] as String?,
      preferredType: titleEntry['preferred_type'] as String?,
    );
  }

  /// Generate a trainer for a specific title (case-insensitive).
  static TrainerInfo? generateByTitle(String targetTitle, {String? gender}) {
    if (_data == null || _data!.isEmpty) return null;

    for (final g in (gender != null ? [gender] : ['male', 'female'])) {
      final genderData = _data![g] as Map<String, dynamic>?;
      if (genderData == null) continue;

      final titles = genderData['titles'] as List<dynamic>? ?? [];
      for (final entry in titles) {
        final map = entry as Map<String, dynamic>;
        if ((map['title'] as String?)?.toLowerCase() ==
            targetTitle.toLowerCase()) {
          final names = (map['names'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              ['???'];
          final name = names[_rng.nextInt(names.length)];
          
          String sprite = 'gentleman.webp';
          final spritesList = map['sprites'] as List<dynamic>?;
          if (spritesList != null && spritesList.isNotEmpty) {
            sprite = spritesList[_rng.nextInt(spritesList.length)] as String;
          } else if (map['sprite'] != null) {
            sprite = map['sprite'] as String;
          }

          return TrainerInfo(
            title: map['title'] as String? ?? targetTitle,
            name: name,
            sprite: sprite,
            gender: g,
            introDialogue: (map['intro_dialogue'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                ['...'],
            midBattleDialogue: (map['mid_battle_dialogue'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                ['...'],
            defeatDialogue: (map['defeat_dialogue'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                ['...'],
            biomeExclusive: (map['biome_exclusive'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            preferredClass: map['preferred_class'] as String?,
            preferredType: map['preferred_type'] as String?,
          );
        }
      }
    }
    return null;
  }

  /// Generate a trainer from a full name (e.g., "Youngster Joey" -> title "Youngster", name "Joey")
  static TrainerInfo? generateByName(String fullName) {
    if (_data == null || _data!.isEmpty) return null;

    // Clean prefix like "VS ", "vs "
    String cleaned = fullName.replaceFirst(RegExp(r'^[vV][sS]\s+'), '').trim();

    for (final g in ['male', 'female']) {
      final genderData = _data![g] as Map<String, dynamic>?;
      if (genderData == null) continue;

      final titles = genderData['titles'] as List<dynamic>? ?? [];
      for (final entry in titles) {
        final map = entry as Map<String, dynamic>;
        final title = map['title'] as String? ?? '';
        if (title.isNotEmpty && cleaned.toLowerCase().startsWith(title.toLowerCase())) {
          String namePart = cleaned.substring(title.length).trim();
          if (namePart.isEmpty) {
            final names = (map['names'] as List<dynamic>?)?.map((e) => e as String).toList() ?? ['???'];
            namePart = names[_rng.nextInt(names.length)];
          }

          String sprite = 'gentleman.webp';
          final spritesList = map['sprites'] as List<dynamic>?;
          if (spritesList != null && spritesList.isNotEmpty) {
            sprite = spritesList[_rng.nextInt(spritesList.length)] as String;
          } else if (map['sprite'] != null) {
            sprite = map['sprite'] as String;
          }

          return TrainerInfo(
            title: title,
            name: namePart,
            sprite: sprite,
            gender: g,
            introDialogue: (map['intro_dialogue'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                ['...'],
            midBattleDialogue: (map['mid_battle_dialogue'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                ['...'],
            defeatDialogue: (map['defeat_dialogue'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                ['...'],
            biomeExclusive: (map['biome_exclusive'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            preferredClass: map['preferred_class'] as String?,
            preferredType: map['preferred_type'] as String?,
          );
        }
      }
    }
    return null;
  }

  /// Fallback trainer when data is unavailable.
  static TrainerInfo _fallbackTrainer() {
    return const TrainerInfo(
      title: 'Trainer',
      name: 'Unknown',
      sprite: 'gentleman.webp',
      gender: 'male',
      introDialogue: ['Let\'s battle!'],
      midBattleDialogue: ['Here comes my next animal!'],
      defeatDialogue: ['You won! Good battle!'],
    );
  }
}
