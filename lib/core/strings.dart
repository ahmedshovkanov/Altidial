/// All user-facing copy. English-only by design; centralised so that
/// localisation stays possible later without hunting through widgets.
abstract final class Strings {
  static const String appTitle = 'Altidial';

  static const String tabClock = 'Clock';
  static const String tabCalendar = 'Calendar';
  static const String tabStats = 'Stats';
  static const String tabProfile = 'Profile';

  static String comingSoon(String feature) => '$feature is coming soon';

  static const String today = 'Today';
  static const String addEvent = 'Add event';
  static const String previousDay = 'Previous day';
  static const String nextDay = 'Next day';
  static const String emptyDayTitle = 'Nothing planned yet';
  static const String emptyDayHint =
      'Drag around the ring to block out your first event.';
  static const String pastDayNotice = 'Past days are read-only';
  static const String loadFailed = "Couldn't load this day.";

  static const String newEvent = 'New event';
  static const String editEvent = 'Edit event';
  static const String titleLabel = 'Title';
  static const String titleHint = 'Deep work';
  static const String titleRequired = 'Enter a title';
  static const String toneLabel = 'Tone';
  static const String startLabel = 'Start';
  static const String endLabel = 'End';
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String ringOverflow = 'Up to three overlapping events.';
  static String stepperDecrease(String label) => '$label minus';
  static String stepperIncrease(String label) => '$label plus';

  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String deleteConfirmTitle = 'Delete this event?';
  static const String deleteConfirmBody = "This can't be undone.";

  // Tab bar and header.
  static String tabSemantics(String label, int position, int count) =>
      '$label, tab $position of $count';
  static const String readOnlyChip = 'Read-only';

  // Now card.
  static const String nowNextUp = 'Next up';
  static const String nowDoneTitle = 'All done for today';
  static const String pastNothingPlanned = 'Nothing was planned';
  static String nowTimeLeft(String duration) => '$duration left';
  static String nowUntil(String end) => 'until $end';
  static String nowStartsAt(String start, String inDuration) =>
      'Starts at $start · in $inDuration';
  static String nowOverlapping(int count) => '+$count overlapping';
  static String eventCount(int count) =>
      count == 1 ? '1 event' : '$count events';
  static String plannedSummary(int count, String duration) =>
      '${eventCount(count)} · $duration planned';
  static String plannedDuration(String duration) => '$duration planned';
  static String pastSummary(int count, String duration) =>
      '${eventCount(count)} · $duration';
  static String dayCountTitle(String weekday, int count) =>
      '$weekday · ${eventCount(count)}';
  static String nowSemantics(String title, String tone, String timeLeft) =>
      'Now: $title, $tone, $timeLeft left';
  static String nextSemantics(String title, String tone, String startsIn) =>
      'Next up: $title, $tone, starts in $startsIn';

  // Day-load bar.
  static String dayLoadSemantics(String parts) => 'Planned load: $parts';

  // Week strip.
  static String weekDaySemantics(
    String date, {
    required String tones,
    required bool isToday,
  }) {
    final planned = tones.isEmpty ? '' : ', $tones planned';
    final today = isToday ? ', today' : '';
    return '$date$planned$today';
  }

  // Dial.
  static const String dialSemanticsLabel = '24-hour day dial';
  static String eventSemantics(
    String title,
    String tone,
    String start,
    String end,
    String duration,
  ) => '$title, $tone, $start to $end, $duration';

  // Today's plan list (wide windows).
  static const String planTitleToday = "Today's plan";
  static String planTitleFor(String weekday) => "$weekday's plan";

  /// "Focus", "Focus and Life", "Focus, Life and Inbox".
  static String joinWords(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    final head = items.sublist(0, items.length - 1).join(', ');
    return '$head and ${items.last}';
  }

  // Onboarding.
  static const String onboardingSkip = 'Skip';
  static const String onboardingNext = 'Next';
  static const String onboardingTitle1 =
      'Plan your day by energy, not just time';
  static const String onboardingBody1 =
      'Altidial puts your day on a 24-hour dial, so you can see how heavy '
      'the day is before you start it.';
  static const String onboardingTitle2 = 'Three tones for every event';
  static const String toneExampleFocus =
      'Deep, demanding work: writing, design, thinking';
  static const String toneExampleLife = 'Body and rest: sport, a walk, lunch';
  static const String toneExampleInbox =
      'Routine and reactive: email, calls, admin';
  static const String onboardingTitle3 = 'Drag the ring to plan';
  static const String onboardingBody3 =
      'Press and drag on the ring around the clock to block out time. Tap an '
      'event to see details, or drag it to move or resize it.';
  static const String onboardingSampleDay = 'Start with a sample day';
  static const String onboardingStartEmpty = 'Start empty';
  static String onboardingPage(int page, int count) => 'Page $page of $count';

