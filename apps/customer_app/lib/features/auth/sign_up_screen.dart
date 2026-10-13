import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

class CustomerSignUpScreen extends ConsumerStatefulWidget {
  const CustomerSignUpScreen({super.key, required this.onDone, this.onSignIn});

  final VoidCallback onDone;

  /// Opens the login screen; goes back to it by default.
  final VoidCallback? onSignIn;

  @override
  ConsumerState<CustomerSignUpScreen> createState() => _CustomerSignUpScreenState();
}

class _CustomerSignUpScreenState extends ConsumerState<CustomerSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            phone: normalizeLibyanPhone(_phone.text)!,
            password: _password.text,
            fullName: _name.text.trim(),
            role: UserRole.customer,
          );
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(
              title: 'أهلاً بك في حلّاقي',
              subtitle: 'احجز موعدك عند أقرب حلاق بدون انتظار',
              subtitleBelow: true,
              centered: true,
              top: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: double.infinity),
                  AppLogo(size: AppSizes.avatarTile),
                  PositionedDirectional(start: 0, child: AppBackButton()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إنشاء حساب', style: AppText.h2),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        label: 'الاسم',
                        controller: _name,
                        hint: 'اكتب اسمك',
                        maxLength: AppConstants.fullNameMaxLength,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (v) => (v == null || v.trim().length < 2) ? 'أدخل اسمك' : null,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PhoneField(controller: _phone, textInputAction: TextInputAction.next),
                      const SizedBox(height: AppSpacing.xl),
                      PasswordField(
                        controller: _password,
                        hint: '${AppConstants.passwordMinLength} أحرف على الأقل',
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
                      ],
                      const SizedBox(height: AppSpacing.xxxl),
                      AppButton(label: 'إنشاء الحساب', onPressed: _submit, loading: _loading),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('لديك حساب؟', style: AppText.body.copyWith(color: AppColors.text2)),
                            TextButton(
                              onPressed: widget.onSignIn ?? () => Navigator.of(context).pop(),
                              child: const Text('تسجيل الدخول'),
                            ),
                          ],
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
    );
  }
}
