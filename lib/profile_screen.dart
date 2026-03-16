// lib/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/edit_profile_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/settings_screen.dart';
import 'package:animal_warfare/achievement_screen.dart';
import 'package:animal_warfare/achievement_service.dart';
import 'package:animal_warfare/models/achievement.dart';
import 'package:animal_warfare/widgets/achievement_selection_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<dynamic> _allOrganisms = [];
  late AchievementService _achievementService;
  List<Achievement> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadOrganisms();
    _initAchievementService();
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      if (mounted) {
        setState(() {
          _allOrganisms = json.decode(response);
          // Re-init achievement service once organisms are loaded
          _initAchievementService();
        });
      }
    } catch (e) {
      debugPrint('Error loading Organisms.json: $e');
    }
  }

  void _initAchievementService() {
    _achievementService = AchievementService(
      allOrganisms: _allOrganisms,
      authService: LocalAuthService(),
    );
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    await _achievementService.loadAchievements();
    if (mounted) {
      setState(() {
        _achievements = _achievementService.getAllAchievements();
      });
    }
  }

  void _navigateToEditScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const EditProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserState>(
      builder: (context, userState, child) {
        final user = userState.currentUser;
        if (user == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F0F),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final totalCount = _allOrganisms.isNotEmpty
            ? _allOrganisms.length
            : 1700;
        final discoveredCount = user.discoveredOrganisms.length;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Stack(
            children: [
              _buildBackground(),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(user),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 24.h),
                          _buildStatGrid(
                            userState,
                            discoveredCount,
                            totalCount,
                          ),
                          SizedBox(height: 32.h),
                          _buildAchievementDisplay(user),
                          SizedBox(height: 32.h),
                          _buildAccountProgress(user),
                          SizedBox(height: 32.h),
                          _buildUtilities(user),
                          if (user.bestRogueFloor > 0) ...[
                            SizedBox(height: 32.h),
                            _buildRogueSection(user),
                          ],
                          SizedBox(height: 100.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.5,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(UserData user) {
    return SliverAppBar(
      expandedHeight: 260.h,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.asset('assets/main.png', fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0F0F0F).withValues(alpha: 0.8),
                      const Color(0xFF0F0F0F),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildAvatar(user),
                SizedBox(height: 16.h),
                Text(
                  user.effectiveDisplayName.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 10,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                _buildRankBadge(user),
                SizedBox(height: 24.h),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SettingsScreen(
                currentUser: user,
                authService: LocalAuthService(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(UserData user) {
    ImageProvider? imageProvider;
    bool isCustom = false;

    if (user.avatar.isNotEmpty && user.avatar != 'default') {
      final file = File(user.avatar);
      if (file.existsSync()) {
        imageProvider = FileImage(file);
        isCustom = true;
      }
    }

    return Container(
      width: 110.w,
      height: 110.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: (isCustom ? AppColors.highlight : AppColors.primary)
              .withValues(alpha: 0.5),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCustom ? AppColors.highlight : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 52.w,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? Icon(Icons.person, size: 55.w, color: AppColors.primary)
            : null,
      ),
    );
  }

  Widget _buildRankBadge(UserData user) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: user.rankColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: user.rankColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: user.rankColor.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child:
          user.effectiveDisplayName.toUpperCase() == user.rankName.toUpperCase()
          ? Text(
              'LV. ${user.accountLevel}',
              style: GoogleFonts.orbitron(
                color: user.rankColor,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            )
          : Text(
              user.rankName.toUpperCase(),
              style: GoogleFonts.orbitron(
                color: user.rankColor,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
    );
  }

  Widget _buildStatGrid(UserState userState, int discovered, int total) {
    final user = userState.currentUser!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => userState.toggleDetailedCurrency(),
                child: _statCard(
                  'CASH',
                  '${UserState.formatCurrency(user.money, detailed: userState.showDetailedCurrency)} Tk.',
                  Icons.savings_outlined,
                  Colors.amber,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _statCard(
                'LEVEL',
                user.accountLevel.toString(),
                Icons.bolt,
                Colors.blueAccent,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _statCard(
          'ANIMAL DEX COMPLETION',
          '$discovered / $total',
          Icons.pets,
          const Color(0xFF2ECC71),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: fullWidth
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 20.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.orbitron(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  color: Colors.white24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementDisplay(UserData user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader('FEATURED MEDALS'),
            TextButton(
              onPressed: () => _showAchievementSelection(context),
              child: Text(
                'CUSTOMIZE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7.sp,
                  color: const Color(0xFFDAA520).withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              if (index < user.displayedAchievements.length) {
                final title = user.displayedAchievements[index];
                final achievement = _achievements.firstWhere(
                  (a) => a.title == title,
                  orElse: () => Achievement(title: title, description: ''),
                );
                return _medalItem(achievement.imagePath, achievement.title);
              } else {
                return _emptyMedalSlot();
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _medalItem(String? path, String title) {
    return Column(
      children: [
        Container(
          width: 80.w,
          height: 80.w,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDAA520).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            path ?? 'assets/achievements/medal_bronze.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.military_tech,
              color: Color(0xFFDAA520),
              size: 50,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: 90.w,
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 6.sp,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.6,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _emptyMedalSlot() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showAchievementSelection(context),
          child: Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
                style: BorderStyle.none,
              ),
            ),
            child: Icon(Icons.add_rounded, color: Colors.white10, size: 36.sp),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'LOCKED',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7.sp,
            color: Colors.white10,
          ),
        ),
      ],
    );
  }

  void _showAchievementSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AchievementSelectionSheet(allOrganisms: _allOrganisms),
    );
  }

  Widget _buildAccountProgress(UserData user) {
    final nextLevelXP = (user.accountLevel + 1) * (user.accountLevel + 1) * 100;
    final prevLevelXP = user.accountLevel * user.accountLevel * 100;
    final progress =
        ((user.accountXP - prevLevelXP) / (nextLevelXP - prevLevelXP)).clamp(
          0.0,
          1.0,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('EXPERIENCE HUB'),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LEVEL ${user.accountLevel} PROGRESS',
                    style: GoogleFonts.orbitron(
                      fontSize: 11.sp,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9.sp,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14.h,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                '${user.accountXP} / $nextLevelXP XP',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUtilities(UserData user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('OPERATIONS'),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _utilityButton(
                'EDIT PROFILE',
                Icons.manage_accounts,
                _navigateToEditScreen,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _utilityButton(
                'ACHIEVEMENTS',
                Icons.emoji_events,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AchievementsScreen(
                      currentUser: user,
                      allOrganisms: _allOrganisms,
                      authService: LocalAuthService(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _utilityButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 100.h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFFDAA520).withValues(alpha: 0.9),
              size: 28.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 6.5.sp,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRogueSection(UserData user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('MISSION LOGS'),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3C72).withValues(alpha: 0.15),
                const Color(0xFF2A5298).withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF1E3C72).withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ROGUE ELITE FLOOR',
                    style: GoogleFonts.orbitron(
                      fontSize: 11.sp,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${user.bestRogueFloor}',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 14.sp,
                      color: const Color(0xFFDAA520),
                    ),
                  ),
                ],
              ),
              if (user.bestRogueTeam.isNotEmpty) ...[
                SizedBox(height: 24.h),
                SizedBox(
                  height: 56.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: user.bestRogueTeam.length,
                    itemBuilder: (context, idx) {
                      final animal = user.bestRogueTeam[idx];
                      final fileName = animal.name.toLowerCase().replaceAll(
                        ' ',
                        '_',
                      );
                      return Padding(
                        padding: EdgeInsets.only(right: 16.w),
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Image.asset(
                            'assets/sprites/$fileName.png',
                            width: 44.h,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.pets, color: Colors.white10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 5.w,
          height: 18.h,
          decoration: BoxDecoration(
            color: const Color(0xFFDAA520),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDAA520).withValues(alpha: 0.4),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        SizedBox(width: 14.w),
        Text(
          title,
          style: GoogleFonts.orbitron(
            fontSize: 13.sp,
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}
