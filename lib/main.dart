import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Required for initialization
import 'package:animal_warfare/splash_screen.dart'; 
import 'package:animal_warfare/main_screen.dart'; // (Currently unused, but good practice to keep the import)

void main() async {
  // 1. Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase asynchronously before running the app
  try {
    await Firebase.initializeApp(
        // NOTE: If you have generated a firebase_options.dart file 
        // using the FlutterFire CLI, uncomment and use it here:
        // options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // In a production app, you would log this error.
    debugPrint("Firebase Initialization Error: $e");
    // Consider adding code here to show a critical error screen to the user.
  }
  
  // 3. Run the application only after initialization is complete
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Since Firebase is initialized in main(), we don't need the FutureBuilder here.
    return MaterialApp(
      title: 'Animal Warfare',
      theme: ThemeData(
        fontFamily: 'PressStart2P',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      // App starts directly with the splash screen
      home: const SplashScreen(), 
    );
  }
}