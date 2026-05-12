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
  final String? biome; // NEW: The primary habitat/biome for background imagery
  final String? habitatName; // NEW: The display name of the selected habitat
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
    this.biome,
    this.habitatName,
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
      _usernames = ['User123', 'NatureLover', 'BattlePro'];
      _commentTemplates = {'GENERAL': ['Interesting!', 'Cool!']};
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
    const int articlesCount = 12;
    
    final shuffled = List<Organism>.from(organisms)..shuffle(rng);
    final articles = <NewsArticle>[];

    for (int i = 0; i < articlesCount; i++) {
      final org = shuffled[i % shuffled.length];
      
      final articleSeed = seed + i;
      final articleRng = Random(articleSeed);
      
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

      final category = validCategories[(articleSeed + i * 19) % validCategories.length];
      
      // Mythical animals are extinct - force PALEONTOLOGY
      final finalCategory = org.rarity == 'Mythical' ? 'PALEONTOLOGY' : category;
      
      final categoryTemplates = _templatesByCategory[finalCategory] ?? _templates;
      final template = categoryTemplates[(articleSeed + i * 37) % categoryTemplates.length];
      
      // Smart picking for org2 (Prey/Competitor/Target)
      Organism org2 = shuffled[(i + 7) % shuffled.length];
      
      final isComparison = template['type'] == 'comparison' || 
                           template['headline'].toLowerCase().contains('hunt') || 
                           template['headline'].toLowerCase().contains('target');

      if (isComparison) {
        final diet = org.diet.toLowerCase();
        final orgHabitats = org.habitat.split(',').map((h) => h.trim().toLowerCase()).toList();
        
        // Filter candidates that share a habitat and make biological sense as prey
        final potentialPrey = organisms.where((cand) {
          if (cand.name == org.name) return false;
          
          // Must share at least one habitat
          final candHabitats = cand.habitat.split(',').map((h) => h.trim().toLowerCase()).toList();
          bool sharesHabitat = orgHabitats.any((h) => candHabitats.contains(h));
          if (!sharesHabitat) return false;

          final candClass = cand.animalClass.toLowerCase();
          
          // Specific diet mappings
          if (diet == 'insectivore') return candClass == 'insect' || candClass == 'arachnid';
          if (diet == 'piscivore') return candClass == 'fish';
          if (diet == 'carnivore' || diet == 'omnivore') {
            // Predator targets something generally lighter or a non-carnivore
            return cand.weight < org.weight || !cand.diet.toLowerCase().contains('carnivore');
          }
          if (diet == 'sanguivore') return cand.animalClass == 'Mammal' || cand.animalClass == 'Bird';
          if (diet == 'parasite') return cand.weight > org.weight; // Parasites target larger hosts
          
          // Fallback for others (Herbivore, Scavenger, etc)
          return true;
        }).toList();

        if (potentialPrey.isNotEmpty) {
          // Sort by weight to prioritize logical targets (smaller for most, larger for parasites)
          if (diet == 'parasite') {
             potentialPrey.sort((a, b) => b.weight.compareTo(a.weight));
          } else {
             potentialPrey.sort((a, b) => a.weight.compareTo(b.weight));
          }
          
          // Pick from the top of the sorted list for more "realistic" matches
          final poolSize = (potentialPrey.length * 0.3).ceil().clamp(1, potentialPrey.length);
          org2 = potentialPrey[articleRng.nextInt(poolSize)];
        }
      }
      
      Map<String, dynamic> channel = _channels[(articleSeed + i * 13) % _channels.length];
      if (finalCategory == 'COOKING') {
        channel = _channels.firstWhere((c) => c['name'] == 'Savory Selections', orElse: () => channel);
      } else if (finalCategory == 'CRIME') {
        channel = _channels.firstWhere((c) => c['name'] == 'Wild Justice', orElse: () => channel);
      } else if (finalCategory == 'PALEONTOLOGY') {
        channel = _channels.firstWhere((c) => c['name'] == 'Ancient Echoes', orElse: () => channel);
      }

      final author = _authors[(articleSeed + i * 11) % _authors.length];
      
      try {
        final article = _buildArticleFromTemplate(
          template,
          org,
          org2,
          articleRng,
          channel,
          author,
          gameTime,
          articleSeed,
        );
        articles.add(article);
      } catch (e) {
        print("Failed to build article for ${org.name}: $e");
        // Skip this article instead of crashing the whole feed
      }
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

    // Use shared replacement logic
    final replacements = _getReplacements(org, org2, rng);

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
      biome: (replacements['{habitat}'] == null || replacements['{habitat}']!.isEmpty || replacements['{habitat}']!.toLowerCase() == 'unknown') 
          ? 'earth' 
          : replacements['{habitat}']!.toLowerCase().trim().replaceAll(' ', '_'),
      habitatName: (replacements['{habitat}'] ?? 'WILD').toUpperCase(),
      publishedAt: _fakeTime(time, rng),
      seed: seed,
      likes: 10 + rng.nextInt(5000),
      commentsCount: 5 + rng.nextInt(200),
      shares: rng.nextInt(1000),
      comments: _generateComments(category, org, org2, seed, rng),
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
    Organism org2,
    int seed,
    Random rng,
  ) {
    final comments = <NewsComment>[];
    final count = 5 + rng.nextInt(6); // 5 to 10 comments
    
    // Get templates for this category or generic ones
    final templates = _commentTemplates[category] ?? _commentTemplates['GENERAL'] ?? ['Cool article!', 'Wow!'];

    // Use shared replacement logic
    final replacements = _getReplacements(org, org2, rng);

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

  static String _getDietVerb(String diet, Random rng) {
    List<String> verbs;
    if (diet.contains('carnivore') || diet.contains('piscivore') || diet.contains('insectivore')) {
      verbs = ['hunting', 'stalking', 'patrolling', 'prowling', 'lurking', 'tracking', 'pouncing'];
    } else if (diet.contains('herbivore') || diet.contains('frugivore')) {
      verbs = ['foraging', 'grazing', 'resting', 'wandering', 'observing', 'migrating', 'feeding'];
    } else if (diet.contains('nectarivore')) {
      verbs = ['sipping nectar', 'hovering', 'pollinating', 'darting', 'feeding'];
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
  ) {
    // Pick single values for cleaner text with null safety
    final allMoves = (org.moves ?? "").split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleMove = allMoves.isNotEmpty ? allMoves[rng.nextInt(allMoves.length)] : "standard strike";
    
    final allHabitats = (org.habitat ?? "").split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleHabitat = allHabitats.isNotEmpty ? allHabitats[rng.nextInt(allHabitats.length)] : "wild";
    
    final allTiles = (org.spawnTiles ?? "").split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleTile = allTiles.isNotEmpty ? allTiles[rng.nextInt(allTiles.length)] : "ground";

    final allAbilities = (org.abilities ?? "").split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final singleAbility = allAbilities.isNotEmpty ? allAbilities[rng.nextInt(allAbilities.length)] : "standard abilities";
    
    final allDrops = (org.drops ?? "").split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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

    String activeTimeFormatted = org.activeTime ?? "any";
    if (activeTimeFormatted.toLowerCase() == 'any') {
      activeTimeFormatted = "any time";
    }

    return {
      '{name}': org.name ?? "Unknown",
      '{name2}': org2.name ?? "Unknown",
      '{other_org}': org2.name ?? "Unknown", 
      '{scientific_name}': org.scientificName ?? "Unknown",
      '{habitat}': singleHabitat,
      '{rarity}': org.rarity ?? "Common",
      '{rarity_emoji}': rEmoji,
      '{weight}': org.formattedWeight,
      '{size}': org.formattedSize,
      '{animal_class}': org.animalClass ?? "unknown",
      '{diet}': org.diet ?? "unknown",
      '{active_time}': activeTimeFormatted,
      '{spawn_tiles}': singleTile,
      '{spawn_tile}': singleTile, 
      '{abilities}': singleAbility,
      '{moves}': singleMove,
      '{drops}': singleDrop,
      '{description}': org.description ?? "",
      '{cry}': org.cry ?? "default",
      '{bst}': org.bst.toString(),
      '{hp}': org.health.toString(),
      '{health}': org.health.toString(),
      '{attack}': org.attack.toString(),
      '{defense}': org.defense.toString(),
      '{power}': org.power.toString(),
      '{resistance}': org.resistance.toString(),
      '{speed}': org.speed.toString(),
      '{robustness}': org.robustness.toStringAsFixed(2),
      '{types}': (org.types ?? []).join(" / "),
      '{status}': org.rarity == 'Mythical' ? 'Extinct' : 'Active',
      '{v}': _getDietVerb((org.diet ?? "unknown").toLowerCase(), rng),
      '{rare_color}': 'shiny', 
    };
  }
}
