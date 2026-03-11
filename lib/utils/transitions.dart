import 'package:flutter/material.dart';

// Define the dark background color for the transition (Deep Forest Green)
const Color _transitionBackgroundColor = Color(0xFF1E3F2A);
const Duration _fadeDuration = Duration(milliseconds: 280);
const Duration _slideUpDuration = Duration(milliseconds: 320);
const Duration _fadeScaleDuration = Duration(milliseconds: 280);

// ------------------------------------------------------------------
// 1. Fade Transition
// Used for smooth, quick transitions (e.g., MainScreen to ProfileScreen)
// ------------------------------------------------------------------
PageRouteBuilder createFadeRoute(Widget page) {
  return PageRouteBuilder(
    opaque: false,
    transitionDuration: _fadeDuration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return Container(
        color: _transitionBackgroundColor,
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

// ------------------------------------------------------------------
// 2. Slide-Up Transition
// Used for detail / sub-screens pushed from the main nav
// (Settings, Profile, PatchNotes, etc.)
// ------------------------------------------------------------------
PageRouteBuilder createSlideUpRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: _slideUpDuration,
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

// ------------------------------------------------------------------
// 3. Fade-Scale Transition
// Used for high-importance pushes (entering Game, Roguelike, Battle)
// ------------------------------------------------------------------
PageRouteBuilder createFadeScaleRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: _fadeScaleDuration,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      );
      final scale = Tween<double>(
        begin: 0.96,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}
