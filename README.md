# AirSky: Book & Fly

AirSky is a Flutter travel app for browsing flights, booking trips, managing tickets, and viewing live flight data. Built with Firebase Auth and Firestore for persistence, Riverpod for state management, and the OpenSky API for live flights.

## What Ships Here

- **Authentication**: Email/password signup and login with email verification; guest mode for limited browsing
- **Onboarding**: Welcome flow on first app launch
- **Flight Search**: Search by route, date, passenger count, and cabin class with Schiphol API integration
- **Search Filtering & Sorting**: Sort by price or duration; filter by stops and price range
- **Local Caching**: Recent searches and last-search results cached via Hive for offline access
- **Flight Details & Booking**: Full booking flow with passenger information forms, seat selection, and booking review
- **Trip Management**: View booked flights in a trips list with QR ticket generation and display
- **Payment Verification**: Local payment flow guarded by Firestore security rules (no Cloud Functions required on Spark plan)
- **User Profile**: Edit profile details, toggle theme, and select preferred currency
- **Live Flight Map**: Real-time flight tracking with live position data
- **Notifications**: Local push notifications for booking and travel updates
- **AI Assistant**: In-app entry point for search suggestions and travel guidance

## Tech Stack

**State & Routing:**
- `flutter_riverpod` – State management with async support
- `go_router` – Navigation and deep linking

**Backend & Auth:**
- `firebase_auth` – User authentication with email verification
- `cloud_firestore` – Cloud database for users, bookings, and trips
- `firebase_core` – Firebase initialization

**Local Storage & Data:**
- `hive` + `hive_flutter` – Local caching (last search, recent searches, offline state)
- `intl` – Internationalization and number/date formatting

**UI & Animation:**
- `flutter_screenutil` – Responsive layout scaling
- `flutter_animate` – Stagger and entrance animations
- `shimmer` – Loading state shimmer effects
- `flutter_form_builder` + `form_builder_validators` – Form handling and validation
- `google_fonts` – Custom typography

**Maps & Charts:**
- `flutter_map` – Interactive map view for live flights
- `latlong2` – Latitude/longitude coordinate handling
- `fl_chart` – Chart rendering (fare trends, analytics)

**Media & Utility:**
- `cached_network_image` – Image caching and display
- `qr_flutter` – QR code generation for tickets
- `uuid` – Unique ID generation
- `google_sign_in` – Google OAuth signin
- `flutter_local_notifications` – Push notifications

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # Root widget and router setup
├── firebase_options.dart        # Firebase configuration
├── config/                      # App configuration and providers
├── services/                    # Core services (Firebase, Hive, notifications, etc.)
├── shared/                      # Shared widgets, theme, and utilities
├── utils/                       # Helper functions and constants
└── features/                    # Feature modules
    ├── auth/                    # Signup, login, email verification
    ├── onboarding/              # Welcome screens
    ├── splash/                  # Splash screen and initialization
    ├── flights/                 # Flight search, listing, details
    ├── booking/                 # Booking flow, passenger forms, seat selection
    ├── home/                    # Home dashboard
    ├── profile/                 # User profile and settings
    ├── live_map/                # Live flight tracking map
    ├── notifications/           # Notification handling and display
    └── ai_assistant/            # AI assistant feature
```

## App Flow

1. **Splash Screen**: Initializes Firebase, checks onboarding and auth state
2. **Onboarding**: First-time users see welcome screens before accessing the app
3. **Authentication**: Verified email login or guest mode signup/access
4. **Home Dashboard**: Authenticated users and guests land on the home screen
5. **Flight Search**: Enter route (Schiphol-connected), date, passengers, cabin class; results pulled from Schiphol API
6. **Search Caching**: Results and searches cached via Hive; previous results shown offline if fresh API data unavailable
7. **Booking Flow**: Select flight → enter passenger details → select seats → review and confirm → writes to Firestore
8. **Payment**: Local payment verification using Firestore rules (no backend functions needed)
9. **Trips & Tickets**: View booked flights with QR codes; mark as paid to complete booking
10. **Guest Upgrade**: Guest users can sign up at any point; login/signup routes always accessible

## Platform Support

- **iOS** (13.0+)
- **Android** (minSdk 23)
- **Web** (Chrome, Firefox, Safari)
- **Windows** (10+)
- **macOS** (11+)
- **Linux**

## Database Structure

**Firestore:**
```
users/
  {uid}/
    profile/          # User name, email, preferences
    bookings/         # Booking records with payment status

bookingRequests/      # Pending multi-passenger booking validations (optional)
```

**Hive Boxes:**
- `lastSearch` – Most recent search query and results
- `recentSearches` – List of past searches
- `userPreferences` – Theme, currency, language

## Known Notes

- Guest users can browse and search but cannot book; login/signup routes always accessible for upgrade
- Booking records include payment metadata (`paymentStatus`, `psid`, paid/due timestamps)
- Firestore security rules enforce payment transitions (unpaid → processing → paid)
- Flight map uses Schiphol data when credentials provided; falls back to OpenSky otherwise
- QR codes generated on-demand and embedded in trip details
- Email verification required before booking; resend emails available in auth flow
- Booking passengers include form validation, seat selection, and insurance options

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
