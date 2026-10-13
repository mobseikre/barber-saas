import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../auth/sign_in.dart';
import 'change_password_screen.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final profile = ref.watch(currentProfileProvider);
    return StatusBarScrim(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PageTitle(title: 'حسابي'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: signedIn
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (profile.value case final p?)
                        AppCard(
                          child: Row(
                            children: [
                              LetterAvatar(name: p.fullName, imageUrl: publicStorageUrl(p.avatarUrl)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.fullName, style: AppText.cardTitle),
                                    Text(
                                      formatLibyanPhone(p.phone),
                                      style: AppText.caption.copyWith(color: AppColors.text3),
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (profile.hasError)
                        RetryMessage(
                          message: authErrorMessage(profile.error!),
                          onRetry: () => ref.invalidate(currentProfileProvider),
                          inline: true,
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'تغيير كلمة المرور',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.lock_outline_rounded,
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen())),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'تواصل مع الدعم',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.chat_outlined,
                        onPressed: () => contactSupport(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'تسجيل الخروج',
                        variant: AppButtonVariant.text,
                        onPressed: () => ref.read(authRepositoryProvider).signOut(),
                      ),
                    ],
                  )
                : const SignInPrompt(message: 'سجّل الدخول لتحجز موعدك وتتابع حجوزاتك'),
          ),
        ],
      ),
    );
  }
}

/// Shown on the tabs that need an account.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: AppText.body.copyWith(color: AppColors.text2)),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: 'تسجيل الدخول', onPressed: () => openSignIn(context)),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'إنشاء حساب',
          variant: AppButtonVariant.secondary,
          onPressed: () => openSignIn(context, signUp: true),
        ),
      ],
    );
  }
}
