import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/quiz_game_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/theme.dart';

class QuizScreen extends StatelessWidget {
  final UserData currentUser;
  final LocalAuthService authService;
  const QuizScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  Widget _buildQuizCard(
    BuildContext context,
    QuizType type,
    UserData activeUser,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.highlightColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToQuizGame(context, type, activeUser),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.highlightColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    type.icon,
                    color: AppColors.highlightColor,
                    size: 24,
                  ),
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
                        style: AppTextStyles.small(
                          context,
                          baseSize: 9,
                          color: Colors.grey[400]!,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatsRow(context, type, activeUser),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.highlightColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    QuizType type,
    UserData activeUser,
  ) {
    final stats = activeUser.quizStats[type.name] as Map<String, dynamic>?;
    final attempts = stats?['attempts'] as int? ?? 0;
    final correct = stats?['correct'] as int? ?? 0;
    final accuracy = attempts > 0
        ? (correct / attempts * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatText(label: 'ATTEMPTS', value: '$attempts'),
          _StatText(
            label: 'CORRECT',
            value: '$correct',
            color: AppColors.correctGreen,
          ),
          _StatText(
            label: 'ACCURACY',
            value: '$accuracy%',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  void _navigateToQuizGame(
    BuildContext context,
    QuizType quizType,
    UserData activeUser,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizGameScreen(
          quizType: quizType,
          currentUser: activeUser,
          authService: authService,
        ),
      ),
    );
    if (context.mounted) {
      Provider.of<UserState>(context, listen: false).loadCurrentUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    final activeUser = userState.currentUser ?? currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('QUIZ LAB'),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
        titleTextStyle: AppTextStyles.headline(context, baseSize: 16),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          image: DecorationImage(
            image: const AssetImage('assets/biomes/savanna-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildQuizCard(
                      context,
                      QuizType.scientificToCommon,
                      activeUser,
                    ),
                    _buildQuizCard(
                      context,
                      QuizType.commonToScientific,
                      activeUser,
                    ),
                    _buildQuizCard(context, QuizType.spriteToName, activeUser),
                    _buildQuizCard(
                      context,
                      QuizType.spriteToScientific,
                      activeUser,
                    ),
                    _buildQuizCard(
                      context,
                      QuizType.silhouetteToName,
                      activeUser,
                    ),
                    _buildQuizCard(
                      context,
                      QuizType.silhouetteToScientific,
                      activeUser,
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

class _StatText extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatText({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 7,
            fontFamily: 'PressStart2P',
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 9,
            fontFamily: 'PressStart2P',
          ),
        ),
      ],
    );
  }
}
