# TableEase

**Restaurant table booking and live queue app**, built with Flutter and Firebase.

TableEase helps diners skip the wait. Customers can see free tables live, book a table, or join a restaurant's digital queue from their phone. Restaurant staff manage tables, the waitlist and today's bookings from the same app, and every change shows up on both sides instantly. Admins approve new restaurants and watch the whole system from a live dashboard.

> IT3060 Human Computer Interaction – Group Project, SLIIT (2026)

---

## Features

### Customer
- Browse restaurants with photos, cuisine, price level, opening hours and live table count
- Book a table (date, time, guests, table type)
- Weekend bookings take a deposit payment (Rs. 500)
- View, track and cancel my bookings
- Join a restaurant's live queue and see my position and wait time
- "Table Ready" alert when staff call my number
- Notifications and profile (edit details, photo, logout)

### Staff
- Live table layout: 3×3 floor grid with Free / Occupied / Reserved status
- Tap a table to change its status, or use **Quick Seat**
- Live waitlist with party size filters: **Notify**, **Seat** or **Remove** guests
- Add walk-in customers to the queue
- Today's bookings with **Arrived** / **No-show**

### Admin
- Live dashboard: restaurants, today's bookings (vs yesterday), no-shows, pending requests
- Busy hours chart (5 PM – 10 PM) with the peak hour highlighted
- Review new restaurant registrations and **Approve** or **Reject** them
- Approved restaurants appear in the customer app straight away
- Manage all restaurants: search, filter by city, **Edit** details or **Remove**

### Restaurant registration
- New restaurant owners register from the staff login screen ("New restaurant? Register here")
- The request waits as "pending" until an admin reviews it

---

## Tech stack

| Part | Technology |
|---|---|
| App | Flutter (Dart) |
| Login | Firebase Authentication (email and password) |
| Database | Cloud Firestore (real-time streams) |
| Design | Figma |
| Version control | Git and GitHub (feature branches + pull requests) |

---

## How it works

- **Real-time updates.** Screens listen to Firestore with `StreamBuilder` and `.snapshots()`. When staff seat a guest or free a table, the customer's screen updates without a refresh.
- **Data-driven restaurants.** Restaurant details live in Firestore. A new restaurant can be added from the Firebase console with no code change. Restaurant photos are bundled in `assets/images/restaurants/`, and Firestore stores only the file names.
- **Role-based login.** Each user has a `role` (`customer`, `staff` or `admin`) in the `users` collection. After login the app opens the matching home screen.
- **Security rules.** `firestore.rules` makes sure customers can only see and change their own bookings, payments and queue entries. Only staff can change tables and manage the queue, and only admins can review registrations and add or delete restaurants.
- **Approval flow.** Owner registers → request saved as `pending` → admin approves → a new document is created in `restaurants` and the customer Home screen shows it live.

### Firestore collections

| Collection | What it stores |
|---|---|
| `users` | Profile and role of each user |
| `restaurants` | Restaurant details, live `tablesAvailable` and `waitMinutes` |
| `restaurants/{id}/tables` | The 9 tables of each restaurant and their status |
| `bookings` | Table bookings and their status |
| `payments` | Deposit payments for weekend bookings |
| `queues` | Live queue entries (app users and walk-ins) |
| `restaurant_requests` | New restaurant registrations (pending / approved / rejected) |

---

## HCI principles applied

- **Jakob's Law:** Restaurant cards follow the familiar layout of popular booking apps, with a large photo on top and details below.
- **Visibility of system status:** Live table counts, queue position, wait time and colour-coded table status.
- **Match with the real world:** `$`, `$$`, `$$$` price levels; a table floor plan that looks like a real dining hall.
- **Consistency:** One colour system (orange primary), the same bottom navigation bar and shared components across customer, staff and admin screens.
- **Error prevention:** Confirmation before removing a guest, cancelling a booking, rejecting a request or removing a restaurant, plus form validation on every input.
- **Accessibility:** Semantic labels on buttons, large touch targets, and status shown with text as well as colour.

---

## Getting started

### Requirements
- Flutter 3.47 or newer
- Android Studio with an Android emulator, or an Android phone with USB debugging on

### Run the app

```bash
git clone https://github.com/haq-ops/TableEase.git
cd TableEase
flutter pub get
flutter run
```

### Build an APK

```bash
flutter build apk --release --split-per-abi
```

Most phones use `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

### Test accounts

| Role | Email | Password |
|---|---|---|
| Customer | *add here* | *add here* |
| Staff | *add here* | *add here* |
| Admin | *add here* | *add here* |

---

## Project structure

```
lib/
├── main.dart
├── theme/            # App colours and theme
└── screens/
    ├── start/        # Splash, role selection, login, create account
    ├── customer/     # Home, restaurant details, booking, payment, my bookings
    ├── queue/        # Join queue, queue status, table ready
    ├── staff/        # Tables, queue, bookings, add walk-in
    ├── admin/        # Dashboard, requests, restaurants, registration form
    └── profile/      # Profile and edit profile
assets/
└── images/restaurants/   # Restaurant photos
firestore.rules           # Firestore security rules
```

---

## Team

| Member | Module |
|---|---|
| Faslulhaq Farees | Customer flow, start screens, integration |
| Kokulayasan | Queue and profile screens |
| Prathiesh | Staff screens |
| Siddarth | Admin screens, restaurant registration, start screens |

### Git workflow
- `main` holds the final submitted version
- `develop` is where all finished features are merged
- Each member works on their own `feature/...` branch and opens a pull request into `develop`