// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:animal_warfare/models/recipe.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/game/biome_map_data.dart';
import 'package:animal_warfare/game/npc_team_loader.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();
  TimeService().start();

  // Lock orientation to portrait — the game is designed portrait-first.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set global status bar / nav bar style: transparent with light icons.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117), // AppColors.background
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

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
  // Load Recipes from JSON
  await Recipe.loadFromJson();
  // Load Biome/Tile/NPC data
  await BiomeDataManager.loadData();
  // Load NPC trainer teams
  await NpcTeamLoader.loadData();

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
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          scrollBehavior: AppScrollBehavior(),
          home: child,
        );
      },
      child: const SplashScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom scroll behavior — bouncy physics on all platforms (feels premium)
// ---------------------------------------------------------------------------
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
