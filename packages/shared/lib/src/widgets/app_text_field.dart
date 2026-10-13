import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/phone.dart';
import '../constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.onFieldSubmitted,
    this.suffix,
    this.required = false,
    this.focusNode,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;
  final bool required;
  final FocusNode? focusNode;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, required: required),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          autofillHints: autofillHints,
          onFieldSubmitted: onFieldSubmitted,
          inputFormatters: maxLength == null ? null : [LengthLimitingTextInputFormatter(maxLength)],
          style: AppText.body,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
        ),
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: AppText.inputLabel,
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: AppText.inputLabel.copyWith(color: AppColors.red700),
            ),
        ],
      ),
    );
  }
}

/// Libyan phone input: LTR digits with a fixed +218 prefix block.
/// The form value is the raw local number; use [normalizeLibyanPhone] on it.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'رقم الهاتف',
    this.required = false,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'أدخل رقم الهاتف';
    if (normalizeLibyanPhone(value) == null) return 'رقم الهاتف غير صحيح، مثال: 91 234 5678';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, required: required),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩ +\-]'))],
          validator: validate,
          style: AppText.body,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            hintText: '91 234 5678',
            hintTextDirection: TextDirection.ltr,
            suffixIcon: Container(
              width: AppSizes.phonePrefix,
              margin: const EdgeInsets.fromLTRB(AppSizes.border, AppSizes.border, AppSpacing.md, AppSizes.border),
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(right: BorderSide(color: AppColors.border)),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(AppRadius.control - AppSizes.border)),
              ),
              alignment: Alignment.center,
              child: Text(
                '+${AppConstants.phoneCountryCode}',
                style: AppText.bodyStrong,
                textDirection: TextDirection.ltr,
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minHeight: AppSizes.input),
          ),
        ),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'كلمة المرور',
    this.required = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String> autofillHints;

  static const minLength = AppConstants.passwordMinLength;

  static String? validate(String? value) {
    if (value == null || value.isEmpty) return 'أدخل كلمة المرور';
    if (value.length < minLength) return 'كلمة المرور يجب أن تكون $minLength أحرف على الأقل';
    return null;
  }

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hint: widget.hint,
      required: widget.required,
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator ?? PasswordField.validate,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: widget.autofillHints,
      suffix: IconButton(
        tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.text3),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