  // The sample day.
  static const String sampleDeepWork = 'Deep work';
  static const String sampleEmailCalls = 'Email and calls';
  static const String sampleLunchWalk = 'Lunch walk';
  static const String sampleWriting = 'Writing';
  static const String sampleDayFailed = "Couldn't add the sample day.";

  // Starting a session.
  static const String sessionStart = 'Start session';
  static const String sessionStartShort = 'Start';
  static const String sessionDone = 'Done';
  static const String nowCompletedSuffix = ', completed';
  static const String eventCompleted = 'Completed';
  static const String sessionAlreadyRunning = 'A session is already running.';
  static const String sessionStartFailed = "Couldn't start the session.";

  // The session screen.
  static const String sessionPause = 'Pause';
  static const String sessionResume = 'Resume';
  static const String sessionAdd5 = '+5m';
  static const String sessionAdd15 = '+15m';
  static const String sessionAdd5Semantics = 'Add 5 minutes';
  static const String sessionAdd15Semantics = 'Add 15 minutes';
  static const String sessionFinishEarly = 'Finish early';
  static const String sessionFinish = 'Finish';
  static const String sessionAbandon = 'Abandon';
  static const String sessionAbandonTitle = 'Abandon this session?';
  static const String sessionAbandonBody =
      "It will be recorded as abandoned and won't count as completed.";
  static const String sessionKeepGoing = 'Keep going';
  static const String sessionRemaining = 'remaining';
  static const String sessionPaused = 'Paused';
  static const String sessionOvertime = 'Overtime';
  static String sessionPlanned(String duration) => 'Planned $duration';
  static String sessionEndsAt(String time) => 'ends $time';
  static String sessionWasDueAt(String time) => 'was due $time';
  static String sessionLogged(String title, String duration) =>
      'Logged $duration on $title.';
  static const String sessionAbandoned = 'Session abandoned.';
  static String sessionRingSemantics(
    String title,
    String tone,
    String time,
    String state,
  ) => '$title, $tone, $time$state';
  static const String sessionStatePaused = ', paused';
  static const String sessionStateOvertime = ', overtime';

  // Session alerts.
  static const String sessionEndedTitle = "Time's up";
  static String sessionEndedBody(String title) =>
      '$title is done. Open Altidial to finish, or keep going.';
  static const String alertsOffTitle = 'Alerts are off';
  static const String alertsOffBody =
      "You won't get an alert when time is up while the app is closed. The "
      'timer still works.';
  static const String openSettings = 'Open Settings';
  static const String dismiss = 'Dismiss';

  // Notifications (spec §10).
  static String eventReminderBody(String tone) =>
      'Starts in 10 minutes · $tone';
  static const String morningReminderTitle = 'Plan your day';
  static const String morningReminderBody =
      'Today is wide open — put something on the dial.';
  static const String roundupReadyTitle = 'Your Weekly Roundup is ready';
  static String roundupReadyBody(int week) =>
      'Week $week in review: scores, streaks and badges.';
  // Project deadline reminder. Reuses the 'event starting soon' toggle and
  // channel (no new permission or setting), so the copy stays generic.
  static const String projectDeadlineReminderTitle = 'Project due tomorrow';
  static const String projectDeadlineReminderBody =
      'A project you are working on is due tomorrow.';

  // Notification settings (spec §10).
  static const String settingsNotifications = 'Notifications';
  static const String notifySessionEndLabel = 'Session end';
  static const String notifyEventSoonLabel = 'Event starting soon';
  static const String notifyRoundupLabel = 'Weekly roundup';
  static const String notifyMorningLabel = 'Morning reminder';
  static const String morningTimeLabel = 'Reminder time';
  static const String notificationsDenied =
      'Notifications are off. Turn them on to use alerts.';
  static const String notificationsOpenSettings = 'Open Settings';
  static const String notificationsOffTitle = 'Notifications are off';
  static const String notificationsOffBody =
      'The app cannot send alerts until they are allowed in Settings.';

  // Finding a session after the app was closed.
  static const String recoveryTitle = 'A session was still running';
  static String recoveryBody(String title, String elapsed) =>
      '$title has been going for $elapsed. Pick it up where you left off, or '
      'close it out.';
  static const String recoveryCloseOutHint =
      'Closing out records at most the planned time.';
  static const String recoveryUnderAMinute = 'under a minute';
  static const String recoveryResume = 'Resume';
  static const String recoveryCloseOut = 'Close out';

