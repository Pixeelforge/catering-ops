import 'package:flutter/material.dart';
import '../../role_views/owner/owner_view.dart';
import '../../role_views/staff/staff_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  String? _role;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserRole();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    } else if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    }
  }

  Future<void> _setOnlineStatus(bool online) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_online': online})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Error updating online status: $e');
      }
    }
  }

  Future<void> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) {
        throw Exception('Profile not found. Please create a new account.');
      }

      if (mounted) {
        setState(() {
          _role = res['role'] as String;
          _loading = false;
        });

        // 🔹 Update online status to true whenever dashboard is initialized
        _setOnlineStatus(true);
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_role == 'owner') {
      return const OwnerView();
    } else if (_role == 'staff') {
      return const StaffView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage ?? 'Unknown role or no access.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
                _fetchUserRole();
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () async {
                await _setOnlineStatus(false);
                await Supabase.instance.client.auth.signOut();
                if (context.mounted)
                  Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
