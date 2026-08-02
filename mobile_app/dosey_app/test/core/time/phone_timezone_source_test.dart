import 'dart:async';

import 'package:dosey_app/core/time/phone_timezone_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as timezone;

void main() {
  setUp(() async {
    await PhoneTimezoneSource(gateway: _Gateway('UTC')).refresh();
  });
  test('currentId throws before initialization', () {
    expect(
      () => PhoneTimezoneSource(gateway: _Gateway('UTC')).currentId,
      throwsStateError,
    );
  });

  test('ensureInitialized caches a trimmed timezone identifier', () async {
    final gateway = _Gateway(' America/New_York ');
    final source = PhoneTimezoneSource(gateway: gateway);
    await source.ensureInitialized();
    await source.ensureInitialized();
    expect(source.currentId, 'America/New_York');
    expect(gateway.calls, 1);
  });

  test(
    'refresh coalesces concurrent lookups and later refreshes again',
    () async {
      final gateway = _BlockingGateway();
      final source = PhoneTimezoneSource(gateway: gateway);
      final first = source.refresh();
      final second = source.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, 1);
      gateway.complete('America/Los_Angeles');
      await Future.wait<void>([first, second]);
      gateway.next = 'America/New_York';
      await source.refresh();
      expect(gateway.calls, 2);
      expect(source.currentId, 'America/New_York');
    },
  );

  test('blank native ID does not publish a timezone', () async {
    final source = PhoneTimezoneSource(gateway: _Gateway('   '));
    final before = timezone.local;
    await expectLater(source.refresh(), throwsStateError);
    expect(source.isInitialized, isFalse);
    expect(timezone.local, same(before));
  });

  test('unsupported native ID does not publish a timezone', () async {
    final source = PhoneTimezoneSource(gateway: _Gateway('Not/A_Timezone'));
    final before = timezone.local;
    await expectLater(source.refresh(), throwsA(isA<FormatException>()));
    expect(source.isInitialized, isFalse);
    expect(timezone.local, same(before));
  });

  test(
    'failed refresh preserves published timezone and later recovery updates it',
    () async {
      final gateway = _Gateway('America/New_York');
      final source = PhoneTimezoneSource(gateway: gateway);
      await source.ensureInitialized();
      final priorLocation = timezone.local;
      gateway.next = 'Not/A_Timezone';
      await expectLater(source.refresh(), throwsA(isA<FormatException>()));
      expect(source.currentId, 'America/New_York');
      expect(timezone.local, same(priorLocation));
      gateway.next = 'America/Los_Angeles';
      await source.refresh();
      expect(source.currentId, 'America/Los_Angeles');
      expect(timezone.local.name, 'America/Los_Angeles');
    },
  );
}

class _Gateway implements LocalTimezoneGateway {
  _Gateway(this.next);
  String next;
  int calls = 0;
  @override
  Future<String> localTimezoneName() async {
    calls += 1;
    return next;
  }
}

class _BlockingGateway implements LocalTimezoneGateway {
  final result = Completer<String>();
  String? next;
  int calls = 0;
  @override
  Future<String> localTimezoneName() {
    calls += 1;
    if (calls == 1) return result.future;
    return Future.value(next!);
  }

  void complete(String value) => result.complete(value);
}
