import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'features/home/home_shell.dart';
import 'providers.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(connectivityProvider, (previous, online) {
      if (online.value != true) return;
      if (previous?.value == false || ref.read(offlineProvider) != null) refreshAll(ref);
    });
    return MaterialApp(
      title: 'حلّاقي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: AppTheme.locale,
      supportedLocales: AppTheme.supportedLocales,
      localizationsDelegates: AppTheme.localizationsDelegates,
      home: const HomeShell(),
    );
  }
}
