# Flight Deck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5th tab, Flight Deck, that lists the user's flights (read from existing flight events) with a next-flight hero plus an offline calm kit (facts/tips cards with favorites, breathing timer, grounding stepper) for aerophobia.

**Architecture:** Light aggregator, no DB migration. New `lib/features/flight_deck/` module reads flights through a new range stream on the existing `EventRepository` (the spec's `calendar_repository` only returns tone-minutes, so this plan adds `watchFlights`; see deviation note), stores favorites as a comma-joined string in the existing settings repo, bundles calm content as `const` Dart, and wires a 5th tab through the existing `TabScaffold`/`AppTabBar` kept-alive pattern.

**Tech Stack:** Flutter, flutter_riverpod 2.x, Drift (existing tables only, no migration), flutter_test.

## Spec deviation (planning finding)

The spec says Flight Deck reads flights from `calendar_repository`. That repository's only API is `watchMonth`, which returns `Map<DateTime, ToneMinutes>` — no titles, times, or flight columns. The full event stream the Deck needs does not exist for ranges (`EventDao` has day-streams plus a `Future` `eventsBetween`). So Task 1 adds `EventDao.watchRange` (a `.watch()` stream, no codegen needed) and `EventRepository.watchFlights` (normalises days, runs the series materialiser, filters `isFlight` client-side per the spec). The spec doc should be amended with one line under §3: "Flights are read via `EventRepository.watchFlights`, not `calendar_repository`."

## Global Constraints

- Offline-first, no backend, no network calls, no new Drift tables or schema changes.
- Features never import each other; Flight Deck imports only `data/`, `core/`, `app/`, `shared/`.
- Never hard-code a colour: use `context.appColors` / `context.toneColors` / `AppColors.transparent` only (enforced by `test/architecture/no_hardcoded_colors_test.dart`).
- All user-facing copy lives in `lib/core/strings.dart`; English-only.
- Runs on iPhone portrait and iPad all orientations; reuse the existing adaptive shell (`ContentWidth`, `TabBarInset`), no custom iPad layout.
- Gates for every task: `flutter analyze` clean, `flutter test <touched paths>` green.

---

## File structure

New files (all under `lib/features/flight_deck/` and `test/features/flight_deck/`):

- `lib/features/flight_deck/calm_content.dart` — `CalmKind` enum, `CalmCard` value type, `const calmCards` list (10 facts + 8 tips). One responsibility: bundled content.
- `lib/features/flight_deck/flight_sort.dart` — pure `FlightSplit` + `splitFlights(events, now)`. One responsibility: upcoming/past/next selection.
- `lib/features/flight_deck/favorites_codec.dart` — `encodeFavorites(Set<String>)` / `decodeFavorites(String?)`. One responsibility: settings-string serialisation.
- `lib/features/flight_deck/providers.dart` — `deckNowProvider` (minute ticker), `deckFlightsProvider` (range stream + split), `flightDeckFavoritesProvider` (favorites notifier). One responsibility: Deck state.
- `lib/features/flight_deck/widgets/calm_card_view.dart` — `CalmCardView` + `CalmFilterChips`. One responsibility: card rendering.
- `lib/features/flight_deck/widgets/breathing_timer.dart` — `BreathingTimer`. One responsibility: breathing exercise.
- `lib/features/flight_deck/widgets/grounding_steps.dart` — `GroundingSteps`. One responsibility: 5-4-3-2-1 exercise.
- `lib/features/flight_deck/widgets/next_flight_hero.dart` — `NextFlightHero`. One responsibility: hero rendering.
- `lib/features/flight_deck/widgets/flights_list.dart` — `FlightsList`. One responsibility: grouped flight rows.
- `lib/features/flight_deck/flight_deck_screen.dart` — `FlightDeckScreen(onOpenDay:)`. One responsibility: tab assembly.

Modified files:

- `lib/data/daos/event_dao.dart` — add `watchRange`.
- `lib/features/clock/data/event_repository.dart` — add `watchFlights` to interface + impl.
- `lib/data/providers.dart` — add moved `eventRepositoryProvider`.
- `lib/features/clock/providers.dart` — remove `eventRepositoryProvider` definition (consumers keep working via new import).
- `lib/core/time/day_time.dart` — add moved `untilNextMinute`.
- `lib/core/strings.dart` — add Deck copy.
- `lib/app/navigation/app_tab_bar.dart`, `lib/app/navigation/tab_scaffold.dart` — 5th tab.
- `test/support/fake_event_repository.dart` — add `watchFlights`.
- Existing tests asserting 4 tabs — updated in Task 6 (enumerated via `rg` in a step).

---

### Task 1: Range flight stream + provider move

**Files:**
- Modify: `lib/data/daos/event_dao.dart`
- Modify: `lib/features/clock/data/event_repository.dart`
- Modify: `lib/data/providers.dart`
- Modify: `lib/features/clock/providers.dart` (delete moved provider, keep the rest)
- Modify: every file that imports `eventRepositoryProvider` from clock providers (re-point import at `data/providers.dart`)
- Modify: `test/support/fake_event_repository.dart`
- Test: `test/data/event_dao_range_test.dart` (new)
- Test: `test/features/clock/event_repository_flights_test.dart` (new)

**Interfaces:**
- Consumes: `EventRow` (Drift, existing), `SeriesMaterialiser.materialise` (existing), `startOfDay`/`nextDay` from `core/time/day_time.dart`.
- Produces: `EventDao.watchRange(DateTime from, DateTime toExclusive) -> Stream<List<EventRow>>`; `EventRepository.watchFlights(DateTime from, DateTime toExclusive) -> Stream<List<CalendarEvent>>` (only `isFlight` rows, ordered by date then startMinute); `eventRepositoryProvider` (same type, new home in `data/providers.dart`).

- [ ] **Step 1: Write the failing DAO test**

```dart
// test/data/event_dao_range_test.dart
import 'package:drift/drift.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';

void main() {
  test('watchRange emits only in-range rows, ordered by date then start', () async {
    final harness = TestClockHarness();
    addTearDown(harness.close);
    final dao = harness.db.eventDao;
    final now = DateTime(2026, 10, 14, 12);
    Future<int> insert(DateTime date, int start, {bool flight = false}) =>
        dao.insertEvent(EventsCompanion.insert(
          date: date,
          title: flight ? 'Flight' : 'Work',
          toneIndex: 2,
          startMinute: start,
          endMinute: start + 60,
          createdAt: now,
          updatedAt: now,
          isFlight: Value(flight),
        ));
    await insert(DateTime(2026, 10, 10), 600, flight: true);
    await insert(DateTime(2026, 10, 14), 900, flight: true);
    await insert(DateTime(2026, 10, 14), 300, flight: true);
    await insert(DateTime(2026, 10, 20), 600);

    final rows = await dao
        .watchRange(DateTime(2026, 10, 12), DateTime(2026, 10, 18))
        .first;
    expect(rows.map((r) => r.startMinute), [300, 900]);
    expect(rows.every((r) => r.date == DateTime(2026, 10, 14)), isTrue);
  });
}
```

Note: check `test/support/clock_harness.dart` first; if its helper names differ (db accessor, close method), use the real ones — the fake above shows intent. If no harness fits, follow the setup in `test/data/event_dao_test.dart` exactly.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/event_dao_range_test.dart`
Expected: FAIL with "method 'watchRange' isn't defined for the class 'EventDao'" (or harness-name error first — fix names, re-run, confirm the watchRange error).

- [ ] **Step 3: Add `watchRange` to `EventDao`**

In `lib/data/daos/event_dao.dart`, after `eventsBetween`:

```dart
  /// Every non-deleted event in `[from, toExclusive)`, oldest first, as a
  /// stream. Feeds range readers such as the Flight Deck.
  Stream<List<EventRow>> watchRange(DateTime from, DateTime toExclusive) =>
      (select(events)
            ..where(
              (row) =>
                  row.date.isBiggerOrEqualValue(from) &
                  row.date.isSmallerThanValue(toExclusive) &
                  row.status.isNotValue(_skipped),
            )
            ..orderBy([
              (row) => OrderingTerm(expression: row.date),
              (row) => OrderingTerm(expression: row.startMinute),
            ]))
          .watch();
```

- [ ] **Step 4: Run the DAO test to verify it passes**

Run: `flutter test test/data/event_dao_range_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing repository test**

```dart
// test/features/clock/event_repository_flights_test.dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  test('watchFlights returns only flights, ordered by date then start', () async {
    final harness = TestClockHarness();
    addTearDown(harness.close);
    final repo = DriftEventRepository(harness.db.eventDao);
    final day = DateTime(2026, 10, 14);
    await repo.createEvent(
      day: day, title: 'Standup', tone: Tone.inbox,
      range: const MinuteRange(540, 600),
    );
    await repo.createEvent(
      day: day, title: 'LH715', tone: Tone.inbox,
      range: const MinuteRange(625, 850),
      isFlight: true, flightNumber: 'LH715', fromCode: 'SOF', toCode: 'BER',
    );
    final flights = await repo
        .watchFlights(DateTime(2026, 10, 1), DateTime(2026, 11, 1))
        .first;
    expect(flights.map((f) => f.title), ['LH715']);
    expect(flights.single.fromCode, 'SOF');
  });
}
```

(Again, match the real harness API from `test/data/event_dao_test.dart` / `event_repository_test.dart` before running.)

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/clock/event_repository_flights_test.dart`
Expected: FAIL with `watchFlights` undefined.

- [ ] **Step 7: Add `watchFlights` to the interface and impl**

In `lib/features/clock/data/event_repository.dart`, add to the interface after `watchTonesByDay`:

```dart
  /// Every flight in `[from, toExclusive)`, oldest first, as a stream.
  Stream<List<CalendarEvent>> watchFlights(
    DateTime from,
    DateTime toExclusive,
  );
```

Add to `DriftEventRepository` after `watchTonesByDay`:

```dart
  @override
  Stream<List<CalendarEvent>> watchFlights(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    await _fill(start, end);
    yield* _dao.watchRange(start, end).map(
      (rows) => rows
          .where((row) => row.isFlight)
          .map(CalendarEvent.fromRow)
          .toList(),
    );
  }
```

- [ ] **Step 8: Run both tests**

Run: `flutter test test/data/event_dao_range_test.dart test/features/clock/event_repository_flights_test.dart`
Expected: PASS, PASS.

- [ ] **Step 9: Move `eventRepositoryProvider` to `data/providers.dart`**

Cut this block from `lib/features/clock/providers.dart`:

```dart
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(
    ref.watch(appDatabaseProvider).eventDao,
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});
```

Paste it into `lib/data/providers.dart` after `calendarRepositoryProvider`, adding the import:

```dart
import 'package:energy_clock/features/clock/data/event_repository.dart';
```

This is not a cycle: `event_repository.dart` imports only `core/`, `data/daos`, `data/database`, `data/repositories/series_materialiser.dart`. Remove now-unused imports from `lib/features/clock/providers.dart` (`data/providers.dart` stays — it still uses `seriesMaterialiserProvider`? check; `reuseRepositoryProvider`? keep what is referenced).

- [ ] **Step 10: Re-point every consumer import**

Run: `rg -l "features/clock/providers.dart" lib test | xargs rg -l "eventRepositoryProvider"`
Expected: consumer list includes `lib/features/clock/clock_screen.dart`, `lib/features/clock/widgets/event_sheet.dart`, `lib/features/clock/widgets/delete_event.dart`, `lib/app/onboarding/onboarding_flow.dart`, `lib/features/clock/providers.dart` itself, plus test files. In each file that references `eventRepositoryProvider`, change the import to `package:energy_clock/data/providers.dart`. Files that also use `selectedDateProvider`/`clockProvider`/`dayEventsProvider` keep the clock-providers import too (two imports). Do NOT change any other code.

- [ ] **Step 11: Add `watchFlights` to `FakeEventRepository`**

In `test/support/fake_event_repository.dart`:

```dart
  List<CalendarEvent> _flightsBetween(DateTime from, DateTime toExclusive) {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    final result = _events
        .where(
          (event) =>
              event.isFlight &&
              !event.date.isBefore(start) &&
              event.date.isBefore(end),
        )
        .toList();
    result.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0
          ? byDate
          : (a.startMinute != b.startMinute
                ? a.startMinute.compareTo(b.startMinute)
                : a.id.compareTo(b.id));
    });
    return result;
  }

  @override
  Stream<List<CalendarEvent>> watchFlights(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    yield _flightsBetween(from, toExclusive);
    yield* _changes.stream.map((_) => _flightsBetween(from, toExclusive));
  }
