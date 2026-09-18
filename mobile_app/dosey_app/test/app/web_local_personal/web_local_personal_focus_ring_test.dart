import 'dart:io';

import 'package:dosey_app/app/web_local_personal/web_local_personal_app.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_pages.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_routes.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keyboard focus must be visible. A real-browser capture measured the default
/// focus cues on this app at about 1.3:1 for the appearance chips and 1.35:1
/// for the bottom navigation, i.e. effectively invisible, while the teal
/// selected chip and the selected navigation foreground are much louder.
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

  testWidgets('bottom navigation draws a focus ring, not a bar-coloured tint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = WebLocalPersonalRouteController(
      initialPath: WebLocalPersonalDestination.prescriptions.path,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view),
        child: WebLocalPersonalApp(
          storage: WebStorageDemoOnly(
            classification: classifyWebStorage(
              WebStorageImplementation.inMemory,
            ),
            missingFeatures: const {},
          ),
          routeController: controller,
          routeInformationProvider: _Fixed(controller.currentPath),
          pageBuilder: buildWebLocalPersonalFoundationPage,
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey('web-local-personal-nav-prescriptions')),
    );
    final side = button.style?.side;
    expect(side, isNotNull, reason: 'navigation buttons must style focus');
    final focused = side!.resolve(<WidgetState>{WidgetState.focused});
    expect(focused, isNotNull, reason: 'a focused destination needs a ring');
    expect(focused!.width, 2);
    expect(focused.color, const Color(0xFFBFEAF0));
    expect(
      side.resolve(<WidgetState>{}),
      isNull,
      reason: 'an unfocused destination stays unstyled',
    );
  });

  testWidgets('a focused appearance chip shows a ring without moving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final setup = PersonalSetupDependencies.local(database);
    await tester.runAsync(() => setup.initializeLocalProfile());
    await tester.pumpWidget(
      PersonalSetupScope(
        dependencies: setup,
        child: MaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: PrescriptionsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add prescription'));
    await tester.pumpAndSettle();

    const ringKey = ValueKey('appearance-chip-focus-ring');
    final capsule = find.widgetWithText(ChoiceChip, 'Capsule');
    expect(capsule, findsOneWidget);
    expect(find.byKey(ringKey), findsNothing, reason: 'no chip is focused yet');
    final unfocusedSize = tester.getSize(capsule);
    List<double> tops() => [
      for (final label in ['Pill', 'Capsule', 'Tablet'])
        tester.getTopLeft(find.widgetWithText(ChoiceChip, label)).dy,
    ];
    final unfocusedTops = tops();

    final node = tester.widget<ChoiceChip>(capsule).focusNode;
    expect(node, isNotNull, reason: 'chips need a focus node to style');
    node!.requestFocus();
    await tester.pumpAndSettle();

    expect(node.hasFocus, isTrue);
    final ring = find.byKey(ringKey);
    expect(ring, findsOneWidget, reason: 'a focused chip needs a visible ring');
    final decoration =
        tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.width, 2);
    expect(border.top.color, const Color(0xFF103E46));

    // Regression guard: the ring must not resize the chip. The appearance row
    // has no slack, and a two-pixel-wider chip wrapped the last one onto a
    // second line, which moved the whole sheet.
    expect(
      tester.getSize(capsule),
      unfocusedSize,
      reason: 'the focus ring must not resize the chip',
    );
    expect(
      tops(),
      unfocusedTops,
      reason: 'focusing a chip must not re-flow the appearance row',
    );
  });
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
