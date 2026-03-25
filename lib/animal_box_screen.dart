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
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/widgets/animal_summary_screen.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'dart:async';

class AnimalBoxScreen extends StatefulWidget {
  final bool teamOnly;
  const AnimalBoxScreen({super.key, this.teamOnly = false});

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
    if (widget.teamOnly) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Animal Party'),
          backgroundColor: AppColors.surface,
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
                Expanded(child: _buildTeamView(user, userState)),
              ],
            );
          },
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Animal Storage'),
          backgroundColor: AppColors.surface,
          bottom: const TabBar(
            indicatorColor: AppColors.highlightColor,
            labelStyle: TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
            tabs: [
              Tab(text: 'Team', icon: Icon(Icons.groups)),
              Tab(text: 'Box', icon: Icon(Icons.inventory)),
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
                      _buildTeamView(user, userState),
                      _buildBoxView(user, userState),
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
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.highlightColor.withValues(alpha: 0.3),
          ),
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
    // Filter out animals that are in the team
    final teamSet = user.battleTeam.toSet();
    final captured = user.capturedOrganisms;
    if (captured.isEmpty) {
      return _buildEmptyState();
    }

    final filtered = captured.asMap().entries.where((entry) {
      if (teamSet.contains(entry.key)) return false; // Skip team members
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
                onManageItems: () =>
                    _showItemSelection(context, userState, originalIndex, org),
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
          onManageItems: () =>
              _showItemSelection(context, userState, originalIndex, org),
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
            'The wild remains untamed.\nNo animals captured yet.',
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
              'Your vanguard is empty.\nDraft up to 5 animals to your team from the Box.',
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
    final inventory = userState.currentUser?.inventory ?? {};

    // Build a combined map of talismanId -> count (from both crafted list and shop inventory)
    final Map<String, int> availableMap = {};
    for (final tid in craftedTalismans) {
      if (Talisman.findById(tid) != null) {
        availableMap[tid] = (availableMap[tid] ?? 0) + 1;
      }
    }
    for (final entry in inventory.entries) {
      if (entry.value > 0 && Talisman.findById(entry.key) != null) {
        // Add inventory items (may overlap with crafted; either way show max)
        availableMap[entry.key] = (availableMap[entry.key] ?? 0) + entry.value;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
              if (availableMap.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'NO TALISMANS AVAILABLE',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: availableMap.entries.map((entry) {
                        final tid = entry.key;
                        final count = entry.value;
                        final t = Talisman.findById(tid)!;
                        return ListTile(
                          leading: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.highlightColor,
                          ),
                          title: Text(
                            t.name,
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
                            if (tid == 'Ability Capsule') {
                              Navigator.pop(ctx);
                              _showAbilitySelectionDialog(
                                context,
                                userState,
                                index,
                                organism,
                              );
                            } else {
                              await userState.equipTalisman(index, tid);
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAbilitySelectionDialog(
    BuildContext context,
    UserState userState,
    int index,
    CapturedOrganism organism,
  ) {
    final pool = organism.baseOrganism.abilities
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != organism.activeAbilityName)
        .toList();

    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This animal has no other abilities to change to!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'SELECT NEW ABILITY',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: AppColors.highlightColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: pool.map((ability) {
            return ListTile(
              title: Text(
                ability.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              onTap: () async {
                await userState.useAbilityCapsule(index, ability);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ability changed to $ability!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showItemSelection(
    BuildContext context,
    UserState userState,
    int index,
    CapturedOrganism organism,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'MANAGE ITEMS',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: AppColors.highlightColor,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome,
                  color: Colors.blueAccent,
                ),
                title: Text(
                  organism.equippedTalisman != null
                      ? 'CHANGE / UNEQUIP TALISMAN'
                      : 'EQUIP TALISMAN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTalismanSelector(context, userState, index, organism);
                },
              ),
              ListTile(
                leading: const Icon(Icons.eco, color: Colors.greenAccent),
                title: const Text(
                  'USE NATURE MINT',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
                enabled:
                    (userState.currentUser?.inventory['nature_mint'] ?? 0) > 0,
                onTap: () {
                  Navigator.pop(ctx);
                  _showNatureSelection(context, userState, index, organism);
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                title: const Text(
                  'USE BERRY',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
                enabled: _hasAnyBerries(userState.currentUser?.inventory ?? {}),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBerrySelection(context, userState, index, organism);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasAnyBerries(Map<String, int> inventory) {
    const berries = {
      'pomeg_berry',
      'kelpsy_berry',
      'qualot_berry',
      'hondew_berry',
      'grepa_berry',
      'tamato_berry',
    };
    return inventory.entries.any((e) => berries.contains(e.key) && e.value > 0);
  }

  void _showNatureSelection(
    BuildContext context,
    UserState userState,
    int index,
    CapturedOrganism organism,
  ) {
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
                        onTap: () async {
                          Navigator.pop(ctx);
                          final success = await userState.applyMint(index, n);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${organism.name}\'s nature changed to ${n.name}!',
                                  style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 8,
                                  ),
                                ),
                                backgroundColor: Colors.green,
                              ),
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
        );
      },
    );
  }

  void _showBerrySelection(
    BuildContext context,
    UserState userState,
    int index,
    CapturedOrganism organism,
  ) {
    const berries = {
      'pomeg_berry',
      'kelpsy_berry',
      'qualot_berry',
      'hondew_berry',
      'grepa_berry',
      'tamato_berry',
    };
    final inventory = userState.currentUser?.inventory ?? {};
    final available = inventory.entries
        .where((e) => berries.contains(e.key) && e.value > 0)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text(
                  'USE BERRY',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Increases Satisfaction, reduces KV.',
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
                    itemCount: available.length,
                    itemBuilder: (context, i) {
                      final b = available[i];
                      final name = b.key.replaceAll('_', ' ').toUpperCase();
                      return ListTile(
                        leading: const Icon(Icons.favorite, color: Colors.pink),
                        title: Text(
                          '$name (x${b.value})',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final success = await userState.applyBerry(
                            index,
                            b.key,
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Used $name on ${organism.name}!',
                                  style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 8,
                                  ),
                                ),
                                backgroundColor: Colors.pinkAccent,
                              ),
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
  final VoidCallback onManageItems;
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
    required this.onManageItems,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final base = captured.baseOrganism;
    final spriteSize = isNarrow
        ? 60.0
        : 80.0; // Slightly smaller to fit details

    List<BoxShadow>? rarityGlow;
    if (base.rarity.toLowerCase() == 'legendary') {
      rarityGlow = [
        BoxShadow(
          color: Colors.orange.withValues(alpha: 0.5),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (base.rarity.toLowerCase() == 'mythical') {
      rarityGlow = [
        BoxShadow(
          color: Colors.purple.withValues(alpha: 0.5),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (base.rarity.toLowerCase() == 'epic' ||
        base.rarity.toLowerCase() == 'elite') {
      rarityGlow = [
        BoxShadow(
          color: Colors.purpleAccent.withValues(alpha: 0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            rarityGlow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
        border: Border.all(
          color: isInTeam
              ? Colors.blueAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: isInTeam ? 2 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showContextMenu(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animal Sprite with Level Badge
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Hero(
                      tag: 'animal_box_sprite_$index',
                      child: _AnimalBoxSprite(organism: base, size: spriteSize),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'L${captured.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              captured.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                fontFamily: 'PressStart2P',
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isInTeam)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TEAM',
                                style: TextStyle(
                                  fontSize: 6,
                                  fontFamily: 'PressStart2P',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Types
                      Wrap(
                        spacing: 4,
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
                              color: _getAnimalTypeColor(
                                type,
                              ).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cat.trim().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 6,
                                fontFamily: 'PressStart2P',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      // HP Bar
                      Row(
                        children: [
                          const Text(
                            'HP',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 7,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    (captured.currentHealth /
                                            captured.maxHealth)
                                        .clamp(0.0, 1.0),
                                backgroundColor: Colors.white12,
                                color:
                                    (captured.currentHealth /
                                            captured.maxHealth) >
                                        0.5
                                    ? Colors.greenAccent
                                    : (captured.currentHealth /
                                              captured.maxHealth) >
                                          0.2
                                    ? Colors.orangeAccent
                                    : Colors.redAccent,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${captured.currentHealth}/${captured.maxHealth} (${((captured.currentHealth / captured.maxHealth) * 100).toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 7,
                              fontFamily: 'PressStart2P',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Item and Ability
                      Row(
                        children: [
                          // Item
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                if (captured.equippedTalisman != null) ...[
                                  Image.asset(
                                    captured.equippedTalisman!.spritePath,
                                    width: 14,
                                    height: 14,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.stars,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.circle_outlined,
                                    size: 14,
                                    color: Colors.white24,
                                  ),
                                ],
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    captured.equippedTalisman?.name ??
                                        'No Item',
                                    style: TextStyle(
                                      color: captured.equippedTalisman != null
                                          ? Colors.amberAccent
                                          : Colors.white24,
                                      fontSize: 7,
                                      fontFamily: 'PressStart2P',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Ability
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(
                                  Icons.auto_fix_high,
                                  size: 12,
                                  color: Colors.cyanAccent,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    captured.activeAbilityName,
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 7,
                                      fontFamily: 'PressStart2P',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                  _AnimalBoxSprite(organism: captured.baseOrganism, size: 50),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          captured.displayName,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'LV.${captured.level} ${captured.baseOrganism.name}',
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
              icon: Icons.edit,
              label: 'RENAME',
              color: Colors.cyanAccent,
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context);
              },
            ),
            _buildContextOption(
              context,
              icon: Icons.bolt,
              label: 'MOVES',
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.pop(ctx);
                onManageMoves();
              },
            ),
            _buildContextOption(
              context,
              icon: Icons.stars,
              label: 'ITEMS',
              color: Colors.amberAccent,
              onTap: () {
                Navigator.pop(ctx);
                onManageItems();
              },
            ),
            _buildContextOption(
              context,
              icon: isInTeam
                  ? Icons.remove_circle_outline
                  : Icons.add_circle_outline,
              label: isInTeam ? 'REMOVE FROM TEAM' : 'ADD TO TEAM',
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(ctx);
                onToggleTeam();
              },
            ),
            _buildContextOption(
              context,
              icon: Icons.bar_chart,
              label: 'SUMMARY',
              color: Colors.greenAccent,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, _, _) =>
                        AnimalSummaryScreen(captured: captured),
                    transitionsBuilder: (_, animation, _, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
            ),
            _buildContextOption(
              context,
              icon: Icons.delete_forever,
              label: 'RELEASE',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(ctx);
                onRelease();
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

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _RenameDialog(
        initialName: captured.nickname ?? '',
        baseName: captured.baseOrganism.name,
        onRename: (newName) {
          Provider.of<UserState>(
            context,
            listen: false,
          ).renameOrganism(captured.id, newName);
        },
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initialName;
  final String baseName;
  final Function(String) onRename;

  const _RenameDialog({
    required this.initialName,
    required this.baseName,
    required this.onRename,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'RENAME ${widget.baseName.toUpperCase()}',
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: Colors.white,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'PressStart2P',
          fontSize: 10,
        ),
        decoration: InputDecoration(
          hintText: 'Enter nickname...',
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.cyanAccent),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 8,
              fontFamily: 'PressStart2P',
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            widget.onRename(_controller.text.trim());
            Navigator.pop(context);
          },
          child: const Text(
            'CONFIRM',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 8,
              fontFamily: 'PressStart2P',
            ),
          ),
        ),
      ],
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
        color: AppColors.surface,
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
            if (captured.teraType != null) ...[
              _buildStatHeader('PRISM TYPE'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: captured.teraType!.color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  captured.teraType!.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.grey),
            ],
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
    } else if (value >= 25) {
      color = Colors.greenAccent;
    } else if (value >= 15) {
      color = Colors.blueAccent;
    }

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
      backgroundColor: AppColors.surface,
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
          child: buildSilhouetteSprite(
            imageUrl: _imagePath,
            silhouetteColor: null, // Keep original colors
            outlineColor: Colors.black,
            outlineWidth: 1.0,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

Color _getAnimalTypeColor(ElementalType type) => type.color;
