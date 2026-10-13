import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

import 'app.dart';
import 'data/offline_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  final cache = CachingHttpClient(http.Client(), PreferencesCacheStore());
  await initSupabase(httpClient: cache);
  supabase.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.signedOut) cache.clearUserEntries();
  });
  runApp(const ProviderScope(child: CustomerApp()));
}
