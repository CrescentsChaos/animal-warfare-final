import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'package:animal_warfare/theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum ShowdownStat { health, attack, defense, speed, weight }

extension ShowdownStatExtension on ShowdownStat {
  String get name {
    switch (this) {
      case ShowdownStat.health: return 'HEALTH';
      case ShowdownStat.attack: return 'ATTACK';
      case ShowdownStat.defense: return 'DEFENSE';
      case ShowdownStat.speed: return 'SPEED';
      case ShowdownStat.weight: return 'WEIGHT';
    }
  }

  Color get color {
    switch (this) {
      case ShowdownStat.health: return AppColors.statHealthColor;
      case ShowdownStat.attack: return AppColors.statAttackColor;
      case ShowdownStat.defense: return AppColors.statDefenseColor;
      case ShowdownStat.speed: return AppColors.statSpeedColor;
      case ShowdownStat.weight: return Colors.orange;
    }
  }
}

class StatShowdownScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const StatShowdownScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<StatShowdownScreen> createState() => _StatShowdownScreenState();
}

class _StatShowdownScreenState extends State<StatShowdownScreen> with SingleTickerProviderStateMixin {
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  Organism? _animalA;
  Organism? _animalB;
  ShowdownStat? _currentStat;

  int _streak = 0;
  int _highScore = 0;
  bool _gameOver = false;
  bool _revealed = false;

  final AudioPlayer _correctPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _wrongPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _correctPlayer.setSource(AssetSource('audio/correct.mp3'));
    _wrongPlayer.setSource(AssetSource('audio/wrong.mp3'));
    
