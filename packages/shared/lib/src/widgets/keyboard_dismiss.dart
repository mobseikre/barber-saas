import 'package:flutter/material.dart';

/// Closes the keyboard when the user taps outside the focused field or drags a scroll view,
/// on every screen, sheet and dialog below it. Goes in `MaterialApp.builder`.
class KeyboardDismiss extends StatelessWidget {
  const KeyboardDismiss({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) {
            intent.focusNode.unfocus();
            return null;
          },
        ),
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag),
        child: child,
      ),
    );
  }
}
