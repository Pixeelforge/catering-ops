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
    'Other'
  ];

  String _selectedUnit = 'kg';
  final List<String> _units = ['kg', 'lbs', 'liters', 'gallons', 'units', 'boxes'];

  bool _isSubmitting = false;

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
      body: SingleChildScrollView(
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
                  if (val == null || val.trim().isEmpty) return 'Item name is required';
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (double.tryParse(val.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildDropdown(
                      label: 'Unit',
                      value: _selectedUnit,
                      items: _units,
                      onChanged: (val) => setState(() => _selectedUnit = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildDropdown(
                label: 'Category',
                value: _selectedCategory,
                items: _categories,
                onChanged: (val) => setState(() => _selectedCategory = val!),
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
                      ? const CircularProgressIndicator(color: Colors.white)
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
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
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
