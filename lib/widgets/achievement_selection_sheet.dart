// lib/widgets/achievement_selection_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/achievement_service.dart';
import 'package:animal_warfare/models/achievement.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AchievementSelectionSheet extends StatefulWidget {
  final List<dynamic> allOrganisms;

  const AchievementSelectionSheet({super.key, required this.allOrganisms});

  @override
  State<AchievementSelectionSheet> createState() =>
      _AchievementSelectionSheetState();
}

class _AchievementSelectionSheetState extends State<AchievementSelectionSheet> {
  late AchievementService _achievementService;
  List<Achievement> _completedAchievements = [];
  List<String> _selectedTitles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final userState = Provider.of<UserState>(context, listen: false);
    _selectedTitles = List<String>.from(
      userState.currentUser?.displayedAchievements ?? [],
    );

    _initAchievementService();
  }

  void _initAchievementService() {
    _achievementService = AchievementService(
      allOrganisms: widget.allOrganisms,
      authService: LocalAuthService(),
    );
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    await _achievementService.loadAchievements();
    final userState = Provider.of<UserState>(context, listen: false);
    final all = _achievementService.getAllAchievements();

    if (mounted) {
      setState(() {
        _completedAchievements = all
            .where(
              (a) =>
                  userState.currentUser?.completedAchievements.contains(
                    a.title,
                  ) ??
                  false,
            )
            .toList();
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(String title) {
    setState(() {
      if (_selectedTitles.contains(title)) {
        _selectedTitles.remove(title);
      } else {
        if (_selectedTitles.length < 3) {
          _selectedTitles.add(title);
        } else {
          // Replace last one or show a message?
          // Let's just limit to 3.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select up to 3 achievements only')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.7.sh,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h, bottom: 20.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SELECT MEDALS',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10.sp,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '${_selectedTitles.length}/3',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10.sp,
                    color: const Color(0xFFDAA520),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFDAA520)),
                  )
                : _completedAchievements.isEmpty
                ? Center(
                    child: Text(
                      'NO COMPLETED ACHIEVEMENTS',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8.sp,
                        color: Colors.white24,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: _completedAchievements.length,
                    itemBuilder: (context, index) {
                      final achievement = _completedAchievements[index];
                      final isSelected = _selectedTitles.contains(
                        achievement.title,
                      );

                      return GestureDetector(
                        onTap: () => _toggleSelection(achievement.title),
                        child: Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFDAA520).withOpacity(0.1)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFDAA520)
                                  : Colors.white.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50.w,
                                height: 50.w,
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black26,
                                ),
                                child: Image.asset(
                                  achievement.imagePath ??
                                      'assets/achievements/medal_bronze.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.military_tech,
                                        color: Color(0xFFDAA520),
                                      ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      achievement.title.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'PressStart2P',
                                        fontSize: 8.sp,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      achievement.description,
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        color: Colors.white54,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFDAA520),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(24.w),
            child: ElevatedButton(
              onPressed: () {
                Provider.of<UserState>(
                  context,
                  listen: false,
                ).updateDisplayedAchievements(_selectedTitles);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDAA520),
                foregroundColor: Colors.black,
                minimumSize: Size(double.infinity, 50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'CONFIRM SELECTION',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 10.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
