import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BidsScreen extends StatefulWidget {
  final String orderId;
  final String clientName;
  final double baseFare;
  final DateTime? biddingEndsAt;

  const BidsScreen({
    super.key,
    required this.orderId,
    required this.clientName,
    required this.baseFare,
    this.biddingEndsAt,
  });

  @override
  State<BidsScreen> createState() => _BidsScreenState();
}

class _BidsScreenState extends State<BidsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _bids = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchBids();
    _setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchBids() async {
    try {
      final data = await _supabase
          .from('delivery_bids')
          .select('id, bid_amount, staff_id, created_at, profiles(full_name)')
          .eq('order_id', widget.orderId)
          .order('bid_amount', ascending: true);
      if (mounted) {
        setState(() {
          _bids = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtime() {
    _subscription = _supabase
        .channel('bids_screen_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_bids',
          callback: (payload) {
            final orderId = (payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord)['order_id'];
            if (orderId == widget.orderId) _fetchBids();
          },
        )
        .subscribe();
  }

  String _timeLeft() {
    if (widget.biddingEndsAt == null) return '';
    final now = DateTime.now();
    if (now.isAfter(widget.biddingEndsAt!)) return 'Auction Ended';
    final diff = widget.biddingEndsAt!.difference(now);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s remaining';
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s remaining';
  }

  @override
  Widget build(BuildContext context) {
    final auctionEnded =
        widget.biddingEndsAt != null &&
        DateTime.now().isAfter(widget.biddingEndsAt!);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Bids',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.clientName,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          if (widget.biddingEndsAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: StatefulBuilder(
                builder: (context, setTimer) {
                  // Refresh countdown every second
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) setTimer(() {});
                  });
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: auctionEnded
                          ? Colors.white10
                          : Colors.deepPurple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: auctionEnded
                            ? Colors.white24
                            : Colors.purpleAccent.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      _timeLeft(),
                      style: TextStyle(
                        color: auctionEnded
                            ? Colors.white38
                            : Colors.purpleAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _fetchBids,
          ),
        ],
      ),
      body: Column(
        children: [
          // Base Fare Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.3),
                  Colors.purple.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gavel,
                      color: Colors.purpleAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Base Fare:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  '₹${widget.baseFare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bids Count Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _isLoading
                      ? 'Loading bids...'
                      : _bids.isEmpty
                      ? 'No bids yet'
                      : '${_bids.length} bid${_bids.length > 1 ? 's' : ''} placed',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_bids.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Lowest: ₹${(_bids.first['bid_amount'] as num).toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Bids List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.purpleAccent,
                    ),
                  )
                : _bids.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.no_accounts_outlined,
                          size: 64,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bids yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Staff members will appear here when they bid',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _bids.length,
                    itemBuilder: (context, index) {
                      final bid = _bids[index];
                      final profile = bid['profiles'];
                      final name =
                          (profile is Map ? profile['full_name'] : null) ??
                          'Unknown';
                      final amount = (bid['bid_amount'] as num).toDouble();
                      final isWinning = index == 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isWinning
                                ? [
                                    Colors.amber.withOpacity(0.15),
                                    Colors.amber.withOpacity(0.05),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.05),
                                    Colors.white.withOpacity(0.02),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isWinning
                                ? Colors.amber.withOpacity(0.5)
                                : Colors.white10,
                            width: isWinning ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Rank
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isWinning
                                    ? Colors.amber.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isWinning
                                    ? const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 20,
                                      )
                                    : Text(
                                        '#${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: isWinning
                                          ? Colors.amber
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (isWinning)
                                    const Text(
                                      '🏆 Lowest Bid',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Amount
                            Text(
                              '₹${amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isWinning
                                    ? Colors.greenAccent
                                    : Colors.white70,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