    final stats = widget.currentUser.quizStats['statShowdown'];
    _highScore = (stats?['Normal']?['correct'] as int?) ?? (stats?['correct'] as int?) ?? 0;

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _loadOrganisms().then((_) {
      _startNewGame();
    });
  }

  @override
  void dispose() {
    if (!_gameOver && _streak > 0) {
      widget.authService.updateGameHighScore(widget.currentUser.username, 'statShowdown', _streak);
    }
    _correctPlayer.dispose();
    _wrongPlayer.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _playSound(AudioPlayer player) async {
    if (player.state == PlayerState.playing) {
      await player.stop();
    }
    await player.resume();
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);
      _allOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _startNewGame() {
    _streak = 0;
    _gameOver = false;
    _revealed = false;
    _nextRound(isFirstRound: true);
  }

  void _nextRound({bool isFirstRound = false}) {
    if (_allOrganisms.length < 2) return;
    
    final random = Random();
    
    if (isFirstRound) {
      _animalA = _allOrganisms[random.nextInt(_allOrganisms.length)];
    } else {
      _animalA = _animalB;
    }

    _currentStat = ShowdownStat.values[random.nextInt(ShowdownStat.values.length)];
    
    // Ensure B is different and has a different stat value to prevent ties
    Organism nextB;
    do {
      nextB = _allOrganisms[random.nextInt(_allOrganisms.length)];
    } while (nextB.name == _animalA!.name || _getStatValue(nextB, _currentStat!) == _getStatValue(_animalA!, _currentStat!));
    
    setState(() {
      _animalB = nextB;
      _revealed = false;
    });

    _animController.forward(from: 0);
  }

  double _getStatValue(Organism org, ShowdownStat stat) {
    switch (stat) {
      case ShowdownStat.health: return org.health.toDouble();
      case ShowdownStat.attack: return org.attack.toDouble();
      case ShowdownStat.defense: return org.defense.toDouble();
      case ShowdownStat.speed: return org.speed.toDouble();
      case ShowdownStat.weight: return org.weight;
    }
  }

  String _formatStatValue(double value, ShowdownStat stat) {
    if (stat == ShowdownStat.weight) {
      return '${value.toStringAsFixed(1)} kg';
    }
    return value.toInt().toString();
  }

  Future<void> _handleGuess(bool guessedHigher) async {
    if (_revealed || _gameOver) return;
    
    final valA = _getStatValue(_animalA!, _currentStat!);
    final valB = _getStatValue(_animalB!, _currentStat!);
    
    final isHigher = valB > valA;
    final isCorrect = (guessedHigher && isHigher) || (!guessedHigher && !isHigher);
    
    setState(() {
      _revealed = true;
    });

    if (isCorrect) {
      _playSound(_correctPlayer);
      _streak++;
      // Award small XP per correct guess
      await widget.authService.addExperience(widget.currentUser.username, 5);
      
      if (_streak > _highScore) {
        _highScore = _streak;
      }
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_gameOver) {
          _nextRound();
        }
      });
    } else {
      _playSound(_wrongPlayer);
      setState(() {
        _gameOver = true;
      });
      
      // Award final rewards based on streak
      int finalExp = 50 + (_streak * 10);
      await widget.authService.addExperience(widget.currentUser.username, finalExp);
      
      await widget.authService.updateGameHighScore(
        widget.currentUser.username,
        'statShowdown',
        _streak,
      );
    }
  }

  Widget _buildAnimalCard(Organism org, bool isAnimalA) {
    final val = _getStatValue(org, _currentStat!);
    final valStr = _formatStatValue(val, _currentStat!);
    final statColor = _currentStat!.color;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAnimalA ? Colors.white30 : AppColors.highlightColor.withValues(alpha: 0.5), width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(org.name.toUpperCase(), style: AppTextStyles.headline(context, baseSize: 10), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            _ShowdownSpriteDisplay(organism: org),
            const SizedBox(height: 16),
            if (isAnimalA || _revealed)
              Text(
                valStr,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20.sp,
                  color: statColor,
                  shadows: [Shadow(color: statColor.withValues(alpha: 0.5), blurRadius: 10)],
                ),
              )
            else
              SizedBox(
                width: 180,
                child: Column(
                  children: [
                    _GameButton(
                      label: 'HIGHER',
                      color: AppColors.correctGreen,
                      icon: Icons.arrow_upward,
                      onTap: () => _handleGuess(true),
                    ),
                    const SizedBox(height: 8),
                    _GameButton(
                      label: 'LOWER',
                      color: AppColors.wrongRed,
                      icon: Icons.arrow_downward,
                      onTap: () => _handleGuess(false),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _animalA == null || _animalB == null) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.highlightColor)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('STAT SHOWDOWN', style: AppTextStyles.headline(context, baseSize: 14)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          image: DecorationImage(
            image: const AssetImage('assets/biomes/mountain-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.8), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('STREAK: $_streak', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: Colors.white)),
                    Text('HIGH SCORE: $_highScore', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: AppColors.highlightColor)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _currentStat!.name,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 20.sp,
                    color: _currentStat!.color,
                    letterSpacing: 2,
                    shadows: [Shadow(color: _currentStat!.color.withValues(alpha: 0.5), blurRadius: 10)],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Expanded(child: _buildAnimalCard(_animalA!, true)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: CircleAvatar(
                          backgroundColor: Colors.white12,
                          radius: 20,
                          child: Text('VS', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12.sp, color: Colors.white54)),
                        ),
                      ),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Opacity(
                                opacity: (1.0 - (_slideAnimation.value / 100)).clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: _buildAnimalCard(_animalB!, false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_gameOver)
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.wrongRed, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text('GAME OVER!', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16.sp, color: AppColors.wrongRed)),
                      const SizedBox(height: 12),
                      Text('FINAL STREAK: $_streak', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12.sp, color: Colors.white)),
                      const SizedBox(height: 24),
                      _GameButton(
                        label: 'PLAY AGAIN',
                        color: AppColors.highlightColor,
                        icon: Icons.refresh,
                        onTap: _startNewGame,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _GameButton({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12.sp, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowdownSpriteDisplay extends StatefulWidget {
  final Organism organism;

  const _ShowdownSpriteDisplay({required this.organism});

  @override
  __ShowdownSpriteDisplayState createState() => __ShowdownSpriteDisplayState();
}

class __ShowdownSpriteDisplayState extends State<_ShowdownSpriteDisplay> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
  }
  
  @override
  void didUpdateWidget(covariant _ShowdownSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organism.name != widget.organism.name) {
      _determineImageSource();
    }
  }

  void _determineImageSource() {
    final String spriteUrl = widget.organism.sprite;
    final fileName = widget.organism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", '_');
    String finalPath = 'assets/sprites/$fileName.png';

    if (spriteUrl.isNotEmpty && !spriteUrl.startsWith('http') && !spriteUrl.contains(' ')) {
      finalPath = spriteUrl.startsWith('assets/') ? spriteUrl : 'assets/sprites/$spriteUrl';
    }

    setState(() {
      _imagePath = finalPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_imagePath == null) return const SizedBox(height: 80);
    return SizedBox(
      height: 80,
      child: buildSilhouetteSprite(
        imageUrl: _imagePath!,
        silhouetteColor: null,
        outlineColor: Colors.black,
        outlineWidth: 2.0,
      ),
    );
  }
}
