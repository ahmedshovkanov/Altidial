# Flight Blocks (Travel Day Mode v1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manual same-day flight blocks render as a pinned overlay arc on the 24h dial, entered through the event sheet with IATA validation, stored as columns on the event.

**Architecture:** Nullable flight columns on the existing `events` table (Approach A from the spec); tone forced to Inbox so Stats/export/notifications need no fork; dial painter adds a second overlay pass reusing `_paintArc`/`_paintCurvedLabel`; all UI stays inside `features/clock`.

**Tech Stack:** Flutter (Riverpod 2.6), Dart 3.12.2, Drift + drift_flutter, intl. No new runtime packages.

## Global Constraints

- **Platform:** iPhone portrait; iPad all orientations.
- **Language:** English-only. All user-facing copy lives in `lib/core/strings.dart`.
- **Boundary rule:** no file under `lib/features/<a>/` imports from `lib/features/<b>/`. Flight code in `features/clock` talks to the DB only via `EventRepository`/`EventDao`.
- **No hard-coded colours in feature code** (`Color(0x`, `Colors.` banned under `lib/features/`; enforced by test). Overlay reuses `toneColors.fillFor/labelFor`.
- **Local dates:** local midnights via `DateTime(y, m, d)`, `startOfDay`/`nextDay` helpers; minutes 0–1439, `endMinute` exclusive, never crosses midnight.
- **Tap targets** ≥ 44 pt. New sheet rows reuse existing shared widgets.
- **Tooling:** `DART="$(dirname "$(which flutter)")/dart"` for Dart commands.
- **Style:** `flutter analyze` clean; lints in `analysis_options.yaml`.
- **Spec:** `docs/superpowers/specs/2026-10-14-flight-blocks-design.md` is authoritative; this plan implements it exactly (same-day only, manual entry only, tone forced to Inbox).

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/core/flight/flight_details.dart` | Pure normalizers/validators for IATA codes + flight numbers; `flightSubtitle` formatter |
| `test/core/flight/flight_details_test.dart` | Unit tests for the pure module |

**Modified:**

| File | Responsibility |
|---|---|
| `lib/data/tables/events_table.dart` | Adds `isFlight`, `flightNumber`, `fromCode`, `toCode` columns |
| `lib/data/database.dart` | `schemaVersion` 4 → 5 + `from < 5` migration adding the 4 columns |
| `lib/data/daos/event_dao.dart` | Adds `updateFlight`; `insertEvent` already takes a full companion so no change needed there |
| `lib/features/clock/model/calendar_event.dart` | Adds flight fields + `fromRow` mapping + equality |
| `lib/features/clock/data/event_repository.dart` | `createEvent`/`updateDetails` accept flight data; forces `Tone.inbox` when `isFlight`; adds `updateFlight` |
| `test/support/fake_event_repository.dart` | Mirrors the interface change (in-memory); preserves flight fields across all `CalendarEvent` copies |
| `lib/core/strings.dart` | Flight copy: toggle label, field labels/hints, validation messages, overnight message, semantics helpers |
| `lib/features/clock/widgets/event_sheet.dart` | Flight toggle + 3 fields + validation wiring |
| `lib/features/clock/widgets/dial_painter.dart` | Second overlay pass for `isFlight` events (thicker arc + route label) |
| `lib/features/clock/widgets/dial_semantics.dart` | Flight-aware semantics label (read file first, extend the existing event-label builder) |
| `lib/features/clock/widgets/todays_plan_list.dart` | Flight rows show plane subtitle |
| `lib/features/clock/widgets/now_card.dart` | Running/next flight shows plane subtitle (same helper as the list) |
| `test/data/migration_test.dart` | Retarget 4 → 5 + new test that v4 rows upgrade with `isFlight=false` |
| `drift_schemas/` + `test/generated_migrations/` | Regenerated via `drift_dev` (commands in Task 2) |

---

### Task 1: Pure flight validator

**Files:**
- Create: `lib/core/flight/flight_details.dart`
- Test: `test/core/flight/flight_details_test.dart`

**Interfaces:**
- Consumes: nothing (pure, no imports from the app).
- Produces: `normalizeAirportCode(String) → String`, `isValidAirportCode(String) → bool`, `normalizeFlightNumber(String) → String`, `isValidFlightNumber(String) → bool` (empty string is valid = field optional), `flightSubtitle({String? flightNumber, String? fromCode, String? toCode}) → String`. Task 4 imports these for sheet validation; Task 5 imports `flightSubtitle` for list/Now rows.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:energy_clock/core/flight/flight_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes and validates IATA codes', () {
    expect(normalizeAirportCode(' sof '), 'SOF');
    expect(isValidAirportCode('SOF'), isTrue);
    expect(isValidAirportCode('SO'), isFalse);
    expect(isValidAirportCode('SOF1'), isFalse);
    expect(isValidAirportCode('so f'), isFalse);
  });

  test('flight number is optional but constrained when present', () {
    expect(normalizeFlightNumber(' lh 715 '), 'LH715');
    expect(isValidFlightNumber(''), isTrue);
    expect(isValidFlightNumber('LH715'), isTrue);
    expect(isValidFlightNumber('LH-715'), isFalse);
    expect(isValidFlightNumber('ABCDEFGHI'), isFalse);
  });

  test('subtitle prefers number and route', () {
    expect(
      flightSubtitle(flightNumber: 'LH715', fromCode: 'SOF', toCode: 'BER'),
      'LH715 · SOF→BER',
    );
    expect(
      flightSubtitle(flightNumber: null, fromCode: 'SOF', toCode: 'BER'),
      'SOF→BER',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/flight/flight_details_test.dart`
