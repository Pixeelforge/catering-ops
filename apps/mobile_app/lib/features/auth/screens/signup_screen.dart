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
  final _companyNameCtrl = TextEditingController();

  bool _loading = false;
  String _role = 'staff'; // 'owner' or 'staff'

  // Validation errors
  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _companyError;

  bool _validate() {
    bool isValid = true;
    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final companyName = _companyNameCtrl.text.trim();

    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
      _passwordError = null;
      _companyError = null;
    });

    if (fullName.length < 3) {
      setState(() => _nameError = 'Name must be at least 3 characters');
      isValid = false;
    }

    final phoneRegExp = RegExp(r'^\d+$');
    if (phone.length < 10 || !phoneRegExp.hasMatch(phone)) {
      setState(() => _phoneError = 'Enter a valid 10-digit phone number');
      isValid = false;
    }

    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isNotEmpty && !emailRegExp.hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      isValid = false;
    }

    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      isValid = false;
    }

    if (_role == 'owner' && companyName.isEmpty) {
      setState(() => _companyError = 'Company name is required for owners');
      isValid = false;
    }

    return isValid;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _companyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final companyName = _companyNameCtrl.text.trim();

    if (!_validate()) return;

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      // Check if phone number is already registered
      try {
        final bool phoneExists = await supabase.rpc('check_phone_exists', params: {'p_phone': phone});
        if (phoneExists) {
          setState(() {
            _phoneError = 'This phone number is already registered';
            _loading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Phone check failed (DB migration might be missing): $e');
        setState(() => _loading = false);
        _toast('Database error! Did you run 22_check_phone_exists.sql?');
        return;
      }

      final signupEmail = email.isEmpty ? '$phone@catering.app' : email;

      final res = await supabase.auth.signUp(
        email: signupEmail,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': _role,
          if (_role == 'owner') 'company_name': companyName,
        },
      );

      if (res.user == null) {
        _toast('Signup failed. Please try again.');
        return;
      }

      try {
        // 1. Mark as online
        await supabase
            .from('profiles')
            .update({'is_online': true})
            .eq('id', res.user!.id);
            
        // 2. Check for pre-approved invitations if joining as staff (or generally)
        final invite = await supabase
            .from('company_invitations')
            .select('*')
            .eq('phone', phone)
            .maybeSingle();
            
        if (invite != null) {
          // 1. Auto-join the company
          await supabase
              .from('profiles')
              .update({'company_id': invite['company_id']})
              .eq('id', res.user!.id);
              
          // 2. Auto-link any orders assigned to this invitation
          await supabase
              .from('orders')
              .update({
                'delivery_staff_id': res.user!.id,
                'pending_delivery_staff_id': null,
              })
              .eq('pending_delivery_staff_id', invite['id']);
              
          // 3. Remove the invitation now that it's processed
          await supabase
              .from('company_invitations')
              .delete()
              .eq('id', invite['id']);
              
          _toast('Account created! You were automatically added to your team.');
          if (mounted) Navigator.pop(context);
          return; // Skip the generic welcome toast
        }
      } catch (e) {
        debugPrint('Post signup profile update error: $e');
      }

      _toast('Account created! Welcome to the team.');

      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.indigoAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join our catering management network',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _fullNameCtrl,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        errorText: _nameError,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        errorText: _phoneError,
                      ),
                      const SizedBox(height: 24),

                      if (_role == 'owner') ...[
                        _buildTextField(
                          controller: _companyNameCtrl,
                          label: 'Company Name',
                          icon: Icons.business_outlined,
                          errorText: _companyError,
                        ),
                        const SizedBox(height: 24),
                      ],

                      const Text(
                        'Select Your Role',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              title: 'Staff Member',
                              isSelected: _role == 'staff',
                              onTap: () => setState(() => _role = 'staff'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              title: 'Business Owner',
                              isSelected: _role == 'owner',
                              onTap: () => setState(() => _role = 'owner'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _emailCtrl,
                        label: 'Email Address (Optional)',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        errorText: _passwordError,
                      ),
                      const SizedBox(height: 32),
                      _buildSignUpButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.redAccent),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.orangeAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _loading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orangeAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: Colors.orangeAccent.withOpacity(0.4),
        ),
        child: _loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'CREATE ACCOUNT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orangeAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orangeAccent : Colors.white12,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.orangeAccent : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
