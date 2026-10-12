import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'focus_ring_border.dart';
import 'app_text.dart';

abstract final class AppTheme {
  static const locale = Locale('ar');
  static const supportedLocales = [locale];
  static const localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static ThemeData light() {
    final textTheme = TextTheme(
      displaySmall: AppText.display,
      headlineMedium: AppText.h1,
      headlineSmall: AppText.h2,
      titleMedium: AppText.h3,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      labelLarge: AppText.button,
      labelMedium: AppText.inputLabel,
      labelSmall: AppText.label,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: const BorderSide(color: AppColors.border, width: AppSizes.border),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.cairo,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.blue900,
        onPrimary: AppColors.surface,
        secondary: AppColors.poleRed,
        onSecondary: AppColors.surface,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.danger,
        outline: AppColors.border,
      ),
      textTheme: textTheme,
      dividerColor: AppColors.dividerSoft,
      dividerTheme: const DividerThemeData(color: AppColors.dividerSoft, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.blue900,
        foregroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.h1.copyWith(color: AppColors.surface),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSizes.inputPaddingY),
        hintStyle: AppText.body.copyWith(color: AppColors.text3),
        labelStyle: AppText.inputLabel,
        errorStyle: AppText.caption.copyWith(color: AppColors.danger),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: FocusRingBorder(
          borderRadius: inputBorder.borderRadius,
          borderSide: const BorderSide(color: AppColors.red400, width: AppSizes.border),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: AppSizes.border),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: AppSizes.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.button),
          backgroundColor: AppColors.blue900,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.blue100,
          disabledForegroundColor: AppColors.text3,
          textStyle: AppText.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        ).copyWith(overlayColor: const WidgetStatePropertyAll(AppColors.bluePressed)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.button),
          foregroundColor: AppColors.blue900,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.blue900, width: AppSizes.border),
          textStyle: AppText.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.red700, textStyle: AppText.button),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.panel))),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.panel)),
        titleTextStyle: AppText.h2,
        contentTextStyle: AppText.body,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.blue900,
        contentTextStyle: AppText.body.copyWith(color: AppColors.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.poleRed : AppColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.blue900 : AppColors.switchOff,
        ),
      ),
    );
  }
}
