import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// Title block for the light screens: title and subtitle, with an optional back button or action.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle, this.leading, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          MediaQuery.paddingOf(context).top + AppSpacing.xl,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.h1),
                  if (subtitle != null) Text(subtitle!, style: AppText.caption.copyWith(color: AppColors.text3)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Outlined square back button; the arrow points right in RTL.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SquareIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'رجوع',
      outlined: true,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
