import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'add_card_sheet.dart';
import 'booking_confirmed_screen.dart';

class PaymentScreen extends StatefulWidget {
  // The booking that needs a deposit
  final String bookingId;

  const PaymentScreen({super.key, required this.bookingId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const int _depositAmount = 500;
  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final _db = FirebaseFirestore.instance;
  String _method = 'card';
  String? _selectedCardId;
  bool _isPaying = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // The saved cards of this user
  CollectionReference<Map<String, dynamic>> get _cards =>
      _db.collection('users').doc(_uid).collection('cards');

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // e.g. "Today, 29 Sep" or "Sat, 3 Oct"
  String _dateText(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final day = isToday ? 'Today' : _weekdays[d.weekday - 1];
    return '$day, ${d.day} ${_shortMonths[d.month - 1]}';
  }

  // e.g. "7:30 PM"
  String _timeText(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _methodName(String method) {
    if (method == 'payhere') return 'PayHere';
    if (method == 'cash') return 'Cash on arrival';
    return 'Card';
  }

  // "The Gallery Café" becomes "GC"
  String _initials(String name) {
    final words = name
        .split(' ')
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'the')
        .take(2);
    return words.map((w) => w[0].toUpperCase()).join();
  }

  // Opens the Add card sheet
  Future<void> _addCard() async {
    final newId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddCardSheet(),
    );
    if (newId != null && mounted) {
      setState(() => _selectedCardId = newId);
      _showMessage('Card added');
    }
  }

  // Removes a saved card after asking first
  Future<void> _deleteCard(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this card?'),
        content: const Text('You can add it again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // DELETE: remove the saved card
      await _cards.doc(id).delete();
      if (!mounted) return;
      if (_selectedCardId == id) setState(() => _selectedCardId = null);
      _showMessage('Card removed');
    } catch (e) {
      debugPrint('CARD DELETE ERROR: $e');
      _showMessage('Could not remove the card.');
    }
  }

  // Simulated payment: no real money is charged
  Future<void> _pay(Map<String, dynamic> booking) async {
    if (_method == 'card' && _selectedCardId == null) {
      _showMessage('Please add or choose a card first.');
      return;
    }

    setState(() => _isPaying = true);

    try {
      // Short wait so it feels like a real payment
      await Future.delayed(const Duration(milliseconds: 1500));

      final bool payLater = _method == 'cash';

      // READ: get the chosen card's short label, e.g. "VISA •••• 4242"
      String cardLabel = '';
      if (_method == 'card') {
        final card = await _cards.doc(_selectedCardId).get();
        final data = card.data();
        if (data != null) cardLabel = '${data['brand']} •••• ${data['last4']}';
      }

      // CREATE: save a payment record
      final payment = await _db.collection('payments').add({
        'userId': _uid,
        'bookingId': widget.bookingId,
        'restaurantName': booking['restaurantName'] ?? '',
        'amount': _depositAmount,
        'method': _method,
        'cardLabel': cardLabel,
        'status': payLater ? 'pay_at_restaurant' : 'paid',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // UPDATE: mark the booking as confirmed
      await _db.collection('bookings').doc(widget.bookingId).update({
        'status': 'confirmed',
        'paymentStatus': payLater ? 'pay_at_restaurant' : 'paid',
        'paymentId': payment.id,
      });

      if (!mounted) return;
      // Show the full Booking Confirmed screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BookingConfirmedScreen(bookingId: widget.bookingId),
        ),
      );
    } catch (e) {
      debugPrint('PAYMENT ERROR: $e');
      _showMessage('Payment failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _showSuccessDialog(bool payLater) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              payLater ? 'Booking confirmed!' : 'Payment successful!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              payLater
                  ? 'Please pay Rs. $_depositAmount at the host desk when you arrive.'
                  : 'Rs. $_depositAmount deposit paid. Your table is confirmed.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  'assets/images/logo_icon.png',
                  errorBuilder: (context, error, stack) => const Icon(
                    Icons.table_restaurant,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),

      // READ (live): the booking that is being paid for
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('bookings').doc(widget.bookingId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _centerText('Could not load this booking.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final booking = snapshot.data!.data();
          if (booking == null) {
            return _centerText('This booking was not found.');
          }

          final paymentStatus = (booking['paymentStatus'] ?? '').toString();
          final bool alreadyPaid =
              paymentStatus == 'paid' || paymentStatus == 'pay_at_restaurant';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _summaryCard(booking),
              const SizedBox(height: 22),

              _sectionTitle('SELECT PAYMENT METHOD'),
              const SizedBox(height: 10),
              _methodCard(
                'card',
                Icons.credit_card,
                'Credit / Debit Card',
                'Visa, Mastercard, Amex',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _smallBadge('VISA', AppColors.textDark),
                    const SizedBox(width: 4),
                    _smallBadge('MC', AppColors.textDark),
                  ],
                ),
              ),

              // Saved cards and "Add new card" (only for the card option)
              if (_method == 'card') ...[
                const SizedBox(height: 8),
                _savedCards(),
              ],
              const SizedBox(height: 10),

              _methodCard(
                'payhere',
                Icons.account_balance_wallet_outlined,
                'PayHere',
                'Online banking & Sri Lankan mobile wallets',
                trailing: _smallBadge('Instant', AppColors.success),
              ),
              const SizedBox(height: 10),
              _methodCard(
                'cash',
                Icons.payments_outlined,
                'Cash on arrival',
                'Pay Rs. $_depositAmount at the restaurant host desk',
              ),
              const SizedBox(height: 20),

              // Pay button
              ElevatedButton(
                onPressed: (_isPaying || alreadyPaid)
                    ? null
                    : () => _pay(booking),
                child: _isPaying
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      alreadyPaid
                          ? 'Already paid'
                          : _method == 'cash'
                          ? 'Confirm Booking'
                          : 'Pay Now · Rs. $_depositAmount',
                    ),
                    if (!alreadyPaid) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.textGrey),
                  SizedBox(width: 4),
                  Text(
                    'Demo payment – no real money is charged',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              _historySection(),
            ],
          );
        },
      ),
    );
  }

  // READ (live): cards this user has saved, with an "Add new card" button
  Widget _savedCards() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cards.snapshots(),
      builder: (context, snapshot) {
        final cards = snapshot.data?.docs ?? [];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'No saved cards yet.',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ),
              ...cards.map((doc) => _savedCardTile(doc.id, doc.data())),
              TextButton.icon(
                onPressed: _addCard,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add new card'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // One saved card, e.g. "VISA •••• 4242"
  Widget _savedCardTile(String id, Map<String, dynamic> card) {
    final bool selected = _selectedCardId == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedCardId = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.primary : AppColors.border,
            ),
            const SizedBox(width: 10),
            _smallBadge((card['brand'] ?? '').toString(), AppColors.textDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•••• ${card['last4'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '${card['holderName'] ?? ''} · Exp ${card['expiry'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove card',
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
                size: 20,
              ),
              onPressed: () => _deleteCard(id),
            ),
          ],
        ),
      ),
    );
  }

  // Booking details and the deposit amount
  Widget _summaryCard(Map<String, dynamic> booking) {
    final name = (booking['restaurantName'] ?? '').toString();
    final address = (booking['address'] ?? '').toString();
    final time = (booking['bookingTime'] as Timestamp).toDate();
    final guests = ((booking['guests'] ?? 0) as num).toInt();
    final tableType = (booking['tableType'] ?? '').toString();
    final guestText = guests == 6
        ? '6+ People'
        : '$guests ${guests == 1 ? 'Person' : 'People'}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _smallBadge('BOOKING SUMMARY', AppColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _iconText(Icons.calendar_today_outlined, _dateText(time)),
              ),
              Expanded(child: _iconText(Icons.schedule, _timeText(time))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _iconText(
                  Icons.people_outline,
                  '$guestText ($tableType)',
                ),
              ),
              Expanded(
                child: _iconText(
                  Icons.check_circle_outline,
                  'Slot reserved',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Deposit box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.savings_outlined, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deposit: Rs. 500 (refundable)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Taken from your final bill, or refunded if you '
                            'cancel at least 1 hour before.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Rs. 500',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // One payment method option with a radio circle
  Widget _methodCard(
      String value,
      IconData icon,
      String title,
      String subtitle, {
        Widget? trailing,
      }) {
    final bool selected = _method == value;

    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.border,
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.textDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // READ (live): this user's payments, newest first
  Widget _historySection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('payments')
          .where('userId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs.toList() ?? [];

        // Sort here so Firestore does not need an extra index
        docs.sort((a, b) {
          final ta = a.data()['createdAt'] as Timestamp?;
          final tb = b.data()['createdAt'] as Timestamp?;
          if (ta == null) return -1;
          if (tb == null) return 1;
          return tb.compareTo(ta);
        });
        final recent = docs.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _sectionTitle('PAYMENT HISTORY'),
                const Spacer(),
                Text(
                  'Recent ${recent.length} transactions',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (recent.isEmpty)
              const Text(
                'No payments yet.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              )
            else
              ...recent.map((doc) => _historyItem(doc.data())),
          ],
        );
      },
    );
  }

  // One payment in the history list
  Widget _historyItem(Map<String, dynamic> p) {
    final status = (p['status'] ?? '').toString();
    final method = (p['method'] ?? '').toString();
    final cardLabel = (p['cardLabel'] ?? '').toString();
    final amount = ((p['amount'] ?? 0) as num).toInt();
    final created = p['createdAt'] as Timestamp?;
    final dateText = created == null ? 'Just now' : _dateText(created.toDate());
    final methodText = method == 'card' && cardLabel.isNotEmpty
        ? cardLabel
        : _methodName(method);

    Color color = AppColors.success;
    String label = 'Paid';
    IconData icon = Icons.check;
    if (status == 'refunded') {
      color = Colors.blue.shade600;
      label = 'Refunded';
      icon = Icons.replay;
    } else if (status == 'pay_at_restaurant') {
      color = AppColors.warning;
      label = 'Pay at venue';
      icon = Icons.storefront;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (p['restaurantName'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateText · $methodText',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. $amount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              _smallBadge(label, color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconText(
      IconData icon,
      String text, {
        Color color = AppColors.textDark,
      }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color == AppColors.textDark ? AppColors.textGrey : color,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 12.5, color: color)),
        ),
      ],
    );
  }

  Widget _smallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Color(0xFF555555),
      ),
    );
  }

  Widget _centerText(String text) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.textGrey)),
    );
  }
}