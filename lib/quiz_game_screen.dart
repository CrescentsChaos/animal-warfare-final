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

class QuizGameScreen extends StatefulWidget {
  final QuizType quizType;
  // FIX: Added currentUser and authService to match other screens
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
  // State variables for the quiz
  Organism? _currentQuestion;
  List<Organism>? _currentOptions;
  String? _selectedAnswer;
  String? _correctAnswer;
  bool _isAnswered = false;

  // State variables for data
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  // Constants
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  static const Color correctGlowColor = Color(0xFF00FF00); // Bright Green
  static const Color wrongGlowColor = Color(0xFFFF0000); // Bright Red
  
  // Quiz parameters
  static const int _numberOfOptions = 4;
  static const int _delayAfterAnswerSeconds = 3;

  @override
  void initState() {
    super.initState();
    _loadOrganisms().then((_) {
      _startNewQuestion();
    });
  }

  // ADDED: Utility function for responsive font size
  double _responsiveFontSize(BuildContext context, double baseSize) {
    // Get the screen width
    final screenWidth = MediaQuery.of(context).size.width;
    // Define a reference width (e.g., 400 pixels for a typical phone)
    const double referenceWidth = 400.0;
    // Calculate a scaling factor
    final double scaleFactor = screenWidth / referenceWidth;
    // Apply the scaling factor to the base size
    return baseSize * scaleFactor;
  }
  // END ADDED

  // --- Data Loading and Setup ---
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

  // --- Quiz Logic ---
  void _startNewQuestion() {
    if (_allOrganisms.isEmpty) return;

    // FIX: Use widget.currentUser to access discovered organisms
    final discoveredAnimals = _allOrganisms.where(
        // Line 83: Fixed error by using widget.currentUser
        (org) => widget.currentUser.discoveredOrganisms.contains(org.name) 
    ).toList();
    
    // Fallback: If no animals are discovered, use all animals for the quiz
    final List<Organism> quizSource = discoveredAnimals.isNotEmpty ? discoveredAnimals : _allOrganisms;

    if (quizSource.length < _numberOfOptions) {
      // Not enough animals to create a quiz with 4 options
      setState(() {
        _isLoading = false;
        _currentQuestion = null;
      });
      return;
    }

    // 1. Select the question (correct answer)
    final random = Random();
    final questionIndex = random.nextInt(quizSource.length);
    _currentQuestion = quizSource[questionIndex];

    // 2. Select the decoy options
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

    // 3. Determine correct answer string and shuffle options
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
        return organism.name;
      case QuizType.commonToScientific:
      case QuizType.spriteToScientific:
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
        return 'What is this animal?'; // Question is implied by the sprite
    }
  }

  void _handleAnswer(String answer) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
    });

    // START: Update Quiz Stats
    final bool isCorrect = answer == _correctAnswer;
    
    // FIX: Changed the first positional argument from UserData to String userId.
    widget.authService.updateQuizStats(
      widget.currentUser.username, // Positional arg 1: String userId (FIXED)
      widget.quizType.name,  // Positional arg 2: String quizName
      isCorrect,             // Positional arg 3: bool isCorrect
    );
    // END: Update Quiz Stats

    Future.delayed(const Duration(seconds: _delayAfterAnswerSeconds), () {
      if (mounted) {
        _startNewQuestion();
      }
    });
  }

  // --- UI Builders ---

  // Helper to determine if the quiz uses a sprite image
  bool get isSpriteQuiz => 
      widget.quizType == QuizType.spriteToName || 
      widget.quizType == QuizType.spriteToScientific;

  Widget _buildAnswerButton(Organism option) {
    final answerText = _getAnswerText(option);
    
    Color buttonColor = secondaryButtonColor;
    Color borderColor = highlightColor;
    Color textColor = highlightColor;

    if (_isAnswered) {
      if (answerText == _correctAnswer) {
        buttonColor = correctGlowColor.withOpacity(0.3);
        borderColor = correctGlowColor;
        textColor = correctGlowColor;
      } else if (answerText == _selectedAnswer) {
        buttonColor = wrongGlowColor.withOpacity(0.3);
        borderColor = wrongGlowColor;
        textColor = wrongGlowColor;
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
            side: BorderSide(color: borderColor, width: 2.0),
          ),
          elevation: 8,
          shadowColor: borderColor,
        ),
        child: Text(
          answerText.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontFamily: 'PressStart2P',
            fontSize: _responsiveFontSize(context, 12), // Responsive font size
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
    
    if (isSpriteQuiz) {
      // Use the new _QuizSpriteDisplay to handle local/network loading
      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: _QuizSpriteDisplay(
          organism: questionOrganism,
          height: 250,
          width: 300,
          // Only show the silhouette if the answer is incorrect
          showSilhouette: _isAnswered && _selectedAnswer != _correctAnswer,
        ),
      );
    } else {
      // Text-based question
      return Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: secondaryButtonColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlightColor, width: 3),
        ),
        child: Text(
          _getQuestionText(questionOrganism).toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle( // MODIFIED: Use TextStyle instead of const TextStyle
            color: highlightColor,
            fontFamily: 'PressStart2P',
            fontSize: _responsiveFontSize(context, 16), // MODIFIED: Responsive font size
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: secondaryButtonColor,
        body: Center(
          child: CircularProgressIndicator(color: highlightColor),
        ),
      );
    }

    if (_currentQuestion == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Game'), 
          backgroundColor: secondaryButtonColor,
          titleTextStyle: TextStyle(
            color: highlightColor, 
            fontFamily: 'PressStart2P', 
            fontSize: _responsiveFontSize(context, 16), // MODIFIED: Responsive font size
          ),
        ),
        backgroundColor: secondaryButtonColor,
        body: Center(
          child: Text('Not enough animals discovered for this quiz type.', 
            textAlign: TextAlign.center,
            style: TextStyle(
              color: wrongGlowColor, 
              fontFamily: 'PressStart2P', 
              fontSize: _responsiveFontSize(context, 14), // MODIFIED: Responsive font size
            )
          ),
        ),
      );
    }
    
    final isSpriteQuiz = this.isSpriteQuiz;
    final questionWidget = _buildQuestionWidget();
    
    // MODIFIED: Added for the AppBar title
    final appBarTextStyle = TextStyle(
        color: highlightColor, 
        fontFamily: 'PressStart2P', 
        fontSize: _responsiveFontSize(context, 16)
    );
    // END MODIFIED

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quizType.name.toUpperCase()} Quiz'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: appBarTextStyle, // MODIFIED: Use responsive style
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'), 
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
                        fontSize: _responsiveFontSize(context, 12), // MODIFIED: Responsive font size
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

