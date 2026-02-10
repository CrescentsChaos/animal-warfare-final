import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:animal_warfare/quiz_game_screen.dart'; // Ensure this path is correct
import 'package:animal_warfare/local_auth_service.dart';

class QuizScreen extends StatelessWidget {
  final UserData currentUser;
  final LocalAuthService authService;
  const QuizScreen({super.key, required this.currentUser,required this.authService,});

  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  static const Color backgroundColor = Color(0xFF13281A); // Very Dark Forest Green

  Widget _buildQuizCard(BuildContext context, QuizType type, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlightColor.withOpacity(0.3),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.1),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToQuizGame(context, type),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: highlightColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: highlightColor.withOpacity(0.5)),
                        ),
                        child: Icon(type.icon, color: highlightColor, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.displayName.toUpperCase(),
                              style: const TextStyle(
                                color: highlightColor,
                                fontFamily: 'PressStart2P',
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              type.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: highlightColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToQuizGame(BuildContext context, QuizType quizType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizGameScreen(
          quizType: quizType,
          currentUser: currentUser,
          authService: authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('QUIZ LAB'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: highlightColor, 
          fontFamily: 'PressStart2P', 
          fontSize: 18.0,
          letterSpacing: 2,
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: backgroundColor,
          image: DecorationImage(
            image: AssetImage('assets/biomes/savanna-bg.png'), 
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  'MASTER THE ECOSYSTEM',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontSize: 10,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildQuizCard(context, QuizType.scientificToCommon, const Color(0xFF38761D)),
                    _buildQuizCard(context, QuizType.commonToScientific, const Color(0xFF1E3F2A)),
                    _buildQuizCard(context, QuizType.spriteToName, const Color(0xFF13281A)),
                    _buildQuizCard(context, QuizType.spriteToScientific, const Color(0xFF674EA7)),
                    _buildQuizCard(context, QuizType.silhouetteToName, const Color(0xFF8E3E63)),
                    _buildQuizCard(context, QuizType.silhouetteToScientific, const Color(0xFF2C3E50)),
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
