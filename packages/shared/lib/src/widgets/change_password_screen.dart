import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/auth_errors.dart';
import '../providers/core_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'page_title.dart';

/// Lets a signed-in user replace their password after confirming the current one.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(currentPassword: _current.text, newPassword: _new.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is AuthException && e.code == 'invalid_credentials'
            ? 'كلمة المرور الحالية غير صحيحة'
            : authErrorMessage(e);
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageTitle(title: 'تغيير كلمة المرور', leading: const AppBackButton()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    controller: _current,
                    label: 'كلمة المرور الحالية',
                    validator: (v) => v == null || v.isEmpty ? 'أدخل كلمة المرور الحالية' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PasswordField(
                    controller: _new,
                    label: 'كلمة المرور الجديدة',
                    hint: '${PasswordField.minLength} أحرف على الأقل',
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PasswordField(
                    controller: _confirm,
                    label: 'تأكيد كلمة المرور الجديدة',
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) => v != _new.text ? 'كلمتا المرور غير متطابقتين' : null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(label: 'حفظ كلمة المرور', loading: _saving, onPressed: _submit),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
