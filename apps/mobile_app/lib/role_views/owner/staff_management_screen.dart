import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffManagementScreen extends StatefulWidget {
  final String companyId;
  const StaffManagementScreen({super.key, required this.companyId});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _staffMembers = [];
  List<Map<String, dynamic>> _pendingInvitations = [];
  bool _loading = true;
  RealtimeChannel? _profileSubscription;
  RealtimeChannel? _invitationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _profileSubscription?.unsubscribe();
    _invitationSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _profileSubscription = supabase
        .channel('public:profiles_staff')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: widget.companyId,
          ),
          callback: (payload) => _fetchStaff(),
        )
        .subscribe();

    _invitationSubscription = supabase
        .channel('public:staff_invitations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'staff_invitations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: widget.companyId,
          ),
          callback: (payload) => _fetchInvitations(),
        )
        .subscribe();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    await Future.wait([_fetchStaff(), _fetchInvitations()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchInvitations() async {
    try {
      final data = await supabase
          .from('staff_invitations')
          .select('email, full_name, phone, created_at')
          .eq('company_id', widget.companyId);

      if (mounted) {
        setState(() {
          _pendingInvitations = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching invitations: $e');
    }
  }

  Future<void> _fetchStaff() async {
    try {
      debugPrint('Fetching staff for company: ${widget.companyId}');
      final data = await supabase
          .from('profiles')
          .select('id, full_name, phone, role, is_online')
          .eq('company_id', widget.companyId)
          .eq('role', 'staff');

      if (mounted) {
        setState(() {
          _staffMembers = List<Map<String, dynamic>>.from(data);

          // 🔹 Explicit Sorting: Online first, then by name
          _staffMembers.sort((a, b) {
            bool aOnline = a['is_online'] == true;
            bool bOnline = b['is_online'] == true;
            if (aOnline && !bOnline) return -1;
            if (!aOnline && bOnline) return 1;
            return (a['full_name'] ?? '').compareTo(b['full_name'] ?? '');
          });

          _loading = false;
        });
        debugPrint('Fetched ${_staffMembers.length} staff members');
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Our Team',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showAddStaffDialog,
            icon: const Icon(
              Icons.person_add_outlined,
              size: 18,
              color: Colors.orangeAccent,
            ),
            label: const Text(
              'ADD STAFF',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : _staffMembers.isEmpty && _pendingInvitations.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_staffMembers.isNotEmpty) ...[
                  const Text(
                    'ACTIVE TEAM',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._staffMembers.map((staff) => _buildStaffTile(staff)),
                  const SizedBox(height: 32),
                ],
                if (_pendingInvitations.isNotEmpty) ...[
                  const Text(
                    'WAITING FOR SIGNUP',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._pendingInvitations.map(
                    (inv) => _buildInvitationTile(inv),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInvitationTile(Map<String, dynamic> inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.05),
            child: Text(
              (inv['full_name'] as String?)?[0].toUpperCase() ?? 'S',
              style: const TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv['full_name'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  inv['email'] ?? 'No email',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white24, size: 20),
            onPressed: () => _cancelInvitation(inv['email']),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvitation(String email) async {
    try {
      await supabase.from('staff_invitations').delete().eq('email', email);
      _fetchInvitations();
    } catch (e) {
      debugPrint('Error cancelling invitation: $e');
    }
  }

  Future<void> _showAddStaffDialog() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161626),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text(
          'Add Staff Member',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration(
                  'Full Name',
                  Icons.person_outline,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration(
                  'Phone Number',
                  Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration(
                  'Email Address',
                  Icons.mail_outline,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'When this staff member signs up with this email, they will be automatically linked with these details.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            child: const Text(
              'Add Staff',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true &&
        emailCtrl.text.isNotEmpty &&
        nameCtrl.text.isNotEmpty) {
      _addStaffMember(
        emailCtrl.text.trim().toLowerCase(),
        nameCtrl.text.trim(),
        phoneCtrl.text.trim(),
      );
    }
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.orangeAccent, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _addStaffMember(String email, String name, String phone) async {
    try {
      await supabase.from('staff_invitations').insert({
        'email': email,
        'company_id': widget.companyId,
        'full_name': name,
        'phone': phone,
      });
      _fetchInvitations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $name to waiting list'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: Colors.white.withOpacity(0.2),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No staff members found.',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your Company ID to invite them!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orangeAccent.withOpacity(0.1),
            child: Text(
              (staff['full_name'] as String?)?[0].toUpperCase() ?? 'S',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff['full_name'] ?? 'Unknown Member',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  staff['phone'] ?? 'No phone added',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (staff['is_online'] == true)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (staff['is_online'] == true) ? 'Active' : 'Offline',
                  style: TextStyle(
                    color: (staff['is_online'] == true)
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _promptRemoveStaff(staff),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptRemoveStaff(Map<String, dynamic> staff) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: const Text(
            'Remove Staff',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to remove ${staff['full_name']} from your company?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _removeStaff(staff['id'], staff['full_name']);
    }
  }

  Future<void> _removeStaff(String staffId, String? staffName) async {
    try {
      if (staffId.isEmpty) return;

      // Update the profile to remove the company_id and reset the role if necessary
      await supabase
          .from('profiles')
          .update({'company_id': null})
          .eq('id', staffId);

      if (mounted) {
        setState(() {
          _staffMembers.removeWhere((s) => s['id'] == staffId);
        });
        // We still call fetch to ensure total sync after local UI update
        _fetchStaff();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${staffName ?? 'staff'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing staff: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
