import 'package:dosey_app/core/notifications/local_notification_models.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/time/phone_timezone_source.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart';

class FlutterLocalNotificationScheduler
    implements ReminderScheduler, UrgentShortageNotifier {
  FlutterLocalNotificationScheduler({
    LocalNotificationsPlugin? plugin,
    this.notificationTapHandler,
    DateTime Function(DateTime dateTime)? localTimeConverter,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPluginAdapter(),
       _localTimeConverter = localTimeConverter ?? _defaultLocalTimeConverter;

  final LocalNotificationsPlugin _plugin;
  final void Function(String doseId)? notificationTapHandler;
  final DateTime Function(DateTime dateTime) _localTimeConverter;
  bool _isInitialized = false;
  Future<void>? _initializing;

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }
    final inFlight = _initializing;
    if (inFlight != null) {
      // Share one initialization future so concurrent permission/schedule calls
      // do not race plugin setup.
      await inFlight;
      return;
    }
    _initializing = _plugin
        .initialize(onNotificationTap: _handleNotificationTap)
        .then((launchPayload) {
          _isInitialized = true;
          _handleNotificationTap(launchPayload);
        });
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  @override
  Future<void> requestPermission() async {
    await _ensureInitialized();
    await _plugin.requestPermission();
  }

  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {
    await _ensureInitialized();
    await _plugin.createChannel(doseyReminderNotificationChannel);
    await _plugin.schedule(
      PluginScheduledNotification(
        id: _notificationIdForDose(doseId),
        channel: doseyReminderNotificationChannel,
        title: 'Dosey reminder',
        body: 'Time for $label. Open Dosey to review and confirm.',
        scheduledFor: scheduledFor,
        payload: doseId,
        scheduleMode: PluginNotificationScheduleMode.inexactAllowWhileIdle,
        repeatsDaily: repeatsDaily,
      ),
    );
  }

  @override
  Future<void> cancelDoseReminder(String doseId) {
    return _ensureInitialized().then((_) {
      return _plugin.cancel(_notificationIdForDose(doseId));
    });
  }

  static int _notificationIdForDose(String doseId) {
    // flutter_local_notifications needs an int id; hash the stable dose id so
    // rescheduling the same reminder replaces its previous notification.
    var hash = 0;
    for (final codeUnit in doseId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  void _handleNotificationTap(String? payload) {
    final doseId = payload?.trim();
    if (doseId == null || doseId.isEmpty) {
      return;
    }
    notificationTapHandler?.call(doseId);
  }

  @override
  Future<void> showUrgentShortageNotification({
    required String alertId,
    required String medicationLabel,
    required DateTime scheduledAt,
    required int slotNumber,
  }) async {
    final localScheduledAt = _localTimeConverter(scheduledAt);
    final scheduledLabel =
        '${localScheduledAt.hour.toString().padLeft(2, '0')}:${localScheduledAt.minute.toString().padLeft(2, '0')}';
    await _ensureInitialized();
    await _plugin.createChannel(doseyUrgentShortageNotificationChannel);
    await _plugin.schedule(
      PluginScheduledNotification(
        id: _notificationIdForDose('shortage:$alertId'),
        channel: doseyUrgentShortageNotificationChannel,
        title: 'Dosey urgent shortage',
        body:
            '$medicationLabel is unavailable for slot $slotNumber at $scheduledLabel. This local only alert needs review in Dosey now.',
        scheduledFor: DateTime.now().toUtc(),
        payload:
            'shortage:$alertId|slot:$slotNumber|scheduledAt:${scheduledAt.toUtc().toIso8601String()}|audience:household|delivery:local_only',
        scheduleMode: PluginNotificationScheduleMode.inexactAllowWhileIdle,
        repeatsDaily: false,
      ),
    );
  }

  static DateTime _defaultLocalTimeConverter(DateTime dateTime) {
    return dateTime.toLocal();
  }
}

abstract interface class UrgentShortageNotifier {
  Future<void> showUrgentShortageNotification({
    required String alertId,
    required String medicationLabel,
    required DateTime scheduledAt,
    required int slotNumber,
  });
}

class PluginScheduledNotification {
  const PluginScheduledNotification({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    required this.scheduledFor,
    required this.payload,
    required this.scheduleMode,
    required this.repeatsDaily,
  });

  final int id;
  final LocalNotificationChannel channel;
  final String title;
  final String body;
  final DateTime scheduledFor;
  final String payload;
  final PluginNotificationScheduleMode scheduleMode;
  final bool repeatsDaily;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PluginScheduledNotification &&
            other.id == id &&
            other.channel == channel &&
            other.title == title &&
            other.body == body &&
            other.scheduledFor == scheduledFor &&
            other.payload == payload &&
            other.scheduleMode == scheduleMode &&
            other.repeatsDaily == repeatsDaily;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      channel,
      title,
      body,
      scheduledFor,
      payload,
      scheduleMode,
      repeatsDaily,
    );
  }
}

enum PluginNotificationScheduleMode { inexactAllowWhileIdle }

abstract interface class LocalNotificationsPlugin {
  Future<String?> initialize({
    void Function(String payload)? onNotificationTap,
  });

  Future<void> requestPermission();

  Future<void> createChannel(LocalNotificationChannel channel);

  Future<void> schedule(PluginScheduledNotification notification);

  Future<void> cancel(int id);
}

class FlutterLocalNotificationsPluginAdapter
    implements LocalNotificationsPlugin {
  FlutterLocalNotificationsPluginAdapter({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationTimezoneInitializer? timezoneInitializer,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _timezoneInitializer =
           timezoneInitializer ?? const NotificationTimezoneInitializer();

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationTimezoneInitializer _timezoneInitializer;
  bool _isInitialized = false;
  Future<void>? _initializing;

  @override
  Future<String?> initialize({
    void Function(String payload)? onNotificationTap,
  }) async {
    if (_isInitialized) {
      return null;
    }
    final inFlight = _initializing;
    if (inFlight != null) {
      // Native plugin setup is not reentrant, so all callers await the same run.
      await inFlight;
      return null;
    }
    _initializing = () async {
      await _timezoneInitializer.ensureInitialized();
      await _plugin.initialize(
        InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload?.trim();
          if (payload == null || payload.isEmpty) {
            return;
          }
          onNotificationTap?.call(payload);
        },
      );
      _isInitialized = true;
    }();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      // Return the launch payload once; foreground taps use the response
      // callback above.
      return launchDetails?.notificationResponse?.payload;
    }
    return null;
  }

  @override
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<void> createChannel(LocalNotificationChannel channel) async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.name,
            description: channel.description,
            sound: RawResourceAndroidNotificationSound(
              channel.sound.androidResourceName,
            ),
            importance: Importance.high,
          ),
        );
  }

  @override
  Future<void> schedule(PluginScheduledNotification notification) async {
    await _plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      scheduledDate(notification.scheduledFor),
      NotificationDetails(
        android: AndroidNotificationDetails(
          notification.channel.id,
          notification.channel.name,
          channelDescription: notification.channel.description,
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(
            notification.channel.sound.androidResourceName,
          ),
        ),
        iOS: DarwinNotificationDetails(
          sound: notification.channel.sound.appleFileName,
        ),
      ),
      payload: notification.payload,
      androidScheduleMode: switch (notification.scheduleMode) {
        PluginNotificationScheduleMode.inexactAllowWhileIdle =>
          AndroidScheduleMode.inexactAllowWhileIdle,
      },
      matchDateTimeComponents: notification.repeatsDaily
          ? DateTimeComponents.time
          : null,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  TZDateTime scheduledDate(DateTime dateTime) {
    return TZDateTime.from(dateTime, local);
  }
}

class NotificationTimezoneInitializer {
  const NotificationTimezoneInitializer({
    this.gateway = const PlatformChannelLocalTimezoneGateway(),
  });

  final LocalTimezoneGateway gateway;
  static bool _timezonesInitialized = false;
  static Future<void>? _initializing;

  Future<void> ensureInitialized() async {
    if (_timezonesInitialized) {
      return;
    }
    final inFlight = _initializing;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    _initializing = () async {
      timezone_data.initializeTimeZones();
      final timeZoneName = await gateway.localTimezoneName();
      setLocalLocation(getLocation(timeZoneName));
      _timezonesInitialized = true;
    }();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  static void resetForTest() {
    _timezonesInitialized = false;
    _initializing = null;
  }
}
