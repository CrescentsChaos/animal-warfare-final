// lib/news_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/services/news_service.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with TickerProviderStateMixin {
  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  late AnimationController _fadeController;
  int? _expandedIndex;
  int _refreshSeed = 0;
  bool _isRefreshing = false;

  static const List<String> _filterOptions = [
    'ALL',
    'ECOLOGY',
    'SCIENCE',
    'BATTLE META',
    'EXPLORATION',
    'TAXONOMY',
    'CONSERVATION',
    'BIOMETRICS',
    'WEATHER',
    'DISCOVERY',
    'STATISTICS',
    'PROFILE',
    'OPINION',
    'COOKING',
    'CRIME',
    'PALEONTOLOGY',
  ];

  String _searchQuery = '';

  List<NewsArticle> get _filteredArticles {
    var filtered = _articles;
    if (_selectedFilter != 'ALL') {
      filtered = filtered.where((a) => a.category == _selectedFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (a) =>
                a.headline.toLowerCase().contains(q) ||
                (a.organismName?.toLowerCase().contains(q) ?? false) ||
                a.channel.toLowerCase().contains(q),
          )
          .toList();
    }
    return filtered;
  }

  static const Map<String, Color> _categoryColors = {
    'ECOLOGY': Color(0xFF4CAF50),
    'SCIENCE': Color(0xFF2196F3),
    'BATTLE META': Color(0xFFF44336),
    'EXPLORATION': Color(0xFFFF9800),
    'TAXONOMY': Color(0xFF9C27B0),
    'CONSERVATION': Color(0xFF009688),
    'BIOMETRICS': Color(0xFF00BCD4),
    'WEATHER': Color(0xFF607D8B),
    'DISCOVERY': Color(0xFFFFEB3B),
    'STATISTICS': Color(0xFF3F51B5),
    'PROFILE': Color(0xFFE91E63),
    'OPINION': Color(0xFF795548),
    'COOKING': Color(0xFFFF5722),
    'CRIME': Color(0xFF212121),
    'PALEONTOLOGY': Color(0xFF6D4C41),
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadNews();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    try {
      await NewsService.initialize();
      final raw = await rootBundle.loadString('assets/Organisms.json');
      final List<dynamic> jsonList = json.decode(raw);
      final organisms = jsonList.map((j) => Organism.fromJson(j)).toList();
      final gameTime = TimeService().currentGameTime;
      final articles = NewsService.generateDailyNews(
        organisms,
        gameTime,
        refreshSeed: _refreshSeed,
      );

      // Sort by publish time descending (latest first)
      articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('Error loading news: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshSeed += 100; // Shift the random sequence
    });
    await _loadNews();
    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameTime = TimeService().currentGameTime;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── App Bar ───
          SliverAppBar(
            backgroundColor: AppColors.background,
            expandedHeight: 180, // More space for search
            floating: true,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      AppColors.background,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE DAILY WIRE',
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            Text(
                              'WILDLIFE INTELLIGENCE NETWORK',
                              style: GoogleFonts.inter(
                                color: AppColors.highlight,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Search Bar
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            onChanged: (val) {
                              setState(() => _searchQuery = val);
                            },
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search organisms or headlines...',
                              hintStyle: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.white70,
                ),
                onPressed: () {},
              ),
              IconButton(
                onPressed: _isRefreshing ? null : _handleRefresh,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh Stories',
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ─── Breaking Ticker ───
          if (_articles.isNotEmpty)
            SliverToBoxAdapter(child: _buildBreakingTicker()),

          // ─── Category Filter Chips ───
          SliverToBoxAdapter(
            child: Container(
              height: 48,
              margin: const EdgeInsets.only(top: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filterOptions.length,
                itemBuilder: (context, index) {
                  final filter = _filterOptions[index];
                  final isActive = _selectedFilter == filter;
                  final color = filter == 'ALL'
                      ? AppColors.highlight
                      : (_categoryColors[filter] ?? AppColors.primary);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter,
                        style: GoogleFonts.inter(
                          color: isActive ? Colors.white : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      selected: isActive,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                          _expandedIndex = null;
                        });
                      },
                      backgroundColor: AppColors.surface,
                      selectedColor: color.withValues(alpha: 0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isActive
                              ? color.withValues(alpha: 0.6)
                              : AppColors.border,
                        ),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── Daily Briefing ───
          if (_articles.isNotEmpty && _selectedFilter == 'ALL')
            SliverToBoxAdapter(child: _buildDailyBriefing()),

          // ─── News Feed ───
          if (!_isLoading) ...[
            if (_selectedFilter == 'ALL' && _filteredArticles.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildHeroArticle(_filteredArticles[0]),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 260,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final articleIndex = (_selectedFilter == 'ALL')
                        ? index + 1
                        : index;
                    if (articleIndex >= _filteredArticles.length) return null;
                    return _buildGridArticleCard(
                      _filteredArticles[articleIndex],
                    );
                  },
                  childCount: (_selectedFilter == 'ALL')
                      ? (_filteredArticles.length - 1).clamp(0, 1000)
                      : _filteredArticles.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildBreakingTicker() {
    final legendaryArticles = _articles
        .where((a) => a.headline.contains('🚨'))
        .toList();
    if (legendaryArticles.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: const Border.symmetric(
          horizontal: BorderSide(color: Colors.red, width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics:
            const NeverScrollableScrollPhysics(), // Just for layout, we can animate it later
        itemCount: 1,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'BREAKING:',
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  legendaryArticles
                      .map((a) => a.headline.replaceFirst('🚨 BREAKING: ', ''))
                      .join('  •  '),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroArticle(NewsArticle article) {
    final catColor = _categoryColors[article.category] ?? AppColors.primary;

    return GestureDetector(
      onTap: () => _showArticleDetail(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: AssetImage(article.biome != null 
                ? 'assets/biomes/${article.biome}.png' 
                : 'assets/background.png'),
            fit: BoxFit.cover,
            opacity: 0.4,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [catColor.withValues(alpha: 0.4), AppColors.surface],
          ),
          border: Border.all(
            color: catColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: catColor.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -20,
              child: Opacity(
                opacity: 0.15,
                child: Text(
                  article.channelIcon,
                  style: const TextStyle(fontSize: 200),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryPill(article.category, catColor),
                  const Spacer(),
                  Text(
                    article.headline,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: catColor.withValues(alpha: 0.2),
                        child: Text(
                          article.author[0],
                          style: GoogleFonts.inter(
                            color: catColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        article.author,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'READ MORE →',
                        style: GoogleFonts.inter(
                          color: AppColors.highlight,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
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
    );
  }

  Widget _buildArticleCard(NewsArticle article) {
    final catColor = _categoryColors[article.category] ?? AppColors.primary;

    return GestureDetector(
      onTap: () => _showArticleDetail(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        article.channelIcon,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        article.channel.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: catColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.headline,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${article.author} • ${_formatTime(article.publishedAt)}',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
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

  // ─── Article detail modal ──────────────────────────────────────────

  void _showArticleDetail(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NewsDetailScreen(article: article, categoryColors: _categoryColors),
      ),
    ).then((_) => setState(() {})); // Sync likes/comments if they changed
  }

  Widget _buildReactionItem(
    IconData icon,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(NewsComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: comment.user == 'You'
                    ? AppColors.highlight.withValues(alpha: 0.2)
                    : Colors.blueAccent.withValues(alpha: 0.2),
                child: Text(
                  comment.user[0].toUpperCase(),
                  style: GoogleFonts.inter(
                    color: comment.user == 'You'
                        ? AppColors.highlight
                        : Colors.blueAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment.user,
                style: GoogleFonts.inter(
                  color: comment.user == 'You'
                      ? AppColors.highlight
                      : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                comment.timeAgo,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.text,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  Widget _buildCategoryPill(
    String category,
    Color color, {
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(
          color: color,
          fontSize: small ? 8 : 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildDailyBriefing() {
    final legendaryCount = _articles
        .where((a) => a.headline.contains('🚨'))
        .length;
    final habitat = _articles.isNotEmpty ? _articles.first.category : 'N/A';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.background.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.highlight,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'DAILY BRIEFING',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              _buildCategoryPill('ACTIVE', Colors.green, small: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBriefingItem('METRICS', 'STABLE', Colors.greenAccent),
              _buildBriefingItem(
                'THREATS',
                legendaryCount > 0 ? 'CRITICAL' : 'LOW',
                legendaryCount > 0 ? Colors.redAccent : Colors.blueAccent,
              ),
              _buildBriefingItem(
                'REPORTS',
                '${_articles.length} STORIES',
                AppColors.highlight,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildGridArticleCard(NewsArticle article) {
    final catColor = _categoryColors[article.category] ?? AppColors.primary;

    return GestureDetector(
      onTap: () => _showArticleDetail(article),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with Category Pill
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      image: article.biome != null
                          ? DecorationImage(
                              image: AssetImage('assets/biomes/${article.biome}.png'),
                              fit: BoxFit.cover,
                              opacity: 0.6,
                            )
                          : null,
                    ),
                    child: Hero(
                      tag: 'article_sprite_${article.headline}',
                      child: article.spritePath != null
                          ? Center(
                              child: Image.asset(
                                'assets/sprites/${article.spritePath}',
                                width: 70,
                                height: 70,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Icon(
                              Icons.newspaper,
                              color: catColor.withValues(alpha: 0.2),
                              size: 40,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildCategoryPill(
                      article.category,
                      catColor,
                      small: true,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: article.habitatName != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 8),
                                const SizedBox(width: 2),
                                Text(
                                  article.habitatName!,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // Text area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      article.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _formatTime(article.publishedAt),
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          article.channelIcon,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
