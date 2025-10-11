import 'package:flutter/material.dart';

// --- 1. COLOR CONSTANTS ---
class AppColors {
  // Primary App Colors (Retro/Military Theme)
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod

  // Individual Battle Stat Colors (Used in Anidex)
  static const Color statHealthColor = Color(0xFFC6FF00); // Lime
  static const Color statAttackColor = Color(0xFFFF0000); // Red
  static const Color statDefenseColor = Color(0xFFFFEB3B); // Yellow
  static const Color statSpeedColor = Color(0xFF00FFFF); // Cyan

  // UI Feedback Colors (Used in Quiz)
  static const Color correctGreen = Color(0xFF00FF00); // Neon Green for correct
  static const Color wrongRed = Color(0xFFFF0000);   // Red for wrong
}

// --- 2. CUSTOM FONT STYLES (PressStart2P) ---
// Note: You still need to ensure 'PressStart2P' is included in your pubspec.yaml
class AppTextStyles {
  // Base style for the primary font
  static const String fontFamily = 'PressStart2P';

  // Used for AppBar Titles and Major Headings (Size is responsive in calling widgets)
  static TextStyle headline(BuildContext context, {double baseSize = 16.0, Color color = AppColors.highlightColor}) {
    return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: _responsiveFontSize(context, baseSize),
    );
  }

  // Used for Button Text and Main Details (Size is responsive in calling widgets)
  static TextStyle body(BuildContext context, {double baseSize = 14.0, Color color = Colors.white}) {
    return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: _responsiveFontSize(context, baseSize),
    );
  }

  // Used for Small Details, Subtitles, and Stats (Size is responsive in calling widgets)
  static TextStyle small(BuildContext context, {double baseSize = 10.0, Color color = Colors.white}) {
    return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: _responsiveFontSize(context, baseSize),
    );
  }
}

// --- 3. RESPONSIVE FONT UTILITY ---
// Extracted from profile_screen.dart and quiz_game_screen.dart
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

// --- 4. OPTIONAL: FULL THEME DATA ---
// You can define a full ThemeData object for app-wide consistency
final ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primaryButtonColor,
  scaffoldBackgroundColor: AppColors.secondaryButtonColor,
  fontFamily: AppTextStyles.fontFamily,
  // Define AppBar theme using the custom font
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.secondaryButtonColor,
    titleTextStyle: AppTextStyles.headline(
      // Use a default context or hardcoded value if ThemeData doesn't have a context
      null as BuildContext, // Placeholder: Responsive sizing needs Context
      baseSize: 16.0, 
      color: AppColors.highlightColor,
    ).copyWith(fontSize: 16.0), // Use non-responsive size here for ThemeData
  ),
  // Define Button theme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryButtonColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5.0),
        side: const BorderSide(color: AppColors.highlightColor, width: 2.0),
      ),
    ),
  ),
);