  // Days of the week, Monday first.
  static const List<String> weekdayShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> weekdayLong = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> weekdayInitials = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  /// The short weekday names reordered so they start on [firstWeekday]
  /// (`DateTime.monday` … `DateTime.sunday`).
  static List<String> weekdayShortStarting(int firstWeekday) => [
    for (var i = 0; i < 7; i++)
      weekdayShort[(firstWeekday - DateTime.monday + i) % 7],
  ];

  // Statistics.
  static const String statsLoadError = 'Could not load these statistics.';
  static const String statsCardHint = 'Tone balance, planned vs actual, focus depth.';
  static const String statsPeriodWeek = 'Week';
  static const String statsPeriodMonth = 'Month';
  static const String statsPreviousWeek = 'Previous week';
  static const String statsNextWeek = 'Next week';
  static const String statsPreviousMonth = 'Previous month';
  static const String statsNextMonth = 'Next month';
  static const String statsThisWeek = 'This week';
  static const String statsThisMonth = 'This month';
  static const String statsToneBalance = 'Tone balance';
  static const String statsPlannedActual = 'Planned vs actual';
  static const String statsFocusDepth = 'Focus depth';
  static const String statsHeatmap = 'Where focus happens';
  static const String statsEmptyToneBalance =
      'Run your first session to see where your focus goes.';
  static const String statsEmptyPlanned =
      'Plan a day and come back to see how it went.';
  static const String statsEmptyFocus =
      'Your longest session will show up here.';
  static const String statsEmptyHeatmap =
      'A week of focus sessions reveals your peak hours.';
  static String statsAdherence(int percent) => '$percent% adherence';
  static const String statsTotalFocus = 'Total focus';
  static const String statsLongestSession = 'Longest session';
  static const String statsAverageSession = 'Average session';
  static const String statsAbandoned = 'Abandoned';
  static String statsAbandonedLabel(int percent) => 'Abandoned · $percent%';
  static String statsAbandonedCount(int abandoned, int ended) =>
      '$abandoned of $ended';
  static String statsPlannedDone(String planned, String done) =>
      '$planned planned · $done done';
  static String statsToneShare(String tone, String duration) =>
      '$tone $duration';
  static String statsToneLegend(String tone, String duration, int percent) =>
      '$tone $duration · $percent%';
  static String statsFocusSummary(
    String total,
    String longest,
    String average,
    String abandoned,
  ) =>
      'Total focus $total, longest session $longest, '
      'average session $average, abandoned $abandoned';
  static String statsHeatmapBusiest(
    String weekday,
    String hour,
    String duration,
  ) => 'Busiest: $weekday $hour ($duration)';

  // Badges (spec §9.4).
  static const String badgeFirstSessionTitle = 'First session';
  static const String badgeFirstSessionDescription = 'Finish any session.';
  static const String badgeSessions10Title = '10 sessions';
  static const String badgeSessions10Description = 'End 10 sessions.';
  static const String badgeSessions50Title = '50 sessions';
  static const String badgeSessions50Description = 'End 50 sessions.';
  static const String badgeSessions100Title = '100 sessions';
  static const String badgeSessions100Description = 'End 100 sessions.';
  static const String badgeFocusDayTitle = 'Four-hour focus day';
  static const String badgeFocusDayDescription =
      'Focus for four hours in a single day.';
  static const String badgeWeekTonesTitle = 'Full spectrum';
  static const String badgeWeekTonesDescription =
      'Use all three tones in one week.';
  static const String badgeStreak7Title = 'Seven-day streak';
  static const String badgeStreak7Description =
      'Keep a streak going for seven days.';
  static const String badgeStreak30Title = 'Thirty-day streak';
  static const String badgeStreak30Description =
      'Keep a streak going for thirty days.';
  static const String badgeCleanWeekTitle = 'Clean week';
  static const String badgeCleanWeekDescription =
      'A week with sessions and nothing abandoned.';
  static const String badgeEarlyBirdTitle = 'Early bird';
  static const String badgeEarlyBirdDescription =
      'Start a focus session before 08:00.';

