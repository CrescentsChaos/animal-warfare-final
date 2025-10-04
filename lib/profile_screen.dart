import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        backgroundColor: Colors.brown,
      ),
      body: Center(
        child: Text(
          'PLAYER STATS & SETTINGS UI HERE',
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
