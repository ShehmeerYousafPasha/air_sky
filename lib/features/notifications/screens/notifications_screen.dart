import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/config/app_providers.dart';
import 'package:air_sky/utils/account_required_prompt.dart';
import 'package:air_sky/utils/date_time_utils.dart';
import 'package:air_sky/shared/empty_state_view.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isGuest = ref.watch(guestModeProvider);
    final User? user = ref.watch(authStateChangesProvider).valueOrNull;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Bookings'),
              Tab(text: 'Promotions'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _PersonalNotificationsTab(
              isGuest: isGuest,
              user: user,
            ),
            const _PublicNotificationsTab(),
          ],
        ),
      ),
    );
  }
}

class _PersonalNotificationsTab extends ConsumerWidget {
  const _PersonalNotificationsTab({required this.isGuest, required this.user});

  final bool isGuest;
  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isGuest || user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const EmptyStateView(
                title: 'Sign in to see booking alerts',
                subtitle:
                    'Booking notifications are tied to your Firestore account.',
                icon: Icons.notifications_none_rounded,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await goToLoginFromGuestSession(context, ref);
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    return _NotificationStreamView(
      query: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true),
      emptyTitle: 'No booking notifications',
      emptySubtitle:
          'Booking confirmations, payment updates, and cancellations will appear here.',
      emptyIcon: Icons.notifications_none_rounded,
    );
  }
}

class _PublicNotificationsTab extends StatelessWidget {
  const _PublicNotificationsTab();

  @override
  Widget build(BuildContext context) {
    return _NotificationStreamView(
      query: FirebaseFirestore.instance
          .collection('public_notifications')
          .orderBy('createdAt', descending: true),
      emptyTitle: 'No promotions yet',
      emptySubtitle:
          'Promotional announcements pushed for all users will appear here.',
      emptyIcon: Icons.campaign_outlined,
    );
  }
}

class _NotificationStreamView extends StatelessWidget {
  const _NotificationStreamView({
    required this.query,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  final Query<Map<String, dynamic>> query;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snapshot.hasError) {
          return const EmptyStateView(
            title: 'Could not load notifications',
            subtitle: 'Please try again in a moment.',
            icon: Icons.error_outline_rounded,
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return EmptyStateView(
            title: emptyTitle,
            subtitle: emptySubtitle,
            icon: emptyIcon,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = docs[index].data();
            return _NotificationCard(data: data);
          },
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.data});

  final Map<String, dynamic> data;

  String _title() {
    final String value = (data['title'] as String? ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
    return 'Notification';
  }

  String _body() {
    return (data['body'] as String? ?? '').trim();
  }

  String _typeLabel() {
    final String type = (data['type'] as String? ?? '').trim();
    if (type.isEmpty) {
      return 'general';
    }
    return type.replaceAll('_', ' ').toUpperCase();
  }

  DateTime _createdAt() {
    final int? createdAtMs = data['createdAt'] as int?;
    if (createdAtMs == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime createdAt = _createdAt();
    final String bookingId = (data['bookingId'] as String? ?? '').trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _title(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _typeLabel(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (_body().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _body(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  createdAt == DateTime.fromMillisecondsSinceEpoch(0)
                      ? 'Just now'
                      : createdAt.toTicketDate(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (bookingId.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bookingId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
