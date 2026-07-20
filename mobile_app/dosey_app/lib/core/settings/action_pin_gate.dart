import 'package:dosey_app/core/settings/local_app_settings_repository.dart';

class ActionPinGate {
  const ActionPinGate(this._settings);

  final LocalAppSettingsRepository _settings;

  Future<bool> authorize({
    required Future<String?> Function() requestPin,
  }) async {
    final pinEnabled = await _settings.isActionPinEnabled();
    if (!pinEnabled) {
      return true;
    }

    final pin = await requestPin();
    if (pin == null) {
      return false;
    }

    return _settings.verifyActionPin(pin);
  }
}
