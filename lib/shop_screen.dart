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
  String _selectedCategory = 'All';

  static const _rodIds = {'old_rod', 'good_rod', 'super_rod'};

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
    List<ShopItem> base;
    if (widget.biome == null) {
      base = _allItemConfigs
          .where((item) => item.biomes == null || item.biomes!.isEmpty)
          .toList();
    } else {
      base = _allItemConfigs.where((item) {
        if (item.biomes == null || item.biomes!.isEmpty) return true;
        return item.biomes!.any(
          (b) => b.toLowerCase() == widget.biome!.toLowerCase(),
        );
      }).toList();
    }

    if (_selectedCategory == 'All') return base;
    return base.where((i) => i.category == _selectedCategory).toList();
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'talisman':
        return 'talisman';
      case 'mint':
        return 'mint';
      case 'rod':
        return 'rod';
      case 'capture_item':
        return 'capture_item';
      default:
        return cat;
    }
  }

  void _showBuyDialog(ShopItem item) {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    int qty = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final total = item.price * qty;
          final canAfford = user.money >= total;
          return AlertDialog(
            backgroundColor: AppColors.secondaryButtonColor,
            title: Text(
              'BUY ${item.name.toUpperCase()}',
              style: AppTextStyles.headline(context, baseSize: 13),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Quantity row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle,
                        color: Colors.redAccent,
                      ),
                      onPressed: qty > 1 ? () => setLocal(() => qty--) : null,
                    ),
                    Container(
                      width: 60,
                      alignment: Alignment.center,
                      child: Text(
                        '$qty',
                        style: AppTextStyles.headline(
                          context,
                          baseSize: 20,
                          color: AppColors.highlightColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.greenAccent,
                      ),
                      onPressed: () => setLocal(() => qty++),
                    ),
                  ],
                ),
                // Slider
                Slider(
                  value: qty.toDouble(),
                  min: 1,
                  max: 99,
                  divisions: 98,
                  activeColor: AppColors.highlightColor,
                  inactiveColor: Colors.grey.shade700,
                  label: '$qty',
                  onChanged: (v) => setLocal(() => qty = v.round()),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: $total Gold',
                  style: TextStyle(
                    color: canAfford
                        ? AppColors.highlightColor
                        : Colors.redAccent,
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                  ),
                ),
                if (!canAfford)
                  const Text(
                    'Not enough gold!',
                    style: TextStyle(color: Colors.redAccent, fontSize: 9),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: canAfford
                    ? () async {
                        Navigator.pop(ctx);
                        await userState.addMoney(-total);
                        await userState.addLoot(item.id, qty);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Purchased $qty× ${item.name}!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    : null,
                child: Text(
                  'BUY',
                  style: TextStyle(
                    color: canAfford ? AppColors.highlightColor : Colors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
          baseSize: 16,
          color: AppColors.highlightColor,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildGoldBalance(),
                _buildCategoryFilter(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
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
        final inv = userState.currentUser?.inventory ?? {};

        // Show which rods are active
        final rodStatus = _rodIds.where((id) => (inv[id] ?? 0) > 0).map((id) {
          final name = id.replaceAll('_', ' ').toUpperCase();
          final isActive = inv['${id}_active'] == 1;
          return GestureDetector(
            onTap: () async {
              final key = '${id}_active';
              final current = (inv[key] ?? 0);
              await userState.addLoot(key, current == 1 ? -1 : 1);
            },
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.blueAccent : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          );
        }).toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.black.withValues(alpha: 0.3),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$money Gold',
                    style: AppTextStyles.headline(
                      context,
                      baseSize: 18,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              if (rodStatus.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Rods: ',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 8,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    ...rodStatus,
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    final cats = [
      ('All', 'All'),
      ('talisman', 'Talismans'),
      ('mint', 'Mints'),
      ('capture_item', 'Nets'),
      ('rod', 'Rods'),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: cats.map((pair) {
          final selected = _selectedCategory == pair.$1;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = pair.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.highlightColor
                    : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                pair.$2,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontSize: 9,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final isRod = _rodIds.contains(item.id);
    return Consumer<UserState>(
      builder: (context, userState, _) {
        final inv = userState.currentUser?.inventory ?? {};
        final owned = inv[item.id] ?? 0;
        final isActive = isRod && inv['${item.id}_active'] == 1;

        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? Colors.blueAccent
                  : AppColors.highlightColor.withValues(alpha: 0.5),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Center(child: _buildItemIcon(item)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  item.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    context,
                    baseSize: 10,
                    color: AppColors.highlightColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 7),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (owned > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Owned: $owned',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 8,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              if (isRod && owned > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showBuyDialog(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.highlightColor,
                            minimumSize: const Size(0, 30),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            '${item.price}G',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          final key = '${item.id}_active';
                          final current = inv[key] ?? 0;
                          await userState.addLoot(key, current == 1 ? -1 : 1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.blueAccent
                                : Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isActive ? Icons.toggle_on : Icons.toggle_off,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () => _showBuyDialog(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.highlightColor,
                      minimumSize: const Size(0, 32),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '${item.price}G',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
          case 'mint':
            iconData = Icons.eco;
            color = Colors.greenAccent;
            break;
          default:
            iconData = Icons.inventory_2;
            color = Colors.grey;
        }
        return Icon(iconData, size: 44, color: color);
      },
    );
  }
}
