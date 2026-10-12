import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// Error message with an "إعادة المحاولة" action, as a centred block or, with [inline], a single row.
class RetryMessage extends StatelessWidget {
  const RetryMessage({super.key, required this.message, required this.onRetry, this.title, this.inline = false});

  final String message;
  final VoidCallback onRetry;
  final String? title;
  final bool inline;

  static const retryLabel = 'إعادة المحاولة';

  @override
  Widget build(BuildContext context) {
    if (inline) {
      return Row(
        children: [
          Expanded(
            child: Text(message, style: AppText.caption.copyWith(color: AppColors.danger)),
          ),
          TextButton(onPressed: onRetry, child: const Text(retryLabel)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[Text(title!, style: AppText.h2), const SizedBox(height: AppSpacing.sm)],
        Text(
          message,
          style: title == null
              ? AppText.body.copyWith(color: AppColors.danger)
              : AppText.caption.copyWith(color: AppColors.text3),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: title == null ? AppSpacing.lg : AppSpacing.xxl),
        AppButton(label: retryLabel, onPressed: onRetry),
      ],
    );
  }
}