  // Profile.
  static const String profileLoadError = 'Could not load your progress.';
  static String profileLevel(int level) => 'Level $level';
  static String profileXp(int current, int next) => '$current / $next XP';
  static String profileStreak(int days) =>
      days == 1 ? '1-day streak' : '$days-day streak';
  static String profileBestStreak(int days) => 'Best $days days';
  static const String profileEmptyHeader =
      'Finish a session to start your streak.';
  static const String profileScoreTitle = 'Energy score';
  static const String profileScoreEmpty =
      'Today has no score yet. Finish a session to start one.';
  static String profilePoints(int earned, int total) => '$earned / $total';
  static const String profileScoreAdherence = 'Adherence';
  static const String profileScoreFocus = 'Focus';
  static const String profileScoreBalance = 'Balance';
  static const String profileScoreCaption =
      'How today adds up: up to 50 for planned time kept, 30 for focus '
      'against your target, 20 for a balanced mix.';
  static const String profileBadgesTitle = 'Badges';
  static const String profileBadgeLocked = 'Locked';
  static const String profileStreakLabel = 'Streak';
  static const String profileXpLabel = 'XP';
  static const String profileArchiveTitle = 'Weekly roundups';
  static const String profileEmptyArchive =
      'Your first roundup appears on Monday.';
  static String roundupWeek(int week) => 'Week $week';
  static String roundupXp(int xp) => '$xp XP';
  static String roundupBestFocusDay(String day, String duration) =>
      '$day · $duration';
  static String roundupPreviousAdherence(int percent) =>
      'Previous week: ${statsAdherence(percent)}';
  static const String roundupNothingPlanned = 'Nothing planned';
  static const String roundupUnavailable = 'This roundup is unavailable.';

  // Settings.
  static const String settingsTitle = 'Settings';
  static const String settingsTheme = 'Theme';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String settingsFocusTarget = 'Daily focus target';
  static const String settingsFirstDay = 'First day of week';
  static const String settingsRecalculate = 'Recalculate all scores';
  static const String settingsRecalculateTitle = 'Rebuild every score?';
  static const String settingsRecalculateBody =
      'Scores, streaks and badges are recomputed from your events and '
      'sessions. This takes a moment.';
  static const String settingsRecalculateConfirm = 'Rebuild';
  static const String settingsRecalculated = 'Scores rebuilt.';
  static const String settingsExport = 'Export data';
  static const String settingsExportSubject = 'Altidial export';
  static const String settingsExportFailed = 'Export failed. Try again.';
  static const String settingsErase = 'Erase everything';
  static const String settingsEraseTitle = 'Erase everything?';
  static const String settingsEraseBody =
      'All events, sessions, scores and settings are deleted. '
      'This cannot be undone.';
  static const String settingsEraseConfirm = 'Erase';
  static const String settingsErased = 'Everything erased.';

  // Repeating events.
  static const String repeatLabel = 'Repeat';
  static const String repeatNone = 'Does not repeat';
  static const String repeatNever = 'Never';
  static const String repeatDaily = 'Every day';
  static const String repeatWeekdays = 'Weekdays';
  static const String repeatCustom = 'Custom';
  static String repeatEvery(String days) => 'Every $days';
  static String repeatUntil(String date) => 'until $date';
  static const String repeatEndsLabel = 'Ends';
  static const String repeatNoEnd = 'No end';
  static const String repeatEndsOnDate = 'On a date';
  static String repeatEndsOn(String date) => 'On $date';
  static const String repeatEndHelp = 'Last day it repeats';

  // Choosing how far a change to a repeating event reaches.
  static const String editScopeTitle = 'Edit repeating event';
  static const String deleteScopeTitle = 'Delete repeating event';
  static const String scopeThisEvent = 'This event';
  static const String scopeThisAndFuture = 'This and all future events';
  static const String repeatChangeTitle = 'Change how it repeats?';
  static const String repeatChangeBody =
      'This applies to this event and all future ones.';

  // Reusing a day: templates and copy-yesterday.
  static const String moreActions = 'More';
  static const String saveAsTemplate = 'Save as template';
  static const String copyYesterday = 'Copy yesterday';
  static const String applyTemplate = 'Apply template';
  static const String templateNameTitle = 'Save as template';
  static const String templateNameLabel = 'Template name';
  static const String templateNameHint = 'Workday';
  static const String templateNameRequired = 'Enter a name';
  static String templateSaved(String name) => 'Saved "$name" as a template.';
  static const String templateSaveFailed = "Couldn't save the template.";
  static const String copyFailed = "Couldn't copy that day.";
  static const String dayNotEmpty = 'That day already has events.';

  // The template picker.
  static const String templatesEmptyTitle = 'No templates yet';
  static const String templatesEmptyBody =
      'Open the ⋯ menu on a day you like and choose Save as template.';
  static const String templatesLoadFailed = "Couldn't load your templates.";
  static String templateSummary(int count, String duration) =>
      '${eventCount(count)} · $duration';
  static String templateSemantics(
    String name,
    String events,
    String duration,
  ) => '$name, $events, $duration';
  static const String deleteTemplate = 'Delete template';
  static const String deleteTemplateTitle = 'Delete this template?';
  static const String deleteTemplateBody =
      'Days you already made from it are not changed.';
  static const String applyFailed = "Couldn't apply the template.";

