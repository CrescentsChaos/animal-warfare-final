// lib/crafting_screen.dart
// Revamped premium Crafting Station with search, tabs, animated UI.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/loot_item.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/recipe.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/widgets/item_icon.dart';

class CraftingScreen extends StatefulWidget {
  const CraftingScreen({super.key});

  @override
  State<CraftingScreen> createState() => _CraftingScreenState();
}

class _CraftingScreenState extends State<CraftingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 60, // Minimal height
            floating: false,
            pinned: true,
            centerTitle: true,
            backgroundColor: const Color(0xFF0D0D1A),
            title: const Text(
              'INVENTORY',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A0A2E),
                      Color(0xFF0A1A2E),
                      Color(0xFF0D0D1A),
                    ],
                  ),
                ),
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    'assets/main.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.highlightColor,
              indicatorWeight: 3,
              labelColor: AppColors.highlightColor,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.construction, size: 18), text: 'FORGE'),
                Tab(
                  icon: Icon(Icons.inventory_2_outlined, size: 18),
                  text: 'MATERIALS',
                ),
                Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'EQUIP'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [_ForgeTab(), _MaterialsTab(), _EquipTab()],
        ),
      ),
    );
  }
}

// ─── FORGE TAB ────────────────────────────────────────────────────────────────

class _ForgeTab extends StatefulWidget {
  const _ForgeTab();

  @override
  State<_ForgeTab> createState() => _ForgeTabState();
}

class _ForgeTabState extends State<_ForgeTab> {
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final inventory = userState.currentUser?.inventory ?? {};

    final recipes = Recipe.allRecipes.where((r) {
      if (_search.isEmpty) return true;
      return (r.resultTalisman?.name ?? '').toLowerCase().contains(_search);
    }).toList();

    // Sort: craftable first
    recipes.sort((a, b) {
      final aC = a.canCraft(inventory) ? 0 : 1;
      final bC = b.canCraft(inventory) ? 0 : 1;
      return aC.compareTo(bC);
    });

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search recipes...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white38,
                size: 18,
              ),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.white38,
                        size: 16,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _statBadge(
                '${recipes.where((r) => r.canCraft(inventory)).length} READY',
                Colors.greenAccent,
              ),
              const SizedBox(width: 8),
              _statBadge('${recipes.length} TOTAL', Colors.white38),
            ],
          ),
        ),
        // Recipe list
        Expanded(
          child: recipes.isEmpty
              ? _emptyState('No recipes found')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: recipes.length,
                  itemBuilder: (ctx, i) =>
                      _RecipeCard(recipe: recipes[i], inventory: inventory),
                ),
        ),
      ],
    );
  }

  Widget _statBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 6, color: color),
      ),
    );
  }
}

// ─── RECIPE CARD ──────────────────────────────────────────────────────────────

