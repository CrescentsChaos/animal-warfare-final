// lib/services/news_service.dart

import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/game/time_service.dart';

/// A fake comment on a news article.
class NewsComment {
  final String user;
  final String text;
  final String timeAgo;

  const NewsComment({
    required this.user,
    required this.text,
    required this.timeAgo,
  });
}

/// A single news article displayed in the feed.
class NewsArticle {
  final String headline;
  final String body;
  final String channel;
  final String author;
  final String channelIcon; // emoji or path to assets/npc/author_icons/
  final String? channelTagline;
  final String category; // e.g. 'ECOLOGY', 'BATTLE', 'SCIENCE', etc.
  final String? organismName; // featured organism, if any
  final String? spritePath;
  final String? biome; // NEW: The primary habitat/biome for background imagery
  final String? habitatName; // NEW: The display name of the selected habitat
  final DateTime publishedAt; // in-game time
  final String? authorIcon; // Path to assets/npc/author_icons/
  final int seed;
  int likes;
  int commentsCount;
  int shares;
  final List<NewsComment> comments;
  bool isLiked; // Track player interaction (mock)

  NewsArticle({
    required this.headline,
    required this.body,
    required this.channel,
    required this.author,
    required this.channelIcon,
    this.channelTagline,
    required this.category,
    this.organismName,
    this.spritePath,
    this.biome,
    this.habitatName,
    this.authorIcon,
    required this.publishedAt,
    required this.seed,
    required this.likes,
    required this.commentsCount,
    required this.shares,
    required this.comments,
    this.isLiked = false,
  });
}

/// Generates deterministic daily news from organism database.
class NewsService {
  static List<Map<String, dynamic>> _channels = [];
  static List<String> _authors = [];
  static List<String> _categories = [];
  static List<Map<String, dynamic>> _templates = [];
  static Map<String, List<Map<String, dynamic>>> _templatesByCategory = {};
  static List<String> _usernames = [];
  static Map<String, List<String>> _commentTemplates = {};
  static bool _isInitialized = false;
  static int refreshSeed = 0;

  /// Loads news configuration from assets/news_config.json
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final jsonString = await rootBundle.loadString('assets/news_config.json');
      final data = json.decode(jsonString);
      _channels = List<Map<String, dynamic>>.from(data['channels']);
      _authors = List<String>.from(data['authors']);
      _categories = List<String>.from(data['categories']);
      _templates = List<Map<String, dynamic>>.from(data['templates']);
      final rawUsernames = data['usernames'];
      _usernames = [];
      if (rawUsernames is List) {
        for (var item in rawUsernames) {
          if (item is String) {
            _usernames.add(item);
          } else if (item is List) {
            _usernames.addAll(item.map((e) => e.toString()));
          }
        }
      }
      if (_usernames.isEmpty) {
        _usernames = ['User123', 'NatureLover', 'BattlePro'];
      }

      final Map<String, dynamic> comments = data['comment_templates'] ?? {};
      _commentTemplates = comments.map((key, value) {
        if (value is List) {
          return MapEntry(key, value.map((e) => e.toString()).toList());
        }
        return MapEntry(key, <String>[]);
      });

      _templatesByCategory = {};
      for (var t in _templates) {
        final cat = t['category'] ?? 'GENERAL';
        _templatesByCategory.putIfAbsent(cat, () => []).add(t);
      }

