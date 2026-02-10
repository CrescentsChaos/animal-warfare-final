// lib/crafting_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/loot_item.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/recipe.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/theme.dart';

class CraftingScreen extends StatefulWidget {
  const CraftingScreen({super.key});

  @override
  State<CraftingScreen> createState() => _CraftingScreenState();
}

class _CraftingScreenState extends State<CraftingScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.secondaryButtonColor,
        appBar: AppBar(
          backgroundColor: AppColors.secondaryButtonColor,
          title: const Text(
            'CRAFTING STATION',
            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.highlightColor,
            labelStyle: TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
            tabs: [
              Tab(text: 'CRAFT', icon: Icon(Icons.build)),
              Tab(text: 'ITEMS', icon: Icon(Icons.inventory)),
              Tab(text: 'EQUIP', icon: Icon(Icons.shield)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CraftingTab(),
            InventoryTab(),
            EquipmentTab(),
          ],
        ),
      ),
    );
  }
}

class CraftingTab extends StatelessWidget {
  const CraftingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final inventory = userState.currentUser?.inventory ?? {};

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: Recipe.allRecipes.length,
      itemBuilder: (context, index) {
        final recipe = Recipe.allRecipes[index];
        final talisman = recipe.resultTalisman;
        if (talisman == null) return const SizedBox.shrink();

        final canCraft = recipe.canCraft(inventory);

        return Card(
          color: Colors.black.withOpacity(0.5),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: canCraft ? AppColors.highlightColor : Colors.grey,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      talisman.name,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: AppColors.highlightColor,
                      ),
                    ),
                    if (canCraft)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  talisman.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Divider(color: Colors.white24, height: 24),
                const Text(
                  'MATERIALS:',
                  style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10, color: Colors.white54),
                ),
                const SizedBox(height: 8),
                ...recipe.requiredLoot.entries.map((entry) {
                  final loot = LootItem.findById(entry.key);
                  final owned = inventory[entry.key] ?? 0;
                  final hasEnough = owned >= entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '- ${loot?.name ?? entry.key}',
                          style: TextStyle(
                            color: hasEnough ? Colors.white : Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$owned/${entry.value}',
                          style: TextStyle(
                            color: hasEnough ? Colors.white : Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canCraft
                        ? () async {
                            final success = await userState.craftTalisman(
                                recipe.resultTalismanId, recipe.requiredLoot);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Crafted ${talisman.name}!'
                                        : 'Crafting failed!',
                                  ),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canCraft ? Colors.green[800] : Colors.grey[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text(
                      'CRAFT',
                      style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Colors.white),
                    ),
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

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final inventory = userState.currentUser?.inventory ?? {};
    final lootItems = inventory.entries.toList();

    if (lootItems.isEmpty) {
      return Center(
        child: Text(
          'INVENTORY EMPTY',
          style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white30),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lootItems.length,
      itemBuilder: (context, index) {
        final entry = lootItems[index];
        final loot = LootItem.findById(entry.key);
        if (loot == null) return const SizedBox.shrink();

        return Card(
          color: Colors.black.withOpacity(0.3),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.category, color: _getRarityColor(loot.rarity)),
            title: Text(
              loot.name,
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Colors.white),
            ),
            subtitle: Text(
              loot.description,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            trailing: Text(
              'x${entry.value}',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: AppColors.highlightColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getRarityColor(LootRarity rarity) {
    switch (rarity) {
      case LootRarity.common: return Colors.grey;
      case LootRarity.uncommon: return Colors.green;
      case LootRarity.rare: return Colors.blue;
      case LootRarity.epic: return Colors.purple;
    }
  }
}

class EquipmentTab extends StatelessWidget {
  const EquipmentTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final organisms = userState.currentUser?.capturedOrganisms ?? [];
    final craftedTalismans = userState.currentUser?.craftedTalismans ?? [];

    if (organisms.isEmpty) {
      return const Center(
        child: Text(
          'NO ANIMALS CAPTURED',
          style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white30),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: organisms.length,
      itemBuilder: (context, index) {
        final organism = organisms[index];
        final talisman = organism.equippedTalisman;

        return Card(
          color: Colors.black.withOpacity(0.5),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.secondaryButtonColor,
                  child: Text(
                    organism.name[0],
                    style: const TextStyle(fontFamily: 'PressStart2P', color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organism.name,
                        style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        talisman != null ? 'EQUIPPED: ${talisman.name}' : 'NO EQUIPMENT',
                        style: TextStyle(
                          fontSize: 10,
                          color: talisman != null ? AppColors.highlightColor : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showTalismanSelector(context, userState, index, organism),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButtonColor,
                    padding: const EdgeInsets.all(8),
                  ),
                  child: Text(
                    talisman != null ? 'CHANGE' : 'EQUIP',
                    style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 8, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTalismanSelector(BuildContext context, UserState userState, int index, CapturedOrganism organism) {
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
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: AppColors.highlightColor),
              ),
              const SizedBox(height: 16),
              if (organism.equippedTalisman != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle, color: Colors.red),
                  title: const Text('UNEQUIP', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Colors.white)),
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
                  final count = craftedTalismans.where((id) => id == tid).length;
                  return ListTile(
                    leading: const Icon(Icons.auto_awesome, color: AppColors.highlightColor),
                    title: Text(t?.name ?? tid, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Colors.white)),
                    subtitle: Text('Count: x$count', style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
