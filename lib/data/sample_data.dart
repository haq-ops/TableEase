import 'package:cloud_firestore/cloud_firestore.dart';

// Adds 4 sample restaurants to Firestore, only if there are none yet.
// This is for testing. The admin screens will add real restaurants later.
Future<void> addSampleRestaurants() async {
  final restaurants = FirebaseFirestore.instance.collection('restaurants');

  // Stop if restaurants already exist, so we never add duplicates
  final existing = await restaurants.limit(1).get();
  if (existing.docs.isNotEmpty) return;

  final samples = [
    {
      'name': 'The Gallery Café',
      'address': '240 Galle Road, Colombo 03',
      'cuisine': 'Casual Fine Dining',
      'priceLevel': '\$\$\$',
      'phone': '+94112345678',
      'image': 'gallery_cafe.jpg',
      'images': ['gallery_cafe.jpg', 'gallery_cafe_2.jpg', 'gallery_cafe_3.jpg'],
      'tablesAvailable': 3,
      'waitMinutes': 0,
      'hours': '11:00 AM – 10:30 PM',
      'tags': ['Sri Lankan', 'Continental', 'Outdoor Patio', 'Good for Dinner'],
      'description':
      'Housed in the former offices of world-renowned architect Geoffrey '
          'Bawa, offering curated seasonal plates and artisan cocktails in a '
          'calm courtyard setting.',
    },
    {
      'name': 'Bistro Central',
      'address': 'Park Street Mews, Colombo 02',
      'cuisine': 'Italian',
      'priceLevel': '\$\$',
      'phone': '+94112345679',
      'image': 'bistro_central.jpg',
      'images': [
        'bistro_central.jpg',
        'bistro_central_2.jpg',
        'bistro_central_3.jpg',
      ],
      'tablesAvailable': 0,
      'waitMinutes': 15,
      'hours': '12:00 PM – 11:00 PM',
      'tags': ['Pasta', 'Pizza', 'Family Friendly', 'Accepts Cards'],
      'description':
      'A cosy city bistro serving handmade pasta, wood-fired pizza and '
          'classic desserts, loved by families and office groups alike.',
    },
    {
      'name': 'Urban Wok Kitchen',
      'address': 'Havelock Road, Colombo 05',
      'cuisine': 'Chinese',
      'priceLevel': '\$\$',
      'phone': '+94112345680',
      'image': 'urban_wok.jpg',
      'images': ['urban_wok.jpg', 'urban_wok_2.jpg', 'urban_wok_3.jpg'],
      'tablesAvailable': 3,
      'waitMinutes': 0,
      'hours': '11:30 AM – 10:00 PM',
      'tags': ['Asian Fusion', 'Quick Service', 'Good for Lunch'],
      'description':
      'Fresh stir-fries, noodles and dumplings cooked to order in an open '
          'kitchen, with quick service for busy lunch hours.',
    },
    {
      'name': 'Ocean Breeze Diner',
      'address': 'Marine Drive, Bambalapitiya',
      'cuisine': 'Seafood',
      'priceLevel': '\$\$\$',
      'phone': '+94112345681',
      'image': 'ocean_breeze.jpg',
      'images': ['ocean_breeze.jpg', 'ocean_breeze_2.jpg', 'ocean_breeze_3.jpg'],
      'tablesAvailable': 0,
      'waitMinutes': 20,
      'hours': '12:00 PM – 11:30 PM',
      'tags': ['Sri Lankan', 'Sea View', 'Good for Dinner', 'Accepts Cash'],
      'description':
      'Fresh catch of the day grilled by the sea, with a relaxed '
          'beach-side atmosphere and sunset views over the Indian Ocean.',
    },
  ];

  for (final restaurant in samples) {
    await restaurants.add({
      ...restaurant,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}