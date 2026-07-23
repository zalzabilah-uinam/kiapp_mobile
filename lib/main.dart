import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/download_provider.dart';
import 'providers/history_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/app_update_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().init();
  runApp(const SosmedDownloaderApp());
}

class SosmedDownloaderApp extends StatelessWidget {
  const SosmedDownloaderApp({super.key});

  /// Konfigurasi upgrader — GitHub Releases.
  static final _upgradeAlert = _initUpgradeAlert();

  static Widget _initUpgradeAlert() {
    AppUpdateService().createUpgrader(
      owner: 'zalzabilah-uinam',
      repo: 'kiapp_mobile',
    );
    return AppUpdateService().buildUpgradeAlert(
      child: const AuthGate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final authService = AuthService(apiClient);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient, authService)),
        ChangeNotifierProvider(create: (_) => DownloadProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => HistoryProvider(apiClient)),
      ],
      child: MaterialApp(
        title: 'Sosmed Downloader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: _upgradeAlert,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _buildBody(auth),
    );
  }

  Widget _buildBody(AuthProvider auth) {
    switch (auth.status) {
      case AuthStatus.uninitialized:
        return const Scaffold(
          key: ValueKey('splash'),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryLight),
                SizedBox(height: 16),
                Text('Memuat...', style: TextStyle(color: Color(0xFF8888A0))),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        return const MainShell(key: ValueKey('main'));
      case AuthStatus.unauthenticated:
      case AuthStatus.loading:
        return const LoginScreen(key: ValueKey('login'));
    }
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _pageIndex = 0;

  final _pages = const [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  void switchTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _pageIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _pageIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _pageIndex,
        onTap: (i) => setState(() => _pageIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

