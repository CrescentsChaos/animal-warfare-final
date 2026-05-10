import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/quiz_game_screen.dart';
import 'package:animal_warfare/stat_showdown_screen.dart';
import 'package:animal_warfare/habitat_sort_screen.dart';
import 'package:animal_warfare/silhouette_sprint_screen.dart';
import 'package:animal_warfare/echo_memory_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/theme.dart';

class QuizScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;
  const QuizScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  QuizDifficulty _selectedDifficulty = QuizDifficulty.normal;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildQuizCard(
    BuildContext context,
    QuizType type,
    UserData activeUser,
  ) {
    // Difficulty-specific stats
    final modeStats = activeUser.quizStats[type.name] as Map<String, dynamic>?;
    final diffStats = modeStats?[_selectedDifficulty.name] as Map<String, dynamic>?;
    
    // Fallback to top-level if no difficulty-specific stats yet (for migration)
    final attempts = diffStats?['attempts'] as int? ?? (modeStats?.containsKey('attempts') == true ? modeStats!['attempts'] : 0);
    final correct = diffStats?['correct'] as int? ?? (modeStats?.containsKey('correct') == true ? modeStats!['correct'] : 0);
    final bestStreak = diffStats?['bestStreak'] as int? ?? 0;
    final totalPoints = diffStats?['totalPoints'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlightColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToQuizGame(context, type, activeUser),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.highlightColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        type.icon,
                        color: AppColors.highlightColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.displayName.toUpperCase(),
                            style: AppTextStyles.headline(context, baseSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white24, size: 20),
                      onPressed: () => _showRules(
                        context, 
                        type.displayName.toUpperCase(), 
                        'Difficulty: ${_selectedDifficulty.name}\n\nEASY: 15s timer, 3 options\nNORMAL: 10s timer, 4 options\nHARD: 7s timer, 6 options\n\nREWARDS:\nCorrect: +10 EXP, +Pts (based on time)\nStreak (x5): +50 Bonus EXP',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatsRow(context, attempts, correct, bestStreak, totalPoints),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    int attempts,
    int correct,
    int streak,
    int points,
  ) {
    final accuracy = attempts > 0
        ? (correct / attempts * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatText(label: 'ACCURACY', value: '$accuracy%', color: AppColors.primary),
          _StatText(label: 'BEST STREAK', value: '$streak', color: AppColors.correctGreen),
          _StatText(label: 'TOTAL PTS', value: '$points', color: AppColors.statAttackColor),
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
          difficulty: _selectedDifficulty,
          currentUser: activeUser,
          authService: widget.authService,
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
    final activeUser = userState.currentUser ?? widget.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('MINIGAMES HUB'),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
        titleTextStyle: AppTextStyles.headline(context, baseSize: 14),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white38,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 8),
          tabs: const [
            Tab(text: 'ARCADE', icon: Icon(Icons.videogame_asset_outlined)),
            Tab(text: 'QUIZZES', icon: Icon(Icons.quiz_outlined)),
            Tab(text: 'TROPHIES', icon: Icon(Icons.emoji_events_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArcadeTab(context, activeUser),
          _buildQuizTab(context, activeUser),
          _buildAchievementTab(context, activeUser),
        ],
      ),
    );
  }

  Widget _buildArcadeTab(BuildContext context, UserData activeUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAccountProgress(context, activeUser),
          _buildSectionHeader('ARCADE MODES'),
          _buildStatShowdownCard(context, activeUser),
          const SizedBox(height: 16),
          _buildArcadeCard(
            context,
            'HABITAT SORT',
            'Categorize wildlife by biome',
            AppColors.habitatGreen,
            Icons.landscape,
            activeUser,
            'habitatSort',
            () => Navigator.push(context, MaterialPageRoute(builder: (c) => HabitatSortScreen(currentUser: activeUser, authService: widget.authService))),
          ),
          const SizedBox(height: 16),
          _buildArcadeCard(
            context,
            'SILHOUETTE SPRINT',
            'Identify species by shadow',
            AppColors.highlightColor,
            Icons.speed,
            activeUser,
            'silhouetteSprint',
            () => Navigator.push(context, MaterialPageRoute(builder: (c) => SilhouetteSprintScreen(currentUser: activeUser, authService: widget.authService))),
          ),
          const SizedBox(height: 16),
          _buildArcadeCard(
            context,
            'THE ECHO',
            'Memory sequence challenge',
            AppColors.statDefenseColor,
            Icons.psychology,
            activeUser,
            'echoMemory',
            () => Navigator.push(context, MaterialPageRoute(builder: (c) => EchoMemoryScreen(currentUser: activeUser, authService: widget.authService))),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizTab(BuildContext context, UserData activeUser) {
    return Column(
      children: [
        _buildDifficultySelector(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: QuizType.values.length,
            itemBuilder: (context, index) {
              return _buildQuizCard(context, QuizType.values[index], activeUser);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Text('DIFFICULTY:', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8, color: Colors.white54)),
          const Spacer(),
          ...QuizDifficulty.values.map((d) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(d.name, style: TextStyle(fontFamily: 'PressStart2P', fontSize: 7, color: _selectedDifficulty == d ? Colors.black : Colors.white)),
              selected: _selectedDifficulty == d,
              selectedColor: d == QuizDifficulty.hard ? AppColors.wrongRed : (d == QuizDifficulty.normal ? AppColors.primary : AppColors.correctGreen),
              backgroundColor: Colors.white10,
              onSelected: (selected) {
                if (selected) setState(() => _selectedDifficulty = d);
              },
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildAchievementTab(BuildContext context, UserData activeUser) {
    return AchievementsScreen(
      currentUser: activeUser,
      allOrganisms: LocalAuthService.getCachedOrganisms().map((o) => o.toJson()).toList(),
      authService: widget.authService,
    );
  }

  Widget _buildStatShowdownCard(BuildContext context, UserData activeUser) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statAttackColor, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StatShowdownScreen(
                  currentUser: activeUser,
                  authService: widget.authService,
                ),
              ),
            );
            if (context.mounted) {
              Provider.of<UserState>(context, listen: false).loadCurrentUser();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, color: AppColors.statAttackColor, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'STAT SHOWDOWN',
                      style: AppTextStyles.headline(context, baseSize: 14).copyWith(color: AppColors.statAttackColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Higher or Lower Survival Mode',
                  style: AppTextStyles.small(context, baseSize: 10, color: Colors.grey[300]!),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, color: AppColors.highlightColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'BEST: ${(activeUser.quizStats['statShowdown']?['correct'] as int?) ?? 0}',
                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9, color: AppColors.highlightColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.info_outline, color: Colors.white30, size: 20),
                      onPressed: () => _showRules(
                        context, 
                        'STAT SHOWDOWN', 
                        'Compare stats between two animals. Guess if the hidden stat of the second animal is Higher or Lower than the first. Streak adds a multiplier to your rewards!\n\nREWARDS:\n+50 EXP base\n+10 EXP per streak point',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountProgress(BuildContext context, UserData user) {
    double progress = user.accountXP / user.xpToNextLevel;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCOUNT LEVEL', style: TextStyle(color: Colors.white54, fontSize: 8, fontFamily: 'PressStart2P')),
                  const SizedBox(height: 8),
                  Text('LV. ${user.accountLevel}', style: TextStyle(color: AppColors.primary, fontSize: 18, fontFamily: 'PressStart2P')),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('RANK', style: TextStyle(color: Colors.white54, fontSize: 8, fontFamily: 'PressStart2P')),
                  const SizedBox(height: 8),
                  Text(user.rankName, style: TextStyle(color: user.rankColor, fontSize: 12, fontFamily: 'PressStart2P')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EXP', style: TextStyle(color: Colors.white30, fontSize: 7, fontFamily: 'PressStart2P')),
              Text('${user.accountXP} / ${user.xpToNextLevel}', style: TextStyle(color: Colors.white30, fontSize: 7, fontFamily: 'PressStart2P')),
            ],
          ),
        ],
      ),
    );
  }

  void _showRules(BuildContext context, String title, String rules) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: AppColors.primary)),
        content: Text(rules, style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('GOT IT', style: TextStyle(color: AppColors.highlightColor, fontFamily: 'PressStart2P', fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArcadeCard(
    BuildContext context,
    String title,
    String subtitle,
    Color accentColor,
    IconData icon,
    UserData activeUser,
    String statsKey,
    VoidCallback onTap,
  ) {
    final stats = activeUser.quizStats[statsKey] ?? {'correct': 0};
    final best = stats['correct'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BEST: $best',
                          style: TextStyle(
                            color: accentColor,
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.info_outline, color: Colors.white24, size: 20),
                      onPressed: () {
                        String rules = '';
                        if (title == 'HABITAT SORT') {
                          rules = 'Drag the animal to its correct biome (Ocean, Forest, etc.) at the bottom of the screen. You have 60 seconds!\n\nREWARDS:\nCorrect: +10 Pts, +5 EXP\nWrong: -5 Pts';
                        } else if (title == 'SILHOUETTE SPRINT') {
                          rules = 'Identify as many animal silhouettes as you can. Every correct answer adds time to the clock!\n\nREWARDS:\nCorrect: +2s, +10 Pts, +5 EXP\nWrong: -3s, -5 Pts';
                        } else if (title == 'THE ECHO') {
                          rules = 'A pattern of animal elements will flash on screen. Repeat the exact sequence to move to the next wave.\n\nREWARDS:\nWave Clear: +50 EXP, +100 Pts';
                        }
                        _showRules(context, title, rules);
                      },
                    ),
                    Icon(Icons.chevron_right, color: Colors.white24),
                  ],
                ),
              ],
            ),
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
