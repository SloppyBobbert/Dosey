import 'package:dosey_app/core/settings/local_app_settings_repository.dart';

class ActionPinGate {
  const ActionPinGate(this._settings);

  final LocalAppSettingsRepository _settings;

  Future<bool> isPinEnabled() {
    return _settings.isActionPinEnabled();
  }

  Future<bool> verifyPin(String pin) {
    return _settings.verifyActionPin(pin);
  }

  Future<bool> authorize({
    required Future<String?> Function() requestPin,
  }) async {
    final pinEnabled = await isPinEnabled();
    if (!pinEnabled) {
      return true;
    }

    final pin = await requestPin();
    if (pin == null) {
      return false;
    }

    return verifyPin(pin);
  }
}
