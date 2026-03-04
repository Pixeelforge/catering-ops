import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffView extends StatefulWidget {
  const StaffView({super.key});

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  String? _companyId;
  String? _staffName;

  final _companyCodeCtrl = TextEditingController();
  bool _submittingCode = false;

  @override
  void initState() {
    super.initState();
    _fetchStaffProfile();
  }

  @override
  void dispose() {
    _companyCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStaffProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await supabase
          .from('profiles')
          .select('full_name, company_id')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _staffName = res['full_name'];
          _companyId = res['company_id'];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinCompany() async {
    final code = _companyCodeCtrl.text.trim();
    if (code.isEmpty) {
      _showToast('Please enter a valid Company ID', Colors.redAccent);
      return;
    }

    setState(() => _submittingCode = true);

    try {
      // First verify if company exists
      final companyRes = await supabase
          .from('companies')
          .select('id')
          .eq('id', code)
          .maybeSingle();

      if (companyRes == null) {
        _showToast(
          'Invalid Company ID. Please check and try again.',
          Colors.redAccent,
        );
        setState(() => _submittingCode = false);
        return;
      }

      // Update staff profile
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase
            .from('profiles')
            .update({'company_id': code})
            .eq('id', user.id);

        _showToast('Successfully joined the company!', Colors.green);
        _fetchStaffProfile(); // Refresh screen
      }
    } catch (e) {
      debugPrint('Error joining company: $e');
      _showToast(
        'Something went wrong. The ID might be invalid.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _submittingCode = false);
    }
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _logout() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase
            .from('profiles')
            .update({'is_online': false})
            .eq('id', user.id);
      } catch (_) {}
    }
    await supabase.auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }

    if (_companyId == null || _companyId!.isEmpty) {
      return _buildJoinCompanyScreen();
    }

    return _buildMainDashboard();
  }

  Widget _buildJoinCompanyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_center,
                  size: 60,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Join Your Team',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the Company ID provided by your owner to access the dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _companyCodeCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'Company ID',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  prefixIcon: const Icon(
                    Icons.vpn_key_outlined,
                    color: Colors.orangeAccent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.orangeAccent),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _submittingCode ? null : _joinCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submittingCode
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'JOIN COMPANY',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainDashboard() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Staff Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello,',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            Text(
              _staffName ?? 'Colleague',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            // Connected Company Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connected to Company',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'ID: ••••••••${_companyId != null && _companyId!.length > 4 ? _companyId!.substring(_companyId!.length - 4) : ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Future Assignments Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      color: Colors.orangeAccent.withOpacity(0.2),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your upcoming events and assigned orders will appear here soon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
