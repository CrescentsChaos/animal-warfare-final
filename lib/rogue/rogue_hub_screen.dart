import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/rogue/move_manage_screen.dart';

class RogueHubScreen extends StatelessWidget {
  const RogueHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final rogueState = userState.currentUser?.rogueLikeState;

    if (rogueState == null || !rogueState.isActive) {
      // Fallback if state is invalid
      Future.microtask(() => Navigator.pop(context));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String biomeName = rogueState.currentBiome ?? 'Forest';
    final Color themeColor = _scanBiomeColor(biomeName);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/backgrounds/${biomeName.toLowerCase()}.png',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(
                rogueState.floor,
                rogueState.encounterIndex,
                themeColor,
              ),

              const Spacer(),

              // Team Slots
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Text(
                      'YOUR TEAM',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        color: themeColor,
                        fontSize: 14,
                        shadows: const [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140, // Height for team cards
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: rogueState.team.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return _buildTeamCard(
                            context,
                            rogueState.team[index],
                            index,
                            themeColor,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildActionButton(
                      context,
                      label: 'NEXT BATTLE',
                      icon: Icons.flash_on,
                      color: Colors.redAccent,
                      onPressed: () => _startNextBattle(context, userState),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      context,
                      label: 'EXIT RUN (SAVE & QUIT)',
                      icon: Icons.exit_to_app,
                      color: Colors.grey,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int floor, int encounterIndex, Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      width: double.infinity,
      color: Colors.black45,
      child: Column(
        children: [
          Text(
            'FLOOR $floor',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Encounter ${encounterIndex + 1} / 5',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              color: themeColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(
    BuildContext context,
    CapturedOrganism member,
    int index,
    Color themeColor,
  ) {
    final hpRatio = member.currentHealth / member.maxHealth;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MoveManageScreen(
              organismIndex: index,
              // We pass the rogue team index
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeColor, width: 2),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sprite could go here if available via asset
            Image.asset(
              'assets/sprites/${member.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
              width: 48,
              height: 48,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.pets, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              member.baseOrganism.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                color: Colors.white,
                fontSize: 8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Lv.${member.level}',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                color: Colors.grey,
                fontSize: 7,
              ),
            ),
            const SizedBox(height: 8),
            // HP Bar
            LinearProgressIndicator(
              value: hpRatio,
              backgroundColor: Colors.grey[800],
              color: hpRatio > 0.5
                  ? Colors.green
                  : (hpRatio > 0.2 ? Colors.orange : Colors.red),
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            const Text(
              'MANAGE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                color: Colors.blueAccent,
                fontSize: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _startNextBattle(BuildContext context, UserState userState) {
    final rogue = userState.currentUser!.rogueLikeState;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) {
              // If we are at encounter 0, it means we just started or changed floors
              // The opponents are already generated in userState.incrementRogueFloor/advanceToNextFloor

              return BattleScreen(
                playerOrganism: rogue.team[0], // First member starts
                opponentOrganism: rogue
                    .opponentTeam![0], // Match logic matches logic in USerState
                biomeName: rogue.currentBiome ?? 'Forest',
                playerTeam: rogue.team,
                opponentTeam: rogue.opponentTeam,
                battleTitle:
                    'Rogue Floor ${rogue.floor} - ${rogue.encounterIndex + 1}/5',
                isArenaBattle: rogue.encounterIndex == 4, // Boss logic
                isRogueMode: true,
              );
            },
          ),
        )
        .then((_) {
          // Refresh state when coming back?
          // State is provided cleanly via Provider, so UI updates automatically if UserState notifies listeners.
        });
  }

  Color _scanBiomeColor(String biome) {
    switch (biome.toLowerCase()) {
      case 'forest':
        return Colors.greenAccent;
      case 'desert':
        return Colors.orangeAccent;
      case 'ocean':
        return Colors.cyanAccent;
      case 'mountain':
        return Colors.grey;
      case 'volcano':
        return Colors.redAccent;
      case 'swamp':
        return Colors.purpleAccent;
      case 'plains':
        return Colors.lightGreenAccent;
      // Add more as needed
      default:
        return Colors.white;
    }
  }
}
