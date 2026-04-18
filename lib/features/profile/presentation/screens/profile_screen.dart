import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/theme/app_theme.dart';
import 'package:air_sky/core/utils/account_required_prompt.dart';
import 'package:air_sky/core/utils/app_feedback.dart';
import 'package:air_sky/core/utils/date_time_utils.dart';
import 'package:air_sky/core/utils/price_formatter.dart';
import 'package:air_sky/shared/widgets/app_primary_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const List<String> _genderOptions = <String>[
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  void _showMessage(
    BuildContext context,
    String message, {
    AppFeedbackType type = AppFeedbackType.general,
  }) {
    showAppFeedback(context, message, type: type);
  }

  String _resolveDisplayName({
    required bool isGuest,
    required String? firestoreName,
    required String? authDisplayName,
    required String? email,
  }) {
    if (isGuest) {
      return 'Guest traveler';
    }

    if (firestoreName != null && firestoreName.trim().isNotEmpty) {
      return firestoreName.trim();
    }

    if (authDisplayName != null && authDisplayName.trim().isNotEmpty) {
      return authDisplayName.trim();
    }

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'AirSky user';
  }

  String _readProfileString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return '';
    }

    for (final String key in keys) {
      final dynamic value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  DateTime? _readProfileDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  String _formatDateOfBirthLabel(DateTime? value) {
    if (value == null) {
      return 'Not added';
    }
    return value.toTicketDate();
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref, {
    required String currentName,
    required String currentPhoneNumber,
    required DateTime? currentDateOfBirth,
    required String currentGender,
  }) async {
    final bool isGuest = ref.read(guestModeProvider);
    final User? user = ref.read(authStateChangesProvider).valueOrNull;

    if (isGuest || user == null) {
      await showAccountRequiredPrompt(
        context,
        ref,
        featureLabel: 'edit your profile and account settings',
      );
      return;
    }

    try {
      final _ProfileEditResult? result = await showDialog<_ProfileEditResult>(
        context: context,
        builder: (BuildContext dialogContext) {
          return _EditProfileDialog(
            initialName: currentName,
            initialPhoneNumber: currentPhoneNumber,
            initialDateOfBirth: currentDateOfBirth,
            initialGender: _genderOptions.contains(currentGender)
                ? currentGender
                : _genderOptions.last,
            genderOptions: _genderOptions,
          );
        },
      );

      if (!context.mounted || result == null) {
        return;
      }

      final String normalizedName = result.name.trim();
      if (normalizedName.length < 2) {
        _showMessage(
          context,
          'AirSky: Name too short.',
          type: AppFeedbackType.error,
        );
        return;
      }

      final String normalizedPhone = result.phoneNumber.trim();
      if (normalizedPhone.isNotEmpty && normalizedPhone.length < 7) {
        _showMessage(
          context,
          'AirSky: Enter a valid phone.',
          type: AppFeedbackType.error,
        );
        return;
      }

      if (result.dateOfBirth != null &&
          result.dateOfBirth!.isAfter(DateTime.now())) {
        _showMessage(
          context,
          'AirSky: Check date of birth.',
          type: AppFeedbackType.error,
        );
        return;
      }

      if (normalizedName != currentName.trim()) {
        await user.updateDisplayName(normalizedName);
      }

      final Map<String, dynamic> payload = <String, dynamic>{
        'uid': user.uid,
        'name': normalizedName,
        'gender': result.gender,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (user.email != null) {
        payload['email'] = user.email;
      }

      payload['phoneNumber'] = normalizedPhone.isEmpty
          ? FieldValue.delete()
          : normalizedPhone;
      payload['dateOfBirth'] = result.dateOfBirth == null
          ? FieldValue.delete()
          : Timestamp.fromDate(result.dateOfBirth!);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        'AirSky: Profile saved.',
        type: AppFeedbackType.success,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showMessage(
        context,
        formatFirebaseAuthError(
          error,
          fallbackMessage: 'AirSky: Profile update failed.',
        ),
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _sendPasswordResetFromProfile(
    BuildContext context,
    WidgetRef ref,
    String? email,
  ) async {
    final String targetEmail = email?.trim() ?? '';
    if (targetEmail.isEmpty) {
      _showMessage(
        context,
        'AirSky: No email on file.',
        type: AppFeedbackType.error,
      );
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(email: targetEmail);

    if (!context.mounted) {
      return;
    }

    final AsyncValue<void> result = ref.read(authControllerProvider);
    if (result.hasError) {
      _showMessage(
        context,
        formatFirebaseAuthError(
          result.error,
          fallbackMessage: 'AirSky: Reset link not sent.',
        ),
        type: AppFeedbackType.error,
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      'AirSky: Reset link sent.',
      type: AppFeedbackType.success,
    );
  }

  Future<void> _handleSessionExit(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) {
      return;
    }
    final AsyncValue<void> result = ref.read(authControllerProvider);
    if (result.hasError) {
      _showMessage(
        context,
        formatFirebaseAuthError(
          result.error,
          fallbackMessage: 'AirSky: Logout failed.',
        ),
        type: AppFeedbackType.error,
      );
      return;
    }

    await ref.read(guestModeProvider.notifier).disableGuestMode();
    if (!context.mounted) {
      return;
    }

    _showMessage(context, 'AirSky: Logged out.', type: AppFeedbackType.success);

    if (context.mounted) {
      context.go(RoutePaths.login);
    }
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm logout'),
          content: const Text(
            'Are you sure you want to logout from your account?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(authStateChangesProvider).valueOrNull;
    final bool isGuest = ref.watch(guestModeProvider);
    final AsyncValue<void> authState = ref.watch(authControllerProvider);
    final ThemeMode mode = ref.watch(themeModeControllerProvider);
    final AppCurrency currency = ref.watch(currencyControllerProvider);
    final String? firestoreName = ref
        .watch(userProfileNameProvider)
        .valueOrNull;
    final Map<String, dynamic>? profileData = ref
        .watch(userProfileDataProvider)
        .valueOrNull;

    final String phoneNumber = _readProfileString(profileData, const <String>[
      'phoneNumber',
      'phone',
    ]);
    final DateTime? dateOfBirth = _readProfileDate(profileData?['dateOfBirth']);
    final String gender = _readProfileString(profileData, const <String>[
      'gender',
    ]);

    final String displayName = _resolveDisplayName(
      isGuest: isGuest,
      firestoreName: firestoreName,
      authDisplayName: user?.displayName,
      email: user?.email,
    );

    final String accountEmail = isGuest ? '' : (user?.email ?? 'Not added');
    final String accountPhone = isGuest
        ? 'Sign in required'
        : (phoneNumber.isEmpty ? 'Not added' : phoneNumber);
    final String accountDateOfBirth = isGuest
        ? 'Sign in required'
        : _formatDateOfBirthLabel(dateOfBirth);
    final String accountGender = isGuest
        ? 'Sign in required'
        : (gender.isEmpty ? 'Not added' : gender);

    final String subtitle = isGuest
        ? 'Browse routes now. Sign in to sync trips and tickets.'
        : (user?.email ?? 'No account linked');

    final String themeLabel = switch (mode) {
      ThemeMode.dark => 'Dark mode',
      ThemeMode.light => 'Light mode',
      _ => 'System theme',
    };
    final String currencyLabel = PriceFormatter.currencyLabel(currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
        children: <Widget>[
          _ProfileHeroCard(
            name: displayName,
            subtitle: subtitle,
            statusLabel: isGuest ? 'Guest' : 'Signed in',
            themeLabel: themeLabel,
            isGuest: isGuest,
            accountEmail: accountEmail,
            accountPhone: accountPhone,
            accountDateOfBirth: accountDateOfBirth,
            accountGender: accountGender,
          ),
          SizedBox(height: 12.h),
          const _SectionLabel(title: 'Travel'),
          SizedBox(height: 8.h),
          _ProfileSurface(
            child: Column(
              children: <Widget>[
                _ProfileMenuTile(
                  icon: Icons.airplane_ticket_outlined,
                  title: 'My trips',
                  subtitle: 'View upcoming and completed journeys',
                  onTap: () => context.push(RoutePaths.myTrips),
                ),
                Divider(height: 1.h),
                _ProfileMenuTile(
                  icon: Icons.search_rounded,
                  title: 'Find flights',
                  subtitle: 'Search routes and compare fares',
                  onTap: () => context.push(RoutePaths.search),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          const _SectionLabel(title: 'Preferences'),
          SizedBox(height: 8.h),
          _ProfileSurface(
            child: Column(
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                  leading: const _LeadingIcon(icon: Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Switch between light and dark theme'),
                  trailing: Switch.adaptive(
                    value: mode == ThemeMode.dark,
                    onChanged: (_) => ref
                        .read(themeModeControllerProvider.notifier)
                        .toggleTheme(),
                  ),
                ),
                Divider(height: 1.h),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                  leading: const _LeadingIcon(
                    icon: Icons.currency_exchange_rounded,
                  ),
                  title: const Text('Currency'),
                  subtitle: Text('Display prices in $currencyLabel'),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppCurrency>(
                      value: currency,
                      isDense: true,
                      onChanged: (AppCurrency? value) {
                        if (value == null) {
                          return;
                        }
                        ref
                            .read(currencyControllerProvider.notifier)
                            .setCurrency(value);
                      },
                      items: AppCurrency.values
                          .map(
                            (AppCurrency value) =>
                                DropdownMenuItem<AppCurrency>(
                                  value: value,
                                  child: Text(
                                    PriceFormatter.currencyCode(value),
                                  ),
                                ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isGuest && user != null) ...<Widget>[
            SizedBox(height: 12.h),
            const _SectionLabel(title: 'Account'),
            SizedBox(height: 8.h),
            _ProfileSurface(
              child: Column(
                children: <Widget>[
                  _ProfileMenuTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit profile',
                    subtitle:
                        'Update name, phone number, date of birth, and gender',
                    onTap: () => _editProfile(
                      context,
                      ref,
                      currentName: displayName,
                      currentPhoneNumber: phoneNumber,
                      currentDateOfBirth: dateOfBirth,
                      currentGender: gender,
                    ),
                  ),
                  Divider(height: 1.h),
                  _ProfileMenuTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change password',
                    subtitle: 'Send a secure reset link to your email',
                    onTap: () =>
                        _sendPasswordResetFromProfile(context, ref, user.email),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 16.h),
          if (isGuest)
            Row(
              children: <Widget>[
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Login',
                    icon: Icons.login_rounded,
                    onPressed: () => goToLoginFromGuestSession(context, ref),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => goToSignupFromGuestSession(context, ref),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Signup'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48.h),
                    ),
                  ),
                ),
              ],
            )
          else
            AppPrimaryButton(
              label: 'Logout',
              icon: Icons.logout_rounded,
              isLoading: authState.isLoading,
              onPressed: () async {
                final bool shouldLogout = await _confirmLogout(context);
                if (!context.mounted || !shouldLogout) {
                  return;
                }
                await _handleSessionExit(context, ref);
              },
            ),
        ],
      ),
    );
  }
}

class _ProfileEditResult {
  const _ProfileEditResult({
    required this.name,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.gender,
  });

  final String name;
  final String phoneNumber;
  final DateTime? dateOfBirth;
  final String gender;
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.initialPhoneNumber,
    required this.initialDateOfBirth,
    required this.initialGender,
    required this.genderOptions,
  });

  final String initialName;
  final String initialPhoneNumber;
  final DateTime? initialDateOfBirth;
  final String initialGender;
  final List<String> genderOptions;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late DateTime? _selectedDate;
  late String _selectedGender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhoneNumber);
    _selectedDate = widget.initialDateOfBirth;
    _selectedGender = widget.initialGender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _selectedDate ?? DateTime(now.year - 20, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDate: initialDate,
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _ProfileEditResult(
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        dateOfBirth: _selectedDate,
        gender: _selectedGender,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+92 300 1234567',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            SizedBox(height: 12.h),
            InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select your date of birth'
                      : _selectedDate!.toTicketDate(),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.wc_rounded),
              ),
              items: widget.genderOptions
                  .map(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ProfileHeroCard extends StatefulWidget {
  const _ProfileHeroCard({
    required this.name,
    required this.subtitle,
    required this.statusLabel,
    required this.themeLabel,
    required this.isGuest,
    required this.accountEmail,
    required this.accountPhone,
    required this.accountDateOfBirth,
    required this.accountGender,
  });
  final String name;
  final String subtitle;
  final String statusLabel;
  final String themeLabel;
  final bool isGuest;
  final String accountEmail;
  final String accountPhone;
  final String accountDateOfBirth;
  final String accountGender;

  @override
  State<_ProfileHeroCard> createState() => _ProfileHeroCardState();
}

class _ProfileHeroCardState extends State<_ProfileHeroCard> {
  bool _detailsExpanded = false;

  void _toggleDetails() {
    setState(() {
      _detailsExpanded = !_detailsExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color titleColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final Color subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: AppTheme.skyGradient(isDark),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.48 : 0.88,
          ),
        ),
        boxShadow: AppTheme.softShadows(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 31.r,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : theme.colorScheme.primary.withValues(alpha: 0.16),
                child: Icon(
                  Icons.person_rounded,
                  size: 34.sp,
                  color: isDark ? Colors.white : theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: widget.statusLabel,
                isGuest: widget.isGuest,
                dense: true,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: <Widget>[
              _HeroMetaChip(
                icon: Icons.palette_outlined,
                label: widget.themeLabel,
                isDark: isDark,
              ),
              _HeroMetaChip(
                icon: Icons.flight_takeoff_rounded,
                label: 'Smart fares',
                isDark: isDark,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, 38.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.28)
                      : theme.colorScheme.outlineVariant,
                ),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              onPressed: _toggleDetails,
              icon: Icon(
                _detailsExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                _detailsExpanded
                    ? 'Hide profile details'
                    : 'View profile details',
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Account profile',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool compact = constraints.maxWidth < 330;
                            final double tileWidth = compact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 8.w) / 2;

                            return Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: <Widget>[
                                SizedBox(
                                  width: tileWidth,
                                  child: _HeroDetailTile(
                                    icon: Icons.email_outlined,
                                    label: 'Email',
                                    value: widget.accountEmail,
                                    isDark: isDark,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _HeroDetailTile(
                                    icon: Icons.phone_outlined,
                                    label: 'Phone',
                                    value: widget.accountPhone,
                                    isDark: isDark,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _HeroDetailTile(
                                    icon: Icons.cake_outlined,
                                    label: 'Date of birth',
                                    value: widget.accountDateOfBirth,
                                    isDark: isDark,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _HeroDetailTile(
                                    icon: Icons.wc_rounded,
                                    label: 'Gender',
                                    value: widget.accountGender,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: _detailsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _HeroDetailTile extends StatelessWidget {
  const _HeroDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              size: 14.sp,
              color: isDark ? Colors.white70 : theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? Colors.white70
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 14.sp,
            color: isDark ? Colors.white : theme.colorScheme.primary,
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadows(context),
      ),
      child: child,
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11.r),
      ),
      child: Icon(icon, size: 19.sp, color: theme.colorScheme.primary),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
      leading: _LeadingIcon(icon: icon),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: onTap != null ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: onTap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.isGuest,
    this.dense = false,
  });

  final String label;
  final bool isGuest;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10.w : 11.w,
        vertical: dense ? 5.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: isGuest
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isGuest
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
