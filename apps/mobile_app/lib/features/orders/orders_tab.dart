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
  String _currentFilter = 'all'; // 'all', 'upcoming', 'completed', 'pending_payment'

  RealtimeChannel? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _setupRealtime();
  }

  @override
  void dispose() {
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
      if (_currentFilter == 'upcoming') return order['order_status'] == 'upcoming';
      if (_currentFilter == 'completed') return order['order_status'] == 'completed';
      if (_currentFilter == 'pending_payment') return order['payment_status'] == 'pending';
      return true;
    }).toList();
  }

  Future<void> _updateOrderStatus(String id, String newStatus) async {
    try {
      await _supabase.from('orders').update({'order_status': newStatus}).eq('id', id);
    } catch (e) {
      _toast('Error updating order: $e');
    }
  }

  Future<void> _updatePaymentStatus(String id, String newStatus) async {
    try {
      await _supabase.from('orders').update({'payment_status': newStatus}).eq('id', id);
    } catch (e) {
      _toast('Error updating payment: $e');
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orangeAccent));
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
    final String formattedDate = DateFormat('EEE, MMM d • h:mm a').format(eventDate);
    final String clientName = order['client_name'] ?? 'Unknown';
    final List<dynamic> menuItems = order['menu_items'] ?? [];
    final double totalValue = (order['total_value'] as num).toDouble();
    final bool isPaid = order['payment_status'] == 'paid';
    final bool isCompleted = order['order_status'] == 'completed';
    final String? middlemanTag = order['middleman_tag'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client label
                      Row(
                        children: [
                          const Text('Client: ', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          Flexible(
                            child: Text(
                              clientName,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.orangeAccent, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(formattedDate, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                      if (middlemanTag != null && middlemanTag.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFFD4A237), size: 14),
                            const SizedBox(width: 4),
                            const Text('Middleman: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Flexible(
                              child: Text(middlemanTag, style: const TextStyle(color: Color(0xFFD4A237), fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${totalValue.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _updatePaymentStatus(order['id'], isPaid ? 'pending' : 'paid'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isPaid ? Colors.greenAccent : Colors.redAccent),
                        ),
                        child: Text(
                          isPaid ? 'PAID' : 'PENDING PAYMENT',
                          style: TextStyle(
                            color: isPaid ? Colors.greenAccent : Colors.redAccent,
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
          
          // Menu Items Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Menu Items:', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: menuItems.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${item['quantity']}x', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(item['name'], style: const TextStyle(color: Colors.white, fontSize: 12)),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      isCompleted ? 'Order Completed' : 'Upcoming Event',
                      style: TextStyle(
                        color: isCompleted ? Colors.white54 : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _updateOrderStatus(order['id'], isCompleted ? 'upcoming' : 'completed'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        backgroundColor: isCompleted ? Colors.white10 : Colors.orangeAccent.withOpacity(0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isCompleted ? 'MARK UPCOMING' : 'MARK COMPLETED',
                        style: TextStyle(
                          color: isCompleted ? Colors.white54 : Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                // Assign for Delivery button — always visible
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assign for Delivery — coming soon!'),
                            backgroundColor: Color(0xFF8B6914),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delivery_dining, color: Colors.black87, size: 18),
                      label: const Text(
                        'Assign for Delivery',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A237),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                // Send to Khata button — only shown when middleman is set
                if (middlemanTag != null && middlemanTag.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sending to $middlemanTag\'s Khata... (coming soon!)'),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_pin_circle_outlined, color: Colors.white, size: 18),
                        label: Text(
                          'Send to $middlemanTag\'s Khata',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
              builder: (context) => CreateOrderScreen(companyId: widget.companyId),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('New Order', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
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
                              Icon(Icons.assignment_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                              const SizedBox(height: 16),
                              Text(
                                'No orders found',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), // padding for FAB
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
}
