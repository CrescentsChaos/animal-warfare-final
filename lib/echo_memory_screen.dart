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

class EchoMemoryScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const EchoMemoryScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<EchoMemoryScreen> createState() => _EchoMemoryScreenState();
}

class _EchoMemoryScreenState extends State<EchoMemoryScreen> {
  List<Organism> _allOrganisms = [];
  List<Organism> _activeFour = [];
  bool _isLoading = true;
  bool _isGameOver = false;
  bool _isPlayingSequence = false;

  List<int> _sequence = [];
  List<int> _playerSequence = [];
  int _wave = 1;
  int _points = 0;
  int _highScore = 0;

  final AudioPlayer _effectPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _wrongPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  int? _flashingIndex;

  @override
  void initState() {
    super.initState();
    _wrongPlayer.setSource(AssetSource('audio/wrong.mp3'));
    _highScore = (widget.currentUser.quizStats['echoMemory']?['correct'] as int?) ?? 0;
    _loadOrganisms().then((_) => _startGame());
  }

  @override
  void dispose() {
    _effectPlayer.dispose();
    _wrongPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);
      _allOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
      
      final random = Random();
      final set = <Organism>{};
      while (set.length < 4) {
        set.add(_allOrganisms[random.nextInt(_allOrganisms.length)]);
      }
      _activeFour = set.toList();
      
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _startGame() {
    setState(() {
      _sequence = [];
      _playerSequence = [];
      _wave = 1;
      _points = 0;
      _isGameOver = false;
    });
    _nextWave();
  }

  void _nextWave() {
    _sequence.add(Random().nextInt(4));
    _playSequence();
  }

  Future<void> _playSequence() async {
    setState(() {
      _isPlayingSequence = true;
      _playerSequence = [];
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    for (int index in _sequence) {
      if (!mounted) return;
      setState(() => _flashingIndex = index);
      _playNote(index);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _flashingIndex = null);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() => _isPlayingSequence = false);
  }

  Future<void> _playNote(int index) async {
    // Note: fallback to correct.mp3 if notes don't exist
    try {
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource('audio/correct.mp3'));
    } catch (_) {}
  }

  void _handleInput(int index) async {
    if (_isPlayingSequence || _isGameOver) return;

    _playNote(index);
    _playerSequence.add(index);

    if (_playerSequence[(_playerSequence.length - 1)] != _sequence[(_playerSequence.length - 1)]) {
      _gameOver();
      return;
    }

    if (_playerSequence.length == _sequence.length) {
      setState(() {
        _wave++;
        _points += 100;
      });
      // Award XP for wave completion
      await widget.authService.addExperience(widget.currentUser.username, 50);
      Future.delayed(const Duration(milliseconds: 800), _nextWave);
    }
  }

  void _gameOver() async {
    _wrongPlayer.resume();
    setState(() => _isGameOver = true);
    
    // Reward bonus based on wave
    int bonusExp = (_wave - 1) * 20;
    await widget.authService.addExperience(widget.currentUser.username, bonusExp);
    
    widget.authService.updateGameHighScore(widget.currentUser.username, 'echoMemory', _wave - 1);
    if ((_wave - 1) > _highScore) _highScore = _wave - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: AppColors.surface, body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('THE ECHO', style: AppTextStyles.headline(context, baseSize: 14)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/biomes/mountain-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.8), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Text('WAVE', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: Colors.white54)),
                  const SizedBox(height: 12),
                  Text('$_wave', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 32.sp, color: AppColors.primary, shadows: [Shadow(color: AppColors.primary, blurRadius: 20)])),
                  const SizedBox(height: 16),
                  Text('POINTS: $_points', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9.sp, color: AppColors.highlightColor)),
                  const SizedBox(height: 8),
                  Text('BEST: $_highScore', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8.sp, color: Colors.white30)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _isGameOver 
                  ? _GameOverView(score: _wave - 1, highScore: _highScore, onRestart: _startGame)
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20),
                        itemCount: 4,
                        itemBuilder: (context, index) => _EchoTile(
                          organism: _activeFour[index],
                          isFlashing: _flashingIndex == index,
                          onTap: () => _handleInput(index),
                          color: _getTileColor(index),
                        ),
                      ),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Text(
                _isPlayingSequence ? 'WATCH CAREFULLY...' : 'REPEAT THE ECHO!',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8.sp, color: _isPlayingSequence ? Colors.orange : Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTileColor(int index) {
    switch (index) {
      case 0: return Colors.cyanAccent;
      case 1: return Colors.orangeAccent;
      case 2: return Colors.purpleAccent;
      case 3: return Colors.greenAccent;
      default: return Colors.white;
    }
  }
}

class _EchoTile extends StatelessWidget {
  final Organism organism;
  final bool isFlashing;
  final VoidCallback onTap;
  final Color color;

  const _EchoTile({required this.organism, required this.isFlashing, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    final fileName = organism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", '_');
    final imagePath = 'assets/sprites/$fileName.png';

    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isFlashing ? color : Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isFlashing ? Colors.white : color.withValues(alpha: 0.3), width: 3),
          boxShadow: isFlashing ? [BoxShadow(color: color, blurRadius: 30, spreadRadius: 5)] : [],
        ),
        padding: const EdgeInsets.all(20),
        child: buildSilhouetteSprite(
          imageUrl: imagePath,
          silhouetteColor: isFlashing ? Colors.white : null,
          outlineColor: isFlashing ? Colors.transparent : Colors.black,
        ),
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
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.cyanAccent)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('FADED!', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 20.sp, color: Colors.orange)),
          const SizedBox(height: 24),
          Text('WAVES SURVIVED: $score', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12.sp, color: Colors.white)),
          const SizedBox(height: 12),
          Text('HIGH SCORE: $highScore', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: Colors.cyanAccent)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: onRestart, child: const Text('RE-ECHO')),
        ],
      ),
    );
  }
}
