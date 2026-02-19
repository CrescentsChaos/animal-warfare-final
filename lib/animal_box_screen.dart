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

class AnimalBoxScreen extends StatefulWidget {
  const AnimalBoxScreen({super.key});

  @override
  State<AnimalBoxScreen> createState() => _AnimalBoxScreenState();
}

class _AnimalBoxScreenState extends State<AnimalBoxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  static const List<String> _predefinedCategories = [
    "Predator",
    "Prey",
    "Scavenger",
    "Parasite",
    "Venomous",
    "Poisonous",
    "Social",
    "Solitary",
    "Flying",
    "Aquatic",
    "Arboreal",
    "Burrowing",
    "Armored",
    "Agile",
    "Tiny",
    "Giant",
  ];

  @override
  void dispose() {
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

            return TabBarView(
              children: [
                _buildBoxView(user, userState),
                _buildTeamView(user, userState),
              ],
            );
          },
        ),
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
              final isAttacker = user.activeAttackerIndex == originalIndex;

              return _AnimalCard(
                captured: org,
                index: originalIndex,
                isInTeam: isInTeam,
                isActiveAttacker: isAttacker,
                isNarrow: MediaQuery.sizeOf(context).width < 400,
                onTap: () => _showAnimalDetails(context, org),
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
                onSetAsAttacker: () =>
                    userState.setActiveAttacker(originalIndex),
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

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: teamIndices.length,
      itemBuilder: (context, index) {
        final originalIndex = teamIndices[index];
        if (originalIndex < 0 ||
            originalIndex >= user.capturedOrganisms.length) {
          return const SizedBox.shrink();
        }
        final org = user.capturedOrganisms[originalIndex];
        final isAttacker = user.activeAttackerIndex == originalIndex;

        return _AnimalCard(
          captured: org,
          index: originalIndex,
          isInTeam: true,
          isActiveAttacker: isAttacker,
          isNarrow: MediaQuery.sizeOf(context).width < 400,
          onTap: () => _showAnimalDetails(context, org),
          onToggleTeam: () => userState.toggleTeamMember(originalIndex),
          onSetAsAttacker: () => userState.setActiveAttacker(originalIndex),
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
              onChanged: (val) => setState(() => _searchQuery = val),
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
          Icon(Icons.pets, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No animals captured yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontFamily: 'PressStart2P',
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
            Icon(Icons.groups, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Your team is empty.\nGo to "Box" and add some animals to your team (Max 5).',
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

  void _showAnimalDetails(BuildContext context, CapturedOrganism captured) {
    showDialog(
      context: context,
      builder: (ctx) => _AnimalDetailsDialog(captured: captured),
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
  final bool isActiveAttacker;
  final bool isNarrow;
  final VoidCallback onTap;
  final VoidCallback onToggleTeam;
  final VoidCallback onSetAsAttacker;
  final VoidCallback onManageMoves;
  final VoidCallback onEquip;
  final VoidCallback onRelease;

  const _AnimalCard({
    required this.captured,
    required this.index,
    required this.isInTeam,
    required this.isActiveAttacker,
    required this.isNarrow,
    required this.onTap,
    required this.onToggleTeam,
    required this.onSetAsAttacker,
    required this.onManageMoves,
    required this.onEquip,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final base = captured.baseOrganism;
    final spriteSize = isNarrow ? 80.0 : 100.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActiveAttacker
              ? AppColors.highlightColor
              : (isInTeam ? Colors.blue[300]! : Colors.grey[700]!),
          width: isActiveAttacker || isInTeam ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _AnimalBoxSprite(organism: base, size: spriteSize),
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
                    Text(
                      'HP: ${(captured.getMaxHealth(atLevel: 50) * (captured.currentHealth / captured.maxHealth)).round()}/${captured.getMaxHealth(atLevel: 50)}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      captured.equippedTalisman != null
                          ? 'Item: ${captured.equippedTalisman!.name}'
                          : 'No Item',
                      style: TextStyle(
                        color: captured.equippedTalisman != null
                            ? AppColors.highlightColor
                            : Colors.grey[500],
                        fontSize: 9,
                        fontFamily: 'PressStart2P',
                      ),
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
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _SmallActionBtn(
          label: isActiveAttacker ? 'ACTIVE' : 'ATTACK',
          color: isActiveAttacker
              ? AppColors.highlightColor
              : AppColors.primaryButtonColor,
          onPressed: isActiveAttacker ? null : onSetAsAttacker,
        ),
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

  const _AnimalDetailsDialog({required this.captured});

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
            _AnimalBoxSprite(organism: base, size: 60),
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
            _buildStatHeader('CORE DNA (IVs)'),
            const SizedBox(height: 8),
            _buildStatRow('HP IV', ivs['health'] ?? 0),
            _buildStatRow('ATK IV', ivs['attack'] ?? 0),
            _buildStatRow('DEF IV', ivs['defense'] ?? 0),
            _buildStatRow('PWR IV', ivs['power'] ?? 0),
            _buildStatRow('RES IV', ivs['resistance'] ?? 0),
            _buildStatRow('SPD IV', ivs['speed'] ?? 0),
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
      return const Color.fromARGB(255, 248, 255, 150);
    case ElementalType.sound:
      return const Color.fromARGB(255, 166, 70, 255);
  }
}
