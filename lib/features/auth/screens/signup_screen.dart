import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/config/app_constants.dart';
import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/config/app_router.dart';
import 'package:air_sky/config/route_paths.dart';
import 'package:air_sky/utils/app_feedback.dart';
import 'package:air_sky/features/auth/components/auth_visual_shell.dart';
import 'package:air_sky/shared/app_primary_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
    final ThemeData theme = Theme.of(context);

    return AuthVisualShell(
      title: 'Create Your Account',
      subtitle:
          'Join ${AppConstants.appName} to save trips, manage tickets, and book faster across devices.',
      badgeLabel: 'New Traveler',
      leadingIcon: Icons.airplane_ticket_rounded,
      child: Form(
        key: _formKey,
        autovalidateMode: _showValidationErrors
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13.r),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 16.sp,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Verification email will be sent after signup.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (String? value) {
                if (value == null || value.trim().length < 2) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            SizedBox(height: 12.h),
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
                hintText: 'Minimum 6 characters',
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
            SizedBox(height: 12.h),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (String? value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            AppPrimaryButton(
              label: 'Create account',
              icon: Icons.person_add_alt_1_rounded,
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

                await authController.signUp(
                  name: _nameController.text.trim(),
                  email: _emailController.text.trim(),
                  password: _passwordController.text.trim(),
                );

                final AsyncValue<void> result = container.read(
                  authControllerProvider,
                );
                if (result.hasError) {
                  final String message = formatFirebaseAuthError(
                    result.error,
                    fallbackMessage: 'AirSky: Signup failed.',
                  );
                  _showFeedbackWithFallback(
                    router,
                    message,
                    type: AppFeedbackType.error,
                  );
                } else {
                  await guestModeController.disableGuestMode();
                  _showFeedbackWithFallback(
                    router,
                    'AirSky: Account created successfully. Verification email sent.',
                    type: AppFeedbackType.success,
                  );
                  router.go(RoutePaths.login);
                }

                authController.clearState();
              },
            ),
            SizedBox(height: 10.h),
            Align(
              child: TextButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).clearState();
                  context.go(RoutePaths.login);
                },
                child: const Text('Already have an account? Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



