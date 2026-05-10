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
import 'package:animal_warfare/achievement_service.dart';
import 'dart:async';

class SilhouetteSprintScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const SilhouetteSprintScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<SilhouetteSprintScreen> createState() => _SilhouetteSprintScreenState();
}

class _SilhouetteSprintScreenState extends State<SilhouetteSprintScreen> {
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;
  bool _isGameOver = false;
  int _score = 0;
  int _highScore = 0;
  double _timeLeft = 30.0;
  Timer? _timer;

  Organism? _currentAnimal;
  List<Organism> _options = [];

  final AudioPlayer _correctPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _wrongPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  void initState() {
    super.initState();
    _correctPlayer.setSource(AssetSource('audio/correct.mp3'));
    _wrongPlayer.setSource(AssetSource('audio/wrong.mp3'));
    final stats = widget.currentUser.quizStats['silhouetteSprint'];
    _highScore = (stats?['Normal']?['correct'] as int?) ?? (stats?['correct'] as int?) ?? 0;
    _loadOrganisms().then((_) => _startGame());
  }

  @override
  void dispose() {
    if (!_isGameOver && _score > 0) {
      widget.authService.updateGameHighScore(widget.currentUser.username, 'silhouetteSprint', _score);
    }
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
      _allOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _timeLeft = 30.0;
      _isGameOver = false;
      _nextQuestion();
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft -= 0.1;
        } else {
          _gameOver();
        }
      });
    });
  }

  void _nextQuestion() {
    if (_allOrganisms.isEmpty) return;
    final random = Random();
    final correct = _allOrganisms[random.nextInt(_allOrganisms.length)];
    final options = [correct];
    
    while (options.length < 4) {
      final decoy = _allOrganisms[random.nextInt(_allOrganisms.length)];
      if (!options.contains(decoy)) options.add(decoy);
    }
    options.shuffle();

    setState(() {
      _currentAnimal = correct;
      _options = options;
    });
  }

  void _gameOver() async {
    _timer?.cancel();
    setState(() => _isGameOver = true);
    
    // Reward based on score
    int bonusExp = _score * 3;
    await widget.authService.addExperience(widget.currentUser.username, bonusExp);
    
    await widget.authService.updateGameHighScore(widget.currentUser.username, 'silhouetteSprint', _score);
    if (_score > _highScore) {
      setState(() => _highScore = _score);
    }

    // Check achievements
    final updatedUser = await widget.authService.getCurrentUser();
    if (updatedUser != null && mounted) {
      final achievementService = AchievementService(
        allOrganisms: _allOrganisms.map((o) => o.toJson()).toList(),
        authService: widget.authService,
      );
      final unlocked = await achievementService.checkAndUnlockAchievements(updatedUser);
      if (unlocked.isNotEmpty && mounted) {
        for (var title in unlocked) {
          achievementService.showAchievementSnackbar(context, title);
        }
      }
    }
  }

  void _handleGuess(Organism org) async {
    if (_isGameOver) return;

    if (org.name == _currentAnimal!.name) {
      _correctPlayer.resume();
      setState(() {
        _score++;
        _timeLeft += 2.0; // Bonus time
        if (_timeLeft > 40) _timeLeft = 40; // Cap max time
      });
      // Award XP
      await widget.authService.addExperience(widget.currentUser.username, 5);
      _nextQuestion();
    } else {
      _wrongPlayer.resume();
      setState(() {
        _timeLeft -= 3.0; // Penalty
      });
      if (_timeLeft <= 0) _gameOver();
      _nextQuestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: AppColors.surface, body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('SILHOUETTE SPRINT', style: AppTextStyles.headline(context, baseSize: 14)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/biomes/frozen-ocean-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            _TimeProgressBar(timeLeft: _timeLeft, maxTime: 40.0),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SCORE: $_score', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: AppColors.highlightColor)),
                  Text('BEST: $_highScore', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: Colors.white54)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _isGameOver 
                  ? _GameOverView(score: _score, highScore: _highScore, onRestart: _startGame)
                  : _currentAnimal == null ? Container() : _SprintSilhouette(organism: _currentAnimal!),
              ),
            ),
            if (!_isGameOver) Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
                children: _options.map((opt) => _ChoiceButton(onPressed: () => _handleGuess(opt), label: opt.name)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeProgressBar extends StatelessWidget {
  final double timeLeft;
  final double maxTime;
  const _TimeProgressBar({required this.timeLeft, required this.maxTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: double.infinity,
      color: Colors.black26,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (timeLeft / maxTime).clamp(0.0, 1.0),
        child: Container(color: timeLeft < 10 ? Colors.red : AppColors.primary),
      ),
    );
  }
}

class _SprintSilhouette extends StatelessWidget {
  final Organism organism;
  const _SprintSilhouette({required this.organism});

  @override
  Widget build(BuildContext context) {
    final fileName = organism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", '_');
    final imagePath = 'assets/sprites/$fileName.png';

    return Container(
      width: 220,
      height: 220,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: buildSilhouetteSprite(
        imageUrl: imagePath,
        silhouetteColor: Colors.black,
        outlineColor: Colors.white70,
        outlineWidth: 1.5,
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const _ChoiceButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label.toUpperCase(), style: AppTextStyles.label(context, baseSize: 8, color: Colors.white), textAlign: TextAlign.center),
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
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CRASHED!', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 20.sp, color: Colors.red)),
          const SizedBox(height: 24),
          Text('CORRECT NAMES: $score', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14.sp, color: Colors.white)),
          const SizedBox(height: 12),
          Text('HIGH SCORE: $highScore', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp, color: AppColors.primary)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: onRestart, child: const Text('RETRY SPRINT')),
        ],
      ),
    );
  }
}
