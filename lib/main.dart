import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/text_input_service.dart';
import 'utils/logger.dart';
import 'services/hand_landmark_service.dart';
import 'services/mongodb_service.dart';
import 'services/config_service.dart';
import 'providers/auth_provider.dart';
import 'screens/about_screen.dart';
import 'screens/detection_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/login_screen.dart'; // Add this import for the login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  
  // Initialize configuration service (handles env variables)
  final configService = ConfigService();
  await configService.initialize();
  AppLogger.info('Configuration initialized');
  
  // Initialize MongoDB connection
  try {
    await MongoDBService.initialize();
  } catch (e) {
    AppLogger.info('Failed to initialize MongoDB: $e');
    // You might want to show an error dialog or retry logic here
  }

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
        Provider.value(value: configService),
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
    AppLogger.info(
      'Warning: Make sure to correctly set up the assets in pubspec.yaml',
    );
    AppLogger.info('Error loading assets: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => AuthProvider())],
      child: MaterialApp(
        title: 'Sign Language Learning App',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
        ),
        initialRoute: '/detect',
        routes: {
          '/detect': (context) => const MainLayout(initialIndex: 0),
          '/learn': (context) => const MainLayout(initialIndex: 1),
          '/notifications': (context) => const NotificationsScreen(),
          '/about': (context) => const AboutScreen(),
          '/progress': (context) => const ProgressScreen(),
          '/user': (context) => const UserProfileScreen(),
          '/login': (context) => const LoginScreen(), // Add route for login screen
        },
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, required this.initialIndex});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentFooterIndex = 0;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    // removed listener because it was not necessary, caused unnecessary
    // rebuilds, refreshes of the screens
    _tabController.addListener(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isLoggedIn =
        Provider.of<AuthProvider>(context, listen: true).isAuthenticated;

    // If login state changed, reset index if needed
    if (_wasLoggedIn != isLoggedIn) {
      setState(() {
        _currentFooterIndex = 0;
        _wasLoggedIn = isLoggedIn;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleFooterNavigation(int index) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // listening the auth provider to check if the user is logged in
    final isLoggedIn = authProvider.isAuthenticated;

    // If not logged in, only handle the first item (About) or the login button
    if (!isLoggedIn) {
      if (index == 0) {
        Navigator.of(context).pushNamed('/about');
      } else if (index == 1) {
        Navigator.of(context).pushNamed('/login');
      }
      return;
    }

    setState(() {
      _currentFooterIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.of(context).pushNamed('/about');
        break;
      case 1:
        Navigator.of(context).pushNamed('/notifications');
        break;
      case 2:
        Navigator.of(context).pushNamed('/progress');
        break;
      case 3:
        Navigator.of(context).pushNamed('/user');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final isLoggedIn = authProvider.isAuthenticated; // authProvider.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Detect', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Learn', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
          indicatorColor: Colors.white,
          dividerColor: Colors.transparent,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [DetectionScreen(), LearnScreen()],
      ),
      bottomNavigationBar:
          isLoggedIn ? _buildLoggedInFooter() : _buildLoggedOutFooter(),
    );
  }

  Widget _buildLoggedInFooter() {
    return BottomNavigationBar(
      currentIndex: _currentFooterIndex,
      onTap: _handleFooterNavigation,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.black,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'About'),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Progress'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Widget _buildLoggedOutFooter() {
    return BottomNavigationBar(
      currentIndex: _currentFooterIndex,
      onTap: _handleFooterNavigation,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.black,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'About'),
        BottomNavigationBarItem(
          icon: Icon(Icons.login),
          label: 'Login to learn',
        ),
      ],
    );
  }
}
