import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Bottom sheet to join a restaurant's live queue
class JoinQueueSheet extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final int waitMinutes;

  const JoinQueueSheet({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.waitMinutes,
  });

  @override
  State<JoinQueueSheet> createState() => _JoinQueueSheetState();
}

class _JoinQueueSheetState extends State<JoinQueueSheet> {
  int _partySize = 2;
  bool _isJoining = false;
  String? _error;

  Future<void> _join() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final queues = db.collection('queues');

      // READ: a customer can only be in one queue at a time
      final mine = await queues.where('userId', isEqualTo: uid).get();
      final active = mine.docs.where((d) {
        final s = d.data()['status'];
        return s == 'waiting' || s == 'notified';
      }).toList();
      if (active.isNotEmpty) {
        setState(() {
          _error =
          'You are already in the queue at '
              '${active.first.data()['restaurantName']}. Leave it first.';
        });
        return;
      }

      // READ: find today's highest queue number at this restaurant
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final restaurantQueue = await queues
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .get();
      int highest = 0;
      for (final d in restaurantQueue.docs) {
        final joined = d.data()['joinedAt'] as Timestamp?;
        final isToday =
            joined == null || !joined.toDate().isBefore(todayStart);
        final number = ((d.data()['queueNumber'] ?? 0) as num).toInt();
        if (isToday && number > highest) highest = number;
      }

      // READ: the customer's name, so staff can call them
      final user = await db.collection('users').doc(uid).get();
      final customerName = (user.data()?['fullName'] ?? '').toString();

      // CREATE: add this customer to the queue
      await queues.add({
        'userId': uid,
        'customerName': customerName,
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'queueNumber': highest + 1,
        'partySize': _partySize,
        'status': 'waiting',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('JOIN QUEUE ERROR: $e');
      setState(() => _error = 'Could not join the queue. Please try again.');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Small grey handle at the top
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
              'Join the queue',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.restaurantName,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),

            // Current waiting time
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    widget.waitMinutes > 0
                        ? 'Current wait: about ${widget.waitMinutes} min'
                        : 'Short wait right now',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'HOW MANY PEOPLE?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _option(1, '1', 'Solo'),
                const SizedBox(width: 8),
                _option(2, '2', 'Couple'),
                const SizedBox(width: 8),
                _option(4, '4', 'Small'),
                const SizedBox(width: 8),
                _option(6, '6+', 'Party'),
              ],
            ),

            // Error message (for example, already in a queue)
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isJoining ? null : _join,
              child: _isJoining
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : const Text('Join Queue'),
            ),
          ],
        ),
      ),
    );
  }

  // One party size option (orange when selected)
  Widget _option(int value, String number, String label) {
    final bool selected = _partySize == value;
    final Color textColor = selected ? Colors.white : AppColors.textDark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _partySize = value),
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
              Text(label, style: TextStyle(fontSize: 11, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}