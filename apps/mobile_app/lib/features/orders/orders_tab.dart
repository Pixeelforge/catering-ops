import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'create_order_screen.dart';
import 'bids_screen.dart';

class OrdersTab extends StatefulWidget {
  final String companyId;

  const OrdersTab({super.key, required this.companyId});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;
  String _currentFilter =
      'all'; // 'all', 'upcoming', 'completed', 'pending_payment'
  String? _expandedOrderId;
  // Cache of bids per order: orderId -> list of bids
  final Map<String, List<Map<String, dynamic>>> _bidsCache = {};
  RealtimeChannel? _bidsSubscription;

  Future<void> _sendToKhata(
    String orderId,
    String tag,
    double amount,
    bool isAlreadySaved,
  ) async {
    if (isAlreadySaved) {
      _toast('Already saved to Khata');
      return;
    }

    try {
      // Parse "Name (Phone)"
      final nameEnd = tag.lastIndexOf(' (');
      if (nameEnd == -1) return;

      final name = tag.substring(0, nameEnd);
      final phone = tag.substring(nameEnd + 2, tag.length - 1);

      // 1. Check if middle man already exists for this company/phone
      final existing = await _supabase
          .from('middle_men')
          .select()
          .eq('company_id', widget.companyId)
          .eq('phone_number', phone)
          .maybeSingle();

      if (existing != null) {
        // 2. Update existing balance
        final double currentBalance =
            (existing['total_balance'] as num?)?.toDouble() ?? 0.0;
        await _supabase
            .from('middle_men')
            .update({'total_balance': currentBalance + amount})
            .eq('id', existing['id']);
      } else {
        // 3. Create new middle man
        await _supabase.from('middle_men').insert({
          'company_id': widget.companyId,
          'name': name,
          'phone_number': phone,
          'total_balance': amount,
        });
      }

      // 4. Mark order as saved to Khata
      await _supabase
          .from('orders')
          .update({'is_khata_saved': true})
          .eq('id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $name\'s Khata (Online)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending to Khata: $e');
      _toast('Error: $e');
    }
  }

