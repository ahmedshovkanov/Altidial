import 'dart:async';

import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:altidial/features/flight_deck/breathing/widgets/breathing_orb.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The full-screen guided-breathing minigame. Inhale for four seconds while
/// pressing and holding anywhere on the screen, then exhale for six with the
/// finger off. Eight breaths, then a finish card. It keeps nothing outside the
/// route and never writes to storage.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  final BreathingCycle _cycle = BreathingCycle();
  late final AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _cycle.phaseDuration,
      // The guide is a timer as much as an animation: even when the system
      // asks for reduced motion the breath must still take four and six
      // seconds, so the controller must not shorten its duration.
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_onTick);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_cycle.done) return;
    if (_controller.value < _controller.upperBound) return;
    _cycle.advance();
    setState(() {});
    if (_cycle.done) {
      unawaited(HapticFeedback.mediumImpact());
      return;
    }
    _controller.duration = _cycle.phaseDuration;
    _controller.forward(from: 0);
    unawaited(HapticFeedback.selectionClick());
  }

  void _restart() {
    setState(() {
      _cycle.reset();
      _pressed = false;
    });
    _controller.duration = _cycle.phaseDuration;
    _controller.forward(from: 0);
  }

  void _close() {
    Navigator.of(context).pop();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (_cycle.done || !_inSync) return;
    unawaited(HapticFeedback.lightImpact());
  }

  bool get _inSync =>
      _cycle.phase == BreathPhase.inhale ? _pressed : !_pressed;

  String get _phaseLabel => _cycle.phase == BreathPhase.inhale
      ? Strings.breatheInhale
      : Strings.breatheExhale;

  /// The gentle correction, shown only while the finger is out of step.
  String? get _prompt {
    if (_cycle.done || _inSync) return null;
    return _cycle.phase == BreathPhase.inhale
        ? Strings.breathePress
        : Strings.breatheRelease;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: colors.page,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _setPressed(true),
                onPointerUp: (_) => _setPressed(false),
                onPointerCancel: (_) => _setPressed(false),
                child: _body(colors, reduceMotion),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton(
                key: const ValueKey('breathe-close'),
                tooltip: Strings.breatheClose,
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
            ),
            if (_cycle.done)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: _finish(colors),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColors colors, bool reduceMotion) {
    final theme = Theme.of(context);
    return Center(
      child: ContentWidth(
        maxWidth: ContentWidths.column,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final smallest = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              final diameter = (smallest * 0.72).clamp(180.0, 360.0);
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final fraction = _controller.value;
                  final secondsLeft =
                      _cycle.secondsLeft(_cycle.phaseDuration * fraction);
                  final breathNumber = (_cycle.breathsTaken + 1)
                      .clamp(1, _cycle.totalBreaths);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(Strings.breatheScreenTitle,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        Strings.breatheCount(breathNumber, _cycle.totalBreaths),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Semantics(
                        label: Strings.breathePhaseSemantics(
                          _phaseLabel,
                          secondsLeft,
                        ),
                        excludeSemantics: true,
                        child: BreathingOrb(
                          diameter: diameter,
                          phase: _cycle.phase,
                          fraction: fraction,
                          secondsLeft: secondsLeft,
                          label: _phaseLabel,
                          inSync: _inSync,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: 24,
                        child: Text(
                          _prompt ?? '',
                          key: const ValueKey('breathe-prompt'),
                          style: theme.textTheme.titleSmall!
                              .copyWith(color: colors.muted),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _finish(AppColors colors) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: colors.page.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Strings.breatheDoneTitle,
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Strings.breatheDoneBody(_cycle.totalBreaths),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(color: colors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    key: const ValueKey('breathe-again'),
                    onPressed: _restart,
                    child: const Text(Strings.breatheAgain),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('breathe-done'),
                    onPressed: _close,
                    child: const Text(Strings.breatheFinish),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