  // The Calendar.
  static const String previousMonth = 'Previous month';
  static const String nextMonth = 'Next month';
  static const String calendarEmptyMonth =
      'Nothing planned this month yet. Tap a day to plan it.';

  // Flights (travel day mode v1).
  static const String flightToggle = 'This is a flight';
  static const String flightNumberLabel = 'Flight no. (optional)';
  static const String flightNumberHint = 'LH715';
  static const String flightFromLabel = 'From';
  static const String flightToLabel = 'To';
  static const String flightAirportHint = 'SOF';
  static const String flightAirportError = 'Use 3 letters, e.g. SOF';
  static const String flightNumberError = 'Use 2–8 letters/digits, e.g. LH715';
  static const String flightOvernightError =
      'Same-day flights only in v1 — split overnight flights into two blocks for now';
  static String flightRoute(String from, String to) => '$from→$to';
  static String flightSemantics(
    String title,
    String route,
    String start,
    String end,
  ) => 'Flight $title, $route, $start to $end';

  // Flight Deck.
  static const String tabDeck = 'Deck';
  static const String flightDeckTitle = 'Flight Deck';
  static const String deckFlightsLoadError = "Couldn't load flights.";
  static const String deckRetry = 'Try again';
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
  static const String deckGroundingTitle = 'Name what is here';
  static const String deckGroundingHint = '5 see · 4 feel · 3 hear · 2 smell · 1 taste';
  static const String deckGroundingNext = 'Notice one';
  static const String deckGroundingDone = 'Well done — you are here.';
  static const String deckGroundingRestart = 'Start over';
  static const String deckStarAdd = 'Save';
  static const String deckStarRemove = 'Saved';
  static const String deckSavedEmptyTitle = 'Nothing saved yet';
  static const String deckSavedEmptyHint = 'Star a card to keep it here.';
  static const String deckBreatheTitle = 'Take a breath';
  static const String deckBreatheHint = '4 in · 6 out · guided';
  static const String breatheScreenTitle = 'Slow breathing';
  static const String breatheInhale = 'Breathe in';
  static const String breatheExhale = 'Breathe out';
  static const String breathePress = 'Press and hold';
  static const String breatheRelease = 'Let go';
  static const String breatheClose = 'Close';
  static const String breatheDoneTitle = "You're here";
  static const String breatheAgain = 'Again';
  static const String breatheFinish = 'Done';
  static String breatheCount(int current, int total) =>
      'Breath $current of $total';
  static String breathePhaseSemantics(String phaseLabel, int secondsLeft) {
    final unit = secondsLeft == 1 ? 'second' : 'seconds';
    return '$phaseLabel, $secondsLeft $unit';
  }
  static String breatheDoneBody(int breaths) =>
      breaths == 1 ? '1 calm breath.' : '$breaths calm breaths.';
  static String deckCountdownToday(String time) => 'Today · $time';
  static String deckCountdownTomorrow(String time) => 'Tomorrow · $time';
  static String deckCountdownDays(int days) =>
      days == 1 ? 'In 1 day' : 'In $days days';

  // Projects.
  static const String projectPickerTitle = 'Project';
  static const String projectNone = 'No project';
  static const String projectNew = '+ New project';
  static const String projectNameHint = 'e.g. Launch portfolio';
  static const String projectsTitle = 'Projects';
  static const String projectsEmptyTitle = 'Name your first outcome';
  static const String projectsEmptyHint =
      'e.g. Launch portfolio, Run 10k — then link events to it.';
  static const String projectsLoadError = "Couldn't load projects.";
  static const String projectsActive = 'Active';
  static const String projectsReady = 'Ready to complete';
  static const String projectsMarkComplete = 'Mark complete';
  static const String projectsReopen = 'Reopen';
  static const String projectsArchive = 'Archive';
  static const String projectsDelete = 'Delete';
  static const String projectsDeleteTitle = 'Delete this project?';
  static const String projectsDeleteBody =
      'Linked events stay on your days, unlinked.';
  static const String projectsDeadline = 'Deadline';
  static const String projectsNoDeadline = 'No deadline';
  static const String projectsTarget = 'Target';
  static const String projectsNoTarget = 'No target';
  static const String projectsAffinity = 'Tone';
  static const String projectsNoAffinity = 'No tone';
  static const String projectsLinkedEvents = 'Linked events';
  static const String projectsUpcoming = 'Upcoming';
  static const String projectsPast = 'Past';
  static const String projectsDetailEmpty =
      'Link events to this project from any day.';
  static const String projectRepeatingHint =
      "Projects can't link repeating events yet";
  static const String projectsSaveFailed =
      "Couldn't save the project. Try again.";
  static const String projectCreateTitle = 'New project';
  static const String projectCreateLabel = 'Project name';
  static String projectsProgress(String actual, String planned) =>
      '$actual of $planned';

