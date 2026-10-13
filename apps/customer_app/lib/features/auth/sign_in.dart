import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'sign_up_screen.dart';

/// Signs the customer in over the current screen and returns whether there is a session.
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authRepositoryProvider);
  if (auth.currentUserId != null) return true;
  await openSignIn(context);
  return auth.currentUserId != null;
}

Future<void> openSignIn(BuildContext context, {bool signUp = false}) {
  final navigator = Navigator.of(context);
  final origin = ModalRoute.of(context);
  void done() => navigator.popUntil((route) => origin == null ? route.isFirst : route == origin);
  Route<void> login() => MaterialPageRoute<void>(builder: (_) => CustomerLoginScreen(onDone: done));
  return navigator.push(
    signUp
        ? MaterialPageRoute<void>(
            builder: (_) => CustomerSignUpScreen(onDone: done, onSignIn: () => navigator.pushReplacement(login())),
          )
        : login(),
  );
}

class CustomerLoginScreen extends ConsumerWidget {
  const CustomerLoginScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LoginScreen(
      onSignIn: ({required phone, required password}) async {
        final auth = ref.read(authRepositoryProvider);
        await auth.signIn(phone: phone, password: password);
        final profile = await auth.currentProfile();
        if (profile?.role != UserRole.customer) {
          await auth.signOut();
          throw const PostgrestException(message: 'not_a_customer');
        }
        onDone();
      },
      signUpRoute: () => MaterialPageRoute<void>(builder: (_) => CustomerSignUpScreen(onDone: onDone)),
    );
  }
}
