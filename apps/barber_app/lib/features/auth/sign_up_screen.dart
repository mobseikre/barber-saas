import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../registration/registration_details.dart';
import '../registration/registration_draft.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _draft = RegistrationDraft();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    try {
      if (auth.currentUserId == null) {
        await auth.signUp(
          phone: normalizeLibyanPhone(_phone.text)!,
          password: _password.text,
          fullName: name,
          role: UserRole.barber,
        );
      }
      final photoSaved = await registerWithDraft(ref, displayName: name, draft: _draft);
      if (!photoSaved) messenger.showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب، لكن تعذّر رفع الصورة')));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
            AppHeader(
              title: 'انضم كحلّاق',
              subtitle: 'سجّل في دقيقة واستقبل حجوزات زبائنك',
              subtitleBelow: true,
              leading: const AppLogo(),
              trailing: const AppBackButton(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'الاسم',
                        required: true,
                        controller: _name,
                        hint: 'مثال: محمد السويحلي',
                        maxLength: AppConstants.fullNameMaxLength,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (v) => (v == null || v.trim().length < 2) ? 'أدخل اسمك الكامل' : null,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PhoneField(controller: _phone, required: true, textInputAction: TextInputAction.next),
                      const SizedBox(height: AppSpacing.xl),
                      PasswordField(
                        controller: _password,
                        required: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PasswordField(
                        controller: _confirm,
                        label: 'تأكيد كلمة المرور',
                        required: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) => v != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Flexible(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: Text(
                                'اختياري — يمكنك إضافتها لاحقاً',
                                style: AppText.caption.copyWith(color: AppColors.text3),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      RegistrationDetails(draft: _draft),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(label: 'إنشاء الحساب', onPressed: _submit, loading: _loading),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('لديك حساب؟', style: AppText.body.copyWith(color: AppColors.text2)),
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('تسجيل الدخول')),
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