  // Project validators (single source; model validators reference these).
  static const String projectNameRequired = 'Name your project';
  static const String projectNameTooLong = 'Keep it under 80 characters';
  static const String projectTargetMin = 'Minimum 15 minutes';
  static const String projectTargetMax = 'Maximum 10,000 hours';
  static const String projectNotesTooLong = 'Keep notes under 500 characters';
  static const String projectPriorityRange = 'Pick a priority between 0 and 3';

  // Project deadline chip.
  static const String deadlineToday = 'Due today';
  static String deadlineOverdueDays(int days) => 'Overdue ${days}d';
  static String deadlineInDays(int days) => 'Due in ${days}d';
  static String deadlineWeekday(String weekday) => 'Due $weekday';
  static const List<String> deadlineWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // Projects hub search, sort and filters.
  static const String projectsSearchHint = 'Search projects';
  static const String projectsNoMatch = 'No projects match.';
  static const String projectsSortBy = 'Sort';
  static const String projectsSortDeadline = 'Deadline';
  static const String projectsSortProgress = 'Progress';
  static const String projectsSortRecent = 'Recently worked';
  static const String projectsSortTitle = 'Title';
  static const String projectsFilterAll = 'All';
  static const String projectsFilterFocus = 'Focus';
  static const String projectsFilterLife = 'Life';
  static const String projectsFilterInbox = 'Inbox';
  static const String projectsFilterOverdue = 'Overdue';

  // Projects tab surfaces (Outcomes / Board / Today) and cross-project views.
  static const String projectsSurfaceOutcomes = 'Outcomes';
  static const String projectsSurfaceBoard = 'Board';
  static const String projectsSurfaceToday = 'Today';
  static const String todayEmpty = 'Nothing planned for today.';
  static String projectsTaskProject(String projectName) => 'Project · $projectName';

  // Projects hub rows and sections.
  static const String projectsWorkedToday = 'today';
  static const String projectsWorkedYesterday = 'yesterday';
  static String projectsWorkedDaysAgo(int days) => '${days}d ago';
  static String projectsSessions(int count) =>
      count == 1 ? '1 session' : '$count sessions';
  static String projectsMeta(int sessionsCount, String lastWorkedLabel) =>
      lastWorkedLabel.isEmpty
          ? projectsSessions(sessionsCount)
          : '${projectsSessions(sessionsCount)} · worked $lastWorkedLabel';
  static String projectsTasksLine(int done, int total) => '$done of $total tasks';
  static const String projectsCompleted = 'Completed';
  static const String projectsArchived = 'Archived';
  static String projectsCompletedOn(String date) => 'Completed $date';

  // --- Tasks (schema v12) ---
  static const String tasksTitle = 'Tasks';
  static const String tasksEmpty = 'Break down the work — add the first task.';
  static const String tasksAddHint = 'Add a task';
  static const String tasksAdd = 'Add';
  static const String tasksTitleRequired = 'Name your task';
  static const String tasksTitleTooLong = 'Keep it under 120 characters';
  static const String tasksNotesTooLong = 'Keep notes under 2000 characters';
  static const String tasksEstimateRange = 'Use 15 minutes to 1000 hours';
  static const List<String> tasksStatusLabels = [
    'Backlog',
    'Todo',
    'Doing',
    'Blocked',
    'Done',
  ];
  static const List<String> tasksPriorityLabels = [
    'None',
    'Low',
    'Medium',
    'High',
  ];
  static const String tasksBoardView = 'Board';
  static const String tasksListView = 'List';
  static const String tasksDeleted = 'Task deleted';
  static const String tasksCompleted = 'Task completed';
  static const String tasksDuplicated = 'Task duplicated';
  static const String tasksNoMatch = 'No tasks match.';
  static const String tasksClear = 'Clear';
  static const String tasksMetaNoEstimate = 'No estimate';
  static const String tasksDropHere = 'Drop here';
  static String tasksEstimateVsActual(String estimate, String actual) =>
      '$actual of $estimate';

  // Task toolbar: search, filters, sort, group, show-done.
  static const String tasksSearchHint = 'Search tasks';
  static const String tasksSortBy = 'Sort';
  static const String tasksSortManual = 'Manual';
  static const String tasksSortTitle = 'Title';
  static const String tasksSortDue = 'Due';
  static const String tasksSortPriority = 'Priority';
  static const String tasksSortCreated = 'Created';
  static const String tasksSortEstimate = 'Estimate';
  static const String tasksSortUpdated = 'Last updated';
  static const String tasksGroupBy = 'Group';
  static const String tasksShowDone = 'Show done';
  static const String tasksDueAny = 'Any due';
  static const String tasksDueOverdue = 'Overdue';
  static const String tasksDueToday = 'Today';
  static const String tasksDueThisWeek = 'This week';
  static const String tasksDueNone = 'No due date';

