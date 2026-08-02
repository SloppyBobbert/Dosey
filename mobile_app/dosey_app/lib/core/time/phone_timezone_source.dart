import 'package:dosey_app/core/reminders/reminder_occurrence_resolver.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as timezone;

abstract interface class LocalTimezoneGateway {
  Future<String> localTimezoneName();
}

class PlatformChannelLocalTimezoneGateway implements LocalTimezoneGateway {
  const PlatformChannelLocalTimezoneGateway({
    this.channel = const MethodChannel(_channelName),
  });

  static const _channelName = 'com.sloppybobbert.dosey_app/timezone';
  final MethodChannel channel;

  @override
  Future<String> localTimezoneName() async {
    final value = await channel.invokeMethod<String>('getLocalTimezone');
    if (value == null || value.trim().isEmpty) {
      throw StateError('Native timezone channel returned no timezone name.');
    }
    return value;
  }
}

class PhoneTimezoneSource {
  PhoneTimezoneSource({
    this.gateway = const PlatformChannelLocalTimezoneGateway(),
    ReminderOccurrenceResolver resolver = const ReminderOccurrenceResolver(),
  }) : _resolver = resolver;

  final LocalTimezoneGateway gateway;
  final ReminderOccurrenceResolver _resolver;
  String? _currentId;
  Future<void>? _refreshing;

  bool get isInitialized => _currentId != null;

  String get currentId {
    final id = _currentId;
    if (id == null) {
      throw StateError('Phone timezone has not been initialized.');
    }
    return id;
  }

  Future<void> ensureInitialized() =>
      isInitialized ? Future.value() : refresh();

  Future<void> refresh() {
    final refreshing = _refreshing;
    if (refreshing != null) return refreshing;
    final run = _refresh();
    _refreshing = run;
    return run.whenComplete(() {
      if (identical(_refreshing, run)) _refreshing = null;
    });
  }

  Future<void> _refresh() async {
    final id = (await gateway.localTimezoneName()).trim();
    if (id.isEmpty) {
      throw StateError('Native timezone channel returned no timezone name.');
    }
    final location = _resolver.locationFor(id);
    timezone.setLocalLocation(location);
    _currentId = id;
  }
}
