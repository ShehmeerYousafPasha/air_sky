import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/constants/app_constants.dart';
import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/app_router.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/utils/app_feedback.dart';
import 'package:air_sky/features/auth/presentation/widgets/auth_visual_shell.dart';
import 'package:air_sky/shared/widgets/app_primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(authControllerProvider.notifier).clearState();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showFeedbackWithFallback(
    GoRouter router,
    String message, {
    AppFeedbackType type = AppFeedbackType.general,
  }) {
    final BuildContext? feedbackContext = mounted
        ? context
        : router.routerDelegate.navigatorKey.currentContext;

    if (feedbackContext == null) {
      return;
    }

    showAppFeedback(feedbackContext, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final bootstrap = ref.watch(firebaseBootstrapProvider);
    final ThemeData theme = Theme.of(context);
    const String bootstrapUserMessage =
        'Sign-in is temporarily unavailable. Please try again later.';

    return AuthVisualShell(
      title: 'Welcome back',
      subtitle:
          'Sign in to keep booking, track tickets, and continue with ${AppConstants.appName}.',
      badgeLabel: 'Secure Sign-In',
      leadingIcon: Icons.flight_takeoff_rounded,
      child: Form(
        key: _formKey,
        autovalidateMode: _showValidationErrors
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!bootstrap.isReady) ...<Widget>[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  bootstrapUserMessage,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(height: 14.h),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final String email = _emailController.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    showAppFeedback(
                      context,
                      'AirSky: Enter your email first.',
                      type: AppFeedbackType.error,
                    );
                    return;
                  }

                  await ref
                      .read(authControllerProvider.notifier)
                      .sendPasswordResetEmail(email: email);

                  if (!context.mounted) {
                    return;
                  }

                  final AsyncValue<void> result = ref.read(
                    authControllerProvider,
                  );
                  if (result.hasError) {
                    showAppFeedback(
                      context,
                      formatFirebaseAuthError(
                        result.error,
                        fallbackMessage: 'AirSky: Reset link not sent.',
                      ),
                      type: AppFeedbackType.error,
                    );
                    return;
                  }

                  showAppFeedback(
                    context,
                    'AirSky: Reset link sent.',
                    type: AppFeedbackType.success,
                  );
                },
                child: const Text('Forgot password?'),
              ),
            ),
            SizedBox(height: 6.h),
            AppPrimaryButton(
              label: 'Login',
              icon: Icons.login_rounded,
              isLoading: authState.isLoading,
              onPressed: () async {
                setState(() {
                  _showValidationErrors = true;
                });
                if (!_formKey.currentState!.validate()) {
                  return;
                }

                final authController = ref.read(
                  authControllerProvider.notifier,
                );
                final guestModeController = ref.read(
                  guestModeProvider.notifier,
                );
                final GoRouter router = ref.read(goRouterProvider);
                final ProviderContainer container = ProviderScope.containerOf(
                  context,
                  listen: false,
                );

                await authController.signIn(
                  email: _emailController.text.trim(),
                  password: _passwordController.text.trim(),
                );

                final AsyncValue<void> result = container.read(
                  authControllerProvider,
                );
                if (result.hasError) {
                  _showFeedbackWithFallback(
                    router,
                    formatFirebaseAuthError(
                      result.error,
                      fallbackMessage: 'AirSky: Login failed.',
                    ),
                    type: AppFeedbackType.error,
                  );
                  return;
                }

                await guestModeController.disableGuestMode();

                _showFeedbackWithFallback(
                  router,
                  'AirSky: Welcome back.',
                  type: AppFeedbackType.success,
                );

                authController.clearState();
              },
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(guestModeProvider.notifier).enableGuestMode();
                  if (!context.mounted) return;
                  context.go(RoutePaths.home);
                },
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Continue as Guest'),
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('No account?'),
                TextButton(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).clearState();
                    context.go(RoutePaths.signup);
                  },
                  child: const Text('Create one'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