      _isInitialized = true;
    } catch (e) {
      // Fallback defaults if file missing
      _channels = [
        {
          'name': 'WildWatch Daily',
          'icon': '🌿',
          'tagline': 'Eyes on nature, 24/7',
        },
      ];
      _authors = ['Dr. Elena Marsh'];
      _categories = ['ECOLOGY'];
      _templates = [
        {
          'headline': '{name}: Spotlight',
          'body': '{name} is a {rarity} {animal_class}.',
          'category': 'PROFILE',
        },
      ];
      _usernames = ['User123', 'NatureLover', 'BattlePro'];
      _commentTemplates = {
        'GENERAL': ['Interesting!', 'Cool!'],
      };
      _isInitialized = true; // Still mark as initialized to allow fallback news
    }
  }

  /// Generate today's news feed from organism data.
  /// Uses the game's daily seed so all players see the same feed.
  static List<NewsArticle> generateDailyNews(
    List<Organism> organisms,
    GameTime gameTime, {
    int refreshSeed = 0,
  }) {
    if (organisms.isEmpty || !_isInitialized) return [];

    final seed = gameTime.dailySeed + refreshSeed;
    final rng = Random(seed);
    const int initialCount = 15;

    final shuffled = List<Organism>.from(organisms)..shuffle(rng);
    final articles = <NewsArticle>[];

    // Master list of required topics (all except PALEONTOLOGY)
    final List<String> requiredTopics = [
      'ECOLOGY',
      'SCIENCE',
      'BATTLE META',
      'EXPLORATION',
      'DISCOVERY',
      'STATISTICS',
      'PROFILE',
      'OPINION',
      'CONSERVATION',
      'TAXONOMY',
      'BIOMETRICS',
      'WEATHER',
      'FIELD STING',
      'SURVIVAL GUIDE',
      'TIER LIST',
      'WILDLIFE DOC',
      'COOKING',
      'CRIME',
    ];

    // Phase 1: Generate initial random articles
    for (int i = 0; i < initialCount; i++) {
      final article = _generateArticle(organisms, shuffled, i, seed, gameTime);
      if (article != null) articles.add(article);
    }

    // Phase 2: Ensure Category Coverage
    final existingCategories = articles.map((a) => a.category).toSet();
    final missingCategories = requiredTopics
        .where((t) => !existingCategories.contains(t))
        .toList();

    for (int i = 0; i < missingCategories.length; i++) {
      final category = missingCategories[i];

      // Find a suitable organism for this category
      Organism? targetOrg;
      if (category == 'COOKING') {
        final candidates = organisms
            .where(
              (o) =>
                  (o.animalClass == 'Mollusk' ||
                  o.animalClass == 'Crustacean' ||
                  o.animalClass == 'Bird' ||
                  o.animalClass == 'Fish' ||
                  (o.animalClass == 'Mammal' && o.diet == 'Herbivore')),
            )
            .toList();
        targetOrg = candidates.isNotEmpty
            ? candidates[rng.nextInt(candidates.length)]
            : organisms[rng.nextInt(organisms.length)];
      } else if (category == 'CRIME') {
        final candidates = organisms
            .where(
              (o) =>
                  (o.attack > 80 || o.diet.toLowerCase().contains('carnivore')),
            )
            .toList();
        targetOrg = candidates.isNotEmpty
            ? candidates[rng.nextInt(candidates.length)]
            : organisms[rng.nextInt(organisms.length)];
      } else {
        targetOrg = organisms[rng.nextInt(organisms.length)];
      }

      // Force generate an article for this category
      final article = _generateArticle(
        organisms,
        shuffled,
        initialCount + i,
        seed,
        gameTime,
        forcedCategory: category,
        forcedOrg: targetOrg,
      );
      if (article != null) articles.add(article);
    }

    return articles;
  }

  /// Helper to generate a single article, optionally forcing a category or organism.
  static NewsArticle? _generateArticle(
    List<Organism> allOrganisms,
    List<Organism> shuffled,
    int index,
    int seed,
    GameTime gameTime, {
    String? forcedCategory,
    Organism? forcedOrg,
  }) {
    final articleSeed = seed + index;
    final articleRng = Random(articleSeed);

    final org = forcedOrg ?? shuffled[index % shuffled.length];

    // Logic for valid categories
    final List<String> availableCategories = [
      'ECOLOGY',
      'SCIENCE',
      'BATTLE META',
      'EXPLORATION',
      'DISCOVERY',
      'STATISTICS',
      'PROFILE',
      'OPINION',
      'CONSERVATION',
      'TAXONOMY',
      'BIOMETRICS',
      'WEATHER',
      'FIELD STING',
      'SURVIVAL GUIDE',
      'TIER LIST',
      'WILDLIFE DOC',
    ];

    final isFoodClass =
        org.animalClass == 'Bird' ||
        org.animalClass == 'Fish' ||
        (org.animalClass == 'Mammal' && org.diet == 'Herbivore');
    final hasFoodDrops =
        org.drops.toLowerCase().contains('meat') ||
        org.drops.toLowerCase().contains('fillet') ||
        org.drops.toLowerCase().contains('egg');
    if (isFoodClass && hasFoodDrops) {
      availableCategories.add('COOKING');
    }

    if (org.rarity == 'Rare' ||
        org.rarity == 'Epic' ||
        org.rarity == 'Legendary' ||
        org.attack > 100) {
      availableCategories.add('CRIME');
    }

    final category =
        forcedCategory ??
        availableCategories[articleRng.nextInt(availableCategories.length)];

    // Mythical animals are extinct - force PALEONTOLOGY unless a specific category was requested
    final finalCategory = (org.rarity == 'Mythical' && forcedCategory == null)
        ? 'PALEONTOLOGY'
        : category;

    final categoryTemplates = _templatesByCategory[finalCategory] ?? _templates;

    // Filter templates: Ensure author compatibility
    final compatibleTemplates = categoryTemplates.where((t) {
      final tAuthor = t['author'];
      if (tAuthor == null) return true;
      return _isAuthorCompatible(tAuthor, org);
    }).toList();

    final templatePool = compatibleTemplates.isNotEmpty
        ? compatibleTemplates
        : categoryTemplates;
    final template = templatePool[articleRng.nextInt(templatePool.length)];

    // Smart picking for org2
    Organism org2 = shuffled[(index + 13) % shuffled.length];
    for (int j = 1; j < 40; j++) {
      final candidate = shuffled[(index + j * 17) % shuffled.length];
      if (candidate.name == org.name) continue;

      final sameHabitat = candidate.habitat == org.habitat;
      final isSmaller = candidate.weight < org.weight;
      final dietMatch = _isDietMatch(org, candidate);

      if (sameHabitat && (isSmaller || dietMatch)) {
        org2 = candidate;
        break;
      }
    }

    final isComparison =
        template['type'] == 'comparison' ||
        template['headline'].toLowerCase().contains('hunt') ||
        template['headline'].toLowerCase().contains('target');

    if (isComparison) {
      final diet = org.diet.toLowerCase();
      final orgHabitats = org.habitat
          .split(',')
          .map((h) => h.trim().toLowerCase())
          .toList();

      final potentialPrey = allOrganisms.where((cand) {
        if (cand.name == org.name) return false;
        final candHabitats = cand.habitat
            .split(',')
            .map((h) => h.trim().toLowerCase())
            .toList();
        bool sharesHabitat = orgHabitats.any((h) => candHabitats.contains(h));
        if (!sharesHabitat) return false;

        final candClass = cand.animalClass.toLowerCase();
        if (diet == 'insectivore') {
          return candClass == 'insect' || candClass == 'arachnid';
        }
        if (diet == 'piscivore') return candClass == 'fish';
        if (diet == 'carnivore' || diet == 'omnivore') {
          return cand.weight < org.weight ||
              !cand.diet.toLowerCase().contains('carnivore');
        }
        if (diet == 'sanguivore') {
          return cand.animalClass == 'Mammal' || cand.animalClass == 'Bird';
        }
        if (diet == 'parasite') return cand.weight > org.weight;
        return true;
      }).toList();

      if (potentialPrey.isNotEmpty) {
        if (diet == 'parasite') {
          potentialPrey.sort((a, b) => b.weight.compareTo(a.weight));
        } else {
          potentialPrey.sort((a, b) => a.weight.compareTo(b.weight));
        }
        final poolSize = (potentialPrey.length * 0.3).ceil().clamp(
          1,
          potentialPrey.length,
        );
        org2 = potentialPrey[articleRng.nextInt(poolSize)];
      }
    }

    Map<String, dynamic> channel =
        _channels[articleRng.nextInt(_channels.length)];
    if (finalCategory == 'COOKING') {
      final candidates = _channels.where((c) => c['name'] == 'TLC').toList();
      if (candidates.isNotEmpty) {
        channel = candidates[articleRng.nextInt(candidates.length)];
      }
    } else if (finalCategory == 'CRIME') {
      final candidates = _channels
          .where((c) => ['CNN', 'Fox News', 'BBC'].contains(c['name']))
          .toList();
      if (candidates.isNotEmpty) {
        channel = candidates[articleRng.nextInt(candidates.length)];
      }
    } else if (finalCategory == 'PALEONTOLOGY') {
      final candidates = _channels
          .where((c) => c['name'] == 'Discovery Channel' || c['name'] == 'CNN')
          .toList();
      if (candidates.isNotEmpty) {
        channel = candidates[articleRng.nextInt(candidates.length)];
      }
    } else if (finalCategory == 'FIELD STING') {
      final candidates = _channels
          .where((c) => c['name'] == 'Animal Planet')
          .toList();
      if (candidates.isNotEmpty) {
        channel = candidates[articleRng.nextInt(candidates.length)];
      }
    } else if (finalCategory == 'SURVIVAL GUIDE') {
      final candidates = _channels
          .where((c) => c['name'] == 'Discovery Channel')
          .toList();
      if (candidates.isNotEmpty) {
        channel = candidates[articleRng.nextInt(candidates.length)];
      }
    } else if (finalCategory == 'TIER LIST') {
      final candidates = _channels
          .where((c) => c['name'] == 'YouTube')
          .toList();
      if (candidates.isNotEmpty) {
        channel = candidates[articleRng.nextInt(candidates.length)];
      }
    } else if (finalCategory == 'WILDLIFE DOC' ||
        finalCategory == 'CONSERVATION') {
      final candidates = _channels
          .where((c) => c['name'] == "National Geographic")
          .toList();
      if (candidates.isNotEmpty) {
        channel = candidates[articleRng.nextInt(candidates.length)];
      }
    }

    final compatibleAuthors = _authors
        .where((a) => _isAuthorCompatible(a, org))
        .toList();
    final authorPool = compatibleAuthors.isNotEmpty
        ? compatibleAuthors
        : _authors;
    final author =
        template['author'] ?? authorPool[articleRng.nextInt(authorPool.length)];

    return _buildArticleFromTemplate(
      template,
      org,
      org2,
      articleRng,
      channel,
      author,
      gameTime,
      articleSeed,
    );
  }

  static NewsArticle _buildArticleFromTemplate(
    Map<String, dynamic> template,
    Organism org,
    Organism org2,
    Random rng,
    Map<String, dynamic> channel,
    String author,
    GameTime time,
    int seed,
  ) {
    String headline = template['headline'] ?? 'Untitled';
    String body = template['body'] ?? 'No content.';
    String category = template['category'] ?? 'OTHER';

    // Use shared replacement logic
    final replacements = _getReplacements(org, org2, rng, time);

    // Apply replacements to headline and body
    headline = _applyReplacements(headline, replacements);
    body = _applyReplacements(body, replacements);

    // BREAKING NEWS logic for high rarity
    if (org.rarity == 'Legendary' || org.rarity == 'Mythical') {
      headline = "🚨 BREAKING!! $headline";
    }

    // Special logic for dynamic comparisons if the template is a "comparison" type
    if (template['type'] == 'comparison') {
      if (org.bst > org2.bst) {
        body += " Statistics indicate ${org.name} has a clear advantage.";
      } else if (org.bst < org2.bst) {
        body += " Analytical models favor ${org2.name} in most scenarios.";
      } else {
        body += " They are perfectly matched on paper.";
      }
    }

    // Generate deterministic sprite path based on name if empty
    String spritePath = org.sprite;
    if (spritePath.isEmpty) {
      spritePath = org.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll("'", '_')
          .replaceAll("-", '_');
      spritePath = "$spritePath.png";
    } else {
      // Strip common prefixes if they exist to avoid double-prefixing in UI
      spritePath = spritePath
          .replaceFirst('assets/sprites/', '')
          .replaceFirst('assets/', '');
    }

    // Map author name to icon path - always attempt to provide a path
    final authorId = author
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp(r'[^a-z0-9]'),
          '_',
        ) // Replace all special chars (including apostrophes) with underscores
        .replaceAll(RegExp(r'_+'), '_') // Clean up multiple underscores
        .replaceAll(RegExp(r'^_|_$'), ''); // Trim underscores from ends

    final String authorIcon = 'assets/npc/author_icons/$authorId.png';

    return NewsArticle(
      headline: headline,
      body: body,
      channel: channel['name'] ?? 'Unknown',
      author: author,
      channelIcon: channel['icon'] ?? '📰',
      channelTagline: channel['tagline'],
      category: category,
      organismName: org.name,
      spritePath: spritePath,
      authorIcon: authorIcon,
      biome:
          (replacements['{habitat}'] == null ||
              replacements['{habitat}']!.isEmpty ||
              replacements['{habitat}']!.toLowerCase() == 'unknown')
          ? 'earth'
          : replacements['{habitat}']!.toLowerCase().trim().replaceAll(
              ' ',
              '_',
            ),
      habitatName: (replacements['{habitat}'] ?? 'WILD').toUpperCase(),
      publishedAt: _fakeTime(time, rng),
      seed: seed,
      likes: 10 + rng.nextInt(5000),
      commentsCount: 5 + rng.nextInt(200),
      shares: rng.nextInt(1000),
      comments: _generateComments(category, org, org2, seed, rng, time),
    );
  }

  static String _applyReplacements(
    String text,
    Map<String, String> replacements,
  ) {
    String result = text;
    replacements.forEach((key, value) {
      // Clean underscores from values (e.g. tall_grass -> tall grass)
      final cleanValue = value.replaceAll('_', ' ');
      result = result.replaceAll(key, cleanValue);
    });
    return result;
  }

  static List<NewsComment> _generateComments(
    String category,
    Organism org,
    Organism org2,
    int seed,
    Random rng,
    GameTime time,
  ) {
    final comments = <NewsComment>[];
    final count = 5 + rng.nextInt(6); // 5 to 10 comments

    // Get templates for this category or generic ones
    final templates =
        _commentTemplates[category] ??
        _commentTemplates['GENERAL'] ??
        ['Cool article!', 'Wow!'];

    // Use shared replacement logic
    final replacements = _getReplacements(org, org2, rng, time);

    for (int i = 0; i < count; i++) {
      // Use a more chaotic hash to avoid serial naming
      final userIndex = (seed * 17 + i * 31 + (seed >> 4)) % _usernames.length;
      final user = _usernames[userIndex];
      // Pick a random template from the pool
      String text = templates[(seed + i * 13) % templates.length];

      text = _applyReplacements(text, replacements);

      comments.add(
        NewsComment(
          user: user,
          text: text,
          timeAgo: "${1 + rng.nextInt(23)}h ago",
        ),
      );
    }
    return comments;
  }

  static DateTime _fakeTime(GameTime t, Random rng) {
    return DateTime(t.year, t.month, t.day, rng.nextInt(24), rng.nextInt(60));
  }

  static String _getDietVerb(String diet, Random rng) {
    List<String> verbs;
    if (diet.contains('carnivore') ||
        diet.contains('piscivore') ||
        diet.contains('insectivore')) {
      verbs = [
        'hunting',
        'stalking',
        'patrolling',
        'prowling',
        'lurking',
        'tracking',
        'pouncing',
      ];
    } else if (diet.contains('herbivore') || diet.contains('frugivore')) {
      verbs = [
        'foraging',
        'grazing',
        'resting',
        'wandering',
        'observing',
        'migrating',
        'feeding',
      ];
    } else if (diet.contains('nectarivore')) {
      verbs = [
        'sipping nectar',
        'hovering',
        'pollinating',
        'darting',
        'feeding',
      ];
    } else if (diet.contains('scavenger') || diet.contains('detritivore')) {
      verbs = ['scavenging', 'searching', 'patrolling', 'lurking', 'cleaning'];
    } else if (diet.contains('filter feeder')) {
      verbs = ['sifting', 'drifting', 'filtering', 'feeding', 'floating'];
    } else if (diet.contains('parasite') || diet.contains('sanguivore')) {
      verbs = ['clinging', 'hiding', 'waiting', 'latching', 'feeding'];
    } else {
      verbs = ['observing', 'resting', 'moving', 'wandering', 'waiting'];
    }
    return verbs[rng.nextInt(verbs.length)];
  }

  /// Shared replacement logic for articles and comments.
  static Map<String, String> _getReplacements(
    Organism org,
    Organism org2,
    Random rng,
    GameTime time,
  ) {
    // Pick single values for cleaner text with null safety
    final allMoves = (org.moves)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final singleMove = allMoves.isNotEmpty
        ? allMoves[rng.nextInt(allMoves.length)]
        : "standard strike";

    final allHabitats = (org.habitat)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final singleHabitat = allHabitats.isNotEmpty
        ? allHabitats[rng.nextInt(allHabitats.length)]
        : "wild";

    final allTiles = (org.spawnTiles)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final singleTile = allTiles.isNotEmpty
        ? allTiles[rng.nextInt(allTiles.length)]
        : "ground";

    final allAbilities = (org.abilities)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final singleAbility = allAbilities.isNotEmpty
        ? allAbilities[rng.nextInt(allAbilities.length)]
        : "standard abilities";

    final allDrops = (org.drops)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final singleDrop = allDrops.isNotEmpty
        ? allDrops[rng.nextInt(allDrops.length)]
        : "no known drops";

    // Rarity emoji mapping
    final rarityEmojis = {
      'Common': '⚪',
      'Uncommon': '🟢',
      'Rare': '🔵',
      'Epic': '🟣',
      'Legendary': '🟠',
      'Mythical': '🌈',
    };
    final rEmoji = rarityEmojis[org.rarity] ?? '📝';

    String activeTimeFormatted = org.activeTime;
    if (activeTimeFormatted.toLowerCase() == 'any') {
      activeTimeFormatted = "any time";
    }

    final score1 = _calculatePredationScore(org, org2);
    final score2 = _calculatePredationScore(org2, org);
    final org1IsPredator = score1 >= score2;

    // Dynamic titles and labels
    final bst1 = org.bst;
    final bst2 = org2.bst;
    final dangerRating = (org.attack + org.power) / 20; // scale of 0-20ish
    String dangerLevel = "Low";
    if (dangerRating > 15) {
      dangerLevel = "Extreme";
    } else if (dangerRating > 10) {
      dangerLevel = "High";
    } else if (dangerRating > 5) {
      dangerLevel = "Moderate";
    }

    String tier = "C";
    if (bst1 > 550) {
      tier = "S";
    } else if (bst1 > 450) {
      tier = "A";
    } else if (bst1 > 350) {
      tier = "B";
    } else if (bst1 < 250) {
      tier = "F";
    }

    String weightClass = "Medium-weight";
    if (org.weight < 0.1) {
      weightClass = "Microscopic";
    } else if (org.weight < 2) {
      weightClass = "Feather-weight";
    } else if (org.weight > 1000) {
      weightClass = "Super-heavyweight";
    } else if (org.weight > 200) {
      weightClass = "Heavy-weight";
    }

    // Power Ranking / Playstyle
    String powerRank = "Generalist";
    final totalOffense = org.attack + org.power;
    final totalDefense = org.defense + org.resistance;
    if (org.speed > 110 && totalOffense > 150) {
      powerRank = "Glass Cannon";
    } else if (org.health > 180 && totalDefense > 200) {
      powerRank = "Behemoth";
    } else if (org.speed > 130) {
      powerRank = "Speedster";
    } else if (totalDefense > 250) {
      powerRank = "Stall-master";
    } else if (totalOffense > 250) {
      powerRank = "Apex Striker";
    }

    String speedComp = "comparable in speed";
    if (org.speed > org2.speed + 30) {
      speedComp = "far faster";
    } else if (org.speed < org2.speed - 30) {
      speedComp = "much slower";
    }

    String timeOfDay = "Day";
    if (time.hour < 6 || time.hour > 18) {
      timeOfDay = "Night";
    } else if (time.hour < 9) {
      timeOfDay = "Dawn";
    } else if (time.hour > 16) {
      timeOfDay = "Dusk";
    }

    return {
      '{name}': org.name,
      '{name2}': org2.name,
      '{other_org}': org2.name,
      '{scientific_name}': org.scientificName,
      '{scientific_name2}': org2.scientificName,
      '{habitat}': singleHabitat,
      '{rarity}': org.rarity,
      '{rarity_emoji}': rEmoji,
      '{weight}': org.formattedWeight,
      '{weight_class}': weightClass,
      '{size}': org.formattedSize,
      '{animal_class}': org.animalClass,
      '{class_title}':
          "The ${org.animalClass[0].toUpperCase()}${org.animalClass.substring(1)}",
      '{diet}': org.diet,
      '{active_time}': activeTimeFormatted,
      '{spawn_tiles}': singleTile,
      '{spawn_tile}': singleTile,
      '{abilities}': singleAbility,
      '{moves}': singleMove,
      '{drops}': singleDrop,
      '{description}': org.description,
      '{cry}': org.cry,
      '{bst}': bst1.toString(),
      '{bst2}': bst2.toString(),
      '{hp}': org.health.toString(),
      '{health}': org.health.toString(),
      '{attack}': org.attack.toString(),
      '{defense}': org.defense.toString(),
      '{power}': org.power.toString(),
      '{resistance}': org.resistance.toString(),
      '{speed}': org.speed.toString(),
      '{speed_comparison}': speedComp,
      '{robustness}': org.robustness.toStringAsFixed(2),
      '{types}': (org.types).join(" / "),
      '{status}': org.rarity == 'Mythical' ? 'Extinct' : 'Active',
      '{rarity_status}': org.rarity == 'Mythical'
          ? 'Extinct Species'
          : 'Extant Species',
      '{v}': _getDietVerb((org.diet).toLowerCase(), rng),
      '{rare_color}': 'shiny',
      '{danger_level}': dangerLevel,
      '{tier}': tier,
      '{power_rank}': powerRank,
      '{predator}': org1IsPredator ? org.name : org2.name,
      '{prey}': org1IsPredator ? org2.name : org.name,
      '{competitor}': org2.name,
      '{subject_status}': org1IsPredator ? "Apex" : "Scavenger",
      '{evolutionary_trait}': singleAbility,
      '{time_of_day}': timeOfDay,
    };
  }

  /// Determines if an author is biologically/thematically compatible with an organism.
  static bool _isAuthorCompatible(String author, Organism org) {
    final authorLower = author.toLowerCase();
    final orgClass = (org.animalClass).toLowerCase();
    final orgHabitat = (org.habitat).toLowerCase();
    final orgName = (org.name).toLowerCase();

    // Fishingarrett: Only Reptiles or Swamp dwellers
    if (authorLower.contains('fishingarrett')) {
      return orgClass == 'reptile' || orgHabitat.contains('swamp');
    }

    // Jeremy Wade: Only Fish or Aquatic/Wetland dwellers
    if (authorLower.contains('jeremy wade')) {
      final aquaticHabitats = ['river', 'swamp', 'wetlands', 'ocean', 'lake'];
      return orgClass == 'fish' ||
          aquaticHabitats.any((h) => orgHabitat.contains(h));
    }

    // Marine Experts: Fish or Ocean/Coastal habitats
    if (authorLower.contains('cousteau') ||
        authorLower.contains('skerry') ||
        authorLower.contains('nicklen')) {
      final marineHabitats = [
        'ocean',
        'coast',
        'reef',
        'sea',
        'marine',
        'abyss',
        'trench',
      ];
      return orgClass == 'fish' ||
          marineHabitats.any((h) => orgHabitat.contains(h));
    }

    // Entomologists / Bug Hunters
    if (authorLower.contains('antscanada') ||
        authorLower.contains('bughunter') ||
        authorLower.contains('goulson')) {
      return orgClass == 'insect' || orgClass == 'arachnid';
    }

    // Herpetologists (Reptiles/Amphibians)
    if (authorLower.contains('snake discovery') ||
        authorLower.contains('clint\'s reptiles') ||
        authorLower.contains('aldecoa')) {
      return orgClass == 'reptile' || orgClass == 'amphibian';
    }

    // Primatologists / Mammalogists
    if (authorLower.contains('goodall') ||
        authorLower.contains('fossey') ||
        authorLower.contains('waal')) {
      return orgClass == 'mammal';
    }

    // Paleontology / Prehistory Specialists
    if (authorLower.contains('ben g thomas') ||
        authorLower.contains('moth light media') ||
        authorLower.contains('budget museum')) {
      return org.rarity == 'Mythical';
    }

    // Domestic / Pet Specialists
    if (authorLower.contains('jackson galaxy')) {
      return orgName.contains('cat') ||
          orgName.contains('lion') ||
          orgName.contains('tiger') ||
          orgName.contains('leopard');
    }
    if (authorLower.contains('tia torres')) {
      return orgName.contains('dog') ||
          orgName.contains('wolf') ||
          orgName.contains('canine');
    }

    // Science / Physics / Astronomy communicators (Brian Cox, NdGT, Bill Nye)
    // They should ideally stick to SCIENCE or statistics, but we'll allow them everywhere
    // unless the user wants more restrictions.

    // Default compatibility for other authors
    return true;
  }

  /// Calculates a score representing how likely [p] is to prey on [target].
  static double _calculatePredationScore(Organism p, Organism target) {
    double score = 0;
    final pDiet = p.diet.toLowerCase();
    final tClass = target.animalClass.toLowerCase();

    // Diet-Class Synergy
    bool isSanguivore = pDiet.contains('sanguivore');
    bool isVertebrate = [
      'mammal',
      'bird',
      'reptile',
      'amphibian',
      'fish',
    ].contains(tClass);

    if (pDiet.contains('carnivore') || pDiet.contains('omnivore')) {
      score += 20;
    } else if (pDiet.contains('insectivore') &&
        (tClass == 'insect' || tClass == 'arachnid')) {
      score += 45;
    } else if (pDiet.contains('piscivore') && tClass == 'fish') {
      score += 45;
    } else if (isSanguivore && isVertebrate) {
      score += 40;
    }

    // Size & Weight Scaling
    // Predators usually avoid much larger prey, EXCEPT for Sanguivores (parasites/blood feeders)
    if (p.weight > target.weight) score += 15;
    if (p.size > target.size) score += 10;

    if (!isSanguivore) {
      if (target.weight > p.weight * 3) {
        score -= 30; // Heavy penalty for attacking giants
      }
      if (target.size > p.size * 2) score -= 20;
    } else {
      // Sanguivores actually PREFER larger targets for more blood
      if (target.weight > p.weight) score += 20;
    }

    // Habitat Match (Interaction requirement)
    if (p.habitat == target.habitat) score += 15;

    // Tactical Strength
    if (p.attack > target.defense) score += 10;
    if (p.speed > target.speed) score += 5;

    return score;
  }

  /// Quick check for dietary compatibility between two organisms.
  static bool _isDietMatch(Organism predator, Organism prey) {
    final d = predator.diet.toLowerCase();
    final c = prey.animalClass.toLowerCase();
    if (d.contains('carnivore') || d.contains('omnivore')) return true;
    if (d.contains('insectivore') && (c == 'insect' || c == 'arachnid')) {
      return true;
    }
    if (d.contains('piscivore') && c == 'fish') return true;
    if (d.contains('sanguivore') &&
        ['mammal', 'bird', 'reptile', 'amphibian', 'fish'].contains(c)) {
      return true;
    }
    return false;
  }
}
