import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/copilot_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load secrets from .env
  await dotenv.load(fileName: '.env');

  // Disable Cactus telemetry (avoids Supabase 400 errors in logs)
  CactusConfig.isTelemetryEnabled = false;

  // Lock to portrait for field use
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Immersive dark status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TacitNodeApp());
}

class TacitNodeApp extends StatelessWidget {
  const TacitNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TacitNode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        colorScheme: ColorScheme.dark(
          primary: Colors.amber.shade600,
          secondary: const Color(0xFF66BB6A),
          surface: const Color(0xFF1A1A2E),
        ),
        fontFamily: 'Roboto',
      ),
      home: const CopilotScreen(),
    );
  }
}
