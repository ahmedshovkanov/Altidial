# Energy Clock — Flight Blocks (Travel Day Mode v1) — Design

**Scope:** New avia feature: manual flight blocks on the 24h dial as a pinned overlay arc. Same-day only, manual entry only, offline-first (no backend, no API).

**Approach:** A — Flight fields on the event (approved). Nullable flight columns on the existing `events` table; overlay rendering only; tone forced to Inbox so Stats/export/notifications need no fork.

**User decisions:** Travel day mode → flight blocks on dial → manual entry only → pinned overlay arc → same-day only.

## 1. Architecture & data model

Existing pattern stays: `lib/data/tables/events_table.dart` → Drift DAO (`event_dao.dart`) → `calendar_repository` → Riverpod providers (`lib/data/providers.dart`) → `features/clock` UI. Features never import each other.

Schema change — one migration on `events`:
- `isFlight: bool, default false`
- `flightNumber: String?` (e.g. `LH715`, optional, uppercased, trimmed, max 8 chars)
- `fromCode, toCode: String?` (IATA, 3 uppercase letters, e.g. `SOF`, `BER`)

Rules for v1:
- A flight *is* an event: it carries `date, startMinute, endMinute` like everything else, same-day only (`endMinute > startMinute`, never crosses midnight — the table already forbids midnight crossing).
- Tone is forced to `Inbox` when `isFlight` is true, so Stats (tone balance, planned-vs-actual, heatmap), energy score, export, and notifications treat it as ordinary Inbox with zero changes. The "pinned" distinction is purely visual in the dial painter.
- Normal overlap rules apply — no special blocking logic in v1.
- Existing rows migrate to `isFlight=false, nulls` — no backfill.
- Future anchor: `departureTz/arrivalTz`, buffers, or share-sheet import can extend these columns later without a new table.

## 2. Components (UI)

All inside `features/clock` (+ theme tokens, core validator). No new screens, no new tabs.

- **Dial overlay (`widgets/dial_painter.dart`, `core/geometry/dial_geometry.dart`):** events with `isFlight` paint last, on top of normal arcs, as a thicker striped arc in the Inbox-orange family resolved from theme tokens (`tone_colors.dart` / `tokens.dart` — never hard-coded; the no-hardcoded-colour test must keep passing) with a plane marker at mid-angle and `FROM→TO` label when space allows. Semantics (`dial_semantics.dart`): "Flight LH715, SOF to BER, 10:25 to 14:10".
- **Event sheet (`widgets/event_sheet.dart`):** a "This is a flight" switch. Off = today's sheet unchanged. On = reveals 3 fields (Flight no. optional, From / To required, auto-uppercase) above the existing time picker. Time picker stays same-day constrained.
- **Today's plan list (`todays_plan_list.dart`) + Now card:** flight rows show a trailing plane icon + `LH715 · SOF→BER` subtitle. No behaviour change.

Visual companion was offered during brainstorming; user continued text-only.

## 3. Data flow

Create / edit / delete reuse the existing write path; no new repository, DAO, or provider.

- **Create:** event sheet → validate (see §4) → `eventDao.create` / `calendar_repository` with `isFlight + flight fields`, `toneIndex` forced to Inbox.
- **Edit:** same sheet; toggling flight off keeps title/times but explicitly clears the 3 flight columns (no orphan data). Toggling on requires From/To.
- **Delete:** existing `delete_event.dart` flow; columns die with the row, no cascade.
- **Read:** calendar day stream returns the new columns after `build_runner` codegen; dial + list branch on `isFlight` client-side for overlay styling only.
- **Notifications (Step 5):** flights schedule like any Inbox event via the existing `NotificationScheduler` — no fork.
- **Migration:** Drift schema version bump + `dart run build_runner build --delete-conflicting-outputs` with the Flutter SDK's `dart`.

## 4. Error handling & edge cases

Tight by design (same-day + manual only); all failures are inline, never throws to the user.

- **Validation (inline in sheet, save disabled until valid):** From/To required when `isFlight` is on, exactly 3 `A–Z` letters (auto-uppercase, strip spaces); flight number optional, uppercased, max 8 chars, `A–Z 0–9` only. Copy lives in `lib/core/strings.dart`.
- **Overnight rejected:** `endMinute <= startMinute` with `isFlight` on → "Same-day flights only in v1 — split overnight flights into two blocks for now", save blocked. No midnight-split rendering.
- **Overlap:** existing conflict UI applies unchanged; flights get no exemption.
- **Toggle-off:** clears flight columns; downstream (export/stats) sees a plain Inbox event, so nothing breaks.
- **Out of scope (explicit non-goals):** timezones, auto buffers (60/30 min), live status/API, import/paste-a-booking, new Travel tone, recurrence of flights, iPad-specific layout beyond the existing adaptive shell.

## 5. Testing

Follows repo gates: `flutter analyze`, `flutter test`, golden rule (`flutter test --update-goldens` only after deliberate visual change + image review).

- **Pure validator unit tests** (`test/core/...flight..._test.dart`): IATA + flight-number normalize/validate, same-day guard.
- **DAO/repository test:** create flight event → read back columns; toggle-off clears columns; pre-migration rows read as `isFlight=false`.
- **Widget tests:** sheet shows/hides flight fields on toggle, blocks save on bad codes / overnight; plan list shows plane subtitle; dial overlay geometry called on top (no pixel assertions).
- **Regression:** no golden regen expected when zero flights exist (default dial pixels unchanged); no-hardcoded-colour test keeps passing.
