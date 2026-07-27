enum AppThemePreference {
  dark('dark'),
  light('light'),
  system('system');

  const AppThemePreference(this.storageValue);

  final String storageValue;

  static AppThemePreference? fromStorageValue(String value) {
    for (final preference in values) {
      if (preference.storageValue == value) return preference;
    }
    return null;
  }
}
