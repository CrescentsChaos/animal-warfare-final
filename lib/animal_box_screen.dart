// lib/animal_box_screen.dart
// Screen where the user can view captured animals and choose which one is the battle attacker.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
          final isNarrow = MediaQuery.sizeOf(context).width < 400;
          final padding = isNarrow ? 8.0 : 16.0;
          return ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: captured.length,
            itemBuilder: (context, index) {
              final org = captured[index];
              final isActive = user.activeAttackerIndex == index;
              return _AnimalCard(
                captured: org,
                index: index,
                isActiveAttacker: isActive,
                isNarrow: isNarrow,
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
                onRelease: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Release animal?'),
                      content: Text(
                        'Are you sure you want to release ${org.name}? They will return to the wild.',
                        style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Release'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await userState.releaseOrganism(index);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${org.name} has been released.'),
                          backgroundColor: AppColors.primaryButtonColor,
                        ),
                      );
                    }
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
  final bool isNarrow;
  final VoidCallback onSetAsAttacker;
  final VoidCallback onRelease;

  const _AnimalCard({
    required this.captured,
    required this.index,
    required this.isActiveAttacker,
    required this.isNarrow,
    required this.onSetAsAttacker,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final base = captured.baseOrganism;
    final movesList = base.moves.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    final spriteSize = isNarrow ? 100.0 : 120.0;
    final padding = isNarrow ? 8.0 : 12.0;

    return Card(
      margin: EdgeInsets.only(bottom: isNarrow ? 8.0 : 12.0),
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
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNarrow) ...[
              _buildNarrowLayout(context, base, spriteSize),
            ] else ...[
              _buildWideLayout(context, base, spriteSize),
            ],
            if (movesList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Moves: ${movesList.join(", ")}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: isNarrow ? 9 : 11,
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

  Widget _buildWideLayout(BuildContext context, dynamic base, double spriteSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnimalBoxSprite(organism: base, size: spriteSize),
        SizedBox(width: isNarrow ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                base.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isNarrow ? 12 : 16,
                  fontFamily: 'PressStart2P',
                ),
              ),
              Text(
                'HP: ${captured.currentHealth}/${captured.maxHealth}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: isNarrow ? 10 : 12,
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
                      fontSize: isNarrow ? 8 : 10,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SizedBox(
                    height: isNarrow ? 28 : 32,
                    child: ElevatedButton(
                      onPressed: isActiveAttacker ? null : onSetAsAttacker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButtonColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12),
                      ),
                      child: Text(
                        isActiveAttacker ? 'Active' : 'Set attacker',
                        style: TextStyle(fontSize: isNarrow ? 9 : 12, fontFamily: 'PressStart2P'),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: isNarrow ? 28 : 32,
                    child: OutlinedButton(
                      onPressed: onRelease,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[300],
                        side: BorderSide(color: Colors.red[300]!),
                        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10),
                      ),
                      child: Text(
                        'Release',
                        style: TextStyle(fontSize: isNarrow ? 9 : 12, fontFamily: 'PressStart2P'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, dynamic base, double spriteSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _AnimalBoxSprite(organism: base, size: spriteSize),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            base.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'PressStart2P',
            ),
          ),
        ),
        Center(
          child: Text(
            'HP: ${captured.currentHealth}/${captured.maxHealth}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
              fontFamily: 'PressStart2P',
            ),
          ),
        ),
        if (isActiveAttacker)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'CURRENT ATTACKER',
                style: TextStyle(
                  color: AppColors.highlightColor,
                  fontSize: 8,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isActiveAttacker ? null : onSetAsAttacker,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButtonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                isActiveAttacker ? 'Active' : 'Set attacker',
                style: const TextStyle(fontSize: 9, fontFamily: 'PressStart2P'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onRelease,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[300],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(
                'Release',
                style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnimalBoxSprite extends StatefulWidget {
  final dynamic organism;
  final double size;

  const _AnimalBoxSprite({required this.organism, required this.size});

  @override
  State<_AnimalBoxSprite> createState() => _AnimalBoxSpriteState();
}

class _AnimalBoxSpriteState extends State<_AnimalBoxSprite> {
  String? _imageSourceType;
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
  }

  String _getLocalPath() {
    final fileName = widget.organism.name
        .toString()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll('-', '_');
    return 'assets/sprites/$fileName.png';
  }

  Future<void> _determineImageSource() async {
    final localPath = _getLocalPath();
    try {
      await rootBundle.load(localPath);
      if (mounted) {
        setState(() {
          _imageSourceType = 'local';
          _imagePath = localPath;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _imageSourceType = 'network';
          _imagePath = widget.organism.sprite;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (_imageSourceType == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Container(
            color: Colors.grey[800],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Container(
          color: Colors.grey[900],
          alignment: Alignment.center,
          child: _imageSourceType == 'local'
              ? Image.asset(
                  _imagePath,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                )
              : Image.network(
                  _imagePath,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: size,
                    height: size,
                    color: Colors.grey[800],
                    child: const Icon(Icons.pets, color: Colors.white54, size: 48),
                  ),
                ),
        ),
      ),
    );
  }
}