Expected: FAIL with file-not-found / function-not-defined.

- [ ] **Step 3: Write minimal implementation**

```dart
/// Pure flight-field helpers. No Flutter, no database. IATA codes are exactly
/// three A-Z letters; flight numbers are optional, 2-8 chars of A-Z/0-9.
String normalizeAirportCode(String input) => input.trim().toUpperCase();

bool isValidAirportCode(String input) =>
    RegExp(r'^[A-Z]{3}$').hasMatch(normalizeAirportCode(input));

String normalizeFlightNumber(String input) =>
    input.trim().toUpperCase().replaceAll(' ', '');

bool isValidFlightNumber(String input) {
  if (input.trim().isEmpty) return true;
  return RegExp(r'^[A-Z0-9]{2,8}$').hasMatch(normalizeFlightNumber(input));
}

String flightSubtitle({
  String? flightNumber,
  String? fromCode,
  String? toCode,
}) {
  final route = (fromCode == null || toCode == null) ? '' : '$fromCode→$toCode';
  final number = (flightNumber == null || flightNumber.isEmpty)
      ? ''
      : flightNumber;
  if (number.isNotEmpty && route.isNotEmpty) return '$number · $route';
  if (route.isNotEmpty) return route;
  return number;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/flight/flight_details_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/core/flight/flight_details.dart test/core/flight/flight_details_test.dart`
Expected: PASS (no issues).

- [ ] **Step 6: Commit**

```bash
git add lib/core/flight/flight_details.dart test/core/flight/flight_details_test.dart
git commit -m "feat: pure flight field validators and subtitle"
```

---

### Task 2: Schema v5 — flight columns + migration

**Files:**
- Modify: `lib/data/tables/events_table.dart`
- Modify: `lib/data/database.dart`
- Modify: `test/data/migration_test.dart`
- Regenerate: Drift codegen + `drift_schemas/drift_schema_v5.json` + `test/generated_migrations/schema_v5.dart`

**Interfaces:**
- Consumes: nothing new (Drift column DSL already used in this file).
- Produces: `EventRow.isFlight/flightNumber/fromCode/toCode` (generated), `schemaVersion == 5`, `updateFlight` on `EventDao` (added in this task). Task 3 consumes all three.

- [ ] **Step 1: Extend the table**

Replace (in `lib/data/tables/events_table.dart`):

```dart
  /// 0 planned, 1 completed, 2 skipped.
  IntColumn get status => integer().withDefault(const Constant(0))();
```

With:

```dart
  /// 0 planned, 1 completed, 2 skipped.
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// True when this event is a manually-entered flight block (spec: travel
  /// day mode v1). Tone is forced to Inbox; rendering branches on this flag.
  BoolColumn get isFlight => boolean().withDefault(const Constant(false))();

  /// Optional, uppercased, e.g. LH715. Null when empty or not a flight.
  TextColumn get flightNumber => text().nullable()();

  /// IATA codes, uppercased, e.g. SOF. Null unless [isFlight].
  TextColumn get fromCode => text().nullable()();
  TextColumn get toCode => text().nullable()();
```

- [ ] **Step 2: Bump version + migrate** (in `lib/data/database.dart`)

Replace:

