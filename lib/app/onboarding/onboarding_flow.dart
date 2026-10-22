import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/app/onboarding/sample_day.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/ring_mark.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The first-run flow: three pages and a way out. It is shown before the tab
/// shell and replaced by it once finished.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const int _pageCount = 3;

  final PageController _controller = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      await _controller.nextPage(
        duration: AppMotion.base,
        curve: AppMotion.standard,
      );
    }
  }

  Future<void> _finish({required bool withSampleDay}) async {
    if (_busy) return;
    setState(() => _busy = true);

    // Taken before anything is awaited and before the flow is replaced, so the
    // message outlives it.
    final messenger = ScaffoldMessenger.of(context);

    var sampleFailed = false;
    if (withSampleDay) {
      sampleFailed = !await createSampleDay(
        ref.read(eventRepositoryProvider),
        day: startOfDay(ref.read(clockProvider)),
      );
    }
    await ref.read(onboardingDoneProvider.notifier).markDone();
    if (sampleFailed) {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.sampleDayFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onLastPage = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: ContentWidths.onboarding,
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: onLastPage
                      ? null
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _finish(withSampleDay: false),
                            child: const Text(Strings.onboardingSkip),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [_IntroPage(), _TonesPage(), _PlanPage()],
                ),
              ),
              _PageDots(index: _page, count: _pageCount),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: onLastPage
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: Strings.onboardingSampleDay,
                            onPressed: _busy
                                ? null
                                : () => _finish(withSampleDay: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: Strings.onboardingStartEmpty,
                            variant: AppButtonVariant.secondary,
                            onPressed: _busy
                                ? null
                                : () => _finish(withSampleDay: false),
                          ),
                        ],
                      )
                    : AppButton(
                        label: Strings.onboardingNext,
                        onPressed: _next,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page's layout: an optional picture, a title and some text, scrollable so
/// large text never overflows.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    this.picture,
    this.body,
    this.child,
  });

  final String title;
  final Widget? picture;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (picture != null) ...[
              picture!,
              const SizedBox(height: AppSpacing.xxxl),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: colors.muted,
                ),
              ),
            ],
            if (child != null) ...[
              const SizedBox(height: AppSpacing.xl),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final tones = context.toneColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _OnboardingPage(
      title: Strings.onboardingTitle1,
      body: Strings.onboardingBody1,
      picture: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
        duration: reduceMotion ? Duration.zero : AppMotion.slow * 2,
        curve: AppMotion.standard,
        builder: (context, progress, _) => RingMark(
          colors: [tones.focus.solid, tones.life.solid, tones.inbox.solid],
          size: 180,
          progress: progress,
        ),
      ),
    );
  }
}

class _TonesPage extends StatelessWidget {
  const _TonesPage();

  static const Map<Tone, String> _examples = {
    Tone.focus: Strings.toneExampleFocus,
    Tone.life: Strings.toneExampleLife,
    Tone.inbox: Strings.toneExampleInbox,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _OnboardingPage(
      title: Strings.onboardingTitle2,
      child: Column(
        children: [
          for (final tone in Tone.values) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ToneChip(tone: tone),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_examples[tone]!, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _PlanPage extends StatelessWidget {
  const _PlanPage();

  @override
  Widget build(BuildContext context) {
    final tones = context.toneColors;
    return _OnboardingPage(
      title: Strings.onboardingTitle3,
      body: Strings.onboardingBody3,
      picture: RingMark(
        colors: [tones.focus.solid, tones.life.solid, tones.inbox.solid],
        size: 96,
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: Strings.onboardingPage(index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppMotion.base,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index
                    ? colors.ink
                    : colors.ink.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}
