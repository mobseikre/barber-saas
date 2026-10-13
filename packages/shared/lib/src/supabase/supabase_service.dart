import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

Future<void> initSupabase({
  http.Client? httpClient,
  String url = SupabaseConfig.url,
  String publishableKey = SupabaseConfig.publishableKey,
}) async {
  if (url.isEmpty || publishableKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are missing. '
      'Run with --dart-define-from-file=env/local.json',
    );
  }
  await Supabase.initialize(
    url: url,
    publishableKey: publishableKey,
    httpClient: httpClient,
    // Barber links open the app too; no link may ever sign anyone in.
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
