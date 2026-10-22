import 'dart:async';

import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/debug/widgets/debug_section.dart';
import 'package:altidial/features/coach/coach_screen.dart';
import 'package:altidial/features/progress/providers.dart';
import 'package:altidial/features/progress/widgets/badge_grid.dart';
import 'package:altidial/features/progress/widgets/coach_teaser_card.dart';
import 'package:altidial/features/progress/widgets/level_card.dart';
import 'package:altidial/features/progress/widgets/notification_settings.dart';
import 'package:altidial/features/progress/widgets/roundup_archive.dart';
import 'package:altidial/features/progress/widgets/reflections_card.dart';
import 'package:altidial/features/progress/widgets/score_card.dart';
import 'package:altidial/features/progress/widgets/settings_card.dart';
import 'package:altidial/features/progress/widgets/stats_card.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Profile tab: level and streaks, today's score, badges, the roundup
/// archive and settings. Badge, archive and settings sections arrive in Tasks
/// 18–19; this shell already refreshes progress on open and on foregrounding.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    unawaited(ref.read(progressRepositoryProvider).ensureFresh());
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressRowProvider);
    final score = ref.watch(todayScoreProvider);
    final badges = ref.watch(unlockedBadgesProvider);
    final archive = ref.watch(roundupArchiveProvider);
    if (progress is AsyncLoading ||
        score is AsyncLoading ||
        badges is AsyncLoading ||
        archive is AsyncLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (progress.hasError ||
        score.hasError ||
        badges.hasError ||
        archive.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(Strings.profileLoadError, textAlign: TextAlign.center),
        ),
      );
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        TabBarInset.of(context) + AppSpacing.xl,
      ),
      child: ContentWidth(
        maxWidth: ContentWidths.stats,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LevelCard(progress: progress.valueOrNull),
            const SizedBox(height: AppSpacing.lg),
            ScoreCard(score: score.valueOrNull),
            const SizedBox(height: AppSpacing.lg),
            const StatsCard(),
            const SizedBox(height: AppSpacing.lg),
            CoachTeaserCard(
              onOpen: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CoachScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const ReflectionsCard(),
            const SizedBox(height: AppSpacing.lg),
            BadgeGrid(unlocked: badges.valueOrNull ?? const []),
            const SizedBox(height: AppSpacing.lg),
            RoundupArchive(summaries: archive.valueOrNull ?? const []),
            const SizedBox(height: AppSpacing.lg),
            const NotificationSettingsSection(),
            const SizedBox(height: AppSpacing.lg),
            const SettingsCard(),
            const DebugSection(),
          ],
        ),
      ),
    );
  }
}