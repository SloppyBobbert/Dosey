enum RobotOnboardingStep {
  chooseMode('choose_mode'),
  notificationSetup('notification_setup'),
  orientation('orientation'),
  pairing('pairing');

  const RobotOnboardingStep(this.storageValue);

  final String storageValue;

  static RobotOnboardingStep? fromStorageValue(String value) {
    for (final step in values) {
      if (step.storageValue == value) return step;
    }
    return null;
  }
}
