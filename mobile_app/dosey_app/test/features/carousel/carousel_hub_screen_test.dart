import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/carousel/carousel_hub_screen.dart';
import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('everyday carousel does not expose controller tools', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Controller'), findsNothing);
    expect(find.byType(CarouselScreen), findsOneWidget);
    expect(find.byType(SegmentedButton), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.database});

  final DoseyDatabase database;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      bleGateway: FakeBleGateway(),
      connectivityGateway: FakeConnectivityGateway(),
      missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
      child: MaterialApp(home: Scaffold(body: const CarouselHubScreen())),
    );
  }
}
