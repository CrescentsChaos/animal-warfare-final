import 'package:flutter/material.dart';
import 'package:animal_warfare/screens/start_screen.dart'; // 1. Import your StartScreen

void main() {
  // Ensure Flutter engine bindings are initialized before runApp, 
  // important for potential asset or device interactions later.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnimalWarfareApp());
}

class AnimalWarfareApp extends StatelessWidget {
  const AnimalWarfareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 2. Set the App Display Name
      title: 'Animal Warfare',
      
      // 3. Define the Global Retro Theme
      theme: ThemeData(
        // Set 'PressStart2P' as the default font across the app
        fontFamily: 'PressStart2P',
        // Optional: Define a dark retro color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.dark,
          primary: Colors.yellowAccent,
          secondary: Colors.redAccent,
        ),
        // Ensure the global use of Material 3 design
        useMaterial3: true,
      ),
      
      // 4. Set the StartScreen as the initial screen
      home: const StartScreen(),
      
      // Optional: Turn off the debug banner for a cleaner look
      debugShowCheckedModeBanner: false,
    );
  }
}