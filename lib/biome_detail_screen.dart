// lib/biome_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'explore_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/achievement_service.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'dart:async';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/shop_screen.dart';
import 'package:animal_warfare/phone_screen.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/widgets/game_clock_widget.dart';
import 'package:animal_warfare/services/weather_service.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/models/weather.dart';

class ItemFindResult {
  final String itemId;
  final String itemName;
  final int count;
  final String message;

  ItemFindResult({
    required this.itemId,
    required this.itemName,
    required this.count,
    required this.message,
  });
}

class BiomeDetailScreen extends StatefulWidget {
  final String biomeName;
  final List<Organism> allOrganisms;
  final UserData currentUser;
  final LocalAuthService authService;

  const BiomeDetailScreen({
    super.key,
    required this.biomeName,
    required this.allOrganisms,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<BiomeDetailScreen> createState() => _BiomeDetailScreenState();
}

class _BiomeDetailScreenState extends State<BiomeDetailScreen>
    with WidgetsBindingObserver {
  static const Color highlightColor = Color(0xFFDAA520);

  SpawnResult? _currentEncounter;
  CapturedOrganism? _persistentEncounter; // Added to track specific instance
  ItemFindResult? _foundItem;
  bool _isExploring = false;
  bool _isNameRevealed = false;

  late Color _biomeBaseColor;
  late Color _biomeDarkColor;
  late Color _biomeHighlightColor;
  late Color _rarityHighlightColor = highlightColor;

  final AudioPlayer _audioPlayer = AudioPlayer();
  List<dynamic> _allOrganismsJson = [];
  late AchievementService _achievementService;
  late UserData _currentUser;
  Map<String, dynamic> _explorationDropData = {};

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _biomeBaseColor = _getBiomeBaseColor(widget.biomeName);
    _biomeDarkColor = _getDarkerColor(_biomeBaseColor);
    _biomeHighlightColor = _getBiomeHighlightColor(widget.biomeName);

    if (widget.allOrganisms.isNotEmpty) {
      _allOrganismsJson = widget.allOrganisms.map((o) => o.toJson()).toList();
    }

    _achievementService = AchievementService(
      allOrganisms: _allOrganismsJson,
      authService: widget.authService,
    );

    if (_allOrganismsJson.isEmpty) {
      _loadOrganismsData();
    }
    _loadExplorationDropData();

    WidgetsBinding.instance.addObserver(this);
    TimeService().start();
    _playBiomeMusic(widget.biomeName);

    // Recover persistent encounter if exists
    final encounters = _currentUser.explorationEncounters;
    if (encounters.containsKey(widget.biomeName)) {
      _persistentEncounter = encounters[widget.biomeName];
      if (_persistentEncounter != null) {
        _currentEncounter = SpawnResult(
          organism: _persistentEncounter!.baseOrganism,
          isRare: false, // Default or store in UserData if needed
        );
      }
    }
  }

  Color _getDarkerColor(Color color) {
    int r = (color.r * 255.0 * 0.6).round().clamp(0, 255);
    int g = (color.g * 255.0 * 0.6).round().clamp(0, 255);
    int b = (color.b * 255.0 * 0.6).round().clamp(0, 255);
    return Color.fromARGB((color.a * 255.0).round().clamp(0, 255), r, g, b);
  }

  Color _getBiomeHighlightColor(String biomeName) {
    final biome = biomeName.toLowerCase();
    if (biome.contains('swamp') || biome.contains('mangrove')) {
      return const Color(0xFFCE93D8);
    }
    if (biome.contains('desert') || biome.contains('savanna')) {
      return const Color(0xFFFFD740);
    }
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra') ||
        biome.contains('polar') ||
        biome.contains('frozen')) {
      return const Color(0xFF40C4FF);
    }
    if (biome.contains('volcan')) return const Color(0xFFFF5252);
    if (biome.contains('mountain') ||
        biome.contains('cave') ||
        biome.contains('urban') ||
        biome.contains('taiga')) {
      return const Color(0xFFB0BEC5);
    }
    if (biome.contains('forest') ||
        biome.contains('jungle') ||
        biome.contains('rainforest') ||
        biome.contains('kelp') ||
        biome.contains('wetlands') ||
        biome.contains('redwoods') ||
        biome.contains('plains')) {
      return const Color(0xFF69F0AE);
    }
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river') ||
        biome.contains('deep sea') ||
        biome.contains('coral') ||
        biome.contains('coastal')) {
      return const Color(0xFF448AFF);
    }
    return const Color(0xFFDAA520);
  }

  String _getTimeOfDay() {
    final hour = TimeService().currentGameTime.hour;
    if (hour >= 6 && hour < 18) return 'day';
    if (hour >= 18 && hour < 21) return 'evening';
    return 'night';
  }

  String _getAssetPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  String _getMusicPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'audio/${fileName}_theme.mp3';
  }

  int _getIdentifyStaminaCost(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 5;
      case 'uncommon':
        return 10;
      case 'rare':
        return 15;
      case 'epic':
        return 25;
      case 'legendary':
        return 40;
      case 'mythical':
        return 60;
      default:
        return 5;
    }
  }

  void _displayMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  void _onEncounterFound(
    Organism wildOrganism, {
    bool startAsleep = false,
  }) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) {
      _displayMessage("You must be logged in to battle!");
      return;
    }
    CapturedOrganism playerFighter;
    if (user.teamOrganisms.isNotEmpty) {
      playerFighter = user.teamOrganisms.first;
    } else if (user.capturedOrganisms.isNotEmpty) {
      playerFighter = user.capturedOrganisms.first;
    } else {
      _displayMessage("You have no organisms! Prepare to fight as Human!");
      playerFighter = CapturedOrganism.spawn(
        Organism.humanOrganism.copyWith(name: user.username),
        level: user.accountLevel,
      );
    }

    // Use persistent encounter if available, otherwise spawn and save
    final wildFighter =
        _persistentEncounter ??
        CapturedOrganism.spawn(wildOrganism, accountLevel: user.accountLevel);

    if (_persistentEncounter == null) {
      _persistentEncounter = wildFighter;
      // Save it immediately in UserData
      userState.updateExplorationEncounter(widget.biomeName, wildFighter);
    }

    AudioService.instance.pauseAll();
    final Object? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerFighter,
          opponentOrganism: wildFighter,
          biomeName: widget.biomeName,
          playerTeam: user.teamOrganisms,
          timeOfDay: _getTimeOfDay(),
          startAsleep: startAsleep,
        ),
      ),
    );
    AudioService.instance.resumeAll();
    if (result == BattleResult.capture || result == BattleResult.win) {
      // Clear persistent encounter on success
      userState.updateExplorationEncounter(widget.biomeName, null);
      setState(() {
        _persistentEncounter = null;
        _currentEncounter = null;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _startExploration();
      });
    } else if (result == BattleResult.loss) {
      // Keeper persistent encounter for next time (don't clear)
    } else if (result == BattleResult.fled) {
      // Clear or keep? Usually flee clears the encounter.
      userState.updateExplorationEncounter(widget.biomeName, null);
      setState(() {
        _persistentEncounter = null;
        _currentEncounter = null;
      });
    }
  }

  void _playBiomeMusic(String biomeName) {
    String musicPath = _getMusicPath(biomeName);
    AudioService.instance.playMusic(musicPath);
  }

  void _pauseMusic() => AudioService.instance.pauseAll();
  void _stopAndDisposeMusic() => AudioService.instance.stopAll();

  @override
  void dispose() {
    _stopAndDisposeMusic();
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Color _getBiomeBaseColor(String biomeName) {
    switch (biomeName.toLowerCase()) {
      case 'swamp':
        return const Color(0xFF4B6F44);
      case 'savanna':
        return const Color(0xFFC39C6B);
      case 'desert':
        return const Color(0xFFC17E45);
      case 'taiga':
        return const Color(0xFF5A6A6F);
      case 'mountain':
        return const Color(0xFF757D75);
      case 'coastal':
        return const Color(0xFF4C98A7);
      case 'volcano':
        return const Color(0xFF8B0000);
      case 'cave':
        return const Color(0xFF3A3A3A);
      case 'urban':
        return const Color(0xFF6C6C6C);
      case 'polar':
        return const Color(0xFFB0E0E6);
      case 'ocean':
        return const Color(0xFF005897);
      case 'deep sea':
        return const Color(0xFF0D0D2E);
      case 'coral reef':
        return const Color(0xFFE9967A);
      case 'rainforest':
        return const Color(0xFF1E5B3D);
      case 'wetlands':
        return const Color(0xFF535C3E);
      case 'plains':
        return const Color(0xFFC39C6B);
      case 'redwoods':
        return const Color(0xFF2E4A2E);
      case 'kelp forest':
        return const Color(0xFF708F70);
      case 'mangrove':
        return const Color(0xFF535C3E);
      case 'frozen ocean':
        return const Color(0xFF8BA6C7);
      case 'river':
        return const Color(0xFF488FB2);
      case 'lake':
        return const Color(0xFF6495ED);
      case 'tundra':
        return const Color(0xFF909C90);
      case 'jungle':
        return const Color(0xFF38761D);
      default:
        return highlightColor;
    }
  }

  Color _getRarityHighlightColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade400;
      case 'uncommon':
        return const Color.fromARGB(255, 22, 254, 95);
      case 'rare':
        return const Color.fromARGB(255, 0, 175, 194);
      case 'epic':
        return const Color.fromARGB(255, 103, 0, 114);
      case 'legendary':
        return const Color.fromARGB(226, 227, 148, 0);
      case 'mythical':
        return Colors.redAccent.shade400;
      default:
        return highlightColor;
    }
  }

  Future<void> _loadOrganismsData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      _allOrganismsJson = json.decode(response);
      _achievementService = AchievementService(
        allOrganisms: _allOrganismsJson,
        authService: widget.authService,
      );
    } catch (e) {
      debugPrint('Error loading organisms for achievement check: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      _playBiomeMusic(widget.biomeName);
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return Colors.green;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      case 'mythical':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  Future<void> _refreshUserData() async {
    final user = await widget.authService.getCurrentUser();
    if (user != null && mounted) setState(() => _currentUser = user);
  }

  void _revealName(Organism organism) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final cost = _getIdentifyStaminaCost(organism.rarity);
    if (userState.currentUser == null ||
        userState.currentUser!.stamina < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough stamina! Need $cost stamina.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    await userState.decreaseStamina(cost);
    await widget.authService.markOrganismAsDiscovered(
      _currentUser.username,
      organism.name,
    );
    await _refreshUserData();
    final newAchievements = await userState.checkAndUnlockAchievements(
      _achievementService,
    );
    if (newAchievements.isNotEmpty) {
      await _refreshUserData();
      for (final title in newAchievements) {
        if (mounted) {
          _achievementService.showAchievementSnackbar(context, title);
        }
      }
    }
    if (mounted) {
      setState(() => _isNameRevealed = true);
      // Play cry when identified
      AudioService.instance.playOrganismCry(organism.cry);
    }
  }

  bool _isDiscovered(Organism organism) =>
      _currentUser.discoveredOrganisms.contains(organism.name);

  String? _checkBiomeAccess() {
    final biome = widget.biomeName.toLowerCase();
    final team = _currentUser.teamOrganisms;
    String? requiredMove;
    if (biome.contains('deep sea')) {
      requiredMove = 'Dive';
    } else if (biome.contains('mountain') || biome.contains('cave')) {
      requiredMove = 'Rock Smash';
    }

    final ignoreFlashOrDive = _currentUser.ignoreBiomeRequirements;

    if (requiredMove == 'Dive' && ignoreFlashOrDive) {
      requiredMove = null;
    }
    if (requiredMove == 'Rock Smash' && ignoreFlashOrDive) {
      requiredMove = null;
    }

    if (requiredMove == null) {
      if (biome.contains('cave') && !ignoreFlashOrDive) {
        bool hasFlash = team.any(
          (org) => org.selectedMoveNames.contains('Flash'),
        );
        if (!hasFlash) return 'Flash';
      }
      return null;
    }

    if (biome.contains('cave') && !ignoreFlashOrDive) {
      bool hasFlash = team.any(
        (org) => org.selectedMoveNames.contains('Flash'),
      );
      if (!hasFlash) return 'Flash';
    }

    bool hasMove = team.any(
      (org) => org.selectedMoveNames.contains(requiredMove!),
    );
    return hasMove ? null : requiredMove;
  }

  void _startExploration() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;
    final blockedByMove = _checkBiomeAccess();
    if (blockedByMove != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _biomeDarkColor,
            title: Text(
              'ACCESS BLOCKED',
              style: TextStyle(
                color: _biomeHighlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 14,
              ),
            ),
            content: Text(
              'To explore this biome, one of your team members must know the move "$blockedByMove".',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'UNDERSTOOD',
                  style: TextStyle(
                    color: _biomeHighlightColor,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (user.stamina < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough stamina!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    await userState.decreaseStamina(10);
    setState(() {
      _isExploring = true;
      _currentEncounter = null;
      _foundItem = null;
      _isNameRevealed = false;
    });
    Future.delayed(const Duration(seconds: 1), () async {
      if (_persistentEncounter != null && mounted) {
        setState(() {
          _currentEncounter = SpawnResult(
            organism: _persistentEncounter!.baseOrganism,
            isRare: false,
          );
          _isExploring = false;
          _rarityHighlightColor = _getRarityHighlightColor(
            _persistentEncounter!.baseOrganism.rarity,
          );
          _isNameRevealed = _isDiscovered(_persistentEncounter!.baseOrganism);
        });
        return;
      }

      final random = math.Random();
      final bool findItem = random.nextDouble() < 0.30;

      if (findItem) {
        final itemPool = _getItemPoolForBiome(widget.biomeName);
        if (itemPool.isNotEmpty) {
          final selectedItem = itemPool[random.nextInt(itemPool.length)];
          final count = random.nextInt(3) + 1;
          final message = _getRandomFindMessage(
            selectedItem['name']!,
            widget.biomeName,
          );

          await userState.addLoot(selectedItem['id']!, count);

          if (mounted) {
            setState(() {
              _foundItem = ItemFindResult(
                itemId: selectedItem['id']!,
                itemName: selectedItem['name']!,
                count: count,
                message: message,
              );
              _isExploring = false;
            });
          }
          return;
        }
      }

      final encounter = getWeightedRandomOrganism(
        widget.biomeName,
        widget.allOrganisms,
        accountLevel: userState.currentUser?.accountLevel ?? 1,
        inventory: userState.currentUser?.inventory ?? {},
        teamMoveNames:
            userState.currentUser?.teamOrganisms
                .expand((o) => o.selectedMoveNames)
                .toList() ??
            [],
        currentTimeOfDay: _getTimeOfDay(),
      );
      if (mounted) {
        setState(() {
          _currentEncounter = encounter;
          _isExploring = false;
          if (encounter != null) {
            final organism = encounter.organism;
            _rarityHighlightColor = _getRarityHighlightColor(organism.rarity);
            _isNameRevealed = _isDiscovered(organism);
            AudioService.instance.playOrganismCry(organism.cry);
          }
        });
      }
    });
  }

  Future<void> _loadExplorationDropData() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/biome_exploration_drops.json',
      );
      if (mounted) {
        setState(() {
          _explorationDropData = jsonDecode(raw) as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('BiomeDetail: failed to load exploration drop data: $e');
    }
  }

  List<Map<String, String>> _getItemPoolForBiome(String biomeName) {
    final name = biomeName.toLowerCase();
    final data = _explorationDropData;

    // Build combined pool: base + matching biome-specific items
    final pool = <Map<String, String>>[];

    // Base pool
    final basePool = (data['base_pool'] as List<dynamic>? ?? []);
    for (final entry in basePool) {
      pool.add({'id': entry['id'] as String, 'name': entry['name'] as String});
    }

    // Biome-specific extras — first matching entry wins
    final biomePools = (data['biome_pools'] as List<dynamic>? ?? []);
    for (final biomeEntry in biomePools) {
      final keywords = (biomeEntry['keywords'] as List<dynamic>).cast<String>();
      final matched = keywords.any((kw) => name.contains(kw));
      if (matched) {
        for (final item in (biomeEntry['items'] as List<dynamic>)) {
          final entry = {
            'id': item['id'] as String,
            'name': item['name'] as String,
          };
          // Avoid duplicate ids
          if (!pool.any((p) => p['id'] == entry['id'])) {
            pool.add(entry);
          }
        }
        break; // only apply first matching biome pool
      }
    }

    return pool;
  }

  String _getRandomFindMessage(String itemName, String biomeName) {
    final random = math.Random();
    final name = biomeName.toLowerCase();
    final data = _explorationDropData;

    final messageGroups = (data['messages'] as List<dynamic>? ?? []);

    List<String> templates = [];

    // Find the first matching group (skip the 'default' fallback)
    for (final group in messageGroups) {
      final id = group['id'] as String;
      if (id == 'default') continue;
      final keywords = (group['keywords'] as List<dynamic>).cast<String>();
      if (keywords.any((kw) => name.contains(kw))) {
        templates = (group['templates'] as List<dynamic>).cast<String>();
        break;
      }
    }

    // Fall back to 'default' group
    if (templates.isEmpty) {
      final defaultGroup = messageGroups.firstWhere(
        (g) => g['id'] == 'default',
        orElse: () => {'templates': <String>[]},
      );
      templates = (defaultGroup['templates'] as List<dynamic>? ?? [])
          .cast<String>();
    }

    if (templates.isEmpty) return 'You found some $itemName!';

    final template = templates[random.nextInt(templates.length)];
    return template.replaceAll('{item}', itemName);
  }

  void _showStatsModal(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, _) =>
            PhoneScreen(initialBiome: widget.biomeName),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildStaminaBarIcon(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStatsModal(context),
      child: Consumer<UserState>(
        builder: (context, userState, child) {
          final user = userState.currentUser;
          if (user == null) return const SizedBox.shrink();
          final progress = user.stamina / 100;
          return Container(
            width: 100,
            height: 24,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _biomeDarkColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: user.stamina > 25
                              ? [Colors.greenAccent, Colors.green]
                              : [Colors.redAccent, Colors.red],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${user.stamina}/100',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'PressStart2P',
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _biomeHighlightColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.biomeName.toUpperCase()),
        backgroundColor: _biomeDarkColor,
        titleTextStyle: TextStyle(
          color: _biomeHighlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 14,
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
          child: GameClockWidget(highlightColor: _biomeHighlightColor),
        ),
        leadingWidth: 120,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart, color: AppColors.highlightColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShopScreen(biome: widget.biomeName),
              ),
            ),
          ),
          _buildStaminaBarIcon(context),
        ],
      ),
      body: StreamBuilder<GameTime>(
        stream: TimeService().timeStream,
        builder: (context, snapshot) {
          final timeOfDay = _getTimeOfDay();
          final weather = WeatherService().getCurrentWeather(widget.biomeName);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _biomeBaseColor,
                  image: DecorationImage(
                    image: AssetImage(_getAssetPath(widget.biomeName)),
                    fit: BoxFit.cover,
                    colorFilter: timeOfDay == 'day'
                        ? ColorFilter.mode(
                            _biomeDarkColor.withValues(alpha: 0.5),
                            BlendMode.darken,
                          )
                        : ColorFilter.mode(
                            timeOfDay == 'evening'
                                ? Colors.orangeAccent.withValues(alpha: 0.3)
                                : Colors.indigo[900]!.withValues(alpha: 0.7),
                            BlendMode.multiply,
                          ),
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isExploring)
                        Column(
                          children: [
                            CircularProgressIndicator(
                              color: _biomeHighlightColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'EXPLORING...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _biomeHighlightColor,
                                fontFamily: 'PressStart2P',
                                fontSize: 18,
                                shadows: [
                                  Shadow(
                                    color: _biomeHighlightColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 5.0,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      if (!_isExploring && _currentEncounter != null)
                        _buildEncounterResultCard(_currentEncounter!),
                      if (!_isExploring && _foundItem != null)
                        _buildItemFindCard(_foundItem!),
                      if (!_isExploring &&
                          _currentEncounter == null &&
                          _foundItem == null)
                        ElevatedButton(
                          onPressed: _startExploration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _biomeDarkColor,
                            shape: const StadiumBorder(
                              side: BorderSide(
                                color: Color(0xFFDAA520),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 40,
                            ),
                          ),
                          child: Text(
                            'START EXPLORING',
                            style: TextStyle(
                              color: _biomeHighlightColor,
                              fontFamily: 'PressStart2P',
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Weather Overlay
              IgnorePointer(child: WeatherOverlay(weather: weather)),
              // Weather Indicator
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _biomeHighlightColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getWeatherIcon(weather, size: 20),
                      const SizedBox(width: 8),
                      _getTemperatureIcon(
                        WeatherService()
                            .getForecast(widget.biomeName)
                            .first
                            .temperatureCelsius,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${WeatherService().getForecast(widget.biomeName).first.temperatureCelsius.toStringAsFixed(1)}°C",
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _getWeatherIcon(Weather weather, {double size = 20}) {
    return Image.asset(
      weather.iconPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.wb_cloudy, color: Colors.white, size: size),
    );
  }

  Widget _getTemperatureIcon(double temp, {double size = 20}) {
    String iconPath;
    if (temp <= 0) {
      iconPath = 'assets/icon/feezing.png';
    } else if (temp <= 15) {
      iconPath = 'assets/icon/cool.png';
    } else if (temp <= 25) {
      iconPath = 'assets/icon/normal.png';
    } else if (temp <= 35) {
      iconPath = 'assets/icon/warm.png';
    } else if (temp <= 45) {
      iconPath = 'assets/icon/hot.png';
    } else {
      iconPath = 'assets/icon/burning.png';
    }
    return Image.asset(
      iconPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.thermostat, color: Colors.white, size: size),
    );
  }

  Widget _buildItemFindCard(ItemFindResult result) {
    final assetName = result.itemId.replaceAll('_', '-');
    final assetPath = 'assets/items/$assetName.png';

    return Card(
      elevation: 12,
      shadowColor: _biomeHighlightColor.withValues(alpha: 0.6),
      color: _biomeDarkColor.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _biomeHighlightColor, width: 3),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ITEM ACQUIRED!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 12,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(color: _biomeHighlightColor, blurRadius: 10.0),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Display item image with no border and a clean background
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                assetPath,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('📦', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${_toTitleCase(result.itemName)} x${result.count}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _startExploration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _biomeHighlightColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      'EXPLORE AGAIN',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _foundItem = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black26,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white24, width: 2),
                      ),
                    ),
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildEncounterResultCard(SpawnResult result) {
    final organism = result.organism;
    final bool isNameVisible = _isDiscovered(organism) || _isNameRevealed;
    return Card(
      elevation: 12,
      shadowColor: _rarityHighlightColor.withValues(alpha: 0.6),
      color: _biomeDarkColor.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _rarityHighlightColor, width: 3),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isNameVisible ? 'ENCOUNTER' : 'UNKNOWN ANIMAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 12,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(color: _rarityHighlightColor, blurRadius: 10.0),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _rarityHighlightColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                organism.rarity.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _getRarityColor(organism.rarity),
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: _getRarityHighlightColor(
                        organism.rarity,
                      ).withValues(alpha: 0.6),
                      blurRadius: 8.0,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: _OrganismSpriteDisplay(
                organism: organism,
                isNameVisible: isNameVisible,
                silhouetteColor: Colors.black.withValues(alpha: 0.8),
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            if (isNameVisible) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _biomeBaseColor.withValues(alpha: 0.6),
                      _biomeDarkColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _biomeHighlightColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _biomeHighlightColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    organism.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (result.isRare)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.lightBlueAccent,
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.nights_stay,
                          color: Colors.lightBlueAccent,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'OFF-TIME ENCOUNTER',
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 12),
              if (result.isRare)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.lightBlueAccent,
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.nights_stay,
                          color: Colors.lightBlueAccent,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'OFF-TIME ENCOUNTER',
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () => _revealName(organism),
                icon: const Icon(
                  Icons.psychology,
                  color: Colors.black,
                  size: 18,
                ),
                label: const Text(
                  'IDENTIFY',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _biomeHighlightColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: isNameVisible
                        ? () => _onEncounterFound(
                            organism,
                            startAsleep: result.isRare,
                          )
                        : () => _displayMessage(
                            "You cannot fight an unidentified animal!",
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNameVisible
                          ? _rarityHighlightColor
                          : Colors.grey.shade800,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    child: Text(
                      isNameVisible ? 'FIGHT' : 'LOCKED',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _startExploration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black26,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white24, width: 2),
                      ),
                    ),
                    child: const Text(
                      'RUN',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _startExploration,
              child: Text(
                'SKIP & CONTINUE EXPLORING',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganismSpriteDisplay extends StatefulWidget {
  final Organism organism;
  final bool isNameVisible;
  final Color silhouetteColor;
  final double height;
  final BoxFit fit;

  const _OrganismSpriteDisplay({
    required this.organism,
    required this.isNameVisible,
    required this.silhouetteColor,
    this.height = 200,
    this.fit = BoxFit.contain,
  });

  @override
  __OrganismSpriteDisplayState createState() => __OrganismSpriteDisplayState();
}

class __OrganismSpriteDisplayState extends State<_OrganismSpriteDisplay> {
  String? _imageSourceType;
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
  }

  String _getLocalPath() {
    final fileName = widget.organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll("-", '_');
    return 'assets/sprites/$fileName.png';
  }

  @override
  void didUpdateWidget(covariant _OrganismSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organism.name != widget.organism.name) {
      _imageSourceType = null;
      _determineImageSource();
    }
  }

  Future<void> _determineImageSource() async {
    final localPath = _getLocalPath();
    try {
      await rootBundle.load(localPath);
      if (mounted) {
        setState(() {
          _imageSourceType = 'local';
          _imagePath = localPath;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String spriteUrl = widget.organism.sprite;
          _imageSourceType = 'network';

          // 🚨 FIX: Remove 'file:///' prefix if present
          if (spriteUrl.startsWith('file:///')) {
            spriteUrl = spriteUrl.replaceFirst('file:///', '');
            if (spriteUrl.startsWith('assets/')) {
              _imageSourceType = 'local';
            }
          }
          _imagePath = spriteUrl;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSourceType == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    final String source = _imagePath;
    if (widget.isNameVisible) {
      return buildSilhouetteSprite(
        imageUrl: source,
        silhouetteColor: null, // Keep original Colors
        outlineColor: Colors.black,
        outlineWidth: 1.0,
        height: widget.height,
        width: 400,
        fit: widget.fit,
      );
    }
    return buildSilhouetteSprite(
      imageUrl: source,
      silhouetteColor: widget.silhouetteColor,
      outlineColor: Colors.white,
      outlineWidth: 1.2,
      height: widget.height,
      width: 400,
      fit: widget.fit,
    );
  }
}
