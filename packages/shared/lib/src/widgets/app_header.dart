import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

/// Dark blue screen header with large rounded bottom corners.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottom,
    this.top,
    this.centered = false,
    this.subtitleBelow = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? bottom;

  /// Shown above the title, e.g. the large logo of the customer sign-up screen.
  final Widget? top;
  final bool centered;

  /// Puts the subtitle under the title, as on the sign-in and sign-up screens.
  final bool subtitleBelow;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final subtitleText = Text(
      subtitle ?? '',
      style: AppText.caption.copyWith(color: AppColors.onDarkMuted),
      textAlign: centered ? TextAlign.center : null,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(AppSpacing.screen, topInset + AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl),
        decoration: const BoxDecoration(
          color: AppColors.blue900,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.header)),
        ),
        child: Column(
          crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (top != null) ...[top!, const SizedBox(height: AppSpacing.lg)],
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      if (subtitle != null && !subtitleBelow) subtitleText,
                      Text(
                        title,
                        style: AppText.h1.copyWith(color: AppColors.surface),
                        textAlign: centered ? TextAlign.center : null,
                      ),
                      if (subtitle != null && subtitleBelow) subtitleText,
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (bottom != null) ...[const SizedBox(height: AppSpacing.xl), bottom!],
          ],
        ),
      ),
    );
  }
}

/// Keeps scrolled content out from under the status bar: a strip the colour of the screen's top,
/// with status bar icons that stay readable on it.
class StatusBarScrim extends StatelessWidget {
  const StatusBarScrim({super.key, required this.child, this.dark = false});

  final Widget child;

  /// A dark blue top (header or photo) instead of the light app background.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: IgnorePointer(child: ColoredBox(color: dark ? AppColors.blue900 : AppColors.bg)),
          ),
        ],
      ),
    );
  }
}

/// Dark blue stat tile: label, big value, red sub-line.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.icon,
    this.background = AppColors.blue800,
    this.valueColor = AppColors.surface,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData? icon;
  final Color background;
  final Color valueColor;

  /// The small header tile (r12, 20/800 value, 12px label), as on today's bookings.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.control)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: AppText.weight(AppText.h2.copyWith(color: valueColor), FontWeight.w800)),
            ),
            Text(
              label,
              style: AppText.weight(AppText.label.copyWith(color: AppColors.onDarkInactive), FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Row(
              children: [
                Icon(icon, size: AppSizes.iconSm, color: AppColors.red400),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.caption.copyWith(color: AppColors.onDarkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppText.statValue.copyWith(color: valueColor)),
          ),
          if (icon == null)
            Text(
              label,
              style: AppText.caption.copyWith(color: AppColors.onDarkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (detail != null)
            Text(
              detail!,
              style: AppText.caption.copyWith(color: AppColors.red300),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// White card with the design-system shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: highlighted ? Border.all(color: AppColors.red400, width: AppSizes.border) : null,
        boxShadow: const [AppColors.cardShadow],
      ),
      child: child,
    );
  }
}

const _letterRatio = 0.4;

/// Circle avatar with the photo when [imageUrl] is set, otherwise the first letter of [name].
class LetterAvatar extends StatelessWidget {
  const LetterAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AppSizes.avatar,
    this.radius,
    this.background = AppColors.blue800,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final double? radius;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius ?? size / 2);
    final letter = Text(
      name.trim().isEmpty ? '؟' : name.trim().characters.first,
      style: AppText.cardTitle.copyWith(color: AppColors.red400, fontSize: size * _letterRatio),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: background, borderRadius: borderRadius),
      alignment: Alignment.center,
      child: imageUrl == null
          ? letter
          : Image.network(imageUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => letter),
    );
  }
}
