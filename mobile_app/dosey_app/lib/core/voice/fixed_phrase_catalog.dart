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
  stillHere,
  standingBy,
  keepingWatch,
  quietButReady,
  wakeCheckIn,
  reminderSoonCheck,
  reminderSoonGentle,
  reminderReadyCheckCup,
  reminderLookFirst,
  reminderConfirmAfter,
  dispenseStarting,
  dispenseWorking,
  dispenseHoldOn,
  dispenseDoNotTouch,
  dispenseDoneCheck,
  safetyDoubleCheck,
  safetyAskIfUnsure,
  safetyNoAutoConfirm,
  safetyCupOnly,
  safetyPauseIfWrong,
  missedStillNeedsReview,
  missedNotTakenByVoice,
  missedFollowInstructions,
  missedAskHelp,
  missedReviewFirst,
  controllerStillOffline,
  controllerReconnect,
  controllerProblem,
  controllerStopCheck,
  controllerReadyAgain,
}

enum DoseyVoicePhraseCategory {
  wakeIdle,
  reminderApproaching,
  doseReadyCupCheck,
  dispensingMovement,
  confirmationSafety,
  missedReview,
  controllerHardware,
}

class FixedPhraseDefinition {
  const FixedPhraseDefinition({
    required this.phrase,
    required this.text,
    required this.assetPath,
    required this.categories,
  });

  final DoseyVoicePhrase phrase;
  final String text;
  final String assetPath;
  final Set<DoseyVoicePhraseCategory> categories;
}

class FixedPhraseCatalog {
  static const String assetDirectory = 'assets/voice/';

