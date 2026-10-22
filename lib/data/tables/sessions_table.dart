import 'package:drift/drift.dart';
import 'package:energy_clock/data/tables/events_table.dart';

/// One timed session on an event (spec §4.2). At most one row has
/// `outcome = 0` (running) at a time; the repository enforces that.
///
/// Every duration is whole seconds. The instants are stored as whole seconds
/// too, which is what lets the timer be pure wall-clock arithmetic.
@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get eventId => integer().references(Events, #id)();

  /// When the session began.
  DateTimeColumn get startedAt => dateTime()();

  /// Null while the session is running.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// The planned length when the session started, plus any extensions.
  IntColumn get plannedSeconds => integer()();

  /// Completed pauses, in total.
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();

  /// When the current pause began; null unless the session is paused.
  DateTimeColumn get pauseStartedAt => dateTime().nullable()();

  /// Time actually worked. Written when the session ends.
  IntColumn get activeSeconds => integer().withDefault(const Constant(0))();

  /// Time worked past the planned end. Written when the session ends.
  IntColumn get overtimeSeconds => integer().withDefault(const Constant(0))();

  /// 0 running, 1 completed, 2 finished early, 3 abandoned.
  IntColumn get outcome => integer().withDefault(const Constant(0))();

  /// 1–5 (drained → charged). Null = not reflected.
  IntColumn get energyRating => integer().nullable()();

  /// 1–5 (scattered → in flow). Null = not reflected.
  IntColumn get focusRating => integer().nullable()();

  /// Comma-joined tag ids, max 4. Null or empty = none.
  TextColumn get tagsCsv => text().nullable()();

  /// 0–140 chars, trimmed. Null or empty = none.
  TextColumn get note => text().nullable()();
}
