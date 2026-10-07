import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'add_customer_dialog.dart';
import 'staff_main_screen.dart';

// Screen 18: live waitlist for this restaurant.
// Reads the same "queues" documents customers create in JoinQueueSheet.
//   Notify   -> status 'notified' -> the customer sees the Table Ready screen
//   Seat Now -> status 'seated'   -> the customer leaves the queue
//   Remove   -> status 'removed'
class StaffQueueScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const StaffQueueScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<StaffQueueScreen> createState() => _StaffQueueScreenState();
}

class _StaffQueueScreenState extends State<StaffQueueScreen> {
  // Party size filter: 'all', 'small' (1-2), 'medium' (3-4), 'large' (5+)
  String _size = 'all';

  // Refreshes the "x mins waiting" text every minute
  Timer? _ticker;

  // Rough estimate used for "~15m wait" and the customer Home screen
  static const int _minutesPerParty = 5;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _queues =>
      FirebaseFirestore.instance.collection('queues');

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // UPDATE: keep the restaurant's waiting time in sync for customers
  Future<void> _syncWaitTime(int parties) async {
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .update({'waitMinutes': parties * _minutesPerParty});
  }

  // UPDATE: tell the customer their table is ready
  Future<void> _notify(_Party party) async {
    try {
      await _queues.doc(party.id).update({
        'status': 'notified',
        'notifiedAt': FieldValue.serverTimestamp(),
        // false, so the customer's Table Ready screen opens
        'acknowledged': false,
      });
      _showMessage('${party.name} has been notified.');
    } catch (e) {
      _showMessage('Could not notify. Check your internet.');
    }
  }

  // UPDATE: the party has been seated, so they leave the queue
  Future<void> _seat(_Party party, int activeCount) async {
    try {
      await _queues.doc(party.id).update({
        'status': 'seated',
        'seatedAt': FieldValue.serverTimestamp(),
      });
      await _syncWaitTime(activeCount - 1);
      _showMessage('${party.name} has been seated.');
    } catch (e) {
      _showMessage('Could not seat this party. Check your internet.');
    }
  }

  // UPDATE: remove a party after the staff member confirms
  Future<void> _remove(_Party party, int activeCount) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from queue?'),
        content: Text(
          'Remove #${party.number} ${party.name} from the waitlist? '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _queues.doc(party.id).update({
        'status': 'removed',
        'removedAt': FieldValue.serverTimestamp(),
      });
      await _syncWaitTime(activeCount - 1);
      _showMessage('${party.name} was removed from the queue.');
    } catch (e) {
      _showMessage('Could not remove this party. Check your internet.');
    }
  }

  // Screen 19: add a walk-in customer
  Future<void> _addCustomer(int activeCount) async {
    final bool? added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AddCustomerDialog(
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
      ),
    );
    if (added != true) return;
    try {
      await _syncWaitTime(activeCount + 1);
    } catch (_) {
      // The customer was added; only the wait estimate failed
    }
    _showMessage('Customer added to the queue.');
  }

  bool _matchesSize(_Party party) {
    switch (_size) {
      case 'small':
        return party.size <= 2;
      case 'medium':
        return party.size >= 3 && party.size <= 4;
      case 'large':
        return party.size >= 5;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffHeader(),
          Expanded(
            // READ (live): every queue entry for this restaurant
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _queues
                  .where('restaurantId', isEqualTo: widget.restaurantId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    'Could not load the queue. Check your internet.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Only parties still waiting, in queue order
                final active = snapshot.data!.docs
                    .map((doc) => _Party.fromDoc(doc))
                    .where((p) => p.status == 'waiting' || p.status == 'notified')
                    .toList()
                  ..sort((a, b) => a.number.compareTo(b.number));

                final shown = active.where(_matchesSize).toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        children: [
                          _titleRow(active.length),
                          const SizedBox(height: 14),
                          _sizeFilters(active),
                          const SizedBox(height: 16),
                          if (shown.isEmpty)
                            _message(
                              active.isEmpty
                                  ? 'No one is waiting right now.'
                                  : 'No parties of this size.',
                            )
                          else
                            ...shown.map((p) => _partyCard(p, active.length)),
                        ],
                      ),
                    ),

                    // Add a walk-in customer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _addCustomer(active.length),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add Customer'),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Queue syncs live across all floor host devices',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // "Live Waitlist" title, restaurant name, Active Queue chip and totals
  Widget _titleRow(int parties) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Live Waitlist',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Active Queue',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ),
            Text(
              '$parties ${parties == 1 ? 'party' : 'parties'} • '
                  '~${parties * _minutesPerParty}m wait',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // All Parties / Small / Medium / Large chips
  Widget _sizeFilters(List<_Party> active) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', 'All Parties (${active.length})'),
          _filterChip('small', 'Small (1–2)'),
          _filterChip('medium', 'Medium (3–4)'),
          _filterChip('large', 'Large (5+)'),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final bool selected = _size == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _size = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  // One party in the waitlist
  Widget _partyCard(_Party party, int activeCount) {
    final bool notified = party.status == 'notified';
    final int minutes = party.joinedAt == null
        ? 0
        : DateTime.now().difference(party.joinedAt!).inMinutes;
    final String joined =
    party.joinedAt == null ? 'Just now' : staffTime(party.joinedAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notified
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Queue number
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${party.number}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Name and waiting time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Joined $joined • $minutes mins waiting',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Party size
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.textDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${party.size} People',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Shown after Notify, so staff know who has been called
          if (notified) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  size: 14,
                  color: AppColors.success,
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Notified – waiting for the customer to arrive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Notify, Seat Now and Remove
          Row(
            children: [
              Expanded(
                child: notified
                    ? StaffActionButton(
                  label: 'Notified',
                  icon: Icons.check,
                  background: AppColors.success.withValues(alpha: 0.12),
                  foreground: AppColors.success,
                )
                    : StaffActionButton(
                  label: 'Notify',
                  icon: Icons.notifications_none,
                  background: AppColors.primary,
                  foreground: Colors.white,
                  onTap: () => _notify(party),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StaffActionButton(
                  label: 'Seat Now',
                  icon: Icons.event_seat_outlined,
                  background: AppColors.surface,
                  foreground: AppColors.textDark,
                  onTap: () => _seat(party, activeCount),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Remove ${party.name} from the queue',
                child: Material(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _remove(party, activeCount),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textGrey),
        ),
      ),
    );
  }
}

// One queue entry, read from the same fields JoinQueueSheet writes
class _Party {
  final String id;
  final String name;
  final int number;
  final int size;
  final String status;
  final DateTime? joinedAt;

  _Party({
    required this.id,
    required this.name,
    required this.number,
    required this.size,
    required this.status,
    required this.joinedAt,
  });

  factory _Party.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String name = (data['customerName'] ?? '').toString().trim();
    final joined = data['joinedAt'];

    return _Party(
      id: doc.id,
      name: name.isEmpty ? 'Guest' : name,
      number: ((data['queueNumber'] ?? 0) as num).toInt(),
      size: ((data['partySize'] ?? 1) as num).toInt(),
      status: (data['status'] ?? '').toString(),
      joinedAt: joined is Timestamp ? joined.toDate() : null,
    );
  }
}
