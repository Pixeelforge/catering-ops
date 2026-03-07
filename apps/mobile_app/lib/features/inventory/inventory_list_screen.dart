import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'add_inventory_item_screen.dart';

class InventoryListScreen extends StatefulWidget {
  final String companyId;
  final bool isOwner;

  const InventoryListScreen({
    super.key,
    required this.companyId,
    required this.isOwner,
  });

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _setupRealtime();
  }

  void _setupRealtime() {
    _subscription = supabase
        .channel('public:inventory_items')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: widget.companyId,
          ),
          callback: (payload) => _fetchInventory(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchInventory() async {
    try {
      final data = await supabase
          .from('inventory_items')
          .select()
          .eq('company_id', widget.companyId)
          .order('category', ascending: true)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await supabase.from('inventory_items').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
          'Inventory',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: widget.isOwner
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddInventoryItemScreen(
                      companyId: widget.companyId,
                    ),
                  ),
                );
              },
              backgroundColor: Colors.orangeAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Item',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : _items.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _buildInventoryCard(item);
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
            Icons.inventory_2_outlined,
            color: Colors.white.withOpacity(0.1),
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            'Inventory is empty',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.isOwner)
            Text(
              'Tap "Add Item" to start tracking food stock.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final String? imageUrl = item['image_url'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.orangeAccent,
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.fastfood_outlined,
                            color: Colors.white24,
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.fastfood_outlined,
                          color: Colors.white24,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['category']?.toUpperCase() ?? 'UNCATEGORIZED',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['name'] ?? 'Unknown Item',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['quantity']} ${item['unit']}',
                        style: TextStyle(
                          color: Colors.orangeAccent.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Delete button for owners
                if (widget.isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white30),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A2E),
                          title: const Text('Delete Item?', style: TextStyle(color: Colors.white)),
                          content: Text(
                            'Are you sure you want to remove ${item['name']} from inventory?',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteItem(item['id']);
                              },
                              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
