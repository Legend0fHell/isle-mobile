// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/mongodb_service.dart';
import 'providers/auth_provider.dart';
import 'screens/about.dart';
import 'screens/detect.dart';
import 'screens/learn.dart';
import 'screens/notifications.dart';
import 'screens/profile_screen.dart';
import 'screens/progress.dart';
import 'screens/login.dart'; // Add this import for the login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  // Initialize MongoDB connection
  try {
    await MongoDBService.initialize();
    print('MongoDB connection initialized');
  } catch (e) {
    print('Failed to initialize MongoDB: $e');
    // You might want to show an error dialog or retry logic here
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
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
          '/user': (context) => const ProfileScreen(),
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

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentFooterIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    // Update URL when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          Navigator.of(context).pushReplacementNamed('/detect');
        } else {
          Navigator.of(context).pushReplacementNamed('/learn');
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleFooterNavigation(int index) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = false; // authProvider.isLoggedIn;

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
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = false; // authProvider.isLoggedIn;

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
        children: const [
          DetectScreen(),
          LearnScreen(),
        ],
      ),
      bottomNavigationBar: isLoggedIn
          ? _buildLoggedInFooter()
          : _buildLoggedOutFooter(),
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
        BottomNavigationBarItem(
          icon: Icon(Icons.info_outline),
          label: 'About',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
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
        BottomNavigationBarItem(
          icon: Icon(Icons.info_outline),
          label: 'About',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.login),
          label: 'Login to learn',
        ),
      ],
    );
  }
}