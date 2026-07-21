enum DoseyVoicePhrase {
  awake,
  helloHere,
  ready,
  robotModeOn,
  goingQuiet,
  doseSoon,
  almostTime,
  scheduledDoseReady,
  checkCupTime,
  checkCupBeforeTaking,
  preparingNextDose,
  dispensingNow,
  movingCarousel,
  waitWhileMove,
  movementFinished,
  dispenserFinishedMoving,
  checkRightDose,
  confirmBeforeTaking,
  confirmAfterTaken,
  doNotMarkTaken,
  stopAskHelp,
  cannotVerifyPills,
  askProfessional,
  willNotMarkTaken,
  missedWarning,
  missedNeedsReview,
  reviewMissedAlert,
  notMarkedTaken,
  controllerOffline,
  needsCheckingBeforeContinue,
}

class FixedPhraseDefinition {
  const FixedPhraseDefinition({
    required this.phrase,
    required this.text,
    required this.assetPath,
  });

  final DoseyVoicePhrase phrase;
  final String text;
  final String assetPath;
}

class FixedPhraseCatalog {
  static const String assetDirectory = 'assets/voice/';

  static const List<FixedPhraseDefinition> phrases = <FixedPhraseDefinition>[
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.awake,
      text: 'Dosey is awake.',
      assetPath: '${assetDirectory}wake_dosey_awake.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.helloHere,
      text: 'Hello. I am here.',
      assetPath: '${assetDirectory}wake_hello_here.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.ready,
      text: 'I am ready.',
      assetPath: '${assetDirectory}wake_ready.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.robotModeOn,
      text: 'Robot Mode is on.',
      assetPath: '${assetDirectory}mode_robot_on.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.goingQuiet,
      text: 'I am going quiet now.',
      assetPath: '${assetDirectory}wake_going_quiet.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.doseSoon,
      text: 'Your dose is coming up soon.',
      assetPath: '${assetDirectory}reminder_dose_soon.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.almostTime,
      text: 'It is almost time for your dose.',
      assetPath: '${assetDirectory}reminder_almost_time.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.scheduledDoseReady,
      text: 'Your scheduled dose is ready.',
      assetPath: '${assetDirectory}reminder_scheduled_ready.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.checkCupTime,
      text: 'It is time to check the cup.',
      assetPath: '${assetDirectory}reminder_check_cup_time.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.checkCupBeforeTaking,
      text: 'Please check the cup before taking anything.',
      assetPath: '${assetDirectory}reminder_check_cup_before_taking.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.preparingNextDose,
      text: 'Preparing the next dose.',
      assetPath: '${assetDirectory}dispense_prepare_next.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispensingNow,
      text: 'Dispensing now.',
      assetPath: '${assetDirectory}dispense_now.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.movingCarousel,
      text: 'Moving the carousel.',
      assetPath: '${assetDirectory}dispense_moving_carousel.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.waitWhileMove,
      text: 'Please wait while I move.',
      assetPath: '${assetDirectory}dispense_please_wait.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.movementFinished,
      text: 'Movement finished.',
      assetPath: '${assetDirectory}dispense_movement_finished.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispenserFinishedMoving,
      text: 'The dispenser finished moving.',
      assetPath: '${assetDirectory}dispense_finished_moving.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.checkRightDose,
      text: 'Please check that the right dose is in the cup.',
      assetPath: '${assetDirectory}dispense_check_right_dose.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.confirmBeforeTaking,
      text: 'Please confirm the dose before taking anything.',
      assetPath: '${assetDirectory}dispense_confirm_before_taking.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.confirmAfterTaken,
      text: 'Only confirm taken after the dose is actually taken.',
      assetPath: '${assetDirectory}safety_confirm_after_taken.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.doNotMarkTaken,
      text: 'Please do not mark this taken unless it was taken.',
      assetPath: '${assetDirectory}safety_do_not_mark_taken.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.stopAskHelp,
      text: 'If something looks wrong, stop and ask for help.',
      assetPath: '${assetDirectory}safety_stop_ask_help.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.cannotVerifyPills,
      text: 'I cannot verify the pills by myself.',
      assetPath: '${assetDirectory}safety_cannot_verify_pills.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.askProfessional,
      text: 'If you are unsure, ask your caregiver, pharmacist, or doctor.',
      assetPath: '${assetDirectory}safety_ask_professional.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.willNotMarkTaken,
      text: 'I will not mark this taken for you.',
      assetPath: '${assetDirectory}safety_will_not_mark_taken.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedWarning,
      text:
          'This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
      assetPath: '${assetDirectory}missed_approved_warning.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedNeedsReview,
      text: 'This dose needs review.',
      assetPath: '${assetDirectory}missed_needs_review.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.reviewMissedAlert,
      text: 'Please review the missed dose alert.',
      assetPath: '${assetDirectory}missed_review_alert.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.notMarkedTaken,
      text: 'This has not been marked taken.',
      assetPath: '${assetDirectory}missed_not_marked_taken.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.controllerOffline,
      text: 'I cannot reach the controller right now.',
      assetPath: '${assetDirectory}controller_offline.wav',
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.needsCheckingBeforeContinue,
      text: 'Something needs checking before I can continue.',
      assetPath: '${assetDirectory}controller_needs_checking.wav',
    ),
  ];

  static final Map<DoseyVoicePhrase, FixedPhraseDefinition> byPhrase =
      Map<DoseyVoicePhrase, FixedPhraseDefinition>.unmodifiable(
        <DoseyVoicePhrase, FixedPhraseDefinition>{
          for (final phrase in phrases) phrase.phrase: phrase,
        },
      );

  static FixedPhraseDefinition definitionFor(DoseyVoicePhrase phrase) {
    return byPhrase[phrase]!;
  }
}
