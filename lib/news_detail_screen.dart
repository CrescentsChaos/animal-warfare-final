import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/services/news_service.dart';
import 'dart:ui';
import 'dart:math';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  final Map<String, Color> categoryColors;
  final List<NewsArticle>? allArticles; // For swipe navigation
  final int? currentIndex; // Current article index in allArticles

  const NewsDetailScreen({
    super.key,
    required this.article,
    required this.categoryColors,
    this.allArticles,
    this.currentIndex,
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  late ScrollController _scrollController;
  double _scrollOpacity = 0.0;
  bool _showScrollToTop = false;
  late NewsArticle _currentArticle;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentArticle = widget.article;
    _currentIndex = widget.currentIndex ?? 0;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final opacity = (_scrollController.offset / 200).clamp(0.0, 1.0);
    final showTop = _scrollController.offset > 400;
    if (opacity != _scrollOpacity || showTop != _showScrollToTop) {
      setState(() {
        _scrollOpacity = opacity;
        _showScrollToTop = showTop;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToArticle(int newIndex) {
    if (widget.allArticles == null) return;
    if (newIndex < 0 || newIndex >= widget.allArticles!.length) return;
    setState(() {
      _currentIndex = newIndex;
      _currentArticle = widget.allArticles![newIndex];
      _scrollOpacity = 0.0;
      _showScrollToTop = false;
    });
    // Reset scroll position
    _scrollController.jumpTo(0);
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _calculateReadingTime(String text) {
    final words = text.split(' ').length;
    return (words / 200).ceil(); // 200 wpm
  }

  /// Ensure displayed comment count is never less than actual comments
  int _effectiveCommentCount(NewsArticle article) {
    return max(article.commentsCount, article.comments.length);
  }

  @override
  Widget build(BuildContext context) {
    final article = _currentArticle;
    final catColor = widget.categoryColors[article.category] ?? AppColors.primary;
    final readingTime = _calculateReadingTime(article.body);
    final canSwipePrev = widget.allArticles != null && _currentIndex > 0;
    final canSwipeNext = widget.allArticles != null && _currentIndex < (widget.allArticles!.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300 && canSwipeNext) {
            // Swiped left → next article
            _navigateToArticle(_currentIndex + 1);
          } else if (details.primaryVelocity! > 300 && canSwipePrev) {
            // Swiped right → previous article
            _navigateToArticle(_currentIndex - 1);
          }
        },
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ─── Hero Header ───
                SliverAppBar(
                  expandedHeight: 350,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Graphic
                        Container(
                          decoration: BoxDecoration(
                            image: article.biome != null
                                ? DecorationImage(
                                    image: AssetImage('assets/biomes/${article.biome}.png'),
                                    fit: BoxFit.cover,
                                    opacity: 0.3,
                                  )
                                : null,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                AppColors.background,
                              ],
                            ),
                          ),
                        ),
                        // Parallax Sprite - clean, no background glow
                        Center(
                          child: Hero(
                            tag: 'article_sprite_${article.headline}',
                            child: article.spritePath != null
                                ? Image.asset(
                                    'assets/sprites/${article.spritePath}',
                                    width: 240,
                                    height: 240,
                                    fit: BoxFit.contain,
                                  )
                                : Icon(Icons.newspaper, size: 120, color: Colors.white.withValues(alpha: 0.15)),
                          ),
                        ),
                        // Bottom Fade
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.background.withValues(alpha: 0.8),
                                  AppColors.background,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Article Content ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildCategoryPill(article.category, catColor),
                            if (article.habitatName != null) ...[
                              const SizedBox(width: 8),
                              _buildCategoryPill(article.habitatName!, Colors.white70, small: true),
                            ],
                            const SizedBox(width: 12),
                            Text(
                              '$readingTime MIN READ',
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          article.headline,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            // Author Profile Picture
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: catColor.withValues(alpha: 0.2),
                                child: article.authorIcon != null
                                    ? Image.asset(
                                        article.authorIcon!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Center(
                                          child: Text(
                                            article.author[0],
                                            style: GoogleFonts.inter(color: catColor, fontWeight: FontWeight.w900, fontSize: 18),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          article.author[0],
                                          style: GoogleFonts.inter(color: catColor, fontWeight: FontWeight.w900, fontSize: 18),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      article.author,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Colors.blue, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // Channel Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                      ),
                                      child: Row(
                                        children: [
                                          if (article.channelIcon.startsWith('assets/'))
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: Image.asset(article.channelIcon, width: 10, height: 10, fit: BoxFit.contain),
                                            )
                                          else
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: Text(article.channelIcon, style: const TextStyle(fontSize: 8)),
                                            ),
                                          Text(
                                            article.channel.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              color: AppColors.textMuted,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•  ${_formatTime(article.publishedAt)}',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.bookmark_border, color: Colors.white54),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_outlined, color: Colors.white54),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(color: AppColors.border, thickness: 1),
                        ),
                        Text(
                          article.body,
                          style: GoogleFonts.spectral(
                            color: AppColors.textSecondary,
                            fontSize: 19,
                            height: 1.7,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Swipe hint
                        if (widget.allArticles != null && widget.allArticles!.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (canSwipePrev) ...[
                                  Icon(Icons.chevron_left, color: AppColors.textMuted, size: 16),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  'SWIPE TO NAVIGATE ARTICLES',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                if (canSwipeNext) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
                                ],
                              ],
                            ),
                          ),

                        // Community Section
                        _buildCommunityStats(article),
                        const SizedBox(height: 40),

                        // Channel Info Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  article.channelIcon.startsWith('assets/')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.asset(
                                            article.channelIcon,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            article.channelIcon,
                                            style: const TextStyle(fontSize: 24),
                                          ),
                                        ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PUBLISHED BY',
                                          style: GoogleFonts.inter(
                                            color: catColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        Text(
                                          article.channel,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (article.channelTagline != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  article.channelTagline!,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),
                        
                        Text(
                          'DISCUSSION',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        if (article.comments.isEmpty)
                          _buildEmptyComments()
                        else
                          ...article.comments.map((c) => _buildCommentCard(c)),
                        
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ─── Always-visible Back Button ───
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Top Floating Bar (Appears on Scroll) ───
            if (_scrollOpacity > 0.1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: MediaQuery.of(context).padding.top + 60,
                        color: AppColors.background.withValues(alpha: 0.8 * _scrollOpacity),
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                        child: Center(
                          child: Text(
                            'THE DAILY WIRE',
                            style: GoogleFonts.orbitron(
                              color: Colors.white.withValues(alpha: _scrollOpacity),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ─── Go to Top Button ───
            if (_showScrollToTop)
              Positioned(
                bottom: 90 + MediaQuery.of(context).padding.bottom,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 24),
                      ),
                    ),
                  ),
                ),
              ),

            // ─── Bottom Interaction Bar ───
            _buildBottomInputBar(article),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityStats(NewsArticle article) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            article.isLiked ? Icons.favorite : Icons.favorite_border,
            _formatNumber(article.likes),
            article.isLiked ? Colors.redAccent : Colors.white54,
            () => setState(() {
              article.isLiked = !article.isLiked;
              article.isLiked ? article.likes++ : article.likes--;
            }),
          ),
          _buildStatItem(
            Icons.chat_bubble_outline,
            _formatNumber(_effectiveCommentCount(article)),
            Colors.blueAccent,
            null,
          ),
          _buildStatItem(Icons.repeat_rounded, _formatNumber(article.shares), Colors.greenAccent, null),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(NewsComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comment.user,
                style: GoogleFonts.inter(
                  color: comment.user == 'You' ? AppColors.highlight : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                comment.timeAgo.toUpperCase(),
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment.text,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInputBar(NewsArticle article) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add to the conversation...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (_commentController.text.trim().isNotEmpty) {
                      setState(() {
                        article.comments.insert(0, NewsComment(
                          user: 'You',
                          text: _commentController.text.trim(),
                          timeAgo: 'Just now',
                        ));
                        article.commentsCount++;
                        _commentController.clear();
                      });
                      FocusScope.of(context).unfocus();
                    }
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.highlight,
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String category, Color color, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(small ? 4 : 6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(
          color: color,
          fontSize: small ? 8 : 10, 
          fontWeight: FontWeight.w900, 
          letterSpacing: small ? 0.5 : 1,
        ),
      ),
    );
  }

  Widget _buildEmptyComments() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Be the first to comment', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}
