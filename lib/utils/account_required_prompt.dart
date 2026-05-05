import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/route_paths.dart';

Future<void> goToLoginFromGuestSession(
  BuildContext context,
  WidgetRef ref,
) async {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  ref.read(authControllerProvider.notifier).clearState();
  await ref.read(guestModeProvider.notifier).disableGuestMode();
  if (!context.mounted) {
    return;
  }
  context.go(RoutePaths.login);
}

Future<void> goToSignupFromGuestSession(
  BuildContext context,
  WidgetRef ref,
) async {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  ref.read(authControllerProvider.notifier).clearState();
  await ref.read(guestModeProvider.notifier).disableGuestMode();
  if (!context.mounted) {
    return;
  }
  context.go(RoutePaths.signup);
}

Future<void> showAccountRequiredPrompt(
  BuildContext context,
  WidgetRef ref, {
  required String featureLabel,
}) async {
  final ThemeData theme = Theme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Sign in required',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in or create an account to $featureLabel.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your existing guest search stays available.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await goToLoginFromGuestSession(context, ref);
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Login'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await goToSignupFromGuestSession(context, ref);
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Signup'),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Continue as guest'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}



