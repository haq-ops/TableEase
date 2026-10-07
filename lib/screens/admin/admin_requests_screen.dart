import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'admin_main_screen.dart';

// Screen 22: new restaurant registrations waiting for review.
// Approve -> a new document is created in "restaurants" (customers see it
// on their Home screen straight away) and the request becomes "approved".
// Reject  -> the request becomes "rejected".
class AdminRequestsScreen extends StatefulWidget {
  final ValueChanged<int> onOpenTab;

  const AdminRequestsScreen({super.key, required this.onOpenTab});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  String _city = 'All';

  // Created once, so tapping a filter chip does not restart the stream
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = pendingRequestsStream();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminHeader(onAvatar: () => widget.onOpenTab(3)),
          Expanded(
            // READ (live): pending registrations
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _requestsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const AdminMessage(
                    text: 'Could not load requests. Check your internet.',
                    icon: Icons.wifi_off,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Newest first
                final requests = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final ta = toDateTime(a.data()['createdAt']);
                    final tb = toDateTime(b.data()['createdAt']);
                    if (ta == null || tb == null) return 0;
                    return tb.compareTo(ta);
                  });

                return _content(requests);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> requests,
  ) {
    String cityOfRequest(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return cityOf((doc.data()['address'] ?? '').toString());
    }

    final counts = cityCounts(requests.map(cityOfRequest));
    // If the selected city has no requests left, go back to "All"
    final String city = counts.containsKey(_city) ? _city : 'All';
    final shown = city == 'All'
        ? requests
        : requests.where((doc) => cityOfRequest(doc) == city).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        // Title and pending count
        Row(
          children: [
            const Expanded(
              child: Text(
                'New Requests',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            AdminChip(
              text: '${requests.length} Pending',
              background: const Color(0xFFFEF3C7),
              foreground: const Color(0xFFB45309),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Partner registrations • Requires verification & onboarding review',
          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        const SizedBox(height: 14),

        if (requests.isEmpty)
          const AdminMessage(
            text: 'No pending requests right now.\n'
                'New restaurant registrations will appear here.',
            icon: Icons.task_alt,
          )
        else ...[
          AdminFilterChips(
            counts: counts,
            total: requests.length,
            selected: city,
            onSelected: (value) => setState(() => _city = value),
          ),
          const SizedBox(height: 14),
          for (final request in shown) ...[
            _RequestCard(request: request),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

// One registration card with Approve / Reject
class _RequestCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final data = request.data();
    final String name = (data['name'] ?? 'Unnamed restaurant').toString();
    final String cuisine = (data['cuisine'] ?? '').toString();
    final String owner = (data['owner'] ?? '-').toString();
    final String address = (data['address'] ?? '').toString();
    final String document = (data['documentName'] ?? '').toString();
    final int tables = ((data['tables'] ?? 0) as num).toInt();
    final DateTime? created = toDateTime(data['createdAt']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Initials, name, cuisine, location, date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminInitialsBox(name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (cuisine.isNotEmpty)
                          AdminChip(
                            text: cuisine,
                            background: const Color(0xFFEFF6FF),
                            foreground: const Color(0xFF2563EB),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            areaOf(address),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                        if (created != null)
                          Text(
                            adminDate(created),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Owner and capacity
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _info('OWNER', owner)),
                const SizedBox(width: 10),
                Expanded(
                  child: _info(
                    'CAPACITY',
                    // about 4 seats per table
                    '$tables Tables (${tables * 4} Seats)',
                  ),
                ),
              ],
            ),
          ),

          // Uploaded verification document (file name only)
          if (document.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.attach_file,
                  size: 15,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    document,
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
          const SizedBox(height: 12),

          // Approve / Reject
          Row(
            children: [
              Expanded(
                child: AdminButton(
                  label: 'Approve',
                  icon: Icons.check,
                  background: kApproveGreen,
                  foreground: Colors.white,
                  onTap: () => approveRequest(context, request),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminButton(
                  label: 'Reject',
                  icon: Icons.close,
                  background: kRejectRed,
                  foreground: Colors.white,
                  onTap: () => rejectRequest(context, request),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionLabel(label),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

// CREATE + UPDATE: approve a registration.
// Adds the restaurant to "restaurants" and marks the request "approved"
// in one batch, so both happen together or not at all.
Future<void> approveRequest(
  BuildContext context,
  DocumentSnapshot<Map<String, dynamic>> request,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = request.data() ?? {};
  final db = FirebaseFirestore.instance;

  final String name = (data['name'] ?? '').toString();
  final String cuisine = (data['cuisine'] ?? 'Dining').toString();
  final String address = (data['address'] ?? '').toString();
  final int tables = ((data['tables'] ?? 0) as num).toInt();

  // New restaurants use a generic photo until real photos are added
  const String photo = 'default_restaurant.jpg';

  final restaurantRef = db.collection('restaurants').doc();
  final batch = db.batch();

  batch.set(restaurantRef, {
    'name': name,
    'cuisine': cuisine,
    'address': address,
    'city': cityOf(address),
    'owner': (data['owner'] ?? '').toString(),
    'phone': (data['phone'] ?? '').toString(),
    'email': (data['email'] ?? '').toString(),
    'hours': '10:00 AM - 10:00 PM',
    'description': '$name is new on TableEase. Book a table or join the '
        'queue from your phone.',
    'priceLevel': r'$$',
    'image': photo,
    'images': [photo, photo, photo],
    'tags': [cuisine],
    'tablesAvailable': tables,
    'totalTables': tables,
    'waitMinutes': 0,
    'createdAt': FieldValue.serverTimestamp(),
  });

  batch.update(request.reference, {
    'status': 'approved',
    'reviewedAt': FieldValue.serverTimestamp(),
    'restaurantId': restaurantRef.id,
  });

  try {
    await batch.commit();
    messenger.showSnackBar(
      SnackBar(content: Text('$name approved. Customers can now see it.')),
    );
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not approve. Please try again.')),
    );
  }
}

// UPDATE: reject a registration (asks first, because it cannot be undone
// from the app)
Future<void> rejectRequest(
  BuildContext context,
  DocumentSnapshot<Map<String, dynamic>> request,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final String name = (request.data()?['name'] ?? 'this restaurant').toString();

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Reject this request?'),
      content: Text('The registration from "$name" will be rejected.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Reject',
            style: TextStyle(color: kRejectRed, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await request.reference.update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    messenger.showSnackBar(
      SnackBar(content: Text('Request from $name rejected.')),
    );
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not reject. Please try again.')),
    );
  }
}
