import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../bookings/today_bookings_provider.dart';
import '../home/home_shell.dart';
import '../registration/complete_registration_screen.dart';
import 'pending_activation_screen.dart';
import 'sign_up_screen.dart';

/// Chooses the first screen from the session, the profile role and the barber's activation state.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentBarberProvider, (_, next) {
      final userId = ref.read(currentUserIdProvider);
      if (next case AsyncData(value: Barber()) when userId != null) ref.read(pushTokensProvider).register(userId);
    });
    ref.listen(pushNoticesProvider, (_, next) {
      final notice = next.value;
      if (notice == null) return;
      ref.invalidate(todayBookingsProvider);
      final text = [notice.title, notice.body].nonNulls.join('\n');
      if (text.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    });

    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return LoginScreen(
        onSignIn: ({required phone, required password}) =>
            ref.read(authRepositoryProvider).signIn(phone: phone, password: password),
        signUpRoute: () => MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
      );
    }

    final barber = ref.watch(currentBarberProvider);
    return barber.when(
      loading: () => const _Splash(),
      error: (e, _) => _Retry(message: authErrorMessage(e), onRetry: () => ref.invalidate(currentBarberProvider)),
      data: (b) {
        if (b != null) return b.isBookable ? const HomeShell() : PendingActivationScreen(barber: b);
        final profile = ref.watch(currentProfileProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (e, _) => _Retry(message: authErrorMessage(e), onRetry: () => ref.invalidate(currentProfileProvider)),
          data: (p) => p != null && p.role == UserRole.barber
              ? CompleteRegistrationScreen(profile: p)
              : const _NotBarberAccount(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.blue900,
      body: Center(child: AppLogo(size: AppSizes.avatarTile)),
    );
  }
}

class _NotBarberAccount extends ConsumerWidget {
  const _NotBarberAccount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'هذا ليس حساب حلاق', leading: AppLogo()),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هذا الرقم غير مسجّل كحلاق. لحجز موعد استخدم تطبيق حلّاقي للزبائن، أو سجّل الدخول برقم حلاق.',
                  style: AppText.body.copyWith(color: AppColors.text2),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(label: 'تسجيل الخروج', onPressed: () => signOut(ref)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Center(
          child: RetryMessage(title: 'تعذّر الاتصال بالخادم', message: message, onRetry: onRetry),
        ),
      ),
    );
  }
}
