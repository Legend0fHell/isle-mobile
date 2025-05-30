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
          scaffoldBackgroundColor: Colors.white,
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
        ),
        // Force light mode regardless of system settings
        themeMode: ThemeMode.light,
        // No dark theme provided, but can set one if needed in future
        darkTheme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
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
  int _unreadNotificationCount = 0;

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

    // Load unread notification count when component initializes
    _loadUnreadNotificationCount();
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

      // Reload notification count when auth state changes
      if (isLoggedIn) {
        _loadUnreadNotificationCount();
      } else {
        setState(() {
          _unreadNotificationCount = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadNotificationCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      setState(() {
        _unreadNotificationCount = 0;
      });
      return;
    }

    try {
      final count = await _calculateUnreadNotifications();
      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (e) {
      print('Error loading unread notification count: $e');
      setState(() {
        _unreadNotificationCount = 0;
      });
    }
  }

  Future<int> _calculateUnreadNotifications() async {
    try {
      // Get practiced dates (for daily goal notifications)
      final practicedDates = await _getDailyGoalReachedDates();
      final createdDate = await _getCreatedDate();

      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      int unreadCount = 0;

      // Count unread daily goal notifications (only today's are unread)
      for (DateTime practiceDate in practicedDates) {
        bool isSameDate = practiceDate.year == today.year &&
            practiceDate.month == today.month &&
            practiceDate.day == today.day;
        if (isSameDate) {
          unreadCount++;
        }
      }

      // Count unread practice reminders (only today's is unread)
      DateTime startDate = DateTime(createdDate.year, createdDate.month, createdDate.day);
      int daysSinceCreation = today.difference(startDate).inDays;

      // Only today's practice reminder is unread
      if (daysSinceCreation >= 0) {
        unreadCount++;
      }

      return unreadCount;
    } catch (e) {
      print('Error calculating unread notifications: $e');
      return 0;
    }
  }

  Future<Set<DateTime>> _getDailyGoalReachedDates() async {
    try {
      final progressCollection = await MongoDBService.getProgressCurrentUser(context);
      Map<DateTime, int> dateCount = {};

      for (var entry in progressCollection) {
        DateTime fullDate = entry['finished_at'];
        DateTime justDate = DateTime(fullDate.year, fullDate.month, fullDate.day);

        dateCount.update(justDate, (count) => count + 1, ifAbsent: () => 1);
      }

      Set<DateTime> frequentDates = dateCount.entries
          .where((entry) => entry.value >= 3)
          .map((entry) => entry.key)
          .toSet();

      return frequentDates;
    } catch (e) {
      print('Error getting daily goal reached dates: $e');
      return {};
    }
  }

  Future<DateTime> _getCreatedDate() async {
    try {
      final userProfile = await MongoDBService.getUserProfile(context);
      return DateTime.parse(userProfile?["created_at"]);
    } catch (e) {
      print('Error getting created date: $e');
      return DateTime.now();
    }
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
      // When navigating to notifications, refresh the count
        Navigator.of(context).pushNamed('/notifications').then((_) {
          // Reload count when returning from notifications screen
          _loadUnreadNotificationCount();
        });
        break;
      case 2:
        Navigator.of(context).pushNamed('/progress');
        break;
      case 3:
        Navigator.of(context).pushNamed('/user');
        break;
    }
  }

  Widget _buildNotificationIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(
                minWidth: 12,
                minHeight: 12,
              ),
              child: Text(
                _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final isLoggedIn = authProvider.isAuthenticated; // authProvider.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Detect', style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Learn', style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
          ],
          indicatorColor: Colors.green,
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
      backgroundColor: Colors.white,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'About'),
        BottomNavigationBarItem(
          icon: _buildNotificationIcon(),
          label: 'Notifications',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Progress'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Widget _buildLoggedOutFooter() {
    return BottomNavigationBar(
      currentIndex: _currentFooterIndex,
      onTap: _handleFooterNavigation,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.green,
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