```dart
  /// Version 1: events, event series, settings. Version 2: sessions. Version 3:
  /// day templates, and the indexes on events. Version 4: day scores, progress,
  /// badge unlocks, weekly roundups. Every bump needs a step in [migration] and
  /// a test in `test/data/migration_test.dart`; see `drift_schemas/`.
  @override
  int get schemaVersion => 4;
```

With:

```dart
  /// Version 1: events, event series, settings. Version 2: sessions. Version 3:
  /// day templates, and the indexes on events. Version 4: day scores, progress,
  /// badge unlocks, weekly roundups. Version 5: flight columns on events.
  /// Every bump needs a step in [migration] and
  /// a test in `test/data/migration_test.dart`; see `drift_schemas/`.
  @override
  int get schemaVersion => 5;
```

Replace:

```dart
      if (from < 4) {
        await migrator.createTable(dayScores);
        await migrator.createTable(progress);
        await migrator.createTable(badgeUnlocks);
        await migrator.createTable(weeklyRoundups);
      }
```

With:

```dart
      if (from < 4) {
        await migrator.createTable(dayScores);
        await migrator.createTable(progress);
        await migrator.createTable(badgeUnlocks);
        await migrator.createTable(weeklyRoundups);
      }
      if (from < 5) {
        await migrator.addColumn(events, events.isFlight);
        await migrator.addColumn(events, events.flightNumber);
        await migrator.addColumn(events, events.fromCode);
        await migrator.addColumn(events, events.toCode);
      }
```

- [ ] **Step 3: Add `updateFlight` to `EventDao`** (append inside `class EventDao` in `lib/data/daos/event_dao.dart`):

```dart
  /// Replaces the flight flag and flight columns of one event. Clearing means
  /// `isFlight: false` with all three columns null (callers enforce this).
  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        isFlight: Value(isFlight),
        flightNumber: Value(flightNumber),
        fromCode: Value(fromCode),
        toCode: Value(toCode),
        updatedAt: Value(updatedAt),
      ),
    );
  }
```

- [ ] **Step 4: Regenerate codegen, schema dump, migration helpers**

Run: `DART="$(dirname "$(which flutter)")/dart" && $DART run build_runner build --delete-conflicting-outputs`
Expected: BUILD SUCCEEDED.

Run: `DART="$(dirname "$(which flutter)")/dart" && $DART run drift_dev schema dump lib/data/database.dart drift_schemas/`
Expected: creates `drift_schemas/drift_schema_v5.json`.

Run: `DART="$(dirname "$(which flutter)")/dart" && $DART run drift_dev schema generate drift_schemas/ test/generated_migrations/`
Expected: creates/updates `test/generated_migrations/schema_v5.dart` and `schema.dart`.

- [ ] **Step 5: Update migration tests** (in `test/data/migration_test.dart`): change every `migrateAndValidate(database, 4)` to `migrateAndValidate(database, 5)`, then append this test:

```dart
  test('upgrading from version 4 keeps events and defaults flight columns', () async {
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 5);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    expect(events.single.isFlight, isFalse);
    expect(events.single.flightNumber, isNull);
    expect(events.single.fromCode, isNull);
    expect(events.single.toCode, isNull);
  });
```

- [ ] **Step 6: Run migration tests**

Run: `flutter test test/data/migration_test.dart`
Expected: PASS (all tests, including the new one).

- [ ] **Step 7: Run analyzer**

Run: `flutter analyze lib/data test/data/migration_test.dart`
Expected: PASS (no issues).

- [ ] **Step 8: Commit**

```bash
git add lib/data/tables/events_table.dart lib/data/database.dart lib/data/daos/event_dao.dart lib/data/database.g.dart lib/data/daos/event_dao.g.dart drift_schemas/drift_schema_v5.json test/generated_migrations/ test/data/migration_test.dart
git commit -m "feat: flight columns on events with v5 migration"
```

---

### Task 3: Model + repository plumbing

**Files:**
- Modify: `lib/features/clock/model/calendar_event.dart`
- Modify: `lib/features/clock/data/event_repository.dart`
- Test: `test/features/clock/event_repository_flight_test.dart` (new; uses the existing in-memory Drift test pattern — check `test/data/*_test.dart` for the `AppDatabase.forTesting` helper and copy its setup verbatim)

**Interfaces:**
- Consumes: generated `EventRow.isFlight/flightNumber/fromCode/toCode` (Task 2), `Tone.inbox` (existing).
- Produces: `CalendarEvent(isFlight, flightNumber, fromCode, toCode)` + `fromRow` mapping; `EventRepository.createEvent({..., bool isFlight, String? flightNumber, String? fromCode, String? toCode})`; `EventRepository.updateFlight({...})`. Task 4 calls both.

