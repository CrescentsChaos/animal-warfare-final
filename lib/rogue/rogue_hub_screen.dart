import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/rogue/move_manage_screen.dart';
import 'package:animal_warfare/data/biome_data.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/rogue/rogue_reward_dialog.dart';
import 'package:animal_warfare/widgets/animal_summary_screen.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/rogue_like_state.dart';
import 'package:animal_warfare/rogue/biome_select_screen.dart';

class RogueHubScreen extends StatefulWidget {
  const RogueHubScreen({super.key});

  @override
  State<RogueHubScreen> createState() => _RogueHubScreenState();
}

class _RogueHubScreenState extends State<RogueHubScreen> {
  @override
  void initState() {
    super.initState();
    _checkForRewards();
  }

  void _checkForRewards() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userState = Provider.of<UserState>(context, listen: false);
      final rewards = userState.currentUser?.rogueLikeState.pendingRewards;

      if (rewards != null && rewards.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => RogueRewardDialog(
            rewards: rewards,
            biome:
                userState.currentUser?.rogueLikeState.currentBiome ?? 'Jungle',
            onSelect: (reward) async {
              if (reward.type == RogueRewardType.singleHeal) {
                final targetIndex = await _showAnimalSelection(context);
                if (targetIndex != null) {
                  userState.claimRogueReward(
                    reward.copyWith(targetIndex: targetIndex),
                  );
                }
              } else {
                userState.claimRogueReward(reward);
              }
            },
          ),
        );
      }
    });
  }

  String _getAssetPath(String biomeName) {
    var name = biomeName;
    if (name.contains(',')) {
      name = name.split(',')[0];
    }
    name = name.trim().toLowerCase();
    if (name == 'forest') return 'assets/biomes/jungle-bg.png';
    if (name == 'rain forest' || name == 'rainforest') {
      return 'assets/biomes/rainforest-bg.png';
    }
    if (name == 'grassland') return 'assets/biomes/savanna-bg.png';
    final fileName = name.replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) return 'day';
    if (hour >= 18 && hour < 21) return 'evening';
    return 'night';
  }

  void _advanceFloor(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BiomeSelectScreen()));
  }

  Future<int?> _showAnimalSelection(BuildContext context) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final team = userState.currentUser?.rogueLikeState.team ?? [];

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text(
          'CHOOSE ANIMAL TO HEAL',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: Colors.white,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: team.length,
            itemBuilder: (context, index) {
              final member = team[index];
              final hpRatio = member.currentHealth / member.maxHealth;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(member.baseOrganism.sprite),
                ),
                title: Text(
                  member.baseOrganism.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'HP: ${member.currentHealth}/${member.maxHealth}',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                    color: hpRatio < 0.3
                        ? Colors.redAccent
                        : Colors.greenAccent,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(index),
              );
            },
          ),
        ),
      ),
    );
  }

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
            image: AssetImage(_getAssetPath(biomeName)),
            fit: BoxFit.cover,
            colorFilter: _getTimeOfDay() == 'day'
                ? ColorFilter.mode(
                    Colors.black.withOpacity(0.75),
                    BlendMode.darken,
                  )
                : ColorFilter.mode(
                    _getTimeOfDay() == 'evening'
                        ? Colors.orangeAccent.withOpacity(0.3)
                        : Colors.indigo[900]!.withOpacity(0.5),
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

              const SizedBox(height: 12),

              // Inventory Summary
              _buildInventoryBar(rogueState.inventory, themeColor),

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
                        label: rogueState.encounterIndex >= 5
                            ? 'ADVANCE TO NEXT FLOOR'
                            : 'START NEXT BATTLE',
                        icon: rogueState.encounterIndex >= 5
                            ? Icons.arrow_forward
                            : Icons.flash_on,
                        color: rogueState.encounterIndex >= 5
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        isPrimary: true,
                        onPressed: () => rogueState.encounterIndex >= 5
                            ? _advanceFloor(context)
                            : _startNextBattle(context, userState),
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

  Widget _buildInventoryBar(Map<String, int> inventory, Color themeColor) {
    final items = inventory.entries.where((e) => e.value > 0).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RUN INVENTORY',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              color: Colors.white.withOpacity(0.5),
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map((e) => _buildInventoryItem(e.key, e.value, themeColor))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(String id, int count, Color themeColor) {
    String label = id.replaceAll('_', ' ').toUpperCase();
    if (id == 'capture_net') label = 'NET';

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_bag_outlined, size: 12, color: themeColor),
          const SizedBox(width: 6),
          Text(
            '$label x$count',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 7,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  void _startNextBattle(BuildContext context, UserState userState) async {
    final rogue = userState.currentUser!.rogueLikeState;
    if (rogue.team.isEmpty || (rogue.opponentTeam?.isEmpty ?? true)) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: rogue.team[0],
          opponentOrganism: rogue.opponentTeam![0],
          playerTeam: rogue.team,
          opponentTeam: rogue.opponentTeam,
          isRogueMode: true,
          biomeName: rogue.currentBiome ?? 'Jungle',
          battleTitle:
              'Rogue Floor ${rogue.floor} - ${rogue.encounterIndex + 1}/5',
          timeOfDay: _getTimeOfDay(),
        ),
      ),
    );
    if (mounted) _checkForRewards();
  }
}

