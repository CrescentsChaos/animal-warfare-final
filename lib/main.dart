// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:animal_warfare/splash_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/models/ability.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();
  TimeService().start();

  // 2. CONFIGURE GLOBAL AUDIO CONTEXT (Retained)
  final audioContext = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      audioMode: AndroidAudioMode.normal,
    ),
  );
  AudioPlayer.global.setAudioContext(audioContext);
  await AudioService.instance.init();

  // Load Talismans from JSON
  await Talisman.loadFromJson();
  // Load Moves from JSON
  await Move.loadFromJson();
  // Load Abilities from JSON
  await Ability.loadFromJson();

  // 3. Initialize Firebase (Retained from your file)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  // 4. Wrap the application with the UserState Provider
  runApp(
    ChangeNotifierProvider(
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
      AudioService.instance.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.instance.resumeAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(
        400,
        800,
      ), // Reference bounds based on previous logic and modern devices.
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          title: 'Animal Warfare',
          theme: appTheme,
          home: child,
        );
      },
      child: const SplashScreen(),
    );
  }
}
