import 'package:dosey_app/core/controller/controller_diagnostics.dart';
import 'package:dosey_app/features/controller/controller_diagnostics_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders registry sections after a read-only diagnostics run', (
    tester,
  ) async {
    final report = ControllerDiagnosticsRegistry.standard.parse(const [
      'DIAGNOSTICS_BEGIN',
      'FIRMWARE_DOSEY_CONTROLLER',
      'PIR_RAW_1',
      'BUTTON_1A_RAW_0',
      'DHT20_PRESENT',
      'PIR_CALIBRATION_REQUIRED',
      'DIAGNOSTICS_DONE',
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ControllerDiagnosticsCard(runDiagnostics: () async => report),
        ),
      ),
    );

    expect(find.text('Hardware diagnostics'), findsOneWidget);
    expect(find.textContaining('Read-only snapshot'), findsOneWidget);
    await tester.tap(find.byKey(const Key('controller-diagnostics-run')));
    await tester.pump();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Sensors'), findsOneWidget);
    expect(find.text('Inputs'), findsOneWidget);
    expect(find.text('Capabilities'), findsOneWidget);
    expect(find.text('1 (raw HIGH)'), findsOneWidget);
    expect(find.text('Calibration required'), findsOneWidget);
    expect(find.text('Refresh diagnostics'), findsOneWidget);
  });

  testWidgets(
    'shows diagnostics failures without discarding the prior report',
    (tester) async {
      final report = ControllerDiagnosticsRegistry.standard.parse(const [
        'DIAGNOSTICS_BEGIN',
        'PIR_RAW_0',
        'DIAGNOSTICS_DONE',
      ]);
      var fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ControllerDiagnosticsCard(
              runDiagnostics: () async {
                if (fail) throw StateError('controller offline');
                return report;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('controller-diagnostics-run')));
      await tester.pump();
      fail = true;

      await tester.tap(find.byKey(const Key('controller-diagnostics-run')));
      await tester.pump();

      expect(find.text('0 (raw LOW)'), findsOneWidget);
      expect(find.textContaining('controller offline'), findsOneWidget);
    },
  );
}
