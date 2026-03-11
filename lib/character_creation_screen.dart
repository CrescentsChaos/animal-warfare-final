// lib/character_creation_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class CharacterCreationScreen extends StatefulWidget {
  final String username;
  final String password;

  const CharacterCreationScreen({
    super.key,
    required this.username,
    required this.password,
  });

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  final LocalAuthService _authService = LocalAuthService();

  // ── State ──
  String _gender = ''; // 'male' | 'female'
  final TextEditingController _displayNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.username;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Future<void> _finishCreation() async {
    if (_gender.isEmpty) {
      _snack('Please choose Male or Female.');
      return;
    }
    setState(() => _isLoading = true);

    final displayName = _displayNameController.text.trim().isEmpty
        ? widget.username
        : _displayNameController.text.trim();

    // Default icon key logic if avatar generic icon is required
    final avatarIconKey = '${_gender[0]}_ranger';

    final success = await _authService.register(
      widget.username,
      widget.password,
      displayName: displayName,
      gender: _gender == 'male' ? 'MALE' : 'FEMALE',
      avatarIconKey: avatarIconKey,
      faction: '',
      title: '',
      bio: '',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        await context.read<UserState>().handleSuccessfulAuth();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, a, __) => const MainScreen(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
          ),
          (_) => false,
        );
      } else {
        _snack('Username already taken. Please go back and choose another.');
      }
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.8,
                colors: [Color(0xFF0D2D2A), AppColors.background],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 24.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display name
                        Text(
                          'DISPLAY NAME',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: _displayNameController,
                          maxLength: 20,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15.sp,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.username,
                            hintStyle: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            counterStyle: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.badge_rounded,
                              color: AppColors.primary,
                              size: 20.sp,
                            ),
                          ),
                        ),
                        SizedBox(height: 32.h),

                        // Gender cards
                        Text(
                          'GENDER',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildGenderCard(
                                'male',
                                'Male',
                                Icons.male_rounded,
                                const Color(0xFF42A5F5),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildGenderCard(
                                'female',
                                'Female',
                                Icons.female_rounded,
                                const Color(0xFFEC407A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _finishCreation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CREATE ACCOUNT',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 11.sp,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(Icons.check_circle_rounded, size: 18.sp),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 8.h),
      child: Column(
        children: [
          Text(
            'CHARACTER CREATION',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10.sp,
              color: AppColors.primary.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'YOUR IDENTITY',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 18.sp,
              color: AppColors.highlight,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            'Who are you, Commander?',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 160.h,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: selected ? 0.2 : 0.08),
              ),
              child: Icon(
                icon,
                size: 42.sp,
                color: selected ? color : AppColors.textMuted,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11.sp,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
            if (selected) ...[
              SizedBox(height: 8.h),
              Icon(Icons.check_circle, color: color, size: 18.sp),
            ],
          ],
        ),
      ),
    );
  }
}