```

- [ ] **Step 12: Run the full affected suites**

Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/data test/features/clock test/support`
Expected: all PASS.

- [ ] **Step 13: Commit**

```bash
git add lib/data/daos/event_dao.dart lib/features/clock/data/event_repository.dart lib/data/providers.dart lib/features/clock/providers.dart lib/app/onboarding/onboarding_flow.dart test/support/fake_event_repository.dart test/data/event_dao_range_test.dart test/features/clock/event_repository_flights_test.dart
git commit -m "feat: flight range stream and shared event repository provider"
```

Note: `git add` only the files that changed; if the `rg` in Step 10 found more consumers/tests, add those paths too.

---

### Task 2: Pure domain — split, content, codec

**Files:**
- Create: `lib/features/flight_deck/flight_sort.dart`
- Create: `lib/features/flight_deck/calm_content.dart`
- Create: `lib/features/flight_deck/favorites_codec.dart`
- Test: `test/features/flight_deck/flight_sort_test.dart`
- Test: `test/features/flight_deck/calm_content_test.dart`
- Test: `test/features/flight_deck/favorites_codec_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent` (existing: `date`, `range.endMinute`, `isFlight`).
- Produces: `FlightSplit({required List<CalendarEvent> upcoming, required List<CalendarEvent> past, required CalendarEvent? next})`; `splitFlights(List<CalendarEvent> flights, DateTime now) -> FlightSplit`; `CalmKind { fact, tip }`; `CalmCard({required String id, required CalmKind kind, required String title, required String body})`; `const List<CalmCard> calmCards` (10 facts + 8 tips); `encodeFavorites(Set<String>) -> String`; `decodeFavorites(String?) -> Set<String>`.

