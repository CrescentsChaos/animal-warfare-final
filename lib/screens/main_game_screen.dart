import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:animal_warfare/screens/profile_screen.dart'; 

class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key}); 

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // State variable to track user status
  bool isLoggedIn = false; 

  // 🚀 NEW: Check for an active user session when the screen starts
  @override
  void initState() {
    super.initState();
    // Use the authStateChanges stream to check the current user status
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // User is signed in
        setState(() {
          isLoggedIn = true;
        });
        print("Existing user found: ${user.displayName}");
      } else {
        // User is signed out
        setState(() {
          isLoggedIn = false;
        });
        print("No active user session.");
      }
    });
  }
  
  void _onPlayTapped() {
    // A new game is usually available regardless of login
    print("Play Tapped: Starting new game.");
  }

  void _onContinueTapped() {
    // Only allow continuing if logged in
    if (isLoggedIn) {
      // TODO: Implement logic to load a SAVED game session
      print("Continue Tapped: Loading saved game.");
    } else {
      print("Continue Blocked: Must log in first.");
      // Optional: Show a message to the user
      _showSnackbar("Please log in to continue a saved game.");
    }
  }

  void _onProfileTapped() {
    // Only allow profile access if logged in
    if (isLoggedIn) {
      final user = _auth.currentUser;
      
      if (user != null) {
      // This part is correct: it navigates and passes the user object.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ProfileScreen(user: user),
        ),
      );
    } else {
        // Fallback case
        print("Profile Blocked: isLoggedIn is true, but currentUser is null.");
        _showSnackbar("Could not load profile. Please try logging in again.");
        setState(() {
          isLoggedIn = false;
        });
      }
    } else {
      print("Profile Blocked: Must log in first.");
      _showSnackbar("Please log in to view your profile.");
    }
  }

  void _onLoginLogoutTapped() async {
      if (isLoggedIn) {
        // ➡️ LOGOUT Logic
        await _auth.signOut();
        await _googleSignIn.signOut();
        // The authStateChanges listener will handle the setState
        _showSnackbar("Logged out successfully.");
        print("Logged Out");
      } else {
        // ➡️ LOGIN Logic
        User? user = await _signInWithGoogle();
        // NOTE: The condition has been corrected from (user != true) to (user != null)
        if (user != null) {
          // The authStateChanges listener will handle the setState
          _showSnackbar("Logged in as ${user.displayName}.");
          print("Logged in as ${user.displayName}");
        } else {
          _showSnackbar("Google Sign-In failed or was cancelled.");
          print("Google Sign-In failed.");
        }
      }
    }
    // Method to handle the Google Sign-In flow
  Future<User?> _signInWithGoogle() async {
    try {
      // 1. Trigger the Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null; 
      }

      // 2. Get the authentication details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Return the authenticated user
      return userCredential.user;
    } catch (e) {
      print("Error during Google Sign-In: $e");
      return null;
    }
  }
  
  // Helper to show messages to the user (snackbars are non-retro, but functional)
  void _showSnackbar(String message) {
    // Check if the widget is mounted before showing a snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  // NOTE: You should also dispose of any streams you listen to, 
  // but for the simple FirebaseAuth stream, it's often managed internally 
  // or the overhead is negligible for a single screen.

  @override
  Widget build(BuildContext context) {
    // Determine button labels and states based on login status
    final loginButtonText = isLoggedIn ? 'LOGOUT' : 'LOGIN';
    
    // Continue and Profile buttons should only be interactable when logged in
    final isSecondaryButtonsEnabled = isLoggedIn; 

    return Scaffold(
      appBar: AppBar(
        title: const Text( 
          'ANIMAL WARFARE',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18.0,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // --- Menu Buttons ---
            _buildMenuButton('PLAY', _onPlayTapped, isEnabled: true),
            const SizedBox(height: 20),
            
            // ⭐️ Dynamic: Disabled if not logged in
            _buildMenuButton('CONTINUE', _onContinueTapped, isEnabled: isSecondaryButtonsEnabled),
            const SizedBox(height: 20),

            // ⭐️ Dynamic: Disabled if not logged in
            _buildMenuButton('PROFILE', _onProfileTapped, isEnabled: isSecondaryButtonsEnabled),
            const SizedBox(height: 60),

            // --- Login/Logout Option ---
            // ⭐️ Dynamic: Toggles function and text
            _buildMenuButton(loginButtonText, _onLoginLogoutTapped, isPrimary: false, isEnabled: true),
          ],
        ),
      ),
    );
  }

  // Helper method to include 'isEnabled' logic
  Widget _buildMenuButton(String text, VoidCallback onPressed, {bool isPrimary = true, required bool isEnabled}) {
    // Use onPressed: null to disable the button, which greys it out automatically
    final effectiveOnPressed = isEnabled ? onPressed : null;

    return SizedBox(
      width: 200,
      height: 40,
      child: ElevatedButton(
        onPressed: effectiveOnPressed, // Pass null if disabled
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled 
              ? (isPrimary ? Colors.yellowAccent : Colors.blueGrey[800])
              : Colors.grey[700], // Grey color when disabled
          foregroundColor: Colors.black,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: BorderSide(
              color: isEnabled ? (isPrimary ? Colors.redAccent : Colors.grey) : Colors.black, 
              width: 3.0
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: isPrimary ? 16.0 : 12.0,
            color: isEnabled ? (isPrimary ? Colors.black : Colors.white70) : Colors.white38, // Faded text when disabled
          ),
        ),
      ),
    );
  }
}