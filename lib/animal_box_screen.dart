// lib/animal_box_screen.dart
// Screen where the user can view captured animals and choose which one is the battle attacker.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';

class AnimalBoxScreen extends StatelessWidget {
  const AnimalBoxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Box'),
        backgroundColor: AppColors.secondaryButtonColor,
      ),
      body: Consumer<UserState>(
        builder: (context, userState, _) {
          final user = userState.currentUser;
          if (user == null) {
            return const Center(child: Text('Not logged in.'));
          }
          final captured = user.capturedOrganisms;
          if (captured.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'No animals captured yet.\nExplore biomes and win battles to capture some!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: captured.length,
            itemBuilder: (context, index) {
              final org = captured[index];
              final isActive = user.activeAttackerIndex == index;
              return _AnimalCard(
                captured: org,
                index: index,
                isActiveAttacker: isActive,
                onSetAsAttacker: () async {
                  await userState.setActiveAttacker(index);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${org.name} is now your battle attacker.'),
                        backgroundColor: AppColors.primaryButtonColor,
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final CapturedOrganism captured;
  final int index;
  final bool isActiveAttacker;
  final VoidCallback onSetAsAttacker;

  const _AnimalCard({
    required this.captured,
    required this.index,
    required this.isActiveAttacker,
    required this.onSetAsAttacker,
  });

  @override
  Widget build(BuildContext context) {
    final base = captured.baseOrganism;
    final movesList = base.moves.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
        color: isActiveAttacker
          ? AppColors.primaryButtonColor.withOpacity(0.3)
          : Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActiveAttacker ? AppColors.highlightColor : Colors.grey[700]!,
          width: isActiveAttacker ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    base.sprite,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey[800],
                      child: const Icon(Icons.pets, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        base.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      Text(
                        'HP: ${captured.currentHealth}/${captured.maxHealth}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      if (isActiveAttacker)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'CURRENT ATTACKER',
                            style: TextStyle(
                              color: AppColors.highlightColor,
                              fontSize: 10,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: isActiveAttacker ? null : onSetAsAttacker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButtonColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    isActiveAttacker ? 'Active' : 'Set attacker',
                    style: const TextStyle(fontSize: 12, fontFamily: 'PressStart2P'),
                  ),
                ),
              ],
            ),
            if (movesList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Moves: ${movesList.join(", ")}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontFamily: 'PressStart2P',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
