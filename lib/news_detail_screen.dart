import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/services/news_service.dart';
import 'dart:ui';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  final Map<String, Color> categoryColors;

  const NewsDetailScreen({
    super.key,
    required this.article,
    required this.categoryColors,
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final opacity = (_scrollController.offset / 200).clamp(0.0, 1.0);
      if (opacity != _scrollOpacity) {
        setState(() => _scrollOpacity = opacity);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final catColor = widget.categoryColors[article.category] ?? AppColors.primary;
    final readingTime = _calculateReadingTime(article.body);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
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
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Graphic
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              catColor.withValues(alpha: 0.3),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                      // Parallax Sprite
                      Center(
                        child: Hero(
                          tag: 'article_sprite_${article.headline}',
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.2),
                                  blurRadius: 100,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: article.spritePath != null
                                ? Image.asset(
                                    'assets/sprites/${article.spritePath}',
                                    fit: BoxFit.contain,
                                  )
                                : Icon(Icons.newspaper, size: 120, color: catColor.withValues(alpha: 0.2)),
                          ),
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
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: catColor.withValues(alpha: 0.2),
                            child: Text(
                              article.author[0],
                              style: GoogleFonts.inter(color: catColor, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.author,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${article.channel} • ${_formatTime(article.publishedAt)}',
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
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
                      
                      // Community Section
                      _buildCommunityStats(article),
                      const SizedBox(height: 32),
                      
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

          // ─── Top Floating Bar (Appears on Scroll) ───
          if (_scrollOpacity > 0.1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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

          // ─── Bottom Interaction Bar ───
          _buildBottomInputBar(article),
        ],
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
          _buildStatItem(Icons.chat_bubble_outline, _formatNumber(article.commentsCount), Colors.blueAccent, null),
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

  Widget _buildCategoryPill(String category, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
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
