import 'package:flutter/material.dart';

import '../auth/phone.dart';
import '../errors/auth_errors.dart';
import '../support/whatsapp.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_header.dart';
import 'app_logo.dart';
import 'page_title.dart';
import 'app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignIn, required this.signUpRoute});

  final Future<void> Function({required String phone, required String password}) onSignIn;
  final Route<void> Function() signUpRoute;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
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
      await widget.onSignIn(phone: normalizeLibyanPhone(_phone.text)!, password: _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() => contactSupport(context, message: 'نسيت كلمة المرور، رقمي: ${_phone.text}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            AppHeader(
              title: 'تسجيل الدخول',
              subtitle: 'أهلاً بعودتك إلى حلّاقي',
              subtitleBelow: true,
              leading: ModalRoute.of(context)?.canPop == true
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppBackButton(),
                        SizedBox(width: AppSpacing.md),
                        AppLogo(),
                      ],
                    )
                  : const AppLogo(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PhoneField(controller: _phone, textInputAction: TextInputAction.next),
                      const SizedBox(height: AppSpacing.xl),
                      PasswordField(
                        controller: _password,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(label: 'تسجيل الدخول', onPressed: _submit, loading: _loading),
                      const SizedBox(height: AppSpacing.xxl),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('ليس لديك حساب؟', style: AppText.body.copyWith(color: AppColors.text2)),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(widget.signUpRoute()),
                              child: const Text('إنشاء حساب'),
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
