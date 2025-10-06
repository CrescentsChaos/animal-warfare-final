import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/models/organism.dart'; // Import the Organism model

// Enum to define the two types of quizzes
enum QuizType {
  scientificToCommon,
  commonToScientific,
  // NEW: Sprite-based quizzes
  spriteToName, 
  spriteToScientific,
}

// Data structure for the animal facts (DELETED: Replaced by Organism)
// class AnimalFact { ... }

// Static database of animals (DELETED: Replaced by async loading)
// const List<AnimalFact> _animalDatabase = [ ... ];

class QuizGameScreen extends StatefulWidget {
  final QuizType quizType;

  const QuizGameScreen({super.key, required this.quizType});

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  final LocalAuthService _authService = LocalAuthService();

  // State variables for the quiz
  Organism? _currentQuestion;
  List<Organism>? _currentOptions;
  String? _selectedAnswer;
  String? _correctAnswer;
  bool _isAnswered = false;

  // State variables for data loading
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  // Custom retro/military colors
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  static const Color correctGlowColor = Color(0xFF00FF00); // Bright Green Glow
  static const Color wrongGlowColor = Color(0xFFFF0000); // Bright Red Glow

  @override
  void initState() {
    super.initState();
    _loadOrganismsAndGenerateQuestion();
  }