  // Task editor sheet.
  static const String tasksEditTitle = 'Edit task';
  static const String tasksTitleLabel = 'Task name';
  static const String tasksNotesTitle = 'Notes';
  static const String tasksNotesHint = 'Context, links, next steps';
  static const String tasksStatusTitle = 'Status';
  static const String tasksPriorityTitle = 'Priority';
  static const String tasksEstimateTitle = 'Estimate';
  static const String tasksEstimateHint = 'Hours, e.g. 1.5';
  static const String tasksEstimateInvalid = 'Enter hours, e.g. 1.5';
  static const String tasksDueTitle = 'Due';
  static const String tasksPlannedTitle = 'Planned';
  static const String tasksPickDate = 'Pick a date';
  static const String tasksDeleteTitle = 'Delete this task?';
  static const String tasksDeleteBody = 'This cannot be undone.';
  static const String tasksSaveFailed = "Couldn't save the task. Try again.";

  // Friendly dates: 'Fri, Oct 17'. Month names live here — never hardcoded
  // in widgets — alongside the existing weekday names above.
  static const List<String> monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String friendlyDate(DateTime date) =>
      '${weekdayShort[(date.weekday - DateTime.monday) % 7]}, '
      '${monthShort[date.month - 1]} ${date.day}';

  // Project detail: rename, notes, priority, deadline chips, target hours,
  // velocity, per-event actuals, undo.
  static const String projectsRenameTitle = 'Rename project';
  static const String projectsRenameHint = 'Project name';
  static const String projectsNotesTitle = 'Notes';
  static const String projectsNotesHint = 'Context, links, next steps';
  static String projectsNotesCounter(int length, int max) => '$length/$max';
  static const String projectsPriorityTitle = 'Priority';
  static const List<String> projectsPriorityLabels = [
    'None',
    'Low',
    'Medium',
    'High',
  ];
  static const String projectsDeadlineToday = 'Today';
  static const String projectsDeadlineTomorrow = 'Tomorrow';
  static const String projectsDeadlineNextWeek = 'Next week';
  static const String projectsDeadlineClear = 'Clear';
  static const String projectsTargetHoursHint = 'Hours, e.g. 10';
  static const String projectsVelocityTitle = 'Last 7 days';
  static const String projectsVelocityEmpty = 'No sessions in the last 7 days.';
  static String projectsEventActuals(
    String date,
    String range,
    String actual,
    String planned,
  ) => '$date · $range · $actual of $planned';
  static const String projectsCompletedMessage = 'Project completed';
  static const String projectsArchivedMessage = 'Project archived';
  static const String projectsUndo = 'Undo';

  // Energy Coach.
  static const String coachTitle = 'Coach';
  static const String coachLoadError = "Couldn't load coach.";
  static const String coachSetIntent = "Set today's intent";
  static const String coachFocusHint = 'e.g. Finish portfolio draft';
  static const String coachFocusError = 'Enter 1–120 characters';
  static const String coachReviewTitle = 'Review your day';
  static const String coachEnergyError = 'Pick 1–5';
  static const String coachWinHint = 'One win (optional)';
  static const String coachSaveFailed = "Couldn't save. Try again.";
  static const String coachPlanDay = 'Plan My Day';
  static const String coachSuggestionsEmpty =
      'Your day already matches your peaks.';
  static const String coachReasonPeak = 'Your peak';
  static const String coachReasonLate = 'Protect focus';
  static const String coachReasonBalance = 'Avoid late slump';
  static const String coachInsightsEmpty =
      'Run sessions for a week to unlock insights.';
  static const String coachIntentSaved = 'Intent saved.';
  static const String coachReviewSaved = 'Review saved.';
  static const String coachAccept = 'Accept';
  static const String coachViewInsights = 'View insights';
  static const String predictedEnergyLabel = 'Morning energy';
  static const String reflectionsTodayEmpty = 'No reflections yet today.';
  static String reflectionsTodayLine(int count, String energy, String focus, String tags) =>
      '$count sessions · E $energy / F $focus · top: $tags';

