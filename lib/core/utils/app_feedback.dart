import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:air_sky/core/theme/app_theme.dart';

enum AppFeedbackType { general, success, error }

void showAppFeedback(
  BuildContext context,
  String message, {
  AppFeedbackType type = AppFeedbackType.general,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String displayMessage = message.startsWith('AirSky:')
      ? message
      : 'AirSky: $message';

  Color? backgroundColor;
  if (type == AppFeedbackType.error) {
    backgroundColor = AppTheme.error;
  } else if (type == AppFeedbackType.success) {
    backgroundColor = AppTheme.success;
  }

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(displayMessage), backgroundColor: backgroundColor),
  );
}

String formatFirebaseAuthError(
  Object? error, {
  String fallbackMessage = 'Authentication failed. Please try again.',
}) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'AirSky: Email already in use.';
      case 'invalid-email':
        return 'AirSky: Enter a valid email.';
      case 'weak-password':
        return 'AirSky: Password is too weak.';
      case 'user-not-found':
        return 'AirSky: No account found.';
      case 'wrong-password':
        return 'AirSky: Wrong password.';
      case 'invalid-credential':
        return 'AirSky: Check your email and password.';
      case 'email-not-verified':
        return error.message ?? 'AirSky: Verify your email first.';
      case 'too-many-requests':
        return 'AirSky: Too many attempts.';
      case 'network-request-failed':
        return 'AirSky: Check your connection.';
      case 'requires-recent-login':
        return 'AirSky: Sign in again.';
      case 'account-exists-with-different-credential':
        return 'AirSky: Use your original sign-in method.';
      case 'operation-not-allowed':
        return 'AirSky: Sign-in method disabled.';
      case 'firebase-not-configured':
        return 'AirSky: Service is temporarily unavailable. Please try again later.';
      default:
        return fallbackMessage;
    }
  }

  if (error == null) {
    return fallbackMessage;
  }

  return fallbackMessage;
}
