// lib/widgets/active_lures_widget.dart
// Displays active taxonomic lure buffs with real-time countdown timers.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animal_warfare/models/player_active_effect.dart';

class ActiveLuresWidget extends StatefulWidget {
  final List<PlayerActiveEffect> activeEffects;

  const ActiveLuresWidget({super.key, required this.activeEffects});

  @override
  State<ActiveLuresWidget> createState() => _ActiveLuresWidgetState();
}

class _ActiveLuresWidgetState extends State<ActiveLuresWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeEffects.where((e) => !e.isExpired).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFDAA520).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 12),
              SizedBox(width: 4),
              Text(
                'ACTIVE LURES',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 6,
                  color: Color(0xFFDAA520),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...active.map((effect) => _LureRow(effect: effect)),
        ],
      ),
    );
  }
}

class _LureRow extends StatelessWidget {
  final PlayerActiveEffect effect;
  const _LureRow({required this.effect});

  @override
  Widget build(BuildContext context) {
    final remaining = effect.expiresAt.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final timeStr = '${minutes}m ${seconds.toString().padLeft(2, '0')}s';

    final isLow = remaining.inSeconds < 60;
    final timeColor = isLow ? Colors.redAccent : Colors.greenAccent;

    // Icon based on target type
    IconData icon;
    switch (effect.targetType) {
      case 'class':
        icon = Icons.category;
        break;
      case 'order':
        icon = Icons.account_tree;
        break;
      case 'subfamily':
        icon = Icons.family_restroom;
        break;
      default:
        icon = Icons.science;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF7EC8E3), size: 10),
          const SizedBox(width: 4),
          Text(
            '${effect.targetValue.toUpperCase()} x${effect.multiplier.toStringAsFixed(1)}',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 5,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 5,
              color: timeColor,
            ),
          ),
        ],
      ),
    );
  }
}
