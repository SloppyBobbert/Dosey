import 'dart:async';

import 'package:dosey_app/app/web_local_personal/web_local_personal_app.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_startup.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_open.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:drift/drift.dart'
    show DatabaseConnection, QueryExecutor, QueryExecutorUser, SqlDialect;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('choice precedes storage and ready uses the existing shell', (
    tester,
  ) async {
    var opens = 0;
    final owner = WebLocalPersonalStartup(
      bootstrap: () async {
        opens++;
        return ready();
      },
    );
    await tester.pumpWidget(WebLocalPersonalStartupApp(startup: owner));
    expect(opens, 0);
    expect(find.text('Use Personal on this browser'), findsOneWidget);
    expect(find.textContaining('not shared with an account'), findsOneWidget);
    await tester.tap(find.text('Continue locally'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(
      find.textContaining('Today actions and history are not available yet'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await owner.shutdown();
  });

  for (final path in ['/prescriptions', '/unknown']) {
    testWidgets('direct route $path survives choice and startup', (
      tester,
    ) async {
      final provider = PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(uri: Uri(path: path)),
      );
      final owner = WebLocalPersonalStartup(bootstrap: () async => ready());
      await tester.pumpWidget(
        WebLocalPersonalStartupApp(
          startup: owner,
          routeInformationProvider: provider,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue locally'), findsOneWidget);
      await tester.tap(find.text('Continue locally'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(
        find.text(path == '/unknown' ? 'Page not found' : 'Medication cabinet'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await owner.shutdown();
      });
      provider.dispose();
    });
  }

  for (final path in ['/prescriptions', '/schedule', '/unknown']) {
    for (final retry in [false, true]) {
      testWidgets('default provider retains $path through ready retry=$retry', (
        tester,
      ) async {
        final dispatcher = tester.binding.platformDispatcher;
        dispatcher.defaultRouteNameTestValue = path;
        final pending = Completer<WebStorageBootstrapResult>();
        final database = GatedProfileDatabase();
        var opens = 0;
        final owner = WebLocalPersonalStartup(
          bootstrap: () async {
            opens++;
            if (retry && opens == 1) {
              return WebStorageStartupRecovery(
                error: StateError('retryable open'),
                stackTrace: StackTrace.current,
                missingFeatures: const {},
              );
            }
            return pending.future;
          },
        );
        try {
          // No injected provider: WidgetsApp must retain its own route state.
          await tester.pumpWidget(WebLocalPersonalStartupApp(startup: owner));
          await tester.pumpAndSettle();
          final appState = tester.state(find.byType(WebLocalPersonalApp));
          final routerFinder = find.byWidgetPredicate((w) => w is Router);
          final routerState = tester.state(routerFinder);
          final router = tester.widget<Router<dynamic>>(routerFinder);
          expect(router.routeInformationProvider!.value.uri.path, path);
          // Flutter web resets this when handling flutter/navigation messages.
          dispatcher.defaultRouteNameTestValue = '/';
          expect(
            PersonalSetupScope.maybeOf(tester.element(routerFinder)),
            isNull,
          );
          await tester.tap(find.text('Continue locally'));
          await tester.pump();
          if (retry) {
            await tester.pumpAndSettle();
            expect(find.text('Local storage needs attention'), findsOneWidget);
            expect(tester.state(routerFinder), same(routerState));
            await tester.tap(find.text('Try again'));
            await tester.pump();
          }
          expect(find.text('Opening local storage…'), findsOneWidget);
          expect(find.text('Add prescription'), findsNothing);
          expect(find.text('Add schedule'), findsNothing);
          expect(
            PersonalSetupScope.maybeOf(tester.element(routerFinder)),
            isNull,
          );
          pending.complete(ready(database));
          await tester.runAsync(() => database.initializationStarted.future);
          // Even an external rebuild during profile initialization must not
          // publish the already-created dependencies or replace the router.
          await tester.pumpWidget(WebLocalPersonalStartupApp(startup: owner));
          expect(owner.result, isA<WebStorageReady>());
          expect(owner.loading, isTrue);
          expect(owner.setup, isNotNull);
          expect(
            PersonalSetupScope.maybeOf(tester.element(routerFinder)),
            isNull,
          );
          expect(tester.state(routerFinder), same(routerState));
          expect(find.text('Opening local storage…'), findsOneWidget);
          expect(find.text('Add prescription'), findsNothing);
          final initialized = Completer<void>();
          owner.addListener(() {
            if (!owner.loading && !initialized.isCompleted) {
              initialized.complete();
            }
          });
          database.allowInitialization.complete();
          await tester.runAsync(() => initialized.future);
          await tester.pumpAndSettle();
          expect(owner.loading, isFalse);
          expect(owner.result, isA<WebStorageReady>());
          expect(
            tester
                .widget<Router<dynamic>>(routerFinder)
                .routeInformationProvider!
                .value
                .uri
                .path,
            path,
          );
          expect(
            find.text(
              path == '/unknown'
                  ? 'Page not found'
                  : path == '/prescriptions'
                  ? 'Medication cabinet'
                  : 'Routine builder',
            ),
            findsOneWidget,
          );
          expect(
            tester.state(find.byType(WebLocalPersonalApp)),
            same(appState),
          );
          expect(tester.state(routerFinder), same(routerState));
          final readyRouter = tester.widget<Router<dynamic>>(routerFinder);
          expect(readyRouter.routerDelegate, same(router.routerDelegate));
          expect(
            readyRouter.routeInformationProvider,
            same(router.routeInformationProvider),
          );
          expect(readyRouter.routeInformationProvider!.value.uri.path, path);
          expect(opens, retry ? 2 : 1);
          expect(owner.loading, isFalse);
          expect(owner.result, isA<WebStorageReady>());
          expect(
            PersonalSetupScope.maybeOf(tester.element(routerFinder)),
            same(owner.setup),
          );
          expect(tester.takeException(), isNull);
        } finally {
          if (!pending.isCompleted) pending.complete(ready(database));
          if (!database.allowInitialization.isCompleted) {
            database.allowInitialization.complete();
          }
          await tester.runAsync(() async {
            await tester.pumpWidget(const SizedBox());
            await owner.shutdown();
          });
          dispatcher.clearDefaultRouteNameTestValue();
        }
        expect(database.closes, 1);
      });
    }
  }

  testWidgets('uncertain cleanup has no retry button or editable shell', (
    tester,
  ) async {
    final owner = WebLocalPersonalStartup(
      bootstrap: () => openWebStorage(
        open: () async => DatabaseConnection(FailingExecutor(failClose: true)),
        implementation: WebStorageImplementation.opfsShared,
        missingFeatures: const {},
      ),
    );
    await tester.pumpWidget(WebLocalPersonalStartupApp(startup: owner));
    await tester.tap(find.text('Continue locally'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Retry is disabled'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Today'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final failClose in [false, true]) {
    test(
      'actual failed SELECT cleanup ${failClose ? 'uncertain locks retry' : 'completed allows retry'}',
      () async {
        final executor = FailingExecutor(
          failClose: failClose,
          failSelect: true,
        );
        var opens = 0;
        final owner = WebLocalPersonalStartup(
          bootstrap: () async {
            opens++;
            if (opens > 1) return ready();
            return openWebStorage(
              open: () async => DatabaseConnection(executor),
              implementation: WebStorageImplementation.opfsShared,
              missingFeatures: const {},
            );
          },
        );
        await owner.start();
        final result = owner.result as WebStorageStartupRecovery;
        expect(result.error, same(executor.openError));
        expect(result.stackTrace.toString(), isNotEmpty);
        expect(
          result.cleanup,
          failClose ? WebStorageCleanup.uncertain : WebStorageCleanup.completed,
        );
        expect(
          result.cleanupError,
          failClose ? same(executor.closeError) : isNull,
        );
        expect(result.cleanupStackTrace, failClose ? isNotNull : isNull);
        expect(executor.closes, 1);
        await owner.start();
        await owner.start();
        expect(opens, failClose ? 1 : 2);
        expect(
          owner.result,
          failClose ? isA<WebStorageStartupRecovery>() : isA<WebStorageReady>(),
        );
        await owner.shutdown();
        owner.dispose();
        expect(executor.closes, 1);
      },
    );
  }

  test(
    'reentrant start and shutdown drain a late ready result exactly once',
    () async {
      final pending = Completer<WebStorageBootstrapResult>();
      final database = CountingDatabase();
      var opens = 0;
      final owner = WebLocalPersonalStartup(
        bootstrap: () {
          opens++;
          return pending.future;
        },
      );
      final opening = owner.start();
      await owner.start();
      final shutdown = owner.shutdown();
      owner.dispose();
      pending.complete(ready(database));
      await opening;
      await shutdown;
      await owner.shutdown();
      expect(opens, 1);
      expect(database.closes, 1);
      expect(owner.result, isNot(isA<WebStorageReady>()));
    },
  );

  test(
    'shutdown close failure is retained and surfaced, never reopened',
    () async {
      final database = CountingDatabase(failClose: true);
      WebStorageStartupRecovery? surfaced;
      final owner = WebLocalPersonalStartup(
        bootstrap: () async => ready(database),
        onShutdownFailure: (failure) => surfaced = failure,
      );
      await owner.start();
      await owner.shutdown();
      await owner.shutdown();
      await owner.start();
      expect(surfaced?.cleanup, WebStorageCleanup.uncertain);
      expect(surfaced?.cleanupError, same(database.closeError));
      expect(owner.result, same(surfaced));
      expect(database.closes, 1);
      owner.dispose();
    },
  );

  testWidgets('unsupported storage does not expose a shell or mutation', (
    tester,
  ) async {
    final owner = WebLocalPersonalStartup(
      bootstrap: () async => WebStorageDemoOnly(
        classification: classifyWebStorage(WebStorageImplementation.inMemory),
        missingFeatures: const {},
      ),
    );
    await tester.pumpWidget(WebLocalPersonalStartupApp(startup: owner));
    await tester.tap(find.text('Continue locally'));
    await tester.pumpAndSettle();
    expect(find.text('Supported local storage is unavailable'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Add prescription'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'rejected connection is recovery without pretending cleanup ran',
    () async {
      final error = StateError('connection rejected');
      final result =
          await openWebStorage(
                open: () => Future.error(error),
                implementation: WebStorageImplementation.opfsLocks,
                missingFeatures: const {},
              )
              as WebStorageStartupRecovery;
      expect(result.error, same(error));
      expect(result.cleanup, WebStorageCleanup.notNeeded);
    },
  );
}

WebStorageReady ready([DoseyDatabase? database]) => WebStorageReady(
  database: database ?? CountingDatabase(),
  classification: classifyWebStorage(WebStorageImplementation.opfsShared),
  missingFeatures: const {},
);

class CountingDatabase extends DoseyDatabase {
  CountingDatabase({this.failClose = false}) : super(NativeDatabase.memory());
  final bool failClose;
  final closeError = StateError('close failed');
  int closes = 0;
  @override
  Future<void> close() async {
    closes++;
    await super.close();
    if (failClose) throw closeError;
  }
}

class GatedProfileDatabase extends CountingDatabase {
  final initializationStarted = Completer<void>();
  final allowInitialization = Completer<void>();

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    if (!initializationStarted.isCompleted) initializationStarted.complete();
    await allowInitialization.future;
    return super.transaction(action, requireNew: requireNew);
  }
}

class FailingExecutor implements QueryExecutor {
  FailingExecutor({required this.failClose, this.failSelect = false});
  final bool failClose;
  final bool failSelect;
  final openError = StateError('initial database open failed');
  final closeError = StateError('executor close failed');
  int closes = 0;
  @override
  SqlDialect get dialect => SqlDialect.sqlite;
  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    if (!failSelect) throw openError;
    return true;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    expect(statement, 'SELECT 1');
    throw openError;
  }

  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw closeError;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
