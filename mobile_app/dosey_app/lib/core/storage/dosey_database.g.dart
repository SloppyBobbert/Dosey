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

abstract class _$DoseyDatabase extends GeneratedDatabase {
  _$DoseyDatabase(QueryExecutor e) : super(e);
  $DoseyDatabaseManager get managers => $DoseyDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $DoseLogEventsTable doseLogEvents = $DoseLogEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    doseLogEvents,
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

class $DoseyDatabaseManager {
  final _$DoseyDatabase _db;
  $DoseyDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$DoseLogEventsTableTableManager get doseLogEvents =>
      $$DoseLogEventsTableTableManager(_db, _db.doseLogEvents);
}
