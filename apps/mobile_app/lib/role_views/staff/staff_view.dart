import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../features/inventory/inventory_list_screen.dart';

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
  String? _companyName;

  final _companyCodeCtrl = TextEditingController();
  bool _submittingCode = false;

  List<Map<String, dynamic>> _teammates = [];
  bool _loadingTeammates = false;
  RealtimeChannel? _teammateSubscription;

  Map<String, dynamic>? _pendingRequest;
  RealtimeChannel? _requestSubscription;
  RealtimeChannel? _profileSubscription;
  RealtimeChannel? _assignedOrdersSubscription;
  final _audioPlayer = AudioPlayer();
  
  List<Map<String, dynamic>> _assignedOrders = [];
  List<Map<String, dynamic>> _openOrders = [];
  bool _loadingAssignedOrders = false;
  final Set<String> _dismissedOrders = {};
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchStaffProfile();
    _fetchRequestStatus();
    _setupRequestRealtime();
    _setupProfileRealtime();
    _fetchAssignedOrders();
    _setupAssignedOrdersRealtime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _companyCodeCtrl.dispose();
    _teammateSubscription?.unsubscribe();
    _requestSubscription?.unsubscribe();
    _profileSubscription?.unsubscribe();
    _assignedOrdersSubscription?.unsubscribe();
    _audioPlayer.dispose();
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
          .maybeSingle();

      if (mounted) {
        setState(() {
          _staffName = res?['full_name'];
          _companyId = res?['company_id'];
          _loading = false;
        });

        if (_companyId != null) {
          _fetchTeammates();
          _setupTeammateRealtime();
          _fetchCompanyName();
        }
      }
    } catch (e) {
      debugPrint('Error fetching staff profile: $e');
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

  Future<void> _fetchRequestStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await supabase
          .from('company_join_requests')
          .select('*, companies(name)')
          .eq('staff_id', user.id)
          .eq('status', 'pending')
          .maybeSingle();

      if (mounted) {
        setState(() => _pendingRequest = res);
      }
    } catch (e) {
      debugPrint('Error fetching request status: $e');
    }
  }

  void _setupRequestRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _requestSubscription?.unsubscribe();
    _requestSubscription = supabase
        .channel('public:company_join_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'company_join_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'staff_id',
            value: user.id,
          ),
          callback: (payload) async {
            // Small delay to let DB trigger finish updating profile
            await Future.delayed(const Duration(milliseconds: 800));
            _fetchRequestStatus();
            _fetchStaffProfile();
          },
        )
        .subscribe();
  }

  void _setupProfileRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _profileSubscription?.unsubscribe();
    _profileSubscription = supabase
        .channel('public:profiles:current_staff')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            final newId = payload.newRecord['company_id'];
            if (newId != null && _companyId == null) {
              _audioPlayer.play(AssetSource('sounds/notification.mp3'));
              if (mounted) {
                setState(() {
                  _companyId = newId;
                });
                // Fetch necessary data now that the user is in a company
                _fetchTeammates();
                _setupTeammateRealtime();
                _fetchCompanyName();
                _fetchAssignedOrders();
              }
            }
            _fetchStaffProfile();
          },
        )
        .subscribe();
  }

  Future<void> _joinCompany() async {
    final codeText = _companyCodeCtrl.text.trim();
    if (codeText.isEmpty) {
      _showToast('Please enter a valid Company ID', Colors.redAccent);
      return;
    }

    // Basic UUID validation
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRegex.hasMatch(codeText)) {
      _showToast(
        'Invalid ID format. Please copy the full ID from your owner.',
        Colors.redAccent,
      );
      return;
    }

    setState(() => _submittingCode = true);

    try {
      final companyRes = await supabase
          .from('companies')
          .select('id')
          .eq('id', codeText)
          .maybeSingle();

      if (companyRes == null) {
        _showToast('Could not find a company with this ID.', Colors.redAccent);
        setState(() => _submittingCode = false);
        return;
      }

      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('company_join_requests').upsert(
          {
            'staff_id': user.id,
            'company_id': codeText,
            'status': 'pending',
          },
          onConflict: 'staff_id, company_id',
        );

        _showToast('Request sent to the owner!', Colors.orangeAccent);
        await _fetchRequestStatus();
      }
    } catch (e) {
      _showToast(
        e.toString().contains('duplicate key')
            ? 'Request already sent'
            : 'Connection error',
        Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _submittingCode = false);
    }
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

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _fetchTeammates() async {
    if (_companyId == null) return;
    if (mounted) setState(() => _loadingTeammates = true);

    try {
      final user = supabase.auth.currentUser;
      final data = await supabase
          .from('profiles')
          .select('id, full_name, phone, is_online')
          .eq('company_id', _companyId!)
          .eq('role', 'staff')
          .neq('id', user?.id ?? '');

      if (mounted) {
        setState(() {
          _teammates = List<Map<String, dynamic>>.from(data);
          _teammates.sort((a, b) {
            bool aOnline = a['is_online'] == true;
            bool bOnline = b['is_online'] == true;
            if (aOnline && !bOnline) return -1;
            if (!aOnline && bOnline) return 1;
            return (a['full_name'] ?? '').compareTo(b['full_name'] ?? '');
          });
          _loadingTeammates = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingTeammates = false);
    }
  }

  void _setupTeammateRealtime() {
    _teammateSubscription?.unsubscribe();
    if (_companyId == null) return;

    _teammateSubscription = supabase
        .channel('public:profiles:teammates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: _companyId!,
          ),
          callback: (payload) => _fetchTeammates(),
        )
        .subscribe();
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
      if (_pendingRequest != null) return _buildPendingRequestScreen();
      return _buildJoinCompanyScreen();
    }

    return _buildMainDashboard();
  }

  Widget _buildPendingRequestScreen() {
    final companyName =
        (_pendingRequest?['companies'] as Map?)?['name'] ?? 'the Company';
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await supabase
                    .from('company_join_requests')
                    .delete()
                    .eq('id', _pendingRequest!['id']);
                _fetchRequestStatus();
              } catch (_) {}
            },
            icon: const Icon(Icons.cancel_outlined, color: Colors.white70),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                size: 80,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 32),
              const Text(
                'Request Pending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your request to join "$companyName" is waiting for approval.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: Colors.orangeAccent),
            ],
          ),
        ),
      ),
    );
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
                          'Connected to Team',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _companyName ??
                              'ID: ••••••••${_companyId!.substring(_companyId!.length - 4)}',
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
            
            // Inventory Action
            InkWell(
              onTap: () {
                if (_companyId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryListScreen(
                        companyId: _companyId!,
                        isOwner: false,
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
                            'View Inventory',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Check current food items and stock',
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
            _buildAvailableToClaim(),
            const SizedBox(height: 30),
            _buildUpcomingEvents(),
            const SizedBox(height: 30),
            _buildTeammatesSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableToClaim() {
    final visibleOpenOrders = _openOrders.where((o) => !_dismissedOrders.contains(o['id'])).toList();

    if (visibleOpenOrders.isEmpty && !_loadingAssignedOrders) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Available to Claim',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
              ),
              child: Text(
                '${visibleOpenOrders.length} OPEN',
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingAssignedOrders)
          const Center(
            child: CircularProgressIndicator(color: Colors.orangeAccent),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleOpenOrders.length,
            itemBuilder: (context, index) {
              final order = visibleOpenOrders[index];
              return _buildOpenOrderTile(order);
            },
          ),
      ],
    );
  }

  Widget _buildOpenOrderTile(Map<String, dynamic> order) {
    final DateTime eventDate = DateTime.parse(order['event_date']).toLocal();
    final String clientName = order['client_name'] ?? 'Unknown';
    final String displayDate = '${eventDate.day}/${eventDate.month}/${eventDate.year} at ${eventDate.hour}:${eventDate.minute.toString().padLeft(2, '0')}';
    final double baseFare = (order['delivery_fare'] as num?)?.toDouble() ?? 0.0;
    final DateTime? biddingEndsAt = order['delivery_bidding_ends_at'] != null 
        ? DateTime.parse(order['delivery_bidding_ends_at']).toLocal() 
        : null;
    
    final bidController = TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  clientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(Icons.flash_on, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _dismissedOrders.add(order['id']);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
              const SizedBox(width: 8),
              Text(
                displayDate,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Fare:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('₹$baseFare', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (biddingEndsAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ends In:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Builder(builder: (context) {
                        final now = DateTime.now();
                        if (now.isAfter(biddingEndsAt)) {
                          // Resolve auction
                          supabase.rpc('resolve_delivery_auction', params: {'p_order_id': order['id']});
                          return const Text('Expired', style: TextStyle(color: Colors.redAccent, fontSize: 12));
                        }
                        final diff = biddingEndsAt.difference(now);
                        return Text('${diff.inMinutes}m ${diff.inSeconds % 60}s', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold));
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: bidController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Your Bid (₹)',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _placeBid(order['id'], bidController.text, baseFare),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('BID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _placeBid(String orderId, String bidText, double baseFare) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    final double? bidAmount = double.tryParse(bidText);
    if (bidAmount == null) {
      _showToast('Please enter a valid amount', Colors.redAccent);
      return;
    }

    if (bidAmount < baseFare) {
      _showToast('Bid must be at least ₹$baseFare', Colors.redAccent);
      return;
    }

    try {
      await supabase.from('delivery_bids').upsert({
        'order_id': orderId,
        'staff_id': user.id,
        'bid_amount': bidAmount,
      });
      _showToast('Bid placed successfully!', Colors.green);
      // In a real app we'd hide the input, but here we'll let them re-bid/update
    } catch (e) {
      _showToast('Error placing bid: $e', Colors.redAccent);
    }
  }

  Widget _buildUpcomingEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Assigned Deliveries',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingAssignedOrders)
          const Center(
            child: CircularProgressIndicator(color: Colors.orangeAccent),
          )
        else if (_assignedOrders.isEmpty)
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
                    'No deliveries assigned to you right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _assignedOrders.length,
            itemBuilder: (context, index) {
              final order = _assignedOrders[index];
              return _buildAssignedOrderTile(order);
            },
          ),
      ],
    );
  }

  Widget _buildAssignedOrderTile(Map<String, dynamic> order) {
    final DateTime eventDate = DateTime.parse(order['event_date']).toLocal();
    final String clientName = order['client_name'] ?? 'Unknown';
    // Format date nicely
    final String displayDate = '${eventDate.day}/${eventDate.month}/${eventDate.year} at ${eventDate.hour}:${eventDate.minute.toString().padLeft(2, '0')}';
    final double? fare = (order['delivery_fare'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  clientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (fare != null)
                Text(
                  '₹$fare',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Upcoming',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
              const SizedBox(width: 8),
              Text(
                displayDate,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          const Text(
            'Order Items:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ...(order['menu_items'] as List? ?? []).map((item) {
            return Row(
              children: [
                const Text('• ', style: TextStyle(color: Colors.orangeAccent)),
                Text(
                  '${item['quantity']}x ${item['name']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _fetchAssignedOrders() async {
    final user = supabase.auth.currentUser;
    if (user == null || _companyId == null) return;
    
    if (mounted) setState(() => _loadingAssignedOrders = true);

    try {
      final resAssigned = await supabase
          .from('orders')
          .select()
          .eq('delivery_staff_id', user.id)
          .eq('order_status', 'upcoming')
          .order('event_date');
          
      final resOpen = await supabase
          .from('orders')
          .select()
          .eq('company_id', _companyId!)
          .eq('is_delivery_open', true)
          .eq('order_status', 'upcoming')
          .isFilter('delivery_staff_id', null)
          .order('event_date');

      if (mounted) {
        setState(() {
          _assignedOrders = List<Map<String, dynamic>>.from(resAssigned);
          _openOrders = List<Map<String, dynamic>>.from(resOpen);
          _loadingAssignedOrders = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching assigned/open orders: $e');
      if (mounted) setState(() => _loadingAssignedOrders = false);
    }
  }

  void _setupAssignedOrdersRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    _assignedOrdersSubscription?.unsubscribe();
    _assignedOrdersSubscription = supabase
        .channel('public:orders:assigned')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) => _fetchAssignedOrders(),
        )
        .subscribe();
  }

  Widget _buildTeammatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Teammates',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingTeammates)
          const Center(
            child: CircularProgressIndicator(color: Colors.orangeAccent),
          )
        else if (_teammates.isEmpty)
          Text(
            'No other teammates found yet.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _teammates.length,
            itemBuilder: (context, index) =>
                _buildTeammateTile(_teammates[index]),
          ),
      ],
    );
  }

  Widget _buildTeammateTile(Map<String, dynamic> staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.orangeAccent.withOpacity(0.1),
            child: Text(
              (staff['full_name'] as String?)?[0].toUpperCase() ?? 'S',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              staff['full_name'] ?? 'Unknown Member',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    : Colors.redAccent.withOpacity(0.7),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