- [ ] **Step 1: Write the failing split test**

```dart
// test/features/flight_deck/flight_sort_test.dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent flight(int id, DateTime date, int start, int end) =>
    CalendarEvent(
      id: id,
      seriesId: null,
      date: DateTime(date.year, date.month, date.day),
      title: 'LH$id',
      tone: Tone.inbox,
      range: MinuteRange(start, end),
      status: EventStatus.planned,
      isFlight: true,
      fromCode: 'SOF',
      toCode: 'BER',
    );

void main() {
  test('past flights sort before split; next is the nearest upcoming', () {
    final now = DateTime(2026, 10, 14, 12);
    final flights = [
      flight(1, DateTime(2026, 10, 20), 600, 700),
      flight(2, DateTime(2026, 10, 10), 600, 700),
      flight(3, DateTime(2026, 10, 14), 900, 1000),
    ];
    final split = splitFlights(flights, now);
    expect(split.past.map((f) => f.id), [2]);
    expect(split.upcoming.map((f) => f.id), [3, 1]);
    expect(split.next?.id, 3);
  });

  test('a flight ending exactly now counts as past; empty gives null next', () {
    final now = DateTime(2026, 10, 14, 12);
    final ending = flight(4, DateTime(2026, 10, 14), 600, 720);
    final split = splitFlights([ending], now);
    expect(split.upcoming, isEmpty);
    expect(split.next, isNull);
    expect(splitFlights([], now).next, isNull);
  });
}
```

"A flight counts as upcoming" rule: `flightEnd.isAfter(now)` where `flightEnd = DateTime(date.year, date.month, date.day).add(Duration(minutes: endMinute))`. Ending exactly now is past.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/flight_deck/flight_sort_test.dart`
Expected: FAIL with "couldn't resolve the package" / file not found (`flight_sort.dart` doesn't exist).

- [ ] **Step 3: Implement `flight_sort.dart`**

```dart
// lib/features/flight_deck/flight_sort.dart
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;

/// Flights divided at [now]: a flight whose end is after [now] is upcoming.
class FlightSplit {
  const FlightSplit({
    required this.upcoming,
    required this.past,
    required this.next,
  });

  final List<CalendarEvent> upcoming;
  final List<CalendarEvent> past;
  final CalendarEvent? next;
}

DateTime flightEndOf(CalendarEvent flight) => DateTime(
  flight.date.year,
  flight.date.month,
  flight.date.day,
).add(Duration(minutes: flight.endMinute));

int _compareFlights(CalendarEvent a, CalendarEvent b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byStart = a.startMinute.compareTo(b.startMinute);
  return byStart != 0 ? byStart : a.id.compareTo(b.id);
}

FlightSplit splitFlights(List<CalendarEvent> flights, DateTime now) {
  final upcoming = <CalendarEvent>[];
  final past = <CalendarEvent>[];
  for (final flight in flights) {
    if (flightEndOf(flight).isAfter(now)) {
      upcoming.add(flight);
    } else {
      past.add(flight);
    }
  }
  upcoming.sort(_compareFlights);
  past.sort(_compareFlights);
  return FlightSplit(
    upcoming: upcoming,
    past: past,
    next: upcoming.isEmpty ? null : upcoming.first,
  );
}
```

- [ ] **Step 4: Run the split test**

Run: `flutter test test/features/flight_deck/flight_sort_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing content + codec tests**

```dart
// test/features/flight_deck/calm_content_test.dart
import 'package:energy_clock/features/flight_deck/calm_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled set is 10 facts + 8 tips with unique comma-free ids', () {
    expect(calmCards, hasLength(18));
    expect(calmCards.where((c) => c.kind == CalmKind.fact), hasLength(10));
    expect(calmCards.where((c) => c.kind == CalmKind.tip), hasLength(8));
    final ids = calmCards.map((c) => c.id).toList();
    expect(ids.toSet(), hasLength(18));
    expect(ids.every((id) => !id.contains(',') && id.isNotEmpty), isTrue);
    expect(calmCards.every((c) => c.title.isNotEmpty && c.body.isNotEmpty), isTrue);
  });
}
```

```dart
// test/features/flight_deck/favorites_codec_test.dart
import 'package:energy_clock/features/flight_deck/favorites_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a set through a comma-joined string', () {
    expect(decodeFavorites(encodeFavorites({'a', 'b'})), {'a', 'b'});
    expect(decodeFavorites(null), isEmpty);
    expect(decodeFavorites(''), isEmpty);
    expect(encodeFavorites({}), '');
  });
}
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/flight_deck/calm_content_test.dart test/features/flight_deck/favorites_codec_test.dart`
Expected: FAIL, file(s) not found.

- [ ] **Step 7: Implement the codec (small file first)**

```dart
// lib/features/flight_deck/favorites_codec.dart
/// Favorites persist as one comma-joined string in the settings table (which
/// has no list API). Card ids never contain commas (see calm_content_test).
String encodeFavorites(Set<String> ids) => ids.join(',');

Set<String> decodeFavorites(String? stored) {
  if (stored == null || stored.isEmpty) return {};
  return stored.split(',').where((id) => id.isNotEmpty).toSet();
}
```

- [ ] **Step 8: Implement the calm content with the exact 18 cards**

