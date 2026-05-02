import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:air_sky/core/providers/app_providers.dart';
import 'package:air_sky/core/router/route_paths.dart';
import 'package:air_sky/core/utils/account_required_prompt.dart';
import 'package:air_sky/core/utils/app_feedback.dart';
import 'package:air_sky/features/ai_assistant/domain/entities/ai_assistant_models.dart';
import 'package:air_sky/features/flights/presentation/controllers/flight_search_controller.dart';

const double _kAiBotVisualSize = 52;
const double _kAiBotRingThickness = 2.8;
const double _kAiBotCoreSize = 36;
const double _kAiBotOuterRadius = 16;
const double _kAiBotInnerRadius = 12;

class AiAssistantEntryPoint extends StatelessWidget {
  const AiAssistantEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DraggableAiAssistantFab();
  }
}

class _DraggableAiAssistantFab extends StatefulWidget {
  const _DraggableAiAssistantFab();

  @override
  State<_DraggableAiAssistantFab> createState() =>
      _DraggableAiAssistantFabState();
}

class _DraggableAiAssistantFabState extends State<_DraggableAiAssistantFab> {
  static Offset? _savedNormalizedOffset;

  Offset? _offset;
  bool _isDragging = false;

  void _openAssistantSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => const _AiAssistantSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double edgePaddingX = 14.w;
          final double edgePaddingY = 14.h;
          final double fabSize = _kAiBotVisualSize.w;

          final double minX = edgePaddingX;
          final double maxX = math.max(
            minX,
            constraints.maxWidth - fabSize - edgePaddingX,
          );

          final double minY = edgePaddingY;
          final double maxY = math.max(
            minY,
            constraints.maxHeight - fabSize - edgePaddingY,
          );

          _offset ??= _initialOffset(
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
          );

