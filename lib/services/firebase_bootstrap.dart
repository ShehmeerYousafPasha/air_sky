import 'package:firebase_core/firebase_core.dart';

import 'package:air_sky/firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.isReady, this.errorMessage});

  final bool isReady;
  final String? errorMessage;
}

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        return const FirebaseBootstrapResult(isReady: true);
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return const FirebaseBootstrapResult(isReady: true);
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app') {
        return const FirebaseBootstrapResult(isReady: true);
      }

      return FirebaseBootstrapResult(
        isReady: false,
        errorMessage:
            'Service initialization is unavailable right now. Please try again later.',
      );
    } catch (error) {
      return FirebaseBootstrapResult(
        isReady: false,
        errorMessage:
            'Service initialization is unavailable right now. Please try again later.',
      );
    }
  }
}



