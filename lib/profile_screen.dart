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
import 'package:google_fonts/google_fonts.dart';

// Helper to get faction styling

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
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final user = _currentUser!;
    final totalCount = _allOrganisms.length;
    final discoveredCount = user.discoveredOrganisms.length;

    return Scaffold(
      backgroundColor: AppColors.background,
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
      backgroundColor: AppColors.surface,
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
                SizedBox(height: 36.h),
                _buildAvatar(user),
                SizedBox(height: 12.h),

                // Display Name + Rank
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.effectiveDisplayName.toUpperCase(),
                      style: AppTextStyles.headline(
                        context,
                        baseSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: user.rankColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: user.rankColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        user.rankName.toUpperCase(),
                        style: TextStyle(
                          color: user.rankColor,
                          fontFamily: 'PressStart2P',
                          fontSize: 6.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),

                // Username label
                if (user.displayName.isNotEmpty)
                  Text(
                    '@${user.username}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (user.displayName.isNotEmpty) SizedBox(height: 8.h),

                // Title & Faction Badges
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.title.isNotEmpty) ...[
                      _buildBadge(
                        Icons.military_tech,
                        user.title,
                        AppColors.highlight,
                      ),
                      SizedBox(width: 6.w),
                    ],
                    if (user.faction.isNotEmpty)
                      _buildFactionBadge(user.faction),
                  ],
                ),

                // Bio
                if (user.bio.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Text(
                      '"${user.bio}"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
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
    // Determine which image to show
    ImageProvider? imageProvider;
    bool isCustom = false;

    if (user.avatar.isNotEmpty && user.avatar != 'default') {
      final file = File(user.avatar);
      if (file.existsSync()) {
        imageProvider = FileImage(file);
        isCustom = true;
      }
    }

    // If no custom photo, try to load archetype icon
    IconData? archetypeIcon;
    Color archetypeColor = AppColors.primary;
    if (!isCustom && user.avatarIconKey.isNotEmpty) {
      if (user.avatarIconKey.contains('warrior')) {
        archetypeIcon = Icons.shield_rounded;
        archetypeColor = const Color(0xFFEF5350);
      } else if (user.avatarIconKey.contains('ranger')) {
        archetypeIcon = Icons.gps_fixed_rounded;
        archetypeColor = AppColors.primary;
      } else if (user.avatarIconKey.contains('scholar')) {
        archetypeIcon = Icons.auto_stories_rounded;
        archetypeColor = const Color(0xFFAB47BC);
      } else if (user.avatarIconKey.contains('rogue')) {
        archetypeIcon = Icons.flash_on_rounded;
        archetypeColor = const Color(0xFFFF7043);
      }
    }

    return Container(
      width: 90.w,
      height: 90.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: archetypeIcon != null
            ? archetypeColor.withValues(alpha: 0.15)
            : AppColors.surface,
        border: Border.all(
          color: isCustom ? AppColors.highlight : archetypeColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCustom ? AppColors.highlight : archetypeColor).withValues(
              alpha: 0.3,
            ),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: imageProvider == null
          ? Icon(
              archetypeIcon ?? Icons.person,
              size: 45.w,
              color: archetypeIcon != null
                  ? archetypeColor
                  : AppColors.textMuted,
            )
          : null,
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactionBadge(String faction) {
    Color color = Colors.grey;
    String emoji = '';

    switch (faction) {
      case 'Wilderness':
        color = const Color(0xFF66BB6A);
        emoji = '🌿';
        break;
      case 'Ocean':
        color = const Color(0xFF29B6F6);
        emoji = '🌊';
        break;
      case 'Sky':
        color = const Color(0xFFFFCA28);
        emoji = '🌤';
        break;
      case 'Shadow':
        color = const Color(0xFF7E57C2);
        emoji = '🌑';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 8.sp)),
          SizedBox(width: 4.w),
          Text(
            faction.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        Container(
          width: 3.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
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
              minHeight: 10.h,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              color: AppColors.primary,
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
          color: Colors.white.withValues(alpha: 0.05),
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
            Colors.purple.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
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
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
