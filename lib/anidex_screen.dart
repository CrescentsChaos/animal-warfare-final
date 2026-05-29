// lib/anidex_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/shop_item.dart';
import 'package:animal_warfare/widgets/anidex_details_sheet.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
//import 'package:animal_warfare/services/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
//import 'package:animal_warfare/widgets/pop_menu_layout.dart';

class AnidexScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const AnidexScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<AnidexScreen> createState() => _AnidexScreenState();
}

class _AnidexScreenState extends State<AnidexScreen>
    with TickerProviderStateMixin {
  List<Organism> _allOrganisms = [];
  List<Organism> _filteredOrganisms = [];
  List<ShopItem> _allItems = [];

  // Filter Collections
  List<String> _allBiomes = [];
  List<String> _allAbilities = [];
  List<String> _allMoves = [];
  List<String> _allDrops = [];
  List<String> _allCategories = [];
  List<String> _allRarities = [];
  List<String> get _allClasses =>
      _allOrganisms
          .map((o) => o.animalClass)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  List<String> get _allOrders =>
      _allOrganisms
          .where(
            (o) => _selectedClass == null || o.animalClass == _selectedClass,
          )
          .map((o) => o.order)
          .where((s) => s.isNotEmpty && s.toLowerCase() != 'unknown')
          .toSet()
          .toList()
        ..sort();
  List<String> get _allFamilies =>
      _allOrganisms
          .where(
            (o) => _selectedClass == null || o.animalClass == _selectedClass,
          )
          .where((o) => _selectedOrder == null || o.order == _selectedOrder)
          .map((o) => o.family)
          .where((s) => s.isNotEmpty && s.toLowerCase() != 'unknown')
          .toSet()
          .toList()
        ..sort();
  List<String> get _allSubfamilies =>
      _allOrganisms
          .where(
            (o) => _selectedClass == null || o.animalClass == _selectedClass,
          )
          .where((o) => _selectedOrder == null || o.order == _selectedOrder)
          .where((o) => _selectedFamily == null || o.family == _selectedFamily)
          .map((o) => o.subfamily)
          .where((s) => s.isNotEmpty && s.toLowerCase() != 'unknown')
          .toSet()
          .toList()
        ..sort();
  List<String> get _allGenera =>
      _allOrganisms
          .where(
            (o) => _selectedClass == null || o.animalClass == _selectedClass,
          )
          .where((o) => _selectedOrder == null || o.order == _selectedOrder)
          .where((o) => _selectedFamily == null || o.family == _selectedFamily)
          .where(
            (o) =>
                _selectedSubfamily == null || o.subfamily == _selectedSubfamily,
          )
          .map((o) => o.scientificName.split(' ').first)
          .where((s) => s.isNotEmpty && s.toLowerCase() != 'unknown')
          .toSet()
          .toList()
        ..sort();

  List<String> _allDiets = [];

  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // Pagination
  static const int _pageSize = 20;
  int _visibleCount = _pageSize;

  // Filter State
  String? _selectedCategory1;
  String? _selectedCategory2;
  String? _selectedRarity;
  String? _selectedBiome;
  String? _selectedAbility;
  String? _selectedMove;
  String? _selectedDrop;
  String? _selectedClass;
  String? _selectedOrder;
  String? _selectedFamily;
  String? _selectedSubfamily;
  String? _selectedGenus;
  String? _selectedDiet;
  String? _selectedWeight;
  String? _selectedSize;
  String? _selectedRobustness;
  String? _selectedBst;
  String _sortBy = 'NAME';
  bool _isAscending = true;
  bool _excludeMythical = false;

  static const List<String> _allWeights = [
    '< 1 kg',
    '1 - 10 kg',
    '10 - 50 kg',
    '50 - 100 kg',
    '> 100 kg',
  ];

  static const List<String> _allSizes = [
    '< 0.5 m',
    '0.5 - 2 m',
    '2 - 5 m',
    '5 - 10 m',
    '> 10 m',
  ];

  static const List<String> _allRobustness = [
    '< 1 λ',
    '1 - 10 λ',
    '10 - 50 λ',
    '50 - 100 λ',
    '> 100 λ',
  ];

  static const List<String> _allBst = [
    '< 300',
    '300 - 450',
    '450 - 550',
    '550 - 650',
    '> 650',
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadData();
    _searchController.addListener(() {
      _applyFilters();
      _resetScroll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_visibleCount < _filteredOrganisms.length) {
        setState(() {
          _visibleCount += _pageSize;
        });
      }
    }
  }

  void _resetScroll() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _visibleCount = _pageSize;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      final List<dynamic> animalsData = json.decode(response);
      _allOrganisms = animalsData.map((j) => Organism.fromJson(j)).toList();
      _allItems = await ShopItem.loadAll();

      _allBiomes =
          _allOrganisms
              .map((o) => o.habitat)
              .expand((h) => h.split(',').map((s) => s.trim()))
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      _allAbilities =
          _allOrganisms
              .map((o) => o.abilities)
              .expand((a) => a.split(',').map((s) => s.trim()))
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      _allMoves =
          _allOrganisms
              .map((o) => o.moves)
              .expand((m) => m.split(',').map((s) => s.trim()))
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      _allDrops =
          _allOrganisms
              .map((o) => o.drops)
              .expand((d) => d.split(',').map((s) => s.trim()))
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      _allCategories =
          ElementalType.values.map((e) => e.name.toUpperCase()).toList()
            ..sort();
      _allRarities =
          _allOrganisms
              .map((o) => o.rarity)
              .expand((d) => d.split(',').map((s) => s.trim()))
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      _allDiets =
          _allOrganisms
              .map((o) => o.diet)
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading anidex data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    _filteredOrganisms = _allOrganisms.where((org) {
      if (query.isNotEmpty &&
          !org.name.toLowerCase().contains(query) &&
          !org.scientificName.toLowerCase().contains(query)) {
        return false;
      }
      if (_excludeMythical && org.rarity.toLowerCase().contains('mythical')) {
        return false;
      }
      if (_selectedRarity != null &&
          !org.rarity.toLowerCase().contains(_selectedRarity!.toLowerCase())) {
        return false;
      }
      if (_selectedCategory1 != null &&
          !org.category.toUpperCase().contains(_selectedCategory1!)) {
        return false;
      }
      if (_selectedCategory2 != null &&
          !org.category.toUpperCase().contains(_selectedCategory2!)) {
        return false;
      }
      if (_selectedBiome != null && !org.habitat.contains(_selectedBiome!)) {
        return false;
      }
      if (_selectedAbility != null &&
          !org.abilities.contains(_selectedAbility!)) {
        return false;
      }
      if (_selectedMove != null && !org.moves.contains(_selectedMove!)) {
        return false;
      }
      if (_selectedDrop != null && !org.drops.contains(_selectedDrop!)) {
        return false;
      }
      if (_selectedClass != null && org.animalClass != _selectedClass) {
        return false;
      }
      if (_selectedOrder != null && org.order != _selectedOrder) {
        return false;
      }
      if (_selectedFamily != null && org.family != _selectedFamily) {
        return false;
      }
      if (_selectedSubfamily != null && org.subfamily != _selectedSubfamily) {
        return false;
      }
      if (_selectedGenus != null &&
          org.scientificName.split(' ').first != _selectedGenus) {
        return false;
      }
      if (_selectedDiet != null && org.diet != _selectedDiet) {
        return false;
      }
      if (_selectedWeight != null) {
        final w = org.weight;
        if (_selectedWeight == '< 1 kg' && w >= 1) return false;
        if (_selectedWeight == '1 - 10 kg' && (w < 1 || w >= 10)) return false;
        if (_selectedWeight == '10 - 50 kg' && (w < 10 || w >= 50)) {
          return false;
        }
        if (_selectedWeight == '50 - 100 kg' && (w < 50 || w >= 100)) {
          return false;
        }
        if (_selectedWeight == '> 100 kg' && w < 100) return false;
      }
      if (_selectedSize != null) {
        final s = org.size;
        if (_selectedSize == '< 0.5 m' && s >= 0.5) return false;
        if (_selectedSize == '0.5 - 2 m' && (s < 0.5 || s >= 2)) return false;
        if (_selectedSize == '2 - 5 m' && (s < 2 || s >= 5)) return false;
        if (_selectedSize == '5 - 10 m' && (s < 5 || s >= 10)) return false;
        if (_selectedSize == '> 10 m' && s < 10) return false;
      }
      if (_selectedRobustness != null) {
        final r = org.robustness;
        if (_selectedRobustness == '< 1 λ' && r >= 1) return false;
        if (_selectedRobustness == '1 - 10 λ' && (r < 1 || r >= 10)) {
          return false;
        }
        if (_selectedRobustness == '10 - 50 λ' && (r < 10 || r >= 50)) {
          return false;
        }
        if (_selectedRobustness == '50 - 100 λ' && (r < 50 || r >= 100)) {
          return false;
        }
        if (_selectedRobustness == '> 100 λ' && r < 100) return false;
      }
      if (_selectedBst != null) {
        final bst = org.bst;
        if (_selectedBst == '< 300' && bst >= 300) return false;
        if (_selectedBst == '300 - 450' && (bst < 300 || bst >= 450)) {
          return false;
        }
        if (_selectedBst == '450 - 550' && (bst < 450 || bst >= 550)) {
          return false;
        }
        if (_selectedBst == '550 - 650' && (bst < 550 || bst >= 650)) {
          return false;
        }
        if (_selectedBst == '> 650' && bst < 650) return false;
      }
      return true;
    }).toList();

    _filteredOrganisms.sort((a, b) {
      int result = 0;
      switch (_sortBy) {
        case 'HEALTH':
          result = b.health.compareTo(a.health);
          break;
        case 'ATTACK':
          result = b.attack.compareTo(a.attack);
          break;
        case 'DEFENSE':
          result = b.defense.compareTo(a.defense);
          break;
        case 'POWER':
          result = b.power.compareTo(a.power);
          break;
        case 'RESISTANCE':
          result = b.resistance.compareTo(a.resistance);
          break;
        case 'SPEED':
          result = b.speed.compareTo(a.speed);
          break;
        case 'BST':
          result = b.bst.compareTo(a.bst);
          break;
        case 'WEIGHT':
          result = b.weight.compareTo(a.weight);
          break;
        case 'SIZE':
          result = b.size.compareTo(a.size);
          break;
        case 'ROBUSTNESS':
          result = b.robustness.compareTo(a.robustness);
          break;
        case 'TAXONOMY':
          result = a.animalClass.compareTo(b.animalClass);
          if (result == 0) {
            result = a.order.compareTo(b.order);
            if (result == 0) {
              result = a.family.compareTo(b.family);
              if (result == 0) {
                result = a.subfamily.compareTo(b.subfamily);
                if (result == 0) {
                  result = a.scientificName
                      .split(' ')
                      .first
                      .compareTo(b.scientificName.split(' ').first);
                  if (result == 0) {
                    result = a.name.compareTo(b.name);
                  }
                }
              }
            }
          }
          break;
        default:
          result = a.name.compareTo(b.name);
          break;
      }
      return _isAscending ? result : -result;
    });

    if (mounted) setState(() {});
  }

  bool _isDiscovered(Organism organism) {
    final userState = Provider.of<UserState>(context, listen: false);
    if (userState.currentUser?.anidexUnlocked == true) return true;
    return userState.currentUser?.discoveredOrganisms.contains(organism.name) ??
        false;
  }

  bool _isCaptured(Organism organism) {
    final userState = Provider.of<UserState>(context, listen: false);
    if (userState.currentUser?.anidexUnlocked == true) return true;
    // Use the persistent 'captured' flag in speciesStats
    final stats = userState.currentUser?.speciesStats[organism.name];
    if (stats != null && stats['captured'] == 1) return true;

    // Fallback to current box (though speciesStats should be updated on capture)
    return userState.currentUser?.capturedOrganisms.any(
          (co) => co.baseOrganism.name == organism.name,
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('DATABASE'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.highlightColor,
          labelStyle: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'ANIMALS'),
            Tab(text: 'ITEMS'),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: Image.asset(
                'assets/icon/map_tools.png',
                width: 24,
                height: 24,
              ),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildFilterDrawer(),
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            _buildStickySearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.highlightColor,
                          ),
                        )
                      : _buildAnimalsGrid(),
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.highlightColor,
                          ),
                        )
                      : _buildItemsGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickySearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'SEARCH SYSTEM...',
          hintStyle: GoogleFonts.orbitron(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/icon/bio_scanner.png',
              width: 18,
              height: 18,
            ),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildAnimalsGrid() {
    if (_filteredOrganisms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/animal_dex.png', width: 48, height: 48),
            const SizedBox(height: 16),
            Text(
              'NO MATCHING DATA',
              style: AppTextStyles.body(
                context,
                baseSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    final displayList = _filteredOrganisms.take(_visibleCount).toList();

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount:
          displayList.length +
          (_visibleCount < _filteredOrganisms.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayList.length) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.highlightColor),
          );
        }
        final org = displayList[index];
        final discovered = _isDiscovered(org);
        final captured = _isCaptured(org);
        return _buildAnimalCard(org, discovered, captured);
      },
    );
  }

  Widget _buildAnimalCard(Organism org, bool discovered, bool captured) {
    final rarityColor = _getRarityColor(org.rarity);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AnidexDetailsPage(organism: org, showScaledStats: false),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          image: discovered
              ? DecorationImage(
                  image: AssetImage(_getRarityBackground(org.rarity)),
                  fit: BoxFit.cover,
                  opacity: 0.4,
                )
              : null,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              discovered
                  ? rarityColor.withValues(alpha: 0.3)
                  : Colors.grey.shade900,
              AppColors.surface, // Using a solid surface color
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: discovered
                ? rarityColor.withValues(alpha: 0.5)
                : Colors.white24,
            width: 1.5,
          ),
          boxShadow: discovered
              ? [
                  BoxShadow(
                    color: rarityColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (discovered)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              rarityColor.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Hero(
                      tag: 'anidex_sprite_${org.name}',
                      child: _OrganismSpriteDisplay(
                        organism: org,
                        isDiscovered: discovered,
                        isCaptured: captured,
                        silhouetteColor: Colors.black,
                      ),
                    ),
                  ),
                  if (captured)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Image.asset(
                        'assets/icon/start_game.png',
                        width: 16,
                        height: 16,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border(
                  top: BorderSide(
                    color: discovered
                        ? rarityColor.withValues(alpha: 0.3)
                        : Colors.white10,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      discovered ? org.name.toUpperCase() : '???',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: discovered ? Colors.white : Colors.white38,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    discovered
                        ? (captured ? org.rarity.toUpperCase() : 'SEEN')
                        : 'UNIDENTIFIED',
                    style: GoogleFonts.inter(
                      color: discovered
                          ? (captured ? rarityColor : Colors.grey[400])
                          : Colors.white24,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsGrid() {
    final query = _searchController.text.toLowerCase();
    final items = _allItems
        .where(
          (it) =>
              it.name.toLowerCase().contains(query) ||
              it.category.toLowerCase().contains(query),
        )
        .toList();

    if (items.isEmpty) {
      return Center(
        child: Text(
          'NO ITEMS MATCH',
          style: AppTextStyles.body(
            context,
            baseSize: 10,
            color: Colors.white24,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final spritePath =
            'assets/items/${item.name.toLowerCase().replaceAll(' ', '-')}.png';

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface, // Solid background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.highlightColor.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    spritePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, _) => Image.asset(
                      _getItemIcon(item.category),
                      color: _getItemColor(item.category),
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  item.name.replaceAll('_', ' ').toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${item.price}G',
                style: const TextStyle(
                  color: AppColors.highlightColor,
                  fontSize: 7,
                  fontFamily: 'PressStart2P',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildFilterLabel('SORT BY'),
                _buildSortOptions(),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'EXCLUDE MYTHICALS',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: Colors.white54,
                    ),
                  ),
                  value: _excludeMythical,
                  activeThumbColor: AppColors.highlightColor,
                  onChanged: (v) => setState(() => _excludeMythical = v),
                ),
                const SizedBox(height: 24),
                _buildSearchableFilter(
                  'BIOME',
                  _selectedBiome,
                  _allBiomes,
                  (v) => setState(() => _selectedBiome = v),
                ),
                _buildSearchableFilter(
                  'RARITY',
                  _selectedRarity,
                  _allRarities,
                  (v) => setState(() => _selectedRarity = v),
                ),
                _buildSearchableFilter(
                  'CATEGORY 1',
                  _selectedCategory1,
                  _allCategories,
                  (v) => setState(() => _selectedCategory1 = v),
                ),
                _buildSearchableFilter(
                  'CATEGORY 2',
                  _selectedCategory2,
                  _allCategories,
                  (v) => setState(() => _selectedCategory2 = v),
                ),
                _buildSearchableFilter(
                  'CLASS',
                  _selectedClass,
                  _allClasses,
                  (v) => setState(() {
                    _selectedClass = v;
                    _selectedOrder = null;
                    _selectedFamily = null;
                    _selectedSubfamily = null;
                    _selectedGenus = null;
                  }),
                ),
                _buildSearchableFilter(
                  'ORDER',
                  _selectedOrder,
                  _allOrders,
                  (v) => setState(() {
                    _selectedOrder = v;
                    _selectedFamily = null;
                    _selectedSubfamily = null;
                    _selectedGenus = null;
                  }),
                ),
                _buildSearchableFilter(
                  'FAMILY',
                  _selectedFamily,
                  _allFamilies,
                  (v) => setState(() {
                    _selectedFamily = v;
                    _selectedSubfamily = null;
                    _selectedGenus = null;
                  }),
                ),
                _buildSearchableFilter(
                  'SUBFAMILY',
                  _selectedSubfamily,
                  _allSubfamilies,
                  (v) => setState(() {
                    _selectedSubfamily = v;
                    _selectedGenus = null;
                  }),
                ),
                _buildSearchableFilter(
                  'GENUS',
                  _selectedGenus,
                  _allGenera,
                  (v) => setState(() => _selectedGenus = v),
                ),
                _buildSearchableFilter(
                  'DIET',
                  _selectedDiet,
                  _allDiets,
                  (v) => setState(() => _selectedDiet = v),
                ),
                _buildSearchableFilter(
                  'WEIGHT',
                  _selectedWeight,
                  _allWeights,
                  (v) => setState(() => _selectedWeight = v),
                ),
                _buildSearchableFilter(
                  'SIZE',
                  _selectedSize,
                  _allSizes,
                  (v) => setState(() => _selectedSize = v),
                ),
                _buildSearchableFilter(
                  'ABILITY',
                  _selectedAbility,
                  _allAbilities,
                  (v) => setState(() => _selectedAbility = v),
                ),
                _buildSearchableFilter(
                  'MOVE',
                  _selectedMove,
                  _allMoves,
                  (v) => setState(() => _selectedMove = v),
                ),
                _buildSearchableFilter(
                  'DROP',
                  _selectedDrop,
                  _allDrops,
                  (v) => setState(() => _selectedDrop = v),
                ),
                _buildSearchableFilter(
                  'ROBUSTNESS',
                  _selectedRobustness,
                  _allRobustness,
                  (v) => setState(() => _selectedRobustness = v),
                ),
                _buildSearchableFilter(
                  'BST',
                  _selectedBst,
                  _allBst,
                  (v) => setState(() => _selectedBst = v),
                ),
              ],
            ),
          ),
          _buildDrawerFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILTERS',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: AppColors.highlightColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'REFINE DATABASE ENTRIES',
            style: TextStyle(
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black.withValues(alpha: 0.2),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory1 = null;
                  _selectedCategory2 = null;
                  _selectedBiome = null;
                  _selectedAbility = null;
                  _selectedMove = null;
                  _selectedDrop = null;
                  _selectedClass = null;
                  _selectedOrder = null;
                  _selectedFamily = null;
                  _selectedSubfamily = null;
                  _selectedGenus = null;
                  _selectedDiet = null;
                  _selectedWeight = null;
                  _selectedSize = null;
                  _selectedRobustness = null;
                  _selectedBst = null;
                  _sortBy = 'NAME';
                  _isAscending = true;
                  _excludeMythical = false;
                });
                _applyFilters();
              },
              child: const Text(
                'RESET',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                _applyFilters();
                _resetScroll();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.highlightColor,
              ),
              child: const Text(
                'APPLY',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 10,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildSortOptions() {
    final options = [
      'NAME',
      'HEALTH',
      'ATTACK',
      'DEFENSE',
      'POWER',
      'RESISTANCE',
      'SPEED',
      'BST',
      'WEIGHT',
      'SIZE',
      'ROBUSTNESS',
      'TAXONOMY',
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = _sortBy == opt;
            return ChoiceChip(
              label: Text(opt.toUpperCase()),
              selected: isSelected,
              onSelected: (v) {
                if (v) setState(() => _sortBy = opt);
              },
              backgroundColor: Colors.white10,
              selectedColor: AppColors.highlightColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.highlightColor : Colors.white54,
                fontSize: 9,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.highlightColor : Colors.white12,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'ORDER: ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 8,
                fontFamily: 'PressStart2P',
              ),
            ),
            InkWell(
              onTap: () {
                setState(() => _isAscending = !_isAscending);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Text(
                      _isAscending ? 'ASCENDING' : 'DESCENDING',
                      style: const TextStyle(
                        color: AppColors.highlightColor,
                        fontSize: 8,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      color: AppColors.highlightColor,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchableFilter(
    String label,
    String? current,
    List<String> items,
    Function(String?) onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterLabel(label),
          InkWell(
            onTap: () => _showSelectionDialog(label, items, onSelected),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      current ?? 'ALL',
                      style: TextStyle(
                        color: current == null ? Colors.white24 : Colors.white,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.highlightColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSelectionDialog(
    String title,
    List<String> items,
    Function(String?) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String query = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = items
                .where((i) => i.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.highlightColor.withValues(alpha: 0.3),
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: AppColors.highlightColor,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'SEARCH...',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.search_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setDialogState(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              title: const Text(
                                'ALL (NONE)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                onSelected(null);
                                Navigator.pop(context);
                              },
                            );
                          }
                          final item = filtered[index - 1];
                          return ListTile(
                            title: Text(
                              item.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              onSelected(item);
                              Navigator.pop(context);
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
      },
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return const Color(0xFF2ECC71);
      case 'rare':
        return Colors.blueAccent;
      case 'epic':
        return Colors.purpleAccent;
      case 'legendary':
        return Colors.orangeAccent;
      case 'mythical':
        return Colors.pinkAccent;
      default:
        return Colors.white;
    }
  }

  String _getItemIcon(String cat) {
    if (cat.contains('rod')) {
      return 'assets/icon/water.png';
    }
    if (cat.contains('talisman')) {
      return 'assets/icon/mystic.png';
    }
    return 'assets/icon/inventory.png';
  }

  Color _getItemColor(String cat) {
    if (cat.contains('rod')) {
      return Colors.blueAccent;
    }
    if (cat.contains('talisman')) {
      return Colors.purpleAccent;
    }
    return Colors.grey.shade400;
  }

  String _getRarityBackground(String rarity) {
    final r = rarity.toLowerCase();
    if (r == 'common') return 'assets/icon/common.png';
    if (r == 'uncommon') return 'assets/icon/uncommon.png';
    if (r == 'rare') return 'assets/icon/rare.png';
    if (r == 'epic') return 'assets/icon/epic.png';
    if (r == 'legendary') return 'assets/icon/legendary.png';
    if (r == 'mythical') return 'assets/icon/mythical.png';
    return 'assets/icon/common.png';
  }
}

class _OrganismSpriteDisplay extends StatefulWidget {
  final Organism organism;
  final bool isDiscovered;
  final bool isCaptured;
  final Color silhouetteColor;

  const _OrganismSpriteDisplay({
    required this.organism,
    required this.isDiscovered,
    required this.isCaptured,
    required this.silhouetteColor,
  });

  @override
  __OrganismSpriteDisplayState createState() => __OrganismSpriteDisplayState();
}

class __OrganismSpriteDisplayState extends State<_OrganismSpriteDisplay> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  @override
  void didUpdateWidget(_OrganismSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organism.name != widget.organism.name) {
      _initPath();
    }
  }

  void _initPath() async {
    setState(() {
      _imagePath = null;
    });

    final fileName = widget.organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll("-", '_');
    final local = 'assets/sprites/$fileName.png';
    try {
      await rootBundle.load(local);
      if (mounted) setState(() => _imagePath = local);
    } catch (_) {
      setState(() {
        String spriteUrl = widget.organism.sprite;
        if (spriteUrl.startsWith('http')) {
          _imagePath =
              local; // Force it to remain the failed local path so the error builder kicks in
        } else {
          if (spriteUrl.startsWith('file:///')) {
            spriteUrl = spriteUrl.replaceFirst('file:///', '');
          }
          if (spriteUrl.isNotEmpty) {
            _imagePath = spriteUrl.startsWith('assets/')
                ? spriteUrl
                : 'assets/sprites/$spriteUrl';
          } else {
            _imagePath = local;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imagePath == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white12),
      );
    }

    // If discovered, show full color. If not, show silhouette.
    return buildSilhouetteSprite(
      imageUrl: _imagePath!,
      silhouetteColor: widget.isDiscovered ? null : Colors.black45,
      outlineColor: widget.isDiscovered ? Colors.black : Colors.white,
      outlineWidth: 2.0,
      fit: BoxFit.contain,
    );
  }
}
