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
import 'dart:async';

class HabitatSortScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const HabitatSortScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<HabitatSortScreen> createState() => _HabitatSortScreenState();
}

class _HabitatSortScreenState extends State<HabitatSortScreen> {
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;
  bool _isGameOver = false;
  int _score = 0;
  int _highScore = 0;
  int _timeLeft = 60;
  Timer? _timer;

  Organism? _currentAnimal;
  final List<String> _targetBiomes = ['Ocean', 'Forest', 'Desert', 'Mountain'];
  final Map<String, String> _biomeImages = {
    'Ocean': 'assets/biomes/ocean-bg.png',
    'Forest': 'assets/biomes/forest-bg.png',
    'Desert': 'assets/biomes/desert-bg.png',
    'Mountain': 'assets/biomes/mountain-bg.png',
  };

  final AudioPlayer _correctPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _wrongPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  void initState() {
    super.initState();
    _correctPlayer.setSource(AssetSource('audio/correct.mp3'));
    _wrongPlayer.setSource(AssetSource('audio/wrong.mp3'));
    _highScore = (widget.currentUser.quizStats['habitatSort']?['correct'] as int?) ?? 0;
    _loadOrganisms().then((_) => _startGame());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _correctPlayer.dispose();
    _wrongPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);
      _allOrganisms = animalsData
          .map((json) => Organism.fromJson(json))
          .where((o) => _targetBiomes.contains(o.habitat))
          .toList();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _timeLeft = 60;
      _isGameOver = false;
      _nextAnimal();
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _gameOver();
        }
      });
    });
  }

  void _nextAnimal() {
    if (_allOrganisms.isEmpty) return;
    setState(() {
      _currentAnimal = _allOrganisms[Random().nextInt(_allOrganisms.length)];
    });
  }

  void _gameOver() async {
    _timer?.cancel();
    setState(() => _isGameOver = true);
    
    // Reward based on score
    int bonusExp = _score * 2;
    await widget.authService.addExperience(widget.currentUser.username, bonusExp);
    
    widget.authService.updateGameHighScore(widget.currentUser.username, 'habitatSort', _score);
    if (_score > _highScore) _highScore = _score;
  }

  void _handleSort(String biome) async {
    if (_currentAnimal == null || _isGameOver) return;

    if (_currentAnimal!.habitat == biome) {
      _correctPlayer.resume();
      setState(() => _score++);
      // Award XP per correct sort
      await widget.authService.addExperience(widget.currentUser.username, 5);
      _nextAnimal();
    } else {
      _wrongPlayer.resume();
      _nextAnimal();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: AppColors.surface, body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('HABITAT SORT', style: AppTextStyles.headline(context, baseSize: 14)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/biomes/savanna-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatTile(label: 'TIME', value: '$_timeLeft', color: _timeLeft < 10 ? Colors.red : Colors.white),
                  _StatTile(label: 'SCORE', value: '$_score', color: AppColors.highlightColor),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _isGameOver 
                  ? _GameOverView(score: _score, highScore: _highScore, onRestart: _startGame)
                  : _currentAnimal == null ? Container() : Draggable<String>(
                      data: _currentAnimal!.habitat,
                      feedback: _SortSprite(organism: _currentAnimal!, isDragging: true),
                      childWhenDragging: Opacity(opacity: 0.3, child: _SortSprite(organism: _currentAnimal!)),
                      child: _SortSprite(organism: _currentAnimal!),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _targetBiomes.map((biome) => _BiomeBucket(
                  biome: biome, 
                  image: _biomeImages[biome]!,
                  onAccept: () => _handleSort(biome),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8.sp, color: Colors.white54)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontFamily: 'PressStart2P', fontSize: 18.sp, color: color)),
      ],
    );
  }
}

class _BiomeBucket extends StatelessWidget {
  final String biome;
  final String image;
  final VoidCallback onAccept;

  const _BiomeBucket({required this.biome, required this.image, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => onAccept(),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 75.w,
          height: 90.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isHovered ? AppColors.highlightColor : Colors.white24, width: 2),
            image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken)),
            boxShadow: isHovered ? [BoxShadow(color: AppColors.highlightColor.withValues(alpha: 0.5), blurRadius: 10)] : [],
          ),
          child: Center(
            child: Text(biome.toUpperCase(), style: TextStyle(fontFamily: 'PressStart2P', fontSize: 6.sp, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ),
        );
      },
    );
  }
}

class _SortSprite extends StatelessWidget {
  final Organism organism;
  final bool isDragging;
  const _SortSprite({required this.organism, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    final fileName = organism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", '_');
    final imagePath = 'assets/sprites/$fileName.png';

    return Container(
      width: isDragging ? 100 : 150,
      height: isDragging ? 100 : 150,
      decoration: BoxDecoration(
        color: isDragging ? Colors.transparent : Colors.black26,
        shape: BoxShape.circle,
        border: isDragging ? null : Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: buildSilhouetteSprite(
        imageUrl: imagePath,
        silhouetteColor: null,
        outlineColor: Colors.black,
        outlineWidth: 2.0,
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  final int score;
  final int highScore;
  final VoidCallback onRestart;
  const _GameOverView({required this.score, required this.highScore, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.highlightColor)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TIME UP!', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 20.sp, color: Colors.red)),
          const SizedBox(height: 24),
          Text('FINAL SCORE: $score', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14.sp, color: Colors.white)),
          const SizedBox(height: 12),
          Text('HIGH SCORE: $highScore', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: AppColors.highlightColor)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: onRestart, child: const Text('PLAY AGAIN')),
        ],
      ),
    );
  }
}
