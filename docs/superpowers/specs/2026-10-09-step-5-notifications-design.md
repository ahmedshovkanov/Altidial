# Energy Clock — Step 5: Notifications — Design

**Scope:** Master spec §10 (all four local notifications, permission at first meaningful use) plus the deferred foreground job: materialising recurring series for the next 7 days whenever the app foregrounds. The session-end notification already exists (`session_alerts.dart`, id 1001) and is kept; everything else here is new.

**Approach:** Foreground reconciliation (approved). No background modes, no entitlements, no new runtime packages. Once scheduled, iOS fires pending notifications even if the app never opens again; each foreground refreshes the 7-day horizon.

**User decisions:** Event lead time fixed at 10 minutes (no setting). Morning reminder configurable, default 08:00, choices 06:00–10:00 in 30-minute steps. Roundup announcement fixed Sunday 20:00 (no setting). Four independent per-type toggles on Profile.

## 1. The four notifications

| Notification | Id | When scheduled | Condition |
|---|---|---|---|
| Session ended | `1001` (existing) | Running session's planned end, kept in line while it runs | Session-end toggle ON |
| Event starting soon | `10000 + eventId` | `event.start − 10 min`, for events in `[now, now+7d)` | Event toggle ON; skipped when the instant already passed |
| Daily planning reminder | `20000 + yyyymmdd` | The configured morning time, next 7 mornings | Morning toggle ON; only for days with zero events |
| Weekly Roundup ready | `30001` | The upcoming Sunday 20:00 (this Sunday if still ahead, else next) | Roundup toggle ON |

Event ids are stable database ids, so rescheduling replaces. Date ids (`20261009` → `20261009 + 20000`) fit comfortably in an int. iOS allows 64 pending per app: event reminders are capped to the nearest 32 in time; the rest are dropped (documented, logged, never erroring — a real 7-day window never reaches 32).

A day is "empty" when it holds zero non-deleted events (status 2 excluded), regardless of sessions. The morning body is therefore always the empty-day variant.

## 2. Scheduler

**`NotificationScheduler`** in `lib/data/repositories/` (data layer: session screen, event sheets and Profile drive it through providers; no feature imports another feature).

- **Pure `computeSchedule({...})`** in `lib/core/notifications/schedule.dart`. Inputs: upcoming event starts (`List<({int eventId, DateTime startsAt, String title, Tone tone})>`), the set of empty dates in the horizon, toggle states, morning minutes, now. Output: `List<DesiredNotification> ({int id, DateTime at, String title, String body})`. No clock, no database — exhaustive unit tests, including DST mornings.
- **Thin `DriftNotificationScheduler.reconcile()`**: materialise-then-read (see §4), call `computeSchedule`, diff against the previously desired set held in memory: cancel ids that disappeared or moved, schedule new/changed ones. Per-id try/catch — one failing schedule never blocks the rest, and a reconcile never throws. The in-memory set starts empty every launch (stable ids make the first pass schedule-everything, cancel-nothing, which is correct). Toggling a type OFF diffs `computeSchedule` with that toggle forced on versus actually off and cancels exactly the difference — no persisted state, restart-safe.

**Triggers:** app foreground, event create/edit/delete (including series operations and template/copy applications — anything that writes events), toggle flip, morning-time change, permission grant. Rapid bursts coalesce: a reconcile already running or queued collapses into one pass. Session start/end do *not* trigger (ending a session changes no plan).

**Ordering:** one `foregroundRefresh()` runs materialisation first, then the scheduler, so the scheduler always reads expanded series.

## 3. Permission

Spec §10: requested at first meaningful use, never at launch.

- The existing session-start prompt is unchanged.
- Flipping any toggle ON is a meaningful use: if permission is undetermined, the flip fires the system prompt. Granted → toggle sticks, reconcile runs. Refused → toggle snaps back OFF, snackbar with an "Open Settings" action (existing `openSettings()`).
- Toggling OFF never prompts; it runs the forced-on-versus-off diff from §2 and cancels exactly the orphaned ids.
- If the OS-level permission is off, the Profile group shows an "off" state (see §5) rather than dead toggles.

## 4. Foreground materialisation

