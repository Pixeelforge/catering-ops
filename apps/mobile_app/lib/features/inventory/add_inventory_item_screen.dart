import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddInventoryItemScreen extends StatefulWidget {
  final String companyId;

  const AddInventoryItemScreen({super.key, required this.companyId});

  @override
  State<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();

  String _selectedCategory = 'Produce';
  final List<String> _categories = [
    'Produce',
    'Meat & Poultry',
    'Dairy',
    'Dry Goods',
    'Beverages',
    'Equipment',
    'Other',
  ];

  String _selectedUnit = 'kgs';
  List<String> _units = ['kgs', 'litres', 'boxes', 'units'];
  bool _isSubmitting = false;
  bool _isLoadingUnits = true;

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  Future<void> _fetchUnits() async {
    try {
      final data = await Supabase.instance.client
          .from('inventory_units')
          .select('name')
          .eq('company_id', widget.companyId);

      final dbUnits = (data as List).map((e) => e['name'] as String).toList();

      setState(() {
        // Merge defaults with DB units, remove duplicates
        _units = {
          ...['kgs', 'litres', 'boxes', 'units'],
          ...dbUnits,
        }.toList();
        _isLoadingUnits = false;
      });
    } catch (e) {
      debugPrint('Error fetching units: $e');
      setState(() => _isLoadingUnits = false);
    }
  }

  Future<void> _addNewUnitDialog() async {
    final ctrl = TextEditingController();
    final newUnit = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Add New Unit',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Unit Name (e.g. Plates, Packets)',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newUnit != null && newUnit.isNotEmpty && mounted) {
      try {
        await Supabase.instance.client.from('inventory_units').insert({
          'company_id': widget.companyId,
          'name': newUnit,
        });
        await _fetchUnits();
        setState(() => _selectedUnit = newUnit);
      } catch (e) {
        debugPrint('Error adding unit: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('inventory_items').insert({
        'company_id': widget.companyId,
        'name': _nameCtrl.text.trim(),
        'category': _selectedCategory,
        'quantity': double.parse(_qtyCtrl.text.trim()),
        'unit': _selectedUnit,
        'image_url': _imgCtrl.text.trim().isEmpty ? null : _imgCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added to inventory!'),
            backgroundColor: Colors.greenAccent,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          'Add New Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingUnits
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _nameCtrl,
                      label: 'Item Name',
                      icon: Icons.fastfood_outlined,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Item name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _qtyCtrl,
                            label: 'Quantity',
                            icon: Icons.numbers_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty)
                                return 'Required';
                              if (double.tryParse(val.trim()) == null)
                                return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildDropdown(
                                label: 'Unit',
                                value: _selectedUnit,
                                items: _units,
                                onChanged: (val) =>
                                    setState(() => _selectedUnit = val!),
                              ),
                              TextButton(
                                onPressed: _addNewUnitDialog,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 30),
                                ),
                                child: const Text(
                                  '+ Add Unit',
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildDropdown(
                      label: 'Category',
                      value: _selectedCategory,
                      items: _categories,
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val!),
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _imgCtrl,
                      label: 'Image URL (Optional)',
                      icon: Icons.image_outlined,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 48),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'SAVE ITEM',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        prefixIcon: Icon(icon, color: Colors.orangeAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.orangeAccent),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool isFullWidth = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1F1F3A),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isFullWidth ? 20 : 16,
        ),
      ),
    );
  }
}