          final Offset clampedOffset = _clampOffset(
            _offset!,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
          );
          _offset = clampedOffset;

          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: clampedOffset.dx,
                top: clampedOffset.dy,
                child: GestureDetector(
                  onPanStart: (_) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onPanUpdate: (DragUpdateDetails details) {
                    setState(() {
                      final Offset candidate = Offset(
                        (_offset?.dx ?? clampedOffset.dx) + details.delta.dx,
                        (_offset?.dy ?? clampedOffset.dy) + details.delta.dy,
                      );
                      _offset = _clampOffset(
                        candidate,
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                      );
                      _saveNormalizedOffset(
                        _offset!,
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                      );
                    });
                  },
                  onPanEnd: (_) {
                    final double centerX = (minX + maxX) / 2;
                    final double targetX =
                        (_offset?.dx ?? clampedOffset.dx) < centerX
                        ? minX
                        : maxX;

                    setState(() {
                      _isDragging = false;
                      _offset = _clampOffset(
                        Offset(targetX, _offset?.dy ?? clampedOffset.dy),
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                      );
                      _saveNormalizedOffset(
                        _offset!,
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                      );
                    });
                  },
                  child: _AnimatedGradientAiFab(onPressed: _openAssistantSheet),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Offset _initialOffset({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    final Offset? normalized = _savedNormalizedOffset;
    if (normalized == null) {
      return Offset(maxX, maxY);
    }

    final double x = minX + (maxX - minX) * normalized.dx.clamp(0.0, 1.0);
    final double y = minY + (maxY - minY) * normalized.dy.clamp(0.0, 1.0);
    return Offset(x, y);
  }

  Offset _clampOffset(
    Offset value, {
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    return Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
  }

  void _saveNormalizedOffset(
    Offset value, {
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    final double nx = maxX == minX ? 1 : (value.dx - minX) / (maxX - minX);
    final double ny = maxY == minY ? 1 : (value.dy - minY) / (maxY - minY);

    _savedNormalizedOffset = Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
  }
}

class _AnimatedGradientAiFab extends StatefulWidget {
  const _AnimatedGradientAiFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AnimatedGradientAiFab> createState() => _AnimatedGradientAiFabState();
}

class _AnimatedGradientAiFabState extends State<_AnimatedGradientAiFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Tooltip(
      message: 'Open AI assistant',
      child: SizedBox.square(
        dimension: _kAiBotVisualSize.w,
        child: AnimatedBuilder(
          animation: _ringController,
          builder: (BuildContext context, Widget? child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kAiBotOuterRadius.r),
                gradient: LinearGradient(
                  colors: const <Color>[
                    Color(0xFF2563EB),
                    Color(0xFF06B6D4),
                    Color(0xFF22C55E),
                    Color(0xFFF59E0B),
                  ],
                  transform: GradientRotation(
                    _ringController.value * 2 * math.pi,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.24),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(_kAiBotRingThickness.w),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(_kAiBotInnerRadius.r),
                  ),
                  child: Center(
                    child: SizedBox.square(
                      dimension: _kAiBotCoreSize.w,
                      child: FloatingActionButton.small(
                        heroTag: null,
                        tooltip: 'Open AI assistant',
                        elevation: 0,
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.primary,
                        onPressed: widget.onPressed,
                        child: const Icon(Icons.smart_toy_rounded),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AiAssistantSheet extends ConsumerStatefulWidget {
  const _AiAssistantSheet();

  @override
  ConsumerState<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<_AiAssistantSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _lastHandledActionId;
  int? _processingActionId;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String text) async {
    final String prompt = text.trim();
    if (prompt.isEmpty) {
      return;
    }

    _inputController.clear();

    await ref
        .read(aiAssistantControllerProvider.notifier)
        .handleUserPrompt(
          prompt: prompt,
          currentSearchForm: ref.read(searchFormControllerProvider),
          currentUserId: ref.read(authStateChangesProvider).valueOrNull?.uid,
        );
  }

  void _clearChat() {
    _inputController.clear();
    _lastHandledActionId = null;
    _processingActionId = null;
    ref.read(aiAssistantControllerProvider.notifier).clearChat();
  }

  Future<bool> _handleNavigationAction(AiNavigationAction action) async {
    final controller = ref.read(aiAssistantControllerProvider.notifier);
    bool handled = false;
    bool shouldCloseSheet = false;

    switch (action.target) {
      case AiNavigationTarget.none:
        handled = true;
        break;
      case AiNavigationTarget.results:
        final query = action.query;
        if (query != null) {
          final flightSearchController = ref.read(
            flightSearchControllerProvider.notifier,
          );
          final formController = ref.read(
            searchFormControllerProvider.notifier,
          );
          formController.setFromAirport(query.fromAirport);
          formController.setToAirport(query.toAirport);
          formController.setDate(query.date);
          formController.setPassengers(query.passengers);
          formController.setCabinClass(query.cabinClass);

          // Always reset old filters before a new AI search to avoid empty
          // second searches caused by stale constraints.
          flightSearchController.applyFilters(maxStops: null, maxPrice: null);

          await flightSearchController.searchFlights(query);

          if (action.maxBudgetUsd != null) {
            flightSearchController.applyFilters(
              maxStops: null,
              maxPrice: action.maxBudgetUsd,
            );
          }

          if (action.forceCheapestSort) {
            flightSearchController.sortBy(FlightSortOption.cheapest);
          }

          if (mounted) {
            _closeSheetIfOpen();
            context.push(RoutePaths.results);
            handled = true;
            shouldCloseSheet = false;
          }
        }
        break;
      case AiNavigationTarget.flightDetails:
        if (action.flight != null) {
          final bool isGuest = ref.read(guestModeProvider);
          if (isGuest) {
            if (mounted) {
              await showAccountRequiredPrompt(
                context,
                ref,
                featureLabel: 'view flight details and proceed to booking',
              );
              handled = true;
            }
          } else if (mounted) {
            _closeSheetIfOpen();
            context.push(RoutePaths.flightDetails, extra: action.flight);
            handled = true;
            shouldCloseSheet = false;
          }
        }
        break;
      case AiNavigationTarget.booking:
        if (action.flight != null) {
          final bool isGuest = ref.read(guestModeProvider);
          if (isGuest) {
            if (mounted) {
              await showAccountRequiredPrompt(
                context,
                ref,
                featureLabel: 'book flights',
              );
              handled = true;
            }
          } else if (mounted) {
            _closeSheetIfOpen();
            context.push(RoutePaths.booking, extra: action.flight);
            showAppFeedback(
              context,
              'AirSky: Please review passenger details and tap Confirm Booking manually.',
              type: AppFeedbackType.general,
            );
            handled = true;
            shouldCloseSheet = false;
          }
        }
        break;
    }

    if (handled) {
      controller.consumePendingNavigation(action.id);
      if (shouldCloseSheet) {
        _closeSheetIfOpen();
      }
    }

    return handled;
  }

  void _closeSheetIfOpen() {
    if (!mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _tryHandleNavigationAction(AiNavigationAction action) async {
    if (_processingActionId == action.id || action.id == _lastHandledActionId) {
      return;
    }

    _processingActionId = action.id;
    final bool handled = await _handleNavigationAction(action);
    if (handled) {
      _lastHandledActionId = action.id;
    } else if (mounted) {
      showAppFeedback(
        context,
        'AirSky: Navigation is ready, please tap again.',
        type: AppFeedbackType.general,
      );
    }
    _processingActionId = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiAssistantState>(aiAssistantControllerProvider, (
      AiAssistantState? previous,
      AiAssistantState next,
    ) {
      final AiNavigationAction? action = next.pendingNavigation;
      if (action == null || action.id == _lastHandledActionId) {
        return;
      }

      if (action.requiresConfirmation) {
        return;
      }

      _tryHandleNavigationAction(action);
    });

    final AiAssistantState state = ref.watch(aiAssistantControllerProvider);
    final AiNavigationAction? pendingConfirmationAction =
        (state.pendingNavigation != null &&
            state.pendingNavigation!.requiresConfirmation)
        ? state.pendingNavigation
        : null;
    final ThemeData theme = Theme.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = MediaQuery.sizeOf(context);
        final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        final double sheetWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : viewport.width;
        final double sheetHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.96
            : viewport.height * 0.96;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: sheetWidth,
            height: sheetHeight,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                14.w,
                2.h,
                14.w,
                10.h + keyboardInset,
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      gradient: LinearGradient(
                        colors: <Color>[
                          theme.colorScheme.primary.withValues(alpha: 0.16),
                          theme.colorScheme.tertiary.withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.22,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.smart_toy_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'AirSky Copilot Studio',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Search, compare, prep docs, and plan smarter. Final booking is always manual.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed:
                              state.messages.length <= 1 && !state.isWorking
                              ? null
                              : _clearChat,
                          icon: Icon(Icons.close_rounded, size: 16.sp),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 6.h,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          _AiToolButton(
                            icon: Icons.insights_rounded,
                            label: 'Fare Radar',
                            onTap: () => _submitPrompt('Show fare radar'),
                          ),
                          _AiToolButton(
                            icon: Icons.inventory_2_outlined,
                            label: 'Pack Smart',
                            onTap: () => _submitPrompt('Build packing tips'),
                          ),
                          _AiToolButton(
                            icon: Icons.badge_outlined,
                            label: 'Visa Helper',
                            onTap: () => _submitPrompt('Give me visa tips'),
                          ),
                          _AiToolButton(
                            icon: Icons.rule_folder_outlined,
                            label: 'Trip Checklist',
                            onTap: () =>
                                _submitPrompt('Create my trip checklist'),
                          ),
                          _AiToolButton(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Surprise Me',
                            onTap: () =>
                                _submitPrompt('Surprise me with a destination'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                        itemCount:
                            state.messages.length + (state.isWorking ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == state.messages.length &&
                              state.isWorking) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.only(bottom: 8.h),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: const Text('Thinking...'),
                              ),
                            );
                          }

                          final AiChatMessage message = state.messages[index];
                          final bool isUser = message.role == AiChatRole.user;
                          final String? confirmationLabel =
                              pendingConfirmationAction?.confirmationLabel;
                          final bool isConfirmationMessage =
                              !isUser &&
                              pendingConfirmationAction != null &&
                              confirmationLabel != null &&
                              message.text.contains(confirmationLabel);
                          final AiNavigationAction? confirmationAction =
                              isConfirmationMessage
                              ? pendingConfirmationAction
                              : null;
                          final Color messageTextColor = isUser
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface;

                          final Widget messageContent = isConfirmationMessage
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      message.text,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: messageTextColor),
                                    ),
                                    SizedBox(height: 8.h),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          999.r,
                                        ),
                                        onTap: () {
                                          if (confirmationAction != null) {
                                            _tryHandleNavigationAction(
                                              confirmationAction,
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999.r,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Text(
                                                confirmationAction
                                                        ?.confirmationLabel ??
                                                    'Continue',
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 16.sp,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  message.text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: messageTextColor,
                                  ),
                                );

                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8.h),
                              constraints: BoxConstraints(maxWidth: 300.w),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: messageContent,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          _QuickPromptChip(
                            label: 'Cheapest to Dubai next week',
                            onTap: () => _submitPrompt(
                              'Find me cheapest flight to Dubai next week',
                            ),
                          ),
                          _QuickPromptChip(
                            label: 'Weekend trip under 40k',
                            onTap: () =>
                                _submitPrompt('Weekend trip under 40k'),
                          ),
                          _QuickPromptChip(
                            label: 'Best Lahore to Istanbul',
                            onTap: () => _submitPrompt(
                              'Best flights from Lahore to Istanbul',
                            ),
                          ),
                          _QuickPromptChip(
                            label: 'Compare cheapest vs fastest',
                            onTap: () =>
                                _submitPrompt('Compare cheapest vs fastest'),
                          ),
                          _QuickPromptChip(
                            label: 'Create trip checklist',
                            onTap: () =>
                                _submitPrompt('Create my trip checklist'),
                          ),
                          if (state.recommendations != null)
                            _QuickPromptChip(
                              label: 'Open AI recommended details',
                              onTap: () => _submitPrompt(
                                'Open AI recommended flight details',
                              ),
                            ),
                          if (state.recommendations != null)
                            _QuickPromptChip(
                              label: 'Take me to booking (manual)',
                              onTap: () => _submitPrompt(
                                'Proceed to booking for recommended flight',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (String value) {
                            _submitPrompt(value);
                          },
                          decoration: const InputDecoration(
                            hintText:
                                'Ask for flights, budget, dates, or guidance...',
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      SizedBox(
                        width: 112.w,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: Size(0, 48.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 10.h,
                            ),
                          ),
                          onPressed: state.isWorking
                              ? null
                              : () => _submitPrompt(_inputController.text),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: ActionChip(label: Text(label), onPressed: onTap),
    );
  }
}

class _AiToolButton extends StatelessWidget {
  const _AiToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, 38.h),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 16.sp),
        label: Text(label),
      ),
    );
  }
}
