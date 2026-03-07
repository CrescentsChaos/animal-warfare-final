// lib/rogue/rogue_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/data/biome_data.dart';
import 'package:animal_warfare/models/rogue_like_state.dart';
import 'package:animal_warfare/rogue/rogue_reward_dialog.dart';
import 'package:animal_warfare/widgets/animal_summary_screen.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/rogue/move_manage_screen.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:google_fonts/google_fonts.dart';

class RogueHubScreen extends StatefulWidget {
  const RogueHubScreen({super.key});

  @override
  State<RogueHubScreen> createState() => _RogueHubScreenState();
}

class _RogueHubScreenState extends State<RogueHubScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _checkForRewards() {
    final userState = Provider.of<UserState>(context, listen: false);
    final rogue = userState.currentUser?.rogueLikeState;
    if (rogue != null &&
        rogue.pendingRewards != null &&
        rogue.pendingRewards!.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => RogueRewardDialog(
          rewards: rogue.pendingRewards!,
          biome: rogue.currentBiome ?? 'Jungle',
          onSelect: (reward) {
            userState.claimRogueReward(reward);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserState>(
      builder: (context, userState, _) {
        final rogue = userState.currentUser?.rogueLikeState;
        if (rogue == null || !rogue.isActive) {
          return const Scaffold(body: Center(child: Text('No active run')));
        }

        final Color themeColor = BiomeData.colorFor(
          rogue.currentBiome ?? 'Jungle',
        );

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: Stack(
            children: [
              // Background Image with darkening overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.4,
                  child: Image.asset(
                    'assets/biomes/${(rogue.currentBiome ?? 'Jungle').toLowerCase()}.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.black),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(rogue, themeColor),
                    _buildStatusBar(rogue.team, themeColor),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: const _RogueTeamList(),
                      ),
                    ),
                    _buildControls(context, userState, themeColor),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(RogueLikeState rogue, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'RUN PROGRESS',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          color: themeColor.withValues(alpha: 0.7),
                          fontSize: 8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${rogue.currentBiome?.toUpperCase() ?? 'REGION'}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'FLOOR',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    color: themeColor.withValues(alpha: 0.7),
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rogue.floor}',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
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
                  color: Colors.white.withValues(alpha: 0.5),
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              color: themeColor,
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    UserState userState,
    Color themeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  label: 'SAVE & EXIT',
                  icon: Icons.save,
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  label: 'INVENTORY',
                  icon: Icons.inventory_2,
                  color: Colors.amberAccent.withValues(alpha: 0.2),
                  onPressed: () => _showRogueInventory(context, userState),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  label: 'ABANDON',
                  icon: Icons.exit_to_app,
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: const Text(
                          'ABANDON RUN',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                        content: const Text(
                          'All progress in this run will be lost! Are you sure?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () {
                              userState.endRogueRun();
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'ABANDON',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.02).animate(_pulseController),
                  child: _buildActionButton(
                    context,
                    label: 'BATTLE',
                    icon: Icons.flash_on,
                    color: themeColor,
                    isPrimary: true,
                    onPressed: () => _startNextBattle(context, userState),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRogueInventory(BuildContext context, UserState userState) {
    final rogueState = userState.currentUser?.rogueLikeState;
    if (rogueState == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'YOUR INVENTORY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: Colors.amberAccent,
                ),
              ),
            ),
            Expanded(
              child: rogueState.inventory.isEmpty
                  ? const Center(
                      child: Text(
                        'EMPTY INVENTORY',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    )
                  : ListView(
                      children: rogueState.inventory.entries.map((entry) {
                        return ListTile(
                          leading: Icon(
                            _getIconForAnyItem(entry.key),
                            color: Colors.amberAccent,
                          ),
                          title: Text(
                            entry.key.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'x${entry.value}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'PressStart2P',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  IconData _getIconForAnyItem(String itemId) {
    if (itemId.contains('talisman')) return Icons.vpn_key;
    if (itemId.contains('berry')) return Icons.eco;
    if (itemId.contains('mint')) return Icons.refresh;
    return Icons.inventory;
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
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: isPrimary ? 12 : 10,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: isPrimary ? 12 : 0,
          shadowColor: isPrimary
              ? color.withValues(alpha: 0.5)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: Colors.white10),
          ),
        ),
        onPressed: onPressed,
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
              'FLOOR ${rogue.floor} - STAGE ${rogue.encounterIndex + 1}/5',
          timeOfDay: 'Day',
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

    if (team.isEmpty) return const SizedBox();

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
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
    final userState = Provider.of<UserState>(context, listen: false);
    final biomeName =
        userState.currentUser?.rogueLikeState.currentBiome ?? 'Jungle';
    final Color themeColor = BiomeData.colorFor(biomeName);
    final hpRatio = member.currentHealth / member.maxHealth;
    final isFainted = member.currentHealth <= 0;

    return Container(
      key: ValueKey(member.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFainted
              ? Colors.redAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showContextMenu(context, userState),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildSprite(member),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            member.nickname ?? member.name.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: isFainted ? Colors.white38 : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LV ${member.level}',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                color: themeColor,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // HP Bar
                      _buildMiniBar(
                        label: 'HP',
                        value: hpRatio,
                        color: _getHpColor(hpRatio),
                        trailing: '${member.currentHealth}/${member.maxHealth}',
                      ),
                      const SizedBox(height: 6),
                      // XP Bar
                      _buildMiniBar(
                        label: 'XP',
                        value: member.xpRatio,
                        color: Colors.blueAccent,
                        trailing: '${(member.xpRatio * 100).toInt()}%',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.drag_handle, color: Colors.white12, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSprite(CapturedOrganism member) {
    final isFainted = member.currentHealth <= 0;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Opacity(
        opacity: isFainted ? 0.3 : 1.0,
        child: ColorFiltered(
          colorFilter: isFainted
              ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
          child: Image.asset(
            'assets/sprites/${member.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}.png',
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.pets, color: Colors.white24),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBar({
    required String label,
    required double value,
    required Color color,
    required String trailing,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                color: color.withValues(alpha: 0.8),
                fontSize: 7,
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                color: Colors.white38,
                fontSize: 6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: Colors.white10,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getHpColor(double ratio) {
    if (ratio > 0.5) return Colors.greenAccent;
    if (ratio > 0.2) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  void _showContextMenu(BuildContext context, UserState userState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF151525),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  _buildSprite(member),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.nickname ?? member.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'LV.${member.level} ${member.baseOrganism.name}',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildContextOption(
              context,
              icon: Icons.bar_chart,
              label: 'SUMMARY',
              color: Colors.greenAccent,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => AnimalSummaryScreen(captured: member),
                  ),
                );
              },
            ),
            _buildContextOption(
              context,
              icon: Icons.bolt,
              label: 'MOVES',
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => MoveManageScreen(organismIndex: index),
                  ),
                );
              },
            ),
            _buildContextOption(
              context,
              icon: Icons.stars,
              label: 'MANAGE ITEMS',
              color: Colors.amberAccent,
              onTap: () {
                Navigator.pop(ctx);
                _showRogueItemSelection(context, userState);
              },
            ),
            _buildContextOption(
              context,
              icon: Icons.delete_forever,
              label: 'RELEASE',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(ctx);
                _showReleaseConfirmation(context, userState);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContextOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReleaseConfirmation(BuildContext context, UserState userState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'RELEASE ANIMAL',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Are you sure you want to release ${member.name}? This will remove it from your Rogue team permanently!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              userState.releaseFromRogueRun(index);
              Navigator.pop(ctx);
            },
            child: const Text(
              'RELEASE',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showRogueItemSelection(BuildContext context, UserState userState) {
    final rogueState = userState.currentUser?.rogueLikeState;
    if (rogueState == null) return;

    final inventoryEntries = rogueState.inventory.entries
        .where((e) => e.value > 0)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'MANAGE ITEMS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: Colors.amberAccent,
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  if (member.equippedTalisman != null)
                    ListTile(
                      leading: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        'REMOVE: ${member.equippedTalisman!.name.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        userState.removeRogueTalisman(index);
                      },
                    ),
                  if (member.equippedTalisman != null)
                    const Divider(color: Colors.white10),
                  Expanded(
                    child: inventoryEntries.isEmpty
                        ? const Center(
                            child: Text(
                              'NO ITEMS IN INVENTORY',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: inventoryEntries.length,
                            itemBuilder: (context, i) {
                              final entry = inventoryEntries[i];
                              final itemId = entry.key;
                              final count = entry.value;

                              return ListTile(
                                leading: Icon(
                                  _getIconForItemById(itemId),
                                  color: Colors.amberAccent,
                                ),
                                title: Text(
                                  itemId.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'In stock: $count',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  if (itemId.contains('talisman')) {
                                    userState.equipRogueTalisman(index, itemId);
                                  } else if (itemId.contains('berry')) {
                                    userState.applyRogueBerry(index, itemId);
                                  } else if (itemId == 'nature_mint') {
                                    _showNatureSelection(context, userState);
                                  } else if (itemId.startsWith(
                                    'nature_mint_',
                                  )) {
                                    final natureName = itemId.replaceFirst(
                                      'nature_mint_',
                                      '',
                                    );
                                    final nature = Nature.allNatures.firstWhere(
                                      (n) => n.name.toLowerCase() == natureName,
                                    );
                                    userState.changeRogueAnimalNature(
                                      index,
                                      nature,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showNatureSelection(BuildContext context, UserState userState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'SELECT NATURE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: Colors.cyanAccent,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: Nature.allNatures.length,
                itemBuilder: (context, i) {
                  final n = Nature.allNatures[i];
                  return ListTile(
                    title: Text(
                      n.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    subtitle: Text(
                      '+${n.increasedStat.name.toUpperCase()} / -${n.decreasedStat.name.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      userState.changeRogueAnimalNature(index, n);
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

  IconData _getIconForItemById(String itemId) {
    if (itemId.contains('talisman')) return Icons.vpn_key;
    if (itemId.contains('berry')) return Icons.eco;
    if (itemId.contains('mint')) return Icons.refresh;
    return Icons.inventory;
  }
}
