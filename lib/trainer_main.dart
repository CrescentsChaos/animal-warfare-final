import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import 'package:animal_warfare/training_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/services/feature_db_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop platforms so SQLite works natively without
  // needing Android/iOS implementations.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Explicitly point to the source code DB so training modifies the asset directly
    // This way, compiling the APK later includes the pretrained DB!
    final absoluteDbPath = p.join(Directory.current.path, 'assets', 'ml', 'sprite_features.db');
    FeatureDbService().setCustomDbPath(absoluteDbPath);
  }

  runApp(const TrainerApp());
}

class TrainerApp extends StatelessWidget {
  const TrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(400, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          title: 'Animal Warfare - Trainer',
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: child,
        );
      },
      child: const TrainingScreen(),
    );
  }
}