class _RogueTeamList extends StatelessWidget {
  const _RogueTeamList();

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final team = userState.currentUser?.rogueLikeState.team ?? [];

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: team.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final newList = List<CapturedOrganism>.from(team);
        final item = newList.removeAt(oldIndex);
        newList.insert(newIndex, item);
        userState.updateRogueTeam(newList);
      },
      itemBuilder: (context, index) => _RogueTeamCard(
        key: ValueKey(team[index].id),
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
    super.key,
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
                            const Spacer(),
                            Text(
                              'LV.${member.level}',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                color: themeColor,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.drag_indicator,
                              color: Colors.white24,
                              size: 16,
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
                // Action buttons
                _buildSmallAction(
                  context,
                  'SUMMARY',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => AnimalSummaryScreen(captured: member),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                label: 'VIEW SUMMARY',
                icon: Icons.info_outline,
                color: Colors.orangeAccent.withOpacity(0.8),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => AnimalSummaryScreen(captured: member),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
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
                label: 'GIVE ITEM',
                icon: Icons.add_circle_outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  _showItemSelection(context);
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
                label: 'USE NATURE MINT',
                icon: Icons.spa,
                enabled:
                    (Provider.of<UserState>(context, listen: false)
                            .currentUser
                            ?.rogueLikeState
                            .inventory['nature_mint'] ??
                        0) >
                    0,
                color: Colors.greenAccent.withOpacity(0.8),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showNatureSelection(context);
                },
              ),
              const SizedBox(height: 12),
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

  void _showNatureSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final natures = Nature.allNatures;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text(
                  'SELECT NEW NATURE',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Consumes 1 Nature Mint',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: natures.length,
                    itemBuilder: (context, i) {
                      final n = natures[i];
                      final isNeutral = n.increasedStat == n.decreasedStat;
                      return ListTile(
                        title: Text(
                          n.name,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          isNeutral
                              ? 'Neutral'
                              : '+${n.increasedStat.name.toUpperCase()} / -${n.decreasedStat.name.toUpperCase()}',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 6,
                            color: isNeutral ? Colors.white38 : Colors.amber,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Provider.of<UserState>(
                            context,
                            listen: false,
                          ).changeRogueAnimalNature(index, n);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${member.name}\'s nature changed to ${n.name}!',
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 8,
                                ),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  void _showItemSelection(BuildContext context) {
    final userState = Provider.of<UserState>(context, listen: false);
    final inv = userState.currentUser!.rogueLikeState.inventory;

    final talismanIds = inv.keys
        .where((id) => Talisman.findById(id) != null)
        .toList();

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
                'GIVE ITEM...',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
            if (talismanIds.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Text(
                  'NO ITEMS IN POCKET',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Colors.white24,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: talismanIds.length,
                  itemBuilder: (context, idx) {
                    final tid = talismanIds[idx];
                    final talisman = Talisman.findById(tid)!;
                    final count = inv[tid];
                    return ListTile(
                      title: Text(
                        '${talisman.name.toUpperCase()} x$count',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        talisman.description,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 7,
                          color: Colors.white54,
                          height: 1.5,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        userState.equipRogueTalisman(index, tid);
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
