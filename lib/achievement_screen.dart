// lib/achievement_screen.dart

import 'package:flutter/material.dart';
// ADDED: Import AchievementService
import 'package:animal_warfare/achievement_service.dart'; 
// ADDED: Import Achievement model (assuming path)
import 'package:animal_warfare/models/achievement.dart'; 
import 'package:animal_warfare/local_auth_service.dart'; 

class AchievementsScreen extends StatefulWidget { // CHANGE: StatelessWidget to StatefulWidget
  final UserData currentUser;
  final List<dynamic> allOrganisms; 
  final LocalAuthService authService; 

  const AchievementsScreen({
    super.key,
    required this.currentUser,
    required this.allOrganisms,
    required this.authService, 
  });

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late AchievementService _achievementService;
  List<Achievement> _achievements = [];
  bool _isLoading = true; // NEW: Loading state

  // Custom retro/military colors
  static const Color primaryButtonColor = Color(0xFF38761D); 
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); 
  static const Color highlightColor = Color(0xFFDAA520); 
  static const Color neonGreen = Color(0xFF39FF14);

  @override
  void initState() {
    super.initState();
    // Initialize the service
    _achievementService = AchievementService(
      allOrganisms: widget.allOrganisms, 
      authService: widget.authService,
    );
    // Asynchronously load the achievements and update state
    _loadAchievements();
  }
  
  // NEW: Asynchronous loading method
  Future<void> _loadAchievements() async {
    // CHANGED: Call the public loadAchievements() method.
    await _achievementService.loadAchievements(); 
    if (mounted) {
      setState(() {
        _achievements = _achievementService.getAllAchievements();
        _isLoading = false;
      });
    }
  }

  Widget _buildAchievementTile(Achievement achievement, bool completed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: completed 
            ? primaryButtonColor.withOpacity(0.9) 
            : secondaryButtonColor.withOpacity(0.7), 
        border: Border.all(
          color: completed ? highlightColor : Colors.white24,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        leading: Icon(
          completed ? Icons.military_tech : Icons.lock,
          color: completed ? highlightColor : Colors.white38,
          size: 40,
        ),
        title: Text(
          achievement.title.toUpperCase(),
          style: TextStyle(
            color: completed ? highlightColor : Colors.white70,
            fontFamily: 'PressStart2P',
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          achievement.description,
          style: TextStyle(
            color: completed ? Colors.white : Colors.white54,
            fontFamily: 'PressStart2P',
            fontSize: 10,
          ),
        ),
        trailing: completed 
            ? const Icon(Icons.check_circle, color: neonGreen) 
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACHIEVEMENTS'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 16
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(10.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: highlightColor)) // NEW: Show loading
            : ListView(
                padding: const EdgeInsets.all(10.0),
                // FIX: Use the state variable _achievements
                children: _achievements.map((achievement) {
                  // FIX 2: Change .id to .title (already done, kept for clarity)
                  final bool completed = widget.currentUser.completedAchievements.contains(achievement.title);
                  return _buildAchievementTile(achievement, completed);
                }).toList(),
              ),
      ),
    );
  }
}