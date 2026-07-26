import 'dart:io';

import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fixed phrase catalog matches the approved 72 phrases verbatim', () {
    expect(FixedPhraseCatalog.phrases, hasLength(72));
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
      'I am still here.',
      'Standing by.',
      'I am keeping watch.',
      'I will stay quiet, but I am ready.',
      'Checking in.',
      'A dose time is getting close.',
      'I will remind you again when it is time.',
      'The scheduled dose should be in the cup.',
      'Please look in the cup before taking anything.',
      'After taking it, confirm it in the app.',
      'Starting the dispenser.',
      'The dispenser is working.',
      'Hold on while the carousel moves.',
      'Please do not touch the carousel while it moves.',
      'The movement is done. Please check the cup.',
      'Please double check before taking anything.',
      'If you are not sure, ask for help before taking it.',
      'I do not confirm doses automatically.',
      'Use what is in the cup only if it looks right.',
      'Pause if anything looks wrong.',
      'The missed dose still needs review.',
      'My voice did not mark this taken.',
      'Follow your prescription instructions before deciding what to do next.',
      'Ask your caregiver, pharmacist, or doctor if you are unsure.',
      'Please review this before taking any action.',
      'The controller still looks offline.',
      'Please check the controller connection.',
      'The dispenser needs attention.',
      'Stop and check the dispenser before continuing.',
      'The controller is ready again.',
      'Your next dose time is getting closer.',
      'A scheduled dose is coming up.',
      'I will let you know when your dose is ready.',
      'Your dose is ready. Please check the cup.',
      'It is dose time. Look in the cup before taking anything.',
      'Please check that the scheduled dose looks right.',
      'I am starting the carousel now.',
      'The carousel is moving. Please wait.',
      'The dispenser is moving your next dose.',
      'The carousel has stopped. Please check the cup.',
      'Check the cup and make sure the dose looks right.',
      'Only confirm taken after you have taken the dose.',
    ]);
  });

  test('every phrase category stays non-empty', () {
    for (final category in DoseyVoicePhraseCategory.values) {
      expect(
        FixedPhraseCatalog.phrasesForCategory(category),
        isNotEmpty,
        reason: 'Expected $category to keep at least one fixed phrase.',
      );
    }
  });

  test(
    'fixed phrase assets stay unique and under the voice asset directory',
    () {
      final assets = FixedPhraseCatalog.phrases
          .map((phrase) => phrase.assetPath)
          .toList();

      expect(assets.toSet(), hasLength(assets.length));
      expect(
        assets.every(
          (asset) => asset.startsWith(FixedPhraseCatalog.assetDirectory),
        ),
        isTrue,
      );
    },
  );

  test('every fixed phrase asset path resolves to a bundled voice file', () {
    for (final phrase in FixedPhraseCatalog.phrases) {
      expect(
        File(phrase.assetPath).existsSync(),
        isTrue,
        reason:
            'Missing bundled voice asset for ${phrase.phrase}: ${phrase.assetPath}',
      );
    }
  });

  test('phrase categories expose safe grouped choices', () {
    expect(
      FixedPhraseCatalog.phrasesForCategory(
        DoseyVoicePhraseCategory.wakeIdle,
      ).map((phrase) => phrase.phrase),
      containsAll(<DoseyVoicePhrase>[
        DoseyVoicePhrase.awake,
        DoseyVoicePhrase.stillHere,
      ]),
    );
    expect(
      FixedPhraseCatalog.phrasesForCategory(
        DoseyVoicePhraseCategory.confirmationSafety,
      ).map((phrase) => phrase.phrase),
      containsAll(<DoseyVoicePhrase>[
        DoseyVoicePhrase.checkRightDose,
        DoseyVoicePhrase.safetyNoAutoConfirm,
      ]),
    );
  });

  test('common event categories include the new wording variants', () {
    final expectedByCategory = {
      DoseyVoicePhraseCategory.reminderApproaching: <DoseyVoicePhrase>{
        DoseyVoicePhrase.nextDoseGettingCloser,
        DoseyVoicePhrase.scheduledDoseComingUp,
        DoseyVoicePhrase.notifyWhenDoseReady,
      },
      DoseyVoicePhraseCategory.doseReadyCupCheck: <DoseyVoicePhrase>{
        DoseyVoicePhrase.doseReadyCheckCup,
        DoseyVoicePhrase.doseTimeLookInCup,
        DoseyVoicePhrase.scheduledDoseLooksRight,
      },
      DoseyVoicePhraseCategory.dispensingMovement: <DoseyVoicePhrase>{
        DoseyVoicePhrase.startingCarouselNow,
        DoseyVoicePhrase.carouselMovingPleaseWait,
        DoseyVoicePhrase.movingNextDose,
      },
      DoseyVoicePhraseCategory.confirmationSafety: <DoseyVoicePhrase>{
        DoseyVoicePhrase.carouselStoppedCheckCup,
        DoseyVoicePhrase.checkCupDoseLooksRight,
        DoseyVoicePhrase.confirmOnlyAfterTaken,
      },
    };

    for (final entry in expectedByCategory.entries) {
      expect(
        FixedPhraseCatalog.phrasesForCategory(
          entry.key,
        ).map((phrase) => phrase.phrase),
        containsAll(entry.value),
      );
    }
  });

  test('missed category does not contain unsafe double-dose advice', () {
    final missedTexts = FixedPhraseCatalog.phrasesForCategory(
      DoseyVoicePhraseCategory.missedReview,
    ).map((phrase) => phrase.text.toLowerCase());

    expect(
      missedTexts.any(
        (text) => text.contains('double dose') || text.contains('double-dose'),
      ),
      isFalse,
    );
  });
}
