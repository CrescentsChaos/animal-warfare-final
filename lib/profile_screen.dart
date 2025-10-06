import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/edit_profile_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
// REMOVED: import 'package:intl/intl.dart'; // FIX: This caused the dependency error

// ------------------------------------------------------------------
// FIX: Define the missing _createFadeRoute function here.
// ------------------------------------------------------------------
PageRouteBuilder _createFadeRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}
// ------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final LocalAuthService _authService = LocalAuthService();

  UserData? _currentUser;
  bool _isLoading = true;

  late AudioPlayer _audioPlayer; 
  bool _wasPlayingBeforePause = false; 

  // Custom retro/military colors
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _playBackgroundMusic();
    _loadUserProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause = _audioPlayer.state == PlayerState.playing;
      await _audioPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        await _audioPlayer.resume();
      }
    }
  }

  Future<void> _playBackgroundMusic() async {
    // Assuming audio file is at assets/audio/main_theme.mp3
    await _audioPlayer.setSourceAsset('audio/main_theme.mp3'); 
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    await _audioPlayer.resume();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  void _navigateToEditScreen() {
    _audioPlayer.pause();
    
    // NOTE: If EditProfileScreen requires 'initialUser' and 'onProfileUpdated', 
    // you must define those parameters in EditProfileScreen. 
    // For now, removing them to fix the "undefined named parameter" errors.
    Navigator.of(context).push(_createFadeRoute(
      const EditProfileScreen(), 
    )).then((_) {
      _audioPlayer.resume(); 
      _loadUserProfile(); // Reload profile data upon return
    });
  }
  
  // FIX: Manual date formatter to replace DateFormat from intl package
  String _formatLastPlayedDate(DateTime dateTime) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$month $day, $hour:$minute $ampm';
  }


  Widget _buildProfileDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: highlightColor,
              fontSize: 10,
              fontFamily: 'PressStart2P',
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.brown.shade700.withOpacity(0.5),
              border: Border.all(color: primaryButtonColor, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemedButton({required String text, required VoidCallback onPressed}) {
    // ... (button styling implementation remains the same)
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: primaryButtonColor,
        border: Border.all(color: highlightColor, width: 2.0),
        borderRadius: BorderRadius.circular(4.0), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Widget to display individual quiz stat blocks
  Widget _buildQuizStatBlock(String quizName, Map<String, dynamic> stats) {
    final attempts = stats['attempts'] as int? ?? 0;
    final correct = stats['correct'] as int? ?? 0;
    final lastAttempt = stats['lastAttempt'] as String?;
    
    final accuracy = attempts > 0 ? (correct / attempts * 100).toStringAsFixed(1) : 'N/A';
    String lastPlayed = 'Never';
    if (lastAttempt != null) {
      try {
        final dateTime = DateTime.parse(lastAttempt);
        // FIX: Use the internal formatter
        lastPlayed = _formatLastPlayedDate(dateTime); 
      } catch (_) {
        lastPlayed = 'Unknown Date';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border.all(color: highlightColor, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quizName.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFDAA520), // Highlight color
              fontSize: 14,
              fontFamily: 'PressStart2P',
            ),
          ),
          const Divider(color: Color(0xFF1E3F2A), thickness: 1, height: 16),
          _buildStatRow('Attempts', attempts.toString()),
          _buildStatRow('Correct', correct.toString()),
          _buildStatRow('Accuracy', '$accuracy%'),
          _buildStatRow('Last Play', lastPlayed, smallFont: true),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, {bool smallFont = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontFamily: 'PressStart2P',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlightColor,
              fontSize: smallFont ? 10 : 14,
              fontFamily: 'PressStart2P',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile'), backgroundColor: Colors.green[900]),
        body: const Center(child: CircularProgressIndicator(color: highlightColor)),
      );
    }

    final user = _currentUser!;
    final avatarImage = user.avatar == 'default'
        ? null
        : FileImage(File(user.avatar)) as ImageProvider?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.green[900],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/main.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken), 
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 1. AVATAR (Display Only)
              CircleAvatar(
                radius: 80,
                backgroundColor: highlightColor.withOpacity(0.2),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? const Icon(Icons.person, size: 50, color: highlightColor)
                    : null,
              ),
              const SizedBox(height: 40),

              // 2. USERNAME (Read-only Detail)
              _buildProfileDetail('USERNAME', user.username),

              // 3. GENDER (Read-only Detail)
              _buildProfileDetail('GENDER', user.gender),

              const SizedBox(height: 40),

              // 4. EDIT PROFILE BUTTON
              _buildThemedButton(
                text: 'EDIT PROFILE',
                onPressed: _navigateToEditScreen,
              ),
              const SizedBox(height: 40),

              // START: QUIZ STATS SECTION
              Text(
                '--- BATTLE QUIZ STATS ---',
                style: TextStyle(color: highlightColor.withOpacity(0.8), fontSize: 10, fontFamily: 'PressStart2P'),
              ),
              const SizedBox(height: 20),
              
              // Dynamically build stat blocks for each quiz
              ...user.quizStats.entries.map((entry) {
                return _buildQuizStatBlock(entry.key, entry.value);
              }).toList(),

              // Display message if no stats are available
              if (user.quizStats.isEmpty)
                Text(
                  'No quiz data found. Go play!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              // END: QUIZ STATS SECTION
              
              const SizedBox(height: 40), 
            ],
          ),
        ),
      ),
    );
  }
}