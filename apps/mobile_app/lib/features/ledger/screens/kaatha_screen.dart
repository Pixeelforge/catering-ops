import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_middle_man_dialog.dart';

class KaathaScreen extends StatefulWidget {
  final String companyId;

  const KaathaScreen({super.key, required this.companyId});

  @override
  State<KaathaScreen> createState() => _KaathaScreenState();
}

class _KaathaScreenState extends State<KaathaScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _middleMen = [];

  @override
  void initState() {
    super.initState();
    _fetchMiddleMen();
  }

  Future<void> _fetchMiddleMen() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('kaatha_middle_men_${widget.companyId}');
    
    if (mounted) {
      setState(() {
        if (data != null) {
          final List<dynamic> decoded = jsonDecode(data);
          _middleMen = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMiddleMen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'kaatha_middle_men_${widget.companyId}',
      jsonEncode(_middleMen),
    );
  }

  Future<void> _callMiddleMan(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  void _deleteMiddleMan(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Remove Middle Man', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this person?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _middleMen.removeAt(index);
              });
              _saveMiddleMen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _editMiddleMan(int index) async {
    final updatedData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMiddleManDialog(
        companyId: widget.companyId,
        initialData: _middleMen[index],
      ),
    );

    if (updatedData != null && mounted) {
      setState(() {
        _middleMen[index] = updatedData;
      });
      await _saveMiddleMen();
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
          'Kaatha (Ledger)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _middleMen.isEmpty
              ? _buildEmptyState()
              : _buildMiddleMenList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final addedData = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (context) => AddMiddleManDialog(companyId: widget.companyId),
          );
          if (addedData != null && mounted) {
            setState(() {
              // Add the mocked data to the top of the list
              _middleMen.insert(0, addedData);
            });
            await _saveMiddleMen();
          }
        },
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Middle Man',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: Colors.orangeAccent.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Middle Men Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep track of your middle men by adding them here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleMenList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _middleMen.length,
      itemBuilder: (context, index) {
        final man = _middleMen[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                child: Text(
                  (man['name'] as String?)?[0].toUpperCase() ?? 'M',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      man['name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          man['phone_number'] ?? 'No phone',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.greenAccent),
                    tooltip: 'Call',
                    onPressed: () {
                      if (man['phone_number'] != null) {
                        _callMiddleMan(man['phone_number']);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                    tooltip: 'Edit',
                    onPressed: () => _editMiddleMan(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Remove',
                    onPressed: () => _deleteMiddleMan(index),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
