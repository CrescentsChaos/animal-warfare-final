import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ---------------------------------------------------------------------------
// APP VERSION — change this ONE value and it propagates everywhere.
// ---------------------------------------------------------------------------
const String kAppVersion = '0.1.1';
const int kBuildNumber = 1;

// --- 1. COLOR CONSTANTS ---
class AppColors {
  // === BASE SURFACES ===
  static const Color background = Color(0xFF0D1117); // Deep navy-black
  static const Color surface = Color(
    0xFF161B22,
  ); // Dark surface (cards, app bars)
  static const Color surfaceVariant = Color(
    0xFF1C2333,
  ); // Slightly lighter surface

  // === ACCENT COLORS ===
  static const Color primary = Color(0xFF00BFA5); // Vibrant teal — main CTA
  static const Color primaryDark = Color(
    0xFF00897B,
  ); // Darker teal for pressed states
  static const Color highlight = Color(
    0xFFFFB300,
  ); // Amber/gold — titles, XP, stars
  static const Color danger = Color(
    0xFFD32F2F,
  ); // Crimson for destructive actions
  static const Color dangerLight = Color(
    0xFFEF5350,
  ); // Lighter red for warnings

  // === LEGACY ALIASES (kept for screens not yet updated) ===
  static const Color primaryButtonColor = Color(0xFF004D40); // Deep teal-green
  static const Color secondaryButtonColor = Color(0xFF0D1117);
  static const Color highlightColor = Color(0xFFFFB300); // Same as highlight

  // === STAT COLORS (Used in Anidex) ===
  static const Color statHealthColor = Color(0xFF4CAF50); // Green
  static const Color statAttackColor = Color(0xFFF44336); // Red
  static const Color statDefenseColor = Color(0xFFFF9800); // Orange
  static const Color statPowerColor = Color(0xFF9C27B0); // Purple
  static const Color statResistanceStatColor = Color(0xFFFFEB3B); // Yellow
  static const Color statSpeedColor = Color(0xFF00BCD4); // Cyan

  // === UI FEEDBACK ===
  static const Color correctGreen = Color(0xFF69F0AE);
  static const Color wrongRed = Color(0xFFFF5252);

  // === TEXT ===
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0BEC5); // Blue-grey 200
  static const Color textMuted = Color(0xFF546E7A); // Blue-grey 600

  // Border/divider
  static const Color border = Color(0xFF30363D);
  static const Color borderHighlight = Color(0xFFFFB300);
}

// --- 2. CUSTOM FONT STYLES ---
class AppTextStyles {
  // Pixel font — ONLY for titles, headings, appbars
  static const String pixelFont = 'PressStart2P';

  // Used for AppBar Titles and Major Headings (pixel font)
  static TextStyle headline(
    BuildContext context, {
    double baseSize = 16.0,
    Color color = AppColors.highlight,
  }) {
    return TextStyle(
      color: color,
      fontFamily: pixelFont,
      fontSize: baseSize.sp,
      height: 1.4,
    );
  }

  // Readable body text — Inter/Roboto for legibility
  static TextStyle body(
    BuildContext context, {
    double baseSize = 14.0,
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: baseSize.sp,
      fontWeight: fontWeight,
      height: 1.5,
    );
  }

  // Small readable text — subtitles, descriptions, stats
  static TextStyle small(
    BuildContext context, {
    double baseSize = 11.0,
    Color color = AppColors.textSecondary,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: baseSize.sp,
      fontWeight: fontWeight,
      height: 1.4,
    );
  }

  // Label text — small caps / button labels (Inter, semi-bold)
  static TextStyle label(
    BuildContext context, {
    double baseSize = 12.0,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.2,
    );
  }
}

// --- 3. THEME DATA ---
ThemeData get appTheme {
  return ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.highlight,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    ),
    fontFamily: GoogleFonts.inter().fontFamily,
    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: AppTextStyles.pixelFont,
        color: AppColors.highlight,
        fontSize: 14.sp,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    ),
    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
        textStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13.sp,
        ),
      ),
    ),
    // Cards
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    // Dividers
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    // Sliders
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      thumbColor: AppColors.primary,
      inactiveTrackColor: Color(0xFF30363D),
    ),
    // Switches
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.grey,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.3),
      ),
    ),
    // Progress indicators
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    // Snackbars
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    // Tooltips
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    // Page Transitions — smooth fade+scale on every push by default
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FadeScalePageTransitionsBuilder(),
        TargetPlatform.iOS: _FadeScalePageTransitionsBuilder(),
        TargetPlatform.windows: _FadeScalePageTransitionsBuilder(),
        TargetPlatform.macOS: _FadeScalePageTransitionsBuilder(),
        TargetPlatform.linux: _FadeScalePageTransitionsBuilder(),
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Custom page transition — fast fade + subtle upward slide (professional feel)
// ---------------------------------------------------------------------------
class _FadeScalePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeScalePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Only animate forward pushes; pops feel instant (like native apps)
    if (animation.status == AnimationStatus.reverse) return child;

    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