  RealtimeChannel? _ordersSubscription;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _setupRealtime();
    // Initialize the countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ordersSubscription?.unsubscribe();
    _bidsSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      final data = await _supabase
          .from('orders')
          .select()
          .eq('company_id', widget.companyId)
          .order('event_date', ascending: true);

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtime() {
    // Orders subscription — no column filter to avoid REPLICA IDENTITY issues
    _ordersSubscription = _supabase
        .channel('orders_tab_orders_global') // Using a cleaner channel name
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            // Refresh on any change for now to be safe, filtering is handled by _fetchOrders select
            _fetchOrders();
          },
        )
        .subscribe();

    // Bids subscription — refresh bids cache when any bid changes
    _bidsSubscription = _supabase
        .channel('orders_tab_bids_${widget.companyId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_bids',
          callback: (payload) {
            final orderId =
                (payload.newRecord.isNotEmpty
                        ? payload.newRecord
                        : payload.oldRecord)['order_id']
                    as String?;
            if (orderId != null) {
              _fetchBidsForOrder(orderId);
            } else {
              // Fallback: refresh all open order bids
              for (final o in _allOrders) {
                if (o['is_delivery_open'] == true) {
                  _fetchBidsForOrder(o['id']);
                }
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchBidsForOrder(String orderId) async {
    try {
      final data = await _supabase
          .from('delivery_bids')
          .select('id, bid_amount, staff_id, created_at, profiles(full_name)')
          .eq('order_id', orderId)
          .order('bid_amount', ascending: true);
      if (mounted) {
        setState(() {
          _bidsCache[orderId] = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching bids for $orderId: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    List<Map<String, dynamic>> orders;
    if (_currentFilter == 'all') {
      orders = List.from(_allOrders);
    } else {
      orders = _allOrders.where((order) {
        if (_currentFilter == 'upcoming')
          return order['order_status'] == 'upcoming';
        if (_currentFilter == 'completed')
          return order['order_status'] == 'completed';
        if (_currentFilter == 'pending_payment')
          return order['payment_status'] == 'pending';
        return true;
      }).toList();
    }

    // Priority sort:
    // 1. Unassigned orders (Action Required)
    // 2. Event Date (Earliest first)
    orders.sort((a, b) {
      final aUnassigned =
          a['delivery_staff_id'] == null && a['is_delivery_open'] != true;
      final bUnassigned =
          b['delivery_staff_id'] == null && b['is_delivery_open'] != true;

      // Unassigned always on top
      if (aUnassigned && !bUnassigned) return -1;
      if (!aUnassigned && bUnassigned) return 1;

      // Then sort by event date (Earliest first)
      final aDate = DateTime.tryParse(a['event_date'] ?? '') ?? DateTime(2099);
      final bDate = DateTime.tryParse(b['event_date'] ?? '') ?? DateTime(2099);
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;

      // Tie-breaker: newest created_at first for same event time
      final aCreated =
          DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      final bCreated =
          DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      return bCreated.compareTo(aCreated);
    });

    return orders;
  }

  Future<void> _updatePaymentStatus(String id, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'payment_status': newStatus})
          .eq('id', id);
    } catch (e) {
      _toast('Error updating payment: $e');
    }
  }

  Future<void> _deleteOrder(String id) async {
    try {
      await _supabase.from('orders').delete().eq('id', id);
      _toast('Order deleted');
      if (mounted) {
        setState(() {
          _allOrders.removeWhere((o) => o['id'] == id);
        });
      }
    } catch (e) {
      _toast('Error deleting order: $e');
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orangeAccent),
      );
    }
  }

  Future<void> _shareToWhatsApp(
    Map<String, dynamic> order,
    String? staffId,
  ) async {
    if (staffId == null) {
      _toast('No delivery staff assigned');
      return;
    }

    try {
      // 1. Fetch staff profile (especially phone)
      final staffProfile = await _supabase
          .from('profiles')
          .select('full_name, phone')
          .eq('id', staffId)
          .maybeSingle();

      if (staffProfile == null || staffProfile['phone'] == null) {
        _toast('Staff phone number not found');
        return;
      }

      final String staffPhone = staffProfile['phone'];
      // Clean phone number: remove non-numeric
      final String cleanPhone = staffPhone.replaceAll(RegExp(r'\D'), '');

      // Ensure it has country code (Assuming Indian numbers if 10 digits)
      final String finalPhone = cleanPhone.length == 10
          ? '91$cleanPhone'
          : cleanPhone;

      // 2. Format Message
      final DateTime eventDate = DateTime.parse(order['event_date']).toLocal();
      final String dateStr = DateFormat(
        'EEE, MMM d • h:mm a',
      ).format(eventDate);
      final List menuItems = order['menu_items'] ?? [];
      final String menuStr = menuItems.join('\n- ');

      final String message =
          '''
*📦 New Order Details*
--------------------------
*Client:* ${order['client_name']}
*Date:* $dateStr
*Value:* ₹${order['total_value']}
*Address:* ${order['event_address'] ?? 'Check App'}

*Menu Items:*
- $menuStr

*Please confirm once received.*
--------------------------
''';

      // 3. Launch WhatsApp
      final Uri whatsappUri = Uri.parse(
        'https://wa.me/$finalPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        _toast('Could not launch WhatsApp');
      }
    } catch (e) {
      debugPrint('Error sharing to WhatsApp: $e');
      _toast('Error: $e');
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _currentFilter = value),
        selectedColor: Colors.orangeAccent.withOpacity(0.2),
        checkmarkColor: Colors.orangeAccent,
        backgroundColor: Colors.white.withOpacity(0.05),
        labelStyle: TextStyle(
          color: isSelected ? Colors.orangeAccent : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? Colors.orangeAccent : Colors.white12,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {bool isNextUp = false}) {
    final DateTime eventDate = DateTime.parse(order['event_date']).toLocal();
    final String formattedDate = DateFormat(
      'EEE, MMM d • h:mm a',
    ).format(eventDate);
    final String clientName = order['client_name'] ?? 'Unknown';
    final List<dynamic> menuItems = order['menu_items'] ?? [];
    final double totalValue = (order['total_value'] as num).toDouble();
    final bool isPaid = order['payment_status'] == 'paid';
    final bool isCompleted = order['order_status'] == 'completed';
    final String? middlemanTag = order['middleman_tag'];
    final bool isKhataSaved = order['is_khata_saved'] == true;
    final String? deliveryStaffId = order['delivery_staff_id'];
    final bool isDeliveryOpen = order['is_delivery_open'] == true;
    final String? deliverySignature = order['delivery_signature'];
    final bool isDelivered =
        deliverySignature != null && deliverySignature.isNotEmpty;

    // Fetch bids when order is open and expanded
    if (isDeliveryOpen &&
        _expandedOrderId == order['id'] &&
        !_bidsCache.containsKey(order['id'])) {
      _fetchBidsForOrder(order['id']);
    }

    final isExpanded = _expandedOrderId == order['id'];

    return Dismissible(
      key: Key(order['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              'Delete Order',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this order?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteOrder(order['id']),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedOrderId = isExpanded ? null : order['id'];
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDelivered
                ? Colors.greenAccent.withOpacity(0.07)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDelivered
                  ? Colors.greenAccent.withOpacity(0.6)
                  : isExpanded
                  ? Colors.orangeAccent.withOpacity(0.5)
                  : (deliveryStaffId == null && !isDeliveryOpen)
                  ? Colors.redAccent.withOpacity(0.8)
                  : Colors.white10,
              width: isDelivered
                  ? 1.5
                  : (deliveryStaffId == null && !isDeliveryOpen)
                  ? 1.5
                  : 1.0,
            ),
            boxShadow: isDelivered
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.2),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : (deliveryStaffId == null && !isDeliveryOpen)
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section (Always Visible)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(20),
                    bottom: isExpanded
                        ? Radius.zero
                        : const Radius.circular(20),
                  ),
                  border: const Border(
                    bottom: BorderSide(color: Colors.white10),
                  ),
                ),
                child: Column(
                  children: [
                    if (isNextUp)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orangeAccent.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notification_important,
                                    size: 14,
                                    color: Colors.black,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'NEXT UP',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            clientName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${totalValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.orangeAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _updatePaymentStatus(
                            order['id'],
                            isPaid ? 'pending' : 'paid',
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? Colors.greenAccent.withOpacity(0.1)
                                  : Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPaid
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                            child: Text(
                              isPaid ? 'PAID' : 'PENDING PAYMENT',
                              style: TextStyle(
                                color: isPaid
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Expandable Section
              AnimatedCrossFade(
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (middlemanTag != null && middlemanTag.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Color(0xFFD4A237),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Middleman: ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                middlemanTag,
                                style: const TextStyle(
                                  color: Color(0xFFD4A237),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Delivery Assignment Status
                    if (isDeliveryOpen || deliveryStaffId != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.delivery_dining,
                                  color: isDeliveryOpen
                                      ? Colors.purpleAccent
                                      : Colors.lightBlue,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isDeliveryOpen ? 'Status: ' : 'Assigned to: ',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isDeliveryOpen)
                                  const Flexible(
                                    child: Text(
                                      'Open for Bidding',
                                      style: TextStyle(
                                        color: Colors.purpleAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: FutureBuilder(
                                      future: _supabase
                                          .from('profiles')
                                          .select('full_name')
                                          .eq('id', deliveryStaffId!)
                                          .maybeSingle(),
                                      builder: (context, snapshot) {
                                        final name =
                                            snapshot.data?['full_name'] ??
                                            'Loading...';
                                        return Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.lightBlue,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                            if (order['delivery_fare'] != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  left: 22,
                                ),
                                child: Text(
                                  isDeliveryOpen
                                      ? 'Base Fare: ₹${order['delivery_fare']}'
                                      : 'Delivery Fare: ₹${order['delivery_fare']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (isDeliveryOpen &&
                                order['delivery_bidding_ends_at'] != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  left: 22,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final endAt = DateTime.parse(
                                      order['delivery_bidding_ends_at'],
                                    ).toLocal();
                                    final now = DateTime.now();
                                    if (now.isAfter(endAt)) {
                                      _supabase
                                          .rpc(
                                            'resolve_delivery_auction',
                                            params: {'p_order_id': order['id']},
                                          )
                                          .then((_) => _fetchOrders());
                                      return const Text(
                                        'Resolving Auction...',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      );
                                    }
                                    final diff = endAt.difference(now);
                                    return Text(
                                      diff.inSeconds < 60
                                          ? 'Bidding Ends in: ${diff.inSeconds}s'
                                          : 'Bidding Ends in: ${diff.inMinutes}m ${diff.inSeconds % 60}s',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            // View Bids button
                            if (isDeliveryOpen)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 22,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BidsScreen(
                                          orderId: order['id'],
                                          clientName:
                                              order['client_name'] ?? '',
                                          baseFare:
                                              (order['delivery_fare'] as num?)
                                                  ?.toDouble() ??
                                              0,
                                          biddingEndsAt:
                                              order['delivery_bidding_ends_at'] !=
                                                  null
                                              ? DateTime.parse(
                                                  order['delivery_bidding_ends_at'],
                                                ).toLocal()
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purpleAccent.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.purpleAccent.withOpacity(
                                          0.4,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.gavel,
                                          color: Colors.purpleAccent,
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'View Bids',
                                          style: TextStyle(
                                            color: Colors.purpleAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.open_in_new,
                                          color: Colors.purpleAccent,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Menu Items Section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Menu Items:',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: menuItems.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      (item['quantity_type'] == 'persons')
                                          ? 'For ${item['quantity']} Persons'
                                          : '${item['quantity']}x',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      item['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // Actions Footer
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white10)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Delivered badge or status label
                              if (isDelivered)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.greenAccent.withOpacity(
                                        0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        color: Colors.greenAccent,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'DELIVERED',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Text(
                                  isCompleted
                                      ? 'Order Completed'
                                      : 'Upcoming Event',
                                  style: TextStyle(
                                    color: isCompleted
                                        ? Colors.white54
                                        : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          // Display Signature Directly
                          if (isDelivered)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.draw,
                                        color: Colors.greenAccent,
                                        size: 14,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Receiver\'s Signature',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(deliverySignature),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            // Assign for Delivery — disabled while bidding is active or if delivered
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (isDeliveryOpen ||
                                          isDelivered ||
                                          deliveryStaffId != null)
                                      ? null
                                      : () => _showAssignDialog(order['id']),
                                  icon: Icon(
                                    Icons.delivery_dining,
                                    color: (isDeliveryOpen || isDelivered)
                                        ? Colors.white24
                                        : Colors.black87,
                                    size: 18,
                                  ),
                                  label: Text(
                                    isDelivered
                                        ? 'Delivered'
                                        : isDeliveryOpen
                                        ? 'Assign Locked (Bidding)'
                                        : (deliveryStaffId != null)
                                        ? 'Re-assign Delivery'
                                        : 'Assign for Delivery',
                                    style: TextStyle(
                                      color:
                                          (isDeliveryOpen ||
                                              isDelivered ||
                                              deliveryStaffId != null)
                                          ? Colors.white24
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        (isDeliveryOpen ||
                                            isDelivered ||
                                            deliveryStaffId != null)
                                        ? Colors.white.withOpacity(0.05)
                                        : const Color(0xFFD4A237),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          // WhatsApp Share — only if assigned
                          if (deliveryStaffId != null && !isDelivered)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _shareToWhatsApp(order, deliveryStaffId),
                                  icon: const Icon(
                                    Icons.chat,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Send Details via WhatsApp',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          // Send to Khata — disabled while bidding is active
                          if (middlemanTag != null && middlemanTag.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (isKhataSaved ||
                                          isDeliveryOpen ||
                                          deliveryStaffId != null)
                                      ? null
                                      : () => _sendToKhata(
                                          order['id'],
                                          middlemanTag,
                                          totalValue,
                                          isKhataSaved,
                                        ),
                                  icon: Icon(
                                    isKhataSaved
                                        ? Icons.check_circle
                                        : Icons.person_pin_circle_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    isKhataSaved
                                        ? 'Saved to $middlemanTag\'s Khata'
                                        : 'Send to $middlemanTag\'s Khata',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isKhataSaved
                                        ? Colors.grey
                                        : const Color(0xFF2E7D32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          // Delete Order Button
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton.icon(
                              onPressed: () async {
                                if (isDelivered) {
                                  _toast('Delivered orders cannot be deleted');
                                  return;
                                }
                                if (deliveryStaffId != null) {
                                  _toast('Assigned orders cannot be deleted');
                                  return;
                                }
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1A2E),
                                    title: const Text(
                                      'Delete Order',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'Are you sure you want to delete this order?',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _deleteOrder(order['id']);
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: const Text(
                                'Delete Order',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;
    String? nextUpId;
    try {
      final now = DateTime.now();
      final nextUp = orders.firstWhere(
        (o) =>
            o['order_status'] == 'upcoming' &&
            DateTime.parse(o['event_date']).isAfter(now),
      );
      nextUpId = nextUp['id'];
    } catch (_) {}

    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by parent View
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CreateOrderScreen(companyId: widget.companyId),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'New Order',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Notebook',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      _buildFilterChip('Upcoming', 'upcoming'),
                      _buildFilterChip('Completed', 'completed'),
                      _buildFilterChip('Pending Payment', 'pending_payment'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // List
                Expanded(
                  child: orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No orders found',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            0,
                            24,
                            100,
                          ), // padding for FAB
                          itemCount: orders.length,
                          itemBuilder: (context, index) => _buildOrderCard(
                            orders[index],
                            isNextUp: orders[index]['id'] == nextUpId,
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _showAssignDialog(String orderId) async {
    final fareController = TextEditingController();
    int selectedDuration = 15;
    String selectedStaffId = '';
    String assignmentType = 'none'; // 'specific', 'open', 'none'

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              title: const Text(
                'Delivery Assignment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Assignment Type:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1A1A2E),
                      value: assignmentType,
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: Text(
                            'Remove Assignment',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'specific',
                          child: Text(
                            'Assign to Specific Staff',
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'open',
                          child: Text(
                            'Open for All (Bidding)',
                            style: TextStyle(color: Colors.purpleAccent),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'claim',
                          child: Text(
                            'Fastest Claim (Direct)',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => assignmentType = val!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (assignmentType != 'none') ...[
                      const SizedBox(height: 16),
                      Text(
                        (assignmentType == 'specific' ||
                                assignmentType == 'claim')
                            ? 'Delivery Fare (₹):'
                            : 'Base Fare (₹):',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fareController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter amount',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    if (assignmentType == 'specific') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select Staff Member:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder(
                        future: _supabase
                            .from('profiles')
                            .select('id, full_name')
                            .eq('company_id', widget.companyId)
                            .eq('role', 'staff'),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const CircularProgressIndicator();
                          final staffList = List<Map<String, dynamic>>.from(
                            snapshot.data ?? [],
                          );
                          return DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF1A1A2E),
                            value: selectedStaffId.isEmpty
                                ? null
                                : selectedStaffId,
                            items: staffList
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s['id'] as String,
                                    child: Text(
                                      s['full_name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedStaffId = val!),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (assignmentType == 'open') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Bidding Duration:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        dropdownColor: const Color(0xFF1A1A2E),
                        value: selectedDuration,
                        items: const [
                          DropdownMenuItem(
                            value: -30,
                            child: Text(
                              '30 Seconds (Test)',
                              style: TextStyle(color: Colors.tealAccent),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 15,
                            child: Text(
                              '15 Minutes',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text(
                              '30 Minutes',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text(
                              '1 Hour',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text(
                              '2 Hours',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => selectedDuration = val!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
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
                  onPressed: () async {
                    if (assignmentType != 'none' &&
                        fareController.text.isEmpty) {
                      _toast('Please enter a fare amount');
                      return;
                    }
                    if (assignmentType == 'specific' &&
                        selectedStaffId.isEmpty) {
                      _toast('Please select a staff member');
                      return;
                    }

                    final double fare =
                        double.tryParse(fareController.text) ?? 0.0;
                    final biddingEndsAt = assignmentType == 'open'
                        ? (selectedDuration == -30
                              ? DateTime.now()
                                    .add(const Duration(seconds: 30))
                                    .toUtc()
                                    .toIso8601String()
                              : DateTime.now()
                                    .add(Duration(minutes: selectedDuration))
                                    .toUtc()
                                    .toIso8601String())
                        : null;

                    try {
                      final updates = {
                        'delivery_staff_id': assignmentType == 'specific'
                            ? selectedStaffId
                            : null,
                        'is_delivery_open':
                            (assignmentType == 'open' ||
                            assignmentType == 'claim'),
                        'delivery_fare': assignmentType == 'none' ? null : fare,
                        'delivery_bidding_ends_at': biddingEndsAt,
                      };

                      await _supabase
                          .from('orders')
                          .update(updates)
                          .eq('id', orderId);
                      _toast('Delivery settings updated');
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      _toast('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A237),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
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
}
