// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dosey_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderSchedulesTable extends ReminderSchedules
    with TableInfo<$ReminderSchedulesTable, ReminderScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prescriptionIdMeta = const VerificationMeta(
    'prescriptionId',
  );
  @override
  late final GeneratedColumn<String> prescriptionId = GeneratedColumn<String>(
    'prescription_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('schedule-1'),
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    prescriptionId,
    profileId,
    hour,
    minute,
    isEnabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('prescription_id')) {
      context.handle(
        _prescriptionIdMeta,
        prescriptionId.isAcceptableOrUnknown(
          data['prescription_id']!,
          _prescriptionIdMeta,
        ),
      );
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    } else if (isInserting) {
      context.missing(_isEnabledMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderScheduleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      prescriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_id'],
      ),
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReminderSchedulesTable createAlias(String alias) {
    return $ReminderSchedulesTable(attachedDatabase, alias);
  }
}

class ReminderScheduleRow extends DataClass
    implements Insertable<ReminderScheduleRow> {
  final String id;
  final String label;
  final String? prescriptionId;
  final String profileId;
  final int hour;
  final int minute;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ReminderScheduleRow({
    required this.id,
    required this.label,
    this.prescriptionId,
    required this.profileId,
    required this.hour,
    required this.minute,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || prescriptionId != null) {
      map['prescription_id'] = Variable<String>(prescriptionId);
    }
    map['profile_id'] = Variable<String>(profileId);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReminderSchedulesCompanion toCompanion(bool nullToAbsent) {
    return ReminderSchedulesCompanion(
      id: Value(id),
      label: Value(label),
      prescriptionId: prescriptionId == null && nullToAbsent
          ? const Value.absent()
          : Value(prescriptionId),
      profileId: Value(profileId),
      hour: Value(hour),
      minute: Value(minute),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReminderScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderScheduleRow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      prescriptionId: serializer.fromJson<String?>(json['prescriptionId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'prescriptionId': serializer.toJson<String?>(prescriptionId),
      'profileId': serializer.toJson<String>(profileId),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReminderScheduleRow copyWith({
    String? id,
    String? label,
    Value<String?> prescriptionId = const Value.absent(),
    String? profileId,
    int? hour,
    int? minute,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReminderScheduleRow(
    id: id ?? this.id,
    label: label ?? this.label,
    prescriptionId: prescriptionId.present
        ? prescriptionId.value
        : this.prescriptionId,
    profileId: profileId ?? this.profileId,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReminderScheduleRow copyWithCompanion(ReminderSchedulesCompanion data) {
    return ReminderScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      prescriptionId: data.prescriptionId.present
          ? data.prescriptionId.value
          : this.prescriptionId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderScheduleRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('profileId: $profileId, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    prescriptionId,
    profileId,
    hour,
    minute,
    isEnabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderScheduleRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.prescriptionId == this.prescriptionId &&
          other.profileId == this.profileId &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ReminderSchedulesCompanion extends UpdateCompanion<ReminderScheduleRow> {
  final Value<String> id;
  final Value<String> label;
  final Value<String?> prescriptionId;
  final Value<String> profileId;
  final Value<int> hour;
  final Value<int> minute;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReminderSchedulesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.prescriptionId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderSchedulesCompanion.insert({
    required String id,
    required String label,
    this.prescriptionId = const Value.absent(),
    this.profileId = const Value.absent(),
    required int hour,
    required int minute,
    required bool isEnabled,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       hour = Value(hour),
       minute = Value(minute),
       isEnabled = Value(isEnabled),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReminderScheduleRow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? prescriptionId,
    Expression<String>? profileId,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (profileId != null) 'profile_id': profileId,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderSchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String?>? prescriptionId,
    Value<String>? profileId,
    Value<int>? hour,
    Value<int>? minute,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReminderSchedulesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      profileId: profileId ?? this.profileId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (prescriptionId.present) {
      map['prescription_id'] = Variable<String>(prescriptionId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('profileId: $profileId, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrescriptionsTable extends Prescriptions
    with TableInfo<$PrescriptionsTable, PrescriptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrescriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pillTypeMeta = const VerificationMeta(
    'pillType',
  );
  @override
  late final GeneratedColumn<String> pillType = GeneratedColumn<String>(
    'pill_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingDosesMeta = const VerificationMeta(
    'remainingDoses',
  );
  @override
  late final GeneratedColumn<int> remainingDoses = GeneratedColumn<int>(
    'remaining_doses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _refillThresholdMeta = const VerificationMeta(
    'refillThreshold',
  );
  @override
  late final GeneratedColumn<int> refillThreshold = GeneratedColumn<int>(
    'refill_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    pillType,
    remainingDoses,
    refillThreshold,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prescriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrescriptionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pill_type')) {
      context.handle(
        _pillTypeMeta,
        pillType.isAcceptableOrUnknown(data['pill_type']!, _pillTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_pillTypeMeta);
    }
    if (data.containsKey('remaining_doses')) {
      context.handle(
        _remainingDosesMeta,
        remainingDoses.isAcceptableOrUnknown(
          data['remaining_doses']!,
          _remainingDosesMeta,
        ),
      );
    }
    if (data.containsKey('refill_threshold')) {
      context.handle(
        _refillThresholdMeta,
        refillThreshold.isAcceptableOrUnknown(
          data['refill_threshold']!,
          _refillThresholdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrescriptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrescriptionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pillType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pill_type'],
      )!,
      remainingDoses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining_doses'],
      )!,
      refillThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refill_threshold'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PrescriptionsTable createAlias(String alias) {
    return $PrescriptionsTable(attachedDatabase, alias);
  }
}

class PrescriptionRow extends DataClass implements Insertable<PrescriptionRow> {
  final String id;
  final String name;
  final String pillType;
  final int remainingDoses;
  final int refillThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PrescriptionRow({
    required this.id,
    required this.name,
    required this.pillType,
    required this.remainingDoses,
    required this.refillThreshold,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['pill_type'] = Variable<String>(pillType);
    map['remaining_doses'] = Variable<int>(remainingDoses);
    map['refill_threshold'] = Variable<int>(refillThreshold);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PrescriptionsCompanion toCompanion(bool nullToAbsent) {
    return PrescriptionsCompanion(
      id: Value(id),
      name: Value(name),
      pillType: Value(pillType),
      remainingDoses: Value(remainingDoses),
      refillThreshold: Value(refillThreshold),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PrescriptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrescriptionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pillType: serializer.fromJson<String>(json['pillType']),
      remainingDoses: serializer.fromJson<int>(json['remainingDoses']),
      refillThreshold: serializer.fromJson<int>(json['refillThreshold']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'pillType': serializer.toJson<String>(pillType),
      'remainingDoses': serializer.toJson<int>(remainingDoses),
      'refillThreshold': serializer.toJson<int>(refillThreshold),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PrescriptionRow copyWith({
    String? id,
    String? name,
    String? pillType,
    int? remainingDoses,
    int? refillThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PrescriptionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    pillType: pillType ?? this.pillType,
    remainingDoses: remainingDoses ?? this.remainingDoses,
    refillThreshold: refillThreshold ?? this.refillThreshold,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PrescriptionRow copyWithCompanion(PrescriptionsCompanion data) {
    return PrescriptionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pillType: data.pillType.present ? data.pillType.value : this.pillType,
      remainingDoses: data.remainingDoses.present
          ? data.remainingDoses.value
          : this.remainingDoses,
      refillThreshold: data.refillThreshold.present
          ? data.refillThreshold.value
          : this.refillThreshold,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrescriptionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pillType: $pillType, ')
          ..write('remainingDoses: $remainingDoses, ')
          ..write('refillThreshold: $refillThreshold, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    pillType,
    remainingDoses,
    refillThreshold,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrescriptionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.pillType == this.pillType &&
          other.remainingDoses == this.remainingDoses &&
          other.refillThreshold == this.refillThreshold &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PrescriptionsCompanion extends UpdateCompanion<PrescriptionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> pillType;
  final Value<int> remainingDoses;
  final Value<int> refillThreshold;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PrescriptionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pillType = const Value.absent(),
    this.remainingDoses = const Value.absent(),
    this.refillThreshold = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrescriptionsCompanion.insert({
    required String id,
    required String name,
    required String pillType,
    this.remainingDoses = const Value.absent(),
    this.refillThreshold = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       pillType = Value(pillType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PrescriptionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? pillType,
    Expression<int>? remainingDoses,
    Expression<int>? refillThreshold,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pillType != null) 'pill_type': pillType,
      if (remainingDoses != null) 'remaining_doses': remainingDoses,
      if (refillThreshold != null) 'refill_threshold': refillThreshold,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrescriptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? pillType,
    Value<int>? remainingDoses,
    Value<int>? refillThreshold,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PrescriptionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pillType: pillType ?? this.pillType,
      remainingDoses: remainingDoses ?? this.remainingDoses,
      refillThreshold: refillThreshold ?? this.refillThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pillType.present) {
      map['pill_type'] = Variable<String>(pillType.value);
    }
    if (remainingDoses.present) {
      map['remaining_doses'] = Variable<int>(remainingDoses.value);
    }
    if (refillThreshold.present) {
      map['refill_threshold'] = Variable<int>(refillThreshold.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrescriptionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pillType: $pillType, ')
          ..write('remainingDoses: $remainingDoses, ')
          ..write('refillThreshold: $refillThreshold, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrescriptionRefillsTable extends PrescriptionRefills
    with TableInfo<$PrescriptionRefillsTable, PrescriptionRefillRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrescriptionRefillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prescriptionIdMeta = const VerificationMeta(
    'prescriptionId',
  );
  @override
  late final GeneratedColumn<String> prescriptionId = GeneratedColumn<String>(
    'prescription_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doseDeltaMeta = const VerificationMeta(
    'doseDelta',
  );
  @override
  late final GeneratedColumn<int> doseDelta = GeneratedColumn<int>(
    'dose_delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingAfterMeta = const VerificationMeta(
    'remainingAfter',
  );
  @override
  late final GeneratedColumn<int> remainingAfter = GeneratedColumn<int>(
    'remaining_after',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    prescriptionId,
    doseDelta,
    remainingAfter,
    occurredAt,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prescription_refills';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrescriptionRefillRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('prescription_id')) {
      context.handle(
        _prescriptionIdMeta,
        prescriptionId.isAcceptableOrUnknown(
          data['prescription_id']!,
          _prescriptionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prescriptionIdMeta);
    }
    if (data.containsKey('dose_delta')) {
      context.handle(
        _doseDeltaMeta,
        doseDelta.isAcceptableOrUnknown(data['dose_delta']!, _doseDeltaMeta),
      );
    } else if (isInserting) {
      context.missing(_doseDeltaMeta);
    }
    if (data.containsKey('remaining_after')) {
      context.handle(
        _remainingAfterMeta,
        remainingAfter.isAcceptableOrUnknown(
          data['remaining_after']!,
          _remainingAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingAfterMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrescriptionRefillRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrescriptionRefillRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      prescriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_id'],
      )!,
      doseDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dose_delta'],
      )!,
      remainingAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining_after'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $PrescriptionRefillsTable createAlias(String alias) {
    return $PrescriptionRefillsTable(attachedDatabase, alias);
  }
}

class PrescriptionRefillRow extends DataClass
    implements Insertable<PrescriptionRefillRow> {
  final String id;
  final String prescriptionId;
  final int doseDelta;
  final int remainingAfter;
  final DateTime occurredAt;
  final String? note;
  const PrescriptionRefillRow({
    required this.id,
    required this.prescriptionId,
    required this.doseDelta,
    required this.remainingAfter,
    required this.occurredAt,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['prescription_id'] = Variable<String>(prescriptionId);
    map['dose_delta'] = Variable<int>(doseDelta);
    map['remaining_after'] = Variable<int>(remainingAfter);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  PrescriptionRefillsCompanion toCompanion(bool nullToAbsent) {
    return PrescriptionRefillsCompanion(
      id: Value(id),
      prescriptionId: Value(prescriptionId),
      doseDelta: Value(doseDelta),
      remainingAfter: Value(remainingAfter),
      occurredAt: Value(occurredAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory PrescriptionRefillRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrescriptionRefillRow(
      id: serializer.fromJson<String>(json['id']),
      prescriptionId: serializer.fromJson<String>(json['prescriptionId']),
      doseDelta: serializer.fromJson<int>(json['doseDelta']),
      remainingAfter: serializer.fromJson<int>(json['remainingAfter']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'prescriptionId': serializer.toJson<String>(prescriptionId),
      'doseDelta': serializer.toJson<int>(doseDelta),
      'remainingAfter': serializer.toJson<int>(remainingAfter),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'note': serializer.toJson<String?>(note),
    };
  }

  PrescriptionRefillRow copyWith({
    String? id,
    String? prescriptionId,
    int? doseDelta,
    int? remainingAfter,
    DateTime? occurredAt,
    Value<String?> note = const Value.absent(),
  }) => PrescriptionRefillRow(
    id: id ?? this.id,
    prescriptionId: prescriptionId ?? this.prescriptionId,
    doseDelta: doseDelta ?? this.doseDelta,
    remainingAfter: remainingAfter ?? this.remainingAfter,
    occurredAt: occurredAt ?? this.occurredAt,
    note: note.present ? note.value : this.note,
  );
  PrescriptionRefillRow copyWithCompanion(PrescriptionRefillsCompanion data) {
    return PrescriptionRefillRow(
      id: data.id.present ? data.id.value : this.id,
      prescriptionId: data.prescriptionId.present
          ? data.prescriptionId.value
          : this.prescriptionId,
      doseDelta: data.doseDelta.present ? data.doseDelta.value : this.doseDelta,
      remainingAfter: data.remainingAfter.present
          ? data.remainingAfter.value
          : this.remainingAfter,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrescriptionRefillRow(')
          ..write('id: $id, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('doseDelta: $doseDelta, ')
          ..write('remainingAfter: $remainingAfter, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    prescriptionId,
    doseDelta,
    remainingAfter,
    occurredAt,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrescriptionRefillRow &&
          other.id == this.id &&
          other.prescriptionId == this.prescriptionId &&
          other.doseDelta == this.doseDelta &&
          other.remainingAfter == this.remainingAfter &&
          other.occurredAt == this.occurredAt &&
          other.note == this.note);
}

class PrescriptionRefillsCompanion
    extends UpdateCompanion<PrescriptionRefillRow> {
  final Value<String> id;
  final Value<String> prescriptionId;
  final Value<int> doseDelta;
  final Value<int> remainingAfter;
  final Value<DateTime> occurredAt;
  final Value<String?> note;
  final Value<int> rowid;
  const PrescriptionRefillsCompanion({
    this.id = const Value.absent(),
    this.prescriptionId = const Value.absent(),
    this.doseDelta = const Value.absent(),
    this.remainingAfter = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrescriptionRefillsCompanion.insert({
    required String id,
    required String prescriptionId,
    required int doseDelta,
    required int remainingAfter,
    required DateTime occurredAt,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       prescriptionId = Value(prescriptionId),
       doseDelta = Value(doseDelta),
       remainingAfter = Value(remainingAfter),
       occurredAt = Value(occurredAt);
  static Insertable<PrescriptionRefillRow> custom({
    Expression<String>? id,
    Expression<String>? prescriptionId,
    Expression<int>? doseDelta,
    Expression<int>? remainingAfter,
    Expression<DateTime>? occurredAt,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (doseDelta != null) 'dose_delta': doseDelta,
      if (remainingAfter != null) 'remaining_after': remainingAfter,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrescriptionRefillsCompanion copyWith({
    Value<String>? id,
    Value<String>? prescriptionId,
    Value<int>? doseDelta,
    Value<int>? remainingAfter,
    Value<DateTime>? occurredAt,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return PrescriptionRefillsCompanion(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      doseDelta: doseDelta ?? this.doseDelta,
      remainingAfter: remainingAfter ?? this.remainingAfter,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (prescriptionId.present) {
      map['prescription_id'] = Variable<String>(prescriptionId.value);
    }
    if (doseDelta.present) {
      map['dose_delta'] = Variable<int>(doseDelta.value);
    }
    if (remainingAfter.present) {
      map['remaining_after'] = Variable<int>(remainingAfter.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrescriptionRefillsCompanion(')
          ..write('id: $id, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('doseDelta: $doseDelta, ')
          ..write('remainingAfter: $remainingAfter, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleProfilesTable extends ScheduleProfiles
    with TableInfo<$ScheduleProfilesTable, ScheduleProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScheduleProfilesTable createAlias(String alias) {
    return $ScheduleProfilesTable(attachedDatabase, alias);
  }
}

class ScheduleProfileRow extends DataClass
    implements Insertable<ScheduleProfileRow> {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ScheduleProfileRow({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScheduleProfilesCompanion toCompanion(bool nullToAbsent) {
    return ScheduleProfilesCompanion(
      id: Value(id),
      name: Value(name),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScheduleProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScheduleProfileRow copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ScheduleProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScheduleProfileRow copyWithCompanion(ScheduleProfilesCompanion data) {
    return ScheduleProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScheduleProfilesCompanion extends UpdateCompanion<ScheduleProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ScheduleProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleProfilesCompanion.insert({
    required String id,
    required String name,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       isActive = Value(isActive),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ScheduleProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ScheduleProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarouselSlotsTable extends CarouselSlots
    with TableInfo<$CarouselSlotsTable, CarouselSlotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarouselSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotNumberMeta = const VerificationMeta(
    'slotNumber',
  );
  @override
  late final GeneratedColumn<int> slotNumber = GeneratedColumn<int>(
    'slot_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prescriptionIdMeta = const VerificationMeta(
    'prescriptionId',
  );
  @override
  late final GeneratedColumn<String> prescriptionId = GeneratedColumn<String>(
    'prescription_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    slotNumber,
    prescriptionId,
    scheduleId,
    profileId,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carousel_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarouselSlotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slot_number')) {
      context.handle(
        _slotNumberMeta,
        slotNumber.isAcceptableOrUnknown(data['slot_number']!, _slotNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_slotNumberMeta);
    }
    if (data.containsKey('prescription_id')) {
      context.handle(
        _prescriptionIdMeta,
        prescriptionId.isAcceptableOrUnknown(
          data['prescription_id']!,
          _prescriptionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prescriptionIdMeta);
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarouselSlotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarouselSlotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      slotNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot_number'],
      )!,
      prescriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_id'],
      )!,
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CarouselSlotsTable createAlias(String alias) {
    return $CarouselSlotsTable(attachedDatabase, alias);
  }
}

class CarouselSlotRow extends DataClass implements Insertable<CarouselSlotRow> {
  final String id;
  final int slotNumber;
  final String prescriptionId;
  final String scheduleId;
  final String profileId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CarouselSlotRow({
    required this.id,
    required this.slotNumber,
    required this.prescriptionId,
    required this.scheduleId,
    required this.profileId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['slot_number'] = Variable<int>(slotNumber);
    map['prescription_id'] = Variable<String>(prescriptionId);
    map['schedule_id'] = Variable<String>(scheduleId);
    map['profile_id'] = Variable<String>(profileId);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CarouselSlotsCompanion toCompanion(bool nullToAbsent) {
    return CarouselSlotsCompanion(
      id: Value(id),
      slotNumber: Value(slotNumber),
      prescriptionId: Value(prescriptionId),
      scheduleId: Value(scheduleId),
      profileId: Value(profileId),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CarouselSlotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarouselSlotRow(
      id: serializer.fromJson<String>(json['id']),
      slotNumber: serializer.fromJson<int>(json['slotNumber']),
      prescriptionId: serializer.fromJson<String>(json['prescriptionId']),
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'slotNumber': serializer.toJson<int>(slotNumber),
      'prescriptionId': serializer.toJson<String>(prescriptionId),
      'scheduleId': serializer.toJson<String>(scheduleId),
      'profileId': serializer.toJson<String>(profileId),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CarouselSlotRow copyWith({
    String? id,
    int? slotNumber,
    String? prescriptionId,
    String? scheduleId,
    String? profileId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CarouselSlotRow(
    id: id ?? this.id,
    slotNumber: slotNumber ?? this.slotNumber,
    prescriptionId: prescriptionId ?? this.prescriptionId,
    scheduleId: scheduleId ?? this.scheduleId,
    profileId: profileId ?? this.profileId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CarouselSlotRow copyWithCompanion(CarouselSlotsCompanion data) {
    return CarouselSlotRow(
      id: data.id.present ? data.id.value : this.id,
      slotNumber: data.slotNumber.present
          ? data.slotNumber.value
          : this.slotNumber,
      prescriptionId: data.prescriptionId.present
          ? data.prescriptionId.value
          : this.prescriptionId,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarouselSlotRow(')
          ..write('id: $id, ')
          ..write('slotNumber: $slotNumber, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('profileId: $profileId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    slotNumber,
    prescriptionId,
    scheduleId,
    profileId,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarouselSlotRow &&
          other.id == this.id &&
          other.slotNumber == this.slotNumber &&
          other.prescriptionId == this.prescriptionId &&
          other.scheduleId == this.scheduleId &&
          other.profileId == this.profileId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CarouselSlotsCompanion extends UpdateCompanion<CarouselSlotRow> {
  final Value<String> id;
  final Value<int> slotNumber;
  final Value<String> prescriptionId;
  final Value<String> scheduleId;
  final Value<String> profileId;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CarouselSlotsCompanion({
    this.id = const Value.absent(),
    this.slotNumber = const Value.absent(),
    this.prescriptionId = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarouselSlotsCompanion.insert({
    required String id,
    required int slotNumber,
    required String prescriptionId,
    required String scheduleId,
    required String profileId,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       slotNumber = Value(slotNumber),
       prescriptionId = Value(prescriptionId),
       scheduleId = Value(scheduleId),
       profileId = Value(profileId),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CarouselSlotRow> custom({
    Expression<String>? id,
    Expression<int>? slotNumber,
    Expression<String>? prescriptionId,
    Expression<String>? scheduleId,
    Expression<String>? profileId,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slotNumber != null) 'slot_number': slotNumber,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (profileId != null) 'profile_id': profileId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarouselSlotsCompanion copyWith({
    Value<String>? id,
    Value<int>? slotNumber,
    Value<String>? prescriptionId,
    Value<String>? scheduleId,
    Value<String>? profileId,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CarouselSlotsCompanion(
      id: id ?? this.id,
      slotNumber: slotNumber ?? this.slotNumber,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      scheduleId: scheduleId ?? this.scheduleId,
      profileId: profileId ?? this.profileId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (slotNumber.present) {
      map['slot_number'] = Variable<int>(slotNumber.value);
    }
    if (prescriptionId.present) {
      map['prescription_id'] = Variable<String>(prescriptionId.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarouselSlotsCompanion(')
          ..write('id: $id, ')
          ..write('slotNumber: $slotNumber, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('profileId: $profileId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuthSessionsTable extends AuthSessions
    with TableInfo<$AuthSessionsTable, AuthSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuthSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    email,
    displayName,
    photoUrl,
    provider,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'auth_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuthSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuthSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuthSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AuthSessionsTable createAlias(String alias) {
    return $AuthSessionsTable(attachedDatabase, alias);
  }
}

class AuthSessionRow extends DataClass implements Insertable<AuthSessionRow> {
  final String id;
  final String userId;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String provider;
  final DateTime updatedAt;
  const AuthSessionRow({
    required this.id,
    required this.userId,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    map['provider'] = Variable<String>(provider);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AuthSessionsCompanion toCompanion(bool nullToAbsent) {
    return AuthSessionsCompanion(
      id: Value(id),
      userId: Value(userId),
      email: Value(email),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      provider: Value(provider),
      updatedAt: Value(updatedAt),
    );
  }

  factory AuthSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuthSessionRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      provider: serializer.fromJson<String>(json['provider']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String?>(displayName),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'provider': serializer.toJson<String>(provider),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AuthSessionRow copyWith({
    String? id,
    String? userId,
    String? email,
    Value<String?> displayName = const Value.absent(),
    Value<String?> photoUrl = const Value.absent(),
    String? provider,
    DateTime? updatedAt,
  }) => AuthSessionRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    email: email ?? this.email,
    displayName: displayName.present ? displayName.value : this.displayName,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    provider: provider ?? this.provider,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AuthSessionRow copyWithCompanion(AuthSessionsCompanion data) {
    return AuthSessionRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      email: data.email.present ? data.email.value : this.email,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      provider: data.provider.present ? data.provider.value : this.provider,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuthSessionRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('provider: $provider, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    email,
    displayName,
    photoUrl,
    provider,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthSessionRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.photoUrl == this.photoUrl &&
          other.provider == this.provider &&
          other.updatedAt == this.updatedAt);
}

class AuthSessionsCompanion extends UpdateCompanion<AuthSessionRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> email;
  final Value<String?> displayName;
  final Value<String?> photoUrl;
  final Value<String> provider;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AuthSessionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.provider = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuthSessionsCompanion.insert({
    required String id,
    required String userId,
    required String email,
    this.displayName = const Value.absent(),
    this.photoUrl = const Value.absent(),
    required String provider,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       email = Value(email),
       provider = Value(provider),
       updatedAt = Value(updatedAt);
  static Insertable<AuthSessionRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? photoUrl,
    Expression<String>? provider,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (provider != null) 'provider': provider,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuthSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? email,
    Value<String?>? displayName,
    Value<String?>? photoUrl,
    Value<String>? provider,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AuthSessionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider ?? this.provider,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuthSessionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('provider: $provider, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DoseLogEventsTable extends DoseLogEvents
    with TableInfo<$DoseLogEventsTable, DoseLogEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DoseLogEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doseIdMeta = const VerificationMeta('doseId');
  @override
  late final GeneratedColumn<String> doseId = GeneratedColumn<String>(
    'dose_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marksDoseTakenMeta = const VerificationMeta(
    'marksDoseTaken',
  );
  @override
  late final GeneratedColumn<bool> marksDoseTaken = GeneratedColumn<bool>(
    'marks_dose_taken',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("marks_dose_taken" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    doseId,
    occurredAt,
    marksDoseTaken,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dose_log_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<DoseLogEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('dose_id')) {
      context.handle(
        _doseIdMeta,
        doseId.isAcceptableOrUnknown(data['dose_id']!, _doseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_doseIdMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('marks_dose_taken')) {
      context.handle(
        _marksDoseTakenMeta,
        marksDoseTaken.isAcceptableOrUnknown(
          data['marks_dose_taken']!,
          _marksDoseTakenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marksDoseTakenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DoseLogEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DoseLogEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      doseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dose_id'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      marksDoseTaken: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marks_dose_taken'],
      )!,
    );
  }

  @override
  $DoseLogEventsTable createAlias(String alias) {
    return $DoseLogEventsTable(attachedDatabase, alias);
  }
}

class DoseLogEventRow extends DataClass implements Insertable<DoseLogEventRow> {
  final String id;
  final String kind;
  final String doseId;
  final DateTime occurredAt;
  final bool marksDoseTaken;
  const DoseLogEventRow({
    required this.id,
    required this.kind,
    required this.doseId,
    required this.occurredAt,
    required this.marksDoseTaken,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['dose_id'] = Variable<String>(doseId);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['marks_dose_taken'] = Variable<bool>(marksDoseTaken);
    return map;
  }

  DoseLogEventsCompanion toCompanion(bool nullToAbsent) {
    return DoseLogEventsCompanion(
      id: Value(id),
      kind: Value(kind),
      doseId: Value(doseId),
      occurredAt: Value(occurredAt),
      marksDoseTaken: Value(marksDoseTaken),
    );
  }

  factory DoseLogEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DoseLogEventRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      doseId: serializer.fromJson<String>(json['doseId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      marksDoseTaken: serializer.fromJson<bool>(json['marksDoseTaken']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'doseId': serializer.toJson<String>(doseId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'marksDoseTaken': serializer.toJson<bool>(marksDoseTaken),
    };
  }

  DoseLogEventRow copyWith({
    String? id,
    String? kind,
    String? doseId,
    DateTime? occurredAt,
    bool? marksDoseTaken,
  }) => DoseLogEventRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    doseId: doseId ?? this.doseId,
    occurredAt: occurredAt ?? this.occurredAt,
    marksDoseTaken: marksDoseTaken ?? this.marksDoseTaken,
  );
  DoseLogEventRow copyWithCompanion(DoseLogEventsCompanion data) {
    return DoseLogEventRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      doseId: data.doseId.present ? data.doseId.value : this.doseId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      marksDoseTaken: data.marksDoseTaken.present
          ? data.marksDoseTaken.value
          : this.marksDoseTaken,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoseLogEventRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('doseId: $doseId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('marksDoseTaken: $marksDoseTaken')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, doseId, occurredAt, marksDoseTaken);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoseLogEventRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.doseId == this.doseId &&
          other.occurredAt == this.occurredAt &&
          other.marksDoseTaken == this.marksDoseTaken);
}

class DoseLogEventsCompanion extends UpdateCompanion<DoseLogEventRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> doseId;
  final Value<DateTime> occurredAt;
  final Value<bool> marksDoseTaken;
  final Value<int> rowid;
  const DoseLogEventsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.doseId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.marksDoseTaken = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DoseLogEventsCompanion.insert({
    required String id,
    required String kind,
    required String doseId,
    required DateTime occurredAt,
    required bool marksDoseTaken,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       doseId = Value(doseId),
       occurredAt = Value(occurredAt),
       marksDoseTaken = Value(marksDoseTaken);
  static Insertable<DoseLogEventRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? doseId,
    Expression<DateTime>? occurredAt,
    Expression<bool>? marksDoseTaken,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (doseId != null) 'dose_id': doseId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (marksDoseTaken != null) 'marks_dose_taken': marksDoseTaken,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DoseLogEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? doseId,
    Value<DateTime>? occurredAt,
    Value<bool>? marksDoseTaken,
    Value<int>? rowid,
  }) {
    return DoseLogEventsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      doseId: doseId ?? this.doseId,
      occurredAt: occurredAt ?? this.occurredAt,
      marksDoseTaken: marksDoseTaken ?? this.marksDoseTaken,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (doseId.present) {
      map['dose_id'] = Variable<String>(doseId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (marksDoseTaken.present) {
      map['marks_dose_taken'] = Variable<bool>(marksDoseTaken.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DoseLogEventsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('doseId: $doseId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('marksDoseTaken: $marksDoseTaken, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ControllerCommandSessionsTable extends ControllerCommandSessions
    with
        TableInfo<
          $ControllerCommandSessionsTable,
          ControllerCommandSessionRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ControllerCommandSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandTypeMeta = const VerificationMeta(
    'commandType',
  );
  @override
  late final GeneratedColumn<String> commandType = GeneratedColumn<String>(
    'command_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doseIdMeta = const VerificationMeta('doseId');
  @override
  late final GeneratedColumn<String> doseId = GeneratedColumn<String>(
    'dose_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<String> slotId = GeneratedColumn<String>(
    'slot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acceptedAtMeta = const VerificationMeta(
    'acceptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> acceptedAt = GeneratedColumn<DateTime>(
    'accepted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    commandType,
    doseId,
    scheduleId,
    slotId,
    state,
    failureReason,
    createdAt,
    acceptedAt,
    resolvedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'controller_command_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ControllerCommandSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_type')) {
      context.handle(
        _commandTypeMeta,
        commandType.isAcceptableOrUnknown(
          data['command_type']!,
          _commandTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandTypeMeta);
    }
    if (data.containsKey('dose_id')) {
      context.handle(
        _doseIdMeta,
        doseId.isAcceptableOrUnknown(data['dose_id']!, _doseIdMeta),
      );
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    }
    if (data.containsKey('slot_id')) {
      context.handle(
        _slotIdMeta,
        slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('accepted_at')) {
      context.handle(
        _acceptedAtMeta,
        acceptedAt.isAcceptableOrUnknown(data['accepted_at']!, _acceptedAtMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ControllerCommandSessionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ControllerCommandSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_type'],
      )!,
      doseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dose_id'],
      ),
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      ),
      slotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      acceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accepted_at'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ControllerCommandSessionsTable createAlias(String alias) {
    return $ControllerCommandSessionsTable(attachedDatabase, alias);
  }
}

class ControllerCommandSessionRow extends DataClass
    implements Insertable<ControllerCommandSessionRow> {
  final String id;
  final String commandType;
  final String? doseId;
  final String? scheduleId;
  final String? slotId;
  final String state;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? resolvedAt;
  final DateTime updatedAt;
  const ControllerCommandSessionRow({
    required this.id,
    required this.commandType,
    this.doseId,
    this.scheduleId,
    this.slotId,
    required this.state,
    this.failureReason,
    required this.createdAt,
    this.acceptedAt,
    this.resolvedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['command_type'] = Variable<String>(commandType);
    if (!nullToAbsent || doseId != null) {
      map['dose_id'] = Variable<String>(doseId);
    }
    if (!nullToAbsent || scheduleId != null) {
      map['schedule_id'] = Variable<String>(scheduleId);
    }
    if (!nullToAbsent || slotId != null) {
      map['slot_id'] = Variable<String>(slotId);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || acceptedAt != null) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ControllerCommandSessionsCompanion toCompanion(bool nullToAbsent) {
    return ControllerCommandSessionsCompanion(
      id: Value(id),
      commandType: Value(commandType),
      doseId: doseId == null && nullToAbsent
          ? const Value.absent()
          : Value(doseId),
      scheduleId: scheduleId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduleId),
      slotId: slotId == null && nullToAbsent
          ? const Value.absent()
          : Value(slotId),
      state: Value(state),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
      createdAt: Value(createdAt),
      acceptedAt: acceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ControllerCommandSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ControllerCommandSessionRow(
      id: serializer.fromJson<String>(json['id']),
      commandType: serializer.fromJson<String>(json['commandType']),
      doseId: serializer.fromJson<String?>(json['doseId']),
      scheduleId: serializer.fromJson<String?>(json['scheduleId']),
      slotId: serializer.fromJson<String?>(json['slotId']),
      state: serializer.fromJson<String>(json['state']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      acceptedAt: serializer.fromJson<DateTime?>(json['acceptedAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'commandType': serializer.toJson<String>(commandType),
      'doseId': serializer.toJson<String?>(doseId),
      'scheduleId': serializer.toJson<String?>(scheduleId),
      'slotId': serializer.toJson<String?>(slotId),
      'state': serializer.toJson<String>(state),
      'failureReason': serializer.toJson<String?>(failureReason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'acceptedAt': serializer.toJson<DateTime?>(acceptedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ControllerCommandSessionRow copyWith({
    String? id,
    String? commandType,
    Value<String?> doseId = const Value.absent(),
    Value<String?> scheduleId = const Value.absent(),
    Value<String?> slotId = const Value.absent(),
    String? state,
    Value<String?> failureReason = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> acceptedAt = const Value.absent(),
    Value<DateTime?> resolvedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => ControllerCommandSessionRow(
    id: id ?? this.id,
    commandType: commandType ?? this.commandType,
    doseId: doseId.present ? doseId.value : this.doseId,
    scheduleId: scheduleId.present ? scheduleId.value : this.scheduleId,
    slotId: slotId.present ? slotId.value : this.slotId,
    state: state ?? this.state,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
    createdAt: createdAt ?? this.createdAt,
    acceptedAt: acceptedAt.present ? acceptedAt.value : this.acceptedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ControllerCommandSessionRow copyWithCompanion(
    ControllerCommandSessionsCompanion data,
  ) {
    return ControllerCommandSessionRow(
      id: data.id.present ? data.id.value : this.id,
      commandType: data.commandType.present
          ? data.commandType.value
          : this.commandType,
      doseId: data.doseId.present ? data.doseId.value : this.doseId,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
      state: data.state.present ? data.state.value : this.state,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      acceptedAt: data.acceptedAt.present
          ? data.acceptedAt.value
          : this.acceptedAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ControllerCommandSessionRow(')
          ..write('id: $id, ')
          ..write('commandType: $commandType, ')
          ..write('doseId: $doseId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('slotId: $slotId, ')
          ..write('state: $state, ')
          ..write('failureReason: $failureReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    commandType,
    doseId,
    scheduleId,
    slotId,
    state,
    failureReason,
    createdAt,
    acceptedAt,
    resolvedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ControllerCommandSessionRow &&
          other.id == this.id &&
          other.commandType == this.commandType &&
          other.doseId == this.doseId &&
          other.scheduleId == this.scheduleId &&
          other.slotId == this.slotId &&
          other.state == this.state &&
          other.failureReason == this.failureReason &&
          other.createdAt == this.createdAt &&
          other.acceptedAt == this.acceptedAt &&
          other.resolvedAt == this.resolvedAt &&
          other.updatedAt == this.updatedAt);
}

class ControllerCommandSessionsCompanion
    extends UpdateCompanion<ControllerCommandSessionRow> {
  final Value<String> id;
  final Value<String> commandType;
  final Value<String?> doseId;
  final Value<String?> scheduleId;
  final Value<String?> slotId;
  final Value<String> state;
  final Value<String?> failureReason;
  final Value<DateTime> createdAt;
  final Value<DateTime?> acceptedAt;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ControllerCommandSessionsCompanion({
    this.id = const Value.absent(),
    this.commandType = const Value.absent(),
    this.doseId = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.slotId = const Value.absent(),
    this.state = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ControllerCommandSessionsCompanion.insert({
    required String id,
    required String commandType,
    this.doseId = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.slotId = const Value.absent(),
    required String state,
    this.failureReason = const Value.absent(),
    required DateTime createdAt,
    this.acceptedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       commandType = Value(commandType),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ControllerCommandSessionRow> custom({
    Expression<String>? id,
    Expression<String>? commandType,
    Expression<String>? doseId,
    Expression<String>? scheduleId,
    Expression<String>? slotId,
    Expression<String>? state,
    Expression<String>? failureReason,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? acceptedAt,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (commandType != null) 'command_type': commandType,
      if (doseId != null) 'dose_id': doseId,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (slotId != null) 'slot_id': slotId,
      if (state != null) 'state': state,
      if (failureReason != null) 'failure_reason': failureReason,
      if (createdAt != null) 'created_at': createdAt,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ControllerCommandSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? commandType,
    Value<String?>? doseId,
    Value<String?>? scheduleId,
    Value<String?>? slotId,
    Value<String>? state,
    Value<String?>? failureReason,
    Value<DateTime>? createdAt,
    Value<DateTime?>? acceptedAt,
    Value<DateTime?>? resolvedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ControllerCommandSessionsCompanion(
      id: id ?? this.id,
      commandType: commandType ?? this.commandType,
      doseId: doseId ?? this.doseId,
      scheduleId: scheduleId ?? this.scheduleId,
      slotId: slotId ?? this.slotId,
      state: state ?? this.state,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (commandType.present) {
      map['command_type'] = Variable<String>(commandType.value);
    }
    if (doseId.present) {
      map['dose_id'] = Variable<String>(doseId.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<String>(slotId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ControllerCommandSessionsCompanion(')
          ..write('id: $id, ')
          ..write('commandType: $commandType, ')
          ..write('doseId: $doseId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('slotId: $slotId, ')
          ..write('state: $state, ')
          ..write('failureReason: $failureReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ControllerCommandEventsTable extends ControllerCommandEvents
    with TableInfo<$ControllerCommandEventsTable, ControllerCommandEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ControllerCommandEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    sequence,
    eventType,
    occurredAt,
    details,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'controller_command_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ControllerCommandEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ControllerCommandEventRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ControllerCommandEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
    );
  }

  @override
  $ControllerCommandEventsTable createAlias(String alias) {
    return $ControllerCommandEventsTable(attachedDatabase, alias);
  }
}

class ControllerCommandEventRow extends DataClass
    implements Insertable<ControllerCommandEventRow> {
  final String id;
  final String sessionId;
  final int sequence;
  final String eventType;
  final DateTime occurredAt;
  final String? details;
  const ControllerCommandEventRow({
    required this.id,
    required this.sessionId,
    required this.sequence,
    required this.eventType,
    required this.occurredAt,
    this.details,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['sequence'] = Variable<int>(sequence);
    map['event_type'] = Variable<String>(eventType);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    return map;
  }

  ControllerCommandEventsCompanion toCompanion(bool nullToAbsent) {
    return ControllerCommandEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      sequence: Value(sequence),
      eventType: Value(eventType),
      occurredAt: Value(occurredAt),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
    );
  }

  factory ControllerCommandEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ControllerCommandEventRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      eventType: serializer.fromJson<String>(json['eventType']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      details: serializer.fromJson<String?>(json['details']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'sequence': serializer.toJson<int>(sequence),
      'eventType': serializer.toJson<String>(eventType),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'details': serializer.toJson<String?>(details),
    };
  }

  ControllerCommandEventRow copyWith({
    String? id,
    String? sessionId,
    int? sequence,
    String? eventType,
    DateTime? occurredAt,
    Value<String?> details = const Value.absent(),
  }) => ControllerCommandEventRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    sequence: sequence ?? this.sequence,
    eventType: eventType ?? this.eventType,
    occurredAt: occurredAt ?? this.occurredAt,
    details: details.present ? details.value : this.details,
  );
  ControllerCommandEventRow copyWithCompanion(
    ControllerCommandEventsCompanion data,
  ) {
    return ControllerCommandEventRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      details: data.details.present ? data.details.value : this.details,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ControllerCommandEventRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, sequence, eventType, occurredAt, details);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ControllerCommandEventRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.sequence == this.sequence &&
          other.eventType == this.eventType &&
          other.occurredAt == this.occurredAt &&
          other.details == this.details);
}

class ControllerCommandEventsCompanion
    extends UpdateCompanion<ControllerCommandEventRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> sequence;
  final Value<String> eventType;
  final Value<DateTime> occurredAt;
  final Value<String?> details;
  final Value<int> rowid;
  const ControllerCommandEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.eventType = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.details = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ControllerCommandEventsCompanion.insert({
    required String id,
    required String sessionId,
    required int sequence,
    required String eventType,
    required DateTime occurredAt,
    this.details = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       sequence = Value(sequence),
       eventType = Value(eventType),
       occurredAt = Value(occurredAt);
  static Insertable<ControllerCommandEventRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? sequence,
    Expression<String>? eventType,
    Expression<DateTime>? occurredAt,
    Expression<String>? details,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (sequence != null) 'sequence': sequence,
      if (eventType != null) 'event_type': eventType,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (details != null) 'details': details,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ControllerCommandEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? sequence,
    Value<String>? eventType,
    Value<DateTime>? occurredAt,
    Value<String?>? details,
    Value<int>? rowid,
  }) {
    return ControllerCommandEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      sequence: sequence ?? this.sequence,
      eventType: eventType ?? this.eventType,
      occurredAt: occurredAt ?? this.occurredAt,
      details: details ?? this.details,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ControllerCommandEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('details: $details, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AdminAuditEventsTable extends AdminAuditEvents
    with TableInfo<$AdminAuditEventsTable, AdminAuditEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdminAuditEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta(
    'targetType',
  );
  @override
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorTypeMeta = const VerificationMeta(
    'actorType',
  );
  @override
  late final GeneratedColumn<String> actorType = GeneratedColumn<String>(
    'actor_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorLabelMeta = const VerificationMeta(
    'actorLabel',
  );
  @override
  late final GeneratedColumn<String> actorLabel = GeneratedColumn<String>(
    'actor_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDeviceRoleMeta = const VerificationMeta(
    'sourceDeviceRole',
  );
  @override
  late final GeneratedColumn<String> sourceDeviceRole = GeneratedColumn<String>(
    'source_device_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudEventIdMeta = const VerificationMeta(
    'cloudEventId',
  );
  @override
  late final GeneratedColumn<String> cloudEventId = GeneratedColumn<String>(
    'cloud_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventType,
    targetType,
    targetId,
    actorType,
    actorUserId,
    actorLabel,
    sourceDeviceRole,
    summary,
    detailsJson,
    cloudEventId,
    lastSyncedAt,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'admin_audit_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AdminAuditEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_targetTypeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('actor_type')) {
      context.handle(
        _actorTypeMeta,
        actorType.isAcceptableOrUnknown(data['actor_type']!, _actorTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actorTypeMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    }
    if (data.containsKey('actor_label')) {
      context.handle(
        _actorLabelMeta,
        actorLabel.isAcceptableOrUnknown(data['actor_label']!, _actorLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_actorLabelMeta);
    }
    if (data.containsKey('source_device_role')) {
      context.handle(
        _sourceDeviceRoleMeta,
        sourceDeviceRole.isAcceptableOrUnknown(
          data['source_device_role']!,
          _sourceDeviceRoleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDeviceRoleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    }
    if (data.containsKey('cloud_event_id')) {
      context.handle(
        _cloudEventIdMeta,
        cloudEventId.isAcceptableOrUnknown(
          data['cloud_event_id']!,
          _cloudEventIdMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AdminAuditEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AdminAuditEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      targetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_type'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      actorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_type'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      ),
      actorLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_label'],
      )!,
      sourceDeviceRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device_role'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      ),
      cloudEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_event_id'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $AdminAuditEventsTable createAlias(String alias) {
    return $AdminAuditEventsTable(attachedDatabase, alias);
  }
}

class AdminAuditEventRow extends DataClass
    implements Insertable<AdminAuditEventRow> {
  final String id;
  final String eventType;
  final String targetType;
  final String? targetId;
  final String actorType;
  final String? actorUserId;
  final String actorLabel;
  final String sourceDeviceRole;
  final String summary;
  final String? detailsJson;
  final String? cloudEventId;
  final DateTime? lastSyncedAt;
  final DateTime occurredAt;
  const AdminAuditEventRow({
    required this.id,
    required this.eventType,
    required this.targetType,
    this.targetId,
    required this.actorType,
    this.actorUserId,
    required this.actorLabel,
    required this.sourceDeviceRole,
    required this.summary,
    this.detailsJson,
    this.cloudEventId,
    this.lastSyncedAt,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_type'] = Variable<String>(eventType);
    map['target_type'] = Variable<String>(targetType);
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    map['actor_type'] = Variable<String>(actorType);
    if (!nullToAbsent || actorUserId != null) {
      map['actor_user_id'] = Variable<String>(actorUserId);
    }
    map['actor_label'] = Variable<String>(actorLabel);
    map['source_device_role'] = Variable<String>(sourceDeviceRole);
    map['summary'] = Variable<String>(summary);
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    if (!nullToAbsent || cloudEventId != null) {
      map['cloud_event_id'] = Variable<String>(cloudEventId);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  AdminAuditEventsCompanion toCompanion(bool nullToAbsent) {
    return AdminAuditEventsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      targetType: Value(targetType),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      actorType: Value(actorType),
      actorUserId: actorUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorUserId),
      actorLabel: Value(actorLabel),
      sourceDeviceRole: Value(sourceDeviceRole),
      summary: Value(summary),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      cloudEventId: cloudEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudEventId),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      occurredAt: Value(occurredAt),
    );
  }

  factory AdminAuditEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AdminAuditEventRow(
      id: serializer.fromJson<String>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      targetType: serializer.fromJson<String>(json['targetType']),
      targetId: serializer.fromJson<String?>(json['targetId']),
      actorType: serializer.fromJson<String>(json['actorType']),
      actorUserId: serializer.fromJson<String?>(json['actorUserId']),
      actorLabel: serializer.fromJson<String>(json['actorLabel']),
      sourceDeviceRole: serializer.fromJson<String>(json['sourceDeviceRole']),
      summary: serializer.fromJson<String>(json['summary']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      cloudEventId: serializer.fromJson<String?>(json['cloudEventId']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventType': serializer.toJson<String>(eventType),
      'targetType': serializer.toJson<String>(targetType),
      'targetId': serializer.toJson<String?>(targetId),
      'actorType': serializer.toJson<String>(actorType),
      'actorUserId': serializer.toJson<String?>(actorUserId),
      'actorLabel': serializer.toJson<String>(actorLabel),
      'sourceDeviceRole': serializer.toJson<String>(sourceDeviceRole),
      'summary': serializer.toJson<String>(summary),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'cloudEventId': serializer.toJson<String?>(cloudEventId),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  AdminAuditEventRow copyWith({
    String? id,
    String? eventType,
    String? targetType,
    Value<String?> targetId = const Value.absent(),
    String? actorType,
    Value<String?> actorUserId = const Value.absent(),
    String? actorLabel,
    String? sourceDeviceRole,
    String? summary,
    Value<String?> detailsJson = const Value.absent(),
    Value<String?> cloudEventId = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    DateTime? occurredAt,
  }) => AdminAuditEventRow(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    targetType: targetType ?? this.targetType,
    targetId: targetId.present ? targetId.value : this.targetId,
    actorType: actorType ?? this.actorType,
    actorUserId: actorUserId.present ? actorUserId.value : this.actorUserId,
    actorLabel: actorLabel ?? this.actorLabel,
    sourceDeviceRole: sourceDeviceRole ?? this.sourceDeviceRole,
    summary: summary ?? this.summary,
    detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
    cloudEventId: cloudEventId.present ? cloudEventId.value : this.cloudEventId,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  AdminAuditEventRow copyWithCompanion(AdminAuditEventsCompanion data) {
    return AdminAuditEventRow(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      targetType: data.targetType.present
          ? data.targetType.value
          : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      actorType: data.actorType.present ? data.actorType.value : this.actorType,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      actorLabel: data.actorLabel.present
          ? data.actorLabel.value
          : this.actorLabel,
      sourceDeviceRole: data.sourceDeviceRole.present
          ? data.sourceDeviceRole.value
          : this.sourceDeviceRole,
      summary: data.summary.present ? data.summary.value : this.summary,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
      cloudEventId: data.cloudEventId.present
          ? data.cloudEventId.value
          : this.cloudEventId,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AdminAuditEventRow(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('actorType: $actorType, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('actorLabel: $actorLabel, ')
          ..write('sourceDeviceRole: $sourceDeviceRole, ')
          ..write('summary: $summary, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('cloudEventId: $cloudEventId, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventType,
    targetType,
    targetId,
    actorType,
    actorUserId,
    actorLabel,
    sourceDeviceRole,
    summary,
    detailsJson,
    cloudEventId,
    lastSyncedAt,
    occurredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdminAuditEventRow &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.actorType == this.actorType &&
          other.actorUserId == this.actorUserId &&
          other.actorLabel == this.actorLabel &&
          other.sourceDeviceRole == this.sourceDeviceRole &&
          other.summary == this.summary &&
          other.detailsJson == this.detailsJson &&
          other.cloudEventId == this.cloudEventId &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.occurredAt == this.occurredAt);
}

class AdminAuditEventsCompanion extends UpdateCompanion<AdminAuditEventRow> {
  final Value<String> id;
  final Value<String> eventType;
  final Value<String> targetType;
  final Value<String?> targetId;
  final Value<String> actorType;
  final Value<String?> actorUserId;
  final Value<String> actorLabel;
  final Value<String> sourceDeviceRole;
  final Value<String> summary;
  final Value<String?> detailsJson;
  final Value<String?> cloudEventId;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime> occurredAt;
  final Value<int> rowid;
  const AdminAuditEventsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.actorType = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.actorLabel = const Value.absent(),
    this.sourceDeviceRole = const Value.absent(),
    this.summary = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.cloudEventId = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AdminAuditEventsCompanion.insert({
    required String id,
    required String eventType,
    required String targetType,
    this.targetId = const Value.absent(),
    required String actorType,
    this.actorUserId = const Value.absent(),
    required String actorLabel,
    required String sourceDeviceRole,
    required String summary,
    this.detailsJson = const Value.absent(),
    this.cloudEventId = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    required DateTime occurredAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventType = Value(eventType),
       targetType = Value(targetType),
       actorType = Value(actorType),
       actorLabel = Value(actorLabel),
       sourceDeviceRole = Value(sourceDeviceRole),
       summary = Value(summary),
       occurredAt = Value(occurredAt);
  static Insertable<AdminAuditEventRow> custom({
    Expression<String>? id,
    Expression<String>? eventType,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<String>? actorType,
    Expression<String>? actorUserId,
    Expression<String>? actorLabel,
    Expression<String>? sourceDeviceRole,
    Expression<String>? summary,
    Expression<String>? detailsJson,
    Expression<String>? cloudEventId,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? occurredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (actorType != null) 'actor_type': actorType,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (actorLabel != null) 'actor_label': actorLabel,
      if (sourceDeviceRole != null) 'source_device_role': sourceDeviceRole,
      if (summary != null) 'summary': summary,
      if (detailsJson != null) 'details_json': detailsJson,
      if (cloudEventId != null) 'cloud_event_id': cloudEventId,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AdminAuditEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventType,
    Value<String>? targetType,
    Value<String?>? targetId,
    Value<String>? actorType,
    Value<String?>? actorUserId,
    Value<String>? actorLabel,
    Value<String>? sourceDeviceRole,
    Value<String>? summary,
    Value<String?>? detailsJson,
    Value<String?>? cloudEventId,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime>? occurredAt,
    Value<int>? rowid,
  }) {
    return AdminAuditEventsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      actorType: actorType ?? this.actorType,
      actorUserId: actorUserId ?? this.actorUserId,
      actorLabel: actorLabel ?? this.actorLabel,
      sourceDeviceRole: sourceDeviceRole ?? this.sourceDeviceRole,
      summary: summary ?? this.summary,
      detailsJson: detailsJson ?? this.detailsJson,
      cloudEventId: cloudEventId ?? this.cloudEventId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      occurredAt: occurredAt ?? this.occurredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (actorType.present) {
      map['actor_type'] = Variable<String>(actorType.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (actorLabel.present) {
      map['actor_label'] = Variable<String>(actorLabel.value);
    }
    if (sourceDeviceRole.present) {
      map['source_device_role'] = Variable<String>(sourceDeviceRole.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (cloudEventId.present) {
      map['cloud_event_id'] = Variable<String>(cloudEventId.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdminAuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('actorType: $actorType, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('actorLabel: $actorLabel, ')
          ..write('sourceDeviceRole: $sourceDeviceRole, ')
          ..write('summary: $summary, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('cloudEventId: $cloudEventId, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DoseyDatabase extends GeneratedDatabase {
  _$DoseyDatabase(QueryExecutor e) : super(e);
  $DoseyDatabaseManager get managers => $DoseyDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ReminderSchedulesTable reminderSchedules =
      $ReminderSchedulesTable(this);
  late final $PrescriptionsTable prescriptions = $PrescriptionsTable(this);
  late final $PrescriptionRefillsTable prescriptionRefills =
      $PrescriptionRefillsTable(this);
  late final $ScheduleProfilesTable scheduleProfiles = $ScheduleProfilesTable(
    this,
  );
  late final $CarouselSlotsTable carouselSlots = $CarouselSlotsTable(this);
  late final $AuthSessionsTable authSessions = $AuthSessionsTable(this);
  late final $DoseLogEventsTable doseLogEvents = $DoseLogEventsTable(this);
  late final $ControllerCommandSessionsTable controllerCommandSessions =
      $ControllerCommandSessionsTable(this);
  late final $ControllerCommandEventsTable controllerCommandEvents =
      $ControllerCommandEventsTable(this);
  late final $AdminAuditEventsTable adminAuditEvents = $AdminAuditEventsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    reminderSchedules,
    prescriptions,
    prescriptionRefills,
    scheduleProfiles,
    carouselSlots,
    authSessions,
    doseLogEvents,
    controllerCommandSessions,
    controllerCommandEvents,
    adminAuditEvents,
  ];
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$DoseyDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$DoseyDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$DoseyDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$DoseyDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$ReminderSchedulesTableCreateCompanionBuilder =
    ReminderSchedulesCompanion Function({
      required String id,
      required String label,
      Value<String?> prescriptionId,
      Value<String> profileId,
      required int hour,
      required int minute,
      required bool isEnabled,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReminderSchedulesTableUpdateCompanionBuilder =
    ReminderSchedulesCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<String?> prescriptionId,
      Value<String> profileId,
      Value<int> hour,
      Value<int> minute,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReminderSchedulesTableFilterComposer
    extends Composer<_$DoseyDatabase, $ReminderSchedulesTable> {
  $$ReminderSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderSchedulesTableOrderingComposer
    extends Composer<_$DoseyDatabase, $ReminderSchedulesTable> {
  $$ReminderSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderSchedulesTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $ReminderSchedulesTable> {
  $$ReminderSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReminderSchedulesTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $ReminderSchedulesTable,
          ReminderScheduleRow,
          $$ReminderSchedulesTableFilterComposer,
          $$ReminderSchedulesTableOrderingComposer,
          $$ReminderSchedulesTableAnnotationComposer,
          $$ReminderSchedulesTableCreateCompanionBuilder,
          $$ReminderSchedulesTableUpdateCompanionBuilder,
          (
            ReminderScheduleRow,
            BaseReferences<
              _$DoseyDatabase,
              $ReminderSchedulesTable,
              ReminderScheduleRow
            >,
          ),
          ReminderScheduleRow,
          PrefetchHooks Function()
        > {
  $$ReminderSchedulesTableTableManager(
    _$DoseyDatabase db,
    $ReminderSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderSchedulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> prescriptionId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderSchedulesCompanion(
                id: id,
                label: label,
                prescriptionId: prescriptionId,
                profileId: profileId,
                hour: hour,
                minute: minute,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                Value<String?> prescriptionId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                required int hour,
                required int minute,
                required bool isEnabled,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReminderSchedulesCompanion.insert(
                id: id,
                label: label,
                prescriptionId: prescriptionId,
                profileId: profileId,
                hour: hour,
                minute: minute,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $ReminderSchedulesTable,
      ReminderScheduleRow,
      $$ReminderSchedulesTableFilterComposer,
      $$ReminderSchedulesTableOrderingComposer,
      $$ReminderSchedulesTableAnnotationComposer,
      $$ReminderSchedulesTableCreateCompanionBuilder,
      $$ReminderSchedulesTableUpdateCompanionBuilder,
      (
        ReminderScheduleRow,
        BaseReferences<
          _$DoseyDatabase,
          $ReminderSchedulesTable,
          ReminderScheduleRow
        >,
      ),
      ReminderScheduleRow,
      PrefetchHooks Function()
    >;
typedef $$PrescriptionsTableCreateCompanionBuilder =
    PrescriptionsCompanion Function({
      required String id,
      required String name,
      required String pillType,
      Value<int> remainingDoses,
      Value<int> refillThreshold,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PrescriptionsTableUpdateCompanionBuilder =
    PrescriptionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> pillType,
      Value<int> remainingDoses,
      Value<int> refillThreshold,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PrescriptionsTableFilterComposer
    extends Composer<_$DoseyDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pillType => $composableBuilder(
    column: $table.pillType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remainingDoses => $composableBuilder(
    column: $table.remainingDoses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refillThreshold => $composableBuilder(
    column: $table.refillThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrescriptionsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pillType => $composableBuilder(
    column: $table.pillType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remainingDoses => $composableBuilder(
    column: $table.remainingDoses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refillThreshold => $composableBuilder(
    column: $table.refillThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrescriptionsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get pillType =>
      $composableBuilder(column: $table.pillType, builder: (column) => column);

  GeneratedColumn<int> get remainingDoses => $composableBuilder(
    column: $table.remainingDoses,
    builder: (column) => column,
  );

  GeneratedColumn<int> get refillThreshold => $composableBuilder(
    column: $table.refillThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PrescriptionsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $PrescriptionsTable,
          PrescriptionRow,
          $$PrescriptionsTableFilterComposer,
          $$PrescriptionsTableOrderingComposer,
          $$PrescriptionsTableAnnotationComposer,
          $$PrescriptionsTableCreateCompanionBuilder,
          $$PrescriptionsTableUpdateCompanionBuilder,
          (
            PrescriptionRow,
            BaseReferences<
              _$DoseyDatabase,
              $PrescriptionsTable,
              PrescriptionRow
            >,
          ),
          PrescriptionRow,
          PrefetchHooks Function()
        > {
  $$PrescriptionsTableTableManager(
    _$DoseyDatabase db,
    $PrescriptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrescriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrescriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrescriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> pillType = const Value.absent(),
                Value<int> remainingDoses = const Value.absent(),
                Value<int> refillThreshold = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrescriptionsCompanion(
                id: id,
                name: name,
                pillType: pillType,
                remainingDoses: remainingDoses,
                refillThreshold: refillThreshold,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String pillType,
                Value<int> remainingDoses = const Value.absent(),
                Value<int> refillThreshold = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PrescriptionsCompanion.insert(
                id: id,
                name: name,
                pillType: pillType,
                remainingDoses: remainingDoses,
                refillThreshold: refillThreshold,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrescriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $PrescriptionsTable,
      PrescriptionRow,
      $$PrescriptionsTableFilterComposer,
      $$PrescriptionsTableOrderingComposer,
      $$PrescriptionsTableAnnotationComposer,
      $$PrescriptionsTableCreateCompanionBuilder,
      $$PrescriptionsTableUpdateCompanionBuilder,
      (
        PrescriptionRow,
        BaseReferences<_$DoseyDatabase, $PrescriptionsTable, PrescriptionRow>,
      ),
      PrescriptionRow,
      PrefetchHooks Function()
    >;
typedef $$PrescriptionRefillsTableCreateCompanionBuilder =
    PrescriptionRefillsCompanion Function({
      required String id,
      required String prescriptionId,
      required int doseDelta,
      required int remainingAfter,
      required DateTime occurredAt,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$PrescriptionRefillsTableUpdateCompanionBuilder =
    PrescriptionRefillsCompanion Function({
      Value<String> id,
      Value<String> prescriptionId,
      Value<int> doseDelta,
      Value<int> remainingAfter,
      Value<DateTime> occurredAt,
      Value<String?> note,
      Value<int> rowid,
    });

class $$PrescriptionRefillsTableFilterComposer
    extends Composer<_$DoseyDatabase, $PrescriptionRefillsTable> {
  $$PrescriptionRefillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doseDelta => $composableBuilder(
    column: $table.doseDelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remainingAfter => $composableBuilder(
    column: $table.remainingAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrescriptionRefillsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $PrescriptionRefillsTable> {
  $$PrescriptionRefillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doseDelta => $composableBuilder(
    column: $table.doseDelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remainingAfter => $composableBuilder(
    column: $table.remainingAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrescriptionRefillsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $PrescriptionRefillsTable> {
  $$PrescriptionRefillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get doseDelta =>
      $composableBuilder(column: $table.doseDelta, builder: (column) => column);

  GeneratedColumn<int> get remainingAfter => $composableBuilder(
    column: $table.remainingAfter,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$PrescriptionRefillsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $PrescriptionRefillsTable,
          PrescriptionRefillRow,
          $$PrescriptionRefillsTableFilterComposer,
          $$PrescriptionRefillsTableOrderingComposer,
          $$PrescriptionRefillsTableAnnotationComposer,
          $$PrescriptionRefillsTableCreateCompanionBuilder,
          $$PrescriptionRefillsTableUpdateCompanionBuilder,
          (
            PrescriptionRefillRow,
            BaseReferences<
              _$DoseyDatabase,
              $PrescriptionRefillsTable,
              PrescriptionRefillRow
            >,
          ),
          PrescriptionRefillRow,
          PrefetchHooks Function()
        > {
  $$PrescriptionRefillsTableTableManager(
    _$DoseyDatabase db,
    $PrescriptionRefillsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrescriptionRefillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrescriptionRefillsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PrescriptionRefillsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> prescriptionId = const Value.absent(),
                Value<int> doseDelta = const Value.absent(),
                Value<int> remainingAfter = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrescriptionRefillsCompanion(
                id: id,
                prescriptionId: prescriptionId,
                doseDelta: doseDelta,
                remainingAfter: remainingAfter,
                occurredAt: occurredAt,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String prescriptionId,
                required int doseDelta,
                required int remainingAfter,
                required DateTime occurredAt,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrescriptionRefillsCompanion.insert(
                id: id,
                prescriptionId: prescriptionId,
                doseDelta: doseDelta,
                remainingAfter: remainingAfter,
                occurredAt: occurredAt,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrescriptionRefillsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $PrescriptionRefillsTable,
      PrescriptionRefillRow,
      $$PrescriptionRefillsTableFilterComposer,
      $$PrescriptionRefillsTableOrderingComposer,
      $$PrescriptionRefillsTableAnnotationComposer,
      $$PrescriptionRefillsTableCreateCompanionBuilder,
      $$PrescriptionRefillsTableUpdateCompanionBuilder,
      (
        PrescriptionRefillRow,
        BaseReferences<
          _$DoseyDatabase,
          $PrescriptionRefillsTable,
          PrescriptionRefillRow
        >,
      ),
      PrescriptionRefillRow,
      PrefetchHooks Function()
    >;
typedef $$ScheduleProfilesTableCreateCompanionBuilder =
    ScheduleProfilesCompanion Function({
      required String id,
      required String name,
      required bool isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ScheduleProfilesTableUpdateCompanionBuilder =
    ScheduleProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ScheduleProfilesTableFilterComposer
    extends Composer<_$DoseyDatabase, $ScheduleProfilesTable> {
  $$ScheduleProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduleProfilesTableOrderingComposer
    extends Composer<_$DoseyDatabase, $ScheduleProfilesTable> {
  $$ScheduleProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduleProfilesTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $ScheduleProfilesTable> {
  $$ScheduleProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScheduleProfilesTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $ScheduleProfilesTable,
          ScheduleProfileRow,
          $$ScheduleProfilesTableFilterComposer,
          $$ScheduleProfilesTableOrderingComposer,
          $$ScheduleProfilesTableAnnotationComposer,
          $$ScheduleProfilesTableCreateCompanionBuilder,
          $$ScheduleProfilesTableUpdateCompanionBuilder,
          (
            ScheduleProfileRow,
            BaseReferences<
              _$DoseyDatabase,
              $ScheduleProfilesTable,
              ScheduleProfileRow
            >,
          ),
          ScheduleProfileRow,
          PrefetchHooks Function()
        > {
  $$ScheduleProfilesTableTableManager(
    _$DoseyDatabase db,
    $ScheduleProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleProfilesCompanion(
                id: id,
                name: name,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required bool isActive,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ScheduleProfilesCompanion.insert(
                id: id,
                name: name,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduleProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $ScheduleProfilesTable,
      ScheduleProfileRow,
      $$ScheduleProfilesTableFilterComposer,
      $$ScheduleProfilesTableOrderingComposer,
      $$ScheduleProfilesTableAnnotationComposer,
      $$ScheduleProfilesTableCreateCompanionBuilder,
      $$ScheduleProfilesTableUpdateCompanionBuilder,
      (
        ScheduleProfileRow,
        BaseReferences<
          _$DoseyDatabase,
          $ScheduleProfilesTable,
          ScheduleProfileRow
        >,
      ),
      ScheduleProfileRow,
      PrefetchHooks Function()
    >;
typedef $$CarouselSlotsTableCreateCompanionBuilder =
    CarouselSlotsCompanion Function({
      required String id,
      required int slotNumber,
      required String prescriptionId,
      required String scheduleId,
      required String profileId,
      required String status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CarouselSlotsTableUpdateCompanionBuilder =
    CarouselSlotsCompanion Function({
      Value<String> id,
      Value<int> slotNumber,
      Value<String> prescriptionId,
      Value<String> scheduleId,
      Value<String> profileId,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CarouselSlotsTableFilterComposer
    extends Composer<_$DoseyDatabase, $CarouselSlotsTable> {
  $$CarouselSlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slotNumber => $composableBuilder(
    column: $table.slotNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CarouselSlotsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $CarouselSlotsTable> {
  $$CarouselSlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slotNumber => $composableBuilder(
    column: $table.slotNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CarouselSlotsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $CarouselSlotsTable> {
  $$CarouselSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get slotNumber => $composableBuilder(
    column: $table.slotNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CarouselSlotsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $CarouselSlotsTable,
          CarouselSlotRow,
          $$CarouselSlotsTableFilterComposer,
          $$CarouselSlotsTableOrderingComposer,
          $$CarouselSlotsTableAnnotationComposer,
          $$CarouselSlotsTableCreateCompanionBuilder,
          $$CarouselSlotsTableUpdateCompanionBuilder,
          (
            CarouselSlotRow,
            BaseReferences<
              _$DoseyDatabase,
              $CarouselSlotsTable,
              CarouselSlotRow
            >,
          ),
          CarouselSlotRow,
          PrefetchHooks Function()
        > {
  $$CarouselSlotsTableTableManager(
    _$DoseyDatabase db,
    $CarouselSlotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarouselSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CarouselSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CarouselSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> slotNumber = const Value.absent(),
                Value<String> prescriptionId = const Value.absent(),
                Value<String> scheduleId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarouselSlotsCompanion(
                id: id,
                slotNumber: slotNumber,
                prescriptionId: prescriptionId,
                scheduleId: scheduleId,
                profileId: profileId,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int slotNumber,
                required String prescriptionId,
                required String scheduleId,
                required String profileId,
                required String status,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CarouselSlotsCompanion.insert(
                id: id,
                slotNumber: slotNumber,
                prescriptionId: prescriptionId,
                scheduleId: scheduleId,
                profileId: profileId,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CarouselSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $CarouselSlotsTable,
      CarouselSlotRow,
      $$CarouselSlotsTableFilterComposer,
      $$CarouselSlotsTableOrderingComposer,
      $$CarouselSlotsTableAnnotationComposer,
      $$CarouselSlotsTableCreateCompanionBuilder,
      $$CarouselSlotsTableUpdateCompanionBuilder,
      (
        CarouselSlotRow,
        BaseReferences<_$DoseyDatabase, $CarouselSlotsTable, CarouselSlotRow>,
      ),
      CarouselSlotRow,
      PrefetchHooks Function()
    >;
typedef $$AuthSessionsTableCreateCompanionBuilder =
    AuthSessionsCompanion Function({
      required String id,
      required String userId,
      required String email,
      Value<String?> displayName,
      Value<String?> photoUrl,
      required String provider,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AuthSessionsTableUpdateCompanionBuilder =
    AuthSessionsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> email,
      Value<String?> displayName,
      Value<String?> photoUrl,
      Value<String> provider,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AuthSessionsTableFilterComposer
    extends Composer<_$DoseyDatabase, $AuthSessionsTable> {
  $$AuthSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuthSessionsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $AuthSessionsTable> {
  $$AuthSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuthSessionsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $AuthSessionsTable> {
  $$AuthSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AuthSessionsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $AuthSessionsTable,
          AuthSessionRow,
          $$AuthSessionsTableFilterComposer,
          $$AuthSessionsTableOrderingComposer,
          $$AuthSessionsTableAnnotationComposer,
          $$AuthSessionsTableCreateCompanionBuilder,
          $$AuthSessionsTableUpdateCompanionBuilder,
          (
            AuthSessionRow,
            BaseReferences<_$DoseyDatabase, $AuthSessionsTable, AuthSessionRow>,
          ),
          AuthSessionRow,
          PrefetchHooks Function()
        > {
  $$AuthSessionsTableTableManager(_$DoseyDatabase db, $AuthSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuthSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuthSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuthSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuthSessionsCompanion(
                id: id,
                userId: userId,
                email: email,
                displayName: displayName,
                photoUrl: photoUrl,
                provider: provider,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String email,
                Value<String?> displayName = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                required String provider,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AuthSessionsCompanion.insert(
                id: id,
                userId: userId,
                email: email,
                displayName: displayName,
                photoUrl: photoUrl,
                provider: provider,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuthSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $AuthSessionsTable,
      AuthSessionRow,
      $$AuthSessionsTableFilterComposer,
      $$AuthSessionsTableOrderingComposer,
      $$AuthSessionsTableAnnotationComposer,
      $$AuthSessionsTableCreateCompanionBuilder,
      $$AuthSessionsTableUpdateCompanionBuilder,
      (
        AuthSessionRow,
        BaseReferences<_$DoseyDatabase, $AuthSessionsTable, AuthSessionRow>,
      ),
      AuthSessionRow,
      PrefetchHooks Function()
    >;
typedef $$DoseLogEventsTableCreateCompanionBuilder =
    DoseLogEventsCompanion Function({
      required String id,
      required String kind,
      required String doseId,
      required DateTime occurredAt,
      required bool marksDoseTaken,
      Value<int> rowid,
    });
typedef $$DoseLogEventsTableUpdateCompanionBuilder =
    DoseLogEventsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> doseId,
      Value<DateTime> occurredAt,
      Value<bool> marksDoseTaken,
      Value<int> rowid,
    });

class $$DoseLogEventsTableFilterComposer
    extends Composer<_$DoseyDatabase, $DoseLogEventsTable> {
  $$DoseLogEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doseId => $composableBuilder(
    column: $table.doseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get marksDoseTaken => $composableBuilder(
    column: $table.marksDoseTaken,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DoseLogEventsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $DoseLogEventsTable> {
  $$DoseLogEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doseId => $composableBuilder(
    column: $table.doseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get marksDoseTaken => $composableBuilder(
    column: $table.marksDoseTaken,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DoseLogEventsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $DoseLogEventsTable> {
  $$DoseLogEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get doseId =>
      $composableBuilder(column: $table.doseId, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get marksDoseTaken => $composableBuilder(
    column: $table.marksDoseTaken,
    builder: (column) => column,
  );
}

class $$DoseLogEventsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $DoseLogEventsTable,
          DoseLogEventRow,
          $$DoseLogEventsTableFilterComposer,
          $$DoseLogEventsTableOrderingComposer,
          $$DoseLogEventsTableAnnotationComposer,
          $$DoseLogEventsTableCreateCompanionBuilder,
          $$DoseLogEventsTableUpdateCompanionBuilder,
          (
            DoseLogEventRow,
            BaseReferences<
              _$DoseyDatabase,
              $DoseLogEventsTable,
              DoseLogEventRow
            >,
          ),
          DoseLogEventRow,
          PrefetchHooks Function()
        > {
  $$DoseLogEventsTableTableManager(
    _$DoseyDatabase db,
    $DoseLogEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DoseLogEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DoseLogEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DoseLogEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> doseId = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<bool> marksDoseTaken = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DoseLogEventsCompanion(
                id: id,
                kind: kind,
                doseId: doseId,
                occurredAt: occurredAt,
                marksDoseTaken: marksDoseTaken,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String doseId,
                required DateTime occurredAt,
                required bool marksDoseTaken,
                Value<int> rowid = const Value.absent(),
              }) => DoseLogEventsCompanion.insert(
                id: id,
                kind: kind,
                doseId: doseId,
                occurredAt: occurredAt,
                marksDoseTaken: marksDoseTaken,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DoseLogEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $DoseLogEventsTable,
      DoseLogEventRow,
      $$DoseLogEventsTableFilterComposer,
      $$DoseLogEventsTableOrderingComposer,
      $$DoseLogEventsTableAnnotationComposer,
      $$DoseLogEventsTableCreateCompanionBuilder,
      $$DoseLogEventsTableUpdateCompanionBuilder,
      (
        DoseLogEventRow,
        BaseReferences<_$DoseyDatabase, $DoseLogEventsTable, DoseLogEventRow>,
      ),
      DoseLogEventRow,
      PrefetchHooks Function()
    >;
typedef $$ControllerCommandSessionsTableCreateCompanionBuilder =
    ControllerCommandSessionsCompanion Function({
      required String id,
      required String commandType,
      Value<String?> doseId,
      Value<String?> scheduleId,
      Value<String?> slotId,
      required String state,
      Value<String?> failureReason,
      required DateTime createdAt,
      Value<DateTime?> acceptedAt,
      Value<DateTime?> resolvedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ControllerCommandSessionsTableUpdateCompanionBuilder =
    ControllerCommandSessionsCompanion Function({
      Value<String> id,
      Value<String> commandType,
      Value<String?> doseId,
      Value<String?> scheduleId,
      Value<String?> slotId,
      Value<String> state,
      Value<String?> failureReason,
      Value<DateTime> createdAt,
      Value<DateTime?> acceptedAt,
      Value<DateTime?> resolvedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ControllerCommandSessionsTableFilterComposer
    extends Composer<_$DoseyDatabase, $ControllerCommandSessionsTable> {
  $$ControllerCommandSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doseId => $composableBuilder(
    column: $table.doseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slotId => $composableBuilder(
    column: $table.slotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ControllerCommandSessionsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $ControllerCommandSessionsTable> {
  $$ControllerCommandSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doseId => $composableBuilder(
    column: $table.doseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slotId => $composableBuilder(
    column: $table.slotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ControllerCommandSessionsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $ControllerCommandSessionsTable> {
  $$ControllerCommandSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get doseId =>
      $composableBuilder(column: $table.doseId, builder: (column) => column);

  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slotId =>
      $composableBuilder(column: $table.slotId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ControllerCommandSessionsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $ControllerCommandSessionsTable,
          ControllerCommandSessionRow,
          $$ControllerCommandSessionsTableFilterComposer,
          $$ControllerCommandSessionsTableOrderingComposer,
          $$ControllerCommandSessionsTableAnnotationComposer,
          $$ControllerCommandSessionsTableCreateCompanionBuilder,
          $$ControllerCommandSessionsTableUpdateCompanionBuilder,
          (
            ControllerCommandSessionRow,
            BaseReferences<
              _$DoseyDatabase,
              $ControllerCommandSessionsTable,
              ControllerCommandSessionRow
            >,
          ),
          ControllerCommandSessionRow,
          PrefetchHooks Function()
        > {
  $$ControllerCommandSessionsTableTableManager(
    _$DoseyDatabase db,
    $ControllerCommandSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ControllerCommandSessionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ControllerCommandSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ControllerCommandSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> commandType = const Value.absent(),
                Value<String?> doseId = const Value.absent(),
                Value<String?> scheduleId = const Value.absent(),
                Value<String?> slotId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> acceptedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ControllerCommandSessionsCompanion(
                id: id,
                commandType: commandType,
                doseId: doseId,
                scheduleId: scheduleId,
                slotId: slotId,
                state: state,
                failureReason: failureReason,
                createdAt: createdAt,
                acceptedAt: acceptedAt,
                resolvedAt: resolvedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String commandType,
                Value<String?> doseId = const Value.absent(),
                Value<String?> scheduleId = const Value.absent(),
                Value<String?> slotId = const Value.absent(),
                required String state,
                Value<String?> failureReason = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> acceptedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ControllerCommandSessionsCompanion.insert(
                id: id,
                commandType: commandType,
                doseId: doseId,
                scheduleId: scheduleId,
                slotId: slotId,
                state: state,
                failureReason: failureReason,
                createdAt: createdAt,
                acceptedAt: acceptedAt,
                resolvedAt: resolvedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ControllerCommandSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $ControllerCommandSessionsTable,
      ControllerCommandSessionRow,
      $$ControllerCommandSessionsTableFilterComposer,
      $$ControllerCommandSessionsTableOrderingComposer,
      $$ControllerCommandSessionsTableAnnotationComposer,
      $$ControllerCommandSessionsTableCreateCompanionBuilder,
      $$ControllerCommandSessionsTableUpdateCompanionBuilder,
      (
        ControllerCommandSessionRow,
        BaseReferences<
          _$DoseyDatabase,
          $ControllerCommandSessionsTable,
          ControllerCommandSessionRow
        >,
      ),
      ControllerCommandSessionRow,
      PrefetchHooks Function()
    >;
typedef $$ControllerCommandEventsTableCreateCompanionBuilder =
    ControllerCommandEventsCompanion Function({
      required String id,
      required String sessionId,
      required int sequence,
      required String eventType,
      required DateTime occurredAt,
      Value<String?> details,
      Value<int> rowid,
    });
typedef $$ControllerCommandEventsTableUpdateCompanionBuilder =
    ControllerCommandEventsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> sequence,
      Value<String> eventType,
      Value<DateTime> occurredAt,
      Value<String?> details,
      Value<int> rowid,
    });

class $$ControllerCommandEventsTableFilterComposer
    extends Composer<_$DoseyDatabase, $ControllerCommandEventsTable> {
  $$ControllerCommandEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ControllerCommandEventsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $ControllerCommandEventsTable> {
  $$ControllerCommandEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ControllerCommandEventsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $ControllerCommandEventsTable> {
  $$ControllerCommandEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);
}

class $$ControllerCommandEventsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $ControllerCommandEventsTable,
          ControllerCommandEventRow,
          $$ControllerCommandEventsTableFilterComposer,
          $$ControllerCommandEventsTableOrderingComposer,
          $$ControllerCommandEventsTableAnnotationComposer,
          $$ControllerCommandEventsTableCreateCompanionBuilder,
          $$ControllerCommandEventsTableUpdateCompanionBuilder,
          (
            ControllerCommandEventRow,
            BaseReferences<
              _$DoseyDatabase,
              $ControllerCommandEventsTable,
              ControllerCommandEventRow
            >,
          ),
          ControllerCommandEventRow,
          PrefetchHooks Function()
        > {
  $$ControllerCommandEventsTableTableManager(
    _$DoseyDatabase db,
    $ControllerCommandEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ControllerCommandEventsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ControllerCommandEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ControllerCommandEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ControllerCommandEventsCompanion(
                id: id,
                sessionId: sessionId,
                sequence: sequence,
                eventType: eventType,
                occurredAt: occurredAt,
                details: details,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int sequence,
                required String eventType,
                required DateTime occurredAt,
                Value<String?> details = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ControllerCommandEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                sequence: sequence,
                eventType: eventType,
                occurredAt: occurredAt,
                details: details,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ControllerCommandEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $ControllerCommandEventsTable,
      ControllerCommandEventRow,
      $$ControllerCommandEventsTableFilterComposer,
      $$ControllerCommandEventsTableOrderingComposer,
      $$ControllerCommandEventsTableAnnotationComposer,
      $$ControllerCommandEventsTableCreateCompanionBuilder,
      $$ControllerCommandEventsTableUpdateCompanionBuilder,
      (
        ControllerCommandEventRow,
        BaseReferences<
          _$DoseyDatabase,
          $ControllerCommandEventsTable,
          ControllerCommandEventRow
        >,
      ),
      ControllerCommandEventRow,
      PrefetchHooks Function()
    >;
typedef $$AdminAuditEventsTableCreateCompanionBuilder =
    AdminAuditEventsCompanion Function({
      required String id,
      required String eventType,
      required String targetType,
      Value<String?> targetId,
      required String actorType,
      Value<String?> actorUserId,
      required String actorLabel,
      required String sourceDeviceRole,
      required String summary,
      Value<String?> detailsJson,
      Value<String?> cloudEventId,
      Value<DateTime?> lastSyncedAt,
      required DateTime occurredAt,
      Value<int> rowid,
    });
typedef $$AdminAuditEventsTableUpdateCompanionBuilder =
    AdminAuditEventsCompanion Function({
      Value<String> id,
      Value<String> eventType,
      Value<String> targetType,
      Value<String?> targetId,
      Value<String> actorType,
      Value<String?> actorUserId,
      Value<String> actorLabel,
      Value<String> sourceDeviceRole,
      Value<String> summary,
      Value<String?> detailsJson,
      Value<String?> cloudEventId,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime> occurredAt,
      Value<int> rowid,
    });

class $$AdminAuditEventsTableFilterComposer
    extends Composer<_$DoseyDatabase, $AdminAuditEventsTable> {
  $$AdminAuditEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorType => $composableBuilder(
    column: $table.actorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorLabel => $composableBuilder(
    column: $table.actorLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDeviceRole => $composableBuilder(
    column: $table.sourceDeviceRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudEventId => $composableBuilder(
    column: $table.cloudEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AdminAuditEventsTableOrderingComposer
    extends Composer<_$DoseyDatabase, $AdminAuditEventsTable> {
  $$AdminAuditEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorType => $composableBuilder(
    column: $table.actorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorLabel => $composableBuilder(
    column: $table.actorLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDeviceRole => $composableBuilder(
    column: $table.sourceDeviceRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudEventId => $composableBuilder(
    column: $table.cloudEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AdminAuditEventsTableAnnotationComposer
    extends Composer<_$DoseyDatabase, $AdminAuditEventsTable> {
  $$AdminAuditEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get actorType =>
      $composableBuilder(column: $table.actorType, builder: (column) => column);

  GeneratedColumn<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorLabel => $composableBuilder(
    column: $table.actorLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDeviceRole => $composableBuilder(
    column: $table.sourceDeviceRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudEventId => $composableBuilder(
    column: $table.cloudEventId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );
}

class $$AdminAuditEventsTableTableManager
    extends
        RootTableManager<
          _$DoseyDatabase,
          $AdminAuditEventsTable,
          AdminAuditEventRow,
          $$AdminAuditEventsTableFilterComposer,
          $$AdminAuditEventsTableOrderingComposer,
          $$AdminAuditEventsTableAnnotationComposer,
          $$AdminAuditEventsTableCreateCompanionBuilder,
          $$AdminAuditEventsTableUpdateCompanionBuilder,
          (
            AdminAuditEventRow,
            BaseReferences<
              _$DoseyDatabase,
              $AdminAuditEventsTable,
              AdminAuditEventRow
            >,
          ),
          AdminAuditEventRow,
          PrefetchHooks Function()
        > {
  $$AdminAuditEventsTableTableManager(
    _$DoseyDatabase db,
    $AdminAuditEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdminAuditEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdminAuditEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdminAuditEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> targetType = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String> actorType = const Value.absent(),
                Value<String?> actorUserId = const Value.absent(),
                Value<String> actorLabel = const Value.absent(),
                Value<String> sourceDeviceRole = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<String?> cloudEventId = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdminAuditEventsCompanion(
                id: id,
                eventType: eventType,
                targetType: targetType,
                targetId: targetId,
                actorType: actorType,
                actorUserId: actorUserId,
                actorLabel: actorLabel,
                sourceDeviceRole: sourceDeviceRole,
                summary: summary,
                detailsJson: detailsJson,
                cloudEventId: cloudEventId,
                lastSyncedAt: lastSyncedAt,
                occurredAt: occurredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventType,
                required String targetType,
                Value<String?> targetId = const Value.absent(),
                required String actorType,
                Value<String?> actorUserId = const Value.absent(),
                required String actorLabel,
                required String sourceDeviceRole,
                required String summary,
                Value<String?> detailsJson = const Value.absent(),
                Value<String?> cloudEventId = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                required DateTime occurredAt,
                Value<int> rowid = const Value.absent(),
              }) => AdminAuditEventsCompanion.insert(
                id: id,
                eventType: eventType,
                targetType: targetType,
                targetId: targetId,
                actorType: actorType,
                actorUserId: actorUserId,
                actorLabel: actorLabel,
                sourceDeviceRole: sourceDeviceRole,
                summary: summary,
                detailsJson: detailsJson,
                cloudEventId: cloudEventId,
                lastSyncedAt: lastSyncedAt,
                occurredAt: occurredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AdminAuditEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$DoseyDatabase,
      $AdminAuditEventsTable,
      AdminAuditEventRow,
      $$AdminAuditEventsTableFilterComposer,
      $$AdminAuditEventsTableOrderingComposer,
      $$AdminAuditEventsTableAnnotationComposer,
      $$AdminAuditEventsTableCreateCompanionBuilder,
      $$AdminAuditEventsTableUpdateCompanionBuilder,
      (
        AdminAuditEventRow,
        BaseReferences<
          _$DoseyDatabase,
          $AdminAuditEventsTable,
          AdminAuditEventRow
        >,
      ),
      AdminAuditEventRow,
      PrefetchHooks Function()
    >;

class $DoseyDatabaseManager {
  final _$DoseyDatabase _db;
  $DoseyDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ReminderSchedulesTableTableManager get reminderSchedules =>
      $$ReminderSchedulesTableTableManager(_db, _db.reminderSchedules);
  $$PrescriptionsTableTableManager get prescriptions =>
      $$PrescriptionsTableTableManager(_db, _db.prescriptions);
  $$PrescriptionRefillsTableTableManager get prescriptionRefills =>
      $$PrescriptionRefillsTableTableManager(_db, _db.prescriptionRefills);
  $$ScheduleProfilesTableTableManager get scheduleProfiles =>
      $$ScheduleProfilesTableTableManager(_db, _db.scheduleProfiles);
  $$CarouselSlotsTableTableManager get carouselSlots =>
      $$CarouselSlotsTableTableManager(_db, _db.carouselSlots);
  $$AuthSessionsTableTableManager get authSessions =>
      $$AuthSessionsTableTableManager(_db, _db.authSessions);
  $$DoseLogEventsTableTableManager get doseLogEvents =>
      $$DoseLogEventsTableTableManager(_db, _db.doseLogEvents);
  $$ControllerCommandSessionsTableTableManager get controllerCommandSessions =>
      $$ControllerCommandSessionsTableTableManager(
        _db,
        _db.controllerCommandSessions,
      );
  $$ControllerCommandEventsTableTableManager get controllerCommandEvents =>
      $$ControllerCommandEventsTableTableManager(
        _db,
        _db.controllerCommandEvents,
      );
  $$AdminAuditEventsTableTableManager get adminAuditEvents =>
      $$AdminAuditEventsTableTableManager(_db, _db.adminAuditEvents);
}
