// lib/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/shop_item.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Text(
              item.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 13,
                color: AppColors.highlight,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Quantity row
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.dangerLight,
                        ),
                        onPressed: qty > 1 ? () => setLocal(() => qty--) : null,
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 18,
                            color: AppColors.highlight,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                        ),
                        onPressed: () => setLocal(() => qty++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: qty.toDouble(),
                  min: 1,
                  max: 99,
                  divisions: 98,
                  label: '$qty',
                  onChanged: (v) => setLocal(() => qty = v.round()),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$total Gold',
                      style: TextStyle(
                        color: canAfford
                            ? AppColors.highlight
                            : AppColors.dangerLight,
                        fontFamily: 'PressStart2P',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (!canAfford)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Not enough gold!',
                      style: GoogleFonts.inter(
                        color: AppColors.dangerLight,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: canAfford
                    ? () async {
                        Navigator.pop(ctx);
                        await userState.addMoney(-total);
                        await userState.addLoot(item.id, qty);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Purchased $qty× ${item.name}!'),
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Buy',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.biome != null ? '${widget.biome!.toUpperCase()} SHOP' : 'SHOP',
        ),
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                _buildGoldBalance(),
                _buildCategoryFilter(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(_filteredItems[index]);
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

        final activeRods = _rodIds.where((id) => (inv[id] ?? 0) > 0).map((id) {
          final isActive = inv['${id}_active'] == 1;
          return GestureDetector(
            onTap: () async {
              final key = '${id}_active';
              final current = (inv[key] ?? 0);
              await userState.addLoot(key, current == 1 ? -1 : 1);
            },
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive ? AppColors.primary : Colors.transparent,
                ),
              ),
              child: Text(
                id.replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.inter(
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$money Gold',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 16,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              if (activeRods.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Rods:',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    ...activeRods,
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
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: cats.map((pair) {
          final selected = _selectedCategory == pair.$1;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = pair.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                pair.$2,
                style: GoogleFonts.inter(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.border,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Center(child: _buildItemIcon(item)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  item.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.highlight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (owned > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Owned: $owned',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // Action area
              if (isRod && owned > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buyButton(
                          label: '${item.price}G',
                          onTap: () => _showBuyDialog(item),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          final key = '${item.id}_active';
                          final current = inv[key] ?? 0;
                          await userState.addLoot(key, current == 1 ? -1 : 1);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            isActive ? Icons.toggle_on : Icons.toggle_off,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: _buyButton(
                    label: '${item.price}G',
                    onTap: () => _showBuyDialog(item),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buyButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemIcon(ShopItem item) {
    final spritePath =
        'assets/items/${item.name.toLowerCase().replaceAll(' ', '-')}.png';
    return Image.asset(
      spritePath,
      width: 54,
      height: 54,
      fit: BoxFit.contain,
      errorBuilder: (context, _, __) {
        IconData iconData;
        Color color;
        switch (item.category) {
          case 'rod':
            iconData = Icons.anchor;
            color = AppColors.primary;
            break;
          case 'talisman':
            iconData = Icons.auto_awesome;
            color = const Color(0xFFAB47BC);
            break;
          case 'mint':
            iconData = Icons.eco;
            color = const Color(0xFF26A69A);
            break;
          default:
            iconData = Icons.inventory_2;
            color = AppColors.textSecondary;
        }
        return Icon(iconData, size: 48, color: color);
      },
    );
  }
}
