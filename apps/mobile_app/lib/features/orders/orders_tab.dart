import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'create_order_screen.dart';

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
    _countdownTimer?.cancel(); // Dispose of the countdown timer
    _ordersSubscription?.unsubscribe();
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
    _ordersSubscription = _supabase
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: widget.companyId,
          ),
          callback: (payload) => _fetchOrders(),
        )
        .subscribe();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_currentFilter == 'all') return _allOrders;
    return _allOrders.where((order) {
      if (_currentFilter == 'upcoming')
        return order['order_status'] == 'upcoming';
      if (_currentFilter == 'completed')
        return order['order_status'] == 'completed';
      if (_currentFilter == 'pending_payment')
        return order['payment_status'] == 'pending';
      return true;
    }).toList();
  }

  Future<void> _updateOrderStatus(String id, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'order_status': newStatus})
          .eq('id', id);
    } catch (e) {
      _toast('Error updating order: $e');
    }
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
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

    final bool isExpanded = _expandedOrderId == order['id'];

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
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded
                  ? Colors.orangeAccent.withOpacity(0.5)
                  : Colors.white10,
            ),
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
                                  color: isDeliveryOpen ? Colors.purpleAccent : Colors.lightBlue,
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
                                        final name = snapshot.data?['full_name'] ?? 'Loading...';
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
                                padding: const EdgeInsets.only(top: 4, left: 22),
                                child: Text(
                                  isDeliveryOpen ? 'Base Fare: ₹${order['delivery_fare']}' : 'Delivery Fare: ₹${order['delivery_fare']}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                            if (isDeliveryOpen && order['delivery_bidding_ends_at'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 22),
                                child: Builder(
                                  builder: (context) {
                                    final endAt = DateTime.parse(order['delivery_bidding_ends_at']).toLocal();
                                    final now = DateTime.now();
                                    if (now.isAfter(endAt)) {
                                      // Timer expired, trigger resolution
                                      _supabase.rpc('resolve_delivery_auction', params: {'p_order_id': order['id']}).then((_) => _fetchOrders());
                                      return const Text('Resolving Auction...', style: TextStyle(color: Colors.redAccent, fontSize: 12));
                                    }
                                    final diff = endAt.difference(now);
                                    return Text(
                                      'Bidding Ends in: ${diff.inMinutes}m ${diff.inSeconds % 60}s',
                                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                    );
                                  },
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
                              TextButton(
                                onPressed: () => _updateOrderStatus(
                                  order['id'],
                                  isCompleted ? 'upcoming' : 'completed',
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  backgroundColor: isCompleted
                                      ? Colors.white10
                                      : Colors.orangeAccent.withOpacity(0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isCompleted
                                      ? 'MARK UPCOMING'
                                      : 'MARK COMPLETED',
                                  style: TextStyle(
                                    color: isCompleted
                                        ? Colors.white54
                                        : Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Assign for Delivery
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showAssignDialog(order['id']),
                                icon: const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.black87,
                                  size: 18,
                                ),
                                label: Text(
                                  (deliveryStaffId != null || isDeliveryOpen) ? 'Re-assign Delivery' : 'Assign for Delivery',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4A237),
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
                          // Send to Khata
                          if (middlemanTag != null && middlemanTag.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isKhataSaved
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
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Text(
                    'Order Notebook',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
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
                          itemBuilder: (context, index) {
                            return _buildOrderCard(orders[index]);
                          },
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Assignment Type:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1A1A2E),
                      value: assignmentType,
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('Remove Assignment', style: TextStyle(color: Colors.redAccent))),
                        DropdownMenuItem(value: 'specific', child: Text('Assign to Specific Staff', style: TextStyle(color: Colors.orangeAccent))),
                        DropdownMenuItem(value: 'open', child: Text('Open for All (Bidding)', style: TextStyle(color: Colors.purpleAccent))),
                      ],
                      onChanged: (val) => setDialogState(() => assignmentType = val!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    if (assignmentType != 'none') ...[
                      const SizedBox(height: 16),
                      Text(
                        assignmentType == 'specific' ? 'Delivery Fare (₹):' : 'Base Fare (₹):',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fareController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter amount',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                    if (assignmentType == 'specific') ...[
                      const SizedBox(height: 16),
                      const Text('Select Staff Member:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      FutureBuilder(
                        future: _supabase
                            .from('profiles')
                            .select('id, full_name')
                            .eq('company_id', widget.companyId)
                            .eq('role', 'staff'),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final staffList = List<Map<String, dynamic>>.from(snapshot.data ?? []);
                          return DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF1A1A2E),
                            value: selectedStaffId.isEmpty ? null : selectedStaffId,
                            items: staffList.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['full_name'], style: const TextStyle(color: Colors.white)))).toList(),
                            onChanged: (val) => setDialogState(() => selectedStaffId = val!),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          );
                        },
                      ),
                    ],
                    if (assignmentType == 'open') ...[
                      const SizedBox(height: 16),
                      const Text('Bidding Duration:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        dropdownColor: const Color(0xFF1A1A2E),
                        value: selectedDuration,
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 Minutes', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 30, child: Text('30 Minutes', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 60, child: Text('1 Hour', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 120, child: Text('2 Hours', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (val) => setDialogState(() => selectedDuration = val!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (assignmentType != 'none' && fareController.text.isEmpty) {
                      _toast('Please enter a fare amount');
                      return;
                    }
                    if (assignmentType == 'specific' && selectedStaffId.isEmpty) {
                      _toast('Please select a staff member');
                      return;
                    }

                    final double fare = double.tryParse(fareController.text) ?? 0.0;
                    final biddingEndsAt = assignmentType == 'open'
                        ? DateTime.now().add(Duration(minutes: selectedDuration)).toUtc().toIso8601String()
                        : null;

                    try {
                      final updates = {
                        'delivery_staff_id': assignmentType == 'specific' ? selectedStaffId : null,
                        'is_delivery_open': assignmentType == 'open',
                        'delivery_fare': assignmentType == 'none' ? null : fare,
                        'delivery_bidding_ends_at': biddingEndsAt,
                      };

                      await _supabase.from('orders').update(updates).eq('id', orderId);
                      _toast('Delivery settings updated');
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      _toast('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A237),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
