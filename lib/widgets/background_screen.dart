import 'package:flutter/material.dart';

class BackgroundScreen extends StatelessWidget {
  final Widget child;
  const BackgroundScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Use BoxDecoration for the background image
      decoration: const BoxDecoration(
        image: DecorationImage(
          // Replace 'background.png' with your actual image file name
          image: AssetImage('assets/background.png'),
          // This is key: it makes the image fill the entire container
          fit: BoxFit.cover,
        ),
      ),
      // The child widget (your game content) is placed on top
      child: child,
    );
  }
}