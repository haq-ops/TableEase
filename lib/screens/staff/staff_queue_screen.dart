import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'add_customer_dialog.dart';

// ---------------------------------------------------------------------------
// Staff "Live Waitlist" screen (Queue tab body).
// Put this file in lib/screens/staff/ and use StaffQueueScreen() as the
// second page in staff_main_screen.dart (replace _Placeholder('Queue')).
// ---------------------------------------------------------------------------

class WaitingParty {
  final String name;
  final int partySize;
  final String joinedLabel; // e.g. "7:15 PM"
  final int waitingMins;
  final String phone;

  WaitingParty({
    required this.name,
    required this.partySize,
    required this.joinedLabel,
    required this.waitingMins,
    this.phone = '',
  });
}

enum _SizeFilter { all, small, medium, large }

bool _matches(_SizeFilter f, int size) {
  switch (f) {
    case _SizeFilter.all:
      return true;
    case _SizeFilter.small:
      return size <= 2;
    case _SizeFilter.medium:
      return size >= 3 && size <= 4;
    case _SizeFilter.large:
      return size >= 5;
  }
}

class StaffQueueScreen extends StatefulWidget {
  const StaffQueueScreen({super.key});

  @override
  State<StaffQueueScreen> createState() => _StaffQueueScreenState();
}

class _StaffQueueScreenState extends State<StaffQueueScreen> {
  // Sample data – later replace with data from Firestore.
  final List<WaitingParty> _queue = [
    WaitingParty(
        name: 'Kasun Perera',
        partySize: 4,
        joinedLabel: '7:15 PM',
        waitingMins: 18),
    WaitingParty(
        name: 'Dilani Silva',
        partySize: 2,
        joinedLabel: '7:21 PM',
        waitingMins: 12),
    WaitingParty(
        name: 'Mohamed Rilwan',
        partySize: 5,
        joinedLabel: '7:25 PM',
        waitingMins: 8),
    WaitingParty(
        name: 'Samantha Jayawardena',
        partySize: 3,
        joinedLabel: '7:30 PM',
        waitingMins: 3),
  ];

  _SizeFilter _filter = _SizeFilter.all;

  List<WaitingParty> get _visible =>
      _queue.where((p) => _matches(_filter, p.partySize)).toList();

  int _countFor(_SizeFilter f) =>
      _queue.where((p) => _matches(f, p.partySize)).length;

  int get _estimatedWait {
    if (_queue.isEmpty) return 0;
    // Simple estimate: roughly 15 minutes. Replace with real logic later.
    return 15;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _notify(WaitingParty p) {
    // TODO: send a push notification / SMS to the customer.
    _snack('${p.name} has been notified');
  }

  void _seatNow(WaitingParty p) {
    // TODO: open table picker, then update Firestore.
    setState(() => _queue.remove(p));
    _snack('${p.name} seated');
  }

  Future<void> _remove(WaitingParty p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remove from queue?'),
        content: Text('${p.name} (${p.partySize} people) will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _queue.remove(p));
    }
  }

  Future<void> _addCustomer() async {
    final result = await showDialog<AddCustomerResult>(
      context: context,
      builder: (_) => const AddCustomerDialog(),
    );
    if (result != null && mounted) {
      setState(() => _queue.add(WaitingParty(
        name: result.name,
        phone: result.phone,
        partySize: result.partySize,
        joinedLabel: TimeOfDay.now().format(context),
        waitingMins: 0,
      )));
      // TODO: save to Firestore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleRow(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No parties waiting',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < list.length; i++) ...[
                      _PartyCard(
                        position: _queue.indexOf(list[i]) + 1,
                        party: list[i],
                        isNext: _queue.indexOf(list[i]) == 0,
                        onNotify: () => _notify(list[i]),
                        onSeat: () => _seatNow(list[i]),
                        onRemove: () => _remove(list[i]),
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _addCustomer,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('+ Add Customer'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Queue syncs live across all floor host devices',
                      style:
                      TextStyle(fontSize: 10, color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              children: [
                const TextSpan(
                    text: 'Table', style: TextStyle(color: Colors.black)),
                TextSpan(
                    text: 'Ease',
                    style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_none, size: 22),
          const SizedBox(width: 12),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD7B0), width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Live Waitlist',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD7B0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active Queue',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'The Gallery Café • Colombo',
                style: TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(
            '${_queue.length} parties • ~${_estimatedWait}m wait',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final items = <_SizeFilter, String>{
      _SizeFilter.all: 'All Parties (${_countFor(_SizeFilter.all)})',
      _SizeFilter.small: 'Small (1-2)',
      _SizeFilter.medium: 'Medium (3-4)',
      _SizeFilter.large: 'Large (5+)',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in items.entries) ...[
            GestureDetector(
              onTap: () => setState(() => _filter = e.key),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _filter == e.key
                      ? AppColors.primary
                      : const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _filter == e.key ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  final int position;
  final WaitingParty party;
  final bool isNext;
  final VoidCallback onNotify;
  final VoidCallback onSeat;
  final VoidCallback onRemove;

  const _PartyCard({
    required this.position,
    required this.party,
    required this.isNext,
    required this.onNotify,
    required this.onSeat,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$position',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 11, color: AppColors.textGrey),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'Joined ${party.joinedLabel} • '
                                '${party.waitingMins} mins waiting',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textGrey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups, size: 12, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      '${party.partySize} People',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  onPressed: onNotify,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    isNext
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none,
                    size: 16,
                  ),
                  label: Text(
                    isNext ? 'Notify Ready' : 'Notify',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  onPressed: onSeat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F1F3),
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.event_seat_outlined, size: 16),
                  label: const Text(
                    'Seat Now',
                    style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: ElevatedButton(
                  onPressed: onRemove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDECEC),
                    foregroundColor: const Color(0xFFEF4444),
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.delete_outline, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}