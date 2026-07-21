import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fixed phrase catalog matches the approved 30 phrases verbatim', () {
    expect(FixedPhraseCatalog.phrases, hasLength(30));
    expect(FixedPhraseCatalog.phrases.map((phrase) => phrase.text).toList(), <
      String
    >[
      'Dosey is awake.',
      'Hello. I am here.',
      'I am ready.',
      'Robot Mode is on.',
      'I am going quiet now.',
      'Your dose is coming up soon.',
      'It is almost time for your dose.',
      'Your scheduled dose is ready.',
      'It is time to check the cup.',
      'Please check the cup before taking anything.',
      'Preparing the next dose.',
      'Dispensing now.',
      'Moving the carousel.',
      'Please wait while I move.',
      'Movement finished.',
      'The dispenser finished moving.',
      'Please check that the right dose is in the cup.',
      'Please confirm the dose before taking anything.',
      'Only confirm taken after the dose is actually taken.',
      'Please do not mark this taken unless it was taken.',
      'If something looks wrong, stop and ask for help.',
      'I cannot verify the pills by myself.',
      'If you are unsure, ask your caregiver, pharmacist, or doctor.',
      'I will not mark this taken for you.',
      'This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
      'This dose needs review.',
      'Please review the missed dose alert.',
      'This has not been marked taken.',
      'I cannot reach the controller right now.',
      'Something needs checking before I can continue.',
    ]);
  });

  test(
    'fixed phrase assets stay unique and under the voice asset directory',
    () {
      final assets = FixedPhraseCatalog.phrases
          .map((phrase) => phrase.assetPath)
          .toList();

      expect(assets.toSet(), hasLength(30));
      expect(
        assets.every(
          (asset) => asset.startsWith(FixedPhraseCatalog.assetDirectory),
        ),
        isTrue,
      );
    },
  );
}
