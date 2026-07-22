import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/household/household_account_state.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class LocalHouseholdRepository {
  LocalHouseholdRepository(this._database);

  static const _householdDisplayNameKey = 'household_display_name';
  static const _robotHubDisplayNameKey = 'robot_hub_display_name';
  static const _profileDisplayNameKey = 'profile_display_name';
  static const _relationshipLabelKey = 'relationship_label';
  static const _defaultHouseholdDisplayName = 'Dosey household';
  static const _defaultRobotHubDisplayName = 'Dosey robot phone';
  static const _maxDisplayNameLength = 80;

  final DoseyDatabase _database;

  Stream<HouseholdAccountState> watchState() {
    return _database
        .watchAppSettings({
          _householdDisplayNameKey,
          _robotHubDisplayNameKey,
          _profileDisplayNameKey,
          _relationshipLabelKey,
        })
        .map(_mapState);
  }

  Future<void> saveLocalNames({
    String? householdDisplayName,
    String? robotHubDisplayName,
    String? profileDisplayName,
    String? relationshipLabel,
    List<AdminAuditEvent> auditEvents = const [],
  }) {
    return _database.transaction(() async {
      if (householdDisplayName != null) {
        final normalizedName = _normalizeDisplayName(
          householdDisplayName,
          fieldName: 'householdDisplayName',
        );
        await _database.setAppSetting(_householdDisplayNameKey, normalizedName);
      }
      if (robotHubDisplayName != null) {
        final normalizedName = _normalizeDisplayName(
          robotHubDisplayName,
          fieldName: 'robotHubDisplayName',
        );
        await _database.setAppSetting(_robotHubDisplayNameKey, normalizedName);
      }
      if (profileDisplayName != null) {
        final normalizedName = _normalizeOptionalDisplayName(
          profileDisplayName,
          fieldName: 'profileDisplayName',
        );
        await _saveOptionalSetting(_profileDisplayNameKey, normalizedName);
      }
      if (relationshipLabel != null) {
        final normalizedName = _normalizeOptionalDisplayName(
          relationshipLabel,
          fieldName: 'relationshipLabel',
        );
        await _saveOptionalSetting(_relationshipLabelKey, normalizedName);
      }
      for (final auditEvent in auditEvents) {
        await LocalAdminAuditRepository.insertEventIntoDatabase(
          _database,
          auditEvent,
        );
      }
    });
  }

  HouseholdAccountState _mapState(List<AppSetting> settings) {
    final values = {for (final setting in settings) setting.key: setting.value};

    return HouseholdAccountState(
      householdDisplayName:
          values[_householdDisplayNameKey] ?? _defaultHouseholdDisplayName,
      robotHubDisplayName:
          values[_robotHubDisplayNameKey] ?? _defaultRobotHubDisplayName,
      profileDisplayName: _normalizeStoredOptionalValue(
        values[_profileDisplayNameKey],
      ),
      relationshipLabel: _normalizeStoredOptionalValue(
        values[_relationshipLabelKey],
      ),
      connectionState: HouseholdConnectionState.localOnly,
      cloudHouseholdId: null,
    );
  }

  Future<void> _saveOptionalSetting(String key, String? value) async {
    if (value == null) {
      await _database.deleteAppSettings({key});
      return;
    }
    await _database.setAppSetting(key, value);
  }

  static String _normalizeDisplayName(
    String value, {
    required String fieldName,
  }) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Display name must not be blank.',
      );
    }
    if (normalizedValue.length > _maxDisplayNameLength) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Display name must be $_maxDisplayNameLength characters or fewer.',
      );
    }
    return normalizedValue;
  }

  static String? _normalizeOptionalDisplayName(
    String value, {
    required String fieldName,
  }) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      return null;
    }
    if (normalizedValue.length > _maxDisplayNameLength) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Display name must be $_maxDisplayNameLength characters or fewer.',
      );
    }
    return normalizedValue;
  }

  static String? _normalizeStoredOptionalValue(String? value) {
    if (value == null) return null;
    final normalizedValue = value.trim();
    return normalizedValue.isEmpty ? null : normalizedValue;
  }
}
