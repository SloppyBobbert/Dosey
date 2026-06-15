import 'package:dosey_app/core/notifications/local_notification_models.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone_latest/flutter_native_timezone_latest.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart';

class FlutterLocalNotificationScheduler implements ReminderScheduler {
  FlutterLocalNotificationScheduler({LocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPluginAdapter();

  final LocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }
    await _plugin.initialize();
    _isInitialized = true;
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
  }) async {
    await _ensureInitialized();
    await _plugin.createChannel(doseyReminderNotificationChannel);
    await _plugin.schedule(
      PluginScheduledNotification(
        id: _notificationIdForDose(doseId),
        channel: doseyReminderNotificationChannel,
        title: 'Dosey reminder',
        body: 'Time for $label.',
        scheduledFor: scheduledFor,
        payload: doseId,
        scheduleMode: PluginNotificationScheduleMode.inexactAllowWhileIdle,
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
    var hash = 0;
    for (final codeUnit in doseId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
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
  });

  final int id;
  final LocalNotificationChannel channel;
  final String title;
  final String body;
  final DateTime scheduledFor;
  final String payload;
  final PluginNotificationScheduleMode scheduleMode;

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
            other.scheduleMode == scheduleMode;
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
    );
  }
}

enum PluginNotificationScheduleMode { inexactAllowWhileIdle }

abstract interface class LocalNotificationsPlugin {
  Future<void> initialize();

  Future<void> requestPermission();

  Future<void> createChannel(LocalNotificationChannel channel);

  Future<void> schedule(PluginScheduledNotification notification);

  Future<void> cancel(int id);
}

class FlutterLocalNotificationsPluginAdapter
    implements LocalNotificationsPlugin {
  FlutterLocalNotificationsPluginAdapter()
    : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;
  bool _timezonesInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    await _initializeTimezones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _isInitialized = true;
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
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  TZDateTime scheduledDate(DateTime dateTime) {
    return TZDateTime.from(dateTime, local);
  }

  Future<void> _initializeTimezones() async {
    if (_timezonesInitialized) {
      return;
    }
    timezone_data.initializeTimeZones();
    final timeZoneName = await FlutterNativeTimezoneLatest.getLocalTimezone();
    setLocalLocation(getLocation(timeZoneName));
    _timezonesInitialized = true;
  }
}
