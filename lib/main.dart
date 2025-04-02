import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/welcome_screen.dart';
import 'services/text_input_service.dart';
import 'utils/logger.dart';
import 'services/hand_landmark_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Ensure the assets path is properly set for MediaPipe
  await loadAssets();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TextInputService()),
        ChangeNotifierProvider.value(value: handLandmarkService),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> loadAssets() async {
  // This is a placeholder to ensure assets are loaded correctly
  // The actual model files will be provided separately
  try {
    await rootBundle.loadString('assets/models/README.md');
    AppLogger.info('Assets confirmed to be properly configured.');
  } catch (e) {
    AppLogger.info('Warning: Make sure to correctly set up the assets in pubspec.yaml');
    AppLogger.info('Error loading assets: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISLE - Interactive Sign Language Engagement',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}