  // Reflections (session debriefs).
  static const String debriefTitle = 'How was it?';
  static const String debriefEnergy = 'Energy';
  static const String debriefEnergyLow = 'Drained';
  static const String debriefEnergyHigh = 'Charged';
  static const String debriefFocus = 'Focus';
  static const String debriefFocusLow = 'Scattered';
  static const String debriefFocusHigh = 'In flow';
  static const String debriefTags = 'What shaped it?';
  static const String debriefNoteHint = 'One line (optional)';
  static const String debriefSave = 'Save reflection';
  static const String debriefSkip = 'Skip';
  static const String debriefSaved = 'Reflection saved.';
  static const String debriefTooManyTags = 'Pick up to 4';
  static const String debriefNoteOver = 'Keep notes under 140 characters';
  static const String debriefFailed = "Couldn't save reflection. Try again.";
  static String debriefSessionLine(String title, int minutes) =>
      '$title · ${minutes}m';
  /// [length] characters of [max] written.
  static String debriefNoteCounter(int length, int max) => '$length/$max';

  /// The label for a debrief tag id. An id nobody knows — a corrupt row from
  /// an older build — is shown as itself rather than swallowed.
  static const Map<String, String> tagLabels = {
    'flow': 'Flow',
    'clear-goal': 'Clear goal',
    'interruptions': 'Interruptions',
    'noisy': 'Noisy',
    'tired': 'Tired',
    'time-pressure': 'Time pressure',
    'context-switch': 'Context switch',
    'low-energy': 'Low energy',
  };
  static String tagLabel(String id) => tagLabels[id] ?? id;
  static const String reflectionsEnergyShort = 'E';
  static const String reflectionsFocusShort = 'F';
  static const String reflectionsTitle = 'Journal';
  static String reflectionsCount(int n) => '$n reflected';
  static const String reflectionsEmptyTitle = 'No reflections yet';
  static const String reflectionsEmptyHint = 'Finish a session — your reflection will land here.';
  static const String reflectionsLoadError = "Couldn't load reflections.";
  static const String reflectionsNotReflected = 'Not reflected — tap to add';
  static const String reflectionsToday = 'Today';
  static const String reflectionsWeek = 'This week';
  static const String reflectionsEarlier = 'Earlier';
  static const String patternsTitle = 'Energy patterns';
  static const String patternsEmpty = 'Reflect on 5 sessions to reveal your patterns.';
  static const String patternsRetry = 'Try again';
  static String patternsSampleSize(int n) => 'n=$n';
  static String patternsSemantics(List<String> titles) =>
      '$patternsTitle: ${joinWords(titles)}';

  // Pattern copy. Positive lifts carry a '+', drains carry a U+2212 MINUS SIGN
  // so the two signs match in width, and every arrow is U+2192.
  static String patternsClearGoalTitle(String lift) =>
      'Clear goal → +$lift focus';
  static String patternsClearGoalDetail(
    String withClearGoal,
    String withoutClearGoal,
    int n,
  ) =>
      'Sessions with a clear goal average $withClearGoal vs '
      '$withoutClearGoal without (n=$n)';
  static String patternsLateInboxTitle(String drain) =>
      'Inbox after 21:00 −$drain energy';
  static String patternsLateInboxDetail(
    String lateInbox,
    String rest,
    int n,
  ) =>
      'Late inbox averages $lateInbox vs $rest otherwise (n=$n)';
  static String patternsPostLifeTitle(String lift) => 'Focus after Life +$lift';
  static String patternsPostLifeDetail(String postLife, String otherFocus, int n) =>
      'Focus right after Life averages $postLife vs $otherFocus (n=$n)';

  // Debug / demo mode.
  static const String debugTitle = 'Debug';
  static const String debugStatusActive = 'Demo data is active';
  static const String debugStatusHint =
      'Three months of sample events, sessions and projects are loaded.';
  static const String debugEnableTitle = 'Load demo data?';
  static const String debugEnableBody =
      'All events, sessions, projects, tasks, reflections, templates, badges '
      'and settings will be erased and replaced with three months of demo '
      'data. This cannot be undone.';
  static const String debugEnableConfirm = 'Load demo data';
  static const String debugLoaded = 'Demo data loaded.';
  static const String debugAlreadyOn = 'Demo mode is already on.';
  static const String debugFailed = "Couldn't load demo data.";
  static const String debugRegenerate = 'Regenerate demo data';
  static const String debugRegenerateTitle = 'Regenerate demo data?';
  static const String debugRegenerateBody =
      'Current demo data will be erased and replaced with a fresh three-month '
      'dataset. This cannot be undone.';
  static const String debugRegenerateConfirm = 'Regenerate';
  static const String debugRegenerated = 'Demo data regenerated.';
  static const String debugExit = 'Exit debug mode';
  static const String debugExitTitle = 'Exit debug mode?';
  static const String debugExitBody =
      'All demo data and settings will be erased. The app will return to '
      'onboarding. This cannot be undone.';
  static const String debugExitConfirm = 'Exit and erase';
  static const String debugExited = 'Demo data erased.';
}
