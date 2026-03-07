import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'staff_management_screen.dart';
import '../../features/inventory/inventory_list_screen.dart';

class OwnerView extends StatefulWidget {
  const OwnerView({super.key});

  @override
  State<OwnerView> createState() => _OwnerViewState();
}

class _OwnerViewState extends State<OwnerView> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  String? _companyId;
  String? _ownerName;
  String? _companyName;
  int _pendingCount = 0;
  RealtimeChannel? _requestSubscription;
  bool _showId = false;
  final _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _requestSubscription?.unsubscribe();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchOwnerProfile();
  }

  Future<void> _fetchOwnerProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await supabase
          .from('profiles')
          .select('full_name, company_id')
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (mounted) {
        setState(() {
          _ownerName = res['full_name'];
          _companyId = res['company_id'];
          _loading = false;
        });

        if (_companyId != null) {
          _fetchCompanyName();
          _fetchRequestCount();
          _setupRequestRealtime();
        }
      }
    } catch (e) {
      debugPrint('Error fetching owner profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCompanyName() async {
    if (_companyId == null) return;
    try {
      final res = await supabase
          .from('companies')
          .select('name')
          .eq('id', _companyId!)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() => _companyName = res['name']);
      }
    } catch (_) {}
  }

  Future<void> _fetchRequestCount() async {
    if (_companyId == null) return;
    try {
      final res = await supabase
          .from('company_join_requests')
          .select('id')
          .eq('company_id', _companyId!)
          .eq('status', 'pending');
      if (mounted) {
        setState(() => _pendingCount = (res as List).length);
      }
    } catch (_) {}
  }

  void _setupRequestRealtime() {
    _requestSubscription?.unsubscribe();
    if (_companyId == null) return;

    _requestSubscription = supabase
        .channel('public:company_join_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'company_join_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: _companyId!,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              _audioPlayer.play(AssetSource('sounds/notification.mp3'));
            }
            _fetchRequestCount();
          },
        )
        .subscribe();
  }

  Future<void> _copyCompanyId() async {
    if (_companyId != null) {
      try {
        await Clipboard.setData(ClipboardData(text: _companyId!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company ID copied to clipboard!'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Browser blocked auto-copy. Please long-press the ID to copy!',
              ),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Widget _buildPendingRequestBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add_outlined, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_pendingCount pending join request${_pendingCount > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/join_requests'),
            child: const Text(
              'REVIEW',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Owner Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () async {
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                try {
                  await Supabase.instance.client
                      .from('profiles')
                      .update({'is_online': false})
                      .eq('id', user.id);
                } catch (_) {}
              }
              await Supabase.instance.client.auth.signOut();
              if (context.mounted)
                Navigator.pushReplacementNamed(context, '/login');
            },
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
              'Welcome Back,',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            Text(
              _companyName ?? 'Dashboard',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Owner: ${_ownerName ?? '...'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 30),

            if (_pendingCount > 0) _buildPendingRequestBanner(),
            // Company ID Card (The "Copy" section)
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
                  Row(
                    children: [
                      const Icon(
                        Icons.business,
                        color: Colors.orangeAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MY COMPANY ID',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            !_showId && _companyId != null
                                ? '•' * 12
                                : (_companyId ?? 'Generating...'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                              fontSize: 14,
                              letterSpacing: 2,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(
                            _showId
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _showId = !_showId),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 15),
                        InkWell(
                          onTap: _copyCompanyId,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              color: Colors.orangeAccent,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Share this ID with your staff so they can join your workspace.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Inventory Action
            InkWell(
              onTap: () {
                if (_companyId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryListScreen(
                        companyId: _companyId!,
                        isOwner: true,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.15),
                      Colors.blueAccent.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.blueAccent.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.blueAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Inventory',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Track food items and stock',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white24,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Staff Management Action
            InkWell(
              onTap: () {
                if (_companyId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StaffManagementScreen(companyId: _companyId!),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orangeAccent.withOpacity(0.15),
                      Colors.orangeAccent.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orangeAccent.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.orangeAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Staff',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'View and manage your team members',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white24,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            // Placeholder for future features
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
                      Icons.analytics_outlined,
                      color: Colors.orangeAccent.withOpacity(0.2),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Revenue & Orders overview will appear here soon.',
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
