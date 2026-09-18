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

  testWidgets('sheet buttons resolve a focus ring from the theme', (
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

    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    // Each ring must contrast with its button's fill.
    final textSide = theme.textButtonTheme.style?.side?.resolve(<WidgetState>{
      WidgetState.focused,
    });
    expect(textSide, isNotNull, reason: 'text buttons need a focus ring');
    expect(textSide!.width, 2);
    expect(textSide.color, const Color(0xFF103E46));
    final filledSide = theme.filledButtonTheme.style?.side?.resolve(
      <WidgetState>{WidgetState.focused},
    );
    expect(filledSide, isNotNull, reason: 'filled buttons need a focus ring');
    expect(filledSide!.width, 2);
    expect(filledSide.color, const Color(0xFFBFEAF0));
    expect(
      theme.textButtonTheme.style?.side?.resolve(<WidgetState>{}),
      isNull,
      reason: 'unfocused buttons stay unstyled',
    );
  });

  for (final width in [320.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'sheet button focus at ${width}px/${scale}x does not resize',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final database = DoseyDatabase.inMemory();
          addTearDown(database.close);
          final setup = PersonalSetupDependencies.local(database);
          await tester.runAsync(() => setup.initializeLocalProfile());
          await tester.pumpWidget(
            PersonalSetupScope(
              dependencies: setup,
              child: const WebLocalPersonalApp(
                startupPage: Scaffold(
                  body: SingleChildScrollView(child: PrescriptionsScreen()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Add prescription'));
          await tester.pumpAndSettle();
          final cancel = find.widgetWithText(TextButton, 'Cancel');
          final save = find.widgetWithText(FilledButton, 'Save prescription');
          final sizes = [tester.getSize(cancel), tester.getSize(save)];
          final separation =
              tester.getTopLeft(save) - tester.getTopLeft(cancel);

          for (final target in [cancel, save]) {
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            final label = find.descendant(
              of: target,
              matching: find.byType(Text),
            );
            final focus = Focus.of(tester.element(label));
            for (var tabs = 0; !focus.hasFocus && tabs < 12; tabs++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
            }
            expect(focus.hasFocus, isTrue);
            final material = tester.widget<Material>(
              find
                  .descendant(of: target, matching: find.byType(Material))
                  .first,
            );
            final border = (material.shape! as OutlinedBorder).side;
            expect(border.width, 2);
            expect(
              border.color,
              target == cancel
                  ? const Color(0xFF103E46)
                  : const Color(0xFFBFEAF0),
            );
            expect([tester.getSize(cancel), tester.getSize(save)], sizes);
            expect(
              tester.getTopLeft(save) - tester.getTopLeft(cancel),
              separation,
            );
            expect(
              tester.getRect(cancel).overlaps(tester.getRect(save)),
              isFalse,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          await setup.drain();
        },
      );
    }
  }

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
