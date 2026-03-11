// lib/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/shop_item.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/services/market_service.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _categoryNames = {
    'All': 'All Items',
    'talisman': 'Talismans',
    'mint': 'Mints',
    'capture_item': 'Capture Nets',
    'rod': 'Fishing Rods',
    'fruit': 'Fruits',
    'farming_tool': 'Farming Tools',
    'misc': 'Miscellaneous',
  };

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

    if (_selectedCategory != 'All') {
      base = base.where((i) => i.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.description.toLowerCase().contains(q),
          )
          .toList();
    }

    // Hide black market items from regular buy pool
    return base.where((i) => i.category != 'mystery_box').toList();
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
          final currentPrice = MarketService.getCurrentPrice(
            item.id,
            item.price,
            TimeService().currentGameTime,
          );
          final maxAffordable = (user.money / currentPrice).floor();
          final maxQty = maxAffordable > 0
              ? (maxAffordable > 99 ? 99 : maxAffordable)
              : 1;

          if (qty > maxQty) qty = maxQty;

          final total = currentPrice * qty;
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
                        onPressed: qty < maxQty
                            ? () => setLocal(() => qty++)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (maxQty > 1)
                  Slider(
                    value: qty.toDouble(),
                    min: 1,
                    max: maxQty.toDouble(),
                    divisions: maxQty > 1 ? maxQty - 1 : 1,
                    label: '$qty',
                    onChanged: (v) => setLocal(() => qty = v.round()),
                  ),
                if (maxQty <= 1)
                  const SizedBox(height: 48), // Spacer to prevent layout jump
                const SizedBox(height: 6),
                Text(
                  '${total.toStringAsFixed(0)} Tk.',
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
    final userState = Provider.of<UserState>(context);
    final isUnlocked = userState.currentUser?.isBlackMarketUnlocked ?? false;

    return DefaultTabController(
      length: isUnlocked ? 3 : 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            widget.biome != null
                ? '${widget.biome!.toUpperCase()} SHOP'
                : 'MARKETPLACE',
            style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
          ),
          backgroundColor: AppColors.surface,
          actions: [
            IconButton(
              icon: const Icon(Icons.tune, color: AppColors.primary),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
            ),
            tabs: [
              const Tab(text: 'BUY'),
              const Tab(text: 'SELL'),
              if (isUnlocked) const Tab(text: 'BLACK MKT'),
            ],
          ),
        ),
        endDrawer: _buildFilterDrawer(),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : TabBarView(
                children: [
                  // Buy Tab
                  Column(
                    children: [
                      _buildTakaBalance(),
                      _buildSearchBar(),
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
                  // Sell Tab
                  _buildSellTab(),
                  // Black Market Tab
                  if (isUnlocked) _buildBlackMarketTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildBlackMarketTab() {
    return Consumer<UserState>(
      builder: (context, userState, _) {
        final gameTime = TimeService().currentGameTime;
        // Filter all items for the black market stock EXCEPT mystery boxes
        final allNormalItems = _allItemConfigs
            .where((i) => i.category != 'mystery_box')
            .map((i) => i.id)
            .toList();
        final stockIds = MarketService.getBlackMarketStock(
          allNormalItems,
          gameTime,
        );

        final stockItems = _allItemConfigs
            .where((i) => stockIds.contains(i.id))
            .toList();
        final mysteryBoxes = _allItemConfigs
            .where((i) => i.category == 'mystery_box')
            .toList();
        mysteryBoxes.sort(
          (a, b) => a.price.compareTo(b.price),
        ); // bronze, silver, gold

        return Container(
          color: const Color(0xFF0F0F1A), // Darker theme
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTakaBalance(isBlackMarket: true),
              const SizedBox(height: 24),
              const Text(
                "TODAY's SHADY DEALS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(height: 16),
              ...stockItems.map(
                (item) => _buildBlackMarketItem(item, userState, gameTime),
              ),

              const SizedBox(height: 32),
              const Text(
                "MYSTERY BOXES (NO REFUNDS)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 16),
              ...mysteryBoxes.map((box) => _buildMysteryBox(box, userState)),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlackMarketItem(
    ShopItem item,
    UserState userState,
    GameTime time,
  ) {
    double mult = MarketService.getBlackMarketMultiplier(item.id, time);
    final price = (item.price * mult).round();
    final isScam = mult > 1.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E), // Darker surface
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildItemIcon(item),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "??? ${item.name} ???",
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                if (isScam)
                  const Text(
                    'Looks suspiciously overpriced...',
                    style: TextStyle(
                      color: AppColors.dangerLight,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  const Text(
                    'Looks like a steal...',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '$price Tk.',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final user = userState.currentUser;
                  if (user == null) return;
                  if (user.money < price) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Not enough Taka to make the deal.'),
                      ),
                    );
                    return;
                  }
                  await userState.addMoney(-price);
                  await userState.addLoot(item.id, 1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Shady deal complete. Received ${item.name}.',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(60, 30),
                ),
                child: const Text(
                  'PURCHASE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMysteryBox(ShopItem box, UserState userState) {
    Color boxColor;
    if (box.id == 'bronze_box')
      boxColor = Colors.brown[400]!;
    else if (box.id == 'silver_box')
      boxColor = Colors.grey[300]!;
    else
      boxColor = Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E), // Darker surface
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: boxColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2, color: boxColor, size: 42),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  box.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: boxColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  box.description,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '${box.price} Tk.',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final user = userState.currentUser;
                  if (user == null) return;
                  if (user.money < box.price) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Not enough Taka to gamble.'),
                      ),
                    );
                    return;
                  }
                  await userState.addMoney(-box.price);
                  // Open Box logic
                  final resultStr = MarketService.openMysteryBox(
                    box.id,
                    user.inventory,
                    user.money,
                    (amt) => userState.addMoney(amt),
                    (id, qty) => userState.addLoot(id, qty),
                  );

                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A2E),
                        title: Text(
                          box.name,
                          style: TextStyle(
                            color: boxColor,
                            fontFamily: 'PressStart2P',
                            fontSize: 12,
                          ),
                        ),
                        content: Text(
                          resultStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: boxColor.withValues(alpha: 0.2),
                  side: BorderSide(color: boxColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(60, 30),
                ),
                child: const Text(
                  'OPEN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellTab() {
    return Consumer<UserState>(
      builder: (context, userState, _) {
        final inv = userState.currentUser?.inventory ?? {};
        final ownedItems = inv.entries
            .where(
              (e) =>
                  e.value > 0 &&
                  !_rodIds.contains(e.key) &&
                  !e.key.endsWith('_active'),
            )
            .toList();

        if (ownedItems.isEmpty) {
          return const Center(
            child: Text(
              'NO ITEMS TO SELL',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ownedItems.length,
          itemBuilder: (context, index) {
            final entry = ownedItems[index];
            final itemId = entry.key;
            final count = entry.value;
            final config = _allItemConfigs.firstWhere(
              (i) => i.id == itemId,
              orElse: () => ShopItem(
                id: itemId,
                name: itemId.replaceAll('_', ' '),
                description: '',
                price: 100,
                category: 'misc',
              ),
            );

            final sellPrice = MarketService.getSellPrice(
              itemId,
              config.price,
              TimeService().currentGameTime,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildItemIcon(config),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Owned: $count',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$sellPrice Tk.',
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 10,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showSellDialog(config, count),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dangerLight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text(
                          'SELL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSellDialog(ShopItem item, int maxQty) {
    final userState = Provider.of<UserState>(context, listen: false);
    int qty = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final sellPrice = MarketService.getSellPrice(
            item.id,
            item.price,
            TimeService().currentGameTime,
          );
          final total = sellPrice * qty;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Text(
              'SELL ${item.name.toUpperCase()}',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: AppColors.dangerLight,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How many do you want to sell?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: qty > 1 ? () => setLocal(() => qty--) : null,
                    ),
                    Text(
                      '$qty / $maxQty',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: qty < maxQty
                          ? () => setLocal(() => qty++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (maxQty > 1)
                  Slider(
                    value: qty.toDouble(),
                    min: 1,
                    max: maxQty.toDouble(),
                    divisions: maxQty - 1,
                    label: '$qty',
                    onChanged: (v) => setLocal(() => qty = v.round()),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Total: ',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${total.toStringAsFixed(0)} Tk.',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final sellPrice = (item.price * 0.5).round();
                  final success = await userState.sellItem(
                    item.id,
                    qty,
                    sellPrice,
                  );
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Sold $qty× ${item.name} for ${total.toStringAsFixed(0)} Taka',
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dangerLight,
                ),
                child: const Text('SELL'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTakaBalance({bool isBlackMarket = false}) {
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
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amberAccent, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${money.toStringAsFixed(0)} Tk.',
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

  Widget _buildFilterDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            color: AppColors.surface,
            child: const Text(
              'FILTERS',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryNames.entries.map((e) {
                    final isSelected = _selectedCategory == e.key;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: isSelected,
                      onSelected: (v) {
                        if (v) {
                          setState(() {
                            _selectedCategory = e.key;
                          });
                        }
                      },
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.white70,
                        fontSize: 11,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text(
                'APPLY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final isRod = _rodIds.contains(item.id);
    return Consumer<UserState>(
      builder: (context, userState, _) {
        final gameTime = TimeService().currentGameTime;
        final currentPrice = MarketService.getCurrentPrice(
          item.id,
          item.price,
          gameTime,
        );
        final multiplier = MarketService.getPriceMultiplier(item.id, gameTime);

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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      color: AppColors.background.withValues(alpha: 0.3),
                      child: Center(child: _buildItemIcon(item)),
                    ),
                    if (multiplier < 0.85)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildBadge('DISCOUNT!', Colors.green),
                      )
                    else if (multiplier > 1.35)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildBadge('SPIKE!', Colors.orange),
                      ),
                    // Embedded Graph in image area bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 30,
                        child: _MarketGraph(
                          itemId: item.id,
                          basePrice: item.price,
                          time: gameTime,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
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
                    const SizedBox(height: 4),
                    Text(
                      'Owned: $owned',
                      style: GoogleFonts.inter(
                        color: owned > 0
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: _buyButton(
                  label: '$currentPrice Tk.',
                  onTap: () => _showBuyDialog(item),
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 6,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MarketGraph extends StatelessWidget {
  final String itemId;
  final int basePrice;
  final GameTime time;

  const _MarketGraph({
    required this.itemId,
    required this.basePrice,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final history = MarketService.getPriceHistory(itemId, basePrice, time);
    final isUp = history.last >= history.first;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: history.length.toDouble() - 1,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              history.length,
              (i) => FlSpot(i.toDouble(), history[i]),
            ),
            isCurved: true,
            color: isUp ? Colors.greenAccent : Colors.redAccent,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: (isUp ? Colors.greenAccent : Colors.redAccent).withValues(
                alpha: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
