import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/rogue/move_manage_screen.dart';
import 'package:animal_warfare/data/biome_data.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'dart:math' as math;

class RogueHubScreen extends StatelessWidget {
  const RogueHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final rogueState = userState.currentUser?.rogueLikeState;

    if (rogueState == null || !rogueState.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String biomeName = rogueState.currentBiome ?? 'Jungle';
    final Color themeColor = BiomeData.colorFor(biomeName);

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
              Colors.black.withOpacity(0.75),
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

              const SizedBox(height: 20),

              // Status Bar
              _buildStatusBar(rogueState.team, themeColor),

              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: _RogueTeamList(),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: themeColor.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildActionButton(
                        context,
                        label: 'START NEXT BATTLE',
                        icon: Icons.flash_on,
                        color: Colors.redAccent,
                        isPrimary: true,
                        onPressed: () => _startNextBattle(context, userState),
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        context,
                        label: 'SAVE & QUIT',
                        icon: Icons.save_outlined,
                        color: Colors.white24,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: const Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RUN PROGRESS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: themeColor.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 5; i++)
                    Container(
                      width: 30,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i < encounterIndex
                            ? themeColor
                            : i == encounterIndex
                            ? Colors.white
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: i == encounterIndex
                            ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'FLOOR',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: themeColor.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$floor',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(List<CapturedOrganism> team, Color themeColor) {
    int totalHp = 0;
    int currentHp = 0;
    for (var m in team) {
      totalHp += m.maxHealth;
      currentHp += m.currentHealth;
    }
    final ratio = totalHp > 0 ? currentHp / totalHp : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TEAM VITALITY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 8,
                ),
              ),
              Text(
                '${(ratio * 100).toInt()}%',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: themeColor,
                  fontSize: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white10,
              color: themeColor,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: isPrimary ? 11 : 9,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: isPrimary ? 8 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: Colors.white12),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _startNextBattle(BuildContext context, UserState userState) {
    final rogue = userState.currentUser!.rogueLikeState;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return BattleScreen(
            playerOrganism: rogue.team[0],
            opponentOrganism: rogue.opponentTeam![0],
            biomeName: rogue.currentBiome ?? 'Forest',
            playerTeam: rogue.team,
            opponentTeam: rogue.opponentTeam,
            battleTitle:
                'Rogue Floor ${rogue.floor} - ${rogue.encounterIndex + 1}/5',
            isArenaBattle: rogue.encounterIndex == 4,
            isRogueMode: true,
          );
        },
      ),
    );
  }
}

class _RogueTeamList extends StatelessWidget {
  const _RogueTeamList();

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final team = userState.currentUser?.rogueLikeState.team ?? [];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: team.length,
      itemBuilder: (context, index) => _RogueTeamCard(
        member: team[index],
        index: index,
        teamCount: team.length,
      ),
    );
  }
}

class _RogueTeamCard extends StatelessWidget {
  final CapturedOrganism member;
  final int index;
  final int teamCount;

  const _RogueTeamCard({
    required this.member,
    required this.index,
    required this.teamCount,
  });

  @override
  Widget build(BuildContext context) {
    final biomeName =
        Provider.of<UserState>(
          context,
          listen: false,
        ).currentUser?.rogueLikeState.currentBiome ??
        'Jungle';
    final Color themeColor = BiomeData.colorFor(biomeName);
    final hpRatio = member.currentHealth / member.maxHealth;
    final isFainted = member.currentHealth <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFainted ? Colors.red.withOpacity(0.5) : Colors.white12,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Main Body
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sprite section
                Container(
                  width: 90,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    border: const Border(
                      right: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: isFainted ? 0.4 : 1.0,
                      child: Image.asset(
                        'assets/sprites/${member.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                        width: 60,
                        height: 60,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.pets,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                // Info section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              member.baseOrganism.name.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              'LV.${member.level}',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                color: themeColor,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // HP
                        Row(
                          children: [
                            const Text(
                              'HP',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                color: Colors.white54,
                                fontSize: 8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: hpRatio,
                                minHeight: 6,
                                backgroundColor: Colors.white10,
                                color: hpRatio > 0.5
                                    ? Colors.green
                                    : (hpRatio > 0.2
                                          ? Colors.orange
                                          : Colors.red),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${member.currentHealth}/${member.maxHealth}',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            color: Colors.white38,
                            fontSize: 7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Actions / Item Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                // Item indicator
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: member.equippedTalisman != null
                      ? Colors.amberAccent
                      : Colors.white24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member.equippedTalisman?.name ?? 'NO ITEM',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: member.equippedTalisman != null
                          ? Colors.amberAccent
                          : Colors.white24,
                    ),
                  ),
                ),
                // Manage button
                _buildSmallAction(
                  context,
                  'MANAGE',
                  onPressed: () => _showManageOptions(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAction(
    BuildContext context,
    String label, {
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showManageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MANAGE ${member.name.toUpperCase()}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _buildLargeOption(
                ctx,
                label: 'MANAGE MOVES',
                icon: Icons.edit_note,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => MoveManageScreen(organismIndex: index),
                    ),
                  ).then((_) {
                    // Update trigger already active via provider
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildLargeOption(
                ctx,
                label: 'SWAP ITEM',
                icon: Icons.swap_horiz,
                enabled: teamCount > 1,
                onPressed: () {
                  Navigator.pop(ctx);
                  _showSwapSelection(context);
                },
              ),
              const SizedBox(height: 12),
              _buildLargeOption(
                ctx,
                label: 'REMOVE ITEM',
                icon: Icons.delete_outline,
                enabled: member.equippedTalisman != null,
                color: Colors.redAccent.withOpacity(0.8),
                onPressed: () {
                  Navigator.pop(ctx);
                  Provider.of<UserState>(
                    context,
                    listen: false,
                  ).removeRogueTalisman(index);
                },
              ),
              const SizedBox(height: 24),
              _buildLargeOption(
                ctx,
                label: 'CANCEL',
                icon: Icons.close,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(
            label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.white10,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  void _showSwapSelection(BuildContext context) {
    final userState = Provider.of<UserState>(context, listen: false);
    final team = userState.currentUser!.rogueLikeState.team;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'SWAP ITEM WITH...',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: team.length,
                itemBuilder: (context, idx) {
                  if (idx == index) return const SizedBox.shrink();
                  final target = team[idx];
                  return ListTile(
                    leading: Image.asset(
                      'assets/sprites/${target.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll("'", "_")}.png',
                      width: 32,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.pets, color: Colors.white24),
                    ),
                    title: Text(
                      target.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      target.equippedTalisman?.name ?? 'NO ITEM',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 7,
                        color: Colors.white54,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      userState.swapRogueTalismans(index, idx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
