import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'payment_screen.dart';

class BookTableScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String address;
  final String cuisine;

  const BookTableScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.address,
    required this.cuisine,
  });

  @override
  State<BookTableScreen> createState() => _BookTableScreenState();
}

class _BookTableScreenState extends State<BookTableScreen> {
  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Dinner time slots as [hour, minute] in 24-hour time
  static const List<List<int>> _slots = [
    [19, 0], [19, 30], [20, 0], [20, 30],
    [21, 0], [21, 30], [22, 0], [22, 30],
  ];

  late final List<DateTime> _dates;
  int _dateIndex = 0;
  List<int>? _selectedSlot;
  int _guests = 2;
  String _tableType = 'Indoor';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // The next 7 days, starting from today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dates = List.generate(7, (i) => today.add(Duration(days: i)));
    _selectedSlot = _firstFreeSlot();
  }

  DateTime get _selectedDate => _dates[_dateIndex];

  // Full date and time of a slot on the selected day
  DateTime _slotTime(List<int> slot) {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slot[0],
      slot[1],
    );
  }

  // A slot is closed if it has passed or is less than 30 minutes away
  bool _isPast(List<int> slot) {
    return _slotTime(
      slot,
    ).isBefore(DateTime.now().add(const Duration(minutes: 30)));
  }

  List<int>? _firstFreeSlot() {
    for (final slot in _slots) {
      if (!_isPast(slot)) return slot;
    }
    return null;
  }

  bool get _isWeekend =>
      _selectedDate.weekday == DateTime.saturday ||
          _selectedDate.weekday == DateTime.sunday;

  // Turns [19, 30] into "7:30 PM"
  String _timeText(List<int> slot) {
    final hour = slot[0] > 12 ? slot[0] - 12 : slot[0];
    final minute = slot[1].toString().padLeft(2, '0');
    final period = slot[0] >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get _guestText {
    if (_guests == 6) return '6+ Guests';
    return '$_guests ${_guests == 1 ? 'Guest' : 'Guests'}';
  }

  // e.g. "Today, 29 Sep • 7:30 PM • 2 Guests"
  String get _summaryText {
    final d = _selectedDate;
    final dayName = _dateIndex == 0 ? 'Today' : _weekdays[d.weekday - 1];
    final time = _selectedSlot == null
        ? 'Choose a time'
        : _timeText(_selectedSlot!);
    return '$dayName, ${d.day} ${_shortMonths[d.month - 1]} • $time • $_guestText';
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Saves the booking in Firestore
  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) {
      _showMessage('Please choose a time slot.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please log in again.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bookingTime = _slotTime(_selectedSlot!);
      final bookings = FirebaseFirestore.instance.collection('bookings');

      // Stop double booking: same user, same restaurant, same time
      final existing = await bookings
          .where('userId', isEqualTo: user.uid)
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .where('bookingTime', isEqualTo: Timestamp.fromDate(bookingTime))
          .get();
      final alreadyBooked = existing.docs.any(
            (doc) => doc.data()['status'] != 'cancelled',
      );
      if (alreadyBooked) {
        _showMessage('You already have a booking here at this time.');
        return;
      }

      // CREATE: save the new booking in the "bookings" collection.
      // Weekend bookings wait for the deposit before they are confirmed.
      final newBooking = await bookings.add({
        'userId': user.uid,
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'address': widget.address,
        'bookingTime': Timestamp.fromDate(bookingTime),
        'guests': _guests,
        'tableType': _tableType,
        'depositRequired': _isWeekend,
        'depositAmount': _isWeekend ? 500 : 0,
        'status': _isWeekend ? 'pending_payment' : 'confirmed',
        'paymentStatus': _isWeekend ? 'unpaid' : 'not_required',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      if (_isWeekend) {
        // Weekend: go to the Payment screen instead
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(bookingId: newBooking.id),
          ),
        );
        return;
      }

      await _showSuccessDialog();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMessage('Could not save your booking. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Popup shown after a weekday booking is saved
  Future<void> _showSuccessDialog() {
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
            const Text(
              'Booking confirmed!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.restaurantName}\n$_summaryText',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textGrey,
              ),
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
        centerTitle: true,
        title: const Text(
          'Book Table',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _restaurantCard(),
                const SizedBox(height: 22),

                // DATE
                _sectionHeader(
                  'DATE',
                  '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dates.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _dateCard(i),
                  ),
                ),
                const SizedBox(height: 22),

                // TIME SLOT
                _sectionHeader('TIME SLOT', 'Dinner Service', dot: true),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.9,
                  children: _slots.map(_slotChip).toList(),
                ),
                if (_firstFreeSlot() == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No more slots today. Please choose another day.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                const SizedBox(height: 22),

                // NUMBER OF PEOPLE
                _sectionHeader('NUMBER OF PEOPLE', _guestText),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _guestOption(1, '1', 'Solo'),
                    const SizedBox(width: 8),
                    _guestOption(2, '2', 'Couple'),
                    const SizedBox(width: 8),
                    _guestOption(4, '4', 'Small'),
                    const SizedBox(width: 8),
                    _guestOption(6, '6+', 'Party'),
                  ],
                ),
                const SizedBox(height: 22),

                // TABLE TYPE
                _sectionHeader('TABLE TYPE', ''),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _tableOption('Indoor', 'AC Dining', Icons.table_restaurant),
                    const SizedBox(width: 8),
                    _tableOption('Outdoor', 'Courtyard', Icons.deck),
                    const SizedBox(width: 8),
                    _tableOption('Window', 'Garden View', Icons.window),
                  ],
                ),

                // Weekend policy (only on Saturday and Sunday)
                if (_isWeekend) ...[
                  const SizedBox(height: 20),
                  _weekendPolicy(),
                ],
                const SizedBox(height: 20),

                // Booking summary
                _summaryRow(),
              ],
            ),
          ),

          // Confirm button fixed at the bottom
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _isSaving ? null : _confirmBooking,
                    child: _isSaving
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
                          _isWeekend
                              ? 'Continue to Payment'
                              : 'Confirm Booking',
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can view or change this booking in My Bookings',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Restaurant name and address at the top
  Widget _restaurantCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          if (widget.cuisine.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              widget.cuisine,
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ],
        ],
      ),
    );
  }

  // Section title on the left, small orange text on the right
  Widget _sectionHeader(String title, String trailing, {bool dot = false}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF555555),
          ),
        ),
        const Spacer(),
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          trailing,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // One date card (e.g. "Today / 29 / Tue")
  Widget _dateCard(int index) {
    final date = _dates[index];
    final bool selected = index == _dateIndex;
    final top = index == 0 ? 'Today' : _weekdays[date.weekday - 1];
    final bottom = index == 0
        ? _weekdays[date.weekday - 1]
        : _shortMonths[date.month - 1];
    final Color textColor = selected ? Colors.white : AppColors.textDark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _dateIndex = index;
          // Keep the time if it is still open, otherwise pick the first free one
          if (_selectedSlot == null || _isPast(_selectedSlot!)) {
            _selectedSlot = _firstFreeSlot();
          }
        });
      },
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(top, style: TextStyle(fontSize: 11, color: textColor)),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(bottom, style: TextStyle(fontSize: 11, color: textColor)),
          ],
        ),
      ),
    );
  }

  // One time slot. Past slots are grey and crossed out.
  Widget _slotChip(List<int> slot) {
    final bool disabled = _isPast(slot);
    final bool selected = !disabled && _selectedSlot == slot;

    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _selectedSlot = slot),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : disabled
              ? const Color(0xFFEDEDED)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          _timeText(slot),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : disabled
                ? const Color(0xFFBDBDBD)
                : AppColors.textDark,
            decoration: disabled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  // One number-of-people option
  Widget _guestOption(int value, String number, String label) {
    final bool selected = _guests == value;
    final Color textColor = selected ? Colors.white : AppColors.textDark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _guests = value),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  // One table type option
  Widget _tableOption(String value, String sub, IconData icon) {
    final bool selected = _tableType == value;
    final Color color = selected ? Colors.white : AppColors.textDark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tableType = value),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(sub, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // Deposit notice for Saturday and Sunday
  Widget _weekendPolicy() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekend Booking Policy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rs. 500 fully refundable deposit is required for weekend '
                      'slots. It is taken from your dining bill, or refunded if '
                      'you cancel at least 1 hour before.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Summary of the choices with a fee label
  Widget _summaryRow() {
    final Color color = _isWeekend ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _summaryText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _isWeekend ? 'RS. 500 DEPOSIT' : 'NO FEE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}