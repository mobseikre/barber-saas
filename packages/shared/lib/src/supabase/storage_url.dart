import 'supabase_config.dart';

/// Public URL of a file stored as `<bucket>/<path>`; values that are already URLs are returned as they are.
String? publicStorageUrl(String? stored, {String base = SupabaseConfig.url}) {
  if (stored == null || stored.isEmpty) return null;
  if (stored.startsWith('http://') || stored.startsWith('https://')) return stored;
  return '$base/storage/v1/object/public/$stored';
}
