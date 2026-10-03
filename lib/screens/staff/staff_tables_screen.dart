import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Staff "Tables" screen (Home tab body).
// Put this file in lib/screens/staff/ and use StaffTablesScreen() as the
// first page in staff_main_screen.dart (replace the Text('Home') placeholder).
// ---------------------------------------------------------------------------

enum TableStatus { free, occupied, reserved }

class RestaurantTable {
  final String id;
  final int seats;
  TableStatus status;

  RestaurantTable({
    required this.id,
    required this.seats,
    required this.status,
  });
}

// Colours – swap these for your AppColors values if you prefer.
const _orange = Color(0xFFF97316);
const _freeColor = Color(0xFF10B981);
const _occupiedColor = Color(0xFFEF4444);
const _reservedColor = Color(0xFFF59E0B);

Color _colorFor(TableStatus s) {
  switch (s) {
    case TableStatus.free:
      return _freeColor;
    case TableStatus.occupied:
      return _occupiedColor;
    case TableStatus.reserved:
      return _reservedColor;
  }
}

String _labelFor(TableStatus s) {
  switch (s) {
    case TableStatus.free:
      return 'FREE';
    case TableStatus.occupied:
      return 'OCCUPIED';
    case TableStatus.reserved:
      return 'RESERVED';
  }
}

String _titleFor(TableStatus s) {
  final l = _labelFor(s).toLowerCase();
  return l[0].toUpperCase() + l.substring(1);
}

class StaffTablesScreen extends StatefulWidget {
  const StaffTablesScreen({super.key});

  @override
  State<StaffTablesScreen> createState() => _StaffTablesScreenState();
}

class _StaffTablesScreenState extends State<StaffTablesScreen> {
  // Sample data – later replace with data from Firestore.
  final List<RestaurantTable> _tables = [
    RestaurantTable(id: 'T1', seats: 2, status: TableStatus.free),
    RestaurantTable(id: 'T2', seats: 4, status: TableStatus.occupied),
    RestaurantTable(id: 'T3', seats: 4, status: TableStatus.free),
    RestaurantTable(id: 'T4', seats: 4, status: TableStatus.reserved),
    RestaurantTable(id: 'T5', seats: 2, status: TableStatus.occupied),
    RestaurantTable(id: 'T6', seats: 4, status: TableStatus.free),
    RestaurantTable(id: 'T7', seats: 2, status: TableStatus.reserved),
    RestaurantTable(id: 'T8', seats: 4, status: TableStatus.occupied),
    RestaurantTable(id: 'T9', seats: 6, status: TableStatus.free),
  ];

  int _count(TableStatus s) => _tables.where((t) => t.status == s).length;

  Future<void> _showStatusDialog(RestaurantTable table) async {
    final picked = await showDialog<TableStatus>(
      context: context,
      builder: (_) => _StatusDialog(table: table),
    );
    if (picked != null) {
      setState(() => table.status = picked);
      // TODO: save the new status to Firestore here.
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Tables – The Gallery Café',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Manage live floor layout and table assignments',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  _buildFloorHeader(),
                  const SizedBox(height: 12),
                  _buildLegend(),
                  const SizedBox(height: 16),
                  _buildGrid(),
                  const SizedBox(height: 14),
                  _buildHintBar(),
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
              color: _orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              children: [
                TextSpan(text: 'Table', style: TextStyle(color: Colors.black)),
                TextSpan(text: 'Ease', style: TextStyle(color: _orange)),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_none, size: 22),
        ],
      ),
    );
  }

  Widget _buildFloorHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FLOOR LAYOUT OVERVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Main Dining Hall (Ground)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD7B0)),
          ),
          child: Text(
            '${_tables.length} Tables Total',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _orange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS LEGEND',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final s in TableStatus.values) ...[
                Expanded(child: _legendChip(s)),
                if (s != TableStatus.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendChip(TableStatus s) {
    final c = _colorFor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${_titleFor(s)} (${_count(s)})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final t = _tables[i];
        return _TableTile(table: t, onTap: () => _showStatusDialog(t));
      },
    );
  }

  Widget _buildHintBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAEE)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Tap table box to change status or assign guests',
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // TODO: open Quick Seat flow.
            },
            child: const Text(
              'Quick\nSeat',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onTap;

  const _TableTile({required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(table.status);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              table.id,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _labelFor(table.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${table.seats} seats',
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDialog extends StatelessWidget {
  final RestaurantTable table;

  const _StatusDialog({required this.table});

  @override
  Widget build(BuildContext context) {
    final current = table.status;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Table ${table.id.substring(1)} – ${table.seats} seats',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: Colors.black54),
                children: [
                  const TextSpan(text: 'Current status: '),
                  TextSpan(
                    text: _titleFor(current),
                    style: TextStyle(
                      color: _colorFor(current),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CHANGE STATUS TO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            for (final s in TableStatus.values) ...[
              _statusButton(context, s),
              const SizedBox(height: 10),
            ],
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(BuildContext context, TableStatus s) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context, s),
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorFor(s),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _titleFor(s),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}