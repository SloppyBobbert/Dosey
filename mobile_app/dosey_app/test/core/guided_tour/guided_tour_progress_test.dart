import 'package:dosey_app/core/guided_tour/guided_tour_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unseen progress is the default persisted baseline', () {
    const progress = GuidedTourProgress.unseen();

    expect(progress.version, 0);
    expect(progress.state, GuidedTourState.unseen);
    expect(progress.step, 0);
  });

  test(
    'current version progress supports in-progress, skipped, and completed',
    () {
      expect(
        GuidedTourProgress.inProgress(step: 2),
        isA<GuidedTourProgress>()
            .having(
              (progress) => progress.version,
              'version',
              guidedTourVersion,
            )
            .having(
              (progress) => progress.state,
              'state',
              GuidedTourState.inProgress,
            )
            .having((progress) => progress.step, 'step', 2),
      );
      expect(
        GuidedTourProgress.skipped(step: 3),
        GuidedTourProgress.fromStorageValues(
          version: '$guidedTourVersion',
          state: 'skipped',
          step: '3',
        ),
      );
      expect(
        GuidedTourProgress.completed(step: 4),
        GuidedTourProgress.fromStorageValues(
          version: '$guidedTourVersion',
          state: 'completed',
          step: '4',
        ),
      );
    },
  );

  test('current version progress rejects a negative step', () {
    expect(() => GuidedTourProgress.inProgress(step: -1), throwsArgumentError);
  });

  for (final values in <Map<String, String?>>[
    {'version': '1', 'state': 'unexpected', 'step': '0'},
    {'version': '1', 'state': 'in_progress', 'step': 'not-an-int'},
    {'version': '1', 'state': 'in_progress', 'step': '-1'},
    {'version': '1', 'state': 'in_progress'},
    {'state': 'in_progress', 'step': '0'},
    {'version': '1', 'step': '0'},
    {'version': '1', 'state': 'unseen', 'step': '0'},
    {'version': '0', 'state': 'unseen', 'step': '0'},
    {'version': '0', 'state': 'in_progress', 'step': '0'},
    {'version': '0', 'state': 'unseen', 'step': '1'},
    {'version': '2', 'state': 'in_progress', 'step': '0'},
  ]) {
    test('malformed persisted progress normalizes to unseen: $values', () {
      expect(
        GuidedTourProgress.fromStorageValues(
          version: values['version'],
          state: values['state'],
          step: values['step'],
        ),
        const GuidedTourProgress.unseen(),
      );
    });
  }
}
