import 'package:flutter/material.dart';
import 'package:animal_warfare/quiz_game_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/theme.dart';

class QuizScreen extends StatelessWidget {
  final UserData currentUser;
  final LocalAuthService authService;
  const QuizScreen({super.key, required this.currentUser,required this.authService,});

  Widget _buildQuizCard(BuildContext context, QuizType type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryButtonColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.highlightColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToQuizGame(context, type),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.highlightColor.withOpacity(0.4)),
                  ),
                  child: Icon(type.icon, color: AppColors.highlightColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayName.toUpperCase(),
                        style: AppTextStyles.headline(context, baseSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        type.description,
                        style: AppTextStyles.small(context, baseSize: 9, color: Colors.grey[400]!),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppColors.highlightColor, size: 16),
              ],
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
      backgroundColor: AppColors.secondaryButtonColor,
      appBar: AppBar(
        title: const Text('QUIZ LAB'),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        titleTextStyle: AppTextStyles.headline(context, baseSize: 16),
        centerTitle: true,
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
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
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
                    _buildQuizCard(context, QuizType.scientificToCommon),
                    _buildQuizCard(context, QuizType.commonToScientific),
                    _buildQuizCard(context, QuizType.spriteToName),
                    _buildQuizCard(context, QuizType.spriteToScientific),
                    _buildQuizCard(context, QuizType.silhouetteToName),
                    _buildQuizCard(context, QuizType.silhouetteToScientific),
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
