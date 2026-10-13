import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

/// The text field under the label [label], as the user sees it on the form.
Finder fieldLabelled(String label) => find.descendant(
  of: find
      .ancestor(of: find.byWidgetPredicate((w) => w is FieldLabel && w.text == label), matching: find.byType(Column))
      .first,
  matching: find.byType(TextFormField),
);
