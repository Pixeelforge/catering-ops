import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuMasterScreen extends StatefulWidget {
  final String companyId;

  const MenuMasterScreen({super.key, required this.companyId});

  @override
  State<MenuMasterScreen> createState() => _MenuMasterScreenState();
}

class _MenuMasterScreenState extends State<MenuMasterScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _categories = [];
  Map<String, List<dynamic>> _itemsByCategory = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenuData();
  }

  Future<void> _fetchMenuData() async {
    setState(() => _loading = true);
    try {
      final categoriesResp = await supabase
          .from('menu_categories')
          .select()
          .eq('company_id', widget.companyId)
          .order('created_at');
          
      final itemsResp = await supabase
          .from('menu_items')
          .select()
          .eq('company_id', widget.companyId)
          .order('name');

      _categories = categoriesResp;
      _itemsByCategory = {};
      
      for (var item in itemsResp) {
        final catId = item['category_id'] as String;
        if (!_itemsByCategory.containsKey(catId)) {
          _itemsByCategory[catId] = [];
        }
        _itemsByCategory[catId]!.add(item);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading menu: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCategory() async {
    final TextEditingController ctrl = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF232336),
            title: const Text('New Category', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Category Name (e.g., Starters, Ice Creams)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (ctrl.text.trim().isEmpty) return;
                  setDialogState(() => isLoading = true);
                  try {
                     await supabase.from('menu_categories').insert({
                       'company_id': widget.companyId,
                       'name': ctrl.text.trim(),
                     });
                     if (context.mounted) Navigator.pop(context);
                     _fetchMenuData();
                  } catch (e) {
                     setDialogState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                child: isLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Add', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _addItem(String categoryId) async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController();
    bool isVeg = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF232336),
            title: const Text('New Menu Item', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Base Price',
                      labelStyle: TextStyle(color: Colors.white54),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                         children: [
                           Icon(
                             Icons.circle,
                             color: isVeg ? Colors.green : Colors.red,
                             size: 16,
                           ),
                           const SizedBox(width: 8),
                           Text(
                             isVeg ? 'Veg' : 'Non-Veg',
                             style: const TextStyle(color: Colors.white),
                           ),
                         ],
                       ),
                       Switch(
                         value: isVeg,
                         activeColor: Colors.green,
                         inactiveThumbColor: Colors.red,
                         inactiveTrackColor: Colors.red.withOpacity(0.5),
                         onChanged: (val) {
                           setDialogState(() => isVeg = val);
                         },
                       ),
                    ],
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
                onPressed: isLoading ? null : () async {
                  if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
                  setDialogState(() => isLoading = true);
                  try {
                     await supabase.from('menu_items').insert({
                       'company_id': widget.companyId,
                       'category_id': categoryId,
                       'name': nameCtrl.text.trim(),
                       'base_price': double.parse(priceCtrl.text.trim()),
                       'is_veg': isVeg,
                     });
                     if (context.mounted) Navigator.pop(context);
                     _fetchMenuData();
                  } catch (e) {
                     setDialogState(() => isLoading = false);
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                       );
                     }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                child: isLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Menu Master', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addCategory,
            tooltip: 'Add Category',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        'Your menu is empty',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text('Add First Category', style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final catId = cat['id'];
                    final items = _itemsByCategory[catId] ?? [];

                    return Card(
                      color: const Color(0xFF232336),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        iconColor: Colors.orangeAccent,
                        collapsedIconColor: Colors.white54,
                        title: Row(
                          children: [
                             Text(
                              cat['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                             ),
                             const SizedBox(width: 8),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.white10,
                                 borderRadius: BorderRadius.circular(10),
                               ),
                               child: Text(
                                 '${items.length}',
                                 style: const TextStyle(color: Colors.white54, fontSize: 12),
                               ),
                             ),
                          ],
                        ),
                        children: [
                           if (items.isEmpty)
                             const Padding(
                               padding: EdgeInsets.all(16.0),
                               child: Text('No items in this category', style: TextStyle(color: Colors.white38)),
                             ),
                           ...items.map((item) => ListTile(
                             leading: Icon(
                               Icons.circle_stop,
                               color: item['is_veg'] ? Colors.green : Colors.red,
                               size: 20,
                             ),
                             title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                             trailing: Text(
                               '₹${item['base_price']}',
                               style: const TextStyle(
                                 color: Colors.orangeAccent,
                                 fontWeight: FontWeight.bold,
                                 fontSize: 16,
                               ),
                             ),
                           )),
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             child: OutlinedButton.icon(
                               onPressed: () => _addItem(catId),
                               icon: const Icon(Icons.add, size: 18, color: Colors.orangeAccent),
                               label: const Text('Add Item', style: TextStyle(color: Colors.orangeAccent)),
                               style: OutlinedButton.styleFrom(
                                 side: const BorderSide(color: Colors.orangeAccent),
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                               ),
                             ),
                           ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
