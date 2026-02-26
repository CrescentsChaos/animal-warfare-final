// lib/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/edit_profile_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/settings_screen.dart';
import 'package:animal_warfare/achievement_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalAuthService _authService = LocalAuthService();
  UserData? _currentUser;
  bool _isLoading = true;
  List<dynamic> _allOrganisms = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadOrganisms();
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      if (mounted) {
        setState(() {
          _allOrganisms = json.decode(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading Organisms.json: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    UserData? user = await _authService.getCurrentUser();
    if (user != null && user.avatar.isNotEmpty && user.avatar != 'default') {
      File avatarFile = File(user.avatar);
      if (!(await avatarFile.exists())) {
        user = user.copyWith(avatar: 'default');
      }
    }
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  void _navigateToEditScreen() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        )
        .then((_) => _loadUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.highlightColor),
        ),
      );
    }

    final user = _currentUser!;
    final totalCount = _allOrganisms.length;
    final discoveredCount = user.discoveredOrganisms.length;

    return Scaffold(
      backgroundColor: AppColors.secondaryButtonColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(user),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatRow(user, discoveredCount, totalCount),
                  SizedBox(height: 32.h),
                  _buildSectionHeader('ACCOUNT PROGRESS'),
                  SizedBox(height: 16.h),
                  _buildProgressCard(user),
                  SizedBox(height: 32.h),
                  _buildSectionHeader('UTILITIES'),
                  SizedBox(height: 16.h),
                  _buildUtilityGrid(),
                  if (user.bestRogueFloor > 0) ...[
                    SizedBox(height: 32.h),
                    _buildSectionHeader('ROGUE RECORDS'),
                    SizedBox(height: 16.h),
                    _buildRogueCard(user),
                  ],
                  SizedBox(height: 32.h),
                  _buildSectionHeader('BATTLE QUIZ ANALYTICS'),
                  SizedBox(height: 16.h),
                  _buildQuizStats(user),
                  SizedBox(height: 60.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(UserData user) {
    return SliverAppBar(
      expandedHeight: 280.h,
      pinned: true,
      backgroundColor: AppColors.secondaryButtonColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/main.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.75),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40.h),
                _buildAvatar(user),
                SizedBox(height: 16.h),
                Text(
                  user.username.toUpperCase(),
                  style: AppTextStyles.headline(
                    context,
                    baseSize: 14,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: user.rankColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: user.rankColor, width: 1),
                  ),
                  child: Text(
                    user.rankName.toUpperCase(),
                    style: TextStyle(
                      color: user.rankColor,
                      fontFamily: 'PressStart2P',
                      fontSize: 7.sp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  SettingsScreen(currentUser: user, authService: _authService),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(UserData user) {
    return Container(
      width: 100.w,
      height: 100.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.highlightColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.highlightColor.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
        image: user.avatar.isNotEmpty && user.avatar != 'default'
            ? DecorationImage(
                image: FileImage(File(user.avatar)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: user.avatar == 'default'
          ? Icon(Icons.person, size: 50.w, color: AppColors.highlightColor)
          : null,
    );
  }

  Widget _buildStatRow(UserData user, int discovered, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMiniStat(
          'GOLD',
          '${user.money}',
          Icons.monetization_on,
          Colors.amber,
        ),
        _buildMiniStat(
          'LEVEL',
          '${user.accountLevel}',
          Icons.trending_up,
          Colors.blueAccent,
        ),
        _buildMiniStat(
          'IDEX',
          '$discovered/$total',
          Icons.pets,
          const Color(0xFF2ECC71),
        ),
      ],
    );
  }

  Widget _buildMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 100.w,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20.w),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppTextStyles.headline(
              context,
              baseSize: 10,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(color: Colors.white38, fontSize: 8.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4.w, height: 16.h, color: AppColors.highlightColor),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10.sp,
            color: AppColors.highlightColor,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(UserData user) {
    final currentLevelXP = user.accountLevel * user.accountLevel * 100;
    final nextLevelXP = (user.accountLevel + 1) * (user.accountLevel + 1) * 100;
    final progress =
        ((user.accountXP - currentLevelXP) / (nextLevelXP - currentLevelXP))
            .clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP PROGRESS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.highlightColor,
                  fontSize: 9.sp,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12.h,
              backgroundColor: Colors.white.withOpacity(0.05),
              color: AppColors.highlightColor,
            ),
          ),
          SizedBox(height: 12.h),
          Center(
            child: Text(
              '${user.accountXP} / $nextLevelXP XP',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10.sp,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.w,
      crossAxisSpacing: 12.w,
      childAspectRatio: 2.5,
      children: [
        _buildIconButton('EDIT PROFILE', Icons.edit, _navigateToEditScreen),
        _buildIconButton(
          'ACHIEVES',
          Icons.emoji_events,
          _navigateToAchievementsScreen,
        ),
      ],
    );
  }

  Widget _buildIconButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.highlightColor, size: 18.w),
            SizedBox(width: 12.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 7.sp,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRogueCard(UserData user) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.black.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildDataRow('MAX FLOOR', '${user.bestRogueFloor}', highlight: true),
          SizedBox(height: 16.h),
          SizedBox(
            height: 40.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: user.bestRogueTeam.map((animal) {
                final fileName = animal.name
                    .toLowerCase()
                    .replaceAll(' ', '_')
                    .replaceAll("'", '_')
                    .replaceAll('-', '_');
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Image.asset(
                    'assets/sprites/$fileName.png',
                    width: 32.h,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.pets, color: Colors.white24),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStats(UserData user) {
    if (user.quizStats.isEmpty) {
      return Center(
        child: Text(
          'NO COMBAT ANALYTICS AVAILABLE',
          style: TextStyle(
            color: Colors.white24,
            fontSize: 8.sp,
            fontFamily: 'PressStart2P',
          ),
        ),
      );
    }
    return Column(
      children: user.quizStats.entries.map((entry) {
        final attempts = entry.value['attempts'] as int? ?? 0;
        final correct = entry.value['correct'] as int? ?? 0;
        final accuracy = attempts > 0 ? (correct / attempts) : 0.0;
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  color: AppColors.highlightColor,
                  fontSize: 9.sp,
                  fontFamily: 'PressStart2P',
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatPill(
                    'ACC:',
                    '${(accuracy * 100).toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                  _buildStatPill('TRIAL:', '$attempts', Colors.orange),
                  _buildStatPill('WIN:', '$correct', const Color(0xFF2ECC71)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white38, fontSize: 8.sp),
        ),
        SizedBox(width: 4.w),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 9.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white38, fontSize: 10.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.highlightColor : Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _navigateToAchievementsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AchievementsScreen(
          currentUser: _currentUser!,
          allOrganisms: _allOrganisms,
          authService: _authService,
        ),
      ),
    );
  }
}
