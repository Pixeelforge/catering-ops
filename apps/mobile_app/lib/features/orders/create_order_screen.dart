import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/notification_service.dart';

class CreateOrderScreen extends StatefulWidget {
  final String companyId;

  const CreateOrderScreen({super.key, required this.companyId});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Form Fields
  final _clientNameController = TextEditingController();
  final _venueAddressController = TextEditingController();
  final _totalController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String _paymentStatus = 'pending';
  String _orderType = 'direct'; // 'direct' or 'middleman'

  // Middleman dropdown
  List<Map<String, dynamic>> _middleMen = [];
  Map<String, dynamic>? _selectedMiddleMan;

  // Menu Item Selection
  List<Map<String, dynamic>> _availableMenuItems = [];
  final List<Map<String, dynamic>> _selectedItems = [];
  List<String> _units = ['kgs', 'litres', 'boxes', 'units'];

  bool _isLoading = false;
  bool _isFetchingMenu = true;

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
    _fetchUnits();
    _fetchMiddleMen();
  }

  Future<void> _fetchMiddleMen() async {
    try {
      final data = await _supabase
          .from('middle_men')
          .select('id, name, phone_number, total_balance')
          .eq('company_id', widget.companyId)
          .order('name');
      if (mounted) {
        setState(() {
          _middleMen = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching middle men: $e');
    }
  }

  Future<void> _fetchUnits() async {
    try {
      final data = await _supabase
          .from('inventory_units')
          .select('name')
          .eq('company_id', widget.companyId);
      final dbUnits = (data as List).map((e) => e['name'] as String).toList();
      setState(() {
        _units = {
          ...['kgs', 'litres', 'boxes', 'units'],
          ...dbUnits,
        }.toList();
      });
    } catch (e) {
      debugPrint('Error fetching units: $e');
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _venueAddressController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _fetchMenuItems() async {
    try {
      final data = await _supabase
          .from('inventory_items')
          .select('id, name, category')
          .eq('company_id', widget.companyId)
          .order('name');

      if (mounted) {
        setState(() {
          _availableMenuItems = List<Map<String, dynamic>>.from(data);
          _isFetchingMenu = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      if (mounted) setState(() => _isFetchingMenu = false);
    }
  }

  Future<void> _pickDateAndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orangeAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.orangeAccent,
                onPrimary: Colors.black,
                surface: Color(0xFF1E1E2C),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
      if (time != null) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
        });
      }
    }
  }

  Future<void> _showQuickAddItemDialog(
    Function(void Function()) setSheetState,
  ) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    String selectedCategory = 'Produce';
    String selectedUnit = 'kgs';

    final categories = [
      'Produce',
      'Meat & Poultry',
      'Dairy',
      'Dry Goods',
      'Beverages',
      'Equipment',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text(
            'Quick Add Item',
            style: TextStyle(color: Colors.white),
          ),
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
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Initial Quantity',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: const Color(0xFF1E1E2C),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedCategory = val!),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  dropdownColor: const Color(0xFF1E1E2C),
                  items: _units
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedUnit = val!),
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                try {
                  final newItem = await _supabase
                      .from('inventory_items')
                      .insert({
                        'company_id': widget.companyId,
                        'name': nameCtrl.text.trim(),
                        'category': selectedCategory,
                        'quantity': double.tryParse(qtyCtrl.text) ?? 0,
                        'unit': selectedUnit,
                      })
                      .select()
                      .single();

                  setState(() {
                    _availableMenuItems.add(newItem);
                    _availableMenuItems.sort(
                      (a, b) => a['name'].compareTo(b['name']),
                    );
                    _selectedItems.add({
                      'id': newItem['id'],
                      'name': newItem['name'],
                      'quantity': 1,
                      'quantity_type': 'fixed',
                    });
                  });
                  setSheetState(() {});
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint('Error quick adding item: $e');
                }
              },
              child: const Text('Save & Select'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMiddleManDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add New Middleman',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  if (kIsWeb) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Contact import is only available on mobile devices.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  try {
                    bool permissionGranted =
                        await Permission.contacts.isGranted;
                    if (!permissionGranted) {
                      permissionGranted = await Permission.contacts
                          .request()
                          .isGranted;
                    }

                    if (permissionGranted) {
                      final Contact? contact =
                          await FlutterContacts.openExternalPick();
                      if (contact != null) {
                        final fullContact = await FlutterContacts.getContact(
                          contact.id,
                        );
                        if (fullContact != null) {
                          setDialogState(() {
                            nameCtrl.text = fullContact.displayName;
                            if (fullContact.phones.isNotEmpty) {
                              // Sanitize phone number (remove spaces, etc.)
                              String phone = fullContact.phones.first.number;
                              phoneCtrl.text = phone.replaceAll(
                                RegExp(r'\s+'),
                                '',
                              );
                            }
                          });
                        }
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Contact permission denied. Please enable it in settings.',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('Error picking contact: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not import contact: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.contact_phone, size: 18),
                label: const Text('Import from Contacts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                  foregroundColor: Colors.orangeAccent,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Middleman Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Colors.orangeAccent,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orangeAccent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.phone,
                    color: Colors.orangeAccent,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orangeAccent),
                  ),
                ),
              ),
            ],
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
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        final res = await _supabase
                            .from('middle_men')
                            .insert({
                              'company_id': widget.companyId,
                              'name': nameCtrl.text.trim(),
                              'phone_number': phoneCtrl.text.trim(),
                              'total_balance': 0,
                            })
                            .select()
                            .single();

                        if (mounted) {
                          setState(() {
                            // Local update for instant feedback
                            final man = Map<String, dynamic>.from(res);
                            _middleMen.add(man);
                            _middleMen.sort(
                              (a, b) => (a['name'] as String).compareTo(
                                b['name'] as String,
                              ),
                            );
                            _selectedMiddleMan = man;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Middleman added successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error adding middleman: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (mounted) setDialogState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Save & Select'),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Menu Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showQuickAddItemDialog(setSheetState),
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.orangeAccent,
                          ),
                          label: const Text(
                            'Create New',
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: _availableMenuItems.isEmpty
                          ? const Center(
                              child: Text(
                                "No items configured yet.",
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _availableMenuItems.length,
                              itemBuilder: (context, index) {
                                final item = _availableMenuItems[index];
                                final isSelected = _selectedItems.any(
                                  (e) => e['id'] == item['id'],
                                );

                                return ListTile(
                                  title: Text(
                                    item['name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.orangeAccent,
                                        )
                                      : const Icon(
                                          Icons.circle_outlined,
                                          color: Colors.white24,
                                        ),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedItems.removeWhere(
                                          (e) => e['id'] == item['id'],
                                        );
                                      } else {
                                        _selectedItems.add({
                                          'id': item['id'],
                                          'name': item['name'],
                                          'quantity': 1,
                                          'quantity_type': 'fixed',
                                        });
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orangeAccent),
      );
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      _toast('Please select an Event Date & Time');
      return;
    }
    if (_selectedItems.isEmpty) {
      _toast('Please select at least one Menu Item');
      return;
    }
    if (_orderType == 'middleman' && _selectedMiddleMan == null) {
      _toast('Please select a middleman');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      ).toUtc().toIso8601String();

      final totalValue = double.tryParse(_totalController.text) ?? 0.0;

      final menuItemsJson = _selectedItems
          .map(
            (item) => {
              'name': item['name'],
              'quantity': item['quantity'],
              'quantity_type': item['quantity_type'] ?? 'fixed',
            },
          )
          .toList();

      String? middlemanTag;
      if (_orderType == 'middleman' && _selectedMiddleMan != null) {
        final name = _selectedMiddleMan?['name'] ?? 'Unknown';
        final phone = _selectedMiddleMan?['phone_number'] ?? '';
        middlemanTag = '$name ($phone)';
      }

      await _supabase.from('orders').insert({
        'company_id': widget.companyId,
        'client_name': _clientNameController.text.trim(),
        'venue_address': _venueAddressController.text.trim(),
        'event_date': eventDateTime,
        'menu_items': menuItemsJson,
        'middleman_tag': middlemanTag,
        'total_value': totalValue,
        'payment_status': _paymentStatus,
        'order_status': 'upcoming',
        'is_khata_saved': _orderType == 'middleman' && _selectedMiddleMan != null,
      });

      // 🔹 Schedule Multi-Tier Reminder Notifications
      try {
        final eventDate = DateTime.parse(eventDateTime);
        final now = DateTime.now().toUtc();
        final user = _supabase.auth.currentUser;
        
        if (user != null) {
          final clientName = _clientNameController.text.trim();
          final formattedTime = DateFormat('h:mm a').format(eventDate.toLocal());

          // 1. Standard Reminder (6 hours before)
          final reminder6h = eventDate.subtract(const Duration(hours: 6));
          if (reminder6h.isAfter(now)) {
            NotificationService.sendNotification(
              playerIds: [user.id], // Owner/Creator
              title: 'Catering Ops: Upcoming Order! ⏰',
              message: 'Reminder: Order for $clientName is scheduled for $formattedTime.',
              data: {'type': 'order_reminder'},
              color: 'FFFF9800', // Orange
              sendAfter: reminder6h,
            );
          }

          // 2. Emergency Reminder (2 hours before)
          final reminder2h = eventDate.subtract(const Duration(hours: 2));
          if (reminder2h.isAfter(now)) {
            NotificationService.sendNotification(
              playerIds: [user.id],
              title: '🚨 EMERGENCY: Order Starting Soon! 🚨',
              message: 'URGENT: Order for $clientName starts in 2 hours ($formattedTime)!',
              data: {'type': 'order_reminder'},
              color: 'FFF44336', // Red
              sendAfter: reminder2h,
            );
          }
        }
      } catch (e) {
        debugPrint('Error scheduling reminders: $e');
      }

      // Auto-save to Khata if middleman order is pending payment
      if (_orderType == 'middleman' &&
          _selectedMiddleMan != null &&
          _paymentStatus == 'pending') {
        final manId = _selectedMiddleMan?['id'];
        final currentBalance =
            (_selectedMiddleMan?['total_balance'] as num?)?.toDouble() ?? 0.0;
        if (manId != null) {
          await _supabase
              .from('middle_men')
              .update({'total_balance': currentBalance + totalValue})
              .eq('id', manId);
        }
      }

      _toast('Order created successfully!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('Error creating order: $e');
      setState(() => _isLoading = false);
    }
  }

  String get _formattedDateTime {
    if (_selectedDate == null || _selectedTime == null)
      return 'Select Date & Time';
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    return DateFormat('MMM dd, yyyy - h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161626),
      appBar: AppBar(
        title: const Text(
          'Create Order',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isFetchingMenu
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Client Name
                  TextFormField(
                    controller: _clientNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Client / Event Name',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Colors.orangeAccent,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Client name is required'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Venue Address
                  TextFormField(
                    controller: _venueAddressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Venue Address (for Maps)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: Colors.orangeAccent,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date & Time Picker
                  InkWell(
                    onTap: _pickDateAndTime,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Event Date & Time',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formattedDateTime,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white24,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Menu Items Section
                  // Menu Items Section header
                  const Text(
                    'Menu Items',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Big tap target to select items
                  if (_selectedItems.isEmpty)
                    GestureDetector(
                      onTap: _showItemSelectorBottomSheet,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              color: Colors.orangeAccent,
                              size: 36,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap to Select Menu Items',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Choose from your inventory',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orangeAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: _selectedItems.map((item) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.restaurant_menu,
                                          color: Colors.orangeAccent,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item['name'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white24,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(
                                            () => _selectedItems.removeWhere(
                                              (e) => e['id'] == item['id'],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // Toggle
                                        ToggleButtons(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          isSelected: [
                                            (item['quantity_type'] ??
                                                    'fixed') ==
                                                'fixed',
                                            (item['quantity_type'] ??
                                                    'fixed') ==
                                                'persons',
                                          ],
                                          onPressed: (idx) {
                                            setState(() {
                                              item['quantity_type'] = idx == 0
                                                  ? 'fixed'
                                                  : 'persons';
                                            });
                                          },
                                          fillColor: Colors.orangeAccent.withOpacity(0.2),
                                          selectedColor: Colors.orangeAccent,
                                          color: Colors.white38,
                                          constraints: const BoxConstraints(
                                            minHeight: 32,
                                            minWidth: 60,
                                          ),
                                          children: const [
                                            Text(
                                              'Qty',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              'Persons',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        // Text Input for Value
                                        Expanded(
                                          child: SizedBox(
                                            height: 40,
                                            child: TextFormField(
                                              initialValue: item['quantity']
                                                  .toString(),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Enter amount...',
                                                hintStyle: const TextStyle(
                                                  color: Colors.white24,
                                                  fontSize: 12,
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 0,
                                                    ),
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.05),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                              onChanged: (val) {
                                                final numVal =
                                                    double.tryParse(val) ?? 0;
                                                setState(
                                                  () =>
                                                      item['quantity'] = numVal,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showItemSelectorBottomSheet,
                            icon: const Icon(
                              Icons.add,
                              color: Colors.orangeAccent,
                              size: 16,
                            ),
                            label: const Text(
                              'Add More Items',
                              style: TextStyle(color: Colors.orangeAccent),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.orangeAccent,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Order Type — Direct or Middleman segmented bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Type',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            // Direct Customer
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _orderType = 'direct'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _orderType == 'direct'
                                        ? Colors.orangeAccent.withOpacity(0.18)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(13),
                                    ),
                                    border: _orderType == 'direct'
                                        ? Border.all(
                                            color: Colors.orangeAccent,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: _orderType == 'direct'
                                            ? Colors.orangeAccent
                                            : Colors.white24,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Direct Customer',
                                          style: TextStyle(
                                            color: _orderType == 'direct'
                                                ? Colors.orangeAccent
                                                : Colors.white38,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Middleman
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _orderType = 'middleman'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _orderType == 'middleman'
                                        ? const Color(
                                            0xFFD4A237,
                                          ).withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(13),
                                    ),
                                    border: _orderType == 'middleman'
                                        ? Border.all(
                                            color: const Color(0xFFD4A237),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people,
                                        color: _orderType == 'middleman'
                                            ? const Color(0xFFD4A237)
                                            : Colors.white24,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Middleman',
                                          style: TextStyle(
                                            color: _orderType == 'middleman'
                                                ? const Color(0xFFD4A237)
                                                : Colors.white38,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Middleman fields — only shown when Middleman is selected
                  if (_orderType == 'middleman') ...[
                    _middleMen.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'No middlemen added yet.',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _showAddMiddleManDialog,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text(
                                      'Add Your First Middleman',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child:
                                    DropdownButtonFormField<
                                      Map<String, dynamic>
                                    >(
                                      dropdownColor: const Color(0xFF1A1A2E),
                                      value: _selectedMiddleMan,
                                      hint: const Text(
                                        'Select Middleman',
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                      items: _middleMen.map((man) {
                                        return DropdownMenuItem(
                                          value: man,
                                          child: Text(
                                            '${man['name']} (${man['phone_number']})',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(
                                        () => _selectedMiddleMan = val,
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFFD4A237),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFD4A237),
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFD4A237),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      validator: (_) =>
                                          _orderType == 'middleman' &&
                                              _selectedMiddleMan == null
                                          ? 'Please select a middleman'
                                          : null,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _showAddMiddleManDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFFD4A237,
                                    ).withOpacity(0.1),
                                    foregroundColor: const Color(0xFFD4A237),
                                    elevation: 0,
                                    side: const BorderSide(
                                      color: Color(0xFFD4A237),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Icon(Icons.add),
                                ),
                              ),
                            ],
                          ),
                    if (_selectedMiddleMan != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Khata: ₹${(_selectedMiddleMan?['total_balance'] as num?)?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_paymentStatus == 'pending' &&
                        _selectedMiddleMan != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.greenAccent,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Will auto-add to Khata (pending payment)',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),

                  // Total Value
                  TextFormField(
                    controller: _totalController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total Order Value',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Total is required' : null,
                  ),
                  const SizedBox(height: 24),

                  // Payment Status — segmented bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Status',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            // PAID option
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _paymentStatus = 'paid'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _paymentStatus == 'paid'
                                        ? Colors.greenAccent.withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(13),
                                    ),
                                    border: _paymentStatus == 'paid'
                                        ? Border.all(
                                            color: Colors.greenAccent,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: _paymentStatus == 'paid'
                                            ? Colors.greenAccent
                                            : Colors.white24,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Paid',
                                        style: TextStyle(
                                          color: _paymentStatus == 'paid'
                                              ? Colors.greenAccent
                                              : Colors.white38,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // PENDING option
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _paymentStatus = 'pending'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _paymentStatus == 'pending'
                                        ? Colors.orangeAccent.withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(13),
                                    ),
                                    border: _paymentStatus == 'pending'
                                        ? Border.all(
                                            color: Colors.orangeAccent,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.pending_actions,
                                        color: _paymentStatus == 'pending'
                                            ? Colors.orangeAccent
                                            : Colors.white24,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Pending',
                                        style: TextStyle(
                                          color: _paymentStatus == 'pending'
                                              ? Colors.orangeAccent
                                              : Colors.white38,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submitOrder,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'Create Order',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
