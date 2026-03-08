import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'add_middle_man_dialog.dart';

class KaathaScreen extends StatefulWidget {
  final String companyId;

  const KaathaScreen({super.key, required this.companyId});

  @override
  State<KaathaScreen> createState() => _KaathaScreenState();
}

class _KaathaScreenState extends State<KaathaScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _middleMen = [];
  RealtimeChannel? _subscription;
  int? _expandedIndex;

  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _fetchMiddleMen();
    _setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    _subscription = _supabase
        .channel('public:middle_men')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'middle_men',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: widget.companyId,
          ),
          callback: (payload) {
            _fetchMiddleMen();
          },
        )
        .subscribe();
  }

  Future<void> _fetchMiddleMen() async {
    try {
      final data = await _supabase
          .from('middle_men')
          .select()
          .eq('company_id', widget.companyId)
          .order('name');

      if (mounted) {
        setState(() {
          _middleMen = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching middle men: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text(
          'Remove Middle Man',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove this person?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Get man info before deletion for order revert
                final manName = _middleMen[index]['name'];
                final manPhone = _middleMen[index]['phone_number'];
                final manId = _middleMen[index]['id'];
                final middlemanTag = '$manName ($manPhone)';

                // 1. Delete the middle man
                await _supabase.from('middle_men').delete().eq('id', manId);

                // 2. Revert orders that were saved for this middleman
                await _supabase
                    .from('orders')
                    .update({'is_khata_saved': false})
                    .eq('middleman_tag', middlemanTag)
                    .eq('company_id', widget.companyId);

                // 3. Local refresh
                _fetchMiddleMen();
              } catch (e) {
                debugPrint('Error deleting: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMiddleManSilently(int index) async {
    try {
      final manId = _middleMen[index]['id'];
      final manName = _middleMen[index]['name'];
      final manPhone = _middleMen[index]['phone_number'];
      final middlemanTag = '$manName ($manPhone)';

      // 1. Delete the middle man
      await _supabase.from('middle_men').delete().eq('id', manId);

      // 2. Revert orders
      await _supabase
          .from('orders')
          .update({'is_khata_saved': false})
          .eq('middleman_tag', middlemanTag)
          .eq('company_id', widget.companyId);

      // 3. UI Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$manName removed from Khata'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error silent deleting: $e');
    }
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
      try {
        final oldName = _middleMen[index]['name'];
        final oldPhone = _middleMen[index]['phone_number'];
        final oldTag = '$oldName ($oldPhone)';

        final newName = updatedData['name'];
        final newPhone = updatedData['phone_number'];
        final newTag = '$newName ($newPhone)';

        // 1. Update the middle man
        await _supabase
            .from('middle_men')
            .update({
              'name': newName,
              'phone_number': newPhone,
              'total_balance': updatedData['total_balance'],
            })
            .eq('id', _middleMen[index]['id']);

        // 2. Update orders with the new tag if the tag changed
        if (oldTag != newTag) {
          await _supabase
              .from('orders')
              .update({'middleman_tag': newTag})
              .eq('middleman_tag', oldTag)
              .eq('company_id', widget.companyId);
        }

        // Manual refresh
        _fetchMiddleMen();
      } catch (e) {
        debugPrint('Error updating: $e');
      }
    }
  }

  Future<void> _recordPayment(int index) async {
    final man = _middleMen[index];
    final controller = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'Record Payment from ${man['name']}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current Collector Amount: ₹${(man['total_balance'] as num).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount Paid (₹)',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
            ),
            child: const Text(
              'Confirm Payment',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0 && mounted) {
      final currentBalance = (man['total_balance'] as num).toDouble();
      if (amount > currentBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Payment amount cannot be more than the Balance!',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      try {
        final newBalance = currentBalance - amount;
        await _supabase
            .from('middle_men')
            .update({'total_balance': newBalance})
            .eq('id', man['id']);

        if (mounted) {
          _fetchMiddleMen(); // Instant refresh

          if (newBalance == 0) {
            _confettiController.play();
            _audioPlayer.play(
              UrlSource(
                'https://assets.mixkit.co/active_storage/sfx/2013/2013-preview.mp3',
              ),
            );

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Column(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.orangeAccent,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'CONGRATULATIONS!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'Full payment received from ${man['name']}! Your Khata is now clear for this collector.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'GREAT!',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment of ₹$amount recorded. New balance: ₹${newBalance.toStringAsFixed(2)}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error recording payment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              'Kaatha (Ledger)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.orangeAccent),
                )
              : _middleMen.isEmpty
              ? _buildEmptyState()
              : _buildMiddleMenList(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final addedData = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) =>
                    AddMiddleManDialog(companyId: widget.companyId),
              );
              if (addedData != null && mounted) {
                try {
                  await _supabase.from('middle_men').insert({
                    'company_id': widget.companyId,
                    'name': addedData['name'],
                    'phone_number': addedData['phone_number'],
                    'total_balance': addedData['total_balance'] ?? 0.0,
                  });
                } catch (e) {
                  debugPrint('Error adding: $e');
                }
              }
            },
            backgroundColor: Colors.orangeAccent,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Middle Man',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
            createParticlePath: _drawStar,
          ),
        ),
      ],
    );
  }

  Path _drawStar(Size size) {
    // Method to draw a star shape for confetti particles
    double degToRad(double deg) => deg * (math.pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * math.cos(step),
        halfWidth + externalRadius * math.sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * math.sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
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
        final isExpanded = _expandedIndex == index;

        return Dismissible(
          key: Key(man['id'].toString()),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                title: const Text(
                  'Delete Middle Man',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Are you sure you want to delete this person?',
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
          onDismissed: (direction) {
            _deleteMiddleManSilently(index);
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 32),
          ),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
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
                  // Header Row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                        child: Text(
                          (man['name'] as String?)?[0].toUpperCase() ?? 'M',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
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
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              man['phone_number'] ?? 'No phone',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Balance Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'AMOUNT TO COLLECT:',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${(man['total_balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expandable Section
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        // PRIMARY ACTION
                        ElevatedButton.icon(
                          onPressed: () => _recordPayment(index),
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.black,
                          ),
                          label: const Text(
                            'RECEIVED PAYMENT (CASH)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // SECONDARY ACTIONS
                        OutlinedButton.icon(
                          onPressed: () {
                            if (man['phone_number'] != null) {
                              _callMiddleMan(man['phone_number']);
                            }
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('CALL NOW'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // MINOR ACTIONS
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _editMiddleMan(index),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('EDIT'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orangeAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _deleteMiddleMan(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text('DELETE'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
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
      },
    );
  }
}
