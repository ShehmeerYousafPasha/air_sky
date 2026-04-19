# AirSky - Book & Fly

AirSky is a Skyscanner-style Flutter app with Firebase Auth + Firestore booking,
dynamic flight simulation, offline caching, and clean architecture.

## Tech Stack

- flutter_riverpod
- go_router
- firebase_auth
- cloud_firestore
- hive + hive_flutter
- flutter_screenutil
- flutter_animate
- shimmer
- cached_network_image
- flutter_form_builder
- fl_chart
- qr_flutter

## Architecture and Folder Structure

The project uses feature-first clean architecture with a consistent presentation
layout.

Detailed guide: `docs/PROJECT_STRUCTURE.md`

Current structure:

```text
lib/
	app.dart
	main.dart
	firebase_options.dart

	core/
		constants/
		providers/
		router/
		theme/
		utils/

	services/

	shared/
		widgets/

	features/
		<feature>/
			data/
			domain/
			presentation/
				controllers/
				screens/
				widgets/
```

### Module Rules

- `screens/`: route-level pages only.
- `controllers/`: Riverpod/StateNotifier state and interaction logic.
- `widgets/`: reusable UI pieces limited to the same feature.
- `shared/widgets/`: cross-feature reusable widgets.

This structure is intended to keep onboarding and long-term maintenance simple
for you and other developers.

## Features

- Email/password signup, login, logout, auth persistence
- Auth-guarded routing for app flows
- Dynamic simulated flights with:
	- date-based pricing
	- weekend multiplier
	- random demand factor
- Flight results with sorting, filtering, shimmer loading, and empty states
- Full booking flow:
	- passenger form
	- seat selection
	- review
	- save booking to Firestore at users/{uid}/bookings/{bookingId}
- My Trips tabs for upcoming and completed bookings with QR tickets
- Profile page with dark mode toggle
- Offline support via Hive for recent searches and last search results

## Firebase Setup

The app compiles with placeholder Firebase config values.

1. Create a Firebase project (free tier is sufficient).
2. Enable Authentication (Email/Password).
3. Create Firestore database (test mode for development).
4. Run FlutterFire config and regenerate options:
	 - flutterfire configure
5. Replace placeholder values in lib/firebase_options.dart with generated values,
	 or let FlutterFire generate and overwrite that file.

## Run

1. flutter pub get
2. flutter run

### Live Map OpenSky Auth (Recommended)

OpenSky now uses OAuth2 client credentials for authenticated requests.

Without credentials, live map runs in anonymous mode and can hit `429` sooner.

1. Create an API client in your OpenSky account page.
2. Run the app with client credentials:
	- flutter run --dart-define=OPENSKY_CLIENT_ID=your_client_id --dart-define=OPENSKY_CLIENT_SECRET=your_client_secret

## Payment Mode (Spark Plan)

The project uses a local dummy payment flow with Firestore only.

1. Create booking as `unpaid`.
2. Tap Pay now.
3. Booking transitions `unpaid` -> `payment_processing` -> `paid`.
4. Ticket/QR unlock after `paid`.

No Stripe account and no Cloud Functions are required.

### Setup

1. Deploy Firestore rules:
	- firebase deploy --only firestore:rules
2. Run app:
	- flutter run

### Security Notes

- Firestore rules restrict payment status updates to the controlled local
	dummy transition.
- Clients cannot update unrelated booking fields during payment transitions.

## Validation

- flutter analyze
- flutter test
