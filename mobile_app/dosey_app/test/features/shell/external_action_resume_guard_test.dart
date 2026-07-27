import 'package:dosey_app/features/shell/external_action_resume_guard.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resume preserves the initiating route after app backgrounding', () {
    final guard = ExternalActionResumeGuard<String>();
    final lease = guard.begin('settings/backup');

    guard.didChangeLifecycleState(AppLifecycleState.inactive);
    guard.didChangeLifecycleState(AppLifecycleState.paused);

    expect(guard.consumeResumeTarget(), 'settings/backup');
    expect(guard.consumeResumeTarget(), isNull);
    lease.complete();
  });

  test('completion clears a lease that never backgrounds the app', () {
    final guard = ExternalActionResumeGuard<String>();
    final lease = guard.begin('carousel/controller');

    lease.complete();

    expect(guard.consumeResumeTarget(), isNull);
  });

  test('completion retains an armed lease until the next resume', () {
    final guard = ExternalActionResumeGuard<String>();
    final lease = guard.begin('settings/export');
    guard.didChangeLifecycleState(AppLifecycleState.inactive);

    lease.complete();

    expect(guard.consumeResumeTarget(), 'settings/export');
    expect(guard.consumeResumeTarget(), isNull);
  });

  test('latest external action replaces an unused lease', () {
    final guard = ExternalActionResumeGuard<String>();
    final first = guard.begin('settings/help');
    final second = guard.begin('settings/notifications');
    guard.didChangeLifecycleState(AppLifecycleState.paused);

    first.complete();
    expect(guard.consumeResumeTarget(), 'settings/notifications');
    second.complete();
  });

  test('resumed lifecycle does not arm a lease', () {
    final guard = ExternalActionResumeGuard<String>();
    final lease = guard.begin('settings/help');

    guard.didChangeLifecycleState(AppLifecycleState.resumed);
    lease.complete();

    expect(guard.consumeResumeTarget(), isNull);
  });
}
