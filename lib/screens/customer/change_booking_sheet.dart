import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Bottom sheet to change the date, time and guests of a booking
class ChangeBookingSheet extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> booking;

  const ChangeBookingSheet({
    super.key,
    required this.bookingId,
    required this.booking,
  });

  @override
  State<ChangeBookingSheet> createState() => _ChangeBookingSheetState();
}

class _ChangeBookingSheetState extends State<ChangeBookingSheet> {
  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Same dinner slots as the Book a Table screen
  static const List<List<int>> _slots = [
    [19, 0], [19, 30], [20, 0], [20, 30],
    [21, 0], [21, 30], [22, 0], [22, 30],
  ];

  late final List<DateTime> _dates;
  late int _dateIndex;
  List<int>? _selectedSlot;
  late int _guests;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dates = List.generate(7, (i) => today.add(Duration(days: i)));

    // Start with the booking's current day, time and guests
    final current = (widget.booking['bookingTime'] as Timestamp).toDate();
    final currentDay = DateTime(current.year, current.month, current.day);
    final index = _dates.indexWhere((d) => d == currentDay);
    _dateIndex = index == -1 ? 0 : index;

    _selectedSlot = _slots.firstWhere(
          (s) => s[0] == current.hour && s[1] == current.minute,
      orElse: () => _slots.first,
    );
    if (_isPast(_selectedSlot!)) _selectedSlot = _firstFreeSlot();

    _guests = ((widget.booking['guests'] ?? 2) as num).toInt();
  }

  DateTime get _selectedDate => _dates[_dateIndex];

  DateTime _slotTime(List<int> slot) {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slot[0],
      slot[1],
    );
  }

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

  bool get _needsNewDeposit =>
      _isWeekend && widget.booking['depositRequired'] != true;

  String _timeText(List<int> slot) {
    final hour = slot[0] > 12 ? slot[0] - 12 : slot[0];
    final minute = slot[1].toString().padLeft(2, '0');
    final period = slot[0] >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _save() async {
    if (_selectedSlot == null) {
      setState(() => _error = 'Please choose a time slot.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final newTime = _slotTime(_selectedSlot!);
      final bookings = FirebaseFirestore.instance.collection('bookings');

      // READ: make sure there is no other booking here at the new time
      final existing = await bookings
          .where('userId', isEqualTo: uid)
          .where('restaurantId', isEqualTo: widget.booking['restaurantId'])
          .where('bookingTime', isEqualTo: Timestamp.fromDate(newTime))
          .get();
      final clash = existing.docs.any(
            (d) => d.id != widget.bookingId && d.data()['status'] != 'cancelled',
      );
      if (clash) {
        setState(() => _error = 'You already have a booking here at this time.');
        return;
      }

      // UPDATE: save the new date, time and number of guests
      await bookings.doc(widget.bookingId).update({
        'bookingTime': Timestamp.fromDate(newTime),
        'guests': _guests,
        'updatedAt': FieldValue.serverTimestamp(),
        // Moving a weekday booking to a weekend adds the deposit
        if (_needsNewDeposit) ...{
          'depositRequired': true,
          'depositAmount': 500,
          'status': 'pending_payment',
          'paymentStatus': 'unpaid',
        },
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('CHANGE ERROR: $e');
      setState(() => _error = 'Could not update the booking. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Change booking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (widget.booking['restaurantName'] ?? '').toString(),
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 18),

              _label('DATE'),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dates.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _dateCard(i),
                ),
              ),
              const SizedBox(height: 18),

              _label('TIME'),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                children: _slots.map(_slotChip).toList(),
              ),
              const SizedBox(height: 18),

              _label('NUMBER OF PEOPLE'),
              Row(
                children: [
                  _guestOption(1, '1'),
                  const SizedBox(width: 8),
                  _guestOption(2, '2'),
                  const SizedBox(width: 8),
                  _guestOption(4, '4'),
                  const SizedBox(width: 8),
                  _guestOption(6, '6+'),
                ],
              ),

              // Warning when moving to a weekend
              if (_needsNewDeposit) ...[
                const SizedBox(height: 14),
                const Text(
                  'Weekend bookings need a Rs. 500 deposit. You can pay it '
                      'from My Bookings after saving.',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 18),

              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF555555),
        ),
      ),
    );
  }

  Widget _dateCard(int index) {
    final date = _dates[index];
    final bool selected = index == _dateIndex;
    final Color textColor = selected ? Colors.white : AppColors.textDark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _dateIndex = index;
          if (_selectedSlot == null || _isPast(_selectedSlot!)) {
            _selectedSlot = _firstFreeSlot();
          }
        });
      },
      child: Container(
        width: 58,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              index == 0 ? 'Today' : _weekdays[date.weekday - 1],
              style: TextStyle(fontSize: 11, color: textColor),
            ),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              _shortMonths[date.month - 1],
              style: TextStyle(fontSize: 11, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _guestOption(int value, String label) {
    final bool selected = _guests == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _guests = value),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}