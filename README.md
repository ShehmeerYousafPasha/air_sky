# AirSky: Book & Fly

AirSky is a Flutter travel app for browsing flights, booking trips, tracking tickets, and checking live aircraft on a map. This branch uses Firebase Auth and Firestore for account and booking persistence, Hive for local state and cached searches, a local deterministic flight generator for search results, and OpenSky for the live radar map.

## What Ships Here

- Email/password signup and login with email verification
- Guest mode for limited browsing without an account
- Onboarding flow on first launch
- Flight search with route, date, passenger count, and cabin class
- Sort by cheapest or fastest, plus stop and price filters
- Cached last-search results and recent searches through Hive
- Flight detail and booking flow with passenger forms, seat selection, and review
- Firestore-backed trips list with QR ticket display
- Local payment verification loop using Firestore rules only
- Profile editing, theme toggle, and currency selection
- Live flights map backed by OpenSky
- In-app AI assistant entry point for search help and travel guidance

## Tech Stack

- flutter_riverpod
- go_router
- firebase_auth
- cloud_firestore
- hive + hive_flutter
- flutter_screenutil
- flutter_animate
- flutter_form_builder
- flutter_map
- fl_chart
- shimmer
- cached_network_image
- qr_flutter
- google_fonts
- intl

## App Flow

1. Splash screen checks onboarding, auth state, and guest mode.
2. If onboarding is incomplete, the app sends the user through the onboarding pages.
3. Verified users and guests land on Home.
4. Login requires a verified email address.
5. Guest users can search and browse, but booking and sensitive details are restricted.
6. Search results are generated locally, cached, and reused if the app cannot load fresh results.
7. Booking writes to Firestore under `users/{uid}/bookings/{bookingId}`.
8. Trips can be marked paid through the local dummy payment verification flow.

## Project Structure

This app follows a feature-first layout with app-level configuration isolated in `config/`, reusable services in `services/`, and cross-feature widgets in `shared/`.

```text
lib/
  app.dart
  main.dart
  firebase_options.dart
  config/
    app_constants.dart
    app_providers.dart
    app_router.dart
    app_theme.dart
    currency_controller.dart
    hive_constants.dart
    route_paths.dart
    theme_mode_controller.dart
  services/
    firebase_bootstrap.dart
    flight_service.dart
    local_storage_service.dart
  shared/
    app_primary_button.dart
    airport_autocomplete_field.dart
    empty_state_view.dart
    flight_result_card.dart
    flight_shimmer_list.dart
    ticket_card.dart
    ticket_shimmer_list.dart
  utils/
    account_required_prompt.dart
    app_feedback.dart
    date_time_utils.dart
    id_generator.dart
    price_formatter.dart
  features/
    auth/
    booking/
    flights/
    home/
    live_map/
    onboarding/
    splash/
    profile/
    ai_assistant/
```

Guidelines used in the codebase:

- `screens/` are route-level pages.
- `services/` and controllers hold business logic and state.
- `shared/` contains reusable UI pieces used across multiple features.
- Feature-specific widgets stay inside their feature folder unless they are reused broadly.

The main wiring points are:

- `main.dart` bootstraps Flutter, Hive, and Firebase before calling `AirSkyApp`.
- `app.dart` assembles `MaterialApp.router`, theme selection, and responsive layout.
- `config/app_router.dart` owns route guards for onboarding, auth, and guest mode.
- `config/app_providers.dart` exposes the Riverpod graph for auth, bookings, flights, theme, currency, and storage.
- `services/local_storage_service.dart` owns all Hive reads and writes.
- `services/flight_service.dart` generates deterministic flight results and fare trends.
- `features/booking/services/booking_repository_impl.dart` writes bookings and runs the local payment transition.
- `features/live_map/services/open_sky_live_flights_service.dart` handles OpenSky live aircraft requests.

## Core Features

### Authentication

- Signup sends a verification email and stores the user profile in Firestore.
- Login refuses unverified accounts.
- Logout clears the session and returns the user to login.
- Guest mode is stored locally and can be upgraded to a real account later.

### Flights

- Flight search is route-based and uses a deterministic local generator.
- Results vary by route distance, cabin class, stop count, demand factor, and travel date.
- Search results are sorted by price or duration.
- Filters support maximum stops and maximum price.
- Recent searches and last results are cached in Hive.

### Booking

- Booking collects passenger details, seat assignments, and a review step.
- The first passenger is prefixed from the current user profile when possible.
- Bookings are saved to Firestore and rendered in My Trips.
- The booking model keeps legacy single-passenger fields for backward compatibility.

### Payment

- This branch uses a local dummy payment flow instead of Stripe or Cloud Functions.
- A booking starts as `unpaid`.
- Tap Pay Now to move it to `payment_processing`.
- Enter a transaction reference like `TXN-AB12CD34` to mark it `paid`.
- Firestore rules only allow the controlled transition, which keeps the flow serverless.

### Trips and Profile

- My Trips groups bookings into upcoming and completed tabs.
- QR ticket cards unlock once a booking is marked paid.
- Profile editing stores name, phone, gender, and date of birth in Firestore.
- Theme and currency are persisted locally.

### Live Map

- The live map renders OpenSky aircraft over a regional map view.
- Authenticated OpenSky requests can use OAuth2 client credentials.
- Without credentials, the map still runs but can rate limit faster.

### AI Assistant

- The floating assistant can help with flight discovery, price insight, and travel prep.
- It is available on the main app screens as a draggable action button.

## Requirements

- Flutter SDK compatible with the package constraints in `pubspec.yaml`
- Firebase project with Auth and Firestore enabled
- OpenSky client credentials if you want authenticated live-map requests

## Firebase Setup

1. Create a Firebase project.
2. Enable Authentication with Email/Password.
3. Create a Firestore database.
4. Run FlutterFire configuration and regenerate `lib/firebase_options.dart`.
5. Make sure Android and other platform files are generated for your project.

This app ships with Firestore rules in `firestore.rules` and a `firebase.json` that only deploys those rules. No Cloud Functions are required.

### Firestore Rules

Deploy the rules with:

```bash
firebase deploy --only firestore:rules
```

The rules restrict booking ownership and only allow the controlled payment transition used by the app.

## Run

```bash
flutter pub get
flutter run
```

If you want to run the live map with authenticated OpenSky access, pass your client credentials at launch:

```bash
flutter run --dart-define=OPENSKY_CLIENT_ID=your_client_id --dart-define=OPENSKY_CLIENT_SECRET=your_client_secret
```

## Local Storage

Hive stores:

- app theme mode
- selected currency
- onboarding completion state
- guest mode state
- recent searches
- last search results

## Validation

```bash
flutter analyze
flutter test
```

## Notes

- Login requires a verified email address.
- Guest mode limits access to sorting, filters, booking, details, and synced trips.
- The app uses a clean, feature-first layout rather than a single large module tree.
