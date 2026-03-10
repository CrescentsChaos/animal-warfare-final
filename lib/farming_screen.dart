// lib/farming_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/models/farm_slot.dart';
import 'package:animal_warfare/crafting_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class FarmingScreen extends StatefulWidget {
  const FarmingScreen({super.key});

  @override
  State<FarmingScreen> createState() => _FarmingScreenState();
}

class _FarmingScreenState extends State<FarmingScreen> {
  final GlobalKey _inventoryKey = GlobalKey();
  final List<_FlyingFruit> _flyingFruits = [];

  void _addFlyingFruit(Offset startOffset, String fruitName, int yieldCount) {
    for (int i = 0; i < yieldCount; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (!mounted) return;
        setState(() {
          _flyingFruits.add(
            _FlyingFruit(
              startOffset: startOffset,
              fruitName: fruitName,
              id: DateTime.now().millisecondsSinceEpoch + i,
            ),
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'FARM',
          style: GoogleFonts.pressStart2p(
            color: Colors.white,
            fontSize: 18,
            shadows: [
              const Shadow(
                color: Colors.black,
                blurRadius: 4,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              key: _inventoryKey,
              icon: const Icon(
                Icons.inventory_2,
                color: AppColors.highlight,
                size: 28,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CraftingScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/biomes/jungle-bg.png',
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.3),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          SafeArea(
            child: FarmGrid(
              inventoryKey: _inventoryKey,
              onHarvested: _addFlyingFruit,
            ),
          ),
          // Flying Fruits Overlay
          ..._flyingFruits.map(
            (fruit) => _FlyingFruitWidget(
              fruit: fruit,
              targetKey: _inventoryKey,
              onComplete: () {
                if (!mounted) return;
                setState(() {
                  _flyingFruits.removeWhere((f) => f.id == fruit.id);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FlyingFruit {
  final Offset startOffset;
  final String fruitName;
  final int id;

  _FlyingFruit({
    required this.startOffset,
    required this.fruitName,
    required this.id,
  });
}

class FarmGrid extends StatelessWidget {
  final GlobalKey inventoryKey;
  final Function(Offset, String, int) onHarvested;

  const FarmGrid({
    super.key,
    required this.inventoryKey,
    required this.onHarvested,
  });

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    final slots = userState.currentUser?.farmSlots ?? [];

    if (slots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        return FarmSlotWidget(slot: slots[index], onHarvested: onHarvested);
      },
    );
  }
}

class FarmSlotWidget extends StatelessWidget {
  final FarmSlot slot;
  final Function(Offset, String, int) onHarvested;

  const FarmSlotWidget({
    super.key,
    required this.slot,
    required this.onHarvested,
  });

  String _getSpritePath() {
    switch (slot.stage) {
      case PlantStage.empty:
        return 'assets/farming/farmland.png';
      case PlantStage.seed:
        return 'assets/farming/seed.png';
      case PlantStage.sprout:
        return 'assets/farming/sprout.png';
      case PlantStage.flower:
        return 'assets/farming/${slot.plantType ?? 'strawberry'}-flower.png';
      case PlantStage.fruit:
        return 'assets/farming/${slot.plantType ?? 'strawberry'}-fruit.png';
    }
  }

  void _showFarmingOptions(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Offset center =
        offset + Offset(renderBox.size.width / 2, renderBox.size.height / 2);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FarmSlotBottomSheet(
        slot: slot,
        onHarvested: (fruitName, yieldCount) =>
            onHarvested(center, fruitName, yieldCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFarmingOptions(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: slot.stage == PlantStage.fruit
                ? AppColors.highlight
                : AppColors.border,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Show either the Farmland Base or the Growth Layer
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Image.asset(
                  _getSpritePath(),
                  key: ValueKey('${slot.stage}_${slot.plantType}'),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.brown[900]),
                ),
              ),
              // Status Badges
              Positioned(
                bottom: 8,
                right: 8,
                child: Row(
                  children: [
                    if (slot.isWatered)
                      _buildIndicator(Icons.water_drop, Colors.blue),
                    if (slot.isFertilized)
                      _buildIndicator(Icons.eco, Colors.green),
                  ],
                ),
              ),
              // Stage Label - MOVED TO TOP
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Text(
                    slot.stage == PlantStage.empty
                        ? 'EMPTY'
                        : slot.stage.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

class FarmSlotBottomSheet extends StatelessWidget {
  final FarmSlot slot;
  final Function(String, int) onHarvested;

  const FarmSlotBottomSheet({
    super.key,
    required this.slot,
    required this.onHarvested,
  });

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    final inventory = userState.currentUser?.inventory ?? {};

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'FIELD PLOT #${slot.index + 1}',
            style: GoogleFonts.pressStart2p(
              color: AppColors.highlight,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (slot.stage == PlantStage.empty) ...[
            Text(
              'PLANT A SEED',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ...inventory.entries
                .where((e) => e.key.endsWith('_seed') && e.value > 0)
                .map((e) {
                  final seedId = e.key;
                  final name = seedId.replaceAll('_', ' ').toUpperCase();
                  return _buildSeedOption(context, seedId, name, inventory);
                }),
            if (!inventory.keys.any(
              (k) => k.endsWith('_seed') && (inventory[k] ?? 0) > 0,
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'NO SEEDS IN INVENTORY',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ] else if (slot.stage == PlantStage.fruit) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final plantType = slot.plantType ?? 'strawberry';
                final yieldCount = await userState.harvestPlant(slot.index);
                if (yieldCount > 0 && context.mounted) {
                  onHarvested(plantType, yieldCount);
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.shopping_basket_rounded),
              label: const Text('HARVEST CROP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ] else ...[
            Text(
              'GROWING: ${slot.plantType?.toUpperCase()}',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _calculateProgress(slot),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.water_drop,
                    label: 'WATER',
                    color: Colors.blue,
                    isEnabled:
                        !slot.isWatered && (inventory['spray_bottle'] ?? 0) > 0,
                    onTap: () async {
                      await userState.waterPlant(slot.index);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
                // Only show Fertilize if not already fertilized
                if (!slot.isFertilized) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.eco,
                      label: 'FERTILIZE',
                      color: Colors.green,
                      isEnabled: (inventory['organic_fertilizer'] ?? 0) > 0,
                      onTap: () async {
                        await userState.fertilizePlant(slot.index);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  double _calculateProgress(FarmSlot slot) {
    if (slot.lastStageTime == null) return 0;
    final now = DateTime.now();
    final elapsed = now.difference(slot.lastStageTime!);
    int requiredSeconds = 60;
    if (slot.isWatered) requiredSeconds -= 20;
    if (slot.isFertilized) requiredSeconds -= 20;
    return (elapsed.inSeconds / requiredSeconds).clamp(0.0, 1.0);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onTap : null,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _buildSeedOption(
    BuildContext context,
    String seedId,
    String name,
    Map<String, int> inventory,
  ) {
    final count = inventory[seedId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.highlight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.energy_savings_leaf,
            color: AppColors.highlight,
          ),
        ),
        title: Text(
          name.toUpperCase(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          'INVENTORY: $count',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: count > 0
              ? () async {
                  final userState = context.read<UserState>();
                  await userState.plantSeed(slot.index, seedId);
                  if (context.mounted) Navigator.pop(context);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('PLANT'),
        ),
      ),
    );
  }
}

class _FlyingFruitWidget extends StatefulWidget {
  final _FlyingFruit fruit;
  final GlobalKey targetKey;
  final VoidCallback onComplete;

  const _FlyingFruitWidget({
    required this.fruit,
    required this.targetKey,
    required this.onComplete,
  });

  @override
  State<_FlyingFruitWidget> createState() => _FlyingFruitWidgetState();
}

class _FlyingFruitWidgetState extends State<_FlyingFruitWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  Offset? _targetOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800), // Slower animation
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_animation);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? targetBox =
          widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (targetBox != null) {
        setState(() {
          _targetOffset =
              targetBox.localToGlobal(Offset.zero) +
              Offset(targetBox.size.width / 2, targetBox.size.height / 2);
        });

        // Add a tiny delay based on the index (from startOffset dx/dy hack or passed prop if we refactor)
        // For now, just play it. The caller will handle staggered spawning.
        _controller.forward().then((_) => widget.onComplete());
      } else {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetOffset == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _animation.value;
        final Offset position = Offset.lerp(
          widget.fruit.startOffset,
          _targetOffset,
          t,
        )!;

        // Add a higher arc to the slower movement
        final double arc = 150 * (1 - (2 * t - 1).abs().pow(2));
        final Offset finalPos = position - Offset(0, arc);

        return Positioned(
          left: finalPos.dx - 20,
          top: finalPos.dy - 20,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: (1.0 - t).clamp(0.0, 1.0),
              child: Image.asset(
                'assets/items/${widget.fruit.fruitName}.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on double {
  double pow(int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= this;
    }
    return result;
  }
}