// ----------------------------------------------------------------------
// NEW WIDGET: _QuizSpriteDisplay
// Handles the local asset check and network fallback for the Quiz screen.
// ----------------------------------------------------------------------
class _QuizSpriteDisplay extends StatefulWidget {
  final Organism organism;
  final double height;
  final double width;
  final bool showSilhouette; // NEW property to decide if silhouette or color image is shown

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
  // null initially, 'local' if found, 'network' if not found locally
  String? _imageSourceType;
  
  // The determined path/url to use
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
  }
  
  // Helper to construct the local path
  String _getLocalPath() {
    // Organism name logic: lowercase and replace spaces with underscores.
    final fileName = widget.organism.name.toLowerCase().replaceAll(' ', '_');
    return 'assets/sprites/$fileName.png';
  }
  
  @override
  void didUpdateWidget(covariant _QuizSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-determine source if the organism or question state changes
    if (oldWidget.organism.name != widget.organism.name || oldWidget.showSilhouette != widget.showSilhouette) {
      _imageSourceType = null;
      _determineImageSource();
    }
  }

  Future<void> _determineImageSource() async {
    final localPath = _getLocalPath();
    
    // 1. Try to load the local asset
    try {
      // Use rootBundle.load to check for existence without rendering
      await rootBundle.load(localPath);
      // If load succeeds, the asset exists
      if (mounted) {
        setState(() {
          _imageSourceType = 'local';
          _imagePath = localPath;
        });
      }
    } catch (e) {
      // 2. If load fails (asset not found), fallback to network
      if (mounted) {
        setState(() {
          _imageSourceType = 'network';
          _imagePath = widget.organism.sprite; // Network URL
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSourceType == null) {
      // Show a simple loading indicator while determining the source
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    final String source = _imagePath;

    if (widget.showSilhouette) {
      // Show Silhouette (e.g., when the answer is wrong)
      // Assuming buildSilhouetteSprite is globally available via organism.dart import
      return buildSilhouetteSprite( 
        imageUrl: source, 
        silhouetteColor: Colors.black, // Dark silhouette for quiz
        organismName: widget.organism.name,
        height: widget.height, 
        width: widget.width, 
        fit: BoxFit.contain,
      );
    } else {
      // Show the actual image (colored image)
      if (_imageSourceType == 'local') {
        return Image.asset(
          source, 
          height: widget.height, 
          width: widget.width, 
          fit: BoxFit.contain,
        );
      } else {
        // Network Image (Fallback)
        return Image.network(
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
            // Fallback for network error (if sprite is missing entirely)
            const Icon(Icons.broken_image, color: Colors.red, size: 80),
        );
      }
    }
  }
}