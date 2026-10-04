import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'table_ready_screen.dart';

// The Queue tab: shows the customer's live place in line
class QueueScreen extends StatelessWidget {
  // Opens the Home tab (used on the empty screen)
  final VoidCallback onGoHome;

  const QueueScreen({super.key, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SafeArea(
      // READ (live): this customer's queue entries
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('queues')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your queue.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Only "waiting" and "notified" entries are still active
          final active = snapshot.data!.docs.where((d) {
            final s = d.data()['status'];
            return s == 'waiting' || s == 'notified';
          }).toList();

          if (active.isEmpty) return _EmptyQueue(onGoHome: onGoHome);

          final doc = active.first;
          final data = doc.data();

          // Staff said the table is ready and the customer has not tapped OK yet
          if (data['status'] == 'notified' && data['acknowledged'] != true) {
            return TableReadyScreen(queueId: doc.id, data: data);
          }

          return _QueueTicket(id: doc.id, data: data);
        },
      ),
    );
  }
}

// The live queue ticket
class _QueueTicket extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _QueueTicket({required this.id, required this.data});

  // Rough time each group ahead takes to be seated
  static const int _minutesPerGroup = 4;

  bool _isToday(Timestamp? time) {
    if (time == null) return true;
    final t = time.toDate();
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final restaurantId = (data['restaurantId'] ?? '').toString();
    final restaurantName = (data['restaurantName'] ?? '').toString();
    final queueNumber = ((data['queueNumber'] ?? 0) as num).toInt();
    final partySize = ((data['partySize'] ?? 1) as num).toInt();
    final bool isReady = data['status'] == 'notified';

    // READ (live): this restaurant's queue, to count the people ahead
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('queues')
          .where('restaurantId', isEqualTo: restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        int ahead = 0;
        for (final d in docs) {
          final q = d.data();
          final s = q['status'];
          final n = ((q['queueNumber'] ?? 0) as num).toInt();
          final stillWaiting = s == 'waiting' || s == 'notified';
          if (stillWaiting &&
              n < queueNumber &&
              _isToday(q['joinedAt'] as Timestamp?)) {
            ahead++;
          }
        }

        final waitText = isReady
            ? 'Now'
            : ahead == 0
            ? 'Any minute'
            : '~${ahead * _minutesPerGroup} min';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'My Queue',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your live place in line',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 20),

            // Orange queue ticket
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFC2410C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'QUEUE TICKET',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isReady ? 'READY' : 'WAITING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your number',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    '#$queueNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    restaurantName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // People ahead, wait time, party size
            Row(
              children: [
                Expanded(
                  child: _stat(
                    Icons.groups_outlined,
                    isReady ? '0' : '$ahead',
                    'People ahead',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(Icons.timer_outlined, waitText, 'Est. wait'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    Icons.people_outline,
                    partySize == 6 ? '6+' : '$partySize',
                    'Party size',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _statusBanner(isReady),
            const SizedBox(height: 20),

            // Change people
            OutlinedButton.icon(
              onPressed: () => _changePeople(context, partySize),
              icon: const Icon(Icons.group_add_outlined, size: 20),
              label: const Text('Change People'),
              style: _buttonStyle(AppColors.textDark),
            ),
            const SizedBox(height: 10),

            // Leave queue
            OutlinedButton.icon(
              onPressed: () => _leave(context, restaurantName),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Leave Queue'),
              style: _buttonStyle(AppColors.danger),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your place is saved while you use other tabs. '
                  'This screen updates by itself.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  // Amber "stay nearby" or green "table ready" message
  Widget _statusBanner(bool isReady) {
    final Color color = isReady ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.notifications_active : Icons.hourglass_top,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady ? 'Your table is ready!' : 'Please stay nearby',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReady
                      ? 'Please go to the host desk now.'
                      : 'We will tell you here when your table is ready.',
                  style: const TextStyle(
                    fontSize: 12,
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

  ButtonStyle _buttonStyle(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(
        color: color == AppColors.textDark ? AppColors.border : color,
      ),
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  // UPDATE: change the number of people
  Future<void> _changePeople(BuildContext context, int current) async {
    final messenger = ScaffoldMessenger.of(context);

    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('How many people?'),
        children: [
          for (final n in [1, 2, 4, 6])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, n),
              child: Row(
                children: [
                  Icon(
                    n == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: n == current ? AppColors.primary : AppColors.border,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    n == 6 ? '6 or more' : '$n ${n == 1 ? 'person' : 'people'}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == current) return;

    try {
      await FirebaseFirestore.instance.collection('queues').doc(id).update({
        'partySize': picked,
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Party size updated')),
      );
    } catch (e) {
      debugPrint('QUEUE UPDATE ERROR: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update. Please try again.')),
      );
    }
  }

  // DELETE: leave the queue after asking first
  Future<void> _leave(BuildContext context, String restaurantName) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the queue?'),
        content: Text('You will lose your place at $restaurantName.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('queues').doc(id).delete();
      messenger.showSnackBar(
        const SnackBar(content: Text('You left the queue')),
      );
    } catch (e) {
      debugPrint('LEAVE QUEUE ERROR: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not leave. Please try again.')),
      );
    }
  }
}

// Shown when the customer is not in any queue
class _EmptyQueue extends StatelessWidget {
  final VoidCallback onGoHome;

  const _EmptyQueue({required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You are not in any queue',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find a restaurant on the Home tab and join its live queue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: onGoHome,
                child: const Text('Go to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}