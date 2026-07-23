import 'dart:async';

import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/notifications/local_notification_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dosey reminder notification channel stays stable', () {
    expect(doseyReminderNotificationChannel.id, 'dosey_reminders');
    expect(doseyReminderNotificationChannel.name, 'Dose reminders');
    expect(
      doseyReminderNotificationChannel.description,
      'Dosey reminder alerts for scheduled doses.',
    );
    expect(
      doseyReminderNotificationChannel.sound.androidResourceName,
      'dosey_reminder',
    );
    expect(
      doseyReminderNotificationChannel.sound.appleFileName,
      'dosey_reminder.aiff',
    );
  });

  test('scheduler keeps plugin calls behind app-owned wrapper', () async {
    final plugin = _FakeLocalNotificationsPlugin();
    final scheduler = FlutterLocalNotificationScheduler(plugin: plugin);
    final scheduledFor = DateTime.utc(2026, 6, 15, 8, 30);

    await scheduler.requestPermission();
    await scheduler.scheduleDoseReminder(
      doseId: 'dose-42',
      scheduledFor: scheduledFor,
      label: 'Morning vitamins',
      repeatsDaily: true,
    );
    await scheduler.cancelDoseReminder('dose-42');

    expect(plugin.initializedCount, 1);
    expect(plugin.permissionRequests, 1);
    expect(plugin.createdChannels, [doseyReminderNotificationChannel]);
    expect(plugin.scheduledNotifications, [
      PluginScheduledNotification(
        id: 1843149358,
        channel: doseyReminderNotificationChannel,
        title: 'Dosey reminder',
        body: 'Time for Morning vitamins. Open Dosey to review and confirm.',
        scheduledFor: scheduledFor,
        payload: 'dose-42',
        scheduleMode: PluginNotificationScheduleMode.inexactAllowWhileIdle,
        repeatsDaily: true,
      ),
    ]);
    expect(plugin.cancelledIds, [1843149358]);
    expect(plugin.operations, [
      'initialize',
      'requestPermission',
      'createChannel',
      'schedule',
      'cancel',
    ]);
  });

  test('scheduler forwards tapped reminder payloads', () async {
    final plugin = _FakeLocalNotificationsPlugin();
    final tappedDoseIds = <String>[];
    final scheduler = FlutterLocalNotificationScheduler(
      plugin: plugin,
      notificationTapHandler: tappedDoseIds.add,
    );

    await scheduler.requestPermission();
    plugin.tapNotification('dose-42');

    expect(tappedDoseIds, ['dose-42']);
  });

  test(
    'scheduler can deliver an immediate urgent shortage notification',
    () async {
      final plugin = _FakeLocalNotificationsPlugin();
      final scheduler = FlutterLocalNotificationScheduler(
        plugin: plugin,
        localTimeConverter: (dateTime) =>
            dateTime.subtract(const Duration(hours: 7)),
      );
      final scheduledFor = DateTime.utc(2026, 6, 15, 8, 30);

      await scheduler.showUrgentShortageNotification(
        alertId: 'shortage-1',
        medicationLabel: 'Vitamin D',
        scheduledAt: scheduledFor,
        slotNumber: 2,
      );

      expect(
        plugin.createdChannels,
        contains(doseyUrgentShortageNotificationChannel),
      );
      expect(
        plugin.scheduledNotifications.single.title,
        'Dosey urgent shortage',
      );
      expect(plugin.scheduledNotifications.single.body, contains('Vitamin D'));
      expect(plugin.scheduledNotifications.single.body, contains('slot 2'));
      expect(plugin.scheduledNotifications.single.body, contains('01:30'));
      expect(plugin.scheduledNotifications.single.body, contains('local only'));
      expect(
        plugin.scheduledNotifications.single.payload,
        'shortage:shortage-1|slot:2|scheduledAt:2026-06-15T08:30:00.000Z|audience:household|delivery:local_only',
      );
    },
  );

  test(
    'scheduler forwards launch reminder payloads after initialization',
    () async {
      final plugin = _FakeLocalNotificationsPlugin(launchPayload: 'dose-42');
      final tappedDoseIds = <String>[];
      final scheduler = FlutterLocalNotificationScheduler(
        plugin: plugin,
        notificationTapHandler: tappedDoseIds.add,
      );

      await scheduler.requestPermission();

      expect(tappedDoseIds, ['dose-42']);
    },
  );

  test('scheduler only initializes once during concurrent first use', () async {
    final plugin = _BlockingFakeLocalNotificationsPlugin();
    final scheduler = FlutterLocalNotificationScheduler(plugin: plugin);

    final permissionFuture = scheduler.requestPermission();
    final cancelFuture = scheduler.cancelDoseReminder('dose-42');
    await Future<void>.delayed(Duration.zero);

    expect(plugin.initializeCalls, 1);

    plugin.completeInitialize();
    await Future.wait([permissionFuture, cancelFuture]);

    expect(plugin.initializeCalls, 1);
    expect(plugin.permissionRequests, 1);
    expect(plugin.cancelledIds, [1843149358]);
  });

  test(
    'timezone initializer resolves and caches the device timezone',
    () async {
      NotificationTimezoneInitializer.resetForTest();
      final gateway = _FakeLocalTimezoneGateway('America/New_York');
      final initializer = NotificationTimezoneInitializer(gateway: gateway);

      await initializer.ensureInitialized();
      await initializer.ensureInitialized();

      expect(gateway.requests, 1);
    },
  );

  test('timezone initializer coalesces concurrent initialization', () async {
    NotificationTimezoneInitializer.resetForTest();
    final gateway = _BlockingFakeLocalTimezoneGateway('America/New_York');
    final initializer = NotificationTimezoneInitializer(gateway: gateway);

    final first = initializer.ensureInitialized();
    final second = initializer.ensureInitialized();
    await Future<void>.delayed(Duration.zero);

    expect(gateway.requests, 1);

    gateway.complete();
    await Future.wait([first, second]);

    expect(gateway.requests, 1);
  });

  test(
    'adapter only initializes plugin and timezone once concurrently',
    () async {
      NotificationTimezoneInitializer.resetForTest();
      final timezoneInitializer =
          _BlockingFakeNotificationTimezoneInitializer();
      final plugin = _FakeFlutterLocalNotificationsPlatformPlugin();
      final adapter = TestFlutterLocalNotificationsPluginAdapter(
        plugin: plugin,
        timezoneInitializer: timezoneInitializer,
      );

      final first = adapter.initialize();
      final second = adapter.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(timezoneInitializer.calls, 1);

      timezoneInitializer.complete();
      await Future.wait([first, second]);

      expect(timezoneInitializer.calls, 1);
      expect(plugin.initializeCalls, 1);
    },
  );

  test('platform channel timezone gateway reads native timezone', () async {
    const channel = MethodChannel('com.sloppybobbert.dosey_app/timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getLocalTimezone');
          return 'America/Los_Angeles';
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final timezoneName = await const PlatformChannelLocalTimezoneGateway()
        .localTimezoneName();

    expect(timezoneName, 'America/Los_Angeles');
  });
}

