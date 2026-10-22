// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<int> seriesId = GeneratedColumn<int>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toneIndexMeta = const VerificationMeta(
    'toneIndex',
  );
  @override
  late final GeneratedColumn<int> toneIndex = GeneratedColumn<int>(
    'tone_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFlightMeta = const VerificationMeta(
    'isFlight',
  );
  @override
  late final GeneratedColumn<bool> isFlight = GeneratedColumn<bool>(
    'is_flight',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_flight" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _flightNumberMeta = const VerificationMeta(
    'flightNumber',
  );
  @override
  late final GeneratedColumn<String> flightNumber = GeneratedColumn<String>(
    'flight_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromCodeMeta = const VerificationMeta(
    'fromCode',
  );
  @override
  late final GeneratedColumn<String> fromCode = GeneratedColumn<String>(
    'from_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toCodeMeta = const VerificationMeta('toCode');
  @override
  late final GeneratedColumn<String> toCode = GeneratedColumn<String>(
    'to_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    seriesId,
    date,
    title,
    toneIndex,
    startMinute,
    endMinute,
    status,
    isFlight,
    flightNumber,
    fromCode,
    toCode,
    projectId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('tone_index')) {
      context.handle(
        _toneIndexMeta,
        toneIndex.isAcceptableOrUnknown(data['tone_index']!, _toneIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_toneIndexMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_flight')) {
      context.handle(
        _isFlightMeta,
        isFlight.isAcceptableOrUnknown(data['is_flight']!, _isFlightMeta),
      );
    }
    if (data.containsKey('flight_number')) {
      context.handle(
        _flightNumberMeta,
        flightNumber.isAcceptableOrUnknown(
          data['flight_number']!,
          _flightNumberMeta,
        ),
      );
    }
    if (data.containsKey('from_code')) {
      context.handle(
        _fromCodeMeta,
        fromCode.isAcceptableOrUnknown(data['from_code']!, _fromCodeMeta),
      );
    }
    if (data.containsKey('to_code')) {
      context.handle(
        _toCodeMeta,
        toCode.isAcceptableOrUnknown(data['to_code']!, _toCodeMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
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
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_id'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      toneIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tone_index'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isFlight: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_flight'],
      )!,
      flightNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flight_number'],
      ),
      fromCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_code'],
      ),
      toCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_code'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      ),
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
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final int id;

  /// Null for one-off events; set when materialised from an [EventSeries].
  final int? seriesId;

  /// Local midnight of the day this event belongs to.
  final DateTime date;
  final String title;
  final int toneIndex;

  /// 0–1439.
  final int startMinute;

  /// 1–1440, exclusive. Never crosses midnight.
  final int endMinute;

  /// 0 planned, 1 completed, 2 skipped.
  final int status;

  /// True when this event is a manually-entered flight block (spec: travel
  /// day mode v1). Tone is forced to Inbox; rendering branches on this flag.
  final bool isFlight;

  /// Optional, uppercased, e.g. LH715. Null when empty or not a flight.
  final String? flightNumber;

  /// IATA codes, uppercased, e.g. SOF. Null unless [isFlight].
  final String? fromCode;
  final String? toCode;

  /// Nullable link to a project. Null = no project. Follows the seriesId precedent.
  final int? projectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const EventRow({
    required this.id,
    this.seriesId,
    required this.date,
    required this.title,
    required this.toneIndex,
    required this.startMinute,
    required this.endMinute,
    required this.status,
    required this.isFlight,
    this.flightNumber,
    this.fromCode,
    this.toCode,
    this.projectId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<int>(seriesId);
    }
    map['date'] = Variable<DateTime>(date);
    map['title'] = Variable<String>(title);
    map['tone_index'] = Variable<int>(toneIndex);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    map['status'] = Variable<int>(status);
    map['is_flight'] = Variable<bool>(isFlight);
    if (!nullToAbsent || flightNumber != null) {
      map['flight_number'] = Variable<String>(flightNumber);
    }
    if (!nullToAbsent || fromCode != null) {
      map['from_code'] = Variable<String>(fromCode);
    }
    if (!nullToAbsent || toCode != null) {
      map['to_code'] = Variable<String>(toCode);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<int>(projectId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      date: Value(date),
      title: Value(title),
      toneIndex: Value(toneIndex),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
      status: Value(status),
      isFlight: Value(isFlight),
      flightNumber: flightNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(flightNumber),
      fromCode: fromCode == null && nullToAbsent
          ? const Value.absent()
          : Value(fromCode),
      toCode: toCode == null && nullToAbsent
          ? const Value.absent()
          : Value(toCode),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<int>(json['id']),
      seriesId: serializer.fromJson<int?>(json['seriesId']),
      date: serializer.fromJson<DateTime>(json['date']),
      title: serializer.fromJson<String>(json['title']),
      toneIndex: serializer.fromJson<int>(json['toneIndex']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      status: serializer.fromJson<int>(json['status']),
      isFlight: serializer.fromJson<bool>(json['isFlight']),
      flightNumber: serializer.fromJson<String?>(json['flightNumber']),
      fromCode: serializer.fromJson<String?>(json['fromCode']),
      toCode: serializer.fromJson<String?>(json['toCode']),
      projectId: serializer.fromJson<int?>(json['projectId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'seriesId': serializer.toJson<int?>(seriesId),
      'date': serializer.toJson<DateTime>(date),
      'title': serializer.toJson<String>(title),
      'toneIndex': serializer.toJson<int>(toneIndex),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
      'status': serializer.toJson<int>(status),
      'isFlight': serializer.toJson<bool>(isFlight),
      'flightNumber': serializer.toJson<String?>(flightNumber),
      'fromCode': serializer.toJson<String?>(fromCode),
      'toCode': serializer.toJson<String?>(toCode),
      'projectId': serializer.toJson<int?>(projectId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EventRow copyWith({
    int? id,
    Value<int?> seriesId = const Value.absent(),
    DateTime? date,
    String? title,
    int? toneIndex,
    int? startMinute,
    int? endMinute,
    int? status,
    bool? isFlight,
    Value<String?> flightNumber = const Value.absent(),
    Value<String?> fromCode = const Value.absent(),
    Value<String?> toCode = const Value.absent(),
    Value<int?> projectId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EventRow(
    id: id ?? this.id,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    date: date ?? this.date,
    title: title ?? this.title,
    toneIndex: toneIndex ?? this.toneIndex,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    status: status ?? this.status,
    isFlight: isFlight ?? this.isFlight,
    flightNumber: flightNumber.present ? flightNumber.value : this.flightNumber,
    fromCode: fromCode.present ? fromCode.value : this.fromCode,
    toCode: toCode.present ? toCode.value : this.toCode,
    projectId: projectId.present ? projectId.value : this.projectId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      date: data.date.present ? data.date.value : this.date,
      title: data.title.present ? data.title.value : this.title,
      toneIndex: data.toneIndex.present ? data.toneIndex.value : this.toneIndex,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      status: data.status.present ? data.status.value : this.status,
      isFlight: data.isFlight.present ? data.isFlight.value : this.isFlight,
      flightNumber: data.flightNumber.present
          ? data.flightNumber.value
          : this.flightNumber,
      fromCode: data.fromCode.present ? data.fromCode.value : this.fromCode,
      toCode: data.toCode.present ? data.toCode.value : this.toCode,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('date: $date, ')
          ..write('title: $title, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('status: $status, ')
          ..write('isFlight: $isFlight, ')
          ..write('flightNumber: $flightNumber, ')
          ..write('fromCode: $fromCode, ')
          ..write('toCode: $toCode, ')
          ..write('projectId: $projectId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    date,
    title,
    toneIndex,
    startMinute,
    endMinute,
    status,
    isFlight,
    flightNumber,
    fromCode,
    toCode,
    projectId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.seriesId == this.seriesId &&
          other.date == this.date &&
          other.title == this.title &&
          other.toneIndex == this.toneIndex &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.status == this.status &&
          other.isFlight == this.isFlight &&
          other.flightNumber == this.flightNumber &&
          other.fromCode == this.fromCode &&
          other.toCode == this.toCode &&
          other.projectId == this.projectId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<int> id;
  final Value<int?> seriesId;
  final Value<DateTime> date;
  final Value<String> title;
  final Value<int> toneIndex;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> status;
  final Value<bool> isFlight;
  final Value<String?> flightNumber;
  final Value<String?> fromCode;
  final Value<String?> toCode;
  final Value<int?> projectId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.date = const Value.absent(),
    this.title = const Value.absent(),
    this.toneIndex = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.status = const Value.absent(),
    this.isFlight = const Value.absent(),
    this.flightNumber = const Value.absent(),
    this.fromCode = const Value.absent(),
    this.toCode = const Value.absent(),
    this.projectId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    required DateTime date,
    required String title,
    required int toneIndex,
    required int startMinute,
    required int endMinute,
    this.status = const Value.absent(),
    this.isFlight = const Value.absent(),
    this.flightNumber = const Value.absent(),
    this.fromCode = const Value.absent(),
    this.toCode = const Value.absent(),
    this.projectId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : date = Value(date),
       title = Value(title),
       toneIndex = Value(toneIndex),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<EventRow> custom({
    Expression<int>? id,
    Expression<int>? seriesId,
    Expression<DateTime>? date,
    Expression<String>? title,
    Expression<int>? toneIndex,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? status,
    Expression<bool>? isFlight,
    Expression<String>? flightNumber,
    Expression<String>? fromCode,
    Expression<String>? toCode,
    Expression<int>? projectId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seriesId != null) 'series_id': seriesId,
      if (date != null) 'date': date,
      if (title != null) 'title': title,
      if (toneIndex != null) 'tone_index': toneIndex,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (status != null) 'status': status,
      if (isFlight != null) 'is_flight': isFlight,
      if (flightNumber != null) 'flight_number': flightNumber,
      if (fromCode != null) 'from_code': fromCode,
      if (toCode != null) 'to_code': toCode,
      if (projectId != null) 'project_id': projectId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EventsCompanion copyWith({
    Value<int>? id,
    Value<int?>? seriesId,
    Value<DateTime>? date,
    Value<String>? title,
    Value<int>? toneIndex,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? status,
    Value<bool>? isFlight,
    Value<String?>? flightNumber,
    Value<String?>? fromCode,
    Value<String?>? toCode,
    Value<int?>? projectId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      date: date ?? this.date,
      title: title ?? this.title,
      toneIndex: toneIndex ?? this.toneIndex,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      status: status ?? this.status,
      isFlight: isFlight ?? this.isFlight,
      flightNumber: flightNumber ?? this.flightNumber,
      fromCode: fromCode ?? this.fromCode,
      toCode: toCode ?? this.toCode,
      projectId: projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<int>(seriesId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (toneIndex.present) {
      map['tone_index'] = Variable<int>(toneIndex.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isFlight.present) {
      map['is_flight'] = Variable<bool>(isFlight.value);
    }
    if (flightNumber.present) {
      map['flight_number'] = Variable<String>(flightNumber.value);
    }
    if (fromCode.present) {
      map['from_code'] = Variable<String>(fromCode.value);
    }
    if (toCode.present) {
      map['to_code'] = Variable<String>(toCode.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('date: $date, ')
          ..write('title: $title, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('status: $status, ')
          ..write('isFlight: $isFlight, ')
          ..write('flightNumber: $flightNumber, ')
          ..write('fromCode: $fromCode, ')
          ..write('toCode: $toCode, ')
          ..write('projectId: $projectId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EventSeriesTable extends EventSeries
    with TableInfo<$EventSeriesTable, EventSeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventSeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toneIndexMeta = const VerificationMeta(
    'toneIndex',
  );
  @override
  late final GeneratedColumn<int> toneIndex = GeneratedColumn<int>(
    'tone_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recurrenceKindMeta = const VerificationMeta(
    'recurrenceKind',
  );
  @override
  late final GeneratedColumn<int> recurrenceKind = GeneratedColumn<int>(
    'recurrence_kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekdayMaskMeta = const VerificationMeta(
    'weekdayMask',
  );
  @override
  late final GeneratedColumn<int> weekdayMask = GeneratedColumn<int>(
    'weekday_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _validFromMeta = const VerificationMeta(
    'validFrom',
  );
  @override
  late final GeneratedColumn<DateTime> validFrom = GeneratedColumn<DateTime>(
    'valid_from',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validUntilMeta = const VerificationMeta(
    'validUntil',
  );
  @override
  late final GeneratedColumn<DateTime> validUntil = GeneratedColumn<DateTime>(
    'valid_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    toneIndex,
    startMinute,
    endMinute,
    recurrenceKind,
    weekdayMask,
    validFrom,
    validUntil,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_series';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventSeriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('tone_index')) {
      context.handle(
        _toneIndexMeta,
        toneIndex.isAcceptableOrUnknown(data['tone_index']!, _toneIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_toneIndexMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('recurrence_kind')) {
      context.handle(
        _recurrenceKindMeta,
        recurrenceKind.isAcceptableOrUnknown(
          data['recurrence_kind']!,
          _recurrenceKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recurrenceKindMeta);
    }
    if (data.containsKey('weekday_mask')) {
      context.handle(
        _weekdayMaskMeta,
        weekdayMask.isAcceptableOrUnknown(
          data['weekday_mask']!,
          _weekdayMaskMeta,
        ),
      );
    }
    if (data.containsKey('valid_from')) {
      context.handle(
        _validFromMeta,
        validFrom.isAcceptableOrUnknown(data['valid_from']!, _validFromMeta),
      );
    } else if (isInserting) {
      context.missing(_validFromMeta);
    }
    if (data.containsKey('valid_until')) {
      context.handle(
        _validUntilMeta,
        validUntil.isAcceptableOrUnknown(data['valid_until']!, _validUntilMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventSeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventSeriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      toneIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tone_index'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      recurrenceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurrence_kind'],
      )!,
      weekdayMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday_mask'],
      )!,
      validFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}valid_from'],
      )!,
      validUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}valid_until'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EventSeriesTable createAlias(String alias) {
    return $EventSeriesTable(attachedDatabase, alias);
  }
}

class EventSeriesRow extends DataClass implements Insertable<EventSeriesRow> {
  final int id;
  final String title;
  final int toneIndex;
  final int startMinute;
  final int endMinute;

  /// 0 none, 1 daily, 2 weekdays, 3 custom mask.
  final int recurrenceKind;

  /// Seven-bit mask, Monday is bit 0.
  final int weekdayMask;
  final DateTime validFrom;
  final DateTime? validUntil;
  final DateTime createdAt;
  const EventSeriesRow({
    required this.id,
    required this.title,
    required this.toneIndex,
    required this.startMinute,
    required this.endMinute,
    required this.recurrenceKind,
    required this.weekdayMask,
    required this.validFrom,
    this.validUntil,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['tone_index'] = Variable<int>(toneIndex);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    map['recurrence_kind'] = Variable<int>(recurrenceKind);
    map['weekday_mask'] = Variable<int>(weekdayMask);
    map['valid_from'] = Variable<DateTime>(validFrom);
    if (!nullToAbsent || validUntil != null) {
      map['valid_until'] = Variable<DateTime>(validUntil);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EventSeriesCompanion toCompanion(bool nullToAbsent) {
    return EventSeriesCompanion(
      id: Value(id),
      title: Value(title),
      toneIndex: Value(toneIndex),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
      recurrenceKind: Value(recurrenceKind),
      weekdayMask: Value(weekdayMask),
      validFrom: Value(validFrom),
      validUntil: validUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(validUntil),
      createdAt: Value(createdAt),
    );
  }

  factory EventSeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventSeriesRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      toneIndex: serializer.fromJson<int>(json['toneIndex']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      recurrenceKind: serializer.fromJson<int>(json['recurrenceKind']),
      weekdayMask: serializer.fromJson<int>(json['weekdayMask']),
      validFrom: serializer.fromJson<DateTime>(json['validFrom']),
      validUntil: serializer.fromJson<DateTime?>(json['validUntil']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'toneIndex': serializer.toJson<int>(toneIndex),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
      'recurrenceKind': serializer.toJson<int>(recurrenceKind),
      'weekdayMask': serializer.toJson<int>(weekdayMask),
      'validFrom': serializer.toJson<DateTime>(validFrom),
      'validUntil': serializer.toJson<DateTime?>(validUntil),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EventSeriesRow copyWith({
    int? id,
    String? title,
    int? toneIndex,
    int? startMinute,
    int? endMinute,
    int? recurrenceKind,
    int? weekdayMask,
    DateTime? validFrom,
    Value<DateTime?> validUntil = const Value.absent(),
    DateTime? createdAt,
  }) => EventSeriesRow(
    id: id ?? this.id,
    title: title ?? this.title,
    toneIndex: toneIndex ?? this.toneIndex,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    recurrenceKind: recurrenceKind ?? this.recurrenceKind,
    weekdayMask: weekdayMask ?? this.weekdayMask,
    validFrom: validFrom ?? this.validFrom,
    validUntil: validUntil.present ? validUntil.value : this.validUntil,
    createdAt: createdAt ?? this.createdAt,
  );
  EventSeriesRow copyWithCompanion(EventSeriesCompanion data) {
    return EventSeriesRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      toneIndex: data.toneIndex.present ? data.toneIndex.value : this.toneIndex,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      recurrenceKind: data.recurrenceKind.present
          ? data.recurrenceKind.value
          : this.recurrenceKind,
      weekdayMask: data.weekdayMask.present
          ? data.weekdayMask.value
          : this.weekdayMask,
      validFrom: data.validFrom.present ? data.validFrom.value : this.validFrom,
      validUntil: data.validUntil.present
          ? data.validUntil.value
          : this.validUntil,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventSeriesRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('recurrenceKind: $recurrenceKind, ')
          ..write('weekdayMask: $weekdayMask, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    toneIndex,
    startMinute,
    endMinute,
    recurrenceKind,
    weekdayMask,
    validFrom,
    validUntil,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSeriesRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.toneIndex == this.toneIndex &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.recurrenceKind == this.recurrenceKind &&
          other.weekdayMask == this.weekdayMask &&
          other.validFrom == this.validFrom &&
          other.validUntil == this.validUntil &&
          other.createdAt == this.createdAt);
}

class EventSeriesCompanion extends UpdateCompanion<EventSeriesRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<int> toneIndex;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> recurrenceKind;
  final Value<int> weekdayMask;
  final Value<DateTime> validFrom;
  final Value<DateTime?> validUntil;
  final Value<DateTime> createdAt;
  const EventSeriesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.toneIndex = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.recurrenceKind = const Value.absent(),
    this.weekdayMask = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EventSeriesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required int toneIndex,
    required int startMinute,
    required int endMinute,
    required int recurrenceKind,
    this.weekdayMask = const Value.absent(),
    required DateTime validFrom,
    this.validUntil = const Value.absent(),
    required DateTime createdAt,
  }) : title = Value(title),
       toneIndex = Value(toneIndex),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute),
       recurrenceKind = Value(recurrenceKind),
       validFrom = Value(validFrom),
       createdAt = Value(createdAt);
  static Insertable<EventSeriesRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? toneIndex,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? recurrenceKind,
    Expression<int>? weekdayMask,
    Expression<DateTime>? validFrom,
    Expression<DateTime>? validUntil,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (toneIndex != null) 'tone_index': toneIndex,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (recurrenceKind != null) 'recurrence_kind': recurrenceKind,
      if (weekdayMask != null) 'weekday_mask': weekdayMask,
      if (validFrom != null) 'valid_from': validFrom,
      if (validUntil != null) 'valid_until': validUntil,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EventSeriesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int>? toneIndex,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? recurrenceKind,
    Value<int>? weekdayMask,
    Value<DateTime>? validFrom,
    Value<DateTime?>? validUntil,
    Value<DateTime>? createdAt,
  }) {
    return EventSeriesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      toneIndex: toneIndex ?? this.toneIndex,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      recurrenceKind: recurrenceKind ?? this.recurrenceKind,
      weekdayMask: weekdayMask ?? this.weekdayMask,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (toneIndex.present) {
      map['tone_index'] = Variable<int>(toneIndex.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (recurrenceKind.present) {
      map['recurrence_kind'] = Variable<int>(recurrenceKind.value);
    }
    if (weekdayMask.present) {
      map['weekday_mask'] = Variable<int>(weekdayMask.value);
    }
    if (validFrom.present) {
      map['valid_from'] = Variable<DateTime>(validFrom.value);
    }
    if (validUntil.present) {
      map['valid_until'] = Variable<DateTime>(validUntil.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventSeriesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('recurrenceKind: $recurrenceKind, ')
          ..write('weekdayMask: $weekdayMask, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
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
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events (id)',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedSecondsMeta = const VerificationMeta(
    'plannedSeconds',
  );
  @override
  late final GeneratedColumn<int> plannedSeconds = GeneratedColumn<int>(
    'planned_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pausedSecondsMeta = const VerificationMeta(
    'pausedSeconds',
  );
  @override
  late final GeneratedColumn<int> pausedSeconds = GeneratedColumn<int>(
    'paused_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pauseStartedAtMeta = const VerificationMeta(
    'pauseStartedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pauseStartedAt =
      GeneratedColumn<DateTime>(
        'pause_started_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _activeSecondsMeta = const VerificationMeta(
    'activeSeconds',
  );
  @override
  late final GeneratedColumn<int> activeSeconds = GeneratedColumn<int>(
    'active_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _overtimeSecondsMeta = const VerificationMeta(
    'overtimeSeconds',
  );
  @override
  late final GeneratedColumn<int> overtimeSeconds = GeneratedColumn<int>(
    'overtime_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<int> outcome = GeneratedColumn<int>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _energyRatingMeta = const VerificationMeta(
    'energyRating',
  );
  @override
  late final GeneratedColumn<int> energyRating = GeneratedColumn<int>(
    'energy_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focusRatingMeta = const VerificationMeta(
    'focusRating',
  );
  @override
  late final GeneratedColumn<int> focusRating = GeneratedColumn<int>(
    'focus_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsCsvMeta = const VerificationMeta(
    'tagsCsv',
  );
  @override
  late final GeneratedColumn<String> tagsCsv = GeneratedColumn<String>(
    'tags_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    eventId,
    startedAt,
    endedAt,
    plannedSeconds,
    pausedSeconds,
    pauseStartedAt,
    activeSeconds,
    overtimeSeconds,
    outcome,
    energyRating,
    focusRating,
    tagsCsv,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('planned_seconds')) {
      context.handle(
        _plannedSecondsMeta,
        plannedSeconds.isAcceptableOrUnknown(
          data['planned_seconds']!,
          _plannedSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plannedSecondsMeta);
    }
    if (data.containsKey('paused_seconds')) {
      context.handle(
        _pausedSecondsMeta,
        pausedSeconds.isAcceptableOrUnknown(
          data['paused_seconds']!,
          _pausedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('pause_started_at')) {
      context.handle(
        _pauseStartedAtMeta,
        pauseStartedAt.isAcceptableOrUnknown(
          data['pause_started_at']!,
          _pauseStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('active_seconds')) {
      context.handle(
        _activeSecondsMeta,
        activeSeconds.isAcceptableOrUnknown(
          data['active_seconds']!,
          _activeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('overtime_seconds')) {
      context.handle(
        _overtimeSecondsMeta,
        overtimeSeconds.isAcceptableOrUnknown(
          data['overtime_seconds']!,
          _overtimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('energy_rating')) {
      context.handle(
        _energyRatingMeta,
        energyRating.isAcceptableOrUnknown(
          data['energy_rating']!,
          _energyRatingMeta,
        ),
      );
    }
    if (data.containsKey('focus_rating')) {
      context.handle(
        _focusRatingMeta,
        focusRating.isAcceptableOrUnknown(
          data['focus_rating']!,
          _focusRatingMeta,
        ),
      );
    }
    if (data.containsKey('tags_csv')) {
      context.handle(
        _tagsCsvMeta,
        tagsCsv.isAcceptableOrUnknown(data['tags_csv']!, _tagsCsvMeta),
      );
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
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      plannedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_seconds'],
      )!,
      pausedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_seconds'],
      )!,
      pauseStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pause_started_at'],
      ),
      activeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_seconds'],
      )!,
      overtimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_seconds'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}outcome'],
      )!,
      energyRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy_rating'],
      ),
      focusRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_rating'],
      ),
      tagsCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_csv'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final int id;
  final int eventId;

  /// When the session began.
  final DateTime startedAt;

  /// Null while the session is running.
  final DateTime? endedAt;

  /// The planned length when the session started, plus any extensions.
  final int plannedSeconds;

  /// Completed pauses, in total.
  final int pausedSeconds;

  /// When the current pause began; null unless the session is paused.
  final DateTime? pauseStartedAt;

  /// Time actually worked. Written when the session ends.
  final int activeSeconds;

  /// Time worked past the planned end. Written when the session ends.
  final int overtimeSeconds;

  /// 0 running, 1 completed, 2 finished early, 3 abandoned.
  final int outcome;

  /// 1–5 (drained → charged). Null = not reflected.
  final int? energyRating;

  /// 1–5 (scattered → in flow). Null = not reflected.
  final int? focusRating;

  /// Comma-joined tag ids, max 4. Null or empty = none.
  final String? tagsCsv;

  /// 0–140 chars, trimmed. Null or empty = none.
  final String? note;
  const SessionRow({
    required this.id,
    required this.eventId,
    required this.startedAt,
    this.endedAt,
    required this.plannedSeconds,
    required this.pausedSeconds,
    this.pauseStartedAt,
    required this.activeSeconds,
    required this.overtimeSeconds,
    required this.outcome,
    this.energyRating,
    this.focusRating,
    this.tagsCsv,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['planned_seconds'] = Variable<int>(plannedSeconds);
    map['paused_seconds'] = Variable<int>(pausedSeconds);
    if (!nullToAbsent || pauseStartedAt != null) {
      map['pause_started_at'] = Variable<DateTime>(pauseStartedAt);
    }
    map['active_seconds'] = Variable<int>(activeSeconds);
    map['overtime_seconds'] = Variable<int>(overtimeSeconds);
    map['outcome'] = Variable<int>(outcome);
    if (!nullToAbsent || energyRating != null) {
      map['energy_rating'] = Variable<int>(energyRating);
    }
    if (!nullToAbsent || focusRating != null) {
      map['focus_rating'] = Variable<int>(focusRating);
    }
    if (!nullToAbsent || tagsCsv != null) {
      map['tags_csv'] = Variable<String>(tagsCsv);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      plannedSeconds: Value(plannedSeconds),
      pausedSeconds: Value(pausedSeconds),
      pauseStartedAt: pauseStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseStartedAt),
      activeSeconds: Value(activeSeconds),
      overtimeSeconds: Value(overtimeSeconds),
      outcome: Value(outcome),
      energyRating: energyRating == null && nullToAbsent
          ? const Value.absent()
          : Value(energyRating),
      focusRating: focusRating == null && nullToAbsent
          ? const Value.absent()
          : Value(focusRating),
      tagsCsv: tagsCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsCsv),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      plannedSeconds: serializer.fromJson<int>(json['plannedSeconds']),
      pausedSeconds: serializer.fromJson<int>(json['pausedSeconds']),
      pauseStartedAt: serializer.fromJson<DateTime?>(json['pauseStartedAt']),
      activeSeconds: serializer.fromJson<int>(json['activeSeconds']),
      overtimeSeconds: serializer.fromJson<int>(json['overtimeSeconds']),
      outcome: serializer.fromJson<int>(json['outcome']),
      energyRating: serializer.fromJson<int?>(json['energyRating']),
      focusRating: serializer.fromJson<int?>(json['focusRating']),
      tagsCsv: serializer.fromJson<String?>(json['tagsCsv']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'plannedSeconds': serializer.toJson<int>(plannedSeconds),
      'pausedSeconds': serializer.toJson<int>(pausedSeconds),
      'pauseStartedAt': serializer.toJson<DateTime?>(pauseStartedAt),
      'activeSeconds': serializer.toJson<int>(activeSeconds),
      'overtimeSeconds': serializer.toJson<int>(overtimeSeconds),
      'outcome': serializer.toJson<int>(outcome),
      'energyRating': serializer.toJson<int?>(energyRating),
      'focusRating': serializer.toJson<int?>(focusRating),
      'tagsCsv': serializer.toJson<String?>(tagsCsv),
      'note': serializer.toJson<String?>(note),
    };
  }

  SessionRow copyWith({
    int? id,
    int? eventId,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? plannedSeconds,
    int? pausedSeconds,
    Value<DateTime?> pauseStartedAt = const Value.absent(),
    int? activeSeconds,
    int? overtimeSeconds,
    int? outcome,
    Value<int?> energyRating = const Value.absent(),
    Value<int?> focusRating = const Value.absent(),
    Value<String?> tagsCsv = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    plannedSeconds: plannedSeconds ?? this.plannedSeconds,
    pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    pauseStartedAt: pauseStartedAt.present
        ? pauseStartedAt.value
        : this.pauseStartedAt,
    activeSeconds: activeSeconds ?? this.activeSeconds,
    overtimeSeconds: overtimeSeconds ?? this.overtimeSeconds,
    outcome: outcome ?? this.outcome,
    energyRating: energyRating.present ? energyRating.value : this.energyRating,
    focusRating: focusRating.present ? focusRating.value : this.focusRating,
    tagsCsv: tagsCsv.present ? tagsCsv.value : this.tagsCsv,
    note: note.present ? note.value : this.note,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      plannedSeconds: data.plannedSeconds.present
          ? data.plannedSeconds.value
          : this.plannedSeconds,
      pausedSeconds: data.pausedSeconds.present
          ? data.pausedSeconds.value
          : this.pausedSeconds,
      pauseStartedAt: data.pauseStartedAt.present
          ? data.pauseStartedAt.value
          : this.pauseStartedAt,
      activeSeconds: data.activeSeconds.present
          ? data.activeSeconds.value
          : this.activeSeconds,
      overtimeSeconds: data.overtimeSeconds.present
          ? data.overtimeSeconds.value
          : this.overtimeSeconds,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      energyRating: data.energyRating.present
          ? data.energyRating.value
          : this.energyRating,
      focusRating: data.focusRating.present
          ? data.focusRating.value
          : this.focusRating,
      tagsCsv: data.tagsCsv.present ? data.tagsCsv.value : this.tagsCsv,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('plannedSeconds: $plannedSeconds, ')
          ..write('pausedSeconds: $pausedSeconds, ')
          ..write('pauseStartedAt: $pauseStartedAt, ')
          ..write('activeSeconds: $activeSeconds, ')
          ..write('overtimeSeconds: $overtimeSeconds, ')
          ..write('outcome: $outcome, ')
          ..write('energyRating: $energyRating, ')
          ..write('focusRating: $focusRating, ')
          ..write('tagsCsv: $tagsCsv, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    startedAt,
    endedAt,
    plannedSeconds,
    pausedSeconds,
    pauseStartedAt,
    activeSeconds,
    overtimeSeconds,
    outcome,
    energyRating,
    focusRating,
    tagsCsv,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.plannedSeconds == this.plannedSeconds &&
          other.pausedSeconds == this.pausedSeconds &&
          other.pauseStartedAt == this.pauseStartedAt &&
          other.activeSeconds == this.activeSeconds &&
          other.overtimeSeconds == this.overtimeSeconds &&
          other.outcome == this.outcome &&
          other.energyRating == this.energyRating &&
          other.focusRating == this.focusRating &&
          other.tagsCsv == this.tagsCsv &&
          other.note == this.note);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> plannedSeconds;
  final Value<int> pausedSeconds;
  final Value<DateTime?> pauseStartedAt;
  final Value<int> activeSeconds;
  final Value<int> overtimeSeconds;
  final Value<int> outcome;
  final Value<int?> energyRating;
  final Value<int?> focusRating;
  final Value<String?> tagsCsv;
  final Value<String?> note;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.plannedSeconds = const Value.absent(),
    this.pausedSeconds = const Value.absent(),
    this.pauseStartedAt = const Value.absent(),
    this.activeSeconds = const Value.absent(),
    this.overtimeSeconds = const Value.absent(),
    this.outcome = const Value.absent(),
    this.energyRating = const Value.absent(),
    this.focusRating = const Value.absent(),
    this.tagsCsv = const Value.absent(),
    this.note = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required int plannedSeconds,
    this.pausedSeconds = const Value.absent(),
    this.pauseStartedAt = const Value.absent(),
    this.activeSeconds = const Value.absent(),
    this.overtimeSeconds = const Value.absent(),
    this.outcome = const Value.absent(),
    this.energyRating = const Value.absent(),
    this.focusRating = const Value.absent(),
    this.tagsCsv = const Value.absent(),
    this.note = const Value.absent(),
  }) : eventId = Value(eventId),
       startedAt = Value(startedAt),
       plannedSeconds = Value(plannedSeconds);
  static Insertable<SessionRow> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? plannedSeconds,
    Expression<int>? pausedSeconds,
    Expression<DateTime>? pauseStartedAt,
    Expression<int>? activeSeconds,
    Expression<int>? overtimeSeconds,
    Expression<int>? outcome,
    Expression<int>? energyRating,
    Expression<int>? focusRating,
    Expression<String>? tagsCsv,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (plannedSeconds != null) 'planned_seconds': plannedSeconds,
      if (pausedSeconds != null) 'paused_seconds': pausedSeconds,
      if (pauseStartedAt != null) 'pause_started_at': pauseStartedAt,
      if (activeSeconds != null) 'active_seconds': activeSeconds,
      if (overtimeSeconds != null) 'overtime_seconds': overtimeSeconds,
      if (outcome != null) 'outcome': outcome,
      if (energyRating != null) 'energy_rating': energyRating,
      if (focusRating != null) 'focus_rating': focusRating,
      if (tagsCsv != null) 'tags_csv': tagsCsv,
      if (note != null) 'note': note,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<int>? eventId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? plannedSeconds,
    Value<int>? pausedSeconds,
    Value<DateTime?>? pauseStartedAt,
    Value<int>? activeSeconds,
    Value<int>? overtimeSeconds,
    Value<int>? outcome,
    Value<int?>? energyRating,
    Value<int?>? focusRating,
    Value<String?>? tagsCsv,
    Value<String?>? note,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      pauseStartedAt: pauseStartedAt ?? this.pauseStartedAt,
      activeSeconds: activeSeconds ?? this.activeSeconds,
      overtimeSeconds: overtimeSeconds ?? this.overtimeSeconds,
      outcome: outcome ?? this.outcome,
      energyRating: energyRating ?? this.energyRating,
      focusRating: focusRating ?? this.focusRating,
      tagsCsv: tagsCsv ?? this.tagsCsv,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (plannedSeconds.present) {
      map['planned_seconds'] = Variable<int>(plannedSeconds.value);
    }
    if (pausedSeconds.present) {
      map['paused_seconds'] = Variable<int>(pausedSeconds.value);
    }
    if (pauseStartedAt.present) {
      map['pause_started_at'] = Variable<DateTime>(pauseStartedAt.value);
    }
    if (activeSeconds.present) {
      map['active_seconds'] = Variable<int>(activeSeconds.value);
    }
    if (overtimeSeconds.present) {
      map['overtime_seconds'] = Variable<int>(overtimeSeconds.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<int>(outcome.value);
    }
    if (energyRating.present) {
      map['energy_rating'] = Variable<int>(energyRating.value);
    }
    if (focusRating.present) {
      map['focus_rating'] = Variable<int>(focusRating.value);
    }
    if (tagsCsv.present) {
      map['tags_csv'] = Variable<String>(tagsCsv.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('plannedSeconds: $plannedSeconds, ')
          ..write('pausedSeconds: $pausedSeconds, ')
          ..write('pauseStartedAt: $pauseStartedAt, ')
          ..write('activeSeconds: $activeSeconds, ')
          ..write('overtimeSeconds: $overtimeSeconds, ')
          ..write('outcome: $outcome, ')
          ..write('energyRating: $energyRating, ')
          ..write('focusRating: $focusRating, ')
          ..write('tagsCsv: $tagsCsv, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $DayTemplatesTable extends DayTemplates
    with TableInfo<$DayTemplatesTable, DayTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
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
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DayTemplatesTable createAlias(String alias) {
    return $DayTemplatesTable(attachedDatabase, alias);
  }
}

class DayTemplateRow extends DataClass implements Insertable<DayTemplateRow> {
  final int id;
  final String name;
  final DateTime createdAt;
  const DayTemplateRow({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DayTemplatesCompanion toCompanion(bool nullToAbsent) {
    return DayTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory DayTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayTemplateRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DayTemplateRow copyWith({int? id, String? name, DateTime? createdAt}) =>
      DayTemplateRow(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  DayTemplateRow copyWithCompanion(DayTemplatesCompanion data) {
    return DayTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayTemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayTemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class DayTemplatesCompanion extends UpdateCompanion<DayTemplateRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const DayTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DayTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<DayTemplateRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DayTemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return DayTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DayTemplateItemsTable extends DayTemplateItems
    with TableInfo<$DayTemplateItemsTable, DayTemplateItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayTemplateItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<int> templateId = GeneratedColumn<int>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES day_templates (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toneIndexMeta = const VerificationMeta(
    'toneIndex',
  );
  @override
  late final GeneratedColumn<int> toneIndex = GeneratedColumn<int>(
    'tone_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    title,
    toneIndex,
    startMinute,
    endMinute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_template_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayTemplateItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('tone_index')) {
      context.handle(
        _toneIndexMeta,
        toneIndex.isAcceptableOrUnknown(data['tone_index']!, _toneIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_toneIndexMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayTemplateItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayTemplateItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      toneIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tone_index'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
    );
  }

  @override
  $DayTemplateItemsTable createAlias(String alias) {
    return $DayTemplateItemsTable(attachedDatabase, alias);
  }
}

class DayTemplateItemRow extends DataClass
    implements Insertable<DayTemplateItemRow> {
  final int id;
  final int templateId;
  final String title;
  final int toneIndex;

  /// 0–1439.
  final int startMinute;

  /// 1–1440, exclusive.
  final int endMinute;
  const DayTemplateItemRow({
    required this.id,
    required this.templateId,
    required this.title,
    required this.toneIndex,
    required this.startMinute,
    required this.endMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['template_id'] = Variable<int>(templateId);
    map['title'] = Variable<String>(title);
    map['tone_index'] = Variable<int>(toneIndex);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    return map;
  }

  DayTemplateItemsCompanion toCompanion(bool nullToAbsent) {
    return DayTemplateItemsCompanion(
      id: Value(id),
      templateId: Value(templateId),
      title: Value(title),
      toneIndex: Value(toneIndex),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
    );
  }

  factory DayTemplateItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayTemplateItemRow(
      id: serializer.fromJson<int>(json['id']),
      templateId: serializer.fromJson<int>(json['templateId']),
      title: serializer.fromJson<String>(json['title']),
      toneIndex: serializer.fromJson<int>(json['toneIndex']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'templateId': serializer.toJson<int>(templateId),
      'title': serializer.toJson<String>(title),
      'toneIndex': serializer.toJson<int>(toneIndex),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
    };
  }

  DayTemplateItemRow copyWith({
    int? id,
    int? templateId,
    String? title,
    int? toneIndex,
    int? startMinute,
    int? endMinute,
  }) => DayTemplateItemRow(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    title: title ?? this.title,
    toneIndex: toneIndex ?? this.toneIndex,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
  );
  DayTemplateItemRow copyWithCompanion(DayTemplateItemsCompanion data) {
    return DayTemplateItemRow(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      title: data.title.present ? data.title.value : this.title,
      toneIndex: data.toneIndex.present ? data.toneIndex.value : this.toneIndex,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayTemplateItemRow(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('title: $title, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, templateId, title, toneIndex, startMinute, endMinute);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayTemplateItemRow &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.title == this.title &&
          other.toneIndex == this.toneIndex &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute);
}

class DayTemplateItemsCompanion extends UpdateCompanion<DayTemplateItemRow> {
  final Value<int> id;
  final Value<int> templateId;
  final Value<String> title;
  final Value<int> toneIndex;
  final Value<int> startMinute;
  final Value<int> endMinute;
  const DayTemplateItemsCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.title = const Value.absent(),
    this.toneIndex = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
  });
  DayTemplateItemsCompanion.insert({
    this.id = const Value.absent(),
    required int templateId,
    required String title,
    required int toneIndex,
    required int startMinute,
    required int endMinute,
  }) : templateId = Value(templateId),
       title = Value(title),
       toneIndex = Value(toneIndex),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute);
  static Insertable<DayTemplateItemRow> custom({
    Expression<int>? id,
    Expression<int>? templateId,
    Expression<String>? title,
    Expression<int>? toneIndex,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (title != null) 'title': title,
      if (toneIndex != null) 'tone_index': toneIndex,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
    });
  }

  DayTemplateItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? templateId,
    Value<String>? title,
    Value<int>? toneIndex,
    Value<int>? startMinute,
    Value<int>? endMinute,
  }) {
    return DayTemplateItemsCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      toneIndex: toneIndex ?? this.toneIndex,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<int>(templateId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (toneIndex.present) {
      map['tone_index'] = Variable<int>(toneIndex.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayTemplateItemsCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('title: $title, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute')
          ..write(')'))
        .toString();
  }
}

class $DayScoresTable extends DayScores
    with TableInfo<$DayScoresTable, DayScoreRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayScoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyScoreMeta = const VerificationMeta(
    'energyScore',
  );
  @override
  late final GeneratedColumn<int> energyScore = GeneratedColumn<int>(
    'energy_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adherencePointsMeta = const VerificationMeta(
    'adherencePoints',
  );
  @override
  late final GeneratedColumn<int> adherencePoints = GeneratedColumn<int>(
    'adherence_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focusPointsMeta = const VerificationMeta(
    'focusPoints',
  );
  @override
  late final GeneratedColumn<int> focusPoints = GeneratedColumn<int>(
    'focus_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balancePointsMeta = const VerificationMeta(
    'balancePoints',
  );
  @override
  late final GeneratedColumn<int> balancePoints = GeneratedColumn<int>(
    'balance_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focusMinutesMeta = const VerificationMeta(
    'focusMinutes',
  );
  @override
  late final GeneratedColumn<int> focusMinutes = GeneratedColumn<int>(
    'focus_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lifeMinutesMeta = const VerificationMeta(
    'lifeMinutes',
  );
  @override
  late final GeneratedColumn<int> lifeMinutes = GeneratedColumn<int>(
    'life_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inboxMinutesMeta = const VerificationMeta(
    'inboxMinutes',
  );
  @override
  late final GeneratedColumn<int> inboxMinutes = GeneratedColumn<int>(
    'inbox_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _plannedMinutesMeta = const VerificationMeta(
    'plannedMinutes',
  );
  @override
  late final GeneratedColumn<int> plannedMinutes = GeneratedColumn<int>(
    'planned_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMinutesMeta = const VerificationMeta(
    'completedMinutes',
  );
  @override
  late final GeneratedColumn<int> completedMinutes = GeneratedColumn<int>(
    'completed_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _computedAtMeta = const VerificationMeta(
    'computedAt',
  );
  @override
  late final GeneratedColumn<DateTime> computedAt = GeneratedColumn<DateTime>(
    'computed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    energyScore,
    adherencePoints,
    focusPoints,
    balancePoints,
    focusMinutes,
    lifeMinutes,
    inboxMinutes,
    plannedMinutes,
    completedMinutes,
    computedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_scores';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayScoreRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('energy_score')) {
      context.handle(
        _energyScoreMeta,
        energyScore.isAcceptableOrUnknown(
          data['energy_score']!,
          _energyScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_energyScoreMeta);
    }
    if (data.containsKey('adherence_points')) {
      context.handle(
        _adherencePointsMeta,
        adherencePoints.isAcceptableOrUnknown(
          data['adherence_points']!,
          _adherencePointsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_adherencePointsMeta);
    }
    if (data.containsKey('focus_points')) {
      context.handle(
        _focusPointsMeta,
        focusPoints.isAcceptableOrUnknown(
          data['focus_points']!,
          _focusPointsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_focusPointsMeta);
    }
    if (data.containsKey('balance_points')) {
      context.handle(
        _balancePointsMeta,
        balancePoints.isAcceptableOrUnknown(
          data['balance_points']!,
          _balancePointsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balancePointsMeta);
    }
    if (data.containsKey('focus_minutes')) {
      context.handle(
        _focusMinutesMeta,
        focusMinutes.isAcceptableOrUnknown(
          data['focus_minutes']!,
          _focusMinutesMeta,
        ),
      );
    }
    if (data.containsKey('life_minutes')) {
      context.handle(
        _lifeMinutesMeta,
        lifeMinutes.isAcceptableOrUnknown(
          data['life_minutes']!,
          _lifeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('inbox_minutes')) {
      context.handle(
        _inboxMinutesMeta,
        inboxMinutes.isAcceptableOrUnknown(
          data['inbox_minutes']!,
          _inboxMinutesMeta,
        ),
      );
    }
    if (data.containsKey('planned_minutes')) {
      context.handle(
        _plannedMinutesMeta,
        plannedMinutes.isAcceptableOrUnknown(
          data['planned_minutes']!,
          _plannedMinutesMeta,
        ),
      );
    }
    if (data.containsKey('completed_minutes')) {
      context.handle(
        _completedMinutesMeta,
        completedMinutes.isAcceptableOrUnknown(
          data['completed_minutes']!,
          _completedMinutesMeta,
        ),
      );
    }
    if (data.containsKey('computed_at')) {
      context.handle(
        _computedAtMeta,
        computedAt.isAcceptableOrUnknown(data['computed_at']!, _computedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_computedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DayScoreRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayScoreRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      energyScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy_score'],
      )!,
      adherencePoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}adherence_points'],
      )!,
      focusPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_points'],
      )!,
      balancePoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_points'],
      )!,
      focusMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_minutes'],
      )!,
      lifeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}life_minutes'],
      )!,
      inboxMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}inbox_minutes'],
      )!,
      plannedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_minutes'],
      )!,
      completedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_minutes'],
      )!,
      computedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}computed_at'],
      )!,
    );
  }

  @override
  $DayScoresTable createAlias(String alias) {
    return $DayScoresTable(attachedDatabase, alias);
  }
}

class DayScoreRow extends DataClass implements Insertable<DayScoreRow> {
  /// Local midnight of the scored day.
  final DateTime date;

  /// 0–100, the sum of the three points columns.
  final int energyScore;

  /// 0–50.
  final int adherencePoints;

  /// 0–30.
  final int focusPoints;

  /// 0–20.
  final int balancePoints;

  /// The minute pool (countsAsDone), by tone.
  final int focusMinutes;
  final int lifeMinutes;
  final int inboxMinutes;
  final int plannedMinutes;
  final int completedMinutes;
  final DateTime computedAt;
  const DayScoreRow({
    required this.date,
    required this.energyScore,
    required this.adherencePoints,
    required this.focusPoints,
    required this.balancePoints,
    required this.focusMinutes,
    required this.lifeMinutes,
    required this.inboxMinutes,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.computedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['energy_score'] = Variable<int>(energyScore);
    map['adherence_points'] = Variable<int>(adherencePoints);
    map['focus_points'] = Variable<int>(focusPoints);
    map['balance_points'] = Variable<int>(balancePoints);
    map['focus_minutes'] = Variable<int>(focusMinutes);
    map['life_minutes'] = Variable<int>(lifeMinutes);
    map['inbox_minutes'] = Variable<int>(inboxMinutes);
    map['planned_minutes'] = Variable<int>(plannedMinutes);
    map['completed_minutes'] = Variable<int>(completedMinutes);
    map['computed_at'] = Variable<DateTime>(computedAt);
    return map;
  }

  DayScoresCompanion toCompanion(bool nullToAbsent) {
    return DayScoresCompanion(
      date: Value(date),
      energyScore: Value(energyScore),
      adherencePoints: Value(adherencePoints),
      focusPoints: Value(focusPoints),
      balancePoints: Value(balancePoints),
      focusMinutes: Value(focusMinutes),
      lifeMinutes: Value(lifeMinutes),
      inboxMinutes: Value(inboxMinutes),
      plannedMinutes: Value(plannedMinutes),
      completedMinutes: Value(completedMinutes),
      computedAt: Value(computedAt),
    );
  }

  factory DayScoreRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayScoreRow(
      date: serializer.fromJson<DateTime>(json['date']),
      energyScore: serializer.fromJson<int>(json['energyScore']),
      adherencePoints: serializer.fromJson<int>(json['adherencePoints']),
      focusPoints: serializer.fromJson<int>(json['focusPoints']),
      balancePoints: serializer.fromJson<int>(json['balancePoints']),
      focusMinutes: serializer.fromJson<int>(json['focusMinutes']),
      lifeMinutes: serializer.fromJson<int>(json['lifeMinutes']),
      inboxMinutes: serializer.fromJson<int>(json['inboxMinutes']),
      plannedMinutes: serializer.fromJson<int>(json['plannedMinutes']),
      completedMinutes: serializer.fromJson<int>(json['completedMinutes']),
      computedAt: serializer.fromJson<DateTime>(json['computedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'energyScore': serializer.toJson<int>(energyScore),
      'adherencePoints': serializer.toJson<int>(adherencePoints),
      'focusPoints': serializer.toJson<int>(focusPoints),
      'balancePoints': serializer.toJson<int>(balancePoints),
      'focusMinutes': serializer.toJson<int>(focusMinutes),
      'lifeMinutes': serializer.toJson<int>(lifeMinutes),
      'inboxMinutes': serializer.toJson<int>(inboxMinutes),
      'plannedMinutes': serializer.toJson<int>(plannedMinutes),
      'completedMinutes': serializer.toJson<int>(completedMinutes),
      'computedAt': serializer.toJson<DateTime>(computedAt),
    };
  }

  DayScoreRow copyWith({
    DateTime? date,
    int? energyScore,
    int? adherencePoints,
    int? focusPoints,
    int? balancePoints,
    int? focusMinutes,
    int? lifeMinutes,
    int? inboxMinutes,
    int? plannedMinutes,
    int? completedMinutes,
    DateTime? computedAt,
  }) => DayScoreRow(
    date: date ?? this.date,
    energyScore: energyScore ?? this.energyScore,
    adherencePoints: adherencePoints ?? this.adherencePoints,
    focusPoints: focusPoints ?? this.focusPoints,
    balancePoints: balancePoints ?? this.balancePoints,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    lifeMinutes: lifeMinutes ?? this.lifeMinutes,
    inboxMinutes: inboxMinutes ?? this.inboxMinutes,
    plannedMinutes: plannedMinutes ?? this.plannedMinutes,
    completedMinutes: completedMinutes ?? this.completedMinutes,
    computedAt: computedAt ?? this.computedAt,
  );
  DayScoreRow copyWithCompanion(DayScoresCompanion data) {
    return DayScoreRow(
      date: data.date.present ? data.date.value : this.date,
      energyScore: data.energyScore.present
          ? data.energyScore.value
          : this.energyScore,
      adherencePoints: data.adherencePoints.present
          ? data.adherencePoints.value
          : this.adherencePoints,
      focusPoints: data.focusPoints.present
          ? data.focusPoints.value
          : this.focusPoints,
      balancePoints: data.balancePoints.present
          ? data.balancePoints.value
          : this.balancePoints,
      focusMinutes: data.focusMinutes.present
          ? data.focusMinutes.value
          : this.focusMinutes,
      lifeMinutes: data.lifeMinutes.present
          ? data.lifeMinutes.value
          : this.lifeMinutes,
      inboxMinutes: data.inboxMinutes.present
          ? data.inboxMinutes.value
          : this.inboxMinutes,
      plannedMinutes: data.plannedMinutes.present
          ? data.plannedMinutes.value
          : this.plannedMinutes,
      completedMinutes: data.completedMinutes.present
          ? data.completedMinutes.value
          : this.completedMinutes,
      computedAt: data.computedAt.present
          ? data.computedAt.value
          : this.computedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayScoreRow(')
          ..write('date: $date, ')
          ..write('energyScore: $energyScore, ')
          ..write('adherencePoints: $adherencePoints, ')
          ..write('focusPoints: $focusPoints, ')
          ..write('balancePoints: $balancePoints, ')
          ..write('focusMinutes: $focusMinutes, ')
          ..write('lifeMinutes: $lifeMinutes, ')
          ..write('inboxMinutes: $inboxMinutes, ')
          ..write('plannedMinutes: $plannedMinutes, ')
          ..write('completedMinutes: $completedMinutes, ')
          ..write('computedAt: $computedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    energyScore,
    adherencePoints,
    focusPoints,
    balancePoints,
    focusMinutes,
    lifeMinutes,
    inboxMinutes,
    plannedMinutes,
    completedMinutes,
    computedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayScoreRow &&
          other.date == this.date &&
          other.energyScore == this.energyScore &&
          other.adherencePoints == this.adherencePoints &&
          other.focusPoints == this.focusPoints &&
          other.balancePoints == this.balancePoints &&
          other.focusMinutes == this.focusMinutes &&
          other.lifeMinutes == this.lifeMinutes &&
          other.inboxMinutes == this.inboxMinutes &&
          other.plannedMinutes == this.plannedMinutes &&
          other.completedMinutes == this.completedMinutes &&
          other.computedAt == this.computedAt);
}

class DayScoresCompanion extends UpdateCompanion<DayScoreRow> {
  final Value<DateTime> date;
  final Value<int> energyScore;
  final Value<int> adherencePoints;
  final Value<int> focusPoints;
  final Value<int> balancePoints;
  final Value<int> focusMinutes;
  final Value<int> lifeMinutes;
  final Value<int> inboxMinutes;
  final Value<int> plannedMinutes;
  final Value<int> completedMinutes;
  final Value<DateTime> computedAt;
  final Value<int> rowid;
  const DayScoresCompanion({
    this.date = const Value.absent(),
    this.energyScore = const Value.absent(),
    this.adherencePoints = const Value.absent(),
    this.focusPoints = const Value.absent(),
    this.balancePoints = const Value.absent(),
    this.focusMinutes = const Value.absent(),
    this.lifeMinutes = const Value.absent(),
    this.inboxMinutes = const Value.absent(),
    this.plannedMinutes = const Value.absent(),
    this.completedMinutes = const Value.absent(),
    this.computedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayScoresCompanion.insert({
    required DateTime date,
    required int energyScore,
    required int adherencePoints,
    required int focusPoints,
    required int balancePoints,
    this.focusMinutes = const Value.absent(),
    this.lifeMinutes = const Value.absent(),
    this.inboxMinutes = const Value.absent(),
    this.plannedMinutes = const Value.absent(),
    this.completedMinutes = const Value.absent(),
    required DateTime computedAt,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       energyScore = Value(energyScore),
       adherencePoints = Value(adherencePoints),
       focusPoints = Value(focusPoints),
       balancePoints = Value(balancePoints),
       computedAt = Value(computedAt);
  static Insertable<DayScoreRow> custom({
    Expression<DateTime>? date,
    Expression<int>? energyScore,
    Expression<int>? adherencePoints,
    Expression<int>? focusPoints,
    Expression<int>? balancePoints,
    Expression<int>? focusMinutes,
    Expression<int>? lifeMinutes,
    Expression<int>? inboxMinutes,
    Expression<int>? plannedMinutes,
    Expression<int>? completedMinutes,
    Expression<DateTime>? computedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (energyScore != null) 'energy_score': energyScore,
      if (adherencePoints != null) 'adherence_points': adherencePoints,
      if (focusPoints != null) 'focus_points': focusPoints,
      if (balancePoints != null) 'balance_points': balancePoints,
      if (focusMinutes != null) 'focus_minutes': focusMinutes,
      if (lifeMinutes != null) 'life_minutes': lifeMinutes,
      if (inboxMinutes != null) 'inbox_minutes': inboxMinutes,
      if (plannedMinutes != null) 'planned_minutes': plannedMinutes,
      if (completedMinutes != null) 'completed_minutes': completedMinutes,
      if (computedAt != null) 'computed_at': computedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayScoresCompanion copyWith({
    Value<DateTime>? date,
    Value<int>? energyScore,
    Value<int>? adherencePoints,
    Value<int>? focusPoints,
    Value<int>? balancePoints,
    Value<int>? focusMinutes,
    Value<int>? lifeMinutes,
    Value<int>? inboxMinutes,
    Value<int>? plannedMinutes,
    Value<int>? completedMinutes,
    Value<DateTime>? computedAt,
    Value<int>? rowid,
  }) {
    return DayScoresCompanion(
      date: date ?? this.date,
      energyScore: energyScore ?? this.energyScore,
      adherencePoints: adherencePoints ?? this.adherencePoints,
      focusPoints: focusPoints ?? this.focusPoints,
      balancePoints: balancePoints ?? this.balancePoints,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      lifeMinutes: lifeMinutes ?? this.lifeMinutes,
      inboxMinutes: inboxMinutes ?? this.inboxMinutes,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      completedMinutes: completedMinutes ?? this.completedMinutes,
      computedAt: computedAt ?? this.computedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (energyScore.present) {
      map['energy_score'] = Variable<int>(energyScore.value);
    }
    if (adherencePoints.present) {
      map['adherence_points'] = Variable<int>(adherencePoints.value);
    }
    if (focusPoints.present) {
      map['focus_points'] = Variable<int>(focusPoints.value);
    }
    if (balancePoints.present) {
      map['balance_points'] = Variable<int>(balancePoints.value);
    }
    if (focusMinutes.present) {
      map['focus_minutes'] = Variable<int>(focusMinutes.value);
    }
    if (lifeMinutes.present) {
      map['life_minutes'] = Variable<int>(lifeMinutes.value);
    }
    if (inboxMinutes.present) {
      map['inbox_minutes'] = Variable<int>(inboxMinutes.value);
    }
    if (plannedMinutes.present) {
      map['planned_minutes'] = Variable<int>(plannedMinutes.value);
    }
    if (completedMinutes.present) {
      map['completed_minutes'] = Variable<int>(completedMinutes.value);
    }
    if (computedAt.present) {
      map['computed_at'] = Variable<DateTime>(computedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayScoresCompanion(')
          ..write('date: $date, ')
          ..write('energyScore: $energyScore, ')
          ..write('adherencePoints: $adherencePoints, ')
          ..write('focusPoints: $focusPoints, ')
          ..write('balancePoints: $balancePoints, ')
          ..write('focusMinutes: $focusMinutes, ')
          ..write('lifeMinutes: $lifeMinutes, ')
          ..write('inboxMinutes: $inboxMinutes, ')
          ..write('plannedMinutes: $plannedMinutes, ')
          ..write('completedMinutes: $completedMinutes, ')
          ..write('computedAt: $computedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressTable extends Progress
    with TableInfo<$ProgressTable, ProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
    'xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestStreakMeta = const VerificationMeta(
    'longestStreak',
  );
  @override
  late final GeneratedColumn<int> longestStreak = GeneratedColumn<int>(
    'longest_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastStreakDateMeta = const VerificationMeta(
    'lastStreakDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastStreakDate =
      GeneratedColumn<DateTime>(
        'last_streak_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    xp,
    level,
    currentStreak,
    longestStreak,
    lastStreakDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
      );
    }
    if (data.containsKey('longest_streak')) {
      context.handle(
        _longestStreakMeta,
        longestStreak.isAcceptableOrUnknown(
          data['longest_streak']!,
          _longestStreakMeta,
        ),
      );
    }
    if (data.containsKey('last_streak_date')) {
      context.handle(
        _lastStreakDateMeta,
        lastStreakDate.isAcceptableOrUnknown(
          data['last_streak_date']!,
          _lastStreakDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      xp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      currentStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_streak'],
      )!,
      longestStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest_streak'],
      )!,
      lastStreakDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_streak_date'],
      ),
    );
  }

  @override
  $ProgressTable createAlias(String alias) {
    return $ProgressTable(attachedDatabase, alias);
  }
}

class ProgressRow extends DataClass implements Insertable<ProgressRow> {
  final int id;
  final int xp;
  final int level;
  final int currentStreak;
  final int longestStreak;

  /// The last local day this row was computed for; drives `ensureFresh()`.
  final DateTime? lastStreakDate;
  const ProgressRow({
    required this.id,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    this.lastStreakDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['xp'] = Variable<int>(xp);
    map['level'] = Variable<int>(level);
    map['current_streak'] = Variable<int>(currentStreak);
    map['longest_streak'] = Variable<int>(longestStreak);
    if (!nullToAbsent || lastStreakDate != null) {
      map['last_streak_date'] = Variable<DateTime>(lastStreakDate);
    }
    return map;
  }

  ProgressCompanion toCompanion(bool nullToAbsent) {
    return ProgressCompanion(
      id: Value(id),
      xp: Value(xp),
      level: Value(level),
      currentStreak: Value(currentStreak),
      longestStreak: Value(longestStreak),
      lastStreakDate: lastStreakDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStreakDate),
    );
  }

  factory ProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressRow(
      id: serializer.fromJson<int>(json['id']),
      xp: serializer.fromJson<int>(json['xp']),
      level: serializer.fromJson<int>(json['level']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      longestStreak: serializer.fromJson<int>(json['longestStreak']),
      lastStreakDate: serializer.fromJson<DateTime?>(json['lastStreakDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'xp': serializer.toJson<int>(xp),
      'level': serializer.toJson<int>(level),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'longestStreak': serializer.toJson<int>(longestStreak),
      'lastStreakDate': serializer.toJson<DateTime?>(lastStreakDate),
    };
  }

  ProgressRow copyWith({
    int? id,
    int? xp,
    int? level,
    int? currentStreak,
    int? longestStreak,
    Value<DateTime?> lastStreakDate = const Value.absent(),
  }) => ProgressRow(
    id: id ?? this.id,
    xp: xp ?? this.xp,
    level: level ?? this.level,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastStreakDate: lastStreakDate.present
        ? lastStreakDate.value
        : this.lastStreakDate,
  );
  ProgressRow copyWithCompanion(ProgressCompanion data) {
    return ProgressRow(
      id: data.id.present ? data.id.value : this.id,
      xp: data.xp.present ? data.xp.value : this.xp,
      level: data.level.present ? data.level.value : this.level,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      longestStreak: data.longestStreak.present
          ? data.longestStreak.value
          : this.longestStreak,
      lastStreakDate: data.lastStreakDate.present
          ? data.lastStreakDate.value
          : this.lastStreakDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRow(')
          ..write('id: $id, ')
          ..write('xp: $xp, ')
          ..write('level: $level, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('lastStreakDate: $lastStreakDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, xp, level, currentStreak, longestStreak, lastStreakDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressRow &&
          other.id == this.id &&
          other.xp == this.xp &&
          other.level == this.level &&
          other.currentStreak == this.currentStreak &&
          other.longestStreak == this.longestStreak &&
          other.lastStreakDate == this.lastStreakDate);
}

class ProgressCompanion extends UpdateCompanion<ProgressRow> {
  final Value<int> id;
  final Value<int> xp;
  final Value<int> level;
  final Value<int> currentStreak;
  final Value<int> longestStreak;
  final Value<DateTime?> lastStreakDate;
  const ProgressCompanion({
    this.id = const Value.absent(),
    this.xp = const Value.absent(),
    this.level = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.lastStreakDate = const Value.absent(),
  });
  ProgressCompanion.insert({
    this.id = const Value.absent(),
    this.xp = const Value.absent(),
    this.level = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.lastStreakDate = const Value.absent(),
  });
  static Insertable<ProgressRow> custom({
    Expression<int>? id,
    Expression<int>? xp,
    Expression<int>? level,
    Expression<int>? currentStreak,
    Expression<int>? longestStreak,
    Expression<DateTime>? lastStreakDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (xp != null) 'xp': xp,
      if (level != null) 'level': level,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (longestStreak != null) 'longest_streak': longestStreak,
      if (lastStreakDate != null) 'last_streak_date': lastStreakDate,
    });
  }

  ProgressCompanion copyWith({
    Value<int>? id,
    Value<int>? xp,
    Value<int>? level,
    Value<int>? currentStreak,
    Value<int>? longestStreak,
    Value<DateTime?>? lastStreakDate,
  }) {
    return ProgressCompanion(
      id: id ?? this.id,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (longestStreak.present) {
      map['longest_streak'] = Variable<int>(longestStreak.value);
    }
    if (lastStreakDate.present) {
      map['last_streak_date'] = Variable<DateTime>(lastStreakDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressCompanion(')
          ..write('id: $id, ')
          ..write('xp: $xp, ')
          ..write('level: $level, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('lastStreakDate: $lastStreakDate')
          ..write(')'))
        .toString();
  }
}

class $BadgeUnlocksTable extends BadgeUnlocks
    with TableInfo<$BadgeUnlocksTable, BadgeUnlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BadgeUnlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _badgeIdMeta = const VerificationMeta(
    'badgeId',
  );
  @override
  late final GeneratedColumn<String> badgeId = GeneratedColumn<String>(
    'badge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedAtMeta = const VerificationMeta(
    'unlockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
    'unlocked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [badgeId, unlockedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'badge_unlocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BadgeUnlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('badge_id')) {
      context.handle(
        _badgeIdMeta,
        badgeId.isAcceptableOrUnknown(data['badge_id']!, _badgeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_badgeIdMeta);
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
        _unlockedAtMeta,
        unlockedAt.isAcceptableOrUnknown(data['unlocked_at']!, _unlockedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {badgeId};
  @override
  BadgeUnlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BadgeUnlockRow(
      badgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}badge_id'],
      )!,
      unlockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}unlocked_at'],
      )!,
    );
  }

  @override
  $BadgeUnlocksTable createAlias(String alias) {
    return $BadgeUnlocksTable(attachedDatabase, alias);
  }
}

class BadgeUnlockRow extends DataClass implements Insertable<BadgeUnlockRow> {
  final String badgeId;
  final DateTime unlockedAt;
  const BadgeUnlockRow({required this.badgeId, required this.unlockedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['badge_id'] = Variable<String>(badgeId);
    map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    return map;
  }

  BadgeUnlocksCompanion toCompanion(bool nullToAbsent) {
    return BadgeUnlocksCompanion(
      badgeId: Value(badgeId),
      unlockedAt: Value(unlockedAt),
    );
  }

  factory BadgeUnlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BadgeUnlockRow(
      badgeId: serializer.fromJson<String>(json['badgeId']),
      unlockedAt: serializer.fromJson<DateTime>(json['unlockedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'badgeId': serializer.toJson<String>(badgeId),
      'unlockedAt': serializer.toJson<DateTime>(unlockedAt),
    };
  }

  BadgeUnlockRow copyWith({String? badgeId, DateTime? unlockedAt}) =>
      BadgeUnlockRow(
        badgeId: badgeId ?? this.badgeId,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
  BadgeUnlockRow copyWithCompanion(BadgeUnlocksCompanion data) {
    return BadgeUnlockRow(
      badgeId: data.badgeId.present ? data.badgeId.value : this.badgeId,
      unlockedAt: data.unlockedAt.present
          ? data.unlockedAt.value
          : this.unlockedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BadgeUnlockRow(')
          ..write('badgeId: $badgeId, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(badgeId, unlockedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BadgeUnlockRow &&
          other.badgeId == this.badgeId &&
          other.unlockedAt == this.unlockedAt);
}

class BadgeUnlocksCompanion extends UpdateCompanion<BadgeUnlockRow> {
  final Value<String> badgeId;
  final Value<DateTime> unlockedAt;
  final Value<int> rowid;
  const BadgeUnlocksCompanion({
    this.badgeId = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BadgeUnlocksCompanion.insert({
    required String badgeId,
    required DateTime unlockedAt,
    this.rowid = const Value.absent(),
  }) : badgeId = Value(badgeId),
       unlockedAt = Value(unlockedAt);
  static Insertable<BadgeUnlockRow> custom({
    Expression<String>? badgeId,
    Expression<DateTime>? unlockedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (badgeId != null) 'badge_id': badgeId,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BadgeUnlocksCompanion copyWith({
    Value<String>? badgeId,
    Value<DateTime>? unlockedAt,
    Value<int>? rowid,
  }) {
    return BadgeUnlocksCompanion(
      badgeId: badgeId ?? this.badgeId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (badgeId.present) {
      map['badge_id'] = Variable<String>(badgeId.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BadgeUnlocksCompanion(')
          ..write('badgeId: $badgeId, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyRoundupsTable extends WeeklyRoundups
    with TableInfo<$WeeklyRoundupsTable, WeeklyRoundupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyRoundupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isoYearMeta = const VerificationMeta(
    'isoYear',
  );
  @override
  late final GeneratedColumn<int> isoYear = GeneratedColumn<int>(
    'iso_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isoWeekMeta = const VerificationMeta(
    'isoWeek',
  );
  @override
  late final GeneratedColumn<int> isoWeek = GeneratedColumn<int>(
    'iso_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    isoYear,
    isoWeek,
    generatedAt,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_roundups';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyRoundupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('iso_year')) {
      context.handle(
        _isoYearMeta,
        isoYear.isAcceptableOrUnknown(data['iso_year']!, _isoYearMeta),
      );
    } else if (isInserting) {
      context.missing(_isoYearMeta);
    }
    if (data.containsKey('iso_week')) {
      context.handle(
        _isoWeekMeta,
        isoWeek.isAcceptableOrUnknown(data['iso_week']!, _isoWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_isoWeekMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isoYear, isoWeek};
  @override
  WeeklyRoundupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyRoundupRow(
      isoYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iso_year'],
      )!,
      isoWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iso_week'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
    );
  }

  @override
  $WeeklyRoundupsTable createAlias(String alias) {
    return $WeeklyRoundupsTable(attachedDatabase, alias);
  }
}

class WeeklyRoundupRow extends DataClass
    implements Insertable<WeeklyRoundupRow> {
  final int isoYear;
  final int isoWeek;
  final DateTime generatedAt;
  final String payloadJson;
  const WeeklyRoundupRow({
    required this.isoYear,
    required this.isoWeek,
    required this.generatedAt,
    required this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['iso_year'] = Variable<int>(isoYear);
    map['iso_week'] = Variable<int>(isoWeek);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    map['payload_json'] = Variable<String>(payloadJson);
    return map;
  }

  WeeklyRoundupsCompanion toCompanion(bool nullToAbsent) {
    return WeeklyRoundupsCompanion(
      isoYear: Value(isoYear),
      isoWeek: Value(isoWeek),
      generatedAt: Value(generatedAt),
      payloadJson: Value(payloadJson),
    );
  }

  factory WeeklyRoundupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyRoundupRow(
      isoYear: serializer.fromJson<int>(json['isoYear']),
      isoWeek: serializer.fromJson<int>(json['isoWeek']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isoYear': serializer.toJson<int>(isoYear),
      'isoWeek': serializer.toJson<int>(isoWeek),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'payloadJson': serializer.toJson<String>(payloadJson),
    };
  }

  WeeklyRoundupRow copyWith({
    int? isoYear,
    int? isoWeek,
    DateTime? generatedAt,
    String? payloadJson,
  }) => WeeklyRoundupRow(
    isoYear: isoYear ?? this.isoYear,
    isoWeek: isoWeek ?? this.isoWeek,
    generatedAt: generatedAt ?? this.generatedAt,
    payloadJson: payloadJson ?? this.payloadJson,
  );
  WeeklyRoundupRow copyWithCompanion(WeeklyRoundupsCompanion data) {
    return WeeklyRoundupRow(
      isoYear: data.isoYear.present ? data.isoYear.value : this.isoYear,
      isoWeek: data.isoWeek.present ? data.isoWeek.value : this.isoWeek,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyRoundupRow(')
          ..write('isoYear: $isoYear, ')
          ..write('isoWeek: $isoWeek, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(isoYear, isoWeek, generatedAt, payloadJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyRoundupRow &&
          other.isoYear == this.isoYear &&
          other.isoWeek == this.isoWeek &&
          other.generatedAt == this.generatedAt &&
          other.payloadJson == this.payloadJson);
}

class WeeklyRoundupsCompanion extends UpdateCompanion<WeeklyRoundupRow> {
  final Value<int> isoYear;
  final Value<int> isoWeek;
  final Value<DateTime> generatedAt;
  final Value<String> payloadJson;
  final Value<int> rowid;
  const WeeklyRoundupsCompanion({
    this.isoYear = const Value.absent(),
    this.isoWeek = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyRoundupsCompanion.insert({
    required int isoYear,
    required int isoWeek,
    required DateTime generatedAt,
    required String payloadJson,
    this.rowid = const Value.absent(),
  }) : isoYear = Value(isoYear),
       isoWeek = Value(isoWeek),
       generatedAt = Value(generatedAt),
       payloadJson = Value(payloadJson);
  static Insertable<WeeklyRoundupRow> custom({
    Expression<int>? isoYear,
    Expression<int>? isoWeek,
    Expression<DateTime>? generatedAt,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (isoYear != null) 'iso_year': isoYear,
      if (isoWeek != null) 'iso_week': isoWeek,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyRoundupsCompanion copyWith({
    Value<int>? isoYear,
    Value<int>? isoWeek,
    Value<DateTime>? generatedAt,
    Value<String>? payloadJson,
    Value<int>? rowid,
  }) {
    return WeeklyRoundupsCompanion(
      isoYear: isoYear ?? this.isoYear,
      isoWeek: isoWeek ?? this.isoWeek,
      generatedAt: generatedAt ?? this.generatedAt,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isoYear.present) {
      map['iso_year'] = Variable<int>(isoYear.value);
    }
    if (isoWeek.present) {
      map['iso_week'] = Variable<int>(isoWeek.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyRoundupsCompanion(')
          ..write('isoYear: $isoYear, ')
          ..write('isoWeek: $isoWeek, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects
    with TableInfo<$ProjectsTable, ProjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
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
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<DateTime> deadline = GeneratedColumn<DateTime>(
    'deadline',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetMinutesMeta = const VerificationMeta(
    'targetMinutes',
  );
  @override
  late final GeneratedColumn<int> targetMinutes = GeneratedColumn<int>(
    'target_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toneIndexMeta = const VerificationMeta(
    'toneIndex',
  );
  @override
  late final GeneratedColumn<int> toneIndex = GeneratedColumn<int>(
    'tone_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    deadline,
    targetMinutes,
    toneIndex,
    status,
    completedAt,
    notes,
    priority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    }
    if (data.containsKey('target_minutes')) {
      context.handle(
        _targetMinutesMeta,
        targetMinutes.isAcceptableOrUnknown(
          data['target_minutes']!,
          _targetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('tone_index')) {
      context.handle(
        _toneIndexMeta,
        toneIndex.isAcceptableOrUnknown(data['tone_index']!, _toneIndexMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deadline'],
      ),
      targetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_minutes'],
      ),
      toneIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tone_index'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class ProjectRow extends DataClass implements Insertable<ProjectRow> {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime? deadline;
  final int? targetMinutes;
  final int? toneIndex;
  final int status;
  final DateTime? completedAt;
  final String? notes;
  final int priority;
  const ProjectRow({
    required this.id,
    required this.title,
    required this.createdAt,
    this.deadline,
    this.targetMinutes,
    this.toneIndex,
    required this.status,
    this.completedAt,
    this.notes,
    required this.priority,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deadline != null) {
      map['deadline'] = Variable<DateTime>(deadline);
    }
    if (!nullToAbsent || targetMinutes != null) {
      map['target_minutes'] = Variable<int>(targetMinutes);
    }
    if (!nullToAbsent || toneIndex != null) {
      map['tone_index'] = Variable<int>(toneIndex);
    }
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['priority'] = Variable<int>(priority);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      deadline: deadline == null && nullToAbsent
          ? const Value.absent()
          : Value(deadline),
      targetMinutes: targetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(targetMinutes),
      toneIndex: toneIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(toneIndex),
      status: Value(status),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      priority: Value(priority),
    );
  }

  factory ProjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deadline: serializer.fromJson<DateTime?>(json['deadline']),
      targetMinutes: serializer.fromJson<int?>(json['targetMinutes']),
      toneIndex: serializer.fromJson<int?>(json['toneIndex']),
      status: serializer.fromJson<int>(json['status']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      priority: serializer.fromJson<int>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deadline': serializer.toJson<DateTime?>(deadline),
      'targetMinutes': serializer.toJson<int?>(targetMinutes),
      'toneIndex': serializer.toJson<int?>(toneIndex),
      'status': serializer.toJson<int>(status),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'notes': serializer.toJson<String?>(notes),
      'priority': serializer.toJson<int>(priority),
    };
  }

  ProjectRow copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    Value<DateTime?> deadline = const Value.absent(),
    Value<int?> targetMinutes = const Value.absent(),
    Value<int?> toneIndex = const Value.absent(),
    int? status,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    int? priority,
  }) => ProjectRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    deadline: deadline.present ? deadline.value : this.deadline,
    targetMinutes: targetMinutes.present
        ? targetMinutes.value
        : this.targetMinutes,
    toneIndex: toneIndex.present ? toneIndex.value : this.toneIndex,
    status: status ?? this.status,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    notes: notes.present ? notes.value : this.notes,
    priority: priority ?? this.priority,
  );
  ProjectRow copyWithCompanion(ProjectsCompanion data) {
    return ProjectRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      targetMinutes: data.targetMinutes.present
          ? data.targetMinutes.value
          : this.targetMinutes,
      toneIndex: data.toneIndex.present ? data.toneIndex.value : this.toneIndex,
      status: data.status.present ? data.status.value : this.status,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('deadline: $deadline, ')
          ..write('targetMinutes: $targetMinutes, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('notes: $notes, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    deadline,
    targetMinutes,
    toneIndex,
    status,
    completedAt,
    notes,
    priority,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.deadline == this.deadline &&
          other.targetMinutes == this.targetMinutes &&
          other.toneIndex == this.toneIndex &&
          other.status == this.status &&
          other.completedAt == this.completedAt &&
          other.notes == this.notes &&
          other.priority == this.priority);
}

class ProjectsCompanion extends UpdateCompanion<ProjectRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deadline;
  final Value<int?> targetMinutes;
  final Value<int?> toneIndex;
  final Value<int> status;
  final Value<DateTime?> completedAt;
  final Value<String?> notes;
  final Value<int> priority;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deadline = const Value.absent(),
    this.targetMinutes = const Value.absent(),
    this.toneIndex = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.priority = const Value.absent(),
  });
  ProjectsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime createdAt,
    this.deadline = const Value.absent(),
    this.targetMinutes = const Value.absent(),
    this.toneIndex = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.priority = const Value.absent(),
  }) : title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<ProjectRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deadline,
    Expression<int>? targetMinutes,
    Expression<int>? toneIndex,
    Expression<int>? status,
    Expression<DateTime>? completedAt,
    Expression<String>? notes,
    Expression<int>? priority,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (deadline != null) 'deadline': deadline,
      if (targetMinutes != null) 'target_minutes': targetMinutes,
      if (toneIndex != null) 'tone_index': toneIndex,
      if (status != null) 'status': status,
      if (completedAt != null) 'completed_at': completedAt,
      if (notes != null) 'notes': notes,
      if (priority != null) 'priority': priority,
    });
  }

  ProjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deadline,
    Value<int?>? targetMinutes,
    Value<int?>? toneIndex,
    Value<int>? status,
    Value<DateTime?>? completedAt,
    Value<String?>? notes,
    Value<int>? priority,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      toneIndex: toneIndex ?? this.toneIndex,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<DateTime>(deadline.value);
    }
    if (targetMinutes.present) {
      map['target_minutes'] = Variable<int>(targetMinutes.value);
    }
    if (toneIndex.present) {
      map['tone_index'] = Variable<int>(toneIndex.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('deadline: $deadline, ')
          ..write('targetMinutes: $targetMinutes, ')
          ..write('toneIndex: $toneIndex, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('notes: $notes, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boardStatusMeta = const VerificationMeta(
    'boardStatus',
  );
  @override
  late final GeneratedColumn<int> boardStatus = GeneratedColumn<int>(
    'board_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _estimateMinutesMeta = const VerificationMeta(
    'estimateMinutes',
  );
  @override
  late final GeneratedColumn<int> estimateMinutes = GeneratedColumn<int>(
    'estimate_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedDateMeta = const VerificationMeta(
    'plannedDate',
  );
  @override
  late final GeneratedColumn<DateTime> plannedDate = GeneratedColumn<DateTime>(
    'planned_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockedReasonMeta = const VerificationMeta(
    'blockedReason',
  );
  @override
  late final GeneratedColumn<String> blockedReason = GeneratedColumn<String>(
    'blocked_reason',
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
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    title,
    notes,
    boardStatus,
    priority,
    estimateMinutes,
    dueDate,
    plannedDate,
    sortOrder,
    blockedReason,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('board_status')) {
      context.handle(
        _boardStatusMeta,
        boardStatus.isAcceptableOrUnknown(
          data['board_status']!,
          _boardStatusMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('estimate_minutes')) {
      context.handle(
        _estimateMinutesMeta,
        estimateMinutes.isAcceptableOrUnknown(
          data['estimate_minutes']!,
          _estimateMinutesMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('planned_date')) {
      context.handle(
        _plannedDateMeta,
        plannedDate.isAcceptableOrUnknown(
          data['planned_date']!,
          _plannedDateMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('blocked_reason')) {
      context.handle(
        _blockedReasonMeta,
        blockedReason.isAcceptableOrUnknown(
          data['blocked_reason']!,
          _blockedReasonMeta,
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      boardStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}board_status'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      estimateMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimate_minutes'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      plannedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}planned_date'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      blockedReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blocked_reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final int id;
  final int projectId;
  final String title;
  final String? notes;
  final int boardStatus;
  final int priority;
  final int? estimateMinutes;
  final DateTime? dueDate;
  final DateTime? plannedDate;
  final int sortOrder;
  final String? blockedReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const TaskRow({
    required this.id,
    required this.projectId,
    required this.title,
    this.notes,
    required this.boardStatus,
    required this.priority,
    this.estimateMinutes,
    this.dueDate,
    this.plannedDate,
    required this.sortOrder,
    this.blockedReason,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['board_status'] = Variable<int>(boardStatus);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || estimateMinutes != null) {
      map['estimate_minutes'] = Variable<int>(estimateMinutes);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || plannedDate != null) {
      map['planned_date'] = Variable<DateTime>(plannedDate);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || blockedReason != null) {
      map['blocked_reason'] = Variable<String>(blockedReason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      boardStatus: Value(boardStatus),
      priority: Value(priority),
      estimateMinutes: estimateMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(estimateMinutes),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      plannedDate: plannedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedDate),
      sortOrder: Value(sortOrder),
      blockedReason: blockedReason == null && nullToAbsent
          ? const Value.absent()
          : Value(blockedReason),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      boardStatus: serializer.fromJson<int>(json['boardStatus']),
      priority: serializer.fromJson<int>(json['priority']),
      estimateMinutes: serializer.fromJson<int?>(json['estimateMinutes']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      plannedDate: serializer.fromJson<DateTime?>(json['plannedDate']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      blockedReason: serializer.fromJson<String?>(json['blockedReason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'boardStatus': serializer.toJson<int>(boardStatus),
      'priority': serializer.toJson<int>(priority),
      'estimateMinutes': serializer.toJson<int?>(estimateMinutes),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'plannedDate': serializer.toJson<DateTime?>(plannedDate),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'blockedReason': serializer.toJson<String?>(blockedReason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  TaskRow copyWith({
    int? id,
    int? projectId,
    String? title,
    Value<String?> notes = const Value.absent(),
    int? boardStatus,
    int? priority,
    Value<int?> estimateMinutes = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    Value<DateTime?> plannedDate = const Value.absent(),
    int? sortOrder,
    Value<String?> blockedReason = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => TaskRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    boardStatus: boardStatus ?? this.boardStatus,
    priority: priority ?? this.priority,
    estimateMinutes: estimateMinutes.present
        ? estimateMinutes.value
        : this.estimateMinutes,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    plannedDate: plannedDate.present ? plannedDate.value : this.plannedDate,
    sortOrder: sortOrder ?? this.sortOrder,
    blockedReason: blockedReason.present
        ? blockedReason.value
        : this.blockedReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      boardStatus: data.boardStatus.present
          ? data.boardStatus.value
          : this.boardStatus,
      priority: data.priority.present ? data.priority.value : this.priority,
      estimateMinutes: data.estimateMinutes.present
          ? data.estimateMinutes.value
          : this.estimateMinutes,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      plannedDate: data.plannedDate.present
          ? data.plannedDate.value
          : this.plannedDate,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      blockedReason: data.blockedReason.present
          ? data.blockedReason.value
          : this.blockedReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('boardStatus: $boardStatus, ')
          ..write('priority: $priority, ')
          ..write('estimateMinutes: $estimateMinutes, ')
          ..write('dueDate: $dueDate, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('blockedReason: $blockedReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    notes,
    boardStatus,
    priority,
    estimateMinutes,
    dueDate,
    plannedDate,
    sortOrder,
    blockedReason,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.boardStatus == this.boardStatus &&
          other.priority == this.priority &&
          other.estimateMinutes == this.estimateMinutes &&
          other.dueDate == this.dueDate &&
          other.plannedDate == this.plannedDate &&
          other.sortOrder == this.sortOrder &&
          other.blockedReason == this.blockedReason &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> title;
  final Value<String?> notes;
  final Value<int> boardStatus;
  final Value<int> priority;
  final Value<int?> estimateMinutes;
  final Value<DateTime?> dueDate;
  final Value<DateTime?> plannedDate;
  final Value<int> sortOrder;
  final Value<String?> blockedReason;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.boardStatus = const Value.absent(),
    this.priority = const Value.absent(),
    this.estimateMinutes = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.blockedReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String title,
    this.notes = const Value.absent(),
    this.boardStatus = const Value.absent(),
    this.priority = const Value.absent(),
    this.estimateMinutes = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.plannedDate = const Value.absent(),
    required int sortOrder,
    this.blockedReason = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
  }) : projectId = Value(projectId),
       title = Value(title),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRow> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? boardStatus,
    Expression<int>? priority,
    Expression<int>? estimateMinutes,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? plannedDate,
    Expression<int>? sortOrder,
    Expression<String>? blockedReason,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (boardStatus != null) 'board_status': boardStatus,
      if (priority != null) 'priority': priority,
      if (estimateMinutes != null) 'estimate_minutes': estimateMinutes,
      if (dueDate != null) 'due_date': dueDate,
      if (plannedDate != null) 'planned_date': plannedDate,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (blockedReason != null) 'blocked_reason': blockedReason,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? title,
    Value<String?>? notes,
    Value<int>? boardStatus,
    Value<int>? priority,
    Value<int?>? estimateMinutes,
    Value<DateTime?>? dueDate,
    Value<DateTime?>? plannedDate,
    Value<int>? sortOrder,
    Value<String?>? blockedReason,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      boardStatus: boardStatus ?? this.boardStatus,
      priority: priority ?? this.priority,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      dueDate: dueDate ?? this.dueDate,
      plannedDate: plannedDate ?? this.plannedDate,
      sortOrder: sortOrder ?? this.sortOrder,
      blockedReason: blockedReason ?? this.blockedReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (boardStatus.present) {
      map['board_status'] = Variable<int>(boardStatus.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (estimateMinutes.present) {
      map['estimate_minutes'] = Variable<int>(estimateMinutes.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (plannedDate.present) {
      map['planned_date'] = Variable<DateTime>(plannedDate.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (blockedReason.present) {
      map['blocked_reason'] = Variable<String>(blockedReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('boardStatus: $boardStatus, ')
          ..write('priority: $priority, ')
          ..write('estimateMinutes: $estimateMinutes, ')
          ..write('dueDate: $dueDate, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('blockedReason: $blockedReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $CoachIntentsTable extends CoachIntents
    with TableInfo<$CoachIntentsTable, CoachIntentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoachIntentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focusGoalMeta = const VerificationMeta(
    'focusGoal',
  );
  @override
  late final GeneratedColumn<String> focusGoal = GeneratedColumn<String>(
    'focus_goal',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topEventIdsMeta = const VerificationMeta(
    'topEventIds',
  );
  @override
  late final GeneratedColumn<String> topEventIds = GeneratedColumn<String>(
    'top_event_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _predictedEnergyMeta = const VerificationMeta(
    'predictedEnergy',
  );
  @override
  late final GeneratedColumn<int> predictedEnergy = GeneratedColumn<int>(
    'predicted_energy',
    aliasedName,
    true,
    check: () => ComparableExpr(predictedEnergy).isBetweenValues(1, 5),
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    date,
    focusGoal,
    topEventIds,
    predictedEnergy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coach_intents';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoachIntentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('focus_goal')) {
      context.handle(
        _focusGoalMeta,
        focusGoal.isAcceptableOrUnknown(data['focus_goal']!, _focusGoalMeta),
      );
    } else if (isInserting) {
      context.missing(_focusGoalMeta);
    }
    if (data.containsKey('top_event_ids')) {
      context.handle(
        _topEventIdsMeta,
        topEventIds.isAcceptableOrUnknown(
          data['top_event_ids']!,
          _topEventIdsMeta,
        ),
      );
    }
    if (data.containsKey('predicted_energy')) {
      context.handle(
        _predictedEnergyMeta,
        predictedEnergy.isAcceptableOrUnknown(
          data['predicted_energy']!,
          _predictedEnergyMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  CoachIntentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoachIntentRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      focusGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}focus_goal'],
      )!,
      topEventIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}top_event_ids'],
      ),
      predictedEnergy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}predicted_energy'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CoachIntentsTable createAlias(String alias) {
    return $CoachIntentsTable(attachedDatabase, alias);
  }
}

class CoachIntentRow extends DataClass implements Insertable<CoachIntentRow> {
  final DateTime date;
  final String focusGoal;
  final String? topEventIds;
  final int? predictedEnergy;
  final DateTime createdAt;
  const CoachIntentRow({
    required this.date,
    required this.focusGoal,
    this.topEventIds,
    this.predictedEnergy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['focus_goal'] = Variable<String>(focusGoal);
    if (!nullToAbsent || topEventIds != null) {
      map['top_event_ids'] = Variable<String>(topEventIds);
    }
    if (!nullToAbsent || predictedEnergy != null) {
      map['predicted_energy'] = Variable<int>(predictedEnergy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CoachIntentsCompanion toCompanion(bool nullToAbsent) {
    return CoachIntentsCompanion(
      date: Value(date),
      focusGoal: Value(focusGoal),
      topEventIds: topEventIds == null && nullToAbsent
          ? const Value.absent()
          : Value(topEventIds),
      predictedEnergy: predictedEnergy == null && nullToAbsent
          ? const Value.absent()
          : Value(predictedEnergy),
      createdAt: Value(createdAt),
    );
  }

  factory CoachIntentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoachIntentRow(
      date: serializer.fromJson<DateTime>(json['date']),
      focusGoal: serializer.fromJson<String>(json['focusGoal']),
      topEventIds: serializer.fromJson<String?>(json['topEventIds']),
      predictedEnergy: serializer.fromJson<int?>(json['predictedEnergy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'focusGoal': serializer.toJson<String>(focusGoal),
      'topEventIds': serializer.toJson<String?>(topEventIds),
      'predictedEnergy': serializer.toJson<int?>(predictedEnergy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CoachIntentRow copyWith({
    DateTime? date,
    String? focusGoal,
    Value<String?> topEventIds = const Value.absent(),
    Value<int?> predictedEnergy = const Value.absent(),
    DateTime? createdAt,
  }) => CoachIntentRow(
    date: date ?? this.date,
    focusGoal: focusGoal ?? this.focusGoal,
    topEventIds: topEventIds.present ? topEventIds.value : this.topEventIds,
    predictedEnergy: predictedEnergy.present
        ? predictedEnergy.value
        : this.predictedEnergy,
    createdAt: createdAt ?? this.createdAt,
  );
  CoachIntentRow copyWithCompanion(CoachIntentsCompanion data) {
    return CoachIntentRow(
      date: data.date.present ? data.date.value : this.date,
      focusGoal: data.focusGoal.present ? data.focusGoal.value : this.focusGoal,
      topEventIds: data.topEventIds.present
          ? data.topEventIds.value
          : this.topEventIds,
      predictedEnergy: data.predictedEnergy.present
          ? data.predictedEnergy.value
          : this.predictedEnergy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoachIntentRow(')
          ..write('date: $date, ')
          ..write('focusGoal: $focusGoal, ')
          ..write('topEventIds: $topEventIds, ')
          ..write('predictedEnergy: $predictedEnergy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(date, focusGoal, topEventIds, predictedEnergy, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoachIntentRow &&
          other.date == this.date &&
          other.focusGoal == this.focusGoal &&
          other.topEventIds == this.topEventIds &&
          other.predictedEnergy == this.predictedEnergy &&
          other.createdAt == this.createdAt);
}

class CoachIntentsCompanion extends UpdateCompanion<CoachIntentRow> {
  final Value<DateTime> date;
  final Value<String> focusGoal;
  final Value<String?> topEventIds;
  final Value<int?> predictedEnergy;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CoachIntentsCompanion({
    this.date = const Value.absent(),
    this.focusGoal = const Value.absent(),
    this.topEventIds = const Value.absent(),
    this.predictedEnergy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoachIntentsCompanion.insert({
    required DateTime date,
    required String focusGoal,
    this.topEventIds = const Value.absent(),
    this.predictedEnergy = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       focusGoal = Value(focusGoal),
       createdAt = Value(createdAt);
  static Insertable<CoachIntentRow> custom({
    Expression<DateTime>? date,
    Expression<String>? focusGoal,
    Expression<String>? topEventIds,
    Expression<int>? predictedEnergy,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (focusGoal != null) 'focus_goal': focusGoal,
      if (topEventIds != null) 'top_event_ids': topEventIds,
      if (predictedEnergy != null) 'predicted_energy': predictedEnergy,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoachIntentsCompanion copyWith({
    Value<DateTime>? date,
    Value<String>? focusGoal,
    Value<String?>? topEventIds,
    Value<int?>? predictedEnergy,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CoachIntentsCompanion(
      date: date ?? this.date,
      focusGoal: focusGoal ?? this.focusGoal,
      topEventIds: topEventIds ?? this.topEventIds,
      predictedEnergy: predictedEnergy ?? this.predictedEnergy,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (focusGoal.present) {
      map['focus_goal'] = Variable<String>(focusGoal.value);
    }
    if (topEventIds.present) {
      map['top_event_ids'] = Variable<String>(topEventIds.value);
    }
    if (predictedEnergy.present) {
      map['predicted_energy'] = Variable<int>(predictedEnergy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoachIntentsCompanion(')
          ..write('date: $date, ')
          ..write('focusGoal: $focusGoal, ')
          ..write('topEventIds: $topEventIds, ')
          ..write('predictedEnergy: $predictedEnergy, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoachReviewsTable extends CoachReviews
    with TableInfo<$CoachReviewsTable, CoachReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoachReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<int> energy = GeneratedColumn<int>(
    'energy',
    aliasedName,
    false,
    check: () => ComparableExpr(energy).isBetweenValues(1, 5),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _winTextMeta = const VerificationMeta(
    'winText',
  );
  @override
  late final GeneratedColumn<String> winText = GeneratedColumn<String>(
    'win_text',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 140),
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
  @override
  List<GeneratedColumn> get $columns => [date, energy, winText, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coach_reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoachReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('energy')) {
      context.handle(
        _energyMeta,
        energy.isAcceptableOrUnknown(data['energy']!, _energyMeta),
      );
    } else if (isInserting) {
      context.missing(_energyMeta);
    }
    if (data.containsKey('win_text')) {
      context.handle(
        _winTextMeta,
        winText.isAcceptableOrUnknown(data['win_text']!, _winTextMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  CoachReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoachReviewRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      energy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy'],
      )!,
      winText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}win_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CoachReviewsTable createAlias(String alias) {
    return $CoachReviewsTable(attachedDatabase, alias);
  }
}

class CoachReviewRow extends DataClass implements Insertable<CoachReviewRow> {
  final DateTime date;
  final int energy;
  final String? winText;
  final DateTime createdAt;
  const CoachReviewRow({
    required this.date,
    required this.energy,
    this.winText,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['energy'] = Variable<int>(energy);
    if (!nullToAbsent || winText != null) {
      map['win_text'] = Variable<String>(winText);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CoachReviewsCompanion toCompanion(bool nullToAbsent) {
    return CoachReviewsCompanion(
      date: Value(date),
      energy: Value(energy),
      winText: winText == null && nullToAbsent
          ? const Value.absent()
          : Value(winText),
      createdAt: Value(createdAt),
    );
  }

  factory CoachReviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoachReviewRow(
      date: serializer.fromJson<DateTime>(json['date']),
      energy: serializer.fromJson<int>(json['energy']),
      winText: serializer.fromJson<String?>(json['winText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'energy': serializer.toJson<int>(energy),
      'winText': serializer.toJson<String?>(winText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CoachReviewRow copyWith({
    DateTime? date,
    int? energy,
    Value<String?> winText = const Value.absent(),
    DateTime? createdAt,
  }) => CoachReviewRow(
    date: date ?? this.date,
    energy: energy ?? this.energy,
    winText: winText.present ? winText.value : this.winText,
    createdAt: createdAt ?? this.createdAt,
  );
  CoachReviewRow copyWithCompanion(CoachReviewsCompanion data) {
    return CoachReviewRow(
      date: data.date.present ? data.date.value : this.date,
      energy: data.energy.present ? data.energy.value : this.energy,
      winText: data.winText.present ? data.winText.value : this.winText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoachReviewRow(')
          ..write('date: $date, ')
          ..write('energy: $energy, ')
          ..write('winText: $winText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, energy, winText, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoachReviewRow &&
          other.date == this.date &&
          other.energy == this.energy &&
          other.winText == this.winText &&
          other.createdAt == this.createdAt);
}

class CoachReviewsCompanion extends UpdateCompanion<CoachReviewRow> {
  final Value<DateTime> date;
  final Value<int> energy;
  final Value<String?> winText;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CoachReviewsCompanion({
    this.date = const Value.absent(),
    this.energy = const Value.absent(),
    this.winText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoachReviewsCompanion.insert({
    required DateTime date,
    required int energy,
    this.winText = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       energy = Value(energy),
       createdAt = Value(createdAt);
  static Insertable<CoachReviewRow> custom({
    Expression<DateTime>? date,
    Expression<int>? energy,
    Expression<String>? winText,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (energy != null) 'energy': energy,
      if (winText != null) 'win_text': winText,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoachReviewsCompanion copyWith({
    Value<DateTime>? date,
    Value<int>? energy,
    Value<String?>? winText,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CoachReviewsCompanion(
      date: date ?? this.date,
      energy: energy ?? this.energy,
      winText: winText ?? this.winText,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (energy.present) {
      map['energy'] = Variable<int>(energy.value);
    }
    if (winText.present) {
      map['win_text'] = Variable<String>(winText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoachReviewsCompanion(')
          ..write('date: $date, ')
          ..write('energy: $energy, ')
          ..write('winText: $winText, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoachInsightsTable extends CoachInsights
    with TableInfo<$CoachInsightsTable, CoachInsightRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoachInsightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isoYearMeta = const VerificationMeta(
    'isoYear',
  );
  @override
  late final GeneratedColumn<int> isoYear = GeneratedColumn<int>(
    'iso_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isoWeekMeta = const VerificationMeta(
    'isoWeek',
  );
  @override
  late final GeneratedColumn<int> isoWeek = GeneratedColumn<int>(
    'iso_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    isoYear,
    isoWeek,
    kind,
    payloadJson,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coach_insights';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoachInsightRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('iso_year')) {
      context.handle(
        _isoYearMeta,
        isoYear.isAcceptableOrUnknown(data['iso_year']!, _isoYearMeta),
      );
    } else if (isInserting) {
      context.missing(_isoYearMeta);
    }
    if (data.containsKey('iso_week')) {
      context.handle(
        _isoWeekMeta,
        isoWeek.isAcceptableOrUnknown(data['iso_week']!, _isoWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_isoWeekMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isoYear, isoWeek, kind};
  @override
  CoachInsightRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoachInsightRow(
      isoYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iso_year'],
      )!,
      isoWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iso_week'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
    );
  }

  @override
  $CoachInsightsTable createAlias(String alias) {
    return $CoachInsightsTable(attachedDatabase, alias);
  }
}

class CoachInsightRow extends DataClass implements Insertable<CoachInsightRow> {
  final int isoYear;
  final int isoWeek;
  final String kind;
  final String payloadJson;
  final DateTime generatedAt;
  const CoachInsightRow({
    required this.isoYear,
    required this.isoWeek,
    required this.kind,
    required this.payloadJson,
    required this.generatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['iso_year'] = Variable<int>(isoYear);
    map['iso_week'] = Variable<int>(isoWeek);
    map['kind'] = Variable<String>(kind);
    map['payload_json'] = Variable<String>(payloadJson);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    return map;
  }

  CoachInsightsCompanion toCompanion(bool nullToAbsent) {
    return CoachInsightsCompanion(
      isoYear: Value(isoYear),
      isoWeek: Value(isoWeek),
      kind: Value(kind),
      payloadJson: Value(payloadJson),
      generatedAt: Value(generatedAt),
    );
  }

  factory CoachInsightRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoachInsightRow(
      isoYear: serializer.fromJson<int>(json['isoYear']),
      isoWeek: serializer.fromJson<int>(json['isoWeek']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isoYear': serializer.toJson<int>(isoYear),
      'isoWeek': serializer.toJson<int>(isoWeek),
      'kind': serializer.toJson<String>(kind),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
    };
  }

  CoachInsightRow copyWith({
    int? isoYear,
    int? isoWeek,
    String? kind,
    String? payloadJson,
    DateTime? generatedAt,
  }) => CoachInsightRow(
    isoYear: isoYear ?? this.isoYear,
    isoWeek: isoWeek ?? this.isoWeek,
    kind: kind ?? this.kind,
    payloadJson: payloadJson ?? this.payloadJson,
    generatedAt: generatedAt ?? this.generatedAt,
  );
  CoachInsightRow copyWithCompanion(CoachInsightsCompanion data) {
    return CoachInsightRow(
      isoYear: data.isoYear.present ? data.isoYear.value : this.isoYear,
      isoWeek: data.isoWeek.present ? data.isoWeek.value : this.isoWeek,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoachInsightRow(')
          ..write('isoYear: $isoYear, ')
          ..write('isoWeek: $isoWeek, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('generatedAt: $generatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(isoYear, isoWeek, kind, payloadJson, generatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoachInsightRow &&
          other.isoYear == this.isoYear &&
          other.isoWeek == this.isoWeek &&
          other.kind == this.kind &&
          other.payloadJson == this.payloadJson &&
          other.generatedAt == this.generatedAt);
}

class CoachInsightsCompanion extends UpdateCompanion<CoachInsightRow> {
  final Value<int> isoYear;
  final Value<int> isoWeek;
  final Value<String> kind;
  final Value<String> payloadJson;
  final Value<DateTime> generatedAt;
  final Value<int> rowid;
  const CoachInsightsCompanion({
    this.isoYear = const Value.absent(),
    this.isoWeek = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoachInsightsCompanion.insert({
    required int isoYear,
    required int isoWeek,
    required String kind,
    required String payloadJson,
    required DateTime generatedAt,
    this.rowid = const Value.absent(),
  }) : isoYear = Value(isoYear),
       isoWeek = Value(isoWeek),
       kind = Value(kind),
       payloadJson = Value(payloadJson),
       generatedAt = Value(generatedAt);
  static Insertable<CoachInsightRow> custom({
    Expression<int>? isoYear,
    Expression<int>? isoWeek,
    Expression<String>? kind,
    Expression<String>? payloadJson,
    Expression<DateTime>? generatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (isoYear != null) 'iso_year': isoYear,
      if (isoWeek != null) 'iso_week': isoWeek,
      if (kind != null) 'kind': kind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoachInsightsCompanion copyWith({
    Value<int>? isoYear,
    Value<int>? isoWeek,
    Value<String>? kind,
    Value<String>? payloadJson,
    Value<DateTime>? generatedAt,
    Value<int>? rowid,
  }) {
    return CoachInsightsCompanion(
      isoYear: isoYear ?? this.isoYear,
      isoWeek: isoWeek ?? this.isoWeek,
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
      generatedAt: generatedAt ?? this.generatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isoYear.present) {
      map['iso_year'] = Variable<int>(isoYear.value);
    }
    if (isoWeek.present) {
      map['iso_week'] = Variable<int>(isoWeek.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoachInsightsCompanion(')
          ..write('isoYear: $isoYear, ')
          ..write('isoWeek: $isoWeek, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $EventSeriesTable eventSeries = $EventSeriesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $DayTemplatesTable dayTemplates = $DayTemplatesTable(this);
  late final $DayTemplateItemsTable dayTemplateItems = $DayTemplateItemsTable(
    this,
  );
  late final $DayScoresTable dayScores = $DayScoresTable(this);
  late final $ProgressTable progress = $ProgressTable(this);
  late final $BadgeUnlocksTable badgeUnlocks = $BadgeUnlocksTable(this);
  late final $WeeklyRoundupsTable weeklyRoundups = $WeeklyRoundupsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $CoachIntentsTable coachIntents = $CoachIntentsTable(this);
  late final $CoachReviewsTable coachReviews = $CoachReviewsTable(this);
  late final $CoachInsightsTable coachInsights = $CoachInsightsTable(this);
  late final Index eventsDate = Index(
    'events_date',
    'CREATE INDEX events_date ON events (date)',
  );
  late final Index eventsSeriesDate = Index(
    'events_series_date',
    'CREATE INDEX events_series_date ON events (series_id, date)',
  );
  late final EventDao eventDao = EventDao(this as AppDatabase);
  late final ProjectDao projectDao = ProjectDao(this as AppDatabase);
  late final TaskDao taskDao = TaskDao(this as AppDatabase);
  late final CoachDao coachDao = CoachDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final SeriesDao seriesDao = SeriesDao(this as AppDatabase);
  late final TemplateDao templateDao = TemplateDao(this as AppDatabase);
  late final StatsDao statsDao = StatsDao(this as AppDatabase);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final RoundupDao roundupDao = RoundupDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    events,
    eventSeries,
    appSettings,
    sessions,
    dayTemplates,
    dayTemplateItems,
    dayScores,
    progress,
    badgeUnlocks,
    weeklyRoundups,
    projects,
    tasks,
    coachIntents,
    coachReviews,
    coachInsights,
    eventsDate,
    eventsSeriesDate,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      Value<int?> seriesId,
      required DateTime date,
      required String title,
      required int toneIndex,
      required int startMinute,
      required int endMinute,
      Value<int> status,
      Value<bool> isFlight,
      Value<String?> flightNumber,
      Value<String?> fromCode,
      Value<String?> toCode,
      Value<int?> projectId,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      Value<int?> seriesId,
      Value<DateTime> date,
      Value<String> title,
      Value<int> toneIndex,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> status,
      Value<bool> isFlight,
      Value<String?> flightNumber,
      Value<String?> fromCode,
      Value<String?> toCode,
      Value<int?> projectId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$EventsTableReferences
    extends BaseReferences<_$AppDatabase, $EventsTable, EventRow> {
  $$EventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<SessionRow>>
  _sessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: 'events__id__sessions__event_id',
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFlight => $composableBuilder(
    column: $table.isFlight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flightNumber => $composableBuilder(
    column: $table.flightNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromCode => $composableBuilder(
    column: $table.fromCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toCode => $composableBuilder(
    column: $table.toCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get projectId => $composableBuilder(
    column: $table.projectId,
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

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFlight => $composableBuilder(
    column: $table.isFlight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flightNumber => $composableBuilder(
    column: $table.flightNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromCode => $composableBuilder(
    column: $table.fromCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toCode => $composableBuilder(
    column: $table.toCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get projectId => $composableBuilder(
    column: $table.projectId,
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

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get toneIndex =>
      $composableBuilder(column: $table.toneIndex, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isFlight =>
      $composableBuilder(column: $table.isFlight, builder: (column) => column);

  GeneratedColumn<String> get flightNumber => $composableBuilder(
    column: $table.flightNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromCode =>
      $composableBuilder(column: $table.fromCode, builder: (column) => column);

  GeneratedColumn<String> get toCode =>
      $composableBuilder(column: $table.toCode, builder: (column) => column);

  GeneratedColumn<int> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          EventRow,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (EventRow, $$EventsTableReferences),
          EventRow,
          PrefetchHooks Function({bool sessionsRefs})
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> toneIndex = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isFlight = const Value.absent(),
                Value<String?> flightNumber = const Value.absent(),
                Value<String?> fromCode = const Value.absent(),
                Value<String?> toCode = const Value.absent(),
                Value<int?> projectId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                seriesId: seriesId,
                date: date,
                title: title,
                toneIndex: toneIndex,
                startMinute: startMinute,
                endMinute: endMinute,
                status: status,
                isFlight: isFlight,
                flightNumber: flightNumber,
                fromCode: fromCode,
                toCode: toCode,
                projectId: projectId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                required DateTime date,
                required String title,
                required int toneIndex,
                required int startMinute,
                required int endMinute,
                Value<int> status = const Value.absent(),
                Value<bool> isFlight = const Value.absent(),
                Value<String?> flightNumber = const Value.absent(),
                Value<String?> fromCode = const Value.absent(),
                Value<String?> toCode = const Value.absent(),
                Value<int?> projectId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => EventsCompanion.insert(
                id: id,
                seriesId: seriesId,
                date: date,
                title: title,
                toneIndex: toneIndex,
                startMinute: startMinute,
                endMinute: endMinute,
                status: status,
                isFlight: isFlight,
                flightNumber: flightNumber,
                fromCode: fromCode,
                toCode: toCode,
                projectId: projectId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$EventsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({sessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionsRefs) db.sessions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<
                      EventRow,
                      $EventsTable,
                      SessionRow
                    >(
                      currentTable: table,
                      referencedTable: $$EventsTableReferences
                          ._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EventsTableReferences(db, table, p0).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      EventRow,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (EventRow, $$EventsTableReferences),
      EventRow,
      PrefetchHooks Function({bool sessionsRefs})
    >;
typedef $$EventSeriesTableCreateCompanionBuilder =
    EventSeriesCompanion Function({
      Value<int> id,
      required String title,
      required int toneIndex,
      required int startMinute,
      required int endMinute,
      required int recurrenceKind,
      Value<int> weekdayMask,
      required DateTime validFrom,
      Value<DateTime?> validUntil,
      required DateTime createdAt,
    });
typedef $$EventSeriesTableUpdateCompanionBuilder =
    EventSeriesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int> toneIndex,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> recurrenceKind,
      Value<int> weekdayMask,
      Value<DateTime> validFrom,
      Value<DateTime?> validUntil,
      Value<DateTime> createdAt,
    });

class $$EventSeriesTableFilterComposer
    extends Composer<_$AppDatabase, $EventSeriesTable> {
  $$EventSeriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recurrenceKind => $composableBuilder(
    column: $table.recurrenceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekdayMask => $composableBuilder(
    column: $table.weekdayMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventSeriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EventSeriesTable> {
  $$EventSeriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrenceKind => $composableBuilder(
    column: $table.recurrenceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdayMask => $composableBuilder(
    column: $table.weekdayMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventSeriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventSeriesTable> {
  $$EventSeriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get toneIndex =>
      $composableBuilder(column: $table.toneIndex, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get recurrenceKind => $composableBuilder(
    column: $table.recurrenceKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekdayMask => $composableBuilder(
    column: $table.weekdayMask,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get validFrom =>
      $composableBuilder(column: $table.validFrom, builder: (column) => column);

  GeneratedColumn<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EventSeriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventSeriesTable,
          EventSeriesRow,
          $$EventSeriesTableFilterComposer,
          $$EventSeriesTableOrderingComposer,
          $$EventSeriesTableAnnotationComposer,
          $$EventSeriesTableCreateCompanionBuilder,
          $$EventSeriesTableUpdateCompanionBuilder,
          (
            EventSeriesRow,
            BaseReferences<_$AppDatabase, $EventSeriesTable, EventSeriesRow>,
          ),
          EventSeriesRow,
          PrefetchHooks Function()
        > {
  $$EventSeriesTableTableManager(_$AppDatabase db, $EventSeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventSeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventSeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventSeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> toneIndex = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> recurrenceKind = const Value.absent(),
                Value<int> weekdayMask = const Value.absent(),
                Value<DateTime> validFrom = const Value.absent(),
                Value<DateTime?> validUntil = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EventSeriesCompanion(
                id: id,
                title: title,
                toneIndex: toneIndex,
                startMinute: startMinute,
                endMinute: endMinute,
                recurrenceKind: recurrenceKind,
                weekdayMask: weekdayMask,
                validFrom: validFrom,
                validUntil: validUntil,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required int toneIndex,
                required int startMinute,
                required int endMinute,
                required int recurrenceKind,
                Value<int> weekdayMask = const Value.absent(),
                required DateTime validFrom,
                Value<DateTime?> validUntil = const Value.absent(),
                required DateTime createdAt,
              }) => EventSeriesCompanion.insert(
                id: id,
                title: title,
                toneIndex: toneIndex,
                startMinute: startMinute,
                endMinute: endMinute,
                recurrenceKind: recurrenceKind,
                weekdayMask: weekdayMask,
                validFrom: validFrom,
                validUntil: validUntil,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventSeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventSeriesTable,
      EventSeriesRow,
      $$EventSeriesTableFilterComposer,
      $$EventSeriesTableOrderingComposer,
      $$EventSeriesTableAnnotationComposer,
      $$EventSeriesTableCreateCompanionBuilder,
      $$EventSeriesTableUpdateCompanionBuilder,
      (
        EventSeriesRow,
        BaseReferences<_$AppDatabase, $EventSeriesTable, EventSeriesRow>,
      ),
      EventSeriesRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
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
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
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
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
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
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
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
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
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
      _$AppDatabase,
      $AppSettingsTable,
      SettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      required int eventId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required int plannedSeconds,
      Value<int> pausedSeconds,
      Value<DateTime?> pauseStartedAt,
      Value<int> activeSeconds,
      Value<int> overtimeSeconds,
      Value<int> outcome,
      Value<int?> energyRating,
      Value<int?> focusRating,
      Value<String?> tagsCsv,
      Value<String?> note,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<int> eventId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> plannedSeconds,
      Value<int> pausedSeconds,
      Value<DateTime?> pauseStartedAt,
      Value<int> activeSeconds,
      Value<int> overtimeSeconds,
      Value<int> outcome,
      Value<int?> energyRating,
      Value<int?> focusRating,
      Value<String?> tagsCsv,
      Value<String?> note,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, SessionRow> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EventsTable _eventIdTable(_$AppDatabase db) =>
      db.events.createAlias('sessions__event_id__events__id');

  $$EventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<int>('event_id')!;

    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedSeconds => $composableBuilder(
    column: $table.plannedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedSeconds => $composableBuilder(
    column: $table.pausedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pauseStartedAt => $composableBuilder(
    column: $table.pauseStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeSeconds => $composableBuilder(
    column: $table.activeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeSeconds => $composableBuilder(
    column: $table.overtimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energyRating => $composableBuilder(
    column: $table.energyRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusRating => $composableBuilder(
    column: $table.focusRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsCsv => $composableBuilder(
    column: $table.tagsCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$EventsTableFilterComposer get eventId {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedSeconds => $composableBuilder(
    column: $table.plannedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedSeconds => $composableBuilder(
    column: $table.pausedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pauseStartedAt => $composableBuilder(
    column: $table.pauseStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeSeconds => $composableBuilder(
    column: $table.activeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeSeconds => $composableBuilder(
    column: $table.overtimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energyRating => $composableBuilder(
    column: $table.energyRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusRating => $composableBuilder(
    column: $table.focusRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsCsv => $composableBuilder(
    column: $table.tagsCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$EventsTableOrderingComposer get eventId {
    final $$EventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableOrderingComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get plannedSeconds => $composableBuilder(
    column: $table.plannedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pausedSeconds => $composableBuilder(
    column: $table.pausedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get pauseStartedAt => $composableBuilder(
    column: $table.pauseStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeSeconds => $composableBuilder(
    column: $table.activeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overtimeSeconds => $composableBuilder(
    column: $table.overtimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get energyRating => $composableBuilder(
    column: $table.energyRating,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusRating => $composableBuilder(
    column: $table.focusRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsCsv =>
      $composableBuilder(column: $table.tagsCsv, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$EventsTableAnnotationComposer get eventId {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (SessionRow, $$SessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({bool eventId})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> eventId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> plannedSeconds = const Value.absent(),
                Value<int> pausedSeconds = const Value.absent(),
                Value<DateTime?> pauseStartedAt = const Value.absent(),
                Value<int> activeSeconds = const Value.absent(),
                Value<int> overtimeSeconds = const Value.absent(),
                Value<int> outcome = const Value.absent(),
                Value<int?> energyRating = const Value.absent(),
                Value<int?> focusRating = const Value.absent(),
                Value<String?> tagsCsv = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                eventId: eventId,
                startedAt: startedAt,
                endedAt: endedAt,
                plannedSeconds: plannedSeconds,
                pausedSeconds: pausedSeconds,
                pauseStartedAt: pauseStartedAt,
                activeSeconds: activeSeconds,
                overtimeSeconds: overtimeSeconds,
                outcome: outcome,
                energyRating: energyRating,
                focusRating: focusRating,
                tagsCsv: tagsCsv,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int eventId,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required int plannedSeconds,
                Value<int> pausedSeconds = const Value.absent(),
                Value<DateTime?> pauseStartedAt = const Value.absent(),
                Value<int> activeSeconds = const Value.absent(),
                Value<int> overtimeSeconds = const Value.absent(),
                Value<int> outcome = const Value.absent(),
                Value<int?> energyRating = const Value.absent(),
                Value<int?> focusRating = const Value.absent(),
                Value<String?> tagsCsv = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                eventId: eventId,
                startedAt: startedAt,
                endedAt: endedAt,
                plannedSeconds: plannedSeconds,
                pausedSeconds: pausedSeconds,
                pauseStartedAt: pauseStartedAt,
                activeSeconds: activeSeconds,
                overtimeSeconds: overtimeSeconds,
                outcome: outcome,
                energyRating: energyRating,
                focusRating: focusRating,
                tagsCsv: tagsCsv,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$SessionsTableReferences
                                    ._eventIdTable(db),
                                referencedColumn: $$SessionsTableReferences
                                    ._eventIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, $$SessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({bool eventId})
    >;
typedef $$DayTemplatesTableCreateCompanionBuilder =
    DayTemplatesCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
    });
typedef $$DayTemplatesTableUpdateCompanionBuilder =
    DayTemplatesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

final class $$DayTemplatesTableReferences
    extends BaseReferences<_$AppDatabase, $DayTemplatesTable, DayTemplateRow> {
  $$DayTemplatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DayTemplateItemsTable, List<DayTemplateItemRow>>
  _dayTemplateItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dayTemplateItems,
    aliasName: 'day_templates__id__day_template_items__template_id',
  );

  $$DayTemplateItemsTableProcessedTableManager get dayTemplateItemsRefs {
    final manager = $$DayTemplateItemsTableTableManager(
      $_db,
      $_db.dayTemplateItems,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dayTemplateItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DayTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $DayTemplatesTable> {
  $$DayTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dayTemplateItemsRefs(
    Expression<bool> Function($$DayTemplateItemsTableFilterComposer f) f,
  ) {
    final $$DayTemplateItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayTemplateItems,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTemplateItemsTableFilterComposer(
            $db: $db,
            $table: $db.dayTemplateItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DayTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayTemplatesTable> {
  $$DayTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayTemplatesTable> {
  $$DayTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> dayTemplateItemsRefs<T extends Object>(
    Expression<T> Function($$DayTemplateItemsTableAnnotationComposer a) f,
  ) {
    final $$DayTemplateItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayTemplateItems,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTemplateItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.dayTemplateItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DayTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayTemplatesTable,
          DayTemplateRow,
          $$DayTemplatesTableFilterComposer,
          $$DayTemplatesTableOrderingComposer,
          $$DayTemplatesTableAnnotationComposer,
          $$DayTemplatesTableCreateCompanionBuilder,
          $$DayTemplatesTableUpdateCompanionBuilder,
          (DayTemplateRow, $$DayTemplatesTableReferences),
          DayTemplateRow,
          PrefetchHooks Function({bool dayTemplateItemsRefs})
        > {
  $$DayTemplatesTableTableManager(_$AppDatabase db, $DayTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DayTemplatesCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => DayTemplatesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DayTemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dayTemplateItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (dayTemplateItemsRefs) db.dayTemplateItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dayTemplateItemsRefs)
                    await $_getPrefetchedData<
                      DayTemplateRow,
                      $DayTemplatesTable,
                      DayTemplateItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$DayTemplatesTableReferences
                          ._dayTemplateItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DayTemplatesTableReferences(
                            db,
                            table,
                            p0,
                          ).dayTemplateItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.templateId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DayTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayTemplatesTable,
      DayTemplateRow,
      $$DayTemplatesTableFilterComposer,
      $$DayTemplatesTableOrderingComposer,
      $$DayTemplatesTableAnnotationComposer,
      $$DayTemplatesTableCreateCompanionBuilder,
      $$DayTemplatesTableUpdateCompanionBuilder,
      (DayTemplateRow, $$DayTemplatesTableReferences),
      DayTemplateRow,
      PrefetchHooks Function({bool dayTemplateItemsRefs})
    >;
typedef $$DayTemplateItemsTableCreateCompanionBuilder =
    DayTemplateItemsCompanion Function({
      Value<int> id,
      required int templateId,
      required String title,
      required int toneIndex,
      required int startMinute,
      required int endMinute,
    });
typedef $$DayTemplateItemsTableUpdateCompanionBuilder =
    DayTemplateItemsCompanion Function({
      Value<int> id,
      Value<int> templateId,
      Value<String> title,
      Value<int> toneIndex,
      Value<int> startMinute,
      Value<int> endMinute,
    });

final class $$DayTemplateItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DayTemplateItemsTable,
          DayTemplateItemRow
        > {
  $$DayTemplateItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DayTemplatesTable _templateIdTable(_$AppDatabase db) => db
      .dayTemplates
      .createAlias('day_template_items__template_id__day_templates__id');

  $$DayTemplatesTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<int>('template_id')!;

    final manager = $$DayTemplatesTableTableManager(
      $_db,
      $_db.dayTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DayTemplateItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DayTemplateItemsTable> {
  $$DayTemplateItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  $$DayTemplatesTableFilterComposer get templateId {
    final $$DayTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.dayTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.dayTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTemplateItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DayTemplateItemsTable> {
  $$DayTemplateItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  $$DayTemplatesTableOrderingComposer get templateId {
    final $$DayTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.dayTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.dayTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTemplateItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayTemplateItemsTable> {
  $$DayTemplateItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get toneIndex =>
      $composableBuilder(column: $table.toneIndex, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  $$DayTemplatesTableAnnotationComposer get templateId {
    final $$DayTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.dayTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.dayTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTemplateItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayTemplateItemsTable,
          DayTemplateItemRow,
          $$DayTemplateItemsTableFilterComposer,
          $$DayTemplateItemsTableOrderingComposer,
          $$DayTemplateItemsTableAnnotationComposer,
          $$DayTemplateItemsTableCreateCompanionBuilder,
          $$DayTemplateItemsTableUpdateCompanionBuilder,
          (DayTemplateItemRow, $$DayTemplateItemsTableReferences),
          DayTemplateItemRow,
          PrefetchHooks Function({bool templateId})
        > {
  $$DayTemplateItemsTableTableManager(
    _$AppDatabase db,
    $DayTemplateItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayTemplateItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayTemplateItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayTemplateItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> templateId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> toneIndex = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
              }) => DayTemplateItemsCompanion(
                id: id,
                templateId: templateId,
                title: title,
                toneIndex: toneIndex,
                startMinute: startMinute,
                endMinute: endMinute,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int templateId,
                required String title,
                required int toneIndex,
                required int startMinute,
                required int endMinute,
              }) => DayTemplateItemsCompanion.insert(
                id: id,
                templateId: templateId,
                title: title,
                toneIndex: toneIndex,
                startMinute: startMinute,
                endMinute: endMinute,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DayTemplateItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({templateId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (templateId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.templateId,
                                referencedTable:
                                    $$DayTemplateItemsTableReferences
                                        ._templateIdTable(db),
                                referencedColumn:
                                    $$DayTemplateItemsTableReferences
                                        ._templateIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DayTemplateItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayTemplateItemsTable,
      DayTemplateItemRow,
      $$DayTemplateItemsTableFilterComposer,
      $$DayTemplateItemsTableOrderingComposer,
      $$DayTemplateItemsTableAnnotationComposer,
      $$DayTemplateItemsTableCreateCompanionBuilder,
      $$DayTemplateItemsTableUpdateCompanionBuilder,
      (DayTemplateItemRow, $$DayTemplateItemsTableReferences),
      DayTemplateItemRow,
      PrefetchHooks Function({bool templateId})
    >;
typedef $$DayScoresTableCreateCompanionBuilder =
    DayScoresCompanion Function({
      required DateTime date,
      required int energyScore,
      required int adherencePoints,
      required int focusPoints,
      required int balancePoints,
      Value<int> focusMinutes,
      Value<int> lifeMinutes,
      Value<int> inboxMinutes,
      Value<int> plannedMinutes,
      Value<int> completedMinutes,
      required DateTime computedAt,
      Value<int> rowid,
    });
typedef $$DayScoresTableUpdateCompanionBuilder =
    DayScoresCompanion Function({
      Value<DateTime> date,
      Value<int> energyScore,
      Value<int> adherencePoints,
      Value<int> focusPoints,
      Value<int> balancePoints,
      Value<int> focusMinutes,
      Value<int> lifeMinutes,
      Value<int> inboxMinutes,
      Value<int> plannedMinutes,
      Value<int> completedMinutes,
      Value<DateTime> computedAt,
      Value<int> rowid,
    });

class $$DayScoresTableFilterComposer
    extends Composer<_$AppDatabase, $DayScoresTable> {
  $$DayScoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energyScore => $composableBuilder(
    column: $table.energyScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get adherencePoints => $composableBuilder(
    column: $table.adherencePoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusPoints => $composableBuilder(
    column: $table.focusPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balancePoints => $composableBuilder(
    column: $table.balancePoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifeMinutes => $composableBuilder(
    column: $table.lifeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inboxMinutes => $composableBuilder(
    column: $table.inboxMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedMinutes => $composableBuilder(
    column: $table.plannedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedMinutes => $composableBuilder(
    column: $table.completedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayScoresTableOrderingComposer
    extends Composer<_$AppDatabase, $DayScoresTable> {
  $$DayScoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energyScore => $composableBuilder(
    column: $table.energyScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get adherencePoints => $composableBuilder(
    column: $table.adherencePoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusPoints => $composableBuilder(
    column: $table.focusPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balancePoints => $composableBuilder(
    column: $table.balancePoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifeMinutes => $composableBuilder(
    column: $table.lifeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inboxMinutes => $composableBuilder(
    column: $table.inboxMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedMinutes => $composableBuilder(
    column: $table.plannedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedMinutes => $composableBuilder(
    column: $table.completedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayScoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayScoresTable> {
  $$DayScoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get energyScore => $composableBuilder(
    column: $table.energyScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get adherencePoints => $composableBuilder(
    column: $table.adherencePoints,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusPoints => $composableBuilder(
    column: $table.focusPoints,
    builder: (column) => column,
  );

  GeneratedColumn<int> get balancePoints => $composableBuilder(
    column: $table.balancePoints,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifeMinutes => $composableBuilder(
    column: $table.lifeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inboxMinutes => $composableBuilder(
    column: $table.inboxMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedMinutes => $composableBuilder(
    column: $table.plannedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedMinutes => $composableBuilder(
    column: $table.completedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => column,
  );
}

class $$DayScoresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayScoresTable,
          DayScoreRow,
          $$DayScoresTableFilterComposer,
          $$DayScoresTableOrderingComposer,
          $$DayScoresTableAnnotationComposer,
          $$DayScoresTableCreateCompanionBuilder,
          $$DayScoresTableUpdateCompanionBuilder,
          (
            DayScoreRow,
            BaseReferences<_$AppDatabase, $DayScoresTable, DayScoreRow>,
          ),
          DayScoreRow,
          PrefetchHooks Function()
        > {
  $$DayScoresTableTableManager(_$AppDatabase db, $DayScoresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayScoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayScoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayScoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<int> energyScore = const Value.absent(),
                Value<int> adherencePoints = const Value.absent(),
                Value<int> focusPoints = const Value.absent(),
                Value<int> balancePoints = const Value.absent(),
                Value<int> focusMinutes = const Value.absent(),
                Value<int> lifeMinutes = const Value.absent(),
                Value<int> inboxMinutes = const Value.absent(),
                Value<int> plannedMinutes = const Value.absent(),
                Value<int> completedMinutes = const Value.absent(),
                Value<DateTime> computedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayScoresCompanion(
                date: date,
                energyScore: energyScore,
                adherencePoints: adherencePoints,
                focusPoints: focusPoints,
                balancePoints: balancePoints,
                focusMinutes: focusMinutes,
                lifeMinutes: lifeMinutes,
                inboxMinutes: inboxMinutes,
                plannedMinutes: plannedMinutes,
                completedMinutes: completedMinutes,
                computedAt: computedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required int energyScore,
                required int adherencePoints,
                required int focusPoints,
                required int balancePoints,
                Value<int> focusMinutes = const Value.absent(),
                Value<int> lifeMinutes = const Value.absent(),
                Value<int> inboxMinutes = const Value.absent(),
                Value<int> plannedMinutes = const Value.absent(),
                Value<int> completedMinutes = const Value.absent(),
                required DateTime computedAt,
                Value<int> rowid = const Value.absent(),
              }) => DayScoresCompanion.insert(
                date: date,
                energyScore: energyScore,
                adherencePoints: adherencePoints,
                focusPoints: focusPoints,
                balancePoints: balancePoints,
                focusMinutes: focusMinutes,
                lifeMinutes: lifeMinutes,
                inboxMinutes: inboxMinutes,
                plannedMinutes: plannedMinutes,
                completedMinutes: completedMinutes,
                computedAt: computedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DayScoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayScoresTable,
      DayScoreRow,
      $$DayScoresTableFilterComposer,
      $$DayScoresTableOrderingComposer,
      $$DayScoresTableAnnotationComposer,
      $$DayScoresTableCreateCompanionBuilder,
      $$DayScoresTableUpdateCompanionBuilder,
      (
        DayScoreRow,
        BaseReferences<_$AppDatabase, $DayScoresTable, DayScoreRow>,
      ),
      DayScoreRow,
      PrefetchHooks Function()
    >;
typedef $$ProgressTableCreateCompanionBuilder =
    ProgressCompanion Function({
      Value<int> id,
      Value<int> xp,
      Value<int> level,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<DateTime?> lastStreakDate,
    });
typedef $$ProgressTableUpdateCompanionBuilder =
    ProgressCompanion Function({
      Value<int> id,
      Value<int> xp,
      Value<int> level,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<DateTime?> lastStreakDate,
    });

class $$ProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressTable> {
  $$ProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressTable> {
  $$ProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressTable> {
  $$ProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => column,
  );
}

class $$ProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressTable,
          ProgressRow,
          $$ProgressTableFilterComposer,
          $$ProgressTableOrderingComposer,
          $$ProgressTableAnnotationComposer,
          $$ProgressTableCreateCompanionBuilder,
          $$ProgressTableUpdateCompanionBuilder,
          (
            ProgressRow,
            BaseReferences<_$AppDatabase, $ProgressTable, ProgressRow>,
          ),
          ProgressRow,
          PrefetchHooks Function()
        > {
  $$ProgressTableTableManager(_$AppDatabase db, $ProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<DateTime?> lastStreakDate = const Value.absent(),
              }) => ProgressCompanion(
                id: id,
                xp: xp,
                level: level,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastStreakDate: lastStreakDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<DateTime?> lastStreakDate = const Value.absent(),
              }) => ProgressCompanion.insert(
                id: id,
                xp: xp,
                level: level,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastStreakDate: lastStreakDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressTable,
      ProgressRow,
      $$ProgressTableFilterComposer,
      $$ProgressTableOrderingComposer,
      $$ProgressTableAnnotationComposer,
      $$ProgressTableCreateCompanionBuilder,
      $$ProgressTableUpdateCompanionBuilder,
      (ProgressRow, BaseReferences<_$AppDatabase, $ProgressTable, ProgressRow>),
      ProgressRow,
      PrefetchHooks Function()
    >;
typedef $$BadgeUnlocksTableCreateCompanionBuilder =
    BadgeUnlocksCompanion Function({
      required String badgeId,
      required DateTime unlockedAt,
      Value<int> rowid,
    });
typedef $$BadgeUnlocksTableUpdateCompanionBuilder =
    BadgeUnlocksCompanion Function({
      Value<String> badgeId,
      Value<DateTime> unlockedAt,
      Value<int> rowid,
    });

class $$BadgeUnlocksTableFilterComposer
    extends Composer<_$AppDatabase, $BadgeUnlocksTable> {
  $$BadgeUnlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get badgeId => $composableBuilder(
    column: $table.badgeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BadgeUnlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $BadgeUnlocksTable> {
  $$BadgeUnlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get badgeId => $composableBuilder(
    column: $table.badgeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BadgeUnlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BadgeUnlocksTable> {
  $$BadgeUnlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get badgeId =>
      $composableBuilder(column: $table.badgeId, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => column,
  );
}

class $$BadgeUnlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BadgeUnlocksTable,
          BadgeUnlockRow,
          $$BadgeUnlocksTableFilterComposer,
          $$BadgeUnlocksTableOrderingComposer,
          $$BadgeUnlocksTableAnnotationComposer,
          $$BadgeUnlocksTableCreateCompanionBuilder,
          $$BadgeUnlocksTableUpdateCompanionBuilder,
          (
            BadgeUnlockRow,
            BaseReferences<_$AppDatabase, $BadgeUnlocksTable, BadgeUnlockRow>,
          ),
          BadgeUnlockRow,
          PrefetchHooks Function()
        > {
  $$BadgeUnlocksTableTableManager(_$AppDatabase db, $BadgeUnlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BadgeUnlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BadgeUnlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BadgeUnlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> badgeId = const Value.absent(),
                Value<DateTime> unlockedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BadgeUnlocksCompanion(
                badgeId: badgeId,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String badgeId,
                required DateTime unlockedAt,
                Value<int> rowid = const Value.absent(),
              }) => BadgeUnlocksCompanion.insert(
                badgeId: badgeId,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BadgeUnlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BadgeUnlocksTable,
      BadgeUnlockRow,
      $$BadgeUnlocksTableFilterComposer,
      $$BadgeUnlocksTableOrderingComposer,
      $$BadgeUnlocksTableAnnotationComposer,
      $$BadgeUnlocksTableCreateCompanionBuilder,
      $$BadgeUnlocksTableUpdateCompanionBuilder,
      (
        BadgeUnlockRow,
        BaseReferences<_$AppDatabase, $BadgeUnlocksTable, BadgeUnlockRow>,
      ),
      BadgeUnlockRow,
      PrefetchHooks Function()
    >;
typedef $$WeeklyRoundupsTableCreateCompanionBuilder =
    WeeklyRoundupsCompanion Function({
      required int isoYear,
      required int isoWeek,
      required DateTime generatedAt,
      required String payloadJson,
      Value<int> rowid,
    });
typedef $$WeeklyRoundupsTableUpdateCompanionBuilder =
    WeeklyRoundupsCompanion Function({
      Value<int> isoYear,
      Value<int> isoWeek,
      Value<DateTime> generatedAt,
      Value<String> payloadJson,
      Value<int> rowid,
    });

class $$WeeklyRoundupsTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklyRoundupsTable> {
  $$WeeklyRoundupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isoYear => $composableBuilder(
    column: $table.isoYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isoWeek => $composableBuilder(
    column: $table.isoWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeklyRoundupsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklyRoundupsTable> {
  $$WeeklyRoundupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isoYear => $composableBuilder(
    column: $table.isoYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isoWeek => $composableBuilder(
    column: $table.isoWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyRoundupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklyRoundupsTable> {
  $$WeeklyRoundupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isoYear =>
      $composableBuilder(column: $table.isoYear, builder: (column) => column);

  GeneratedColumn<int> get isoWeek =>
      $composableBuilder(column: $table.isoWeek, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$WeeklyRoundupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeeklyRoundupsTable,
          WeeklyRoundupRow,
          $$WeeklyRoundupsTableFilterComposer,
          $$WeeklyRoundupsTableOrderingComposer,
          $$WeeklyRoundupsTableAnnotationComposer,
          $$WeeklyRoundupsTableCreateCompanionBuilder,
          $$WeeklyRoundupsTableUpdateCompanionBuilder,
          (
            WeeklyRoundupRow,
            BaseReferences<
              _$AppDatabase,
              $WeeklyRoundupsTable,
              WeeklyRoundupRow
            >,
          ),
          WeeklyRoundupRow,
          PrefetchHooks Function()
        > {
  $$WeeklyRoundupsTableTableManager(
    _$AppDatabase db,
    $WeeklyRoundupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyRoundupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyRoundupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyRoundupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isoYear = const Value.absent(),
                Value<int> isoWeek = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyRoundupsCompanion(
                isoYear: isoYear,
                isoWeek: isoWeek,
                generatedAt: generatedAt,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int isoYear,
                required int isoWeek,
                required DateTime generatedAt,
                required String payloadJson,
                Value<int> rowid = const Value.absent(),
              }) => WeeklyRoundupsCompanion.insert(
                isoYear: isoYear,
                isoWeek: isoWeek,
                generatedAt: generatedAt,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeklyRoundupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeeklyRoundupsTable,
      WeeklyRoundupRow,
      $$WeeklyRoundupsTableFilterComposer,
      $$WeeklyRoundupsTableOrderingComposer,
      $$WeeklyRoundupsTableAnnotationComposer,
      $$WeeklyRoundupsTableCreateCompanionBuilder,
      $$WeeklyRoundupsTableUpdateCompanionBuilder,
      (
        WeeklyRoundupRow,
        BaseReferences<_$AppDatabase, $WeeklyRoundupsTable, WeeklyRoundupRow>,
      ),
      WeeklyRoundupRow,
      PrefetchHooks Function()
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      required String title,
      required DateTime createdAt,
      Value<DateTime?> deadline,
      Value<int?> targetMinutes,
      Value<int?> toneIndex,
      Value<int> status,
      Value<DateTime?> completedAt,
      Value<String?> notes,
      Value<int> priority,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime?> deadline,
      Value<int?> targetMinutes,
      Value<int?> toneIndex,
      Value<int> status,
      Value<DateTime?> completedAt,
      Value<String?> notes,
      Value<int> priority,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'projects__id__tasks__project_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetMinutes => $composableBuilder(
    column: $table.targetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetMinutes => $composableBuilder(
    column: $table.targetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toneIndex => $composableBuilder(
    column: $table.toneIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<int> get targetMinutes => $composableBuilder(
    column: $table.targetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get toneIndex =>
      $composableBuilder(column: $table.toneIndex, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          ProjectRow,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (ProjectRow, $$ProjectsTableReferences),
          ProjectRow,
          PrefetchHooks Function({bool tasksRefs})
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deadline = const Value.absent(),
                Value<int?> targetMinutes = const Value.absent(),
                Value<int?> toneIndex = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> priority = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                deadline: deadline,
                targetMinutes: targetMinutes,
                toneIndex: toneIndex,
                status: status,
                completedAt: completedAt,
                notes: notes,
                priority: priority,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime createdAt,
                Value<DateTime?> deadline = const Value.absent(),
                Value<int?> targetMinutes = const Value.absent(),
                Value<int?> toneIndex = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> priority = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                deadline: deadline,
                targetMinutes: targetMinutes,
                toneIndex: toneIndex,
                status: status,
                completedAt: completedAt,
                notes: notes,
                priority: priority,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedData<
                      ProjectRow,
                      $ProjectsTable,
                      TaskRow
                    >(
                      currentTable: table,
                      referencedTable: $$ProjectsTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProjectsTableReferences(db, table, p0).tasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.projectId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      ProjectRow,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (ProjectRow, $$ProjectsTableReferences),
      ProjectRow,
      PrefetchHooks Function({bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      required int projectId,
      required String title,
      Value<String?> notes,
      Value<int> boardStatus,
      Value<int> priority,
      Value<int?> estimateMinutes,
      Value<DateTime?> dueDate,
      Value<DateTime?> plannedDate,
      required int sortOrder,
      Value<String?> blockedReason,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> title,
      Value<String?> notes,
      Value<int> boardStatus,
      Value<int> priority,
      Value<int?> estimateMinutes,
      Value<DateTime?> dueDate,
      Value<DateTime?> plannedDate,
      Value<int> sortOrder,
      Value<String?> blockedReason,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('tasks__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get boardStatus => $composableBuilder(
    column: $table.boardStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockedReason => $composableBuilder(
    column: $table.blockedReason,
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

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get boardStatus => $composableBuilder(
    column: $table.boardStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockedReason => $composableBuilder(
    column: $table.blockedReason,
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

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get boardStatus => $composableBuilder(
    column: $table.boardStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get blockedReason => $composableBuilder(
    column: $table.blockedReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> boardStatus = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> estimateMinutes = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime?> plannedDate = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> blockedReason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                projectId: projectId,
                title: title,
                notes: notes,
                boardStatus: boardStatus,
                priority: priority,
                estimateMinutes: estimateMinutes,
                dueDate: dueDate,
                plannedDate: plannedDate,
                sortOrder: sortOrder,
                blockedReason: blockedReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<int> boardStatus = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> estimateMinutes = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime?> plannedDate = const Value.absent(),
                required int sortOrder,
                Value<String?> blockedReason = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                projectId: projectId,
                title: title,
                notes: notes,
                boardStatus: boardStatus,
                priority: priority,
                estimateMinutes: estimateMinutes,
                dueDate: dueDate,
                plannedDate: plannedDate,
                sortOrder: sortOrder,
                blockedReason: blockedReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$TasksTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$TasksTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$CoachIntentsTableCreateCompanionBuilder =
    CoachIntentsCompanion Function({
      required DateTime date,
      required String focusGoal,
      Value<String?> topEventIds,
      Value<int?> predictedEnergy,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CoachIntentsTableUpdateCompanionBuilder =
    CoachIntentsCompanion Function({
      Value<DateTime> date,
      Value<String> focusGoal,
      Value<String?> topEventIds,
      Value<int?> predictedEnergy,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CoachIntentsTableFilterComposer
    extends Composer<_$AppDatabase, $CoachIntentsTable> {
  $$CoachIntentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get focusGoal => $composableBuilder(
    column: $table.focusGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topEventIds => $composableBuilder(
    column: $table.topEventIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get predictedEnergy => $composableBuilder(
    column: $table.predictedEnergy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoachIntentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoachIntentsTable> {
  $$CoachIntentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get focusGoal => $composableBuilder(
    column: $table.focusGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topEventIds => $composableBuilder(
    column: $table.topEventIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get predictedEnergy => $composableBuilder(
    column: $table.predictedEnergy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoachIntentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoachIntentsTable> {
  $$CoachIntentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get focusGoal =>
      $composableBuilder(column: $table.focusGoal, builder: (column) => column);

  GeneratedColumn<String> get topEventIds => $composableBuilder(
    column: $table.topEventIds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get predictedEnergy => $composableBuilder(
    column: $table.predictedEnergy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CoachIntentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoachIntentsTable,
          CoachIntentRow,
          $$CoachIntentsTableFilterComposer,
          $$CoachIntentsTableOrderingComposer,
          $$CoachIntentsTableAnnotationComposer,
          $$CoachIntentsTableCreateCompanionBuilder,
          $$CoachIntentsTableUpdateCompanionBuilder,
          (
            CoachIntentRow,
            BaseReferences<_$AppDatabase, $CoachIntentsTable, CoachIntentRow>,
          ),
          CoachIntentRow,
          PrefetchHooks Function()
        > {
  $$CoachIntentsTableTableManager(_$AppDatabase db, $CoachIntentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoachIntentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoachIntentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoachIntentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<String> focusGoal = const Value.absent(),
                Value<String?> topEventIds = const Value.absent(),
                Value<int?> predictedEnergy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoachIntentsCompanion(
                date: date,
                focusGoal: focusGoal,
                topEventIds: topEventIds,
                predictedEnergy: predictedEnergy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required String focusGoal,
                Value<String?> topEventIds = const Value.absent(),
                Value<int?> predictedEnergy = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CoachIntentsCompanion.insert(
                date: date,
                focusGoal: focusGoal,
                topEventIds: topEventIds,
                predictedEnergy: predictedEnergy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoachIntentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoachIntentsTable,
      CoachIntentRow,
      $$CoachIntentsTableFilterComposer,
      $$CoachIntentsTableOrderingComposer,
      $$CoachIntentsTableAnnotationComposer,
      $$CoachIntentsTableCreateCompanionBuilder,
      $$CoachIntentsTableUpdateCompanionBuilder,
      (
        CoachIntentRow,
        BaseReferences<_$AppDatabase, $CoachIntentsTable, CoachIntentRow>,
      ),
      CoachIntentRow,
      PrefetchHooks Function()
    >;
typedef $$CoachReviewsTableCreateCompanionBuilder =
    CoachReviewsCompanion Function({
      required DateTime date,
      required int energy,
      Value<String?> winText,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CoachReviewsTableUpdateCompanionBuilder =
    CoachReviewsCompanion Function({
      Value<DateTime> date,
      Value<int> energy,
      Value<String?> winText,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CoachReviewsTableFilterComposer
    extends Composer<_$AppDatabase, $CoachReviewsTable> {
  $$CoachReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winText => $composableBuilder(
    column: $table.winText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoachReviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoachReviewsTable> {
  $$CoachReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winText => $composableBuilder(
    column: $table.winText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoachReviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoachReviewsTable> {
  $$CoachReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<String> get winText =>
      $composableBuilder(column: $table.winText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CoachReviewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoachReviewsTable,
          CoachReviewRow,
          $$CoachReviewsTableFilterComposer,
          $$CoachReviewsTableOrderingComposer,
          $$CoachReviewsTableAnnotationComposer,
          $$CoachReviewsTableCreateCompanionBuilder,
          $$CoachReviewsTableUpdateCompanionBuilder,
          (
            CoachReviewRow,
            BaseReferences<_$AppDatabase, $CoachReviewsTable, CoachReviewRow>,
          ),
          CoachReviewRow,
          PrefetchHooks Function()
        > {
  $$CoachReviewsTableTableManager(_$AppDatabase db, $CoachReviewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoachReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoachReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoachReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<int> energy = const Value.absent(),
                Value<String?> winText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoachReviewsCompanion(
                date: date,
                energy: energy,
                winText: winText,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required int energy,
                Value<String?> winText = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CoachReviewsCompanion.insert(
                date: date,
                energy: energy,
                winText: winText,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoachReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoachReviewsTable,
      CoachReviewRow,
      $$CoachReviewsTableFilterComposer,
      $$CoachReviewsTableOrderingComposer,
      $$CoachReviewsTableAnnotationComposer,
      $$CoachReviewsTableCreateCompanionBuilder,
      $$CoachReviewsTableUpdateCompanionBuilder,
      (
        CoachReviewRow,
        BaseReferences<_$AppDatabase, $CoachReviewsTable, CoachReviewRow>,
      ),
      CoachReviewRow,
      PrefetchHooks Function()
    >;
typedef $$CoachInsightsTableCreateCompanionBuilder =
    CoachInsightsCompanion Function({
      required int isoYear,
      required int isoWeek,
      required String kind,
      required String payloadJson,
      required DateTime generatedAt,
      Value<int> rowid,
    });
typedef $$CoachInsightsTableUpdateCompanionBuilder =
    CoachInsightsCompanion Function({
      Value<int> isoYear,
      Value<int> isoWeek,
      Value<String> kind,
      Value<String> payloadJson,
      Value<DateTime> generatedAt,
      Value<int> rowid,
    });

class $$CoachInsightsTableFilterComposer
    extends Composer<_$AppDatabase, $CoachInsightsTable> {
  $$CoachInsightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isoYear => $composableBuilder(
    column: $table.isoYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isoWeek => $composableBuilder(
    column: $table.isoWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoachInsightsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoachInsightsTable> {
  $$CoachInsightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isoYear => $composableBuilder(
    column: $table.isoYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isoWeek => $composableBuilder(
    column: $table.isoWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoachInsightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoachInsightsTable> {
  $$CoachInsightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isoYear =>
      $composableBuilder(column: $table.isoYear, builder: (column) => column);

  GeneratedColumn<int> get isoWeek =>
      $composableBuilder(column: $table.isoWeek, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );
}

class $$CoachInsightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoachInsightsTable,
          CoachInsightRow,
          $$CoachInsightsTableFilterComposer,
          $$CoachInsightsTableOrderingComposer,
          $$CoachInsightsTableAnnotationComposer,
          $$CoachInsightsTableCreateCompanionBuilder,
          $$CoachInsightsTableUpdateCompanionBuilder,
          (
            CoachInsightRow,
            BaseReferences<_$AppDatabase, $CoachInsightsTable, CoachInsightRow>,
          ),
          CoachInsightRow,
          PrefetchHooks Function()
        > {
  $$CoachInsightsTableTableManager(_$AppDatabase db, $CoachInsightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoachInsightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoachInsightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoachInsightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isoYear = const Value.absent(),
                Value<int> isoWeek = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoachInsightsCompanion(
                isoYear: isoYear,
                isoWeek: isoWeek,
                kind: kind,
                payloadJson: payloadJson,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int isoYear,
                required int isoWeek,
                required String kind,
                required String payloadJson,
                required DateTime generatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CoachInsightsCompanion.insert(
                isoYear: isoYear,
                isoWeek: isoWeek,
                kind: kind,
                payloadJson: payloadJson,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoachInsightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoachInsightsTable,
      CoachInsightRow,
      $$CoachInsightsTableFilterComposer,
      $$CoachInsightsTableOrderingComposer,
      $$CoachInsightsTableAnnotationComposer,
      $$CoachInsightsTableCreateCompanionBuilder,
      $$CoachInsightsTableUpdateCompanionBuilder,
      (
        CoachInsightRow,
        BaseReferences<_$AppDatabase, $CoachInsightsTable, CoachInsightRow>,
      ),
      CoachInsightRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$EventSeriesTableTableManager get eventSeries =>
      $$EventSeriesTableTableManager(_db, _db.eventSeries);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$DayTemplatesTableTableManager get dayTemplates =>
      $$DayTemplatesTableTableManager(_db, _db.dayTemplates);
  $$DayTemplateItemsTableTableManager get dayTemplateItems =>
      $$DayTemplateItemsTableTableManager(_db, _db.dayTemplateItems);
  $$DayScoresTableTableManager get dayScores =>
      $$DayScoresTableTableManager(_db, _db.dayScores);
  $$ProgressTableTableManager get progress =>
      $$ProgressTableTableManager(_db, _db.progress);
  $$BadgeUnlocksTableTableManager get badgeUnlocks =>
      $$BadgeUnlocksTableTableManager(_db, _db.badgeUnlocks);
  $$WeeklyRoundupsTableTableManager get weeklyRoundups =>
      $$WeeklyRoundupsTableTableManager(_db, _db.weeklyRoundups);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$CoachIntentsTableTableManager get coachIntents =>
      $$CoachIntentsTableTableManager(_db, _db.coachIntents);
  $$CoachReviewsTableTableManager get coachReviews =>
      $$CoachReviewsTableTableManager(_db, _db.coachReviews);
  $$CoachInsightsTableTableManager get coachInsights =>
      $$CoachInsightsTableTableManager(_db, _db.coachInsights);
}
