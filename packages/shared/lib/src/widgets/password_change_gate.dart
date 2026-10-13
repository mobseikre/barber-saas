import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/auth_errors.dart';
import '../providers/core_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_header.dart';
import 'app_logo.dart';
import 'app_text_field.dart';

/// Goes in `MaterialApp.builder`: keeps the app hidden under [ChangePasswordRequiredScreen]
/// while the session carries `must_change_password`.
class PasswordChangeGate extends ConsumerWidget {
  const PasswordChangeGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(mustChangePasswordProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: locked,
          child: TickerMode(
            enabled: !locked,
            child: ExcludeFocus(excluding: locked, child: child),
          ),
        ),
        if (locked)
          HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const ChangePasswordRequiredScreen()),
            ),
          ),
      ],
    );
  }
}

class ChangePasswordRequiredScreen extends ConsumerStatefulWidget {
  const ChangePasswordRequiredScreen({super.key});

  @override
  ConsumerState<ChangePasswordRequiredScreen> createState() => _ChangePasswordRequiredScreenState();
}

class _ChangePasswordRequiredScreenState extends ConsumerState<ChangePasswordRequiredScreen> {
  final _formKey = GlobalKey<FormState>();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).completePasswordChange(_new.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = authErrorMessage(e);
        });
      }
      return;
    }
    messenger?.showSnackBar(const SnackBar(content: Text('تم حفظ كلمة المرور الجديدة')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const AppHeader(
                title: 'اختر كلمة مرور جديدة',
                subtitle: 'أعادت الإدارة تعيين كلمة مرورك. اختر كلمة مرور خاصة بك للمتابعة.',
                subtitleBelow: true,
                leading: AppLogo(),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        AppButton(label: 'حفظ والمتابعة', loading: _saving, onPressed: _submit),
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: TextButton(
                            onPressed: _saving ? null : () => signOut(ref),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
