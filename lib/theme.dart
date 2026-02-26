import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// --- 1. COLOR CONSTANTS ---
class AppColors {
  // Primary App Colors (Retro/Military Theme)
  static const Color primaryButtonColor = Color(0xFF1B301B); // Tactical Forest
  static const Color secondaryButtonColor = Color(0xFF0A0C0A); // Tactical Black
  static const Color highlightColor = Color(0xFFC5A059); // Muted Gold

  // Individual Battle Stat Colors (Used in Anidex)
  static const Color statHealthColor = Color(0xFFC6FF00); // Lime
  static const Color statAttackColor = Color(0xFFFF0000); // Red
  static const Color statDefenseColor = Color(0xFFFFEB3B); // Yellow
  static const Color statPowerColor = Color(0xFF9C27B0); // Purple
  static const Color statResistanceStatColor = Color(0xFFFF5722); // Deep Orange
  static const Color statSpeedColor = Color(0xFF00FFFF); // Cyan

  // UI Feedback Colors (Used in Quiz)
  static const Color correctGreen = Color(0xFF00FF00); // Neon Green for correct
  static const Color wrongRed = Color(0xFFFF0000); // Red for wrong
}

// --- 2. CUSTOM FONT STYLES ---
class AppTextStyles {
  // Headers/Buttons use PressStart2P
  static const String fontFamily = 'PressStart2P';

  // Used for AppBar Titles and Major Headings
  static TextStyle headline(
    BuildContext context, {
    double baseSize = 16.0,
    Color color = AppColors.highlightColor,
  }) {
    return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: baseSize.sp,
    );
  }

  // Used for Button Text and Main Details
  static TextStyle body(
    BuildContext context, {
    double baseSize = 14.0,
    Color color = Colors.white,
  }) {
    return GoogleFonts.robotoMono(
      color: color,
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
  }

  // Used for Small Details, Subtitles, and Stats
  static TextStyle small(
    BuildContext context, {
    double baseSize = 10.0,
    Color color = Colors.white,
  }) {
    return GoogleFonts.robotoMono(
      color: color,
      fontSize: baseSize.sp,
      height: 1.4,
    );
  }
}

// --- 3. THEME DATA ---
ThemeData get appTheme {
  return ThemeData(
    primaryColor: AppColors.primaryButtonColor,
    scaffoldBackgroundColor: AppColors.secondaryButtonColor,
    fontFamily: GoogleFonts.robotoMono().fontFamily, // Default app font
    // Define AppBar theme using the custom font
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.secondaryButtonColor,
      titleTextStyle: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        color: AppColors.highlightColor,
        fontSize: 16.sp,
      ),
    ),
    // Define Button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryButtonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.r),
          side: const BorderSide(color: AppColors.highlightColor, width: 2.0),
        ),
      ),
    ),
  );
}
