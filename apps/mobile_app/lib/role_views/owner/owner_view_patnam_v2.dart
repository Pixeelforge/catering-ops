import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'staff_management_screen.dart';
import 'join_requests_screen.dart';
import '../../features/inventory/inventory_list_screen.dart';
import '../../features/orders/orders_tab.dart';
import '../../features/ledger/screens/kaatha_screen.dart';

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
  int _selectedIndex = 0;
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
          _fetchActiveDelivery();
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

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _shareLocationToMiddleman() async {
    try {
      final res = await supabase
          .from('middle_men')
          .select('name, phone_number')
          .eq('company_id', _companyId!);
      
      if (res == null || (res as List).isEmpty) {
        _toast('No middlemen found to share location with');
        return;
      }

      final middleMen = List<Map<String, dynamic>>.from(res);
      
      if (!mounted) return;

      final selectedMid = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Share Location With...', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: middleMen.length,
              itemBuilder: (context, index) {
                final mid = middleMen[index];
                return ListTile(
                  title: Text(mid['name'] ?? '', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(mid['phone_number'] ?? '', style: const TextStyle(color: Colors.white70)),
                  onTap: () => Navigator.pop(context, mid),
                );
              },
            ),
          ),
        ),
      );

      if (selectedMid != null) {
        await _performLocationSharing(selectedMid['phone_number']);
      }
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _performLocationSharing(String phone) async {
    final phoneNumber = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phoneNumber.isEmpty) {
      _toast('Invalid phone number');
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _toast('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _toast('Location permissions are denied');
          return;
        }
      }

      _toast('Getting location...');
      Position position = await Geolocator.getCurrentPosition();
      
      final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      final String message = Uri.encodeComponent('Hi, I am the owner. Here is my current location: $googleMapsUrl');
      final Uri whatsappUrl = Uri.parse('whatsapp://send?phone=$phoneNumber&text=$message');

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        final Uri webWhatsapp = Uri.parse('https://wa.me/$phoneNumber?text=$message');
        await launchUrl(webWhatsapp, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _toast('Error sharing location: $e');
    }
  }

  Map<String, dynamic>? _activeDelivery;
  bool _loadingActive = false;

  Future<void> _fetchActiveDelivery() async {
    if (_companyId == null) return;
    setState(() => _loadingActive = true);
    try {
      final res = await supabase
          .from('orders')
          .select('id, client_name, middleman_tag, delivery_staff_id, profiles!orders_delivery_staff_id_fkey(full_name, last_latitude, last_longitude)')
          .eq('company_id', _companyId!)
          .eq('order_status', 'upcoming')
          .not('delivery_staff_id', 'is', null)
          .order('event_date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeDelivery = res;
          _loadingActive = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching active delivery: $e');
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  Future<void> _shareStaffLocation(Map<String, dynamic> delivery) async {
    final middlemanTag = delivery['middleman_tag'];
    final staff = delivery['profiles'];
    
    if (middlemanTag == null || middlemanTag.isEmpty) {
      _toast('No middleman for this order');
      return;
    }

    final regExp = RegExp(r'\((.*?)\)');
    final match = regExp.firstMatch(middlemanTag);
    final phoneNumber = match?.group(1)?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';

    if (phoneNumber.isEmpty) {
      _toast('No middleman phone found');
      return;
    }

    if (staff == null || staff['last_latitude'] == null) {
      _toast('Staff location not available yet');
      return;
    }

    final lat = staff['last_latitude'];
    final lng = staff['last_longitude'];
    final staffName = staff['full_name'] ?? 'Staff';
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final String message = Uri.encodeComponent('Hi, I am the owner. Here is the live location of our delivery staff ($staffName): $googleMapsUrl');
    
    final Uri whatsappUrl = Uri.parse('whatsapp://send?phone=$phoneNumber&text=$message');
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        await launchUrl(Uri.parse('https://wa.me/$phoneNumber?text=$message'), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _toast('Error: $e');
    }
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

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
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

          if (_activeDelivery != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      const Icon(Icons.local_shipping, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'ACTIVE DELIVERY',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.orangeAccent, size: 16),
                        onPressed: _fetchActiveDelivery,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Client: ${_activeDelivery!['client_name']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Staff: ${_activeDelivery!['profiles']?['full_name'] ?? 'Assigning...'}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _shareStaffLocation(_activeDelivery!),
                      icon: const Icon(Icons.share_location, size: 18),
                      label: const Text('Share Staff Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

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
                              ? 'ΓÇó' * 12
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

          const SizedBox(height: 24),

          // QUICK LOCATION SHARE CARD
          InkWell(
            onTap: _shareLocationToMiddleman,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.greenAccent.withOpacity(0.15),
                    Colors.greenAccent.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share_location,
                      color: Colors.greenAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share My Location',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Send live location to a middleman',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
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
    );
  }
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
      body: _selectedIndex == 0
          ? _buildDashboardTab()
          : _selectedIndex == 1
              ? OrdersTab(companyId: _companyId ?? '')
              : _selectedIndex == 2
                  ? const JoinRequestsScreen()
                  : StaffManagementScreen(companyId: _companyId ?? ''),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF161626),
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingCount > 0,
              label: Text('$_pendingCount'),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.person_add_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: _pendingCount > 0,
              label: Text('$_pendingCount'),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.person_add),
            ),
            label: 'Requests',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
            label: 'Staff',
          ),
        ],
      ),
    );
  }
}
