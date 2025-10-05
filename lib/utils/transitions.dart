import 'package:flutter/material.dart';

// Define the dark background color for the transition (Deep Forest Green)
const Color _transitionBackgroundColor = Color(0xFF1E3F2A); 
const Duration _fadeDuration = Duration(milliseconds: 400);
const Duration _cloudDuration = Duration(milliseconds: 1500);


// ------------------------------------------------------------------
// 1. Fade Transition
// Used for smooth, quick transitions (e.g., MainScreen to ProfileScreen)
// ------------------------------------------------------------------
PageRouteBuilder createFadeRoute(Widget page) {
  return PageRouteBuilder(
    // ⬅️ FIX: Set opaque to false so we can draw the background
    opaque: false, 
    transitionDuration: _fadeDuration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // ⬅️ FIX: Wrap the entire transition in a Container with the dark background color.
      // This prevents the underlying black screen from flashing.
      return Container(
        color: _transitionBackgroundColor,
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}


// ------------------------------------------------------------------
// 2. Cloud Transition (Clash of Clans style)
// Used for high-impact transitions (e.g., Splash to Main, Main to Game)
// NOTE: Requires 'assets/cloud_transition.png' to be available.
// ------------------------------------------------------------------
PageRouteBuilder createCloudTransitionRoute(Widget page) {
  // Use 1500ms (1.5 second) for a cinematic, noticeable transition.
  return PageRouteBuilder(
    // ⬅️ FIX: Set opaque to false so we can draw the background
    opaque: false,
    transitionDuration: _cloudDuration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // The entering screen (page) itself is underneath.
      final Widget incomingScreen = child;

      // ⬅️ FIX: Wrap the entire transition stack in a Container with the dark background color.
      // This guarantees the area behind the clouds is always dark green, not black.
      return Container(
        color: _transitionBackgroundColor,
        child: Stack(
          children: [
            incomingScreen, // The new screen, visible underneath the cloud layers

            // SlideTransition holds the cloud overlay
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0), // Start from left, off-screen
                end: const Offset(1.0, 0.0),    // Move to right, off-screen
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  // Ensure the animation covers the full duration for the clouds to hide and reveal
                  curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine), 
                ),
              ),
              child: Stack(
                children: [
                  // Layer 1: Main Cloud Pattern (Faster, top layer)
                  Positioned.fill(
                    child: Image.asset(
                      'assets/cloud_transition.png', 
                      fit: BoxFit.cover,
                      repeat: ImageRepeat.repeatX,
                      alignment: Alignment.centerLeft,
                      // Use BlendMode.screen or another mode to help with transparency/white clouds
                      color: Colors.white.withOpacity(0.9),
                      colorBlendMode: BlendMode.modulate,
                      // Fallback text if image isn't found
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text("Loading...", style: TextStyle(color: Colors.white, fontFamily: 'PressStart2P')),
                      ),
                    ),
                  ),
                  // Layer 2: Offset Cloud Pattern (Slightly slower/smaller for depth)
                  Positioned.fill(
                    left: 50, // Slight offset
                    right: -50,
                    child: Opacity(
                      opacity: 0.7,
                      child: Image.asset(
                        'assets/cloud_transition.png',
                        fit: BoxFit.cover,
                        repeat: ImageRepeat.repeatX,
                        alignment: Alignment.centerRight,
                        color: Colors.white.withOpacity(0.5),
                        colorBlendMode: BlendMode.modulate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
