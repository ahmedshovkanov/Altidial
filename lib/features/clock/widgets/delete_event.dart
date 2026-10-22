import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/widgets/edit_scope.dart';
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks, then deletes [event]. Returns true when it was deleted. Used by the
/// detail sheet and by the dial's VoiceOver Delete action.
///
/// An occurrence of a repeating series asks how far the delete reaches: "this
/// event" skips just that day, so the series cannot bring it back; "this and
/// all future events" ends the series here. Any other event asks for a plain
/// confirmation.
Future<bool> confirmAndDeleteEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  if (event.seriesId != null) {
    final scope = await askDeleteScope(context);
    if (scope == null) return false;
    switch (scope) {
      case EditScope.thisEvent:
        await ref.read(eventRepositoryProvider).deleteEvent(event.id);
      case EditScope.thisAndFuture:
        await ref.read(seriesRepositoryProvider).deleteFromHere(event.id);
    }
    return true;
  }

  final confirmed = await confirmDestructive(
    context,
    title: Strings.deleteConfirmTitle,
    body: Strings.deleteConfirmBody,
    confirmLabel: Strings.delete,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed) return false;
  await ref.read(eventRepositoryProvider).deleteEvent(event.id);
  return true;
}