  // Function to load data from JSON asset
  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);

      // Map the List of JSON objects to a List of Organism objects
      final List<Organism> organisms = animalsData.map((json) => Organism.fromJson(json)).toList();

      // Ensure we have enough data for the quiz (at least 4 options)
      if (organisms.length < 4) {
          throw Exception("Not enough organisms in JSON file (need at least 4)");
      }
      
      // Filter out organisms that don't have a sprite for the new quiz types
      if (widget.quizType == QuizType.spriteToName || widget.quizType == QuizType.spriteToScientific) {
        _allOrganisms = organisms.where((org) => org.sprite.isNotEmpty).toList();
        if (_allOrganisms.length < 4) {
          throw Exception("Not enough organisms with sprites for this quiz type (need at least 4)");
        }
      } else {
        _allOrganisms = organisms;
      }

    } catch (e) {
      print('Error loading organisms for quiz: $e');
    }
  }

  // Combined loading and generation function
  Future<void> _loadOrganismsAndGenerateQuestion() async {
    await _loadOrganisms();
    
    // Only set loading to false and generate question if we have data
    if (_allOrganisms.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      _generateQuestion();
    } else {
      // Handle the case where loading failed or data is insufficient
      setState(() {
        _isLoading = false;
        _currentQuestion = null;
      });
    }
  }


  // Generates a new question and three random incorrect options
  void _generateQuestion() {
    // Only proceed if we have loaded data and have enough options
    if (_allOrganisms.length < 4) return;

    setState(() {
      _isAnswered = false;
      _selectedAnswer = null;
      _correctAnswer = null;

      final random = Random();
      // 1. Pick the correct answer from the loaded list
      final correctOrganism = _allOrganisms[random.nextInt(_allOrganisms.length)];
      _currentQuestion = correctOrganism;

      // 2. Determine the correct answer string based on quiz type
      switch (widget.quizType) {
        case QuizType.scientificToCommon:
        case QuizType.spriteToName:
          _correctAnswer = correctOrganism.name; // Common name
          break;
        case QuizType.commonToScientific:
        case QuizType.spriteToScientific:
          _correctAnswer = correctOrganism.scientificName; // Scientific name
          break;
      }

      // 3. Select 3 random unique incorrect options
      final availableOrganisms = _allOrganisms.where((org) => org != correctOrganism).toList();
      availableOrganisms.shuffle(random);

      final incorrectOrganisms = availableOrganisms.take(3).toList();

      // 4. Combine and shuffle options
      final List<Organism> allOptions = [correctOrganism, ...incorrectOrganisms];
      allOptions.shuffle(random);

      _currentOptions = allOptions;
    });
  }

  // Handles the user's answer submission
  void _handleAnswer(String selectedOption) async {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = selectedOption;
      _isAnswered = true;
    });

    final bool isCorrect = selectedOption == _correctAnswer;
    
    String quizName;
    switch (widget.quizType) {
      case QuizType.scientificToCommon:
        quizName = 'Scientific to Common';
        break;
      case QuizType.commonToScientific:
        quizName = 'Common to Scientific';
        break;
      case QuizType.spriteToName:
        quizName = 'Sprite to Name';
        break;
      case QuizType.spriteToScientific:
        quizName = 'Sprite to Scientific';
        break;
    }

    // Save the attempt data
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      await _authService.updateQuizStats(currentUser.username, quizName, isCorrect);
    }

    // Delay before moving to the next question
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _generateQuestion();
      }
    });
  }

  // Determines the background color for the button
  Color _getButtonColor(String option) {
    if (!_isAnswered) {
      return primaryButtonColor;
    }

    // If answered, check for glow effects
    if (option == _correctAnswer) {
      return correctGlowColor; // Correct button glows green
    }

    if (option == _selectedAnswer) {
      return wrongGlowColor; // Selected WRONG button glows red
    }

    return primaryButtonColor; // Default color for unselected wrong options
  }

  // Determines the shadow/glow for the button
  BoxShadow _getButtonShadow(String option) {
    Color shadowColor = Colors.black.withOpacity(0.6);
    double blurRadius = 0;

    if (_isAnswered) {
      if (option == _correctAnswer) {
        shadowColor = correctGlowColor.withOpacity(0.8);
        blurRadius = 8.0;
      } else if (option == _selectedAnswer) {
        shadowColor = wrongGlowColor.withOpacity(0.8);
        blurRadius = 8.0;
      }
    }

    return BoxShadow(
      color: shadowColor,
      offset: const Offset(4, 4),
      blurRadius: blurRadius,
      spreadRadius: 0,
    );
  }

  // Helper method to extract the display text for an option
  String _getOptionText(Organism fact) {
    // Options are always either Common Name or Scientific Name
    return widget.quizType == QuizType.scientificToCommon || widget.quizType == QuizType.spriteToName
        ? fact.name 
        : fact.scientificName;
  }

  // Helper method to get the main question text
  // Only returns the text for text-based quizzes
  String _getQuestionText() {
    if (_currentQuestion == null) return "Error Loading Question...";

    switch (widget.quizType) {
      case QuizType.scientificToCommon:
        return _currentQuestion!.scientificName;
      case QuizType.commonToScientific:
        return _currentQuestion!.name;
      case QuizType.spriteToName:
      case QuizType.spriteToScientific:
        // Return the sprite URL so it can be used by the sprite builder
        return _currentQuestion!.sprite;
    }
  }
  
  // NEW: Widget to display the sprite question
  Widget _buildSpriteQuestion(String spriteUrl) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        border: Border.all(color: highlightColor, width: 3.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Text(
            'IDENTIFY THIS UNIT:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: highlightColor,
              fontSize: 12,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(height: 16),
          // Display the sprite image
          // Using Image.network assuming the sprite is a URL
          Image.network(
            spriteUrl,
            height: 150, // Fixed height for visual consistency
            width: 200,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator(color: highlightColor));
            },
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 80),
          ),
        ],
      ),
    );
  }


  // The main button widget for the answers
  Widget _buildAnswerButton(Organism fact) {
    final optionText = _getOptionText(fact);
    final buttonColor = _getButtonColor(optionText);
    final buttonShadow = _getButtonShadow(optionText);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: buttonColor,
        border: Border.all(color: highlightColor, width: 2.0),
        borderRadius: BorderRadius.circular(4.0),
        boxShadow: [
          buttonShadow,
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAnswered ? null : () => _handleAnswer(optionText),
          borderRadius: BorderRadius.circular(4.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                optionText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  // Change text color to black for better contrast on bright green glow
                  color: optionText == _correctAnswer && _isAnswered ? Colors.black : Colors.white,
                  fontSize: 16,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    String title;
    switch (widget.quizType) {
      case QuizType.scientificToCommon:
        title = 'Scientific to Common';
        break;
      case QuizType.commonToScientific:
        title = 'Common to Scientific';
        break;
      case QuizType.spriteToName:
        title = 'Sprite to Name';
        break;
      case QuizType.spriteToScientific:
        title = 'Sprite to Scientific';
        break;
    }


    // Handle the loading state before attempting to display the quiz
    if (_isLoading || _currentQuestion == null || _currentOptions == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: Colors.green[900]),
        body: Center(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                const CircularProgressIndicator(color: highlightColor),
                const SizedBox(height: 20),
                Text(
                  _isLoading ? "LOADING ORGANISMS..." : "PREPARING QUIZ...",
                  style: const TextStyle(color: highlightColor, fontFamily: 'PressStart2P'),
                ),
                if (!_isLoading && _allOrganisms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "ERROR: FAILED TO LOAD DATA OR INSUFFICIENT DATA.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: wrongGlowColor, fontFamily: 'PressStart2P', fontSize: 10),
                    ),
                  )
            ],
          ),
        ),
      );
    }
    
    // Determine the question widget based on quiz type
    final isSpriteQuiz = widget.quizType == QuizType.spriteToName || widget.quizType == QuizType.spriteToScientific;
    final questionWidget = isSpriteQuiz
        ? _buildSpriteQuestion(_currentQuestion!.sprite)
        : Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              border: Border.all(color: highlightColor, width: 3.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              children: [
                Text(
                  'WHICH ANIMAL IS THIS?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: highlightColor,
                    fontSize: 12,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getQuestionText(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ],
            ),
          );


    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green[900],
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/main.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Quiz Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question Box (Sprite or Text)
                  questionWidget,
                  
                  // Add spacing only if it's a text-based quiz, as sprite quiz adds margin
                  if (!isSpriteQuiz)
                    const SizedBox(height: 40),

                  // Answer Options
                  // Use the Organism list for options
                  ..._currentOptions!.map((org) => _buildAnswerButton(org)).toList(),

                  const SizedBox(height: 40),

                  // Status Message
                  if (_isAnswered)
                    Text(
                      _selectedAnswer == _correctAnswer ? 'CORRECT! NEXT QUESTION LOADING...' : 'INCORRECT! ANSWER WAS: $_correctAnswer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedAnswer == _correctAnswer ? correctGlowColor : wrongGlowColor,
                        fontFamily: 'PressStart2P',
                        shadows: [
                          Shadow(color: Colors.black, offset: const Offset(1, 1))
                        ]
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}