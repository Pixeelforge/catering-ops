import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String _role = 'staff'; // 'owner' or 'staff'

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _toast('Email and password are required.');
      return;
    }

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1) Create auth user (Supabase Auth stores email/password securely)
      // 2) Extra fields go into raw_user_meta_data
      // 3) Your DB trigger should auto-create row in public.profiles
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': _role, // must be exactly 'owner' or 'staff'
        },
      );

      if (res.user == null) {
        _toast('Signup failed. Please try again.');
        return;
      }

      // IMPORTANT:
      // Do NOT insert/upsert into profiles here.
      // If email confirmation is enabled, there is no session yet,
      // and RLS will block the insert => "Database error saving new user".
      _toast('Account created! Now login (or verify email if required).');

      if (mounted) Navigator.pop(context); // back to login screen
    } on AuthException catch (e) {
      // Show the real auth error message
      _toast('Signup error: ${e.message}');
    } catch (e) {
      _toast('Signup error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _fullNameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'staff',
                    groupValue: _role,
                    onChanged:
                        _loading ? null : (v) => setState(() => _role = v!),
                    title: const Text('Staff'),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'owner',
                    groupValue: _role,
                    onChanged:
                        _loading ? null : (v) => setState(() => _role = v!),
                    title: const Text('Owner'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loading ? null : _signUp,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
