import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'features/auth/auth_gate.dart';

class BarberApp extends ConsumerWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'حلّاقي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: AppTheme.locale,
      supportedLocales: AppTheme.supportedLocales,
      localizationsDelegates: AppTheme.localizationsDelegates,
      home: const AuthGate(),
    );
  }
}
