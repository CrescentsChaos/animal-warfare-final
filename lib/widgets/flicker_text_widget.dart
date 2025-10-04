import 'package:flutter/material.dart';

class FlickerTextWidget extends StatefulWidget {
  final String text;
  final double fontSize;

  const FlickerTextWidget({
    super.key,
    required this.text,
    this.fontSize = 20.0,
  });

  @override
  State<FlickerTextWidget> createState() => _FlickerTextWidgetState();
}

class _FlickerTextWidgetState extends State<FlickerTextWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1. Initialize the controller. A short duration creates a quick flicker.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Total flicker cycle
    )..repeat(reverse: true); // 2. Set it to repeat and reverse the animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3. Use an AnimatedBuilder to rebuild the Opacity widget on every frame
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // We use a Tween to map the controller's 0.0-1.0 value to a min/max opacity
        // 0.2 is the dimmest, 1.0 is the brightest.
        final opacity = Tween<double>(begin: 0.2, end: 1.0).evaluate(_controller);

        return Opacity(
          opacity: opacity,
          child: Text(
            widget.text,
            style: TextStyle(
              fontFamily: 'PressStart2P', // Use your retro font
              fontSize: widget.fontSize,
              color: Colors.white,
              shadows: const [
                // Optional: Add a subtle glow for better retro feel
                Shadow(color: Colors.blue, blurRadius: 3.0),
              ],
            ),
          ),
        );
      },
    );
  }
}