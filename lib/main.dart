import 'package:flutter/material.dart';
import 'start_screen.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameFlow(),
    );
  }
}

class GameFlow extends StatefulWidget {
  @override
  State<GameFlow> createState() => _GameFlowState();
}

class _GameFlowState extends State<GameFlow> {
  bool showStart = true;

  @override
  Widget build(BuildContext context) {
    return showStart
        ? StartScreen(
            onTap: () {
              setState(() {
                showStart = false; // go to game after tapping
              });
            },
          )
        : const GameScreen(); // 👈 your actual game screen
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("This is the game screen")),
    );
  }
}