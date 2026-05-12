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
  final String channelIcon; // emoji
  final String category; // e.g. 'ECOLOGY', 'BATTLE', 'SCIENCE', etc.
  final String? organismName; // featured organism, if any
  final String? spritePath;
  final DateTime publishedAt; // in-game time
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
    required this.category,
    this.organismName,
    this.spritePath,
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
      _usernames = List<String>.from(data['usernames'] ?? ['User123', 'NatureLover', 'BattlePro']);
      
      final Map<String, dynamic> comments = data['comment_templates'] ?? {};
      _commentTemplates = comments.map((key, value) => MapEntry(key, List<String>.from(value)));

      _templatesByCategory = {};
      for (var t in _templates) {
        final cat = t['category'] ?? 'GENERAL';
        _templatesByCategory.putIfAbsent(cat, () => []).add(t);
      }

      _isInitialized = true;
    } catch (e) {
      print("Error initializing NewsService: $e");
      // Fallback defaults if file missing
      _channels = [
        {'name': 'WildWatch Daily', 'icon': '🌿', 'tagline': 'Eyes on nature, 24/7'}
      ];
      _authors = ['Dr. Elena Marsh'];
      _categories = ['ECOLOGY'];
      _templates = [
        {
          'headline': '{name}: Spotlight',
          'body': '{name} is a {rarity} {animal_class}.',
          'category': 'PROFILE'
        }
      ];
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
    final articleCount = 12 + rng.nextInt(8); // 12-19 articles per day
    final articles = <NewsArticle>[];

    // Shuffle organisms deterministically for this day
    final shuffled = List<Organism>.from(organisms)..shuffle(rng);

    for (int i = 0; i < articleCount; i++) {
      final org = shuffled[i % shuffled.length];
      
      // Logic for valid categories
      final validCategories = ['ECOLOGY', 'SCIENCE', 'BATTLE META', 'EXPLORATION', 'DISCOVERY', 'STATISTICS', 'PROFILE', 'OPINION'];
      
      final isFoodClass = org.animalClass == 'Bird' || org.animalClass == 'Fish' || (org.animalClass == 'Mammal' && org.diet == 'Herbivore');
      final hasFoodDrops = org.drops.toLowerCase().contains('meat') || org.drops.toLowerCase().contains('fillet') || org.drops.toLowerCase().contains('egg');
      if (isFoodClass && hasFoodDrops) {
        validCategories.add('COOKING');
      }
      
      if (org.rarity == 'Rare' || org.rarity == 'Epic' || org.rarity == 'Legendary' || org.attack > 100) {
        validCategories.add('CRIME');
      }

      final category = validCategories[(seed + i * 19) % validCategories.length];
      
      // Mythical animals are extinct - force PALEONTOLOGY
      final finalCategory = org.rarity == 'Mythical' ? 'PALEONTOLOGY' : category;
      
      final categoryTemplates = _templatesByCategory[finalCategory] ?? _templates;
      final template = categoryTemplates[(seed + i * 37) % categoryTemplates.length];
      
      // Smart picking for org2 in comparison/predator templates
      Organism org2 = shuffled[(i + 7) % shuffled.length];
      if (template['type'] == 'comparison' || template['headline'].contains('Hunt') || template['headline'].contains('Target')) {
        // If org is a predator (Carnivore/Omnivore), try to find a prey (Herbivore)
        final isPredator = org.diet.toLowerCase().contains('carnivore') || org.diet.toLowerCase().contains('omnivore');
        if (isPredator) {
          for (int j = 1; j < 15; j++) {
            final candidate = shuffled[(i + j + 7) % shuffled.length];
            if (candidate.diet.toLowerCase().contains('herbivore') && candidate.name != org.name) {
              org2 = candidate;
              break;
            }
          }
        }
      }
      
      Map<String, dynamic> channel = _channels[(seed + i * 13) % _channels.length];
      if (finalCategory == 'COOKING') {
        channel = _channels.firstWhere((c) => c['name'] == 'Savory Selections', orElse: () => channel);
      } else if (finalCategory == 'CRIME') {
        channel = _channels.firstWhere((c) => c['name'] == 'Wild Justice', orElse: () => channel);
      } else if (finalCategory == 'PALEONTOLOGY') {
        channel = _channels.firstWhere((c) => c['name'] == 'Ancient Echoes', orElse: () => channel);
      }

      final author = _authors[(seed + i * 11) % _authors.length];
      
      final article = _buildArticleFromTemplate(
        template,
        org,
        org2,
        rng,
        channel,
        author,
        gameTime,
        seed + i,
      );
      articles.add(article);
    }

    return articles;
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

    // Pick a single move and habitat for cleaner text
    final allMoves = org.moves.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleMove = allMoves.isNotEmpty ? allMoves[rng.nextInt(allMoves.length)] : "standard strike";
    
    final allHabitats = org.habitat.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleHabitat = allHabitats.isNotEmpty ? allHabitats[rng.nextInt(allHabitats.length)] : "wild";
    
    final allTiles = org.spawnTiles.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleTile = allTiles.isNotEmpty ? allTiles[rng.nextInt(allTiles.length)] : "ground";

    final allAbilities = org.abilities.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleAbility = allAbilities.isNotEmpty ? allAbilities[rng.nextInt(allAbilities.length)] : "standard abilities";
    
    final allDrops = org.drops.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleDrop = allDrops.isNotEmpty ? allDrops[rng.nextInt(allDrops.length)] : "no known drops";

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

    // Format active time
    String activeTimeFormatted = org.activeTime;
    if (activeTimeFormatted.toLowerCase() == 'any') {
      activeTimeFormatted = "any time";
    }

    // Replacement map
    final replacements = {
      '{name}': org.name,
      '{name2}': org2.name,
      '{scientific_name}': org.scientificName,
      '{habitat}': singleHabitat,
      '{rarity}': org.rarity,
      '{rarity_emoji}': rEmoji,
      '{weight}': org.formattedWeight,
      '{size}': org.formattedSize,
      '{animal_class}': org.animalClass,
      '{diet}': org.diet,
      '{active_time}': activeTimeFormatted,
      '{spawn_tiles}': singleTile,
      '{abilities}': singleAbility,
      '{moves}': singleMove,
      '{drops}': singleDrop,
      '{description}': org.description,
      '{cry}': org.cry,
      '{bst}': org.bst.toString(),
      '{hp}': org.health.toString(),
      '{health}': org.health.toString(),
      '{attack}': org.attack.toString(),
      '{defense}': org.defense.toString(),
      '{power}': org.power.toString(),
      '{resistance}': org.resistance.toString(),
      '{speed}': org.speed.toString(),
      '{robustness}': org.robustness.toStringAsFixed(2),
      '{types}': org.types.join(" / "),
      '{status}': org.rarity == 'Mythical' ? 'Extinct' : 'Active',
    };

    // Apply replacements to headline and body
    headline = _applyReplacements(headline, replacements);
    body = _applyReplacements(body, replacements);

    // BREAKING NEWS logic for high rarity
    if (org.rarity == 'Legendary' || org.rarity == 'Mythical') {
      headline = "🚨 BREAKING: $headline";
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
      spritePath = org.name.toLowerCase()
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

    return NewsArticle(
      headline: headline,
      body: body,
      channel: channel['name'] ?? 'Unknown',
      author: author,
      channelIcon: channel['icon'] ?? '📰',
      category: category,
      organismName: org.name,
      spritePath: spritePath,
      publishedAt: _fakeTime(time, rng),
      seed: seed,
      likes: 10 + rng.nextInt(5000),
      commentsCount: 5 + rng.nextInt(200),
      shares: rng.nextInt(1000),
      comments: _generateComments(category, org, seed, rng),
    );
  }

  static String _applyReplacements(String text, Map<String, String> replacements) {
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
    int seed,
    Random rng,
  ) {
    final comments = <NewsComment>[];
    final count = 5 + rng.nextInt(6); // 5 to 10 comments
    
    // Get templates for this category or generic ones
    final templates = _commentTemplates[category] ?? _commentTemplates['GENERAL'] ?? ['Cool article!', 'Wow!'];

    // Standard replacements for comments too
    // We reuse the single habitat/move logic for comments to keep them concise
    final allHabitats = org.habitat.split(',').map((e) => e.trim()).toList();
    final singleHab = allHabitats.isNotEmpty ? allHabitats[rng.nextInt(allHabitats.length)] : "wild";

    final replacements = {
      '{name}': org.name,
      '{habitat}': singleHab,
      '{rarity}': org.rarity,
      '{animal_class}': org.animalClass,
      '{drops}': org.drops.isNotEmpty ? org.drops.split(',').first.trim() : "items",
    };

    for (int i = 0; i < count; i++) {
      // Use a more chaotic hash to avoid serial naming
      final userIndex = (seed * 17 + i * 31 + (seed >> 4)) % _usernames.length;
      final user = _usernames[userIndex];
      // Pick a random template from the pool
      String text = templates[(seed + i * 13) % templates.length];
      
      text = _applyReplacements(text, replacements);
      
      comments.add(NewsComment(
        user: user,
        text: text,
        timeAgo: "${1 + rng.nextInt(23)}h ago",
      ));
    }
    return comments;
  }

  static DateTime _fakeTime(GameTime t, Random rng) {
    return DateTime(t.year, t.month, t.day, rng.nextInt(24), rng.nextInt(60));
  }
}