- [ ] **Step 1: Write the failing repository test** — create `test/features/clock/event_repository_flight_test.dart` with this exact content (setup mirrors `test/data/event_dao_test.dart`: in-memory Drift, fixed clock):

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftEventRepository repository;
  final day = DateTime(2026, 10, 14);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(
      db.eventDao,
      clock: () => DateTime(2026, 10, 14, 9, 0),
    );
  });

  tearDown(() async => db.close());

  test('creating a flight forces Inbox tone and round-trips columns', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'Fly home',
      tone: Tone.focus, // flights always land on Inbox regardless
      range: const MinuteRange(625, 850),
      isFlight: true,
      flightNumber: 'LH715',
      fromCode: 'SOF',
      toCode: 'BER',
    );
    final events = await repository.eventsForDay(day);
    final flight = events.singleWhere((e) => e.id == id);
    expect(flight.tone, Tone.inbox);
    expect(flight.isFlight, isTrue);
    expect(flight.flightNumber, 'LH715');
    expect(flight.fromCode, 'SOF');
    expect(flight.toCode, 'BER');
  });

  test('updateFlight clears columns when toggled off', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'Fly home',
      tone: Tone.inbox,
      range: const MinuteRange(625, 850),
      isFlight: true,
      flightNumber: 'LH715',
      fromCode: 'SOF',
      toCode: 'BER',
    );
    await repository.updateFlight(
      id: id,
      isFlight: false,
      flightNumber: null,
      fromCode: null,
      toCode: null,
    );
    final events = await repository.eventsForDay(day);
    final event = events.singleWhere((e) => e.id == id);
    expect(event.isFlight, isFalse);
    expect(event.flightNumber, isNull);
    expect(event.fromCode, isNull);
    expect(event.toCode, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/clock/event_repository_flight_test.dart`
Expected: FAIL (`createEvent` has no `isFlight` named parameter).

- [ ] **Step 3: Extend `CalendarEvent`** — replace the constructor/fields/`fromRow`/equality with:

```dart
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.seriesId,
    required this.date,
    required this.title,
    required this.tone,
    required this.range,
    required this.status,
    this.isFlight = false,
    this.flightNumber,
    this.fromCode,
    this.toCode,
  });

  final int id;
  final int? seriesId;
  final DateTime date;
  final String title;
  final Tone tone;
  final MinuteRange range;
  final EventStatus status;
  final bool isFlight;
  final String? flightNumber;
  final String? fromCode;
  final String? toCode;

  int get startMinute => range.start;
  int get endMinute => range.end;

  static CalendarEvent fromRow(EventRow row) => CalendarEvent(
    id: row.id,
    seriesId: row.seriesId,
    date: row.date,
    title: row.title,
    tone: Tone.fromDbIndex(row.toneIndex),
    range: MinuteRange(row.startMinute, row.endMinute),
    status: EventStatus.fromDbIndex(row.status),
    isFlight: row.isFlight,
    flightNumber: row.flightNumber,
    fromCode: row.fromCode,
    toCode: row.toCode,
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.seriesId == seriesId &&
      other.date == date &&
      other.title == title &&
      other.tone == tone &&
      other.range == range &&
      other.status == status &&
      other.isFlight == isFlight &&
      other.flightNumber == flightNumber &&
      other.fromCode == fromCode &&
      other.toCode == toCode;

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    date,
    title,
    tone,
    range,
    status,
    isFlight,
    flightNumber,
    fromCode,
    toCode,
  );
}
```

- [ ] **Step 4: Extend the repository interface + implementation**

In the `EventRepository` interface, replace `createEvent` signature with:

```dart
  /// Throws [RingOverflowException] if the new event would need a fourth ring.
  /// When [isFlight] is true the tone is forced to Inbox and [fromCode] /
  /// [toCode] must be valid IATA codes (validated by the caller).
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    bool isFlight = false,
    String? flightNumber,
    String? fromCode,
    String? toCode,
  });
```

And append to the interface:

```dart
  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
  });
