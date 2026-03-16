import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
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
          border: Border.all(
            color: themeColor.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.2),
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
                          if (reward.type == RogueRewardType.singleHeal ||
                              reward.type == RogueRewardType.singleStamina) {
                            _showAnimalSelection(context, themeColor, reward);
                          } else {
                            onSelect(reward);
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPremium
                                ? Colors.amber.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.05),
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
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : themeColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    reward.type == RogueRewardType.item &&
                                        reward.itemId != null
                                    ? Image.asset(
                                        'assets/items/${reward.itemId!.replaceAll('_', '-')}.png',
                                        errorBuilder: (context, _, _) => Icon(
                                          isPremium
                                              ? Icons.star
                                              : _iconFor(reward.type),
                                          color: isPremium
                                              ? Colors.amber
                                              : themeColor,
                                        ),
                                      )
                                    : Icon(
                                        isPremium
                                            ? Icons.star
                                            : _iconFor(reward.type),
                                        color: isPremium
                                            ? Colors.amber
                                            : themeColor,
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

  void _showAnimalSelection(
    BuildContext context,
    Color themeColor,
    RogueReward reward,
  ) {
    final userState = Provider.of<UserState>(context, listen: false);
    final team = userState.currentUser?.rogueLikeState.team ?? [];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reward.type == RogueRewardType.singleHeal
                    ? 'HEAL WHO?'
                    : 'RESTORE WHO?',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: team.length,
                  itemBuilder: (c, i) {
                    final org = team[i];
                    final isFainted = org.currentHealth <= 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          onSelect(reward.copyWith(targetIndex: i));
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  org.baseOrganism.sprite,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, _, _) => const Icon(
                                    Icons.pets,
                                    color: Colors.white24,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          org.displayName.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 8,
                                            color: isFainted
                                                ? Colors.white38
                                                : Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'LVL ${org.level}',
                                          style: const TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 6,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // HP Bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value:
                                            org.currentHealth / org.maxHealth,
                                        backgroundColor: Colors.white12,
                                        color:
                                            org.currentHealth / org.maxHealth >
                                                0.5
                                            ? Colors.greenAccent
                                            : org.currentHealth /
                                                      org.maxHealth >
                                                  0.2
                                            ? Colors.orangeAccent
                                            : Colors.redAccent,
                                        minHeight: 4,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'HP: ${org.currentHealth}/${org.maxHealth}',
                                          style: TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 6,
                                            color: isFainted
                                                ? Colors.redAccent
                                                : Colors.white54,
                                          ),
                                        ),
                                        if (reward.type ==
                                            RogueRewardType.singleStamina)
                                          Text(
                                            'STAMINA LOW',
                                            style: TextStyle(
                                              fontFamily: 'PressStart2P',
                                              fontSize: 5,
                                              color: Colors.blueAccent
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
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
      case RogueRewardType.singleStamina:
        return Icons.bolt;
      case RogueRewardType.cureStatus:
        return Icons.auto_mode;
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
        return 'Fully heal a chosen animal';
      case RogueRewardType.singleStamina:
        return 'Restore stamina of a chosen animal';
      case RogueRewardType.cureStatus:
        return 'Restore all moves stamina for the whole team';
      case RogueRewardType.captureItems:
        return 'Receive highly valuable capture nets';
      case RogueRewardType.natureMint:
        return 'Change the nature of any animal';
      case RogueRewardType.premium:
        return 'Exceptional high-tier reward';
    }
  }
}
