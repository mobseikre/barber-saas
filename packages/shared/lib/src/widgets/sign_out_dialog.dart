import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'app_button.dart';

/// Asks before signing out, then signs out through [signOut].
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تسجيل الخروج؟'),
      content: const Text('ستحتاج رقم هاتفك وكلمة المرور للدخول مرة أخرى.'),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('رجوع')),
        AppButton(
          label: 'تسجيل الخروج',
          variant: AppButtonVariant.accent,
          compact: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  if (confirmed == true) await signOut(ref);
}
