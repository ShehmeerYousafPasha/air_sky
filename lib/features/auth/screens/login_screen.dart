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
            SizedBox(height: 16.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.outlineVariant,
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Text(
                    'Or continue with',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.outlineVariant,
                    thickness: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final authController = ref.read(
                        authControllerProvider.notifier,
                      );
                      final guestModeController = ref.read(
                        guestModeProvider.notifier,
                      );
                      final GoRouter router = ref.read(goRouterProvider);
                      final ProviderContainer container =
                          ProviderScope.containerOf(context, listen: false);

                      await authController.signInWithGoogle();

                      final AsyncValue<void> result = container.read(
                        authControllerProvider,
                      );
                      if (result.hasError) {
                        _showFeedbackWithFallback(
                          router,
                          formatFirebaseAuthError(
                            result.error,
                            fallbackMessage: 'AirSky: Google sign-in failed.',
                          ),
                          type: AppFeedbackType.error,
                        );
                        return;
                      }

                      await guestModeController.disableGuestMode();

                      _showFeedbackWithFallback(
                        router,
                        'AirSky: Welcome!',
                        type: AppFeedbackType.success,
                      );

                      authController.clearState();
                    },
                    icon: const _GoogleBrandIcon(),
                    label: const Text('Google'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(guestModeProvider.notifier)
                          .enableGuestMode();
                      if (!context.mounted) return;
                      context.go(RoutePaths.home);
                    },
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('Guest'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleBrandIcon extends StatelessWidget {
  const _GoogleBrandIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _GoogleBrandIconPainter(),
    );
  }
}

class _GoogleBrandIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = size.width * 0.18;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(arcRect, -0.35, 1.15, false, bluePaint);
    canvas.drawArc(arcRect, 0.8, 1.2, false, redPaint);
    canvas.drawArc(arcRect, 2.0, 1.1, false, yellowPaint);
    canvas.drawArc(arcRect, 3.15, 1.15, false, greenPaint);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.56, center.dy),
      Offset(size.width * 0.88, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