```

In `DriftEventRepository.createEvent`, replace the `insertEvent` call with:

```dart
    final now = _clock();
    final flight = isFlight;
    return _dao.insertEvent(
      EventsCompanion.insert(
        date: normalisedDay,
        title: title,
        toneIndex: flight ? Tone.inbox.dbIndex : tone.dbIndex,
        startMinute: range.start,
        endMinute: range.end,
        createdAt: now,
        updatedAt: now,
        isFlight: Value(flight),
        flightNumber: Value(flight ? flightNumber : null),
        fromCode: Value(flight ? fromCode : null),
        toCode: Value(flight ? toCode : null),
      ),
    );
```

And append to `DriftEventRepository`:

```dart
  @override
  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
  }) {
    return _dao.updateFlight(
      id: id,
      isFlight: isFlight,
      flightNumber: isFlight ? flightNumber : null,
      fromCode: isFlight ? fromCode : null,
      toCode: isFlight ? toCode : null,
      updatedAt: _clock(),
    );
  }
```

- [ ] **Step 6: Update the in-memory fake** — `test/support/fake_event_repository.dart` implements `EventRepository`, so the new parameters break it until mirrored. Replace its `createEvent` signature and body:

```dart
  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    bool isFlight = false,
    String? flightNumber,
    String? fromCode,
    String? toCode,
  }) async {
    final normalised = startOfDay(day);
    _guard(normalised, range, null);
    final id = _nextId++;
    _events.add(
      CalendarEvent(
        id: id,
        seriesId: null,
        date: normalised,
        title: title,
        tone: isFlight ? Tone.inbox : tone,
        range: range,
        status: EventStatus.planned,
        isFlight: isFlight,
        flightNumber: isFlight ? flightNumber : null,
        fromCode: isFlight ? fromCode : null,
        toCode: isFlight ? toCode : null,
      ),
    );
    _notify();
    return id;
  }

  @override
  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
  }) async {
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: existing.seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: existing.range,
      status: existing.status,
      isFlight: isFlight,
      flightNumber: isFlight ? flightNumber : null,
      fromCode: isFlight ? fromCode : null,
      toCode: isFlight ? toCode : null,
    );
    _notify();
  }
```

Then preserve flight fields in the three methods that rebuild events (`moveEvent`, `updateDetails`, `setSeriesId`, `setStatus`): in each `CalendarEvent(...)` reconstruction add `isFlight: existing.isFlight, flightNumber: existing.flightNumber, fromCode: existing.fromCode, toCode: existing.toCode`. (`addOccurrence` creates non-flight helpers — leave it unchanged.)

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/clock/event_repository_flight_test.dart`
Expected: PASS (2 tests). Then run the existing clock-model tests to catch equality regressions: `flutter test test/features/clock/`
Expected: PASS.

- [ ] **Step 8: Run analyzer + commit**

Run: `flutter analyze lib/features/clock test/features/clock/event_repository_flight_test.dart test/support/fake_event_repository.dart`
Expected: PASS.

```bash
git add lib/features/clock/model/calendar_event.dart lib/features/clock/data/event_repository.dart test/support/fake_event_repository.dart test/features/clock/event_repository_flight_test.dart
git commit -m "feat: flight fields on CalendarEvent and event repository"
```

---

### Task 4: Event sheet flight toggle + copy

