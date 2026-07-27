import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/carousel/carousel_hub_screen.dart';
import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('defaults to Carousel and preserves a selected segment', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final app = _TestApp(database: database);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Carousel'), findsWidgets);
    expect(find.text('Controller'), findsWidgets);
    expect(find.byType(CarouselScreen), findsOneWidget);
    expect(find.byType(ControllerScreen), findsNothing);

    await tester.tap(find.text('Controller').last);
    await tester.pumpAndSettle();
    expect(find.byType(ControllerScreen), findsOneWidget);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.byType(ControllerScreen), findsOneWidget);
  });

  testWidgets('can open Controller directly', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      _TestApp(
        database: database,
        initialSegment: CarouselHubSegment.controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ControllerScreen), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.database, this.initialSegment});

  final DoseyDatabase database;
  final CarouselHubSegment? initialSegment;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      bleGateway: FakeBleGateway(),
      connectivityGateway: FakeConnectivityGateway(),
      missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
      child: MaterialApp(
        home: Scaffold(
          body: CarouselHubScreen(
            initialSegment: initialSegment ?? CarouselHubSegment.carousel,
          ),
        ),
      ),
    );
  }
}
