import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

Future<void> initSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are missing. '
      'Run with --dart-define-from-file=env/local.json',
    );
  }
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
}

SupabaseClient get supabase => Supabase.instance.client;
