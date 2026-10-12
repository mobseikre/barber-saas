import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import 'registration_details.dart';
import 'registration_draft.dart';

/// For a signed-in barber whose registration stopped before the barber row was created.
class CompleteRegistrationScreen extends ConsumerStatefulWidget {
  const CompleteRegistrationScreen({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<CompleteRegistrationScreen> createState() => _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState extends ConsumerState<CompleteRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  final _draft = RegistrationDraft();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final photoSaved = await registerWithDraft(ref, displayName: _name.text.trim(), draft: _draft);
      if (!photoSaved) messenger.showSnackBar(const SnackBar(content: Text('تم إكمال التسجيل، لكن تعذّر رفع الصورة')));
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
              title: 'أكمل تسجيلك',
              subtitle: 'اختر صالونك وحدّد موقعه لنُكمل طلبك',
              subtitleBelow: true,
              leading: AppLogo(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'الاسم',
                      required: true,
                      controller: _name,
                      validator: (v) => (v == null || v.trim().length < 2) ? 'أدخل اسمك الكامل' : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    RegistrationDetails(draft: _draft),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(label: 'إكمال التسجيل', onPressed: _submit, loading: _loading),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton(
                        onPressed: () => ref.read(authRepositoryProvider).signOut(),
                        child: const Text('تسجيل الخروج'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