```dart
// lib/features/flight_deck/calm_content.dart
/// Bundled, offline calm-kit content for the Flight Deck. ids are stable
/// slugs: favorites persist them, so never rename an id.
enum CalmKind { fact, tip }

class CalmCard {
  const CalmCard({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
  });

  final String id;
  final CalmKind kind;
  final String title;
  final String body;
}

const List<CalmCard> calmCards = [
  // Facts (10).
  CalmCard(id: 'fact-odds', kind: CalmKind.fact, title: 'Flying is the safest way to travel', body: 'About 1 in 11 million flights has a fatal accident — you are safer in the air than on the drive to the airport.'),
  CalmCard(id: 'fact-turbulence', kind: CalmKind.fact, title: 'Turbulence is uncomfortable, not dangerous', body: 'Planes are built to handle forces far beyond any turbulence, and it has never brought down a modern airliner. Think of it as bumps on a road.'),
  CalmCard(id: 'fact-sounds', kind: CalmKind.fact, title: 'Those sounds are normal', body: 'Clunks after takeoff are the landing gear retracting; dings are crew signals; engine pitch changes are routine power adjustments.'),
  CalmCard(id: 'fact-wings', kind: CalmKind.fact, title: 'Wings flex by design', body: 'A wing tip can bend several metres in testing without damage. Flexing you see from the window is the wing doing its job.'),
  CalmCard(id: 'fact-pilots', kind: CalmKind.fact, title: 'Two trained pilots, always', body: 'Every airliner flies with two fully qualified pilots who rehearse emergencies in simulators every six months.'),
  CalmCard(id: 'fact-backups', kind: CalmKind.fact, title: 'Everything important has a backup', body: 'Engines, hydraulics, electrics and instruments are all redundant — a plane lands safely even after several failures.'),
  CalmCard(id: 'fact-one-engine', kind: CalmKind.fact, title: 'One engine is enough', body: 'Twin-engine airliners climb and land on a single engine, and pilots practise exactly that in the simulator.'),
  CalmCard(id: 'fact-weather', kind: CalmKind.fact, title: 'Storms are flown around, not through', body: 'Dispatchers and radar keep flights clear of severe weather; a bumpy detour means the crew chose the safer path.'),
  CalmCard(id: 'fact-crew-calm', kind: CalmKind.fact, title: 'Watch the crew, not the window', body: 'If the cabin crew are calmly serving drinks, nothing is wrong — they feel the same bumps and know they are routine.'),
  CalmCard(id: 'fact-landing', kind: CalmKind.fact, title: 'Landings are firm on purpose', body: 'A positive touchdown keeps the wheels gripping the runway, especially when it is wet. A firm landing is a good landing.'),
  // Tips (8).
  CalmCard(id: 'tip-breathing', kind: CalmKind.tip, title: 'Slow your exhale', body: 'Breathe in 4 seconds, hold 4, out 6. Long exhales tell your nervous system the danger has passed. Try it in the timer below.'),
  CalmCard(id: 'tip-seat', kind: CalmKind.tip, title: 'Sit over the wing', body: 'Seats over the wing feel the least motion. A window seat also gives you a stable horizon to look at.'),
  CalmCard(id: 'tip-crew', kind: CalmKind.tip, title: 'Tell the crew you are nervous', body: 'Flight attendants help nervous flyers every day. Saying so out loud often halves the anxiety on its own.'),
  CalmCard(id: 'tip-caffeine', kind: CalmKind.tip, title: 'Skip the extra coffee', body: 'Caffeine mimics anxiety: racing heart, jitters, alertness. Water and a light meal keep your body calmer.'),
  CalmCard(id: 'tip-arrive', kind: CalmKind.tip, title: 'Arrive early, rush less', body: 'Most panic starts with running late. Being at the gate with time to spare removes the biggest controllable stressor.'),
  CalmCard(id: 'tip-distraction', kind: CalmKind.tip, title: 'Plan your distraction', body: 'Download a film, an album and a puzzle before boarding. Giving your brain a job leaves less room for worry.'),
  CalmCard(id: 'tip-feet', kind: CalmKind.tip, title: 'Plant your feet', body: 'Press both feet flat into the floor and notice the pressure. Grounding through your body interrupts spiralling thoughts.'),
  CalmCard(id: 'tip-turbulence-plan', kind: CalmKind.tip, title: 'Have a turbulence plan', body: 'Decide now: seatbelt on, sip water, run the breathing timer. A rehearsed plan turns bumps into routine.'),
];
```

- [ ] **Step 9: Run the Task 2 tests**

Run: `flutter test test/features/flight_deck`
Expected: all PASS.
Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 10: Commit**

```bash
git add lib/features/flight_deck/flight_sort.dart lib/features/flight_deck/calm_content.dart lib/features/flight_deck/favorites_codec.dart test/features/flight_deck/
git commit -m "feat: flight split, calm content and favorites codec"
```

---

### Task 3: Deck providers

**Files:**
- Modify: `lib/core/time/day_time.dart` (add `untilNextMinute`)
- Modify: `lib/features/clock/providers.dart` (use the moved function — delete local copy, no import change needed since `day_time.dart` is already imported; verify)
- Create: `lib/features/flight_deck/providers.dart`
- Test: `test/features/flight_deck/providers_test.dart`

**Interfaces:**
- Consumes: `eventRepositoryProvider` (Task 1), `settingsRepositoryProvider` (existing), `startOfDay` (existing), `untilNextMinute` (moved here), `splitFlights`/`FlightSplit` (Task 2), `encodeFavorites`/`decodeFavorites` (Task 2).
- Produces: `deckNowProvider -> DateTime` (ticks each minute); `deckFlightsProvider -> AsyncValue<FlightSplit>`; `flightDeckFavoritesKey = 'flight_deck_favs'`; `flightDeckFavoritesProvider -> AsyncNotifierProvider<FavoritesNotifier, Set<String>>` with `Future<void> toggle(String id)`.

- [ ] **Step 1: Move `untilNextMinute` to `day_time.dart`**

Check `lib/core/time/day_time.dart` exports (`startOfDay`, `nextDay`, `previousDay` live there). Append:

```dart
/// How long until the next minute boundary, so clocks tick exactly on it.
Duration untilNextMinute(DateTime now) {
  final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
  return next.difference(now);
}
```

In `lib/features/clock/providers.dart`, delete the local `untilNextMinute` function (keep `ClockNotifier` using it — the `day_time.dart` import is already there; confirm the import line exists, add it if not).

- [ ] **Step 2: Write the failing providers test**

```dart
// test/features/flight_deck/providers_test.dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/flight_deck/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';
import '../../support/fake_settings_repository.dart';

Future<int> addFlight(FakeEventRepository repo, DateTime day, int start) =>
    repo.createEvent(
      day: day,
      title: 'LH715',
      tone: Tone.inbox,
      range: MinuteRange(start, start + 120),
      isFlight: true,
      flightNumber: 'LH715',
      fromCode: 'SOF',
      toCode: 'BER',
    );

void main() {
  test('deckFlights splits upcoming and past around now', () async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await addFlight(events, today.subtract(const Duration(days: 30)), 600);
    await addFlight(events, today.add(const Duration(days: 30)), 600);
    final container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWithValue(events),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
    );
    addTearDown(container.dispose);
    final split = await container.read(deckFlightsProvider.future);
    expect(split.past, hasLength(1));
    expect(split.upcoming, hasLength(1));
    expect(split.next?.flightNumber, 'LH715');
  });

  test('favorites toggle persists and reverts on write failure', () async {
    final settings = FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    await container.read(flightDeckFavoritesProvider.future);
    await container
        .read(flightDeckFavoritesProvider.notifier)
        .toggle('fact-odds');
    expect(
      container.read(flightDeckFavoritesProvider).value,
      {'fact-odds'},
    );
    expect(settings.values['flight_deck_favs'], 'fact-odds');
    settings.failWrites = true;
    await container
        .read(flightDeckFavoritesProvider.notifier)
        .toggle('fact-turbulence');
    expect(
      container.read(flightDeckFavoritesProvider).value,
      {'fact-odds'},
    );
  });
}
```

Note: `deckFlightsProvider.future` with a minute ticker — the test completes on first emission, fine. `FakeEventRepository` needs `dispose()` — it has one.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/flight_deck/providers_test.dart`
Expected: FAIL, `providers.dart` doesn't exist.

- [ ] **Step 4: Implement `providers.dart`**

```dart
// lib/features/flight_deck/providers.dart
import 'dart:async';

import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;
import 'package:energy_clock/features/flight_deck/favorites_codec.dart';
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings key holding the comma-joined ids of starred calm cards.
const String flightDeckFavoritesKey = 'flight_deck_favs';

/// Flight Deck's "now", ticking once a minute. Local to this feature so the
/// feature-import rule stays intact (the Clock tab has its own ticker).
final deckNowProvider = NotifierProvider<DeckNowNotifier, DateTime>(
  DeckNowNotifier.new,
);

class DeckNowNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = DateTime.now();
    _timer = Timer(untilNextMinute(now), () => state = DateTime.now());
    ref.onDispose(() => _timer?.cancel());
    return now;
  }
}

/// Every flight from a year ago to a year ahead, split at now.
final deckFlightsProvider = StreamProvider<FlightSplit>((ref) {
  final now = ref.watch(deckNowProvider);
  final from = startOfDay(now).subtract(const Duration(days: 365));
  final to = startOfDay(now).add(const Duration(days: 366));
  return ref
      .watch(eventRepositoryProvider)
      .watchFlights(from, to)
      .map((flights) => splitFlights(flights, now));
});

final flightDeckFavoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
      FavoritesNotifier.new,
    );

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final stored = await ref
        .watch(settingsRepositoryProvider)
        .getString(flightDeckFavoritesKey);
    return decodeFavorites(stored);
  }

  /// Stars or unstars [id], persisting optimistically and reverting when the
  /// write fails so the UI never shows a star that isn't stored.
  Future<void> toggle(String id) async {
    final previous = state.valueOrNull ?? {};
    final next = {...previous};
    if (!next.remove(id)) next.add(id);
    state = AsyncData(next);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setString(flightDeckFavoritesKey, encodeFavorites(next));
    } on Object {
      state = AsyncData(previous);
    }
  }
}
```

Note on `CalendarEvent` import: `show CalendarEvent` only — the file exports `RingOverflowException` too; importing the file is fine (it's `features/clock/data/`, and the rule is about feature-to-feature UI coupling; `flight_sort.dart` already imports it the same way — data-model import, consistent with Task 2).

- [ ] **Step 5: Run the providers test**

Run: `flutter test test/features/flight_deck/providers_test.dart`
Expected: PASS. If the minute-timer keeps the test alive, the `.future` completes on first emission — no hang expected.

- [ ] **Step 6: Gates + commit**

Run: `flutter analyze`
Expected: no issues.
```bash
git add lib/core/time/day_time.dart lib/features/clock/providers.dart lib/features/flight_deck/providers.dart test/features/flight_deck/providers_test.dart
git commit -m "feat: flight deck providers and favorites"
```

---

### Task 4: Strings + calm widgets

**Files:**
- Modify: `lib/core/strings.dart`
- Create: `lib/features/flight_deck/widgets/calm_card_view.dart`
- Create: `lib/features/flight_deck/widgets/breathing_timer.dart`
- Create: `lib/features/flight_deck/widgets/grounding_steps.dart`
- Test: `test/features/flight_deck/calm_widgets_test.dart`

**Interfaces:**
- Consumes: `CalmCard`/`CalmKind` (Task 2), `Strings.*` (this task), theme tokens.
- Produces: `CalmCardView({required CalmCard card, required bool starred, required VoidCallback onStar})`; `CalmFilterChips({required CalmFilter filter, required ValueChanged<CalmFilter> onChanged})` with `enum CalmFilter { all, facts, tips, saved }`; `BreathingTimer()`; `GroundingSteps()`.

- [ ] **Step 1: Add Deck copy to `Strings`**

Append after the flights section in `lib/core/strings.dart`:

```dart
  // Flight Deck.
  static const String tabDeck = 'Deck';
  static const String flightDeckTitle = 'Flight Deck';
  static const String deckFlightsLoadError = "Couldn't load flights.";
  static const String deckUpcoming = 'Upcoming';
  static const String deckPast = 'Past flights';
  static const String deckNextFlight = 'Next flight';
  static const String deckEmptyTitle = 'No flights yet';
  static const String deckEmptyHint =
      'Mark an event as a flight and it will show up here.';
  static const String deckCalmTitle = 'Calm kit';
  static const String deckFacts = 'Facts';
  static const String deckTips = 'Tips';
  static const String deckSaved = 'Saved';
  static const String deckAll = 'All';
  static const String deckBreathingTitle = 'Slow breathing';
  static const String deckBreathingHint = 'In 4 · hold 4 · out 6';
  static const String deckBreathingStart = 'Start';
  static const String deckBreathingPause = 'Pause';
  static const String deckBreathingReset = 'Reset';
  static const String deckGroundingTitle = 'Name what is here';
  static const String deckGroundingHint = '5 see · 4 feel · 3 hear · 2 smell · 1 taste';
  static const String deckGroundingNext = 'Notice one';
  static const String deckGroundingDone = 'Well done — you are here.';
  static const String deckGroundingRestart = 'Start over';
  static const String deckStarAdd = 'Save';
  static const String deckStarRemove = 'Saved';
  static const String deckSavedEmptyTitle = 'Nothing saved yet';
  static const String deckSavedEmptyHint = 'Star a card to keep it here.';
  static String deckCountdownToday(String time) => 'Today · $time';
  static String deckCountdownTomorrow(String time) => 'Tomorrow · $time';
  static String deckCountdownDays(int days) =>
      days == 1 ? 'In 1 day' : 'In $days days';
```

Check `day_time.dart`/existing helpers for a `HH:MM` formatter for the hero time; if one exists (e.g. in `core/time/`), reuse it in Task 5 — do not add a formatter here.

- [ ] **Step 2: Write the failing widget test**

```dart
// test/features/flight_deck/calm_widgets_test.dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/features/flight_deck/calm_content.dart';
import 'package:energy_clock/features/flight_deck/widgets/breathing_timer.dart';
import 'package:energy_clock/features/flight_deck/widgets/calm_card_view.dart';
import 'package:energy_clock/features/flight_deck/widgets/grounding_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('card shows title and toggles its star', (tester) async {
    var starred = false;
    await tester.pumpWidget(host(CalmCardView(
      card: calmCards.first,
      starred: starred,
      onStar: () => starred = !starred,
    )));
    expect(find.text(calmCards.first.title), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deck-star')));
    expect(starred, isTrue);
  });

  testWidgets('breathing timer starts and pauses', (tester) async {
    await tester.pumpWidget(host(const BreathingTimer()));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Start'), findsNothing);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('grounding completes all five steps then restarts', (tester) async {
    await tester.pumpWidget(host(const GroundingSteps()));
    for (var i = 0; i < 15; i++) {
      await tester.tap(find.text('Notice one'));
      await tester.pump();
    }
    expect(find.text('Well done — you are here.'), findsOneWidget);
    await tester.tap(find.text('Start over'));
    await tester.pump();
    expect(find.text('Notice one'), findsOneWidget);
  });
}
```

5+4+3+2+1 = 15 taps. The `BreathingTimer` test uses real timers advanced by `tester.pump(duration)` — no fake-async waiting needed.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/flight_deck/calm_widgets_test.dart`
Expected: FAIL, widgets don't exist.

- [ ] **Step 4: Implement `calm_card_view.dart`**

