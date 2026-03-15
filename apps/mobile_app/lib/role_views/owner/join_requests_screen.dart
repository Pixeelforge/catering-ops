import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/notification_service.dart';
import '../../services/cache_service.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key, this.onRequestHandled});

  final VoidCallback? onRequestHandled;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _companyId;
  RealtimeChannel? _requestsChannel;
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Fetches the company_id first, then starts both data fetch & realtime listener.
  Future<void> _init() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final profileRes = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();

      _companyId = profileRes?['company_id'];

      if (_companyId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    } catch (e) {
      debugPrint('Error fetching company_id: $e');
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Now that we have companyId, load data and setup realtime
    await _loadRequests();
    _setupRealtime();
  }

  /// Fetches pending requests. Does NOT touch the realtime subscription.
  Future<void> _loadRequests() async {
    if (_companyId == null) return;

    // 1. Try loading from Cache
    final cached = CacheService.get('join_requests_$_companyId');
    if (cached != null && mounted) {
      setState(() {
        _requests = List<Map<String, dynamic>>.from(cached);
        _loading = false;
      });
    }

    try {
      final res = await supabase
          .from('company_join_requests')
          .select('*, profiles(*)')
          .eq('company_id', _companyId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });

        // 2. Save to Cache
        CacheService.save('join_requests_$_companyId', res);
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sets up realtime once. Callback only calls _loadRequests (safe, no loop).
  void _setupRealtime() {
    if (_companyId == null) return;

    _requestsChannel?.unsubscribe();
    _requestsChannel = supabase
        .channel('join_requests_screen_${_companyId}')
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
            // Show notification only on new incoming request
            if (payload.eventType == PostgresChangeEvent.insert) {
              _audioPlayer.play(AssetSource('sounds/notification.mp3'));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('New join request received!'),
                      ],
                    ),
                    backgroundColor: Colors.deepOrangeAccent,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
            // Just refresh the list — do NOT call _setupRealtime again
            _loadRequests();
          },
        )
        .subscribe();
  }

  Future<void> _handleRequest(String requestId, String status) async {
    try {
      await supabase
          .from('company_join_requests')
          .update({'status': status})
          .eq('id', requestId);

      if (status == 'accepted') {
        // Scenario 2: Notify Staff when their request is accepted
        final reqData = _requests.firstWhere((r) => r['id'] == requestId, orElse: () => {});
        final staffId = reqData['profiles']?['id'];
        
        if (staffId != null) {
          await NotificationService.sendNotification(
            playerIds: [staffId],
            title: 'Request Accepted! 🎉',
            message: 'You have been added to the company team. Welcome aboard!',
            data: {'type': 'request_accepted'},
            color: 'FF4CAF50', // Green
          );
        }
      } else if (status == 'rejected') {
        // Scenario: Notify Staff when their request is rejected
        final reqData = _requests.firstWhere((r) => r['id'] == requestId, orElse: () => {});
        final staffId = reqData['profiles']?['id'];
        
        if (staffId != null) {
          await NotificationService.sendNotification(
            playerIds: [staffId],
            title: 'Request Update ❌',
            message: 'Your request to join the company was not accepted.',
            data: {'type': 'request_rejected'},
            color: 'FFF44336', // Red
          );
        }
      }

      _toast(status == 'accepted' ? 'Staff accepted!' : 'Request rejected.');
      // Notify owner_view to refresh badge count immediately
      widget.onRequestHandled?.call();
      _loadRequests();
    } catch (e) {
      _toast('Error: ${e.toString()}');
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orangeAccent),
      );
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
          'Join Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : _requests.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final profilesRaw = req['profiles'];
                Map<String, dynamic> profile;

                if (profilesRaw is List && profilesRaw.isNotEmpty) {
                  profile = profilesRaw.first as Map<String, dynamic>;
                } else if (profilesRaw is Map) {
                  profile = Map<String, dynamic>.from(profilesRaw);
                } else {
                  profile = {
                    'full_name': 'Unknown',
                    'phone': 'N/A',
                    'email': 'N/A',
                  };
                }

                return _buildRequestCard(req['id'], profile);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_disabled_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending requests',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                child: Text(
                  (profile['full_name'] as String?)?[0].toUpperCase() ?? 'S',
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
                      profile['full_name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Staff Member',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(Icons.phone_outlined, profile['phone'] ?? 'No phone'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.email_outlined, profile['email'] ?? 'No email'),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleRequest(requestId, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'REJECT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleRequest(requestId, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'ACCEPT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white30),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}
