import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../../dashboard/dashboard_screen.dart';
import 'signup_screen.dart'; // ✅ Added

/// 🔹 Main Login Widget
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// 🔹 State Class
class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    // ✅ Validation
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      setState(() {
        _error = "Email and password cannot be empty";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.signIn(
        _email.text.trim(),
        _password.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login successful")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );

    } on AuthException catch (e) {
      setState(() {
        _error = e.message.contains("Invalid login credentials")
            ? "Incorrect email or password"
            : e.message;
      });

    } catch (_) {
      setState(() {
        _error = "Something went wrong. Please try again.";
      });

    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),

            const SizedBox(height: 20),

            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Login"),
            ),

            const SizedBox(height: 10),

            /// ✅ NEW: Sign Up navigation
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignUpScreen(),
                  ),
                );
              },
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
