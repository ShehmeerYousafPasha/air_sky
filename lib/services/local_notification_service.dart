import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for managing local push notifications.
///
/// Handles platform-specific notification setup and display for:
/// - Booking confirmations
/// - Payment status changes
/// - Booking cancellations
/// - Travel reminders
///
/// Supports Android, iOS, and macOS with proper channel/permission handling.
class LocalNotificationService {
  LocalNotificationService._();

  /// Singleton instance for app-wide access
  static final LocalNotificationService instance = LocalNotificationService._();

  /// Android notification channel for booking-related notifications
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'airsky_booking_updates',
    'Booking updates',
    description: 'Booking creation, payment, and cancellation alerts.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initializes local notification system for all supported platforms.
  ///
  /// - Sets up Android notification channel for booking alerts
  /// - Requests iOS permissions (alert, badge, sound)
  /// - Requests macOS permissions (alert, badge, sound)
  /// - Safe to call multiple times (guards against duplicate initialization)
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // Configure platform-specific initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin
    await _plugin.initialize(settings);

    // Android: Create notification channel
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_channel);
      await androidImplementation.requestNotificationsPermission();
    }

    // iOS: Request permissions
    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final MacOSFlutterLocalNotificationsPlugin? macImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macImplementation != null) {
      await macImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _initialized = true;
  }

  Future<void> showBookingEvent({
    required String bookingId,
    required String title,
    required String body,
    required String type,
  }) async {
    if (!_initialized) {
      return;
    }

    final int notificationId =
        Object.hash('booking', bookingId, type, body.hashCode) & 0x7fffffff;

    try {
      await _plugin.show(
        notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'airsky_booking_updates',
            'Booking updates',
            channelDescription:
                'Booking creation, payment, and cancellation alerts.',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: '$type:$bookingId',
      );
    } catch (_) {
      // Notification display failures must not block the booking flow.
    }
  }
}
