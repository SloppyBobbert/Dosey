import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:dosey_app/features/shared/protected_admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'pending local setup form drops focus and ignores keyboard activation',
    (tester) async {
      final db = DoseyDatabase.inMemory();
      addTearDown(db.close);
      final cancelFocus = FocusNode();
      addTearDown(cancelFocus.dispose);
      var pending = false;
      var cancelled = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        PersonalSetupScope(
          dependencies: PersonalSetupDependencies.local(db),
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return protectSetupForm(
                    context,
                    pending,
                    TextButton(
                      focusNode: cancelFocus,
                      autofocus: true,
                      onPressed: () => cancelled++,
                      child: const Text('Cancel'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(cancelFocus.hasFocus, isTrue);
      rebuild(() => pending = true);
      await tester.pump();
      // AbsorbPointer alone left the button focused, so Enter could still pop
      // the route while the save was pending.
      expect(cancelFocus.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(cancelled, 0);
      // The block must lift again once the action is no longer pending.
      rebuild(() => pending = false);
      await tester.pump();
      cancelFocus.requestFocus();
      await tester.pump();
      expect(cancelFocus.hasFocus, isTrue);
    },
  );
}
