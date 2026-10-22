# Energy Clock — Flight Deck (Aero Center) — Design

**Date:** 2026-10-14
**Scope:** New 5th window named **Flight Deck** (chosen over "Aero Center" / "Calm Skies"). Flight list hub + aerophobia calm kit. Offline-first, no backend.
**Approach:** A — Light aggregator (approved). No DB migration, reuse existing flight events + settings store, bundled calm content.
**User decisions:** manage = flight list hub (read-only, tap opens edit) → calm = full kit scoped to breathing + grounding + favorites for v1 → lives as 5th tab → named Flight Deck → must-haves = breathing + grounding only.

## 1. Architecture & data model

New module `lib/features/flight_deck/` (screen + widgets + `calm_content.dart` + providers). No new Drift table, no schema bump.

- **Navigation:** `TabScaffold` + `AppTabBar`: `tabCount` 4→5, 5th entry label `Deck` (full title `Flight Deck`, `Strings.tabDeck` / `Strings.flightDeckTitle`), plane icon (`CupertinoIcons.airplane`), kept-alive via existing `_visited` IndexedStack pattern. Semantics become "tab X of 5".
- **Flights source:** existing `calendar_repository` streams (month-range query), filtered client-side on `isFlight`, sorted by date + startMinute. No new DAO/provider for writes.
- **Favorites source:** existing `settingsRepository` (key-value store, same pattern as `onboardingDoneProvider`) with key `flight_deck_favs` holding a comma-joined string of calm-card ids via the existing `getString`/`setString` (the repo has no string-list API). `AsyncNotifier` reads on build, toggle writes back.
- **Rules:** Features never import each other; Flight Deck imports only `data/`, `core/`, `app/`, `shared/`. All copy in `lib/core/strings.dart`. All colors via theme tokens (`tone_colors.dart` / `tokens.dart`) — the no-hardcoded-colour test must keep passing.

## 2. Components (UI)

All inside `features/flight_deck/`. Tab keeps state when switching (existing scaffold behavior).

- **Next-flight hero:** nearest upcoming flight (end in future) with countdown text ("in 3d 4h" / "today 10:25"), `FLIGHT · SOF→BER` subtitle, plane marker. Tap → `selectedDateProvider.select(date)` + jump to Clock tab (reuse `CalendarTab._openDay` pattern). Empty state: "No flights yet — mark an event as a flight".
- **My flights list:** Upcoming / Past grouped headers, rows show title + `LH715 · SOF→BER` + date/time, trailing plane icon. Read-only here; tap opens the existing event sheet edit flow (no new creation form in v1).
- **Calm kit cards:** 10 facts (safety stats, turbulence explainer, "sounds are normal", pilot quotes) + 8 tips (breathing, seat choice, talk to crew, caffeine/sleep), fixed bundled set. Card grid/list, each starrable for favorites. Filter chips: All / Facts / Tips / Saved.
- **Breathing timer widget:** preset 4s in / 4s hold / 6s out, animated ring + phase label, start/pause/reset, haptics on phase change, respects `MediaQuery.disableAnimationsOf` (reduce-motion → numeric only).
- **5-4-3-2-1 grounding stepper:** 5 steps (see/hear/touch…), tap-to-advance with progress dots, reset at end. Local state only.

Visual companion was not needed; user proceeded text-only.

## 3. Data flow

- **Read flights:** providers watch calendar streams → filter `isFlight` → split upcoming (end >= now) / past → next-flight = first upcoming. Countdown is a pure function of start time; UI ticks locally, no DB polling.
- **Open/edit:** tap flight → select date + switch to Clock tab → existing sheet handles edit/delete/validation (same-day guard, IATA + flight-number rules unchanged).
- **Favorites:** `flightDeckFavoritesProvider` (AsyncNotifier<Set<String>>) loads the comma-joined string, `toggle(id)` optimistically updates + persists via `setString`; read back on restart.
- **Calm content:** `const` Dart list `CalmCard(id, kind[fact|tip], title, body)` in `calm_content.dart`, bundled, always offline. No network, no API.
- **Notifications:** no fork — flights already schedule as Inbox events via existing scheduler.

## 4. Error handling & edge cases

- **No new flight validation** — creation/editing stays in the event sheet; Flight Deck never writes flights so same-day-only + IATA rules apply unchanged there.
- **Load failure:** "Couldn't load flights." with retry (provider invalidate). Never throws to user.
- **Empty states:** no flights; no saved favorites ("Star a card to keep it here").
- **Favorites write failure:** revert optimistic update + snackbar, never crash.
- **Countdown edge:** flight today already ended → Past group; flight spanning midnight impossible (table forbids it).
- **Timer lifecycle:** breathing animation cancelled on dispose/tab switch; kept-alive tab restores idle state, never a runaway timer.
- **Out of scope (explicit non-goals):** creating flights from Deck, timezones, live status/API, import/paste-a-booking, checklists/timeline coaching (v2), new Travel tone, recurrence of flights, iPad-specific layout beyond existing adaptive shell.

## 5. Testing

Repo gates: `flutter analyze`, `flutter test`. No golden regen expected (new tab only; default dial pixels unchanged).

- **Pure unit tests:** next-flight picker (upcoming/past split, empty list, countdown text), calm content ids unique, favorites key round-trip.
- **Notifier test:** favorites toggle adds/removes + persists via fake settings repo; write failure reverts.
- **Widget tests:** 5th tab appears with plane icon + "tab 5 of 5" semantics; groups render; empty state shows; fact/tip cards render + star toggles + Saved filter; breathing timer starts/pauses/resets; grounding steps advance to completion.
- **Regression:** no-hardcoded-colour test passes; existing flight overlay/sheet tests untouched; tab switch preserves Deck state.