class _RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final Map<String, int> inventory;

  const _RecipeCard({required this.recipe, required this.inventory});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _crafting = false;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _craft(BuildContext ctx) async {
    final talisman = widget.recipe.resultTalisman;
    if (talisman == null) return;
    setState(() => _crafting = true);
    _glowCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!ctx.mounted) return;
    
    final userState = Provider.of<UserState>(ctx, listen: false);
    final success = await userState.craftTalisman(
      widget.recipe.resultTalismanId,
      widget.recipe.requiredLoot,
    );
    _glowCtrl.stop();
    _glowCtrl.reset();
    if (context.mounted) {
      setState(() => _crafting = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: success
              ? const Color(0xFF1E3A1E)
              : const Color(0xFF3A1E1E),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.greenAccent : Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                success ? 'Crafted ${talisman.name}!' : 'Not enough materials!',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final talisman = widget.recipe.resultTalisman;
    if (talisman == null) return const SizedBox.shrink();
    final canCraft = widget.recipe.canCraft(widget.inventory);

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (ctx, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF14142A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _crafting
                  ? AppColors.highlightColor.withValues(
                      alpha: 0.5 + _glowAnim.value * 0.5,
                    )
                  : (canCraft
                        ? AppColors.highlightColor.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.07)),
            ),
            boxShadow: canCraft
                ? [
                    BoxShadow(
                      color: AppColors.highlightColor.withValues(
                        alpha: 0.08 + _glowAnim.value * 0.08,
                      ),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          // Header row (always shown)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: canCraft
                          ? AppColors.highlightColor.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ItemIcon(itemName: talisman.name, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          talisman.name,
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: canCraft
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          talisman.description,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.45),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand arrow
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expandable materials + craft button
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      const Divider(height: 1, color: Colors.white10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MATERIALS REQUIRED',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 7,
                                color: Colors.white.withValues(alpha: 0.4),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...widget.recipe.requiredLoot.entries.map((entry) {
                              final loot = LootItem.findById(entry.key);
                              final owned = widget.inventory[entry.key] ?? 0;
                              final required = entry.value;
                              final hasEnough = owned >= required;
                              final progress = (owned / required).clamp(
                                0.0,
                                1.0,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.hexagon_outlined,
                                          size: 12,
                                          color: Colors.white38,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            loot.name,
                                            style: TextStyle(
                                              fontFamily: 'PressStart2P',
                                              fontSize: 8,
                                              color: hasEnough
                                                  ? Colors.white
                                                  : Colors.white.withValues(
                                                      alpha: 0.5,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$owned / $required',
                                          style: TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 8,
                                            color: hasEnough
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 5,
                                        color: hasEnough
                                            ? Colors.greenAccent
                                            : Colors.orange,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.07),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      // Craft button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: ElevatedButton(
                              onPressed: canCraft && !_crafting
                                  ? () => _craft(context)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canCraft
                                    ? AppColors.highlightColor
                                    : Colors.white.withValues(alpha: 0.08),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                disabledBackgroundColor: Colors.white
                                    .withValues(alpha: 0.06),
                              ),
                              child: _crafting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      canCraft
                                          ? '⚒  FORGE'
                                          : 'MISSING MATERIALS',
                                      style: TextStyle(
                                        fontFamily: 'PressStart2P',
                                        fontSize: 10,
                                        color: canCraft
                                            ? Colors.black
                                            : Colors.white30,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── MATERIALS TAB ────────────────────────────────────────────────────────────

class _MaterialsTab extends StatefulWidget {
  const _MaterialsTab();

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
  String _search = '';
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final inventory = userState.currentUser?.inventory ?? {};
    final entries =
        inventory.entries
            .where((e) => e.value > 0)
            .where(
              (e) =>
                  _search.isEmpty ||
                  (LootItem.findById(
                    e.key,
                  ).name).toLowerCase().contains(_search),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (inventory.isEmpty) return _emptyState('No materials collected yet');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _ctrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search materials...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white38,
                size: 18,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${entries.length} UNIQUE MATERIALS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 6,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              Text(
                'TOTAL: ${inventory.values.fold(0, (a, b) => a + b)}',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 6,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? _emptyState('Nothing matches')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final entry = entries[i];
                    final loot = LootItem.findById(entry.key);
                    final name = loot.name;
                    // Check if it's used in any recipe
                    final usedIn = Recipe.allRecipes
                        .where((r) => r.requiredLoot.containsKey(entry.key))
                        .length;

                    return InkWell(
                      onTap: () {
                        if (entry.key == 'sickle') {
                          userState.toggleSickle();
                        } else {
                          final config =
                              userState.farmingConfig['seed_picking']?[entry.key
                                  .toLowerCase()];
                          final hasTweezers = (inventory['tweezers'] ?? 0) > 0;
                          if (config != null && hasTweezers) {
                            _showSeedPickingDialog(
                              context,
                              userState,
                              entry.key,
                              config,
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14142A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: ItemIcon(itemName: name, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 7,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    entry.key == 'sickle'
                                        ? 'STATUS: ${userState.eventFlags.isSickleActive ? "ON" : "OFF"}'
                                        : (usedIn > 0
                                            ? 'Used in $usedIn recipe${usedIn > 1 ? 's' : ''}'
                                            : 'Drop item'),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: entry.key == 'sickle' &&
                                              userState.eventFlags
                                                  .isSickleActive
                                          ? Colors.greenAccent
                                          : Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'x${entry.value}',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 10,
                                color: AppColors.highlightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showSeedPickingDialog(
    BuildContext context,
    UserState userState,
    String fruitId,
    dynamic config,
  ) {
    final inventory = userState.currentUser?.inventory ?? {};
    final maxFruit = inventory[fruitId] ?? 0;
    if (maxFruit <= 0) return;

    int qty = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: const Color(0xFF14142A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text(
              'SEED PICKING',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Use Tweezers to extract seeds from ${fruitId.toUpperCase()}?',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.dangerLight,
                      onPressed: qty > 1 ? () => setLocal(() => qty--) : null,
                    ),
                    Text(
                      '$qty / $maxFruit',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: AppColors.highlightColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.primary,
                      onPressed: qty < maxFruit
                          ? () => setLocal(() => qty++)
                          : null,
                    ),
                  ],
                ),
                if (maxFruit > 1)
                  Slider(
                    value: qty.toDouble(),
                    min: 1,
                    max: maxFruit.toDouble(),
                    divisions: maxFruit > 1 ? maxFruit - 1 : 1,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.white24,
                    label: '$qty',
                    onChanged: (v) => setLocal(() => qty = v.toInt()),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success = await userState.pickSeeds(fruitId, qty);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Successfully picked seeds from $qty ${fruitId.toUpperCase()}!'
                              : 'Failed to pick seeds.',
                        ),
                        backgroundColor: success
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.highlightColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'PICK SEEDS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── EQUIP TAB ────────────────────────────────────────────────────────────────

class _EquipTab extends StatelessWidget {
  const _EquipTab();

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final organisms = userState.currentUser?.capturedOrganisms ?? [];
    final craftedTalismans = userState.currentUser?.craftedTalismans ?? [];

    if (organisms.isEmpty) {
      return _emptyState('No animals captured yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: organisms.length,
      itemBuilder: (ctx, i) {
        final org = organisms[i];
        final talisman = org.equippedTalisman;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF14142A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: talisman != null
                  ? AppColors.highlightColor.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Animal pic placeholder / initials
                _AnimalAvatar(organism: org),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            org.name,
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 9,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Lv.${org.level}',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 6,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (talisman != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                talisman.name,
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 7,
                                  color: Colors.amber,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          talisman.description,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.4),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else
                        Text(
                          'No item equipped',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 7,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _EquipButton(
                  organism: org,
                  index: i,
                  craftedTalismans: craftedTalismans,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EquipButton extends StatelessWidget {
  final CapturedOrganism organism;
  final int index;
  final List<String> craftedTalismans;

  const _EquipButton({
    required this.organism,
    required this.index,
    required this.craftedTalismans,
  });

  @override
  Widget build(BuildContext context) {
    final hasTalisman = organism.equippedTalisman != null;
    return GestureDetector(
      onTap: () => _showSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasTalisman
              ? AppColors.highlightColor.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasTalisman
                ? AppColors.highlightColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          hasTalisman ? 'SWAP' : 'EQUIP',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: hasTalisman ? AppColors.highlightColor : Colors.white54,
          ),
        ),
      ),
    );
  }

  void _showSelector(BuildContext context) {
    final userState = Provider.of<UserState>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF12122A),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.highlightColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Select Item for ${organism.name}',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (organism.equippedTalisman != null)
                      _sheetItem(
                        ctx,
                        userState,
                        null,
                        'Unequip',
                        'Remove held item',
                        Icons.remove_circle_outline,
                        Colors.redAccent,
                      ),
                    if (craftedTalismans.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Craft items in the FORGE tab first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      )
                    else
                      ...craftedTalismans.toSet().map((tid) {
                        final t = Talisman.findById(tid);
                        final count = craftedTalismans
                            .where((id) => id == tid)
                            .length;
                        return _sheetItem(
                          ctx,
                          userState,
                          tid,
                          '${t?.name ?? tid} (x$count)',
                          t?.description ?? '',
                          Icons.auto_awesome,
                          Colors.amber,
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetItem(
    BuildContext ctx,
    UserState userState,
    String? tId,
    String name,
    String desc,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () async {
        await userState.equipTalisman(index, tId);
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: color,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AnimalAvatar extends StatelessWidget {
  final CapturedOrganism organism;

  const _AnimalAvatar({required this.organism});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildSprite(),
      ),
    );
  }

  Widget _buildSprite() {
    final name = organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll('-', '_');
    final path = 'assets/sprites/$name.png';
    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          organism.name.isNotEmpty ? organism.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}

// ─── SHARED HELPERS ───────────────────────────────────────────────────────────

Widget _emptyState(String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
