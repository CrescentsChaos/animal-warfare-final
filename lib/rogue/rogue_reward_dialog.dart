import 'package:flutter/material.dart';
import 'package:animal_warfare/models/rogue_like_state.dart';
import 'package:animal_warfare/data/biome_data.dart';

class RogueRewardDialog extends StatelessWidget {
  final List<RogueReward> rewards;
  final String biome;
  final Function(RogueReward) onSelect;

  const RogueRewardDialog({
    super.key,
    required this.rewards,
    required this.biome,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = BiomeData.colorFor(biome);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: themeColor.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    'VICTORY!',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      color: themeColor,
                      fontSize: 24,
                      shadows: [Shadow(color: Colors.white24, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SELECT YOUR REWARD',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: rewards.map((reward) {
                    final isPremium = reward.type == RogueRewardType.premium;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          onSelect(reward);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPremium
                                ? Colors.amber.withOpacity(0.1)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPremium ? Colors.amber : Colors.white12,
                              width: isPremium ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isPremium
                                      ? Colors.amber.withOpacity(0.2)
                                      : themeColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPremium
                                      ? Icons.star
                                      : _iconFor(reward.type),
                                  color: isPremium ? Colors.amber : themeColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reward.label,
                                      style: TextStyle(
                                        fontFamily: 'PressStart2P',
                                        color: isPremium
                                            ? Colors.amber
                                            : Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _descriptionFor(reward.type),
                                      style: TextStyle(
                                        fontFamily: 'PressStart2P',
                                        color: Colors.white38,
                                        fontSize: 7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'CHOOSE WISELY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: Colors.white24,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(RogueRewardType type) {
    switch (type) {
      case RogueRewardType.item:
        return Icons.auto_awesome;
      case RogueRewardType.fullHeal:
        return Icons.favorite;
      case RogueRewardType.singleHeal:
        return Icons.favorite_border;
      case RogueRewardType.cureStatus:
        return Icons.bolt;
      case RogueRewardType.captureItems:
        return Icons.catching_pokemon;
      case RogueRewardType.natureMint:
        return Icons.spa;
      case RogueRewardType.premium:
        return Icons.workspace_premium;
    }
  }

  String _descriptionFor(RogueRewardType type) {
    switch (type) {
      case RogueRewardType.item:
        return 'Gain a random talisman';
      case RogueRewardType.fullHeal:
        return 'Heal all animals to 100% HP';
      case RogueRewardType.singleHeal:
        return 'Fully heal your most injured animal';
      case RogueRewardType.cureStatus:
        return 'Restore all moves stamina';
      case RogueRewardType.captureItems:
        return 'Receive highly valuable capture nets';
      case RogueRewardType.natureMint:
        return 'Change the nature of any animal';
      case RogueRewardType.premium:
        return 'Exceptional high-tier reward';
    }
  }
}
