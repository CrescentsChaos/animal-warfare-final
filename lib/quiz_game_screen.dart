// lib/quiz_game_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'package:animal_warfare/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum QuizType {
  scientificToCommon,
  commonToScientific,
  spriteToName,
  spriteToScientific,
  silhouetteToName,
  silhouetteToScientific,
}

extension QuizTypeExtension on QuizType {
  String get displayName {
    switch (this) {
      case QuizType.scientificToCommon:
        return 'Scientific to Name';
      case QuizType.commonToScientific:
        return 'Name to Scientific';
      case QuizType.spriteToName:
        return 'Sprite to Name';
      case QuizType.spriteToScientific:
        return 'Sprite to Scientific';
      case QuizType.silhouetteToName:
        return 'Silhouette to Name';
      case QuizType.silhouetteToScientific:
        return 'Silhouette to Scientific';
    }
  }

  String get description {
    switch (this) {
      case QuizType.scientificToCommon:
        return 'Identify by Latin names';
      case QuizType.commonToScientific:
        return 'Learn the biology';
      case QuizType.spriteToName:
        return 'Visual identification';
      case QuizType.spriteToScientific:
        return 'Advanced recognition';
      case QuizType.silhouetteToName:
        return 'Shadow challenge';
      case QuizType.silhouetteToScientific:
        return 'Expert biology';
    }
  }

  IconData get icon {
    switch (this) {
      case QuizType.scientificToCommon:
        return Icons.biotech;
      case QuizType.commonToScientific:
        return Icons.sort_by_alpha;
      case QuizType.spriteToName:
        return Icons.image;
      case QuizType.spriteToScientific:
        return Icons.image_search;
      case QuizType.silhouetteToName:
        return Icons.hide_image;
      case QuizType.silhouetteToScientific:
        return Icons.visibility_off;
    }
  }
}

class QuizGameScreen extends StatefulWidget {
  final QuizType quizType;
  final UserData currentUser;
  final LocalAuthService authService;

  const QuizGameScreen({
    super.key,
    required this.quizType,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  Organism? _currentQuestion;
  List<Organism>? _currentOptions;
  String? _selectedAnswer;
  String? _correctAnswer;
  bool _isAnswered = false;

  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  // 🟢 NEW: Store the current user data locally so we can update it
  late UserData _currentUser;

  // 🔴 REMOVED: Soft hardcoded colors

  static const int _numberOfOptions = 4;
  static const int _delayAfterAnswerSeconds = 2; // Faster transition

  @override
  void initState() {
    super.initState();
    // 🟢 NEW: Initialize local user data
    _currentUser = widget.currentUser;

    _loadOrganisms().then((_) {
      _startNewQuestion();
    });
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);

      _allOrganisms = animalsData
          .map((json) => Organism.fromJson(json))
          .toList();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _startNewQuestion() {
    if (_allOrganisms.isEmpty) return;
    final List<Organism> quizSource = _allOrganisms;

    if (quizSource.length < _numberOfOptions) {
      setState(() {
        _isLoading = false;
        _currentQuestion = null;
      });
      return;
    }

    final random = Random();
    final questionIndex = random.nextInt(quizSource.length);
    _currentQuestion = quizSource[questionIndex];

    final List<Organism> options = [_currentQuestion!];
    final Set<int> usedIndices = {questionIndex};

    while (options.length < _numberOfOptions) {
      int decoyIndex;
      do {
        decoyIndex = random.nextInt(quizSource.length);
      } while (usedIndices.contains(decoyIndex));

      usedIndices.add(decoyIndex);
      options.add(quizSource[decoyIndex]);
    }

    _correctAnswer = _getAnswerText(_currentQuestion!);
    options.shuffle();

    setState(() {
      _currentOptions = options;
      _selectedAnswer = null;
      _isAnswered = false;
    });
  }

  String _getAnswerText(Organism organism) {
    switch (widget.quizType) {
      case QuizType.scientificToCommon:
      case QuizType.spriteToName:
      case QuizType.silhouetteToName:
        return organism.name;
      case QuizType.commonToScientific:
      case QuizType.spriteToScientific:
      case QuizType.silhouetteToScientific:
        return organism.scientificName;
    }
  }

  String _getQuestionText(Organism organism) {
    switch (widget.quizType) {
      case QuizType.scientificToCommon:
        return organism.scientificName;
      case QuizType.commonToScientific:
        return organism.name;
      case QuizType.spriteToName:
      case QuizType.spriteToScientific:
        return 'What animal is this? (Full Sprite)';
      case QuizType.silhouetteToName:
      case QuizType.silhouetteToScientific:
        return 'What animal is this? (Silhouette)';
    }
  }

  void _handleAnswer(String answer) async {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
    });

    final bool isCorrect = answer == _correctAnswer;

    // 🟢 FIX: Update quiz stats using the CURRENT local user data
    await widget.authService.updateQuizStats(
      _currentUser.username,
      widget.quizType.name,
      isCorrect,
    );

    // 🟢 CRITICAL FIX: Immediately refresh the local user data after updating
    final updatedUser = await widget.authService.getCurrentUser();
    if (updatedUser != null && mounted) {
      setState(() {
        _currentUser = updatedUser;
      });
    }

    Future.delayed(const Duration(seconds: _delayAfterAnswerSeconds), () {
      if (mounted) {
        _startNewQuestion();
      }
    });
  }

