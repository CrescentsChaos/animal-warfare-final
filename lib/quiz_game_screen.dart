// lib/quiz_game_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/models/organism.dart';

enum QuizType {
  scientificToCommon,
  commonToScientific,
  spriteToName, 
  spriteToScientific,
  silhouetteToName, 
  silhouetteToScientific,
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

  static const Color primaryButtonColor = Color.fromARGB(0, 56, 118, 29);
  static const Color secondaryButtonColor = Color.fromARGB(0, 30, 63, 42);
  static const Color highlightColor = Color(0xFFDAA520);
  static const Color correctGlowColor = Color(0xFF00FF00);
  static const Color wrongGlowColor = Color(0xFFFF0000);
  
  static const int _numberOfOptions = 4;
  static const int _delayAfterAnswerSeconds = 3;

  @override
  void initState() {
    super.initState();
    // 🟢 NEW: Initialize local user data
    _currentUser = widget.currentUser;
    
    _loadOrganisms().then((_) {
      _startNewQuestion();
    });
  }

  double _responsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double referenceWidth = 400.0;
    final double scaleFactor = screenWidth / referenceWidth;
    return baseSize * scaleFactor;
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);
      
      _allOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
      setState(() { _isLoading = false; });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
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
    
    Color buttonColor = const Color.fromARGB(0, 30, 63, 42);
    Color borderColor = highlightColor;
    Color textColor = highlightColor;
    Color shadowColor = Colors.black;
    double borderWidth = 2.0;
    double elevation = 8;

    if (_isAnswered) {
      if (answerText == _correctAnswer) {
        borderColor = correctGlowColor;
        textColor = correctGlowColor;
        shadowColor = correctGlowColor;
        borderWidth = 3.0;
        elevation = 15;
      } else if (answerText == _selectedAnswer) {
        borderColor = wrongGlowColor;
        textColor = wrongGlowColor;
        shadowColor = wrongGlowColor;
        borderWidth = 3.0;
        elevation = 15;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: _isAnswered ? null : () => _handleAnswer(answerText),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
          elevation: elevation,
          shadowColor: shadowColor,
        ),
        child: Text(
          answerText.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontFamily: 'PressStart2P',
            fontSize: _responsiveFontSize(context, 12),
            shadows: [
              const Shadow(color: Colors.black, offset: Offset(1, 1))
            ]
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
          
      bool displaySilhouette = false;
      
      if (isSilhouetteQuizType) {
        displaySilhouette = true;
        if (_isAnswered && _selectedAnswer == _correctAnswer) {
            displaySilhouette = false;
        }
      } else {
        displaySilhouette = false;
      }
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Column(
          children: [
            Text(
              _getQuestionText(questionOrganism),
              textAlign: TextAlign.center,
              style: TextStyle( 
                color: highlightColor,
                fontFamily: 'PressStart2P',
                fontSize: _responsiveFontSize(context, 14), 
              ),
            ),
            const SizedBox(height: 10),
            _QuizSpriteDisplay(
              organism: questionOrganism,
              height: 250,
              width: 300,
              showSilhouette: displaySilhouette,
            ),
          ],
        )
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color.fromARGB(0, 30, 63, 42).withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlightColor, width: 3),
        ),
        child: Text(
          _getQuestionText(questionOrganism).toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: highlightColor,
            fontFamily: 'PressStart2P',
            fontSize: _responsiveFontSize(context, 16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color.fromARGB(0, 30, 63, 42),
        body: Center(
          child: CircularProgressIndicator(color: highlightColor),
        ),
      );
    }

    if (_currentQuestion == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz'), 
          backgroundColor: const Color.fromARGB(0, 30, 63, 42),
          titleTextStyle: TextStyle(
            color: highlightColor, 
            fontFamily: 'PressStart2P', 
            fontSize: _responsiveFontSize(context, 16),
          ),
        ),
        backgroundColor: const Color.fromARGB(0, 30, 63, 42),
        body: Center(
          child: Text('Not enough animals discovered for this quiz type.', 
            textAlign: TextAlign.center,
            style: TextStyle(
              color: wrongGlowColor, 
              fontFamily: 'PressStart2P', 
              fontSize: _responsiveFontSize(context, 14),
            )
          ),
        ),
      );
    }
    
    final usesImageQuestion = this.usesImageQuestion;
    final questionWidget = _buildQuestionWidget();
    
    final appBarTextStyle = TextStyle(
        color: highlightColor, 
        fontFamily: 'PressStart2P', 
        fontSize: _responsiveFontSize(context, 12)
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quizType.name.toUpperCase()}'),
        backgroundColor: const Color.fromARGB(0, 30, 63, 42),
        titleTextStyle: appBarTextStyle,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(0, 30, 63, 42),
          image: DecorationImage(
            image: const AssetImage('assets/biomes/savanna-bg.png'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  questionWidget,
                  
                  if (!usesImageQuestion)
                    const SizedBox(height: 40),

                  ..._currentOptions!.map((org) => _buildAnswerButton(org)).toList(),

                  const SizedBox(height: 40),

                  if (_isAnswered)
                    Text(
                      _selectedAnswer == _correctAnswer ? 'CORRECT! NEXT QUESTION LOADING...' : 'INCORRECT! ANSWER WAS: $_correctAnswer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _responsiveFontSize(context, 12),
                        color: _selectedAnswer == _correctAnswer ? correctGlowColor : wrongGlowColor,
                        fontFamily: 'PressStart2P',
                        shadows: [
                          const Shadow(color: Colors.black, offset: Offset(1, 1))
                        ]
                      ),
                    ),
                ],
              ),
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
    final fileName = widget.organism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", '_');
    return 'assets/sprites/$fileName.png';
  }
  
  @override
  void didUpdateWidget(covariant _QuizSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organism.name != widget.organism.name || oldWidget.showSilhouette != widget.showSilhouette) {
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
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    final String source = _imagePath;
    Widget imageWidget;
    
    if (widget.showSilhouette) {
      imageWidget = buildSilhouetteSprite( 
        imageUrl: source, 
        silhouetteColor: Colors.black,
        organismName: widget.organism.name,
        height: widget.height, 
        width: widget.width, 
        fit: BoxFit.contain,
      );
    } else {
      if (_imageSourceType == 'local') {
        imageWidget = Image.asset(
          source, 
          height: widget.height, 
          width: widget.width, 
          fit: BoxFit.contain,
        );
      } else {
        imageWidget = Image.network(
          source, 
          height: widget.height, 
          width: widget.width, 
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              height: widget.height,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          },
          errorBuilder: (context, error, stackTrace) => 
            const Icon(Icons.broken_image, color: Colors.red, size: 80),
        );
      }
    }
    
    return Container(
      height: widget.height,
      width: widget.width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color.fromARGB(78, 1, 6, 38).withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _QuizGameScreenState.highlightColor, 
          width: 4,
        ),
      ),
      padding: const EdgeInsets.all(5),
      child: imageWidget,
    );
  }
}