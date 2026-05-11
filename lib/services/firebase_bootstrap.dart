import 'package:firebase_core/firebase_core.dart';

import 'package:air_sky/firebase_options.dart';

/// Result object returned after Firebase initialization attempt.
///
/// Indicates whether Firebase initialization was successful and provides
/// an error message if initialization failed.
class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.isReady, this.errorMessage});

  /// True if Firebase initialized successfully; false otherwise.
  final bool isReady;
  
  /// Human-readable error message if initialization failed; null if successful.
  final String? errorMessage;
}

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      // Prevent duplicate initialization if Firebase is already set up
      if (Firebase.apps.isNotEmpty) {
        return const FirebaseBootstrapResult(isReady: true);
      }

      // Initialize Firebase with platform-specific configuration
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return const FirebaseBootstrapResult(isReady: true);
    } on FirebaseException catch (error) {
      // Treat duplicate-app errors as success (already initialized)
      if (error.code == 'duplicate-app') {
        return const FirebaseBootstrapResult(isReady: true);
      }

      // Return user-friendly error message for other Firebase errors
      return FirebaseBootstrapResult(
        isReady: false,
        errorMessage:
            'Service initialization is unavailable right now. Please try again later.',
      );
    } catch (error) {
      // Handle unexpected errors gracefully
      return FirebaseBootstrapResult(
        isReady: false,
        errorMessage:
            'Service initialization is unavailable right now. Please try again later.',
      );
    }
  }
}



