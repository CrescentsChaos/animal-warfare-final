// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:animal_warfare/splash_screen.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:provider/provider.dart'; // 🚨 NEW: Import Provider
import 'package:animal_warfare/user_state.dart'; // 🚨 NEW: Import UserState (Assumed to exist/created in previous steps)
import 'package:animal_warfare/audio_manager.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. CONFIGURE GLOBAL AUDIO CONTEXT (Retained)
  final audioContext = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck, 
      audioMode: AndroidAudioMode.normal,
    ),
  );
  AudioPlayer.global.setAudioContext(audioContext);
  
  // 3. Initialize Firebase (Retained from your file)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }
  
  // 4. 🚨 CRITICAL FIX: Wrap the application with the UserState Provider
  runApp(
    ChangeNotifierProvider(
      // This is where the UserState is created and starts loading data/timers.
      create: (context) => UserState()..loadCurrentUser(), 
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      AudioManager.instance.handleLifecycleChange(true);
    } else if (state == AppLifecycleState.resumed) {
      AudioManager.instance.handleLifecycleChange(false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      home: const SplashScreen(), 
    );
  }
}