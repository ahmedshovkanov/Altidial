import 'package:altidial/app/navigation/app_tab_bar.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({
  required int selected,
  required ValueChanged<int> onSelected,
  VoidCallback? onProfileHold,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: AppTabBar(
          selectedIndex: selected,
          onSelected: onSelected,
          onProfileHold: onProfileHold,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('only the selected tab shows its label', (tester) async {
    await tester.pumpWidget(host(selected: 1, onSelected: (_) {}));

    expect(find.text(Strings.projectsTitle), findsOneWidget);
    expect(find.text(Strings.tabClock), findsNothing);
    expect(find.text(Strings.tabCalendar), findsNothing);
    expect(find.text(Strings.tabProfile), findsNothing);
    expect(find.text(Strings.tabDeck), findsNothing);
  });

  testWidgets('tapping an item reports its index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(host(selected: 0, onSelected: taps.add));

    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    expect(taps, [2, 3]);
  });

  testWidgets('every item is at least 44 x 44', (tester) async {
    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));
    for (var i = 0; i < 5; i++) {
      final size = tester.getSize(find.byKey(ValueKey('tab-$i')));
      expect(size.width, greaterThanOrEqualTo(44), reason: 'tab $i width');
      expect(size.height, greaterThanOrEqualTo(44), reason: 'tab $i height');
    }
  });

  testWidgets('semantics report selected state and position', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Clock, tab 1 of 5')),
      matchesSemantics(
        label: 'Clock, tab 1 of 5',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Profile, tab 4 of 5')),
      matchesSemantics(
        label: 'Profile, tab 4 of 5',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

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

  testWidgets('the pill is capped at 480 pt and centred on a wide window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));
    final pill = find
        .descendant(
          of: find.byType(AppTabBar),
          matching: find.byType(DecoratedBox),
        )
        .first;
    // 480 pt of bar, less 16 pt of padding on each side.
    expect(tester.getSize(pill).width, lessThanOrEqualTo(480));
    expect(tester.getCenter(pill).dx, closeTo(600, 0.5));
  });

  testWidgets('the pill fills a narrow window less its side padding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));
    final pill = find
        .descendant(
          of: find.byType(AppTabBar),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(tester.getSize(pill).width, 375 - 32);
  });

  testWidgets('holding Profile for six seconds fires the debug callback', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      host(selected: 0, onSelected: (_) {}, onProfileHold: () => holds++),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-3'))),
    );
    await tester.pump(const Duration(milliseconds: 5900));
    expect(holds, 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(holds, 1);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('releasing early cancels the hold', (tester) async {
    var holds = 0;
    await tester.pumpWidget(
      host(selected: 0, onSelected: (_) {}, onProfileHold: () => holds++),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-3'))),
    );
    await tester.pump(const Duration(milliseconds: 5000));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(holds, 0);
  });

  testWidgets('other tabs do not fire the debug callback', (tester) async {
    var holds = 0;
    await tester.pumpWidget(
      host(selected: 0, onSelected: (_) {}, onProfileHold: () => holds++),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-2'))),
    );
    await tester.pump(const Duration(seconds: 7));
    await gesture.up();
    await tester.pump();
    expect(holds, 0);
  });

  testWidgets('large text does not overflow the bar', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppTabBar(selectedIndex: 1, onSelected: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
