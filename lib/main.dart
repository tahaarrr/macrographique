import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/home_screen.dart';
import 'services/pdf_service_modern.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation SQLite FFI pour Windows Desktop, macOS & Linux
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Pré-chargement des polices PDF en arrière-plan (évite la latence au 1er rapport)
  PdfServiceModern.preloadFonts();

  runApp(const RapportEssaiApp());
}

class RapportEssaiApp extends StatelessWidget {
  const RapportEssaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Macrographique',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) => AppShell(child: child!),
      home: const HomeScreen(),
    );
  }
}
