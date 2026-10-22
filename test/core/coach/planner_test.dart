// test/core/coach/planner_test.dart
import 'package:altidial/core/coach/planner.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/core/event_status.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(int id, Tone tone, int start, int end, {bool flight = false}) =>
    CalendarEvent(
      id: id, seriesId: null, date: startOfDay(DateTime(2026, 10, 12)),
      title: 'E$id', tone: tone, range: MinuteRange(start, end),
      status: EventStatus.planned, isFlight: flight,
    );

void main() {
  test('empty day yields no suggestions', () {
    expect(suggestSwaps(today: [], peakHours: [9, 10], focusTargetMinutes: 180), isEmpty);
  });

  test('focus outside peak moves into peak', () {
    final today = [event(1, Tone.focus, 840, 960)]; // 14:00-16:00
    final swaps = suggestSwaps(today: today, peakHours: [9, 10], focusTargetMinutes: 180);
    expect(swaps.length, 1);
    expect(swaps.single.eventId, 1);
    expect(swaps.single.toStartMinute, 540); // 09:00
    expect(swaps.single.reason, SwapReason.peak);
  });

  test('flights are never moved', () {
    final today = [event(1, Tone.inbox, 840, 960, flight: true)];
    expect(
      suggestSwaps(today: today, peakHours: [14, 15], focusTargetMinutes: 180),
      isEmpty,
    );
  });

  test('card state mornings without intent', () {
    expect(
      coachCardKind(hasIntent: false, hasSuggestions: false, hasReview: false, hasNewInsights: false, hour: 8),
      CoachCardKind.setIntent,
    );
  });

  test('4th-ring refusal: no suggestion when peak is full', () {
    final today = [
      event(1, Tone.focus, 540, 900),
      event(2, Tone.focus, 540, 900),
      event(3, Tone.focus, 540, 900),
      event(4, Tone.focus, 840, 960),
    ];
    final swaps = suggestSwaps(
      today: today,
      peakHours: [9, 10],
      focusTargetMinutes: 180,
    );
    expect(swaps.where((s) => s.eventId == 4), isEmpty);
  });

  test('midnight clamp: inbox move that would cross midnight is omitted', () {
    // 500-minute inbox inside peak would end at 24:20 from 16:00.
    final today = [event(1, Tone.inbox, 540, 1040)];
    final swaps = suggestSwaps(
      today: today,
      peakHours: [9, 10],
      focusTargetMinutes: 180,
    );
    expect(swaps, isEmpty);
  });

  test('inbox inside peak moves out to 16:00', () {
    final today = [event(1, Tone.inbox, 540, 600)];
    final swaps = suggestSwaps(
      today: today,
      peakHours: [9, 10],
      focusTargetMinutes: 180,
    );
    expect(swaps, hasLength(1));
    expect(swaps.single.eventId, 1);
    expect(swaps.single.toStartMinute, 960);
    expect(swaps.single.reason, SwapReason.lateAvoid);
  });

  test('lateAvoid no-op at 16:00', () {
    final today = [event(1, Tone.inbox, 960, 1020)];
    final swaps = suggestSwaps(
      today: today,
      peakHours: [16, 17],
      focusTargetMinutes: 180,
    );
    expect(swaps, isEmpty);
  });

  group('balance path', () {
    test('moves earliest Life in peak to 12:00 when focus is short', () {
      final today = [
        event(1, Tone.focus, 540, 600),
        event(2, Tone.life, 600, 660),
      ];
      final swaps = suggestSwaps(
        today: today,
        peakHours: [9, 10],
        focusTargetMinutes: 180,
      );
      final balance = swaps.where((s) => s.reason == SwapReason.balance);
      expect(balance, hasLength(1));
      expect(balance.single.eventId, 2);
      expect(balance.single.toStartMinute, 720);
      expect(balance.single.evidence, 'Frees your peak for focus');
    });

    test('omitted when focus already meets target', () {
      final today = [
        event(1, Tone.focus, 540, 660),
        event(2, Tone.life, 600, 660),
      ];
      final swaps = suggestSwaps(
        today: today,
        peakHours: [9, 10],
        focusTargetMinutes: 60,
      );
      expect(swaps.where((s) => s.reason == SwapReason.balance), isEmpty);
    });

    test('omitted when no Life sits in peak', () {
      final today = [event(1, Tone.focus, 840, 900)];
      final swaps = suggestSwaps(
        today: today,
        peakHours: [9, 10],
        focusTargetMinutes: 180,
      );
      expect(swaps.where((s) => s.reason == SwapReason.balance), isEmpty);
    });
  });
}
