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
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'dart:async';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/shop_screen.dart';

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

  Organism? _currentEncounter;
  bool _isExploring = false;
  bool _isNameRevealed = false;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  late Color _biomeBaseColor;
  late Color _biomeDarkColor;
  late Color _biomeHighlightColor;
  late Color _rarityHighlightColor = highlightColor;

  final AudioPlayer _audioPlayer = AudioPlayer();
  List<dynamic> _allOrganismsJson = [];
  late AchievementService _achievementService;
  late UserData _currentUser;

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

    WidgetsBinding.instance.addObserver(this);
    _startClockTimer();
    _playBiomeMusic(widget.biomeName);
  }

  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Color _getDarkerColor(Color color) {
    int r = (color.red * 0.6).round().clamp(0, 255);
    int g = (color.green * 0.6).round().clamp(0, 255);
    int b = (color.blue * 0.6).round().clamp(0, 255);
    return Color.fromARGB(color.alpha, r, g, b);
  }

  Color _getBiomeHighlightColor(String biomeName) {
    final biome = biomeName.toLowerCase();
    if (biome.contains('swamp') || biome.contains('mangrove'))
      return const Color(0xFFCE93D8);
    if (biome.contains('desert') || biome.contains('savanna'))
      return const Color(0xFFFFD740);
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra') ||
        biome.contains('polar') ||
        biome.contains('frozen'))
      return const Color(0xFF40C4FF);
    if (biome.contains('volcan')) return const Color(0xFFFF5252);
    if (biome.contains('mountain') ||
        biome.contains('cave') ||
        biome.contains('urban') ||
        biome.contains('taiga'))
      return const Color(0xFFB0BEC5);
    if (biome.contains('forest') ||
        biome.contains('jungle') ||
        biome.contains('rainforest') ||
        biome.contains('kelp'))
      return const Color(0xFF69F0AE);
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river') ||
        biome.contains('deep sea') ||
        biome.contains('coral') ||
        biome.contains('coastal'))
      return const Color(0xFF448AFF);
    return const Color(0xFFDAA520);
  }

  String _getTimeOfDay() {
    final hour = _currentTime.hour;
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

  void _onEncounterFound(Organism wildOrganism) async {
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
        Organism.HUMAN_ORGANISM.copyWith(name: user.username),
        level: user.accountLevel,
      );
    }
    final wildFighter = CapturedOrganism.spawn(
      wildOrganism,
      accountLevel: user.accountLevel,
    );
    AudioService.instance.pauseAll();
    final Object? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerFighter,
          opponentOrganism: wildFighter,
          biomeName: widget.biomeName,
          playerTeam: user.teamOrganisms,
          timeOfDay: _getTimeOfDay(),
        ),
      ),
    );
    AudioService.instance.resumeAll();
    if (result == BattleResult.capture ||
        result == BattleResult.fled ||
        result == BattleResult.win) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _startExploration();
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
    _clockTimer?.cancel();
    _stopAndDisposeMusic();
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildClock() {
    final hour = _currentTime.hour.toString().padLeft(2, '0');
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final timeStr = "$hour:$minute";
    final isNight = _getTimeOfDay() == 'night';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _biomeHighlightColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNight ? Icons.nightlight_round : Icons.wb_sunny,
            color: _biomeHighlightColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough stamina! Need $cost stamina.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      return;
    }
    await userState.decreaseStamina(cost);
    await widget.authService.markOrganismAsDiscovered(
      _currentUser.username,
      organism.name,
    );
    await _refreshUserData();
    final newAchievements = await _achievementService
        .checkAndUnlockAchievements(_currentUser);
    if (newAchievements.isNotEmpty) {
      _currentUser = _currentUser.copyWith(
        completedAchievements: [
          ..._currentUser.completedAchievements,
          ...newAchievements,
        ],
      );
      await widget.authService.updateUser(_currentUser);
      userState.setCurrentUser(_currentUser);
      for (final title in newAchievements) {
        if (mounted)
          _achievementService.showAchievementSnackbar(context, title);
      }
    }
    if (mounted) setState(() => _isNameRevealed = true);
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
    if (requiredMove == null) return null;
    if (biome.contains('cave')) {
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough stamina!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      return;
    }
    await userState.decreaseStamina(10);
    setState(() {
      _isExploring = true;
      _currentEncounter = null;
      _isNameRevealed = false;
    });
    Future.delayed(const Duration(seconds: 1), () {
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
      );
      if (mounted) {
        setState(() {
          _currentEncounter = encounter;
          _isExploring = false;
          if (encounter != null) {
            _rarityHighlightColor = _getRarityHighlightColor(encounter.rarity);
            _isNameRevealed = _isDiscovered(encounter);
          }
        });
      }
    });
  }

  void _showStatsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _StatsModalContent(),
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
            width: 90,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _biomeHighlightColor, width: 2),
              borderRadius: BorderRadius.circular(4),
              color: _biomeDarkColor,
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: user.stamina > 25
                          ? Colors.greenAccent[400]
                          : Colors.redAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${user.stamina}/100',
                    style: TextStyle(
                      color: user.stamina > 50 ? Colors.black : Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
        title: Row(
          children: [
            Expanded(child: Text(widget.biomeName.toUpperCase())),
            _buildClock(),
          ],
        ),
        backgroundColor: _biomeDarkColor,
        titleTextStyle: TextStyle(
          color: _biomeHighlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 14,
        ),
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
      body: Container(
        decoration: BoxDecoration(
          color: _biomeBaseColor,
          image: DecorationImage(
            image: AssetImage(_getAssetPath(widget.biomeName)),
            fit: BoxFit.cover,
            colorFilter: _getTimeOfDay() == 'day'
                ? ColorFilter.mode(
                    _biomeDarkColor.withOpacity(0.5),
                    BlendMode.darken,
                  )
                : ColorFilter.mode(
                    _getTimeOfDay() == 'evening'
                        ? Colors.orangeAccent.withOpacity(0.3)
                        : Colors.indigo[900]!.withOpacity(0.5),
                    BlendMode.darken,
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
                    CircularProgressIndicator(color: _biomeHighlightColor),
                    const SizedBox(height: 10),
                    Text(
                      'EXPLORING...',
                      style: TextStyle(
                        color: _biomeHighlightColor,
                        fontFamily: 'PressStart2P',
                        fontSize: 18,
                        shadows: [
                          Shadow(
                            color: _biomeHighlightColor.withOpacity(0.5),
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
              if (!_isExploring && _currentEncounter == null)
                ElevatedButton(
                  onPressed: _startExploration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _biomeDarkColor,
                    shape: StadiumBorder(
                      side: BorderSide(color: _biomeHighlightColor, width: 2),
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
    );
  }

  Widget _buildEncounterResultCard(Organism organism) {
    final bool isNameVisible = _isDiscovered(organism) || _isNameRevealed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: _biomeDarkColor.withOpacity(0.8),
        border: Border.all(color: _rarityHighlightColor, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _rarityHighlightColor.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isNameVisible ? 'ENCOUNTER:' : 'UNKNOWN ANIMAL DETECTED:',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 14,
              shadows: [
                Shadow(
                  color: _rarityHighlightColor.withOpacity(0.8),
                  blurRadius: 8.0,
                ),
              ],
            ),
          ),
          Text(
            organism.rarity.toUpperCase(),
            style: TextStyle(
              color: _getRarityColor(organism.rarity),
              fontFamily: 'PressStart2P',
              fontSize: 20,
              shadows: [
                Shadow(
                  color: _getRarityHighlightColor(
                    organism.rarity,
                  ).withOpacity(0.8),
                  blurRadius: 10.0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: _rarityHighlightColor, thickness: 2),
          const SizedBox(height: 10),
          _OrganismSpriteDisplay(
            organism: organism,
            isNameVisible: isNameVisible,
            silhouetteColor: Colors.black,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          if (isNameVisible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _biomeBaseColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _biomeHighlightColor),
              ),
              child: Text(
                organism.name.toUpperCase(),
                style: TextStyle(
                  color: _biomeHighlightColor,
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _revealName(organism),
              style: ElevatedButton.styleFrom(
                backgroundColor: _biomeHighlightColor.withOpacity(0.8),
                shape: const StadiumBorder(
                  side: BorderSide(color: Colors.black, width: 2),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
              child: Text(
                'IDENTIFY',
                style: TextStyle(
                  color: _biomeDarkColor,
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isNameVisible
                      ? () => _onEncounterFound(organism)
                      : () => _displayMessage(
                          "You cannot fight an unidentified animal!",
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isNameVisible
                        ? _rarityHighlightColor
                        : Colors.grey.shade600,
                    shape: const StadiumBorder(
                      side: BorderSide(color: Colors.black, width: 3),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isNameVisible ? 'FIGHT' : 'LOCKED',
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startExploration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _biomeDarkColor.withOpacity(0.8),
                    shape: StadiumBorder(
                      side: BorderSide(color: _biomeHighlightColor, width: 2),
                    ),
                  ),
                  child: Text(
                    'RUN',
                    style: TextStyle(
                      color: _biomeHighlightColor,
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startExploration,
            style: ElevatedButton.styleFrom(
              backgroundColor: _biomeDarkColor.withOpacity(0.7),
              shape: StadiumBorder(
                side: BorderSide(color: _rarityHighlightColor, width: 2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            ),
            child: Text(
              'EXPLORE',
              style: TextStyle(
                color: _rarityHighlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 14,
              ),
            ),
          ),
        ],
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
    if (_imageSourceType == null)
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    final String source = _imagePath;
    if (widget.isNameVisible) {
      if (_imageSourceType == 'local')
        return Image.asset(
          source,
          height: widget.height,
          width: 400,
          fit: widget.fit,
        );
      return Image.network(
        source,
        height: widget.height,
        width: 400,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) =>
            loadingProgress == null
            ? child
            : SizedBox(
                height: widget.height,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
        errorBuilder: (context, error, stackTrace) => SizedBox(
          height: widget.height,
          child: const Center(
            child: Text(
              'IMAGE ERROR',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'PressStart2P',
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }
    return buildSilhouetteSprite(
      imageUrl: source,
      silhouetteColor: widget.silhouetteColor,
      height: widget.height,
      width: 400,
      fit: widget.fit,
    );
  }
}

class _StatsModalContent extends StatelessWidget {
  const _StatsModalContent();
  Widget _buildStatRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    ),
  );

  Widget _buildStaminaBar(BuildContext context, int currentStamina) {
    final progress = currentStamina / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STAMINA',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 5),
        Stack(
          children: [
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.grey[800],
              minHeight: 20,
              color: Colors.grey[600],
            ),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              color: currentStamina > 25
                  ? Colors.greenAccent[400]
                  : Colors.redAccent,
              minHeight: 20,
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  '$currentStamina / 100',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Regenerates +20 every 5 seconds.',
          style: TextStyle(fontSize: 10, color: Colors.greenAccent),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserState>(
      builder: (context, userState, child) {
        final user = userState.currentUser;
        if (user == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Player Stats',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(),
              _buildStatRow('Username:', user.username),
              _buildStatRow('Gender:', user.gender),
              _buildStatRow('Money:', '\$${user.money}'),
              const SizedBox(height: 20),
              _buildStaminaBar(context, user.stamina),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
