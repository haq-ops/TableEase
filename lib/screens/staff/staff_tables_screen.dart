import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'staff_main_screen.dart';

// Screens 15 and 16: live table layout.
// Tables live in restaurants/{restaurantId}/tables.
// Tapping a table opens a popup to change it to Free, Occupied or Reserved.
// Every change also updates restaurants/{id}.tablesAvailable, so the
// "Tables: N" chip on the customer Home screen updates live.
class StaffTablesScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const StaffTablesScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<StaffTablesScreen> createState() => _StaffTablesScreenState();
}

class _StaffTablesScreenState extends State<StaffTablesScreen> {
  bool _creatingTables = false;

  DocumentReference<Map<String, dynamic>> get _restaurant => FirebaseFirestore
      .instance
      .collection('restaurants')
      .doc(widget.restaurantId);

  CollectionReference<Map<String, dynamic>> get _tables =>
      _restaurant.collection('tables');

  // CREATE (first time only): make 9 tables for this restaurant.
  // The number of free tables matches the current tablesAvailable value,
  // so customers and staff see the same number from the start.
  Future<void> _createTables() async {
    if (_creatingTables) return;
    _creatingTables = true;

    try {
      final restaurant = await _restaurant.get();
      final int free =
      ((restaurant.data()?['tablesAvailable'] ?? 0) as num).toInt();

      const seats = [2, 4, 4, 6, 2, 4, 2, 4, 6];
      final int total = free > seats.length ? free : seats.length;

      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < total; i++) {
        batch.set(_tables.doc('T${i + 1}'), {
          'number': i + 1,
          'seats': seats[i % seats.length],
          'status': i < free ? 'free' : 'occupied',
        });
      }
      await batch.commit();
    } catch (e) {
      _creatingTables = false;
      _showMessage('Could not create tables. Check your internet.');
    }
  }

  // UPDATE: change one table's status and keep the free count in sync
  Future<void> _setStatus(
      List<_TableInfo> tables,
      _TableInfo table,
      String status,
      ) async {
    final int freeAfter = tables
        .where((t) => (t.id == table.id ? status : t.status) == 'free')
        .length;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_tables.doc(table.id), {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_restaurant, {'tablesAvailable': freeAfter});
    await batch.commit();
  }

  // Quick Seat: the first free table becomes occupied
  Future<void> _quickSeat(List<_TableInfo> tables) async {
    final free = tables.where((t) => t.status == 'free').toList();
    if (free.isEmpty) {
      _showMessage('No free tables right now.');
      return;
    }
    final table = free.first;
    try {
      await _setStatus(tables, table, 'occupied');
      _showMessage('T${table.number} is now occupied.');
    } catch (e) {
      _showMessage('Could not update the table. Check your internet.');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffHeader(),
          Expanded(
            // READ (live): the tables of this restaurant
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _tables.orderBy('number').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    'Could not load tables. Check your internet.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tables = snapshot.data!.docs
                    .map((doc) => _TableInfo.fromDoc(doc))
                    .toList();

                // First time for this restaurant: create the tables
                if (tables.isEmpty) {
                  _createTables();
                  return const Center(child: CircularProgressIndicator());
                }

                return _content(tables);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<_TableInfo> tables) {
    int count(String status) => tables.where((t) => t.status == status).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        // Title and subtitle
        Text(
          'Tables – ${widget.restaurantName}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage live floor layout and table assignments',
          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        const SizedBox(height: 18),

        // Floor name and total tables
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StaffSectionLabel('FLOOR LAYOUT OVERVIEW'),
                  SizedBox(height: 2),
                  Text(
                    'Main Dining Hall (Ground)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${tables.length} Tables Total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Status legend with live counts
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StaffSectionLabel('STATUS LEGEND'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _legend('Free', count('free'), _colorOf('free')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _legend(
                      'Occupied',
                      count('occupied'),
                      _colorOf('occupied'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _legend(
                      'Reserved',
                      count('reserved'),
                      _colorOf('reserved'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3-column grid of tables
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: tables.map((t) => _tableTile(tables, t)).toList(),
        ),
        const SizedBox(height: 18),

        // Hint and Quick Seat
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tap a table to change its status or assign guests',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ),
              TextButton(
                onPressed: () => _quickSeat(tables),
                child: const Text(
                  'Quick Seat',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // One legend chip, e.g. "● Free (4)"
  Widget _legend(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label ($count)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // One coloured table box in the grid (Figma screen 15)
  Widget _tableTile(List<_TableInfo> tables, _TableInfo table) {
    final Color color = _colorOf(table.status);
    final Color textColor = _textColorOf(table.status);

    return Semantics(
      button: true,
      label: 'Table ${table.number}, ${_labelOf(table.status)}, '
          '${table.seats} seats',
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStatusPopup(tables, table),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'T${table.number}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  // a slightly darker shade of the tile colour
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _labelOf(table.status).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${table.seats} seats',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Screen 16: popup to change a table's status
  void _showStatusPopup(List<_TableInfo> tables, _TableInfo table) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Table ${table.number} – ${table.seats} seats',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: AppColors.textGrey),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      const TextSpan(
                        text: 'Current status: ',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                      TextSpan(
                        text: _labelOf(table.status),
                        style: TextStyle(
                          color: _colorOf(table.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const StaffSectionLabel('CHANGE STATUS TO'),
                const SizedBox(height: 10),
                for (final status in ['free', 'occupied', 'reserved']) ...[
                  _statusOption(dialogContext, tables, table, status),
                  const SizedBox(height: 10),
                ],
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // One big coloured option inside the popup
  Widget _statusOption(
      BuildContext dialogContext,
      List<_TableInfo> tables,
      _TableInfo table,
      String status,
      ) {
    final bool isCurrent = table.status == status;
    final Color textColor = _textColorOf(status);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: _colorOf(status),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            Navigator.pop(dialogContext);
            if (isCurrent) return;
            try {
              await _setStatus(tables, table, status);
              _showMessage('T${table.number} is now ${_labelOf(status)}.');
            } catch (e) {
              _showMessage('Could not update the table. Check your internet.');
            }
          },
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isCurrent
                    ? Icon(Icons.check, size: 18, color: textColor)
                    : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: textColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isCurrent
                      ? '${_labelOf(status)} (current)'
                      : _labelOf(status),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
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

// Table status colours from the Figma design (screen 15)
const Color _freeColor = Color(0xFF10B981); // green
const Color _occupiedColor = Color(0xFFF43F5E); // red
const Color _reservedColor = Color(0xFFFBBF24); // yellow

// Green = free, red = occupied, yellow = reserved
Color _colorOf(String status) {
  switch (status) {
    case 'occupied':
      return _occupiedColor;
    case 'reserved':
      return _reservedColor;
    default:
      return _freeColor;
  }
}

// Dark text on yellow is easier to read than white
Color _textColorOf(String status) {
  return status == 'reserved' ? AppColors.textDark : Colors.white;
}

String _labelOf(String status) {
  switch (status) {
    case 'occupied':
      return 'Occupied';
    case 'reserved':
      return 'Reserved';
    default:
      return 'Free';
  }
}

// One table as read from Firestore
class _TableInfo {
  final String id;
  final int number;
  final int seats;
  final String status;

  _TableInfo({
    required this.id,
    required this.number,
    required this.seats,
    required this.status,
  });

  factory _TableInfo.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _TableInfo(
      id: doc.id,
      number: ((data['number'] ?? 0) as num).toInt(),
      seats: ((data['seats'] ?? 2) as num).toInt(),
      status: (data['status'] ?? 'free').toString(),
    );
  }
}
