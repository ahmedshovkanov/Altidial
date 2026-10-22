import 'dart:async';

import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/reuse_repository.dart';
import 'package:altidial/features/clock/widgets/template_name_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for a name, then saves [day]'s events as a template and says so.
Future<void> saveDayAsTemplate(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
) async {
  final name = await askTemplateName(context);
  if (name == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(reuseRepositoryProvider).saveTemplate(name: name, day: day);
    messenger.showSnackBar(
      SnackBar(content: Text(Strings.templateSaved(name))),
    );
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.templateSaveFailed)),
    );
  }
}

/// Copies the day before [day] onto it. The events appear on the dial, so
/// success needs no message; a failure says what went wrong.
Future<void> copyPreviousDay(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(reuseRepositoryProvider)
        .copyDay(from: previousDay(day), to: day);
    unawaited(HapticFeedback.mediumImpact());
  } on DayNotEmptyException {
    messenger.showSnackBar(const SnackBar(content: Text(Strings.dayNotEmpty)));
  } on Object {
    messenger.showSnackBar(const SnackBar(content: Text(Strings.copyFailed)));
  }
}