  bool get usesImageQuestion =>
      widget.quizType == QuizType.spriteToName ||
      widget.quizType == QuizType.spriteToScientific ||
      widget.quizType == QuizType.silhouetteToName ||
      widget.quizType == QuizType.silhouetteToScientific;

  Widget _buildAnswerButton(Organism option) {
    final answerText = _getAnswerText(option);

    bool isCorrect = _isAnswered && answerText == _correctAnswer;
    bool isWrong =
        _isAnswered &&
        answerText == _selectedAnswer &&
        answerText != _correctAnswer;

    Color borderColor = AppColors.highlightColor.withValues(alpha: 0.5);
    Color textColor = Colors.white;
    Color bgColor = Colors.black.withValues(alpha: 0.3);

    if (isCorrect) {
      borderColor = AppColors.correctGreen;
      textColor = AppColors.correctGreen;
      bgColor = AppColors.correctGreen.withValues(alpha: 0.1);
    } else if (isWrong) {
      borderColor = AppColors.wrongRed;
      textColor = AppColors.wrongRed;
      bgColor = AppColors.wrongRed.withValues(alpha: 0.1);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAnswered ? null : () => _handleAnswer(answerText),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              answerText.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontFamily: 'PressStart2P',
                fontSize: 10.sp,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionWidget() {
    final questionOrganism = _currentQuestion!;

    if (usesImageQuestion) {
      final bool isSilhouetteQuizType =
          widget.quizType == QuizType.silhouetteToName ||
          widget.quizType == QuizType.silhouetteToScientific;

      bool displaySilhouette = isSilhouetteQuizType;
      if (_isAnswered && _selectedAnswer == _correctAnswer) {
        displaySilhouette = false;
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _getQuestionText(questionOrganism),
              textAlign: TextAlign.center,
              style: AppTextStyles.small(context, color: Colors.grey[400]!),
            ),
          ),
          _QuizSpriteDisplay(
            organism: questionOrganism,
            height: 200,
            width: double.infinity,
            showSilhouette: displaySilhouette,
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.highlightColor, width: 2),
        ),
        child: Text(
          _getQuestionText(questionOrganism).toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.headline(context, baseSize: 12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.secondaryButtonColor,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.highlightColor),
        ),
      );
    }

    if (_currentQuestion == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QUIZ'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: AppTextStyles.headline(context, baseSize: 16),
        ),
        backgroundColor: AppColors.secondaryButtonColor,
        body: Center(
          child: Text(
            'NOT ENOUGH ANIMALS DISCOVERED.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              context,
              baseSize: 12,
              color: AppColors.wrongRed,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.quizType.displayName.toUpperCase()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headline(context, baseSize: 10),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/biomes/savanna-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.7),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Expanded(flex: 3, child: Center(child: _buildQuestionWidget())),

                Expanded(
                  flex: 4,
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: _currentOptions!
                        .map((org) => _buildAnswerButton(org))
                        .toList(),
                  ),
                ),

                if (_isAnswered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      _selectedAnswer == _correctAnswer
                          ? 'EXCELLENT! + XP'
                          : 'WRONG! THE ANSWER IS:\n$_correctAnswer'
                                .toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.small(
                        context,
                        color: _selectedAnswer == _correctAnswer
                            ? AppColors.correctGreen
                            : AppColors.wrongRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizSpriteDisplay extends StatefulWidget {
  final Organism organism;
  final double height;
  final double width;
  final bool showSilhouette;

  const _QuizSpriteDisplay({
    required this.organism,
    this.height = 250,
    this.width = 300,
    required this.showSilhouette,
  });

  @override
  __QuizSpriteDisplayState createState() => __QuizSpriteDisplayState();
}

class __QuizSpriteDisplayState extends State<_QuizSpriteDisplay> {
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
        .replaceAll('-', '_')
        .replaceAll("'", '_');
    return 'assets/sprites/$fileName.png';
  }

  @override
  void didUpdateWidget(covariant _QuizSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organism.name != widget.organism.name ||
        oldWidget.showSilhouette != widget.showSilhouette) {
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
          _imageSourceType = 'network';
          _imagePath = widget.organism.sprite;
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
    Widget imageWidget;

    if (widget.showSilhouette) {
      imageWidget = buildSilhouetteSprite(
        imageUrl: source,
        silhouetteColor: Colors.black,
        outlineColor: Colors.white,
        outlineWidth: 2.2,
        organismName: widget.organism.name,
        height: widget.height,
        width: widget.width,
        fit: BoxFit.contain,
      );
    } else {
      imageWidget = buildSilhouetteSprite(
        imageUrl: source,
        silhouetteColor: null, // Keep original Colors
        outlineColor: Colors.black,
        outlineWidth: 2.0,
        height: widget.height,
        width: widget.width,
        fit: BoxFit.contain,
      );
    }

    return Container(
      height: widget.height,
      width: widget.width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.highlightColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: imageWidget,
    );
  }
}
