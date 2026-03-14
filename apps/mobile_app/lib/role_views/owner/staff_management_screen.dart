import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

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
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
    _setupRealtime();
  }

  void _setupRealtime() {
    _subscription = supabase
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: widget.companyId,
          ),
          callback: (payload) {
            _fetchStaff();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchStaff() async {
    try {
      debugPrint('Fetching staff for company: ${widget.companyId}');
      final data = await supabase
          .from('profiles')
          .select('id, full_name, phone, role, is_online')
          .eq('company_id', widget.companyId)
          .eq('role', 'staff');

      // Fetch pending invitations
      final invitesData = await supabase
          .from('company_invitations')
          .select('id, full_name, phone, created_at')
          .eq('company_id', widget.companyId);

      if (mounted) {
        setState(() {
          _staffMembers = List<Map<String, dynamic>>.from(data);
          _pendingInvitations = List<Map<String, dynamic>>.from(invitesData);

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
        debugPrint('Fetched ${_staffMembers.length} staff members and ${_pendingInvitations.length} pending invitations');
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelInvitation(String inviteId, String name) async {
    try {
      await Supabase.instance.client
          .from('company_invitations')
          .delete()
          .eq('id', inviteId);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation for $name cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _fetchStaff();
    } catch (e) {
      debugPrint('Error cancelling invitation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Our Team',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : (_staffMembers.isEmpty && _pendingInvitations.isEmpty)
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_staffMembers.isNotEmpty) ...[
                  const Text(
                    'Active Staff',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._staffMembers.map((staff) => _buildStaffTile(staff)),
                ],
                if (_pendingInvitations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Pending Invitations',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._pendingInvitations.map((invite) => _buildInviteTile(invite)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.person_add, color: Colors.black),
        label: const Text(
          'Add Staff',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _showAddStaffDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isProcessing = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              title: const Text(
                'Add Staff Member',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final contact = await _pickFromContacts();
                              if (contact != null) {
                                setDialogState(() {
                                  nameController.text = contact.displayName;
                                  if (contact.phones.isNotEmpty) {
                                    // Clean phone number: remove spaces, dashes, etc.
                                    phoneController.text = contact.phones.first.number
                                        .replaceAll(RegExp(r'\D'), '');
                                  }
                                });
                              }
                            },
                      icon: const Icon(Icons.contacts, size: 18),
                      label: const Text('Select from Contacts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'e.g. 9876543210',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (nameController.text.isEmpty ||
                              phoneController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all fields'),
                                backgroundColor: Colors.orangeAccent,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isProcessing = true);
                          await _addStaffProfile(
                            nameController.text,
                            phoneController.text,
                          );
                          if (mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Contact?> _pickFromContacts() async {
    try {
      if (await Permission.contacts.request().isGranted) {
        return await FlutterContacts.openExternalPick();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission denied'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking contact: $e');
    }
    return null;
  }

  Future<void> _addStaffProfile(String name, String phone) async {
    try {
      // Normalize phone: if it's 10 digits, we might want to handle prefixes, 
      // but for now we'll search by exact match or simple normalization.
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      
      // 1. Check if profile exists
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('phone', cleanPhone)
          .maybeSingle();

      if (existing != null) {
        // 2a. Update existing profile
        await supabase
            .from('profiles')
            .update({
              'company_id': widget.companyId,
              'role': 'staff',
              'full_name': name, // Update name if provided from contacts
            })
            .eq('id', existing['id']);
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staff member $name linked successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 2b. User doesn't have an account yet, create an invitation
        // First check if invitation already exists
        final existingInvite = await supabase
            .from('company_invitations')
            .select('id')
            .eq('phone', cleanPhone)
            .eq('company_id', widget.companyId)
            .maybeSingle();
            
        if (existingInvite == null) {
          await supabase.from('company_invitations').insert({
            'full_name': name,
            'phone': cleanPhone,
            'company_id': widget.companyId,
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name has been invited. They will be added automatically when they sign up!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name is already invited to join.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      _fetchStaff(); // Refresh list
    } catch (e) {
      debugPrint('Error adding staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
            color: Colors.white.withValues(alpha: 0.2),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No staff members found.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your Company ID to invite them!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
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
            backgroundColor: Colors.orangeAccent.withValues(alpha: 0.1),
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
                    color: Colors.white.withValues(alpha: 0.5),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (staff['is_online'] == true)
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.redAccent.withValues(alpha: 0.1),
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
          title: const Text('Remove Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to remove ${staff['full_name']} from your company?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildInviteTile(Map<String, dynamic> invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
          child: const Icon(Icons.hourglass_empty, color: Colors.orangeAccent),
        ),
        title: Text(
          invite['full_name'] ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '📱 ${invite['phone'] ?? ''}\nMissing App Account',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF161626),
                title: const Text('Cancel Invitation?', style: TextStyle(color: Colors.white)),
                content: Text('Are you sure you want to cancel the invitation for ${invite['full_name']}?', style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('No', style: TextStyle(color: Colors.white54)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelInvitation(invite['id'], invite['full_name']);
                    },
                    child: const Text('Yes, Cancel', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