class _FakeLocalNotificationsPlugin implements LocalNotificationsPlugin {
  _FakeLocalNotificationsPlugin({this.launchPayload});

  final String? launchPayload;
  int initializedCount = 0;
  int permissionRequests = 0;
  final List<LocalNotificationChannel> createdChannels = [];
  final List<PluginScheduledNotification> scheduledNotifications = [];
  final List<int> cancelledIds = [];
  final List<String> operations = [];
  void Function(String payload)? onNotificationTap;

  @override
  Future<String?> initialize({
    void Function(String payload)? onNotificationTap,
  }) async {
    initializedCount += 1;
    operations.add('initialize');
    this.onNotificationTap = onNotificationTap;
    return launchPayload;
  }

  void tapNotification(String payload) {
    onNotificationTap?.call(payload);
  }

  @override
  Future<void> createChannel(LocalNotificationChannel channel) async {
    createdChannels.add(channel);
    operations.add('createChannel');
  }

  @override
  Future<void> requestPermission() async {
    permissionRequests += 1;
    operations.add('requestPermission');
  }

  @override
  Future<void> schedule(PluginScheduledNotification notification) async {
    scheduledNotifications.add(notification);
    operations.add('schedule');
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    operations.add('cancel');
  }
}

class _BlockingFakeLocalNotificationsPlugin
    extends _FakeLocalNotificationsPlugin {
  final Completer<void> _initializeCompleter = Completer<void>();
  int initializeCalls = 0;

  @override
  Future<String?> initialize({
    void Function(String payload)? onNotificationTap,
  }) async {
    initializeCalls += 1;
    await _initializeCompleter.future;
    return super.initialize(onNotificationTap: onNotificationTap);
  }

  void completeInitialize() {
    if (!_initializeCompleter.isCompleted) {
      _initializeCompleter.complete();
    }
  }
}

class _FakeLocalTimezoneGateway implements LocalTimezoneGateway {
  _FakeLocalTimezoneGateway(this.timezoneName);

  final String timezoneName;
  int requests = 0;

  @override
  Future<String> localTimezoneName() async {
    requests += 1;
    return timezoneName;
  }
}

class _BlockingFakeLocalTimezoneGateway extends _FakeLocalTimezoneGateway {
  _BlockingFakeLocalTimezoneGateway(super.timezoneName);

  final Completer<void> _completer = Completer<void>();

  @override
  Future<String> localTimezoneName() async {
    requests += 1;
    await _completer.future;
    return timezoneName;
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class _BlockingFakeNotificationTimezoneInitializer
    extends NotificationTimezoneInitializer {
  _BlockingFakeNotificationTimezoneInitializer();

  final Completer<void> _completer = Completer<void>();
  int calls = 0;

  @override
  Future<void> ensureInitialized() async {
    calls += 1;
    await _completer.future;
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class _FakeFlutterLocalNotificationsPlatformPlugin
    implements FlutterLocalNotificationsPlugin {
  int initializeCalls = 0;
  DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse;

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalls += 1;
    this.onDidReceiveNotificationResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    return const NotificationAppLaunchDetails(false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFlutterLocalNotificationsPluginAdapter
    extends FlutterLocalNotificationsPluginAdapter {
  TestFlutterLocalNotificationsPluginAdapter({
    required super.timezoneInitializer,
    required FlutterLocalNotificationsPlugin plugin,
  }) : super(plugin: plugin);
}
