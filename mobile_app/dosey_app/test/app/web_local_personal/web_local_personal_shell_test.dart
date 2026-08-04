import 'dart:io';
import 'dart:ui';

import 'package:dosey_app/app/web_local_personal/web_local_personal_app.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_pages.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_routes.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DoseyDatabase database;

  setUp(() => database = DoseyDatabase.inMemory());
  tearDown(() => database.close());

  test('routes are exact and deep links choose the matching destination', () {
    expect(WebLocalPersonalDestination.values.map((item) => item.path), [
      '/today',
      '/prescriptions',
      '/schedule',
      '/log',
      '/settings',
    ]);
    expect(WebLocalPersonalDestination.values.map((item) => item.label), [
      'Today',
      'Prescriptions',
      'Schedule',
      'Log',
      'Settings',
    ]);
    for (final destination in WebLocalPersonalDestination.values) {
      expect(
        WebLocalPersonalRouteController(initialPath: destination.path).current,
        destination,
      );
    }
  });

  test('route controller maintains back and forward history', () {
    final controller = WebLocalPersonalRouteController();
    controller.setPath('/prescriptions');
    controller.setPath('/schedule');
    expect(controller.goBack(), isTrue);
    expect(controller.currentPath, '/prescriptions');
    expect(controller.goForward(), isTrue);
    expect(controller.currentPath, '/schedule');
    expect(controller.goBack(), isTrue);
    controller.setPath('/log');
    expect(controller.canGoForward, isFalse);
  });

  test(
    'route delegate builds routes and keeps unknown paths explicit',
    () async {
      final controller = WebLocalPersonalRouteController();
      final delegate = WebLocalPersonalRouteDelegate(
        controller: controller,
        builder: (_, controller) => Text(controller.currentPath),
      );
      await delegate.setNewRoutePath(RouteInformation(uri: Uri(path: '/log')));
      expect(delegate.currentConfiguration!.uri.path, '/log');
      expect(await delegate.popRoute(), isTrue);
      expect(controller.currentPath, '/today');
      await delegate.setNewRoutePath(
        RouteInformation(uri: Uri(path: '/not-local-personal')),
      );
      expect(controller.hasUnknownPath, isTrue);
      expect(delegate.currentConfiguration!.uri.path, '/not-local-personal');
      delegate.dispose();
    },
  );

  testWidgets('each supported deep link builds its matching shell page', (
    tester,
  ) async {
    final content = <WebLocalPersonalDestination, String>{
      WebLocalPersonalDestination.today:
          'Local schedule details will appear here.',
      WebLocalPersonalDestination.prescriptions:
          'Local prescription details will appear here.',
      WebLocalPersonalDestination.schedule:
          'Local schedule details will appear here.',
      WebLocalPersonalDestination.log:
          'This read-only space will show local dose history.',
      WebLocalPersonalDestination.settings:
          'Demo only — non-persistent. Nothing entered here is saved.',
    };
    for (final destination in WebLocalPersonalDestination.values) {
      await _pump(
        tester,
        width: 390,
        controller: WebLocalPersonalRouteController(
          initialPath: destination.path,
        ),
        appKey: ValueKey(destination.path),
      );
      expect(find.text(content[destination]!), findsOneWidget);
    }
  });

  testWidgets('injected browser route information updates the shell', (
    tester,
  ) async {
    final controller = WebLocalPersonalRouteController();
    final provider = _FakeRouteInformationProvider('/schedule');
    await _pump(
      tester,
      width: 390,
      controller: controller,
      routeInformationProvider: provider,
    );
    expect(
      find.text('Local schedule details will appear here.'),
      findsOneWidget,
    );
    expect(controller.currentPath, '/schedule');

    provider.send('/log');
    await tester.pump();
    expect(
      find.text('This read-only space will show local dose history.'),
      findsOneWidget,
    );
    expect(controller.currentPath, '/log');

    provider.send('/schedule');
    await tester.pump();
    expect(
      find.text('Local schedule details will appear here.'),
      findsOneWidget,
    );
    expect(controller.currentPath, '/schedule');
  });

  testWidgets('unknown paths use an explicit return gate', (tester) async {
    await _pump(
      tester,
      width: 390,
      controller: WebLocalPersonalRouteController(initialPath: '/unknown'),
    );
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to Today'));
    await tester.pump();
    expect(
      find.text('Local schedule details will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile shows five labelled destinations and desktop uses a 232px rail',
    (tester) async {
      await _pump(tester, width: 699);
      expect(
        find.byKey(const ValueKey('web-local-personal-bottom-navigation')),
        findsOneWidget,
      );
      expect(find.byType(NavigationRail), findsNothing);
      for (final label in [
        'Today',
        'Prescriptions',
        'Schedule',
        'Log',
        'Settings',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey('web-local-personal-bottom-navigation'),
            ),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }

      await _pump(tester, width: 1024);
      final rail = tester.getSize(find.byType(NavigationRail));
      expect(rail.width, 232);
      expect(
        find.byKey(const ValueKey('web-local-personal-bottom-navigation')),
        findsNothing,
      );
    },
  );

  testWidgets('700 through 1023 use the compact rail and 1024 expands it', (
    tester,
  ) async {
    await _pump(tester, width: 700);
    expect(tester.getSize(find.byType(NavigationRail)).width, 80);
    await _pump(tester, width: 1023);
    expect(tester.getSize(find.byType(NavigationRail)).width, 80);
    await _pump(tester, width: 1024);
    expect(tester.getSize(find.byType(NavigationRail)).width, 232);
  });

  testWidgets('desktop rail uses clear high-contrast navigation states', (
    tester,
  ) async {
    await _pump(tester, width: 1024);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.useIndicator, isTrue);
    expect(rail.indicatorColor, const Color(0xFFBFEAF0));
    expect(rail.selectedIconTheme!.color, const Color(0xFF103E46));
    expect(rail.unselectedIconTheme!.color, const Color(0xFFFFFCF6));
    expect(rail.selectedLabelTextStyle!.color, const Color(0xFF103E46));
    expect(rail.unselectedLabelTextStyle!.color, const Color(0xFFFFFCF6));
  });

  testWidgets('mobile navigation follows focus order and has 44px targets', (
    tester,
  ) async {
    final controller = WebLocalPersonalRouteController();
    await _pump(tester, width: 390, controller: controller);
    final destinations = WebLocalPersonalDestination.values
        .map(
          (destination) => find.byKey(
            ValueKey('web-local-personal-nav-${destination.name}'),
          ),
        )
        .toList();
    expect(destinations, hasLength(5));
    for (var index = 0; index < 5; index++) {
      final size = tester.getSize(destinations[index]);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
    expect(Focus.of(tester.element(destinations[0])).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(Focus.of(tester.element(destinations[1])).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.current, WebLocalPersonalDestination.prescriptions);
    expect(controller.currentPath, '/prescriptions');
    expect(
      find.text('Local prescription details will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets(
    '320 by 256 at 200% keeps navigation and page content reachable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, width: 320, height: 256, textScale: 2);
      expect(tester.takeException(), isNull);
      final navigation = find.byKey(
        const ValueKey('web-local-personal-bottom-navigation'),
      );
      expect(
        find.descendant(
          of: navigation,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      for (final destination in WebLocalPersonalDestination.values) {
        final destinationFinder = find.descendant(
          of: navigation,
          matching: find.bySemanticsLabel(destination.label),
        );
        expect(
          find.descendant(
            of: navigation,
            matching: find.text(destination.label),
          ),
          findsOneWidget,
        );
        expect(destinationFinder, findsOneWidget);
        final node = tester.getSemantics(destinationFinder);
        expect(node.label, destination.label);
        expect(node.flagsCollection.isButton, isTrue);
        expect(
          node.flagsCollection.isSelected,
          destination == WebLocalPersonalDestination.today
              ? Tristate.isTrue
              : Tristate.isFalse,
        );
      }
      final schedule = find.descendant(
        of: navigation,
        matching: find.bySemanticsLabel('Schedule'),
      );
      await tester.tap(schedule);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Local schedule details will appear here.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(schedule).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'short landscape at 200% keeps navigation and page content reachable',
    (tester) async {
      await _pump(tester, width: 480, height: 320, textScale: 2);
      expect(tester.takeException(), isNull);

      await tester.tap(find.bySemanticsLabel('Log'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text('This read-only space will show local dose history.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('mobile navigation preserves safe-area bottom padding', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 24);
    await _pump(tester, width: 390);
    final container = tester.widget<Container>(
      find.byKey(const ValueKey('web-local-personal-bottom-navigation')),
    );
    expect((container.padding! as EdgeInsets).bottom, 24);
    addTearDown(tester.view.resetPadding);
  });

  testWidgets('page headings are semantic and navigation changes the page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, width: 390);
    expect(
      tester.getSemantics(find.text('Today').first).flagsCollection.isHeader,
      isTrue,
    );
    await tester.tap(find.text('Schedule'));
    await tester.pump();
    expect(
      find.text('Local schedule details will appear here.'),
      findsOneWidget,
    );
    expect(
      Focus.of(
        tester.element(
          find.byKey(const ValueKey('web-local-personal-page-focus')),
        ),
      ).hasFocus,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets(
    'demo is visibly fictional and suppresses injected data actions',
    (tester) async {
      var calls = 0;
      await _pump(
        tester,
        width: 390,
        storage: _demoStorage(),
        controller: WebLocalPersonalRouteController(
          initialPath: '/prescriptions',
        ),
        onAddPrescription: () => calls++,
        onAddSchedule: () => calls++,
      );
      expect(
        find.text('Demo only — non-persistent. Nothing entered here is saved.'),
        findsNothing,
      );
      expect(
        find.text('This is a fictional, non-persistent preview.'),
        findsOneWidget,
      );
      expect(find.text('Add prescription'), findsNothing);
      expect(calls, 0);
      await tester.tap(find.text('Schedule'));
      await tester.pump();
      expect(find.text('Add schedule'), findsNothing);
    },
  );

  testWidgets('demo withholds data callbacks from injected page builders', (
    tester,
  ) async {
    VoidCallback? exposedPrescriptionAction;
    VoidCallback? exposedScheduleAction;
    await _pump(
      tester,
      width: 390,
      storage: _demoStorage(),
      onAddPrescription: () {},
      onAddSchedule: () {},
      pageBuilder:
          (context, destination, storage, {onAddPrescription, onAddSchedule}) {
            exposedPrescriptionAction = onAddPrescription;
            exposedScheduleAction = onAddSchedule;
            return const SizedBox.shrink();
          },
    );
    expect(exposedPrescriptionAction, isNull);
    expect(exposedScheduleAction, isNull);
  });

  testWidgets(
    'ready storage can expose injected prescription and schedule actions',
    (tester) async {
      var prescriptionCalls = 0;
      var scheduleCalls = 0;
      await _pump(
        tester,
        width: 390,
        storage: WebStorageReady(
          database: database,
          classification: classifyWebStorage(
            WebStorageImplementation.sharedIndexedDb,
          ),
          missingFeatures: const {},
        ),
        controller: WebLocalPersonalRouteController(
          initialPath: '/prescriptions',
        ),
        onAddPrescription: () => prescriptionCalls++,
        onAddSchedule: () => scheduleCalls++,
      );
      await tester.tap(find.text('Add prescription'));
      expect(prescriptionCalls, 1);
      await tester.tap(find.text('Schedule'));
      await tester.pump();
      await tester.tap(find.text('Add schedule'));
      expect(scheduleCalls, 1);
    },
  );

  testWidgets('storage recovery does not present an empty local shell', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 390,
      storage: WebStorageStartupRecovery(
        error: StateError('unavailable'),
        stackTrace: StackTrace.empty,
        missingFeatures: const {},
      ),
    );
    expect(find.text('Local storage needs attention'), findsOneWidget);
    expect(find.text('Local schedule details will appear here.'), findsNothing);
    expect(
      find.byKey(const ValueKey('web-local-personal-bottom-navigation')),
      findsNothing,
    );
  });

  testWidgets('recovery scrolls safely in a narrow short 200% viewport', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 320,
      height: 160,
      textScale: 2,
      storage: WebStorageStartupRecovery(
        error: StateError('unavailable'),
        stackTrace: StackTrace.empty,
        missingFeatures: const {},
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown route scrolls safely in a narrow short 200% viewport', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 320,
      height: 160,
      textScale: 2,
      controller: WebLocalPersonalRouteController(initialPath: '/unknown'),
    );
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('local shell source does not import remote or device integrations', () {
    final source = Directory('lib/app/web_local_personal')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    for (final expression in [
      RegExp(
        r'appwrite|account|cloud|pairing|caregiver|household|sync|bluetooth|\bble\b|carousel|robot|native|notification|permission|audio',
        caseSensitive: false,
      ),
      RegExp(
        r'package:dosey_app/(core/(controller|hardware)|features/)',
        caseSensitive: false,
      ),
    ]) {
      expect(expression.hasMatch(source), isFalse, reason: '$expression found');
    }
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  double height = 800,
  WebStorageBootstrapResult? storage,
  WebLocalPersonalRouteController? controller,
  RouteInformationProvider? routeInformationProvider,
  Key? appKey,
  VoidCallback? onAddPrescription,
  VoidCallback? onAddSchedule,
  WebLocalPersonalPageBuilder? pageBuilder,
}) async {
  final activeController = controller ?? WebLocalPersonalRouteController();
  final activeProvider =
      routeInformationProvider ??
      _FakeRouteInformationProvider(activeController.currentPath);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(
        tester.view,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: WebLocalPersonalApp(
        key: appKey,
        storage: storage ?? _demoStorage(),
        routeController: activeController,
        routeInformationProvider: activeProvider,
        pageBuilder: pageBuilder ?? buildWebLocalPersonalFoundationPage,
        onAddPrescription: onAddPrescription,
        onAddSchedule: onAddSchedule,
      ),
    ),
  );
  await tester.pump();
}

WebStorageDemoOnly _demoStorage() => WebStorageDemoOnly(
  classification: classifyWebStorage(WebStorageImplementation.inMemory),
  missingFeatures: const {},
);

class _FakeRouteInformationProvider extends ValueNotifier<RouteInformation>
    implements RouteInformationProvider {
  _FakeRouteInformationProvider(String path)
    : super(RouteInformation(uri: Uri(path: path)));

  void send(String path) => value = RouteInformation(uri: Uri(path: path));

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {}
}
