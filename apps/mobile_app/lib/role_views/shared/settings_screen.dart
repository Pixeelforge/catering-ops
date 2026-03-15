import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final String? companyId;
  final String? companyName;
  final String role; // 'owner' or 'staff'
  final String? fullName;

  const SettingsScreen({
    super.key,
    this.companyId,
    this.companyName,
    required this.role,
    this.fullName,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _logout() async {
    setState(() => _isLoading = true);
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

  Future<void> _leaveCompany() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161626),
        title: const Text('Leave Company', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave this company? You will need a new invite code to join again.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null || widget.companyId == null) return;

      // 1. Get Owner ID before leaving
      final companyRes = await supabase
          .from('companies')
          .select('owner_id')
          .eq('id', widget.companyId!)
          .maybeSingle();
      
      final ownerId = companyRes?['owner_id'];

      // 2. Update Profile
      await supabase
          .from('profiles')
          .update({'company_id': null})
          .eq('id', user.id);

      // 3. Send Notifications
      if (ownerId != null) {
        await supabase.from('notifications').insert({
          'owner_id': ownerId,
          'company_id': widget.companyId,
          'title': 'Staff Left 👤',
          'message': '${widget.fullName ?? 'A staff member'} has left the company.',
          'type': 'staff_left',
        });

        await NotificationService.sendNotification(
          playerIds: [ownerId],
          title: 'Staff Member Left 👤',
          message: '${widget.fullName ?? 'A staff member'} has left your team.',
          data: {'type': 'staff_left'},
          color: 'FFFF5722',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left company successfully'), backgroundColor: Colors.green),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                        child: Text(
                          (widget.fullName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fullName ?? 'User',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.role.toUpperCase(),
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Account Actions
                const Text(
                  'Account Actions',
                  style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Leave Company (Only for Staff who are in a company)
                if (widget.role == 'staff' && widget.companyId != null)
                  _buildSettingTile(
                    icon: Icons.exit_to_app,
                    title: 'Leave Company',
                    subtitle: 'Disconnect from your current team',
                    color: Colors.redAccent,
                    onTap: _leaveCompany,
                  ),

                const SizedBox(height: 12),

                // Logout
                _buildSettingTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  subtitle: 'Sign out of your account',
                  color: Colors.orangeAccent,
                  onTap: _logout,
                ),

                const SizedBox(height: 32),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                
                // Troubleshooting
                const Text(
                  'Troubleshooting',
                  style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSettingTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Test Notification',
                  subtitle: 'Check if push notifications reach this device',
                  color: Colors.blueAccent,
                  onTap: () async {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user == null) return;
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Triggering test...'), duration: Duration(seconds: 1)),
                    );
                    
                    final result = await NotificationService.sendToSelf(user.id);
                    if (result == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Test triggered successfully!'), backgroundColor: Colors.green),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ Error: $result'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                ),

                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Catering Ops v1.0.0',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