```dart
// lib/features/flight_deck/widgets/calm_card_view.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/flight_deck/calm_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum CalmFilter { all, facts, tips, saved }

/// One fact or tip with a star toggle. Colours come from theme tokens only.
class CalmCardView extends StatelessWidget {
  const CalmCardView({
    required this.card,
    required this.starred,
    required this.onStar,
    super.key,
  });

  final CalmCard card;
  final bool starred;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    card.body,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('deck-star'),
              icon: Icon(
                starred ? CupertinoIcons.star_fill : CupertinoIcons.star,
                color: starred ? colors.ink : colors.muted,
              ),
              tooltip: starred ? Strings.deckStarRemove : Strings.deckStarAdd,
              onPressed: onStar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chips above the card list.
class CalmFilterChips extends StatelessWidget {
  const CalmFilterChips({
    required this.filter,
    required this.onChanged,
    super.key,
  });

  final CalmFilter filter;
  final ValueChanged<CalmFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    String label(CalmFilter f) => switch (f) {
      CalmFilter.all => Strings.deckAll,
      CalmFilter.facts => Strings.deckFacts,
      CalmFilter.tips => Strings.deckTips,
      CalmFilter.saved => Strings.deckSaved,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final f in CalmFilter.values)
          ChoiceChip(
            label: Text(label(f)),
            selected: f == filter,
            onSelected: (_) => onChanged(f),
          ),
      ],
    );
  }
}
```

Verify `AppColors`/`tokens.dart` export names (`appColors`, `surface`, `muted`, `ink`, `AppSpacing.md/xs/sm`) against `lib/app/theme/` before running — adjust to the real names; the no-hardcoded-colour test is the gate.

- [ ] **Step 5: Implement `breathing_timer.dart`**

```dart
// lib/features/flight_deck/widgets/breathing_timer.dart
import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _Phase { inhale, hold, exhale }

/// 4s in / 4s hold / 6s out. Ticks with a 1s timer; the ring animates unless
/// reduce-motion is on. Cancels its timer on dispose.
class BreathingTimer extends StatefulWidget {
  const BreathingTimer({super.key});

  @override
  State<BreathingTimer> createState() => _BreathingTimerState();
}

class _BreathingTimerState extends State<BreathingTimer> {
  static const _lengths = {
    _Phase.inhale: 4,
    _Phase.hold: 4,
    _Phase.exhale: 6,
  };

  Timer? _timer;
  _Phase _phase = _Phase.inhale;
  int _left = 4;
  bool _running = false;

  String get _label => switch (_phase) {
    _Phase.inhale => 'Breathe in',
    _Phase.hold => 'Hold',
    _Phase.exhale => 'Breathe out',
  };

  double get _scale => switch (_phase) {
    _Phase.inhale => 1.25,
    _Phase.hold => 1.25,
    _Phase.exhale => 1.0,
  };

  void _tick() {
    if (_left > 1) {
      setState(() => _left--);
      return;
    }
    final next = _Phase.values[(_phase.index + 1) % _Phase.values.length];
    setState(() {
      _phase = next;
      _left = _lengths[next]!;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _phase = _Phase.inhale;
      _left = _lengths[_Phase.inhale]!;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Strings.deckBreathingTitle,
            style: Theme.of(context).textTheme.titleSmall),
        Text(Strings.deckBreathingHint,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: colors.muted)),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : const Duration(seconds: 4),
            curve: Curves.easeInOut,
            width: 120 * _scale,
            height: 120 * _scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.ink, width: 3),
            ),
            alignment: Alignment.center,
            child: Text('$_label\n$_left',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: _toggle,
              child: Text(
                _running
                    ? Strings.deckBreathingPause
                    : Strings.deckBreathingStart,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: _reset,
              child: const Text(Strings.deckBreathingReset),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Implement `grounding_steps.dart`**

```dart
// lib/features/flight_deck/widgets/grounding_steps.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';

/// 5-4-3-2-1 grounding: name 5 things you see, 4 you feel, 3 you hear,
/// 2 you smell, 1 you taste. "Notice one" counts down each sense in turn.
class GroundingSteps extends StatefulWidget {
  const GroundingSteps({super.key});

  @override
  State<GroundingSteps> createState() => _GroundingStepsState();
}

class _GroundingStepsState extends State<GroundingSteps> {
  static const _targets = [5, 4, 3, 2, 1];
  static const _senses = ['see', 'feel', 'hear', 'smell', 'taste'];

  int _step = 0;
  int _left = 5;

  bool get _done => _step >= _targets.length;

  void _notice() {
    if (_done) return;
    setState(() {
      if (_left > 1) {
        _left--;
      } else {
        _step++;
        if (!_done) _left = _targets[_step];
      }
    });
  }