  static const List<FixedPhraseDefinition> phrases = <FixedPhraseDefinition>[
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.awake,
      text: 'Dosey is awake.',
      assetPath: '${assetDirectory}wake_dosey_awake.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.helloHere,
      text: 'Hello. I am here.',
      assetPath: '${assetDirectory}wake_hello_here.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.ready,
      text: 'I am ready.',
      assetPath: '${assetDirectory}wake_ready.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.robotModeOn,
      text: 'Robot Mode is on.',
      assetPath: '${assetDirectory}mode_robot_on.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.goingQuiet,
      text: 'I am going quiet now.',
      assetPath: '${assetDirectory}wake_going_quiet.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.doseSoon,
      text: 'Your dose is coming up soon.',
      assetPath: '${assetDirectory}reminder_dose_soon.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.reminderApproaching,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.almostTime,
      text: 'It is almost time for your dose.',
      assetPath: '${assetDirectory}reminder_almost_time.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.reminderApproaching,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.scheduledDoseReady,
      text: 'Your scheduled dose is ready.',
      assetPath: '${assetDirectory}reminder_scheduled_ready.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.doseReadyCupCheck,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.checkCupTime,
      text: 'It is time to check the cup.',
      assetPath: '${assetDirectory}reminder_check_cup_time.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.doseReadyCupCheck,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.checkCupBeforeTaking,
      text: 'Please check the cup before taking anything.',
      assetPath: '${assetDirectory}reminder_check_cup_before_taking.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.doseReadyCupCheck,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.preparingNextDose,
      text: 'Preparing the next dose.',
      assetPath: '${assetDirectory}dispense_prepare_next.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispensingNow,
      text: 'Dispensing now.',
      assetPath: '${assetDirectory}dispense_now.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.movingCarousel,
      text: 'Moving the carousel.',
      assetPath: '${assetDirectory}dispense_moving_carousel.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.waitWhileMove,
      text: 'Please wait while I move.',
      assetPath: '${assetDirectory}dispense_please_wait.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.movementFinished,
      text: 'Movement finished.',
      assetPath: '${assetDirectory}dispense_movement_finished.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispenserFinishedMoving,
      text: 'The dispenser finished moving.',
      assetPath: '${assetDirectory}dispense_finished_moving.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.checkRightDose,
      text: 'Please check that the right dose is in the cup.',
      assetPath: '${assetDirectory}dispense_check_right_dose.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.confirmBeforeTaking,
      text: 'Please confirm the dose before taking anything.',
      assetPath: '${assetDirectory}dispense_confirm_before_taking.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.confirmAfterTaken,
      text: 'Only confirm taken after the dose is actually taken.',
      assetPath: '${assetDirectory}safety_confirm_after_taken.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.doNotMarkTaken,
      text: 'Please do not mark this taken unless it was taken.',
      assetPath: '${assetDirectory}safety_do_not_mark_taken.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.stopAskHelp,
      text: 'If something looks wrong, stop and ask for help.',
      assetPath: '${assetDirectory}safety_stop_ask_help.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.cannotVerifyPills,
      text: 'I cannot verify the pills by myself.',
      assetPath: '${assetDirectory}safety_cannot_verify_pills.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.askProfessional,
      text: 'If you are unsure, ask your caregiver, pharmacist, or doctor.',
      assetPath: '${assetDirectory}safety_ask_professional.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.willNotMarkTaken,
      text: 'I will not mark this taken for you.',
      assetPath: '${assetDirectory}safety_will_not_mark_taken.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedWarning,
      text:
          'This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
      assetPath: '${assetDirectory}missed_approved_warning.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedNeedsReview,
      text: 'This dose needs review.',
      assetPath: '${assetDirectory}missed_needs_review.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.reviewMissedAlert,
      text: 'Please review the missed dose alert.',
      assetPath: '${assetDirectory}missed_review_alert.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.notMarkedTaken,
      text: 'This has not been marked taken.',
      assetPath: '${assetDirectory}missed_not_marked_taken.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.controllerOffline,
      text: 'I cannot reach the controller right now.',
      assetPath: '${assetDirectory}controller_offline.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.controllerHardware,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.needsCheckingBeforeContinue,
      text: 'Something needs checking before I can continue.',
      assetPath: '${assetDirectory}controller_needs_checking.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.controllerHardware,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.stillHere,
      text: 'I am still here.',
      assetPath: '${assetDirectory}idle_still_here.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.standingBy,
      text: 'Standing by.',
      assetPath: '${assetDirectory}idle_standing_by.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.keepingWatch,
      text: 'I am keeping watch.',
      assetPath: '${assetDirectory}idle_keeping_watch.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.quietButReady,
      text: 'I will stay quiet, but I am ready.',
      assetPath: '${assetDirectory}idle_quiet_but_ready.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.wakeCheckIn,
      text: 'Checking in.',
      assetPath: '${assetDirectory}idle_checking_in.wav',
      categories: <DoseyVoicePhraseCategory>{DoseyVoicePhraseCategory.wakeIdle},
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.reminderSoonCheck,
      text: 'A dose time is getting close.',
      assetPath: '${assetDirectory}reminder_time_getting_close.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.reminderApproaching,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.reminderSoonGentle,
      text: 'I will remind you again when it is time.',
      assetPath: '${assetDirectory}reminder_again_when_time.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.reminderApproaching,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.reminderReadyCheckCup,
      text: 'The scheduled dose should be in the cup.',
      assetPath: '${assetDirectory}reminder_ready_check_cup.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.doseReadyCupCheck,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.reminderLookFirst,
      text: 'Please look in the cup before taking anything.',
      assetPath: '${assetDirectory}reminder_look_in_cup.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.doseReadyCupCheck,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.reminderConfirmAfter,
      text: 'After taking it, confirm it in the app.',
      assetPath: '${assetDirectory}reminder_confirm_after.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.doseReadyCupCheck,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispenseStarting,
      text: 'Starting the dispenser.',
      assetPath: '${assetDirectory}dispense_starting.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispenseWorking,
      text: 'The dispenser is working.',
      assetPath: '${assetDirectory}dispense_working.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispenseHoldOn,
      text: 'Hold on while the carousel moves.',
      assetPath: '${assetDirectory}dispense_hold_on.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispenseDoNotTouch,
      text: 'Please do not touch the carousel while it moves.',
      assetPath: '${assetDirectory}dispense_do_not_touch.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.dispenseDoneCheck,
      text: 'The movement is done. Please check the cup.',
      assetPath: '${assetDirectory}dispense_done_check.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.dispensingMovement,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.safetyDoubleCheck,
      text: 'Please double check before taking anything.',
      assetPath: '${assetDirectory}safety_double_check.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.safetyAskIfUnsure,
      text: 'If you are not sure, ask for help before taking it.',
      assetPath: '${assetDirectory}safety_ask_if_unsure.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.safetyNoAutoConfirm,
      text: 'I do not confirm doses automatically.',
      assetPath: '${assetDirectory}safety_no_auto_confirm.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.safetyCupOnly,
      text: 'Use what is in the cup only if it looks right.',
      assetPath: '${assetDirectory}safety_cup_only_if_right.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.safetyPauseIfWrong,
      text: 'Pause if anything looks wrong.',
      assetPath: '${assetDirectory}safety_pause_if_wrong.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.confirmationSafety,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedStillNeedsReview,
      text: 'The missed dose still needs review.',
      assetPath: '${assetDirectory}missed_still_needs_review.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedNotTakenByVoice,
      text: 'My voice did not mark this taken.',
      assetPath: '${assetDirectory}missed_voice_not_taken.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedFollowInstructions,
      text:
          'Follow your prescription instructions before deciding what to do next.',
      assetPath: '${assetDirectory}missed_follow_instructions.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedAskHelp,
      text: 'Ask your caregiver, pharmacist, or doctor if you are unsure.',
      assetPath: '${assetDirectory}missed_ask_help.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.missedReviewFirst,
      text: 'Please review this before taking any action.',
      assetPath: '${assetDirectory}missed_review_first.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.missedReview,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.controllerStillOffline,
      text: 'The controller still looks offline.',
      assetPath: '${assetDirectory}controller_still_offline.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.controllerHardware,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.controllerReconnect,
      text: 'Please check the controller connection.',
      assetPath: '${assetDirectory}controller_check_connection.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.controllerHardware,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.controllerProblem,
      text: 'The dispenser needs attention.',
      assetPath: '${assetDirectory}controller_needs_attention.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.controllerHardware,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.controllerStopCheck,
      text: 'Stop and check the dispenser before continuing.',
      assetPath: '${assetDirectory}controller_stop_check.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.controllerHardware,
      },
    ),
    FixedPhraseDefinition(
      phrase: DoseyVoicePhrase.controllerReadyAgain,
      text: 'The controller is ready again.',
      assetPath: '${assetDirectory}controller_ready_again.wav',
      categories: <DoseyVoicePhraseCategory>{
        DoseyVoicePhraseCategory.controllerHardware,
      },
    ),
  ];

  static final Map<DoseyVoicePhrase, FixedPhraseDefinition> byPhrase =
      Map<DoseyVoicePhrase, FixedPhraseDefinition>.unmodifiable(
        <DoseyVoicePhrase, FixedPhraseDefinition>{
          for (final phrase in phrases) phrase.phrase: phrase,
        },
      );

  static final Map<DoseyVoicePhraseCategory, List<FixedPhraseDefinition>>
  _phrasesByCategory =
      Map<DoseyVoicePhraseCategory, List<FixedPhraseDefinition>>.unmodifiable(
        <DoseyVoicePhraseCategory, List<FixedPhraseDefinition>>{
          for (final category in DoseyVoicePhraseCategory.values)
            category: List<FixedPhraseDefinition>.unmodifiable(
              phrases
                  .where((phrase) => phrase.categories.contains(category))
                  .toList(),
            ),
        },
      );

  static FixedPhraseDefinition definitionFor(DoseyVoicePhrase phrase) {
    return byPhrase[phrase]!;
  }

  static List<FixedPhraseDefinition> phrasesForCategory(
    DoseyVoicePhraseCategory category,
  ) {
    return _phrasesByCategory[category]!;
  }
}
