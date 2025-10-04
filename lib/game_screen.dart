import 'package:flutter/material.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Arena'),
        backgroundColor: Colors.green[900],
      ),
      body: Center(
        child: Text(
          'START THE ANIMAL WARFARE!',
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