  void _restart() => setState(() {
    _step = 0;
    _left = _targets.first;
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (_done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.deckGroundingDone,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _restart,
              child: const Text(Strings.deckGroundingRestart),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Strings.deckGroundingTitle,
            style: Theme.of(context).textTheme.titleSmall),
        Text(
          'Name $_left thing${_left == 1 ? '' : 's'} you ${_senses[_step]} '
          '(${_step + 1} of ${_targets.length})',
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < _targets.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(
                  i < _step
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: colors.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: _notice,
            child: const Text(Strings.deckGroundingNext),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 7: Run the widget tests + gates**

Run: `flutter test test/features/flight_deck/calm_widgets_test.dart`
Expected: PASS (fix theme-token names first if analyze complains).
Run: `flutter analyze && flutter test test/architecture`
Expected: clean + PASS (no hard-coded colours).

- [ ] **Step 8: Commit**

```bash
git add lib/core/strings.dart lib/features/flight_deck/widgets/calm_card_view.dart lib/features/flight_deck/widgets/breathing_timer.dart lib/features/flight_deck/widgets/grounding_steps.dart test/features/flight_deck/calm_widgets_test.dart
git commit -m "feat: flight deck calm widgets and copy"
```

---

### Task 5: Flights UI + screen

**Files:**
- Create: `lib/features/flight_deck/widgets/next_flight_hero.dart`
- Create: `lib/features/flight_deck/widgets/flights_list.dart`
- Create: `lib/features/flight_deck/flight_deck_screen.dart`
- Test: `test/features/flight_deck/flight_deck_screen_test.dart`

**Interfaces:**
- Consumes: `FlightSplit`/`flightEndOf` (Task 2), `deckFlightsProvider`/`flightDeckFavoritesProvider`/`deckNowProvider` (Task 3), `calmCards` (Task 2), Task 4 widgets, `Strings.*`, `flightRoute` from `Strings` (existing: `Strings.flightRoute(from, to)`).
- Produces: `NextFlightHero({required CalendarEvent flight, required DateTime now, required VoidCallback onOpen})`; `FlightsList({required FlightSplit split, required ValueChanged<DateTime> onOpenDay})`; `FlightDeckScreen({required ValueChanged<DateTime> onOpenDay})` (mirrors `CalendarTab(onOpenDay:)` so `TabScaffold` can wire it without importing clock providers).

- [ ] **Step 1: Write the failing screen test**

```dart
// test/features/flight_deck/flight_deck_screen_test.dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;
import 'package:energy_clock/features/flight_deck/flight_deck_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';
import '../../support/fake_settings_repository.dart';

CalendarEvent flightOn(DateTime day, int start) => CalendarEvent(
  id: start,
  seriesId: null,
  date: DateTime(day.year, day.month, day.day),
  title: 'LH715',
  tone: Tone.inbox,
  range: MinuteRange(start, start + 120),
  status: EventStatus.planned,
  isFlight: true,
  flightNumber: 'LH715',
  fromCode: 'SOF',
  toCode: 'BER',
});

Widget host({
  required FakeEventRepository events,
  required ValueChanged<DateTime> onOpenDay,
}) => ProviderScope(
  overrides: [
    eventRepositoryProvider.overrideWithValue(events),
    settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: FlightDeckScreen(onOpenDay: onOpenDay)),
  ),
);

void main() {
  testWidgets('hero shows next flight and opens its day on tap', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    final now = DateTime.now();
    final future = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 30));
    await events.createEvent(
      day: future, title: 'LH715', tone: Tone.inbox,
      range: const MinuteRange(625, 745),
      isFlight: true, flightNumber: 'LH715', fromCode: 'SOF', toCode: 'BER',
    );
    DateTime? opened;
    await tester.pumpWidget(host(events: events, onOpenDay: (d) => opened = d));
    await tester.pumpAndSettle();
    expect(find.text('Next flight'), findsOneWidget);
    expect(find.textContaining('SOF→BER'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('deck-hero-open')));
    expect(opened, DateTime(future.year, future.month, future.day));
  });

  testWidgets('empty days show the no-flights empty state', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    await tester.pumpWidget(host(events: events, onOpenDay: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text('No flights yet'), findsOneWidget);
  });

  testWidgets('saved filter shows only starred cards', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    await tester.pumpWidget(host(events: events, onOpenDay: (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await tester.tap(find.text('Facts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deck-star')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/flight_deck/flight_deck_screen_test.dart`
Expected: FAIL, screen doesn't exist.

- [ ] **Step 3: Implement `next_flight_hero.dart` + `flights_list.dart`**

```dart
// lib/features/flight_deck/widgets/next_flight_hero.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

String deckCountdownLabel(DateTime now, CalendarEvent flight) {
  final end = flightEndOf(flight);
  final days = end.difference(now).inDays;
  final today = DateTime(now.year, now.month, now.day);
  final flightDay = DateTime(
    flight.date.year, flight.date.month, flight.date.day);
  final time =
      '${(flight.startMinute ~/ 60).toString().padLeft(2, '0')}:'
      '${(flight.startMinute % 60).toString().padLeft(2, '0')}';
  if (flightDay == today) return Strings.deckCountdownToday(time);
  if (flightDay == today.add(const Duration(days: 1))) {
    return Strings.deckCountdownTomorrow(time);
  }
  return Strings.deckCountdownDays(days);
}
```

Note: check `core/time/day_time.dart` for an existing minute-formatter first; if one exists, use it instead of the manual padLeft above.

```dart
/// The nearest upcoming flight with its countdown. Tapping opens the day.
class NextFlightHero extends StatelessWidget {
  const NextFlightHero({
    required this.flight,
    required this.now,
    required this.onOpen,
    super.key,
  });

  final CalendarEvent flight;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final route = Strings.flightRoute(
      flight.fromCode ?? '?',
      flight.toCode ?? '?',
    );
    return Card(
      color: colors.surface,
      child: InkWell(
        key: const ValueKey('deck-hero-open'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(CupertinoIcons.airplane, size: 32, color: colors.ink),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Strings.deckNextFlight,
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(color: colors.muted)),
                    Text(
                      '${flight.flightNumber ?? flight.title} · $route',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(deckCountdownLabel(now, flight),
                        style: Theme.of(context).textTheme.bodyMedium!
                            .copyWith(color: colors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/features/flight_deck/widgets/flights_list.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

String _dayLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Upcoming + past flight rows. Read-only: tapping a row opens its day via
/// the existing Clock sheet, so there is no edit form here.
class FlightsList extends StatelessWidget {
  const FlightsList({
    required this.split,
    required this.onOpenDay,
    super.key,
  });

  final FlightSplit split;
  final ValueChanged<DateTime> onOpenDay;

  Widget _row(BuildContext context, CalendarEvent flight) {
    final route = Strings.flightRoute(
      flight.fromCode ?? '?',
      flight.toCode ?? '?',
    );
    return ListTile(
      leading: Icon(
        CupertinoIcons.airplane,
        color: context.appColors.muted,
      ),
      title: Text(flight.flightNumber ?? flight.title),
      subtitle: Text('$route · ${_dayLabel(flight.date)}'),
      onTap: () => onOpenDay(flight.date),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (split.upcoming.isEmpty && split.past.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.deckEmptyTitle,
              style: Theme.of(context).textTheme.titleSmall),
          Text(Strings.deckEmptyHint,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: context.appColors.muted,
              )),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (split.upcoming.isNotEmpty) ...[
          Text(Strings.deckUpcoming,
              style: Theme.of(context).textTheme.titleSmall),
          for (final flight in split.upcoming) _row(context, flight),
        ],
        if (split.past.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(Strings.deckPast,
              style: Theme.of(context).textTheme.titleSmall),
          for (final flight in split.past) _row(context, flight),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `flight_deck_screen.dart`**

Mirror `StatsScreen`'s structure (data.when + `SingleChildScrollView` + `ContentWidth` + `TabBarInset`):

```dart
// lib/features/flight_deck/flight_deck_screen.dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/flight_deck/calm_content.dart';
import 'package:energy_clock/features/flight_deck/providers.dart';
import 'package:energy_clock/features/flight_deck/widgets/breathing_timer.dart';
import 'package:energy_clock/features/flight_deck/widgets/calm_card_view.dart';
import 'package:energy_clock/features/flight_deck/widgets/flights_list.dart';
import 'package:energy_clock/features/flight_deck/widgets/grounding_steps.dart';
import 'package:energy_clock/features/flight_deck/widgets/next_flight_hero.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Flight Deck tab: flights hub on top, calm kit below.
class FlightDeckScreen extends ConsumerStatefulWidget {
  const FlightDeckScreen({required this.onOpenDay, super.key});

  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<FlightDeckScreen> createState() => _FlightDeckScreenState();
}

class _FlightDeckScreenState extends ConsumerState<FlightDeckScreen> {
  CalmFilter _filter = CalmFilter.all;

  @override
  Widget build(BuildContext context) {
    final flights = ref.watch(deckFlightsProvider);
    final favorites = ref.watch(flightDeckFavoritesProvider);
    return flights.when(
      data: (split) => _DeckBody(
        onOpenDay: widget.onOpenDay,
        filter: _filter,
        onFilter: (f) => setState(() => _filter = f),
      ),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(Strings.deckFlightsLoadError,
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
```

`_DeckBody` is a `ConsumerWidget` that reads `deckFlightsProvider.value!`, `deckNowProvider`, and `favorites.valueOrNull ?? {}` (favorites errors degrade to unstarred, never block the screen), then builds: hero (if `split.next != null`, `onOpen: () => onOpenDay(next.date)`), `FlightsList`, calm title + `CalmFilterChips` + filtered cards + `BreathingTimer` + `GroundingSteps`, all inside the scroll + `ContentWidth(maxWidth: ContentWidths.stats)` + bottom inset padding exactly like `StatsScreen`. Filtering: all → every card; facts/tips → by kind; saved → `favorites.contains(id)`; saved-empty shows `deckSavedEmptyTitle/Hint`. Star tap calls `ref.read(flightDeckFavoritesProvider.notifier).toggle(id)`.

- [ ] **Step 5: Run the screen tests**

Run: `flutter test test/features/flight_deck/flight_deck_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Gates + commit**

Run: `flutter analyze && flutter test test/features/flight_deck test/architecture`
Expected: clean + PASS.
```bash
git add lib/features/flight_deck/widgets/next_flight_hero.dart lib/features/flight_deck/widgets/flights_list.dart lib/features/flight_deck/flight_deck_screen.dart test/features/flight_deck/flight_deck_screen_test.dart
git commit -m "feat: flight deck screen with flights hub and calm kit"
```

---

### Task 6: 5th tab wiring + regression

**Files:**
- Modify: `lib/app/navigation/app_tab_bar.dart`
- Modify: `lib/app/navigation/tab_scaffold.dart`
- Modify: existing tests that assert 4 tabs (enumerated below)
- Test: extend `test/app/app_tab_bar_test.dart`, add Deck case to tab scaffold tests

**Interfaces:**
- Consumes: `FlightDeckScreen(onOpenDay:)` (Task 5), `Strings.tabDeck`, `TabScaffold._openDay` (existing: selects date + jumps to Clock).
- Produces: 5-tab bar; `tabCount == 5`; Deck keeps state via the existing `_visited` IndexedStack.

- [ ] **Step 1: Enumerate every 4-tab assumption**

Run: `rg -n "tabCount|tab 4 of 4|of 4|i < 4|< AppTabBar.tabCount|tab-3" lib test`
Expected: hits in `lib/app/navigation/app_tab_bar.dart` (`tabCount = 4`, `_labels` 4 entries, `_icon` switch), `lib/app/navigation/tab_scaffold.dart` (`_screen` 4 branches), `test/app/app_tab_bar_test.dart` (`for i < 4`, `'Clock, tab 1 of 4'`, `'Profile, tab 4 of 4'`), and possibly `test/app/tab_scaffold_test.dart` / `clock_tab_test.dart`. Record every file; all get updated below.

- [ ] **Step 2: Write the failing tab test first**

In `test/app/app_tab_bar_test.dart`, change the semantics test expectations to `'Clock, tab 1 of 5'` / `'Profile, tab 4 of 5'` and add:

```dart
  testWidgets('deck is the fifth tab', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(selected: 4, onSelected: (_) {}));

    expect(find.text(Strings.tabDeck), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Deck, tab 5 of 5')),
      matchesSemantics(
        label: 'Deck, tab 5 of 5',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
```

Also update the `for (var i = 0; i < 4; i++)` loop bound to `5`.

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/app/app_tab_bar_test.dart`
Expected: FAIL (tab-4 missing, semantics say "of 4").

- [ ] **Step 4: Wire the 5th tab**

In `lib/app/navigation/app_tab_bar.dart`:

```dart
  static const int tabCount = 5;

  static const List<String> _labels = [
    Strings.tabClock,
    Strings.tabCalendar,
    Strings.tabStats,
    Strings.tabProfile,
    Strings.tabDeck,
  ];
```

and in `_icon`, add before the default branch:

```dart
    3 => Icon(
      selected ? CupertinoIcons.person_fill : CupertinoIcons.person,
      color: color,
      size: 24,
    ),
    _ => Icon(
      selected ? CupertinoIcons.airplane_fill : CupertinoIcons.airplane,
      color: color,
      size: 24,
    ),
```

(restructuring the old `_ =>` person branch into explicit `3 =>`; verify `CupertinoIcons.airplane_fill` exists — if not, use `CupertinoIcons.airplane` for both states.)

In `lib/app/navigation/tab_scaffold.dart`:

```dart
  Widget _screen(int index) => switch (index) {
    0 => const ClockTab(),
    1 => CalendarTab(onOpenDay: _openDay),
    2 => const StatsScreen(),
    3 => const ProfileScreen(),
    _ => FlightDeckScreen(onOpenDay: _openDay),
  };
```

plus the import of `flight_deck_screen.dart`.

- [ ] **Step 5: Run tab tests + fix overflow if any**

Run: `flutter test test/app/app_tab_bar_test.dart`
Expected: PASS. Pay special attention to `large text does not overflow the bar` at 320pt with 5 tabs: if it throws an overflow, shrink the selected-tab label flex or the bar's horizontal padding minimally (one-line change in `app_tab_bar.dart`), re-run. Do not redesign the bar.

- [ ] **Step 6: Update remaining tab-count tests + full suite**

Fix every other file found in Step 1 (scaffold tests asserting 4 children, `tab-3`-as-last assumptions, semantics strings). Then:

Run: `flutter analyze`
Expected: no issues.
Run: `flutter test`
Expected: full suite PASS (no golden regen: default dial pixels are unchanged when zero flights exist).

- [ ] **Step 7: Commit**

```bash
git add lib/app/navigation/app_tab_bar.dart lib/app/navigation/tab_scaffold.dart test/app/
git commit -m "feat: flight deck as fifth tab"
```

(If Step 1 found tab-count assumptions in other test dirs, add those paths too.)

---

## Self-review

**1. Spec coverage:** §1 architecture → Tasks 1 (watchFlights deviation noted), 3 (providers), 6 (tab wiring, `tabCount` 4→5, `Deck`/`Flight Deck` strings). §2 components → Tasks 4 (cards, breathing 4-4-6, grounding, starrable + All/Facts/Tips/Saved), 5 (hero with countdown + tap-to-open, Upcoming/Past groups, empty states). §3 data flow → Tasks 1 (range stream, client-side `isFlight` filter), 3 (countdown from local tick, `onOpenDay` reuse of `_openDay`, comma-joined favorites via `getString`/`setString`, bundled `const` content, no notification fork). §4 errors → Task 3 (favorites revert), Task 5 (load-error + empty states, favorites degrade to unstarred), Task 4 (reduce-motion, dispose), Task 6 (320pt overflow check). §5 testing → each task has named test files plus the arch/analyze gates. No gaps.

**2. Placeholder scan:** every step has concrete file paths, code blocks, run commands, and expected outputs. Calm copy is written out verbatim (18 cards). Theme-token names are flagged for verification against `lib/app/theme/` before running — the single deliberate lookup, gated by `flutter analyze`.

**3. Type consistency:** `CalendarEvent` fields used (`date`, `startMinute`, `endMinute`, `flightNumber`, `fromCode`, `toCode`, `isFlight`) all exist on the model. `EventRow.isFlight` exists post-migration. `watchRange`/`watchFlights` signatures match between DAO, repo, fake, and tests. `FlightSplit`/`splitFlights`/`flightEndOf` names are identical across Tasks 2, 3, 5. `CalmFilter` lives in `calm_card_view.dart`, imported by the screen. `flightDeckFavoritesKey` is defined once in `providers.dart` and asserted in the providers test.
