import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/theme/app_theme.dart';
import 'package:air_sky/core/utils/account_required_prompt.dart';
import 'package:air_sky/core/utils/app_feedback.dart';
import 'package:air_sky/core/utils/date_time_utils.dart';
import 'package:air_sky/core/utils/price_formatter.dart';
import 'package:air_sky/features/booking/domain/entities/booking.dart';
import 'package:air_sky/features/booking/domain/entities/passenger.dart';
import 'package:air_sky/features/booking/presentation/controllers/booking_controller.dart';
import 'package:air_sky/features/flights/domain/entities/flight.dart';
import 'package:air_sky/shared/widgets/app_primary_button.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.flight});

  final Flight flight;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  final Set<String> _autoFilledPassengerFields = <String>{};
  bool _prefillScheduled = false;
  bool _showPassengerValidationErrors = false;

  static const Set<String> _reservedSeats = <String>{
    '1C',
    '2D',
    '4B',
    '5A',
    '7F',
    '9C',
    '10E',
  };

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(bookingControllerProvider.notifier).resetFlow(),
    );
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

  Map<String, String> _buildPassengerPrefill({
    required User? user,
    required Map<String, dynamic>? profileData,
  }) {
    final String profileName = _readProfileString(profileData, <String>[
      'name',
    ]);
    final String authName = user?.displayName?.trim() ?? '';
    final String profileEmail = _readProfileString(profileData, <String>[
      'email',
    ]);
    final String email = profileEmail.isNotEmpty
        ? profileEmail
        : (user?.email?.trim() ?? '');

    final String fullName = profileName.isNotEmpty ? profileName : authName;
    final List<String> nameParts = fullName
        .split(RegExp(r'\s+'))
        .where((String value) => value.trim().isNotEmpty)
        .toList();

    String firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final String lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';

    if (firstName.isEmpty && email.contains('@')) {
      firstName = email.split('@').first.trim();
    }

    return <String, String>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': _readProfileString(profileData, <String>[
        'phoneNumber',
        'phone',
      ]),
      'nationality': _readProfileString(profileData, <String>['nationality']),
      'passportNumber': _readProfileString(profileData, <String>[
        'passportNumber',
      ]),
    };
  }

  void _schedulePassengerPrefill({
    required User? user,
    required Map<String, dynamic>? profileData,
  }) {
    if (_prefillScheduled) {
      return;
    }

    _prefillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillScheduled = false;
      if (!mounted) {
        return;
      }

      final FormBuilderState? formState = _formKey.currentState;
      if (formState == null) {
        return;
      }

      final Map<String, String> prefillValues = _buildPassengerPrefill(
        user: user,
        profileData: profileData,
      );
      final Map<String, dynamic> patch = <String, dynamic>{};

      prefillValues.forEach((String field, String value) {
        if (value.trim().isEmpty ||
            _autoFilledPassengerFields.contains(field)) {
          return;
        }

        if (!formState.fields.containsKey(field)) {
          return;
        }

        final dynamic currentValue = formState.fields[field]?.value;
        final bool isCurrentEmpty =
            currentValue == null ||
            (currentValue is String && currentValue.trim().isEmpty);

        if (isCurrentEmpty) {
          patch[field] = value;
        }
      });

      if (patch.isEmpty) {
        return;
      }

      formState.patchValue(patch);
      _autoFilledPassengerFields.addAll(patch.keys);
    });
  }

  @override
  Widget build(BuildContext context) {
    final BookingState state = ref.watch(bookingControllerProvider);
    final BookingController controller = ref.read(
      bookingControllerProvider.notifier,
    );
    final User? user = ref.watch(authStateChangesProvider).valueOrNull;
    final Map<String, dynamic>? profileData = ref
        .watch(userProfileDataProvider)
        .valueOrNull;
    final int progressStep = state.currentStep >= 3 ? 3 : state.currentStep + 1;
    final ThemeData theme = Theme.of(context);

    _schedulePassengerPrefill(user: user, profileData: profileData);

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Booking')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: _StepProgressHeader(step: progressStep),
            ),
            if (state.errorMessage != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(state.errorMessage!),
              ),
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: AppTheme.softShadows(context),
                ),
                child: Stepper(
                  currentStep: state.currentStep,
                  controlsBuilder:
                      (BuildContext context, ControlsDetails details) =>
                          const SizedBox.shrink(),
                  onStepTapped: (_) {},
                  steps: <Step>[
                    Step(
                      title: const Text('Passenger Info'),
                      isActive: state.currentStep >= 0,
                      content: _PassengerStep(
                        formKey: _formKey,
                        showValidationErrors: _showPassengerValidationErrors,
                      ),
                    ),
                    Step(
                      title: const Text('Seat Selection'),
                      isActive: state.currentStep >= 1,
                      content: _SeatStep(
                        selectedSeat: state.selectedSeat,
                        reservedSeats: _reservedSeats,
                        onSelect: controller.selectSeat,
                      ),
                    ),
                    Step(
                      title: const Text('Review'),
                      isActive: state.currentStep >= 2,
                      content: _ReviewStep(
                        flight: widget.flight,
                        passenger: state.passenger,
                        selectedSeat: state.selectedSeat,
                      ),
                    ),
                    Step(
                      title: const Text('Done'),
                      isActive: state.currentStep >= 3,
                      content: _SuccessStep(booking: state.createdBooking),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: _buildActions(context, state, controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    BookingState state,
    BookingController controller,
  ) {
    final User? user = ref.watch(authStateChangesProvider).valueOrNull;
    final bool isGuest = ref.watch(guestModeProvider);

    if (state.currentStep == 3) {
      return AppPrimaryButton(
        label: 'Go to My Trips',
        icon: Icons.airplane_ticket_rounded,
        onPressed: () {
          controller.resetFlow();
          context.go(RoutePaths.myTrips);
        },
      );
    }

    return Row(
      children: <Widget>[
        if (state.currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: controller.previousStep,
              child: const Text('Back'),
            ),
          ),
        if (state.currentStep > 0) SizedBox(width: 12.w),
        Expanded(
          child: AppPrimaryButton(
            label: state.currentStep == 2 ? 'Confirm Booking' : 'Continue',
            icon: state.currentStep == 2
                ? Icons.check_circle_outline_rounded
                : Icons.arrow_forward_rounded,
            isLoading: state.isSubmitting,
            onPressed: () async {
              if (state.currentStep == 0) {
                if (_formKey.currentState?.saveAndValidate() ?? false) {
                  final Map<String, dynamic> data =
                      _formKey.currentState!.value;
                  controller.setPassenger(
                    Passenger(
                      firstName: data['firstName'] as String,
                      lastName: data['lastName'] as String,
                      email: data['email'] as String,
                      phone: data['phone'] as String,
                      nationality: data['nationality'] as String,
                      passportNumber: data['passportNumber'] as String,
                    ),
                  );
                  controller.nextStep();
                } else {
                  setState(() {
                    _showPassengerValidationErrors = true;
                  });
                }
                return;
              }

              if (state.currentStep == 1) {
                if (state.selectedSeat == null) {
                  showAppFeedback(
                    context,
                    'AirSky: Select a seat.',
                    type: AppFeedbackType.error,
                  );
                  return;
                }
                controller.nextStep();
                return;
              }

              if (state.currentStep == 2) {
                if (isGuest) {
                  await showAccountRequiredPrompt(
                    context,
                    ref,
                    featureLabel: 'complete bookings and receive tickets',
                  );
                  return;
                }

                if (user == null) {
                  await showAccountRequiredPrompt(
                    context,
                    ref,
                    featureLabel: 'complete bookings and receive tickets',
                  );
                  return;
                }

                await controller.submitBooking(
                  userId: user.uid,
                  flight: widget.flight,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _PassengerStep extends StatelessWidget {
  const _PassengerStep({
    required this.formKey,
    required this.showValidationErrors,
  });

  final GlobalKey<FormBuilderState> formKey;
  final bool showValidationErrors;

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: formKey,
      autovalidateMode: showValidationErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        children: <Widget>[
          FormBuilderTextField(
            name: 'firstName',
            decoration: const InputDecoration(
              labelText: 'First name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              errorMaxLines: 2,
            ),
            validator:
                FormBuilderValidators.compose(<String? Function(String?)>[
                  FormBuilderValidators.required(
                    errorText: 'First name is required.',
                  ),
                  FormBuilderValidators.minLength(
                    2,
                    errorText: 'Enter at least 2 characters.',
                  ),
                ]),
          ),
          SizedBox(height: 10.h),
          FormBuilderTextField(
            name: 'lastName',
            decoration: const InputDecoration(
              labelText: 'Last name',
              prefixIcon: Icon(Icons.badge_outlined),
              errorMaxLines: 2,
            ),
            validator:
                FormBuilderValidators.compose(<String? Function(String?)>[
                  FormBuilderValidators.required(
                    errorText: 'Last name is required.',
                  ),
                  FormBuilderValidators.minLength(
                    2,
                    errorText: 'Enter at least 2 characters.',
                  ),
                ]),
          ),
          SizedBox(height: 10.h),
          FormBuilderTextField(
            name: 'email',
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              errorMaxLines: 2,
            ),
            validator: FormBuilderValidators.compose(
              <String? Function(String?)>[
                FormBuilderValidators.required(errorText: 'Email is required.'),
                FormBuilderValidators.email(
                  errorText: 'Enter a valid email address.',
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          FormBuilderTextField(
            name: 'phone',
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.call_outlined),
              errorMaxLines: 2,
            ),
            validator: FormBuilderValidators.required(
              errorText: 'Phone number is required.',
            ),
          ),
          SizedBox(height: 10.h),
          FormBuilderTextField(
            name: 'nationality',
            decoration: const InputDecoration(
              labelText: 'Nationality',
              prefixIcon: Icon(Icons.flag_outlined),
              errorMaxLines: 2,
            ),
            validator: FormBuilderValidators.required(
              errorText: 'Nationality is required.',
            ),
          ),
          SizedBox(height: 10.h),
          FormBuilderTextField(
            name: 'passportNumber',
            decoration: const InputDecoration(
              labelText: 'Passport number',
              prefixIcon: Icon(Icons.fact_check_outlined),
              errorMaxLines: 2,
            ),
            validator:
                FormBuilderValidators.compose(<String? Function(String?)>[
                  FormBuilderValidators.required(
                    errorText: 'Passport number is required.',
                  ),
                  FormBuilderValidators.minLength(
                    6,
                    errorText: 'Passport number must be at least 6 characters.',
                  ),
                ]),
          ),
        ],
      ),
    );
  }
}

class _SeatStep extends StatelessWidget {
  const _SeatStep({
    required this.selectedSeat,
    required this.reservedSeats,
    required this.onSelect,
  });

  static const List<String> _leftColumns = <String>['A', 'B', 'C'];
  static const List<String> _rightColumns = <String>['D', 'E', 'F'];

  final String? selectedSeat;
  final Set<String> reservedSeats;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget buildSeat(String column, int row, double size) {
      final String seatCode = '$row$column';
      final bool isReserved = reservedSeats.contains(seatCode);
      final bool isSelected = selectedSeat == seatCode;

      return _SeatCell(
        label: seatCode,
        size: size,
        isReserved: isReserved,
        isSelected: isSelected,
        onTap: isReserved ? null : () => onSelect(seatCode),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Select your seat',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (selectedSeat != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  'Seat $selectedSeat',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 6.h,
          children: <Widget>[
            _SeatLegend(label: 'Available', color: theme.colorScheme.surface),
            _SeatLegend(label: 'Selected', color: theme.colorScheme.primary),
            _SeatLegend(
              label: 'Reserved',
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.2,
            ),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 8.h),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double seatGap = 6.w;
                final double aisleGap = 26.w;
                final double seatSize =
                    ((constraints.maxWidth - (seatGap * 4) - aisleGap) / 6)
                        .clamp(24.w, 34.w);

                Widget seatLetter(String value) {
                  return SizedBox(
                    width: seatSize,
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return Column(
                  children: <Widget>[
                    Text(
                      'Front',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        seatLetter('A'),
                        SizedBox(width: seatGap),
                        seatLetter('B'),
                        SizedBox(width: seatGap),
                        seatLetter('C'),
                        SizedBox(width: aisleGap),
                        seatLetter('D'),
                        SizedBox(width: seatGap),
                        seatLetter('E'),
                        SizedBox(width: seatGap),
                        seatLetter('F'),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    for (int row = 1; row <= 10; row++)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            for (
                              int i = 0;
                              i < _leftColumns.length;
                              i++
                            ) ...<Widget>[
                              buildSeat(_leftColumns[i], row, seatSize),
                              if (i != _leftColumns.length - 1)
                                SizedBox(width: seatGap),
                            ],
                            SizedBox(width: aisleGap),
                            for (
                              int i = 0;
                              i < _rightColumns.length;
                              i++
                            ) ...<Widget>[
                              buildSeat(_rightColumns[i], row, seatSize),
                              if (i != _rightColumns.length - 1)
                                SizedBox(width: seatGap),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          selectedSeat == null
              ? 'Tap an available seat to continue.'
              : 'Seat $selectedSeat selected.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    required this.label,
    required this.size,
    required this.isReserved,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final double size;
  final bool isReserved;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color fill = isReserved
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.48)
        : isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;

    final Color border = isReserved
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.48)
        : isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    final Color text = isReserved || isSelected
        ? Colors.white
        : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 1.w),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.flight,
    required this.passenger,
    required this.selectedSeat,
  });

  final Flight flight;
  final Passenger? passenger;
  final String? selectedSeat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Review booking',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.42,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Route: ${flight.fromAirport} -> ${flight.toAirport}'),
              Text(
                'Departure: ${flight.departureTime.toTicketDate()} ${flight.departureTime.toTimeLabel()}',
              ),
              Text('Airline: ${flight.airline}'),
              Text('Passenger: ${passenger?.fullName ?? '-'}'),
              Text('Seat: ${selectedSeat ?? '-'}'),
              SizedBox(height: 6.h),
              Text(
                'Total: ${PriceFormatter.format(flight.price)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.booking});

  final Booking? booking;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String bookingId = booking?.bookingId ?? '-';
    final String psid = (booking?.psid ?? '').trim();
    final bool hasPsid = psid.isNotEmpty;
    final String amount = booking == null
        ? '-'
        : PriceFormatter.format(booking!.amount);
    final String dueAt = booking?.paymentDueAt == null
        ? '-'
        : '${booking!.paymentDueAt!.toTicketDate()} ${booking!.paymentDueAt!.toTimeLabel()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.hourglass_top_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8.w),
            const Expanded(child: Text('Booking created as unpaid.')),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          'Booking ID: $bookingId',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8.h),
        Text('Amount due: $amount'),
        Text('PSID: ${hasPsid ? psid : '-'}'),
        Text('Due by: $dueAt'),
        SizedBox(height: 10.h),
        Text(
          'Pay with this PSID in any payment app. Ticket and QR unlock after payment is confirmed.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasPsid) ...<Widget>[
          SizedBox(height: 10.h),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: psid));
              if (!context.mounted) {
                return;
              }
              showAppFeedback(
                context,
                'AirSky: PSID copied.',
                type: AppFeedbackType.success,
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy PSID'),
          ),
        ],
      ],
    );
  }
}

class _StepProgressHeader extends StatelessWidget {
  const _StepProgressHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = step / 3;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Step $step/3',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(width: 6.w),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
