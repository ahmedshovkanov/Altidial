# Energy Clock — Step 1: Design Foundation, Clock Redesign, Brand and iPad

**Date:** 2026-10-03
**Status:** Design approved in conversation (Parts 1–4 and 3b); awaiting written review
**Roadmap position:** Step 1 of 6 (see §1)
**Amends:** `2026-08-23-energy-clock-design.md` (see §3)
**Platform:** iOS 15+. iPhone in portrait; iPad in all four orientations with resizable windows. Flutter 3.44.7 / Dart 3.12.2

---

## Summary

Step 1 turns the working-but-plain Clock tab into a finished-looking product and
lays the foundation every later step builds on.

- A bold, colourful design system (tokens, one bundled rounded font, shared
  components, a floating tab bar). Colour only ever encodes a tone.
- Dial v2: a bigger raised face that resizes with the number of overlapping
  rings, thicker arcs, a rim marker instead of the long hand, a night tint,
  animations, and VoiceOver support.
- A new Clock screen: week strip, dial, tone-coloured **Now card**, day-load bar,
  and on wide iPad windows a two-pane layout with a Today's plan list.
- Restyled event sheets, a real app icon and launch screen, and a three-screen
  onboarding with an optional sample day.
- iPad support with narrow, medium and wide layouts (this reverses the Aug 23
  "iPhone only" decision at the user's request).

Step 1 alone is **not a release candidate**: Calendar, Stats and Profile remain
placeholders until Steps 3–5.

---

## 1. Context and roadmap

On 2026-10-03 only Phase 1 of the Aug 23 spec existed: the dial planner. A review
of the app found:

- Three of four tabs are "coming soon" placeholders (App Review guideline 2.1).
- No timer session, notifications, or settings (guideline 4.2).
- The default Flutter app icon and a blank white launch screen.
- No privacy policy link or support contact (guidelines 5.1.1(i) and 1.5).
- A stock Material 3 look. The dial face is only about 56% of the screen width,
  and the hand's centre dot covers the digital time.
- No accessibility semantics; the dial is invisible to VoiceOver.
- An iPad build setting (`TARGETED_DEVICE_FAMILY = "1,2"`) with only portrait
  declared for iPad, which App Store Connect is expected to reject at upload
  (ITMS-90474: iPad multitasking requires all four orientations). This comes from
  the plist and public reports; the real upload check is part of Step 6.

The goal is App Store submission. The roadmap, chosen by the user on 2026-10-03:

| Step | Work | Source |
|---|---|---|
| 1 | Design foundation, Clock redesign, brand assets, onboarding, iPad support | This spec |
| 2 | Session timer, notifications, crash recovery | Aug 23 spec §6, §10 (Phase 2) |
| 3 | Calendar month grid, recurring events, day templates, copy-yesterday | §7 (Phase 3) |
| 4 | Statistics | §8 (Phase 4) |
| 5 | Progress, Profile and Settings. XP and levels are recommended for removal from 1.0 | §9 (Phase 5) |
| 6 | Submission kit: privacy policy page, support URL, privacy manifest, iPhone and iPad screenshots, TestFlight, store listing | New |

Each step gets its own spec amendment and plan. Steps 2–5 are built on this
step's foundation (tokens, components, adaptive layout) and must follow the same
three window sizes.

---

## 2. Decisions taken

These were settled in conversation and are not open in planning.

| Area | Decision |
|---|---|
| Look | **Bold and colourful**, chosen over "Soft and airy" and "Dark and glowing": deep tone colours, thick arcs, bold rounded type, large numerals |
| Colour use | **Plain background.** Colour only ever encodes a tone. The Now card takes the current tone's colour. A "mood screen" (the whole top of the screen tinted) was considered and deferred; the foundation must not prevent adding it later |
| UI accent | Near-black (white in dark mode) for buttons and the selected tab. Never purple, because purple means Focus |
| Typeface | Nunito (SIL Open Font Licence), four weights, bundled as assets |
| iPad | **Supported** (user decision). All four orientations on iPad, iPhone stays portrait, multitasking stays on. Narrow / medium / wide layouts; two panes and a Today's plan list on wide |
| Now indicator | A thick marker on the rim of the face replaces the long hand, so the centre text is never covered |
| Day navigation | A week strip replaces the `<` `>` arrows |
| First run | Three-screen onboarding with an optional sample day |
| App icon | Generated in code from the dial's arc style; replaceable by a designer's files |
| Start button | Added to the Now card and the detail sheet in Step 2. No dead button in Step 1 |

---

## 3. Amendments to the 2026-08-23 spec

| Aug 23 reference | Change |
|---|---|
| Header: Platform | "iOS 15+. iPhone portrait; iPad all orientations, resizable windows" replaces "iPhone, portrait, iOS 15+" |
| §2 "Visual language" | Replaced by §4 of this spec (bold and colourful). `image.png` remains the reference for the arcs-on-a-dial concept, not for colours, weights, or the thin ticks |
| §2 "Explicitly out of scope" | "iPad" is removed from the list |
| §5.1 dial: "a single 'now' hand" | A rim marker (§7.2). The centre still shows the time and the tone in effect |
| §5.1 geometry | Face and ring sizes depend on the number of rings in use (§7.1) |
| §5 Clock screen | Adds the week strip, Now card, day-load bar and (wide only) Today's plan list (§8) |
| §11 Theming | Replaced by §4. "Every colour is defined once in the theme" still holds and is now enforced by a test (§14) |
| §12 Manual verification | Adds a small iPhone, iPad Pro 13" in all orientations, Split View, light and dark, largest text size |
| §14 Build phases | Step 1 is inserted before Phase 2 (§1 above) |
| §15 Dependencies | No new packages. Adds font assets (§15) |

Everything else in the Aug 23 spec is unchanged, including the three fixed tones,
the data model, the minute domain, drag rules, overlap rules, and read-only past
days. The carried-over rules from the Phase 1 plan still apply: English-only copy
in `lib/core/strings.dart`; no feature imports another feature; no charting
library, HTTP client, or analytics SDK.

---

## 4. Design tokens

All tokens live in `lib/app/theme/`. Feature code never hard-codes a colour,
size, duration, or font; it reads tokens through the theme (`context.appColors`,
`context.toneColors`, `AppSpacing`, `AppRadii`, `AppMotion`, `Theme.textTheme`).

### 4.1 Colour

Every pair below was checked with a contrast script. Text pairs meet 4.5:1; arcs
against the face meet 3:1. §14 turns these checks into unit tests.

**Tone palette.** Each tone has four colours: `solid` (arcs, Now card, day-load
segments), `onSolid` (text on `solid`), `soft` (chip background), `deep` (text on
`soft` or on the page).

| | Light solid | Light onSolid | Light soft | Light deep | Dark solid | Dark onSolid | Dark soft | Dark deep |
|---|---|---|---|---|---|---|---|---|
| Focus | `#6D4AFF` | `#FFFFFF` | `#ECE8FF` | `#4A2FD1` | `#8E78FF` | `#17141F` | `#2A2450` | `#C9BEFF` |
| Life | `#14A85A` | `#17141F` | `#DDF7EA` | `#0E7A47` | `#34D399` | `#17141F` | `#16382B` | `#A7F3D0` |
| Inbox | `#F26B00` | `#17141F` | `#FFEBD6` | `#9A4D00` | `#FFA040` | `#17141F` | `#402A12` | `#FFD2A1` |

White text is readable only on Focus purple (5.15:1). On Life green (3.1:1) and
Inbox orange (3.05:1) it falls short of 4.5:1, so those use near-black text (5.9:1
and 5.95:1).

**Neutrals** (`AppColors` theme extension).

| Token | Light | Dark |
|---|---|---|
| `page` | `#F4F5F7` | `#0F0F14` |
| `surface` (cards, dial face, sheets) | `#FFFFFF` | `#1A1A22` |
| `ink` (text, buttons, selected tab) | `#17141F` | `#F4F4F8` |
| `onInk` (text on `ink`) | `#FFFFFF` | `#17141F` |
| `muted` (secondary text) | `#5E5B6B` | `#A7A5B5` |
| `outline` (hairlines, decorative) | `#E4E4EA` | `#2C2C38` |
| `danger` (delete, errors) | `#C4261B` | `#FF6B63` |
| `nightTint` (decorative) | `#4A6FA5` at 8% | `#7C9CFF` at 12% |

`ColorScheme` for Material widgets is built from these tokens: `primary = ink`,
`onPrimary = onInk`, `surface`, `error = danger`, `outline`. The seed colour
`0xFF6C5CE7` in `AppTheme` is removed.

### 4.2 Typography

Nunito, bundled as four static weights (400, 600, 700, 800). Google publishes
Nunito only as one variable font, so the four static files are cut from it with
`fontTools` (see §15).

| Style | Size | Weight | Use |
|---|---|---|---|
| `displayTime` | `clamp(0.22 × faceRadius, 22, 44)` | 800 | Dial centre time |
| `titleLarge` | 28 | 800 | Day name, sheet titles |
| `title` | 20 | 700 | Card and event titles |
| `body` | 16 | 400 | Body text |
| `bodyStrong` | 16 | 700 | Emphasis, button labels |
| `label` | 14 | 700 | Chips, tab labels, week pills |
| `caption` | 12 | 600 | Captions, legends |
| `dialNumeral` | `0.13 × faceRadius`, min 11 | 800 | Dial hour numerals |
| `arcLabel` | `0.5 × ringWidth`, min 10 | 800 | Curved arc labels |

Time displays use tabular figures so they do not jitter, if Nunito supports them
(open item 1, §15). Text drawn on the dial uses a text scale clamped to 1.2; all
other text scales fully.

### 4.3 Spacing, shape, elevation, motion

- **Spacing scale:** 4, 8, 12, 16, 20, 24, 32, 40.
- **Radii:** chip 12, control (button, field, tone tile) 16, card 24, sheet 28, pill 999.
- **Elevation, light mode:** card `0 2 12` at 8% ink; dial face `0 6 24` at 12%
  ink; floating tab bar `0 8 24` at 16% ink.
- **Elevation, dark mode:** no shadows. A 1 px `outline` border and a one-step
  lighter `surface` carry the layering.
- **Motion:** fast 150 ms, base 250 ms, slow 400 ms. Standard curve
  `Curves.easeOutCubic`; pop curve `Curves.easeOutBack`. All durations are 0 and
  all loops stop when iOS Reduce Motion is on (`MediaQuery.disableAnimations`).
- **Haptics:** `selectionClick` on tab change, day-pill tap and tone selection.
  The existing drag haptics stay.

### 4.4 Structure

- `lib/app/theme/app_colors.dart`: `AppColors` extension and context accessor.
- `lib/app/theme/tone_colors.dart`: `ToneColors` becomes a per-tone table of
  `TonePalette(solid, onSolid, soft, deep)` with `paletteFor(tone)`. `fillFor`
  and `labelFor` stay as thin wrappers (`solid` and `onSolid`) so existing call
  sites keep working; `softFor` and `deepFor` are added.
- `lib/app/theme/tokens.dart`: `AppSpacing`, `AppRadii`, `AppMotion`.
- `lib/app/theme/app_typography.dart`: the text theme.
- `lib/app/theme/app_theme.dart`: builds light and dark `ThemeData` from the
  above. Splash effects are disabled in favour of a press-scale (skipped under
  Reduce Motion).

---

## 5. Adaptive layout

Layout follows the **app window width**, not the device name, because iPad windows
resize in Split View, Slide Over, and iPadOS windowing.

| Window class | Width | Where it occurs | Clock layout |
|---|---|---|---|
| Narrow | under 600 pt | iPhones, and iPad windows in Slide Over or a narrow Split View | Single column (§8) |
| Medium | 600–899 pt | iPad mini and iPad 11" in portrait, wider Split View windows | Single column, centred, at most 560 pt wide |
| Wide | 900 pt and up | iPad 13" in portrait, and full-screen iPads in landscape | Two panes (§8.8) |

- `lib/shared/layout/window_class.dart`: `WindowClass` enum and
  `windowClassFor(double width)`.
- `lib/shared/layout/content_width.dart`: `ContentWidth(maxWidth, child)`
  centres its child. Maximum widths: medium column 560; modal sheets and dialogs
  560; onboarding 480; tab bar 480.
- The theme caps modal bottom sheets at 560 pt wide
  (`bottomSheetTheme.constraints`); they sit bottom-centred, and each sheet asks
  for the drag handle itself once it scrolls. Confirmation dialogs show the native
  alert on iOS and a Material dialog elsewhere, chosen by an explicit iOS check
  (`flutter test` reports the host platform, so `AlertDialog.adaptive`, which also
  picks the iOS style on macOS, would change what tests see).
- All tap targets are at least 44 pt.
- The Clock page never scrolls (a vertical scroll would compete with the dial's
  drag gestures). Instead §8.7 compacts it.

---

## 6. Shared components and navigation

Components live in `lib/shared/widgets/` and use only tokens.

- **`AppCard`**: `surface` fill, radius 24, elevation per §4.3, padding 16.
- **`ToneChip`**: pill; `soft` fill, `deep` text in `label` style, a 8 pt `solid` dot.
- **`AppButton`**: at least 56 pt tall, radius 16, `bodyStrong` label, full width
  by default. Variants: *primary* (`ink` fill, `onInk` text), *secondary* (`ink`
  at 8% fill, `ink` text), *destructive* (text only, `danger`). Disabled at 38%
  opacity.
- **`SectionHeader`**: `title` text with an optional trailing action.

**`AppTabBar`** (`lib/app/navigation/app_tab_bar.dart`) replaces the Material
`NavigationBar`.

- A floating pill, 64 pt tall, radius 32, `surface` fill with the floating-bar
  shadow, centred, 12 pt above the bottom safe area, at most 480 pt wide.
- Four items, each at least 44 × 44 pt. The selected item is an `ink` pill with
  `onInk` icon and label; unselected items show a `muted` icon only.
- Icons: `CupertinoIcons` for Calendar, Stats and Profile. The Clock icon is
  `TabDialIcon`, a small custom painter drawing a three-arc ring (tone colours
  when selected, `muted` when not).
- `selectionClick` on change. Semantics: button, selected state, "tab N of 4".

**`TabScaffold`** keeps all four tabs alive in an `IndexedStack`, building each
tab the first time it is selected. It exposes the bar's height plus margin as
`TabBarInset.of(context)`, which screens add as bottom padding.

---

## 7. Dial v2

### 7.1 Geometry

`DialGeometry.fitted(Size size, {int ringCount = 3, double? maxRadius})`:

```
R           = min(size.shortestSide / 2 - 8, maxRadius ?? infinity)
ringWidth   = R * {1: 0.15, 2: 0.13, 3: 0.11}[ringCount]
ringGap     = 0.018 * R
inset       = 0.045 * R
faceRadius  = R - inset - ringCount * ringWidth - (ringCount - 1) * ringGap
```

The face is about 0.805 R, 0.677 R, 0.589 R for 1, 2, 3 rings. **The three-ring case
equals today's geometry**, so today's size is the worst case and every other case
is larger.

- `DialGeometry` gains an immutable `ringCount` field that defaults to
  `maxRings`, so every existing geometry test stays valid. `orbitOuterRadius`
  and `ringAtPoint` use it. `orbitOuterRadius` equals R for every ring count.
- `DialGeometry.lerp(a, b, t)` supports the resize animation.
- Rings in use = `max(1, highest ring index from assignRings + 1)`. Events beyond
  three rings are never drawn, as today.
- Geometry changes only when stored events change, never during a drag. Hit
  testing always uses the target geometry, not a mid-animation one.
- **Hit slop:** the creation band and each ring's hit area are widened by 12 pt on
  each side. Where two rings' areas meet, the ring with the nearest centre wins.
  The thinnest case (one ring, small phone) stays at least 44 pt.
- On phones the dial is limited by the height left after the other Clock-screen
  elements, not only by the width. On an iPhone 17 Pro the face is about 77% of the
  screen width (it is 56% today).

### 7.2 Painting

All colours come from tokens. Paint order:

1. **Face:** `surface` fill; shadow (light) or 1 px `outline` (dark).
2. **Night tint:** the 21:00–06:00 sector, clipped to the face, `nightTint`, edges
   fading over one hour of arc. Fixed hours (no location). Behind a
   `showNightTint` constant so it can be removed if it looks busy.
3. **Ticks:** 24 hourly ticks with round caps, `ink` at 40%. Every third hour is
   thicker (2.2 pt against 1.2 pt) and longer (0.085 F against 0.045 F).
4. **Numerals:** 0, 3, … 21 at radius 0.70 F, `dialNumeral`.
5. **Arcs:** `solid` fill, round caps, `ringWidth` thick, with a 2 pt outline in
   the `page` colour (what is behind the arcs) beneath so adjacent arcs separate.
   Labels use `onSolid` and
   `arcLabel`, curved as today, and are omitted when they do not fit.
6. **Ghost:** the dragged range at ring 0, `solid` at 55% (unchanged).
7. **Rim marker** (selected day is today only): a capsule between 0.80 F and
   0.96 F, thickness `max(6, 0.05 F)`, a 2 pt `surface` outline, in the `solid`
   colour of the active event's tone, or `ink` when nothing is active. It clears
   the numerals (outer edge about 0.765 F). The long hand and its hub are removed.
8. **Centre text:** the time in `displayTime`, and below it the active tone's name
   in `label` style in its `deep` colour. While dragging, the swept range and its
   duration replace them. The block fits inside radius 0.55 F.

### 7.3 Motion

- **Sweep-in:** on first paint of a day and on day change, arcs sweep from start
  to end over 400 ms, staggered by 40 ms (at most 5 staggered).
- **Pop:** a newly created arc grows from 90% to 100% of its thickness while it
  sweeps in over 250 ms with `easeOutBack`.
- **Ring-count change:** `DialGeometry.lerp` over 350 ms with `easeOutBack`.
- **Empty-day hint:** on an editable empty day, a ghost arc at 09:00–10:00 on
  ring 0 in Focus colour pulses between 20% and 50% opacity every 1600 ms. It is
  not interactive and disappears when any event exists.
- **Reduce Motion:** no sweep, pop, lerp, or pulse. The hint is static at 35%.

### 7.4 Interaction

Unchanged: drag in the orbit band to create (5-minute snap, 15-minute minimum,
clamp at 24:00, haptic ticks), drag an arc to move, drag its ends to resize, tap
an arc for details, a fourth overlapping ring is refused with "Up to three
overlapping events."

---

## 8. Clock screen

`ClockScreen` composes the pieces below. `DayHeader` is replaced by `ClockHeader`.

### 8.1 Header (`ClockHeader`)

- Left: the day name in `titleLarge` and the date in `caption` under it.
- Right: a **Today** pill button (shown when the selected day is not today) and a
  44 pt round **+** button (`ink` fill, `onInk` icon; disabled on past days).
- A past day shows a small neutral "Read-only" chip (`outline` border, `muted`
  text) in place of the old "Past days are read-only" text line.

### 8.2 Week strip (`WeekStrip`)

- Seven day pills for the week containing the selected day, **Monday first** until
  Step 5 adds the first-day-of-week setting.
- Each pill: weekday abbreviation (`caption`), date number (`label`), and up to
  three 6 pt dots in the `solid` colours of the tones planned that day.
- Selected pill: `ink` fill, `onInk` text. Today (when not selected): an `ink`
  outline. Tap selects the day (`selectionClick`). Swiping horizontally moves the
  selected day by seven days (same weekday), so the header, dial and strip always
  agree. The strip is an unbounded `PageView` that also follows
  `selectedDateProvider` when the date changes elsewhere (for example the Today
  button).
- Each pill is at least 44 pt wide on a 375 pt phone.

### 8.3 Now card (`NowCard`)

`computeNowStatus` (pure Dart, `lib/features/clock/model/now_status.dart`) turns
the day's events, the selected day and the current time into one of:

| State | When | Card |
|---|---|---|
| Active | Selected day is today and an event has `start <= now < end` | Filled with the tone's `solid`, text `onSolid`. Tone chip, event title, "42 min left · until 11:00", a thin progress bar. If several events are active, the one that started latest (ties: the higher id) is shown with "+N overlapping" |
| Next | Today, nothing active, a later event exists | Neutral card. "Next up", title, "Starts at 12:30 · in 40 min", a tone dot |
| Free | Today, no events | "Nothing planned yet" and "Drag around the ring to block out your first event." |
| Done | Today, events exist, all ended | "All done for today" and "5 events · 6h 30m planned" |
| Future summary | Future day | "Tuesday · 5 events" and "6h 30m planned"; empty: the Free text |
| Past summary | Past day | "Read-only" caption and "5 events · 6h 30m"; empty: "Nothing was planned" |

An event's end minute is exclusive, so an event is not active at its end minute.
Tapping the card opens the detail sheet of the active or next event, if any. Time
displays use minutes only; seconds belong to the Step 2 session timer.

### 8.4 Day-load bar (`DayLoadBar`)

One rounded bar split into tone segments in proportion to planned minutes, with
2 pt gaps and a minimum visible width of 8 pt for any non-zero tone. Beneath it:
"Focus 4h · Life 2h · Inbox 1h" (zero-minute tones omitted) and, at the right,
the total ("7h planned"). `computeDayLoad` sums each event's duration per tone, so
**overlapping events count twice, because overlap is extra load.** Hidden when the
day has no events. Read by VoiceOver as one sentence (§12).

### 8.5 Empty and read-only states

An empty editable day shows the dial hint (§7.3) and the Free Now-card text.
Past days ignore creation drags, as today.

### 8.6 Narrow and medium layout

A `Column`: header, week strip, the dial (expanded), Now card, day-load bar, then
bottom padding from `TabBarInset`. Medium uses the same column inside
`ContentWidth(560)`.

### 8.7 Vertical space rules (narrow and medium)

Heights at normal text size: header 48, week strip 60, Now card 96, day-load bar
68, gaps 8 (the text-bearing ones grow with the text size). The dial gets what
remains. The full Now card's four lines of text outgrow 96 pt as soon as text is
larger than normal (measured: 98 pt at 115%, 107 pt at 130%), so its budget is
`max(96, 36 + 56 × scale)`; the one-row card is budgeted at `24 + 28 × scale`
(52 pt at normal size).

1. If the dial area is under 300 pt, hide the day-load bar.
2. If it is still under 260 pt, compact the Now card to one row.
3. At text scale above 1.3, hide the day-load bar and the week-strip dots, and
   show only the title and time left in the Now card.

On an iPhone SE (375 × 667) this hides the day-load bar and leaves the dial about
340 pt tall. A fourth rule applies last: if the dial would still be under 240 pt,
the header drops its date line. The layout test (§14) asserts the dial area stays
at least 240 pt in every supported case; if a size fails, the plan adds further
compaction.

### 8.8 Wide layout

A `Row` of two panes with a 24 pt gap, above the floating tab bar.

- **Left:** the dial, centred, with `maxRadius` 340.
- **Right** (width `clamp(0.36 × windowWidth, 340, 440)`): `ClockHeader`,
  `WeekStrip`, `NowCard`, `DayLoadBar`, then **Today's plan** filling the rest.
- **Today's plan** (`TodaysPlanList`, wide only): events sorted by start. Each row
  has a 6 pt tone bar, the title (`bodyStrong`), the time range and duration
  (`caption`). The active event's row is highlighted. Tap opens the detail sheet.
  The list scrolls; it does not conflict with dial gestures because it is a
  separate pane. Hidden when the day has no events.

---

## 9. Event sheets

The same fields and rules as today, restyled with the foundation.

- **New / Edit sheet:** a filled title field (radius 16, no outline), three tone
  tiles at least 72 pt tall (`solid` fill, `onSolid` label, selected = a 3 pt
  `ink` outline and a check icon), Start and End rows with 44 pt round stepper
  buttons and the time in `displayTime`, a duration chip, and a full-width primary
  Save button. The sheet scrolls so large text never overflows.
- **Detail sheet:** tone chip, title, time range, duration; secondary **Edit**,
  destructive **Delete** (confirmed with an adaptive alert). Step 2 adds **Start
  session** above Edit.
- Both are bottom-centred with a 560 pt maximum width (§5).

---

## 10. Brand and first run

### 10.1 App icon

A near-black (`#17141F`) square with a thick ring of three rounded arcs in the
light-mode tone colours, with small gaps between them, drawn with the dial's arc
style. Generated by a script in `tool/brand/` (run with `flutter test`, which
provides `dart:ui` rendering) at 1024 × 1024, then resized to every size in the
existing `AppIcon.appiconset/Contents.json` (iPhone, iPad, marketing) with
`sips`. The 1024 px marketing icon must be opaque with **no alpha channel**
(checked with `sips -g hasAlpha`). The generated PNGs are committed, so the
script is only needed to regenerate.

### 10.2 Launch screen

The ring logo, about 120 pt, centred on a `LaunchBackground` colour set (light and
dark variants) in the asset catalog. `LaunchScreen.storyboard` references the
colour and the image. This replaces the blank white screen.

### 10.3 Onboarding

`lib/app/onboarding/` (an app-level flow shown before the tab shell; it may use the
Clock feature's public repository provider because the app layer composes
features). Three swipeable pages in a `ContentWidth(480)`, with page dots and a
**Skip** button on pages 1–2.

1. **"Plan your day by energy, not just time"**, "Energy Clock puts your day on a
   24-hour dial, so you can see how heavy the day is before you start it." The
   dial's arcs sweep in.
2. **"Three tones for every event"**, three `ToneChip`s with examples. Focus:
   "Deep, demanding work: writing, design, thinking". Life: "Body and rest: sport, a
   walk, lunch". Inbox: "Routine and reactive: email, calls, admin".
3. **"Drag the ring to plan"**, "Press and drag on the ring around the clock to
   block out time. Tap an event to see details, or drag it to move or resize it."
   Buttons: **Start with a sample day** (primary) and **Start empty** (secondary).

**Sample day:** four ordinary events on today: Deep work (Focus, 09:00–11:00),
Email and calls (Inbox, 11:00–11:45), Lunch walk (Life, 12:30–13:15), Writing
(Focus, 14:00–16:00). Created through `EventRepository.createEvent`. Any event that
would need a fourth ring on a day that already has events is skipped.

"Seen" is stored in the existing `settings` table under the key `onboarding_done`.
This is the first reader of that table; no schema change, so no migration. If the
flag cannot be read, onboarding is skipped. A "Replay intro" link is added to
Profile in Step 5.

### 10.4 Housekeeping

- `ios/Runner/Info.plist`: `UISupportedInterfaceOrientations~ipad` lists all four
  orientations (portrait, upside-down, landscape left, landscape right).
  `UISupportedInterfaceOrientations` for iPhone stays portrait only.
  `UIRequiresFullScreen` stays unset. `TARGETED_DEVICE_FAMILY` stays `"1,2"`.
- `pubspec.yaml` description becomes "Plan your day by energy, not just time."
- `README.md` is replaced with a short real README: what the app is, how to run
  and test it, the project layout, and links to the specs.

---

## 11. Data and state

All new user-facing copy goes in `lib/core/strings.dart`.

- **`clockProvider`** (`lib/features/clock/providers.dart`): a
  `NotifierProvider<ClockNotifier, DateTime>` that starts at the current time and
  updates at each minute boundary. It replaces `DialView`'s own 20-second timer,
  so the Now card and the rim marker share one source. Tests override it with a
  `FakeClock` (`clockProvider.overrideWith(() => FakeClock(...))`). The selected
  day starts at, and "Today" returns to, this clock's today.
- **`computeNowStatus`** and **`computeDayLoad`**: pure functions in
  `lib/features/clock/model/`, unit-tested directly.
- **Rings in use:** derived from `assignRings(...)` in the dial.
- **Week dots:** `EventRepository.watchTonesByDay(DateTime from, DateTime toExclusive)`
  returns `Stream<Map<DateTime, Set<Tone>>>`. Backed by a new `EventDao` query that
  selects distinct `(date, toneIndex)` for the range. Added to `EventRepository`,
  `DriftEventRepository`, and `test/support/fake_event_repository.dart`.
  `weekTonesProvider(weekStart)` is a family keyed by a week's Monday; each page of
  the strip watches its own week, so neighbouring pages have their dots ready
  while swiping.
- **Settings:** a new `SettingsDao` over the existing `AppSettings` table, a
  `SettingsRepository` (`getBool`, `setBool`), and `onboardingDoneProvider`.
  Generated Drift code is regenerated with `build_runner` and committed, like the
  existing `.g.dart` files.
- **`appDatabaseProvider` moves** from `lib/features/clock/providers.dart` to a new
  `lib/data/providers.dart`, together with `settingsRepositoryProvider`. Onboarding
  and the later steps need the database, and the boundary rule forbids features
  importing each other.

No new tables, no schema change, no migration.

---

## 12. Accessibility

- **VoiceOver, dial:** the dial is a labelled group ("24-hour day dial"). Each
  event arc is one node placed over the arc's bounds, in chronological order,
  reading "Deep work, Focus, 09:00 to 11:00, 2 hours". The default action opens
  details. On editable days, custom actions **Edit** and **Delete** are added, so
  nobody has to drag. The **+** button remains the no-drag way to add an event.
- **VoiceOver, other:** the Now card reads as one item ("Now: Deep work, Focus, 42
  minutes left"). Week pills read "Tuesday 6 October, Focus and Life planned",
  plus selected and today. The day-load bar reads "Planned load: Focus 4 hours,
  Life 2 hours, Inbox 1 hour". Tab bar items report selected state and position.
- **Reading order:** header, week strip, dial events (chronological), Now card,
  day-load bar, tab bar.
- **Large text:** all text scales except text drawn on the dial (clamped at 1.2).
  Sheets and onboarding scroll. The Clock page follows §8.7.
- **Reduce Motion:** §4.3 and §7.3.
- **Colour is never the only signal:** the tone name is always present as text
  (Now card, detail sheet, semantics, arc labels). This matters because green and
  orange are hard to tell apart for some people.
- **Contrast:** §4.1, enforced by tests.

---

## 13. Error handling and edge cases

| Case | Handling |
|---|---|
| Font asset fails to load | Falls back to the system font; no crash |
| Week-dots stream errors | Dots are hidden; the strip still works |
| Onboarding flag unreadable | Onboarding is skipped |
| Sample day would need a fourth ring | Those events are skipped; the rest are created |
| Sample day write fails otherwise | A snack bar with a new `Strings.sampleDayFailed`; the user lands on the Clock tab |
| Several active events | The latest-started is shown with "+N overlapping" |
| Event ends exactly at the current minute | Not active (end is exclusive) |
| Midnight passes while the app is open | `clockProvider` ticks; the Today button and Now card recompute; the selected day does not change on its own (existing behaviour) |
| DST change day | Minute-of-day logic is unchanged |
| Window resized or device rotated mid-drag | Drag state is held in minutes, not pixels, so the drag continues against the recomputed geometry; the selected day and open sheets are preserved because state lives in providers |
| Text size changes | Layout rules in §8.7 |
| Selected day far in the past or future | The week strip pages without bounds |
| Day with more than three overlaps (legacy data) | Unchanged: events beyond three rings are not drawn |

---

## 14. Testing and verification

**Impact on existing tests.** These are updated or replaced:

- `test/app/tab_scaffold_test.dart`: asserts on `NavigationBar`; rewritten for `AppTabBar`.
- `test/features/clock/day_header_test.dart`: replaced by header and week-strip tests.
- `test/features/clock/clock_screen_test.dart`: updated for the Now card and the moved empty-state copy.
- `test/core/geometry/dial_geometry_test.dart`: extended for `ringCount`.
- `test/app/tone_colors_test.dart`: updated for the palette.
- `test/support/fake_event_repository.dart`: gains `watchTonesByDay`.
- Dial goldens: regenerated (below).

Tests that need only a mechanical update because a constructor or widget changed
(expected: `dial_painter_test.dart`, `dial_view_test.dart`, `dial_golden_test.dart`,
`event_sheet_test.dart`, `event_detail_sheet_test.dart`) keep every behavioural
assertion. All other existing tests pass unchanged.

**Unit tests (pure logic).**

- `DialGeometry.fitted` for ring counts 1–3: the three-ring case equals today's
  values; fewer rings give a larger face; `orbitOuterRadius == R`; `lerp`.
- Ring-count derivation from `assignRings`.
- `computeNowStatus`: every state; boundaries at the start and end minutes;
  overlaps; past, today and future days.
- `computeDayLoad`: sums per tone; overlap counts twice.
- Week-dot grouping and the week-start (Monday) calculation.
- `windowClassFor` at 599 / 600 / 899 / 900.
- **Contrast:** for every token pair in §4.1 in both modes, text pairs are at
  least 4.5:1 and arc-against-face pairs at least 3:1.
- A test that scans `lib/features/` and fails if it finds a hard-coded colour
  (`\bColor\(0x` or `\bColors\.`, with word boundaries so identifiers such as
  `toneColors.` do not match). Today's feature code passes it.

**DAO test.** The new range query and `SettingsDao`, primed the way the existing
DAO tests prime a fresh Drift database.

**Widget tests.** `AppTabBar` (selection, state kept across tabs, semantics);
`WeekStrip` (select; swipe moves the selected day by seven days; Today button; dots; semantics); `NowCard` states;
`DayLoadBar` proportions and hiding; `TodaysPlanList`; onboarding (pages, Skip,
sample day, "seen" persisted, skipped when unreadable); both sheets; the dial's
semantics nodes and custom actions; the Reduce Motion path.

**Layout matrix.** The Clock screen is pumped at 8 window sizes: iPhone SE
(375 × 667), iPhone 17 Pro (402 × 874), iPad mini portrait (744 × 1133), iPad 11"
portrait (834 × 1194), iPad 11" landscape (1194 × 834), iPad 13" portrait
(1032 × 1376), iPad 13" landscape (1376 × 1032), and a narrow Split View
(320 × 1000), each at text scale 1.0, 1.3 and 2.0 (1.3 is the largest size that
still shows the full Now card). Each case asserts no overflow errors, that the
dial is at least 240 pt, and that the expected layout class is used.

**Goldens.** A shared test helper loads Nunito with `FontLoader`, so goldens show
real text. The old note in `dial_golden_test.dart` about black text boxes is
removed. Goldens: dial (light and dark; 1, 2 and 3 rings; empty) with a fixed
clock; Clock screen in narrow, medium and wide light, and narrow dark; Now card
states. Goldens are generated and verified on the development machine.

**Manual verification, with screenshots reviewed with the user:** iPhone 17 Pro, a
small iPhone (iPhone SE-size simulator, created if missing), iPad Pro 13" in all
four orientations and in Split View at 1/3 and 1/2, in light and dark, at the
largest text size, with Reduce Motion on, plus a VoiceOver spot check with the
Accessibility Inspector.

**Acceptance criteria.**

1. Everything in §§4–10 is implemented as described.
2. `flutter analyze` is clean and the full test suite passes.
3. The contrast tests, the no-hard-coded-colour test, and the layout matrix pass.
4. The user approves the phone and iPad screenshots.
5. The iPad orientation settings match Apple's rule. The real upload validation
   needs the user's signing and is part of Step 6.
6. No new runtime packages.

---

## 15. Build order, risks, scope, dependencies

### Build order

Each stage leaves the app runnable with its tests green.

1. **Foundation:** tokens, fonts, `ToneColors` refactor, adaptive helpers,
   components, `AppTabBar`, `TabScaffold`, move `appDatabaseProvider`.
2. **Dial v2:** geometry, painter, semantics, animations, regenerated goldens.
3. **Clock screen (narrow and medium):** `clockProvider`, `ClockHeader` and
   `WeekStrip` (with the repository query), `NowCard`, `DayLoadBar`, empty hint.
4. **Sheets:** restyled New, Edit and Detail sheets and adaptive dialogs.
5. **iPad:** wide two-pane layout, `TodaysPlanList`, Info.plist orientations, layout matrix.
6. **Brand and onboarding:** icon and launch assets, `SettingsRepository`,
   onboarding flow, sample day.
7. **Final checks:** full test and analyze run, manual matrix, README and
   `pubspec.yaml`, cross-check against this spec, screenshot review.

**Cut line,** if the step must shrink, in this order: the Today's plan list, the
night tint, the week-strip dots, the pulsing empty-day hint.

The plan may be split into two documents after stage 4 if it grows past about 35
tasks. Each document must leave the app runnable.

### Risks

| Risk | Mitigation |
|---|---|
| Face resizing feels jumpy | Geometry changes only after a save; 350 ms ease; Reduce Motion disables it |
| Nunito digits are not even-width | Fixed-width boxes for the time text (open item 1) |
| Night tint looks busy | Behind `showNightTint`; in the cut line |
| iPad adds a large test matrix | The layout matrix test; all later screens reuse the same three window classes |
| Goldens with real fonts differ across machines | Generated and verified on the development machine; the helper pins the font |
| Step 1 is large | Seven runnable stages and an explicit cut line |

### Out of scope

- The Start button, session timer, and notifications (Step 2).
- Content for Calendar, Stats and Profile (Steps 3–5); they stay placeholders.
- Privacy policy page, support link, and privacy manifest (Steps 5–6).
- A "mood screen" tinting the whole top of the Clock screen.
- iPad keyboard shortcuts and pointer hover effects.
- Widgets, Live Activities, and localisation.

### Dependencies

No new runtime packages. New assets: Nunito (four static TTFs plus its
`OFL.txt` licence) under `assets/fonts/`, declared in `pubspec.yaml`, and the
licence registered with `LicenseRegistry`. Nunito is published only as a variable
font, so the four static weights are cut from `Nunito[wght].ttf` with `fontTools`
(already installed on the development machine); the licence file is checked for a
Reserved Font Name first. **Downloading the font files needs the user's approval
at implementation time.** `cupertino_icons` is already a dependency.

### Open items to settle in the plan

1. Whether Nunito supports tabular figures (`tnum`). The styles request them; the
   final manual check watches the centre time for jitter and, if it jitters, the
   time text gets a fixed width.
2. Exact pixel sizes for the header, week strip, Now card, and day-load bar,
   tuned against the layout matrix. (The plan fixes them at 48, 60, 96 and 68;
   the Now card's budget grows with text size, see §8.7.)
3. The 1024 px icon has no alpha channel after `sips` resizing. (Settled: the
   master is flattened through JPEG first, and a test reads the PNG headers.)
4. Which `CupertinoIcons` glyphs match the tabs. (Settled: `calendar`;
   `chart_bar_alt_fill` selected and `chart_bar` unselected; `person_fill` selected
   and `person` unselected. The Clock tab uses the three-arc ring.)
