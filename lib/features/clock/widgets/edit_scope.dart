import 'package:altidial/core/strings.dart';
import 'package:altidial/shared/widgets/adaptive_choice.dart';
import 'package:flutter/widgets.dart';

/// How far a change to one event of a repeating series reaches.
enum EditScope {
  /// Only the event the person is looking at. The series is left alone.
  thisEvent,

  /// This event and every later one: the series is split here.
  thisAndFuture,
}

/// Asks how far an edit of a repeating event reaches. Returns null when the
/// person cancels.
///
/// When [ruleChanged] is true they have changed how the event repeats, which
/// cannot apply to a single occurrence, so only "this and all future" is
/// offered and the prompt says so.
Future<EditScope?> askEditScope(
  BuildContext context, {
  bool ruleChanged = false,
}) {
  if (ruleChanged) {
    return chooseOne<EditScope>(
      context,
      title: Strings.repeatChangeTitle,
      body: Strings.repeatChangeBody,
      options: const [
        ChoiceOption(
          label: Strings.scopeThisAndFuture,
          value: EditScope.thisAndFuture,
        ),
      ],
      cancelLabel: Strings.cancel,
    );
  }
  return chooseOne<EditScope>(
    context,
    title: Strings.editScopeTitle,
    options: const [
      ChoiceOption(label: Strings.scopeThisEvent, value: EditScope.thisEvent),
      ChoiceOption(
        label: Strings.scopeThisAndFuture,
        value: EditScope.thisAndFuture,
      ),
    ],
    cancelLabel: Strings.cancel,
  );
}

/// Asks how far a delete of a repeating event reaches. Returns null when the
/// person cancels.
Future<EditScope?> askDeleteScope(BuildContext context) {
  return chooseOne<EditScope>(
    context,
    title: Strings.deleteScopeTitle,
    options: const [
      ChoiceOption(
        label: Strings.scopeThisEvent,
        value: EditScope.thisEvent,
        destructive: true,
      ),
      ChoiceOption(
        label: Strings.scopeThisAndFuture,
        value: EditScope.thisAndFuture,
        destructive: true,
      ),
    ],
    cancelLabel: Strings.cancel,
  );
}
