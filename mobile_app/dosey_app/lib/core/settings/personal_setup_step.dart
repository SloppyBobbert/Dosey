enum PersonalSetupStep {
  chooseNextAction('choose_next_action'),
  orientThenAddMedication('orient_then_add_medication'),
  orientThenPairRobot('orient_then_pair_robot'),
  complete('complete');

  const PersonalSetupStep(this.storageValue);

  final String storageValue;

  static PersonalSetupStep? fromStorageValue(String value) {
    for (final step in values) {
      if (step.storageValue == value) return step;
    }
    return null;
  }
}
