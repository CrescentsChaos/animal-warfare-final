// lib/animal_box_screen.dart
// Screen where the user can view captured animals and choose which one is the battle attacker.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/widgets/item_icon.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/widgets/animal_summary_screen.dart';
import 'dart:async';

class AnimalBoxScreen extends StatefulWidget {
  const AnimalBoxScreen({super.key});

  @override
  State<AnimalBoxScreen> createState() => _AnimalBoxScreenState();
}

class _AnimalBoxScreenState extends State<AnimalBoxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  Timer? _debounce;

  static const List<String> _predefinedCategories = [
    "Earth",
    "Basic",
    "Aquatic",
    "Cryo",
    "Blaze",
    "Rock",
    "Toxic",
    "Arthropod",
    "Electric",
    "Flying",
    "Grass",
    "Darkness",
    "Martial",
    "Metal",
    "Mystic",
    "Drake",
    "Spectral",
    "Aura",
    "Sound",
    "Holy",
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Animal Box'),
          backgroundColor: AppColors.secondaryButtonColor,
          bottom: const TabBar(
            indicatorColor: AppColors.highlightColor,
            labelStyle: TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
            tabs: [
              Tab(text: 'Box', icon: Icon(Icons.inventory)),
              Tab(text: 'Team', icon: Icon(Icons.groups)),
            ],
          ),
        ),
        body: Consumer<UserState>(
          builder: (context, userState, _) {
            final user = userState.currentUser;
            if (user == null) {
              return const Center(child: Text('Not logged in.'));
            }

            return Column(
              children: [
                _buildAccountHeader(user),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBoxView(user, userState),
                      _buildTeamView(user, userState),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountHeader(UserData user) {
    final nextLevelXP = (user.accountLevel + 1) * (user.accountLevel + 1) * 100;
    final progress = (user.accountXP / nextLevelXP).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryButtonColor,
        border: Border(
          bottom: BorderSide(color: AppColors.highlightColor.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACCOUNT RANK: ${user.accountLevel}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: AppColors.highlightColor,
                ),
              ),
              Text(
                '${user.accountXP} / $nextLevelXP XP',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: Colors.blueAccent,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxView(UserData user, UserState userState) {
    final captured = user.capturedOrganisms;
    if (captured.isEmpty) {
      return _buildEmptyState();
    }

    final filtered = captured.asMap().entries.where((entry) {
      final org = entry.value;
      final matchesSearch = org.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategory == null ||
          org.baseOrganism.category.toLowerCase().contains(
            _selectedCategory!.toLowerCase(),
          );
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final entry = filtered[index];
              final org = entry.value;
              final originalIndex = entry.key;
              final isInTeam = user.battleTeam.contains(originalIndex);
              return _AnimalCard(
                captured: org,
                index: originalIndex,
                isInTeam: isInTeam,
                isNarrow: MediaQuery.sizeOf(context).width < 400,
                isNew:
                    captured.length > 3 && originalIndex >= captured.length - 3,
                onTap: () => _showAnimalDetails(context, org, originalIndex),
                onToggleTeam: () async {
                  final success = await userState.toggleTeamMember(
                    originalIndex,
                  );
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Team is full (Max 5)!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                onManageMoves: () =>
                    _showMoveSelection(context, org, originalIndex),
                onEquip: () => _showTalismanSelector(
                  context,
                  userState,
                  originalIndex,
                  org,
                ),
                onRelease: () =>
                    _confirmRelease(context, org, originalIndex, userState),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamView(UserData user, UserState userState) {
    final teamIndices = user.battleTeam;
    if (teamIndices.isEmpty) {
      return _buildEmptyTeamState();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: teamIndices.length,
      onReorder: (oldIndex, newIndex) {
        userState.reorderBattleTeam(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final originalIndex = teamIndices[index];
        if (originalIndex < 0 ||
            originalIndex >= user.capturedOrganisms.length) {
          return SizedBox.shrink(key: ValueKey('empty_team_$index'));
        }
        final org = user.capturedOrganisms[originalIndex];

        return _AnimalCard(
          key: ValueKey('team_card_$originalIndex'),
          captured: org,
          index: originalIndex,
          isInTeam: true,
          isNarrow: MediaQuery.sizeOf(context).width < 400,
          isNew: false,
          onTap: () => _showAnimalDetails(context, org, originalIndex),
          onToggleTeam: () => userState.toggleTeamMember(originalIndex),
          onManageMoves: () => _showMoveSelection(context, org, originalIndex),
          onEquip: () =>
              _showTalismanSelector(context, userState, originalIndex, org),
          onRelease: () =>
              _confirmRelease(context, org, originalIndex, userState),
        );
      },
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() => _searchQuery = val);
                });
              },
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 10),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white54,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[850],
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<UserState>(
            builder: (context, userState, _) {
              final user = userState.currentUser;
              if (user == null) return const SizedBox.shrink();

              return DropdownButton<String>(
                value: _selectedCategory,
                hint: const Text(
                  'Cat',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                dropdownColor: Colors.grey[850],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ..._predefinedCategories.map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.toUpperCase()),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.catching_pokemon_outlined,
            size: 80,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            'The wild remains untamed.\nNo monsters captured yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontFamily: 'PressStart2P',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTeamState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Your vanguard is empty.\nDraft up to 5 monsters to your team from the Box.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontFamily: 'PressStart2P',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRelease(
    BuildContext context,
    CapturedOrganism org,
    int index,
    UserState userState,
  ) async {
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
    if (confirmed == true) {
      await userState.releaseOrganism(index);
    }
  }

  void _showAnimalDetails(
    BuildContext context,
    CapturedOrganism captured,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _AnimalDetailsDialog(captured: captured, index: index),
    );
  }

  void _showMoveSelection(
    BuildContext context,
    CapturedOrganism captured,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _MoveSelectionDialog(captured: captured, index: index),
    );
  }

  void _showTalismanSelector(
    BuildContext context,
    UserState userState,
    int index,
    CapturedOrganism organism,
  ) {
    final craftedTalismans = userState.currentUser?.craftedTalismans ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.secondaryButtonColor,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SELECT TALISMAN',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: AppColors.highlightColor,
                ),
              ),
              const SizedBox(height: 16),
              if (organism.equippedTalisman != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle, color: Colors.red),
                  title: const Text(
                    'UNEQUIP',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  onTap: () async {
                    await userState.equipTalisman(index, null);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              if (craftedTalismans.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'NO TALISMANS AVAILABLE',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              else
                ...craftedTalismans.toSet().map((tid) {
                  final t = Talisman.findById(tid);
                  final count = craftedTalismans
                      .where((id) => id == tid)
                      .length;
                  return ListTile(
                    leading: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.highlightColor,
                    ),
                    title: Text(
                      t?.name ?? tid,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      'Count: x$count',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                    onTap: () async {
                      await userState.equipTalisman(index, tid);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final CapturedOrganism captured;
  final int index;
  final bool isInTeam;
  final bool isNarrow;
  final bool isNew;
  final VoidCallback onTap;
  final VoidCallback onToggleTeam;
  final VoidCallback onManageMoves;
  final VoidCallback onEquip;
  final VoidCallback onRelease;

  const _AnimalCard({
    super.key,
    required this.captured,
    required this.index,
    required this.isInTeam,
    required this.isNarrow,
    this.isNew = false,
    required this.onTap,
    required this.onToggleTeam,
    required this.onManageMoves,
    required this.onEquip,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final base = captured.baseOrganism;
    final spriteSize = isNarrow ? 80.0 : 100.0;

    List<BoxShadow>? rarityGlow;
    if (base.rarity.toLowerCase() == 'legendary') {
      rarityGlow = [
        BoxShadow(
          color: Colors.orange.withOpacity(0.5),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (base.rarity.toLowerCase() == 'mythical') {
      rarityGlow = [
        BoxShadow(
          color: Colors.purple.withOpacity(0.5),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (base.rarity.toLowerCase() == 'epic' ||
        base.rarity.toLowerCase() == 'elite') {
      rarityGlow = [
        BoxShadow(
          color: Colors.purpleAccent.withOpacity(0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        boxShadow:
            rarityGlow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
        border: Border.all(
          color: isInTeam ? Colors.blue[300]! : Colors.grey[700]!,
          width: isInTeam ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'animal_box_sprite_$index',
                  child: _AnimalBoxSprite(organism: base, size: spriteSize),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              base.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'PressStart2P',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isNew)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontFamily: 'PressStart2P',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (isInTeam)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TEAM',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontFamily: 'PressStart2P',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: base.category.split(',').map((cat) {
                          final typeStr = cat.trim().toLowerCase();
                          final type = ElementalType.values.firstWhere(
                            (e) => e.toString().split('.').last == typeStr,
                            orElse: () => ElementalType.basic,
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getAnimalTypeColor(type),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              cat.trim().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontFamily: 'PressStart2P',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'LV.${captured.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value:
                                    (captured.xp /
                                            CapturedOrganism.xpForLevel(
                                              captured.level + 1,
                                            ))
                                        .clamp(0.0, 1.0),
                                backgroundColor: Colors.white10,
                                color: Colors.greenAccent,
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HP: ${captured.currentHealth}/${captured.maxHealth}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (captured.equippedTalisman != null) ...[
                            ItemIcon(
                              itemName: captured.equippedTalisman!.name,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            captured.equippedTalisman != null
                                ? captured.equippedTalisman!.name
                                : 'No Item',
                            style: TextStyle(
                              color: captured.equippedTalisman != null
                                  ? AppColors.highlightColor
                                  : Colors.grey[500],
                              fontSize: 9,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildActions(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _SmallActionBtn(
          label: 'MOVES',
          color: AppColors.secondaryButtonColor,
          onPressed: onManageMoves,
          isOutlined: true,
          textColor: AppColors.highlightColor,
        ),
        _SmallActionBtn(
          label: captured.equippedTalisman != null ? 'CHANGE' : 'EQUIP',
          color: AppColors.secondaryButtonColor,
          onPressed: onEquip,
          isOutlined: true,
          textColor: Colors.blueAccent,
        ),
        _SmallActionBtn(
          label: isInTeam ? 'REMOVE' : 'ADD TEAM',
          color: isInTeam ? Colors.blue[700]! : Colors.blue[400]!,
          onPressed: onToggleTeam,
        ),
        _SmallActionBtn(
          label: 'SUMMARY',
          color: AppColors.secondaryButtonColor,
          onPressed: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  AnimalSummaryScreen(captured: captured),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 250),
            ),
          ),
          isOutlined: true,
          textColor: Colors.orange,
        ),
        _SmallActionBtn(
          label: 'RELEASE',
          color: Colors.transparent,
          textColor: Colors.red[300],
          onPressed: onRelease,
          isOutlined: true,
        ),
      ],
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final Color? textColor;

  const _SmallActionBtn({
    required this.label,
    required this.color,
    this.onPressed,
    this.isOutlined = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        height: 24,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: textColor ?? color),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontFamily: 'PressStart2P',
              color: textColor,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 24,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 8, fontFamily: 'PressStart2P'),
        ),
      ),
    );
  }
}

class _AnimalDetailsDialog extends StatelessWidget {
  final CapturedOrganism captured;
  final int index;

  const _AnimalDetailsDialog({required this.captured, required this.index});

  @override
  Widget build(BuildContext context) {
    final base = captured.baseOrganism;
    final ivs = captured.individualValues;

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.secondaryButtonColor,
        child: Row(
          children: [
            Hero(
              tag: 'animal_box_sprite_$index',
              child: _AnimalBoxSprite(organism: base, size: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    base.name,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    base.scientificName,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (captured.equippedTalisman != null) ...[
              _buildStatHeader('HELD ITEM'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars,
                      size: 14,
                      color: AppColors.highlightColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      captured.equippedTalisman!.name,
                      style: const TextStyle(
                        color: AppColors.highlightColor,
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
            ],
            _buildStatHeader('GENETIC DNA (GVs)'),
            const SizedBox(height: 8),
            _buildStatRow('HP GV', ivs['health'] ?? 0),
            _buildStatRow('ATK GV', ivs['attack'] ?? 0),
            _buildStatRow('DEF GV', ivs['defense'] ?? 0),
            _buildStatRow('PWR GV', ivs['power'] ?? 0),
            _buildStatRow('RES GV', ivs['resistance'] ?? 0),
            _buildStatRow('SPD GV', ivs['speed'] ?? 0),
            const Divider(color: Colors.grey),
            _buildStatHeader('EFFECTIVE STATS'),
            const SizedBox(height: 4),
            const Text(
              'LV 50 BATTLE SCALE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 4),
            _buildNatureHeader(captured.nature),
            const SizedBox(height: 6),
            _buildEffectiveStatRow(
              'HP',
              captured.getMaxHealth(atLevel: 50),
              _getNatureColor('health', captured.nature),
            ),
            _buildEffectiveStatRow(
              'Attack',
              captured.getAttack(atLevel: 50),
              _getNatureColor('attack', captured.nature),
            ),
            _buildEffectiveStatRow(
              'Defense',
              captured.getDefense(atLevel: 50),
              _getNatureColor('defense', captured.nature),
            ),
            _buildEffectiveStatRow(
              'Power',
              captured.getPower(atLevel: 50),
              _getNatureColor('power', captured.nature),
            ),
            _buildEffectiveStatRow(
              'Resistance',
              captured.getResistance(atLevel: 50),
              _getNatureColor('resistance', captured.nature),
            ),
            _buildEffectiveStatRow(
              'Speed',
              captured.getSpeed(atLevel: 50),
              _getNatureColor('speed', captured.nature),
            ),
            const SizedBox(height: 16),
            _buildStatHeader('SELECTED MOVES'),
            const SizedBox(height: 8),
            ...captured.selectedMoveNames.map((mn) {
              final move = Move.findByName(mn);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mn,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'PressStart2P',
                            color: AppColors.highlightColor,
                          ),
                        ),
                        if (move != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: move.category.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              move.category.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 6,
                                fontFamily: 'PressStart2P',
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (move != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'DMG: ${move.baseDamage} TYPE: ${move.type.name.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 7,
                          fontFamily: 'PressStart2P',
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(
              color: AppColors.highlightColor,
              fontFamily: 'PressStart2P',
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontFamily: 'PressStart2P',
        color: Colors.white54,
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    // Determine color based on IV quality
    Color color = Colors.grey;
    if (value >= 31) {
      color = Colors.orange;
    } else if (value >= 25)
      color = Colors.greenAccent;
    else if (value >= 15)
      color = Colors.blueAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontFamily: 'PressStart2P'),
          ),
          Text(
            '$value / 31',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'PressStart2P',
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNatureHeader(Nature nature) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        'Nature: ${nature.name}',
        style: const TextStyle(
          fontSize: 10,
          fontFamily: 'PressStart2P',
          color: AppColors.highlightColor,
        ),
      ),
    );
  }

  Color _getNatureColor(String statName, Nature nature) {
    final mult = nature.getMultiplier(statName);
    if (mult > 1.0) return Colors.orange;
    if (mult < 1.0) return Colors.cyan;
    return Colors.white;
  }

  Widget _buildEffectiveStatRow(
    String label,
    int value, [
    Color color = Colors.white,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontFamily: 'PressStart2P'),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'PressStart2P',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveSelectionDialog extends StatefulWidget {
  final CapturedOrganism captured;
  final int index;

  const _MoveSelectionDialog({required this.captured, required this.index});

  @override
  State<_MoveSelectionDialog> createState() => _MoveSelectionDialogState();
}

class _MoveSelectionDialogState extends State<_MoveSelectionDialog> {
  late List<String> _selectedMoves;
  late List<String> _allPossibleMoves;

  @override
  void initState() {
    super.initState();
    _selectedMoves = List<String>.from(widget.captured.selectedMoveNames);
    _allPossibleMoves = widget.captured.baseOrganism.moves
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _toggleMove(String moveName) {
    setState(() {
      if (_selectedMoves.contains(moveName)) {
        if (_selectedMoves.length > 1) {
          _selectedMoves.remove(moveName);
        }
      } else {
        if (_selectedMoves.length < 4) {
          _selectedMoves.add(moveName);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.secondaryButtonColor,
      title: const Text(
        'Select Moves (Max 4)',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: AppColors.highlightColor,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _allPossibleMoves.length,
          itemBuilder: (ctx, i) {
            final moveName = _allPossibleMoves[i];
            final isSelected = _selectedMoves.contains(moveName);
            final move = Move.findByName(moveName);

            return CheckboxListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      moveName,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (move != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: move.category.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        move.category.name.substring(0, 4).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 6,
                          fontFamily: 'PressStart2P',
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: move != null
                  ? Text(
                      'DMG: ${move.baseDamage}, STAMINA: ${move.stamina}, TYPE: ${move.type.name.toUpperCase()}',
                      style: TextStyle(fontSize: 8, color: Colors.grey[400]),
                    )
                  : null,
              value: isSelected,
              onChanged: (_) => _toggleMove(moveName),
              activeColor: AppColors.highlightColor,
              checkColor: Colors.black,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            final userState = Provider.of<UserState>(context, listen: false);
            await userState.updateCapturedOrganismMoves(
              widget.index,
              _selectedMoves,
            );
            if (context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryButtonColor,
          ),
          child: const Text(
            'Save',
            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
          ),
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
  void didUpdateWidget(_AnimalBoxSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.organism.name != oldWidget.organism.name ||
        widget.organism.sprite != oldWidget.organism.sprite) {
      _determineImageSource();
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
                width: 16,
                height: 16,
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
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: size,
                    height: size,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.pets,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

Color _getAnimalTypeColor(ElementalType type) {
  switch (type) {
    case ElementalType.basic:
      return const Color.fromARGB(255, 168, 168, 130);
    case ElementalType.flying:
      return const Color(0xFFA98FF3);
    case ElementalType.aquatic:
      return const Color.fromARGB(255, 46, 60, 255);
    case ElementalType.earth:
      return const Color(0xFFE2BF65);
    case ElementalType.cryo:
      return const Color.fromARGB(255, 0, 247, 255);
    case ElementalType.toxic:
      return const Color(0xFFA33EA1);
    case ElementalType.rock:
      return const Color.fromARGB(255, 158, 97, 5);
    case ElementalType.arthropod:
      return const Color.fromARGB(255, 111, 207, 0);
    case ElementalType.electric:
      return const Color.fromARGB(255, 255, 251, 27);
    case ElementalType.spectral:
      return const Color.fromARGB(255, 91, 11, 240);
    case ElementalType.martial:
      return const Color.fromARGB(255, 160, 24, 0);
    case ElementalType.blaze:
      return const Color.fromARGB(255, 226, 72, 0);
    case ElementalType.grass:
      return const Color.fromARGB(255, 22, 131, 0);
    case ElementalType.mystic:
      return const Color.fromARGB(255, 255, 81, 162);
    case ElementalType.darkness:
      return const Color.fromARGB(255, 37, 36, 37);
    case ElementalType.drake:
      return const Color.fromARGB(255, 76, 0, 255);
    case ElementalType.metal:
      return const Color.fromARGB(255, 172, 168, 168);
    case ElementalType.aura:
      return const Color.fromARGB(255, 229, 255, 79);
    case ElementalType.sound:
      return const Color.fromARGB(255, 166, 70, 255);
    case ElementalType.holy:
      return const Color.fromARGB(255, 255, 208, 0);
  }
}