The Step 3 deferral lands here: `foregroundRefresh()` expands every recurring series over `[startOfDay(today), +7 days]` via the existing `SeriesMaterialiser`, then reconciles notifications. Same trigger point as the scheduler (app foreground via the existing lifecycle observation), materialise-first ordering guaranteed by construction, materialiser failure degrades to "schedule from stored events" exactly like the Calendar does.

## 5. Profile settings UI

A "Notifications" group in the existing settings card, after the current rows:

- Four toggle rows with native `CupertinoSwitch` in place (no dialog): Session end, Event starting soon, Weekly roundup, Morning reminder. Keys `settings-notify-session`, `-event`, `-roundup`, `-morning`.
- A morning-time row (value like "8:00 AM", `chooseOne` sheet, 06:00–10:00 step 30), disabled (muted, untappable) while the morning toggle is off. Key `settings-morning-time`.
- When `areEnabled()` is false at the OS level, the four toggles are replaced by a single "Notifications are off" row that opens the Settings app. The morning-time row stays visible but disabled.
- New settings keys: `notify_session_end`, `notify_event_soon`, `notify_roundup`, `notify_morning` (booleans, default true — inert until permission exists), `morning_reminder_minutes` (int, default 480).

## 6. Copy

All in `lib/core/strings.dart`. Event: `"<title> starts in 10 minutes"` plus tone context — final shape `"<title> (Focus) starts in 10 minutes"`? No: keep the title clean and put the tone in the subtitle position iOS provides — the plugin's `schedule` takes title+body only, so: title = event title, body = `"Starts in 10 minutes · Focus"`. Morning: title `"Plan your day"`, body `"Today is wide open — put something on the dial."` Roundup: title `"Your Weekly Roundup is ready"`, body `"Week 41 in review: scores, streaks and badges."` with the real week number. Session-end copy is unchanged.

## 7. Error handling

- Plugin throw during reconcile: swallowed per-id, reconcile completes, next trigger retries (desired set is recomputed from scratch every time, so nothing wedges).
- Permission revoked at OS level after scheduling: pending items silently never fire; next foreground's `areEnabled()` check flips Profile to the off-state. No error UI.
- Timezone/DST travel: instants are absolute (`at` is a `DateTime` instant; the service already sends UTC). A morning time is a wall-clock time re-resolved every reconcile — after travel it fires at the right local hour without orphaned ids (stable date ids replace).
- Past instants are never scheduled (filtered in `computeSchedule`, belt-and-braces in the scheduler).

## 8. Testing

- Pure `computeSchedule` tests: lead math, already-passed filtering, empty/non-empty days, Sunday 20:00 selection from each weekday, 64-cap with 100 events, DST spring-forward morning.
- Fake-service reconcile tests: event added → scheduled; event deleted → cancelled; toggle off → all of type cancelled; plugin throw → swallowed and retried next pass; empty week → 7 dailies; full week → none.
- Widget tests: four toggles flip and persist; refused permission snaps back + snackbar; morning row disabled with toggle off; OS-off state row opens settings (fake counter); foreground triggers materialise+scheduler (fake calls).
- No new goldens (toggle rows reuse existing chrome). Manual simulator pass: real notifications arrive with the app foregrounded, backgrounded, and the device locked; roundup item on Sunday 20:00 verified by clock override on a dev build.

## 9. Build order and risks

1. Pure schedule computation + unit tests (no UI, no plugin).
2. Scheduler + foregroundRefresh wiring + fake-service tests.
3. Toggles + morning row + off-state + permission flow + widget tests.
4. Manual device verification.

Biggest risk: iOS pending-notification visibility is untestable in CI — the fake proves our logic, only the simulator proves firing. Second risk: `flutter_local_notifications` version API drift in `zonedSchedule` — the service layer already absorbs it; the scheduler never touches the plugin directly.

## 10. Out of scope

Notification content extensions (custom sounds, images), snooze/actions, per-event custom lead times, watch complications, push notifications, analytics on opens. The post-Step-4 note (review XP/level gameiness) is a design review, not Step 5 work.

## 11. Open items (all resolved during brainstorming)

- Lead time: fixed 10 min. Morning: configurable, default 08:00. Roundup: fixed Sunday 20:00. Toggles: four per-type. No remaining open items.
