// lib/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/shop_item.dart';
import 'package:animal_warfare/theme.dart';

class ShopScreen extends StatefulWidget {
  final String? biome;
  const ShopScreen({super.key, this.biome});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<ShopItem> _allItemConfigs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await ShopItem.loadAll();
    setState(() {
      _allItemConfigs = items;
      _isLoading = false;
    });
  }

  List<ShopItem> get _filteredItems {
    if (widget.biome == null) {
      // Global shop items (those with no biomes restricted)
      return _allItemConfigs
          .where((item) => item.biomes == null || item.biomes!.isEmpty)
          .toList();
    } else {
      // Items for this biome + global items
      return _allItemConfigs.where((item) {
        if (item.biomes == null || item.biomes!.isEmpty) return true;
        return item.biomes!.any(
          (b) => b.toLowerCase() == widget.biome!.toLowerCase(),
        );
      }).toList();
    }
  }

  void _buyItem(ShopItem item) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    if (user.money < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough money! Need ${item.price} Gold.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool confirmed =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.secondaryButtonColor,
            title: Text(
              'BUY ${item.name.toUpperCase()}?',
              style: AppTextStyles.headline(context, baseSize: 14),
            ),
            content: Text(
              'Cost: ${item.price} Gold. Confirm purchase?',
              style: AppTextStyles.body(context, baseSize: 12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'BUY',
                  style: TextStyle(color: AppColors.highlightColor),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await userState.addMoney(-item.price);
      if (item.category == 'talisman') {
        // Special case for talismans?
        // UserState.craftTalisman uses loot. I should add a direct "addTalisman" method or just use inventory.
        // For now, let's put it in inventory, and maybe the player can "use" it to add to craftedTalismans.
        // Actually, let's look at UserState again.
        await userState.addLoot(item.id, 1);
      } else {
        await userState.addLoot(item.id, 1);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchased ${item.name}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryButtonColor,
      appBar: AppBar(
        title: Text(
          widget.biome != null
              ? '${widget.biome!.toUpperCase()} SHOP'
              : 'GLOBAL SHOP',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTextStyles.headline(
          context,
          baseSize: 18,
          color: AppColors.highlightColor,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildGoldBalance(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildItemCard(item);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGoldBalance() {
    return Consumer<UserState>(
      builder: (context, userState, _) {
        final money = userState.currentUser?.money ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                '$money Gold',
                style: AppTextStyles.headline(
                  context,
                  baseSize: 20,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemCard(ShopItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlightColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Hero(
                  tag: 'shop-${item.id}',
                  child: _buildItemIcon(item),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                context,
                baseSize: 12,
                color: AppColors.highlightColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 8),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () => _buyItem(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.highlightColor,
                minimumSize: const Size(0, 36),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                '${item.price}G',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemIcon(ShopItem item) {
    final spritePath =
        'assets/items/${item.name.toLowerCase().replaceAll(' ', '-')}.png';

    return Image.asset(
      spritePath,
      width: 48,
      height: 48,
      fit: BoxFit.contain,
      errorBuilder: (context, _, __) {
        IconData iconData;
        Color color;
        switch (item.category) {
          case 'rod':
            iconData = Icons.anchor;
            color = Colors.blueAccent;
            break;
          case 'talisman':
            iconData = Icons.auto_awesome;
            color = Colors.purpleAccent;
            break;
          default:
            iconData = Icons.inventory_2;
            color = Colors.grey;
        }
        return Icon(iconData, size: 48, color: color);
      },
    );
  }
}
