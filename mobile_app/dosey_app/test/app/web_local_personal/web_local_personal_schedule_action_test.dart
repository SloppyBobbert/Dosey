import 'dart:io';

import 'package:dosey_app/app/web_local_personal/web_local_personal_app.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_routes.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The schedule hero renders its add action even when no prescriptions exist
/// yet, and the default disabled colours all but disappear on the dark hero:
/// a browser capture of the merged build showed an empty pill-shaped smear at
/// both 320px and 800px with no readable label. These assertions pin the
/// disabled action to colours that stay legible on that hero.
void main() {
  setUpAll(() async {
    final font = FontLoader('DoseyLocalRoboto')
      ..addFont(
        File(
          'tool/local_personal/assets/local_fonts/Roboto-Regular.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
  });

  testWidgets('schedule hero keeps its disabled action legible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final setup = PersonalSetupDependencies.local(database);
    final controller = WebLocalPersonalRouteController(
      initialPath: WebLocalPersonalDestination.schedule.path,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(() => setup.initializeLocalProfile());

    await tester.pumpWidget(
      PersonalSetupScope(
        dependencies: setup,
        child: WebLocalPersonalApp(
          storage: WebStorageReady(
            database: database,
            classification: classifyWebStorage(
              WebStorageImplementation.opfsShared,
            ),
            missingFeatures: const {},
          ),
          routeController: controller,
          routeInformationProvider: _Fixed(
            WebLocalPersonalDestination.schedule.path,
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 8; attempt++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
    }
    await tester.pump(const Duration(milliseconds: 40));

    // No prescriptions exist, so the hero action is offered but unavailable.
    final addSchedule = find.widgetWithText(FilledButton, 'Add schedule');
    expect(addSchedule, findsOneWidget, reason: 'schedule hero action missing');
    final button = tester.widget<FilledButton>(addSchedule);
    expect(
      button.onPressed,
      isNull,
      reason: 'this test covers the unavailable-action state',
    );

    final heroCard = tester.widget<Card>(
      find.ancestor(of: addSchedule, matching: find.byType(Card)).first,
    );
    final heroColour = heroCard.color ?? const Color(0xFFFFFFFF);

    final style = button.style;
    expect(
      style,
      isNotNull,
      reason:
          'the disabled hero action must define legible colours; without them '
          'the label renders invisible on the dark hero',
    );
    final disabledBackground = style!.backgroundColor?.resolve(<WidgetState>{
      WidgetState.disabled,
    });
    final disabledForeground = style.foregroundColor?.resolve(<WidgetState>{
      WidgetState.disabled,
    });
    expect(disabledBackground, isNotNull);
    expect(disabledForeground, isNotNull);

    final compositedBackground = Color.alphaBlend(
      disabledBackground!,
      heroColour,
    );
    final compositedForeground = Color.alphaBlend(
      disabledForeground!,
      compositedBackground,
    );
    expect(
      _contrastRatio(compositedForeground, compositedBackground),
      greaterThanOrEqualTo(4.5),
      reason: 'disabled hero action label is not readable on its own pill',
    );
    expect(
      _contrastRatio(compositedBackground, heroColour),
      greaterThanOrEqualTo(1.2),
      reason: 'the disabled pill must stay visible against the hero',
    );
    expect(tester.takeException(), isNull);
  });
}

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color colour) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : ((value + 0.055) / 1.055) * ((value + 0.055) / 1.055);
  final r = channel(colour.r);
  final g = channel(colour.g);
  final b = channel(colour.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

class _Fixed extends ValueNotifier<RouteInformation>
    implements RouteInformationProvider {
  _Fixed(String path) : super(RouteInformation(uri: Uri(path: path)));

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {}
}
