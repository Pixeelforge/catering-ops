import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'role_views/owner/join_requests_screen.dart';
import 'core/env.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: "assets/.env");

    // Initialize Push Notifications early
    await NotificationService.setupOneSignal();
    
    // Initialize Local Cache for Offline-First behavior
    await CacheService.init();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    runApp(const MyApp());
  } catch (e, stack) {
    debugPrint('FATAL STARTUP ERROR: $e');
    debugPrint(stack.toString());
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectableText('Fatal Startup Error: $e\n\n$stack'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Catering Ops',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/join_requests': (context) => const JoinRequestsScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();
        return const DashboardScreen();
      },
    );
  }
}
