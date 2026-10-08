import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_restaurants_screen.dart';

// Firestore collection that holds new restaurant registrations (screen 21)
const String kRequestsCollection = 'restaurant_requests';

// READ (live): registrations that are still waiting for the admin
Stream<QuerySnapshot<Map<String, dynamic>>> pendingRequestsStream() {
  return FirebaseFirestore.instance
      .collection(kRequestsCollection)
      .where('status', isEqualTo: 'pending')
      .snapshots();
}

// Admin app: 4 tabs with a bottom navigation bar (Figma screens 20–24)
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentTab = 0;

  void _openTab(int index) => setState(() => _currentTab = index);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      // Screen 20: overview and analytics
      AdminDashboardScreen(onOpenTab: _openTab),
      // Screens 23 and 24: partner restaurants
      AdminRestaurantsScreen(onOpenTab: _openTab),
      // Screen 22: new registration requests
      AdminRequestsScreen(onOpenTab: _openTab),
      // Same profile screen as customers and staff (edit, logout)
      const ProfileScreen(),
    ];

    return Scaffold(
      // IndexedStack keeps each tab's state when switching tabs
      body: IndexedStack(index: _currentTab, children: tabs),
      // Same bottom navigation bar style as the customer and staff apps
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: _openTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textGrey,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,

          // Solid icons, same look as the customer and staff nav bars
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.store),
              label: 'Restaurants',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],



        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared admin widgets
// ---------------------------------------------------------------------------

// Top bar used on every admin tab.
// With a title (Dashboard): small "TableEase" above a big title.
// Without a title: logo and "TableEase" only.
class AdminHeader extends StatelessWidget {
  final String? title;
  final VoidCallback? onBell;
  final VoidCallback? onAvatar;

  const AdminHeader({super.key, this.title, this.onBell, this.onAvatar});

  @override
  Widget build(BuildContext context) {
    final String? title = this.title;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Image.asset(
                'assets/images/logo_icon.png',
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.table_restaurant,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (title == null)
            const AdminBrandText(fontSize: 19)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const AdminBrandText(fontSize: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Pending requests',
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.textDark,
            ),
            onPressed: onBell ??
                    () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new alerts')),
                  );
                },
          ),
          if (onAvatar != null)
            Semantics(
              button: true,
              label: 'Open profile',
              child: GestureDetector(
                onTap: onAvatar,
                child: const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFFB45309),
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// "TableEase" with "Ease" in orange
class AdminBrandText extends StatelessWidget {
  final double fontSize;

  const AdminBrandText({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
        children: const [
          TextSpan(
            text: 'Table',
            style: TextStyle(color: AppColors.textDark),
          ),
          TextSpan(
            text: 'Ease',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// Small grey uppercase label, e.g. "OWNER"
class AdminSectionLabel extends StatelessWidget {
  final String text;

  const AdminSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Color(0xFF555555),
      ),
    );
  }
}

// Small rounded pill, e.g. "3 Pending"
class AdminChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const AdminChip({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// Rounded square with the restaurant's initials, e.g. "GC"
class AdminInitialsBox extends StatelessWidget {
  final String name;

  const AdminInitialsBox({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = avatarColorsFor(name);

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.foreground.withValues(alpha: 0.25)),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: colors.foreground,
        ),
      ),
    );
  }
}

// Horizontal filter chips: "All (3)", "Colombo (2)", ...
class AdminFilterChips extends StatelessWidget {
  final Map<String, int> counts; // city -> count, already sorted
  final int total;
  final String selected;
  final ValueChanged<String> onSelected;

  const AdminFilterChips({
    super.key,
    required this.counts,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      MapEntry('All', total),
      ...counts.entries,
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final bool isSelected = entry.key == selected;

          return Semantics(
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => onSelected(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry.key} (${entry.value})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Coloured full-width button used in admin cards (Approve, Reject, Edit...)
class AdminButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AdminButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Message shown when a list is empty or failed to load
class AdminMessage extends StatelessWidget {
  final String text;
  final IconData icon;

  const AdminMessage({
    super.key,
    required this.text,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textGrey),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

// Figma colours used for approve / remove actions
const Color kApproveGreen = Color(0xFF059669);
const Color kRejectRed = Color(0xFFE11D48);
const Color kRemoveRed = Color(0xFFDC2626);
const Color kRemoveRedLight = Color(0xFFFEE2E2);

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// Firestore Timestamp -> DateTime (null if missing)
DateTime? toDateTime(dynamic value) {
  return value is Timestamp ? value.toDate() : null;
}

// Aug 05, 2026
String adminDate(DateTime date) {
  return '${_months[date.month - 1]} '
      '${date.day.toString().padLeft(2, '0')}, ${date.year}';
}

// Aug 05
String adminShortDate(DateTime date) {
  return '${_months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
}

// 12m ago, 1h ago, 3d ago
String adminTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// "240 Galle Road, Colombo 03" -> "Colombo 03"
String areaOf(String address) {
  final parts = address
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? '' : parts.last;
}

// "240 Galle Road, Colombo 03" -> "Colombo" (used for the filter chips)
String cityOf(String address) {
  final city = areaOf(address).replaceAll(RegExp(r'[0-9]'), '').trim();
  return city.isEmpty ? 'Other' : city;
}

// Counts per city, biggest first: {"Colombo": 16, "Kandy": 6}
Map<String, int> cityCounts(Iterable<String> cities) {
  final counts = <String, int>{};
  for (final city in cities) {
    counts[city] = (counts[city] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

// "The Gallery Café" -> "GC"
String initialsOf(String name) {
  final words = name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty && word.toLowerCase() != 'the')
      .toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

// Same name always gets the same soft colour pair
({Color background, Color foreground}) avatarColorsFor(String name) {
  const pairs = [
    (background: Color(0xFFFFF7ED), foreground: Color(0xFFEA580C)),
    (background: Color(0xFFFEFCE8), foreground: Color(0xFFCA8A04)),
    (background: Color(0xFFEFF6FF), foreground: Color(0xFF2563EB)),
    (background: Color(0xFFECFDF5), foreground: Color(0xFF059669)),
    (background: Color(0xFFF5F3FF), foreground: Color(0xFF7C3AED)),
  ];
  final int index = name.codeUnits.fold(0, (total, code) => total + code) % pairs.length;
  return pairs[index];
}