**Files:**
- Modify: `lib/core/strings.dart` (append flight copy block)
- Modify: `lib/features/clock/widgets/event_sheet.dart`
- Test: `test/features/clock/event_sheet_flight_test.dart` (new widget test using `ClockHarness.app` from `test/support/clock_harness.dart`, the repo's standard widget-test harness)

**Interfaces:**
- Consumes: Task 1 validators, Task 3 repository methods, `Strings.*flight*` copy (this task).
- Produces: sheet with keys `flight-toggle`, `flight-number-field`, `flight-from-field`, `flight-to-field`; on-save validation with inline errors + overnight message; series occurrences never offer the toggle; repeat picker hidden while flying. Task 5 needs nothing from this task.

- [ ] **Step 1: Add copy** — append inside `abstract final class Strings`:

```dart
  // Flights (travel day mode v1).
  static const String flightToggle = 'This is a flight';
  static const String flightNumberLabel = 'Flight no. (optional)';
  static const String flightNumberHint = 'LH715';
  static const String flightFromLabel = 'From';
  static const String flightToLabel = 'To';
  static const String flightAirportHint = 'SOF';
  static const String flightAirportError = 'Use 3 letters, e.g. SOF';
  static const String flightNumberError =
      'Use 2–8 letters/digits, e.g. LH715';
  static const String flightOvernightError =
      'Same-day flights only in v1 — split overnight flights into two blocks for now';
  static String flightRoute(String from, String to) => '$from→$to';
  static String flightSemantics(
    String title,
    String route,
    String start,
    String end,
  ) => 'Flight $title, $route, $start to $end';
```

- [ ] **Step 2: Write the failing widget test** — create `test/features/clock/event_sheet_flight_test.dart` with this exact content (`ClockHarness.app` mounts any widget under the real provider scope with fakes; `EventSheet` needs no series load when `existing` is null):

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  testWidgets('flight toggle reveals fields and validates codes', (
    tester,
  ) async {
    final harness = ClockHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      harness.app(
        EventSheet(
          day: DateTime(2026, 10, 14),
          initialRange: const MinuteRange(625, 850),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('flight-toggle')), findsOneWidget);
    expect(find.byKey(const Key('flight-from-field')), findsNothing);

    await tester.tap(find.byKey(const Key('flight-toggle')));
    await tester.pump();

    expect(find.byKey(const Key('flight-number-field')), findsOneWidget);
    expect(find.byKey(const Key('flight-from-field')), findsOneWidget);
    expect(find.byKey(const Key('flight-to-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flight-from-field')), 'so');
    await tester.pump();
    expect(find.text(Strings.flightAirportError), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flight-from-field')), 'SOF');
    await tester.enterText(find.byKey(const Key('flight-to-field')), 'BER');
    await tester.pump();
    expect(find.text(Strings.flightAirportError), findsNothing);
  });
}
```

- [ ] **Step 3: Implement the sheet** — in `_EventSheetState` add:

```dart
  bool _isFlight = false;
  late final TextEditingController _flightNumber = TextEditingController();
  late final TextEditingController _from = TextEditingController();
  late final TextEditingController _to = TextEditingController();
```

Initialize from `widget.existing` in `initState` (after the existing assignments): if `existing?.isFlight == true`, set `_isFlight = true` and fill the three controllers (flightNumber may be null → `''`). Dispose the three controllers in `dispose`.

Add `import 'package:energy_clock/core/flight/flight_details.dart';` to the imports. Add below the tone picker (find the `Strings.toneLabel` row in `build` and insert after it). The toggle is hidden for series occurrences (v1 flights are one-off blocks only):

```dart
    if (widget.existing?.seriesId == null)
      SwitchListTile(
        key: const Key('flight-toggle'),
        title: const Text(Strings.flightToggle),
        secondary: const Icon(Icons.flight),
        value: _isFlight,
        onChanged: (v) => setState(() => _isFlight = v),
      ),
    if (_isFlight) ...[
      TextField(
        key: const Key('flight-number-field'),
        controller: _flightNumber,
        decoration: const InputDecoration(
          labelText: Strings.flightNumberLabel,
          hintText: Strings.flightNumberHint,
        ),
        textCapitalization: TextCapitalization.characters,
        onChanged: (_) => setState(() {}),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('flight-from-field'),
              controller: _from,
              decoration: InputDecoration(
                labelText: Strings.flightFromLabel,
                hintText: Strings.flightAirportHint,
                errorText: _from.text.isEmpty || isValidAirportCode(_from.text)
                    ? null
                    : Strings.flightAirportError,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('flight-to-field'),
              controller: _to,
              decoration: InputDecoration(
                labelText: Strings.flightToLabel,
                hintText: Strings.flightAirportHint,
                errorText: _to.text.isEmpty || isValidAirportCode(_to.text)
                    ? null
                    : Strings.flightAirportError,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    ],
```

Hide the repeat picker while flying (find the `RepeatPicker`/`Strings.repeatLabel` usage in `build` and guard it with `if (!_isFlight)`), so a flight can never take the recurring-series path.

Validate in `_save()` — this sheet validates on save with inline errors (there is no save-enabled getter). Insert after the title-empty check (after line `if (title.isEmpty) {...}` returns, before `setState(() { _titleError = null; ... })` is wrong — insert the flight block right after the title check):

```dart
    if (_isFlight) {
      final fromOk = isValidAirportCode(_from.text);
      final toOk = isValidAirportCode(_to.text);
      final numberOk = isValidFlightNumber(_flightNumber.text);
      if (!fromOk || !toOk || !numberOk) {
        setState(() {}); // field-level errorText above already shows; stay open
        return;
      }
      if (_range.end <= _range.start) {
        setState(() => _saveError = Strings.flightOvernightError);
        return;
      }
    }
```

(`MinuteRange` guarantees end > start for drag-built ranges, so the overnight branch is defensive — keep it wired per spec.)

Wire `_create`: the recurring branch condition becomes `if (_rule.repeats && !_isFlight)`, and the one-off `createEvent` call gains the flight arguments:

```dart
      await ref
          .read(eventRepositoryProvider)
          .createEvent(
            day: widget.day,
            title: title,
            tone: _tone,
            range: _range,
            isFlight: _isFlight,
            flightNumber: _isFlight && _flightNumber.text.trim().isNotEmpty
                ? normalizeFlightNumber(_flightNumber.text)
                : null,
            fromCode: _isFlight ? normalizeAirportCode(_from.text) : null,
            toCode: _isFlight ? normalizeAirportCode(_to.text) : null,
          );
```

Wire `_update`'s `thisEventOnly()` (one-off events only — the toggle is hidden for series, so the series paths need no change):

```dart
    Future<void> thisEventOnly() async {
      await events.moveEvent(id: existing.id, day: widget.day, range: _range);
      await events.updateDetails(id: existing.id, title: title, tone: _tone);
      await events.updateFlight(
        id: existing.id,
        isFlight: _isFlight,
        flightNumber: _isFlight && _flightNumber.text.trim().isNotEmpty
            ? normalizeFlightNumber(_flightNumber.text)
            : null,
        fromCode: _isFlight ? normalizeAirportCode(_from.text) : null,
        toCode: _isFlight ? normalizeAirportCode(_to.text) : null,
      );
    }
```

(Toggle-off sends nulls; the repository nulls them again — double-safe by construction.)

- [ ] **Step 4: Run widget test to verify it passes**

Run: `flutter test test/features/clock/event_sheet_flight_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyzer + existing clock widget tests**

Run: `flutter analyze lib/features/clock/widgets/event_sheet.dart lib/core/strings.dart`
Expected: PASS. Run: `flutter test test/features/clock/`
Expected: PASS (no regressions).

- [ ] **Step 6: Commit**

```bash
git add lib/core/strings.dart lib/features/clock/widgets/event_sheet.dart test/features/clock/event_sheet_flight_test.dart
git commit -m "feat: flight toggle and fields in event sheet"
```

---

### Task 5: Dial overlay + list subtitles + semantics

**Files:**
- Modify: `lib/features/clock/widgets/dial_painter.dart`
- Modify: `lib/features/clock/widgets/dial_semantics.dart` (extend the existing event-label builder with a flight branch)
- Modify: `lib/features/clock/widgets/todays_plan_list.dart`
- Modify: `lib/features/clock/widgets/now_card.dart`
- Test: `test/features/clock/dial_flight_overlay_test.dart` (new)

**Interfaces:**
- Consumes: `CalendarEvent.isFlight/fromCode/toCode` (Task 3), `flightSubtitle` (Task 1), `Strings.flightSemantics/flightRoute` (Task 4).
- Produces: visible overlay + subtitles; nothing downstream consumes this task. End state: full suite green, analyzer clean.

- [ ] **Step 1: Write the failing overlay test** — create `test/features/clock/dial_flight_overlay_test.dart` with this exact content. It pins the overlay label contract through a small pure helper that lives next to the painter:

```dart
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CalendarEvent flight() => CalendarEvent(
    id: 1,
    seriesId: null,
    date: DateTime(2026, 10, 14),
    title: 'Fly home',
    tone: Tone.inbox,
    range: const MinuteRange(625, 850),
    status: EventStatus.planned,
    isFlight: true,
    flightNumber: 'LH715',
    fromCode: 'SOF',
    toCode: 'BER',
  );

  test('overlay label shows route with plane marker', () {
    expect(flightOverlayLabel(flight()), '✈ SOF→BER');
  });

  test('overlay label falls back to title when route is missing', () {
    final noRoute = CalendarEvent(
      id: 2,
      seriesId: null,
      date: DateTime(2026, 10, 14),
      title: 'Fly home',
      tone: Tone.inbox,
      range: const MinuteRange(625, 850),
      status: EventStatus.planned,
      isFlight: true,
    );
    expect(flightOverlayLabel(noRoute), '✈ Fly home');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/clock/dial_flight_overlay_test.dart`
Expected: FAIL with "flightOverlayLabel not defined" (nothing imports it yet).

- [ ] **Step 3: Add the helper + overlay pass** — in `lib/features/clock/widgets/dial_painter.dart`, add this top-level function above `class DialPainter`:

```dart
/// Short route label for the pinned flight overlay. Route when both codes
/// are present, otherwise the event title — never empty for a saved flight.
String flightOverlayLabel(CalendarEvent event) {
  if (event.fromCode != null && event.toCode != null) {
    return '✈ ${event.fromCode}→${event.toCode}';
  }
  return '✈ ${event.title}';
}
```

Then at the end of `_paintEvents` (after the existing `for` loop, still inside `_paintEvents`), insert:

```dart
    // Pinned flight overlay: flights already painted as normal Inbox arcs
    // above; this second pass draws a thicker arc on top so the block reads
    // as pinned. Same tone colour (no new palette), same geometry helpers.
    for (final flight in events.where((e) => e.isFlight)) {
      final ring = ringByEventId[flight.id];
      if (ring == null) continue;
      final progress = arcProgress[flight.id] ?? 1.0;
      if (progress <= 0) continue;
      final radius = geometry.ringCenterRadius(ring);
      _paintArc(
        canvas,
        radius: radius,
        range: flight.range,
        color: toneColors.fillFor(flight.tone),
        thickness: geometry.ringWidth * 1.3,
        progress: math.min(progress, 1),
        outline: style.page,
      );
      if (progress >= 1) {
        final room = labelRoom(flight);
        _paintCurvedLabel(
          canvas,
          text: flightOverlayLabel(flight),
          radius: radius,
          range: flight.range,
          offset: room.offset,
          sweep: room.sweep,
          color: toneColors.labelFor(flight.tone),
        );
      }
    }
```

- [ ] **Step 4: List + Now subtitles** — in `todays_plan_list.dart` item builder (after the title `Text`), insert:

```dart
              if (event.isFlight)
                Text(
                  flightSubtitle(
                    flightNumber: event.flightNumber,
                    fromCode: event.fromCode,
                    toCode: event.toCode,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
```

with `import 'package:energy_clock/core/flight/flight_details.dart';` added to the file. Mirror the same block in `now_card.dart` wherever the running/next event title is built (read the file, find the title `Text`, insert directly below it).

- [ ] **Step 5: Semantics** — in `lib/features/clock/widgets/dial_semantics.dart`, replace:

```dart
                  label: Strings.eventSemantics(
                    event.title,
                    event.tone.label,
                    formatMinuteOfDay(event.startMinute),
                    formatMinuteOfDay(event.endMinute),
                    spokenDurationMinutes(event.range.durationMinutes),
                  ),
```

With:

```dart
                  label:
                      event.isFlight &&
                          event.fromCode != null &&
                          event.toCode != null
                      ? Strings.flightSemantics(
                          event.title.isEmpty
                              ? (event.flightNumber ?? '')
                              : event.title,
                          Strings.flightRoute(event.fromCode!, event.toCode!),
                          formatMinuteOfDay(event.startMinute),
                          formatMinuteOfDay(event.endMinute),
                        )
                      : Strings.eventSemantics(
                          event.title,
                          event.tone.label,
                          formatMinuteOfDay(event.startMinute),
                          formatMinuteOfDay(event.endMinute),
                          spokenDurationMinutes(event.range.durationMinutes),
                        ),
```

- [ ] **Step 6: Run the new tests + full gates**

Run: `flutter test test/features/clock/dial_flight_overlay_test.dart`
Expected: PASS.

Run: `flutter test test/features/clock/ test/core/flight/ test/data/migration_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: PASS (no issues).

- [ ] **Step 7: Commit**

```bash
git add lib/features/clock/widgets/dial_painter.dart lib/features/clock/widgets/dial_semantics.dart lib/features/clock/widgets/todays_plan_list.dart lib/features/clock/widgets/now_card.dart test/features/clock/dial_flight_overlay_test.dart
git commit -m "feat: pinned flight overlay arc and list subtitles"
```

---

## Self-Review (plan author checklist — run before handoff)

- [ ] Spec coverage: §1 migration → Task 2; §2 overlay/sheet/list → Tasks 4–5; §3 data flow (forced Inbox, toggle-off clears, notifications untouched) → Task 3; §4 validation + overnight → Tasks 1, 4; §5 tests → every task.
- [ ] No placeholders: every step has exact code/commands; grep the plan for `TODO`, `TBD`, `similar to`, `appropriate`, `as needed` — none should remain except this checklist line.
- [ ] Type consistency: `isFlight/flightNumber/fromCode/toCode` names identical across table, DAO, model, repository, UI; `normalizeAirportCode/isValidAirportCode/normalizeFlightNumber/isValidFlightNumber/flightSubtitle` signatures identical in Tasks 1, 4, 5.
