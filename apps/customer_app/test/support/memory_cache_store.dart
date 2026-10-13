import 'package:customer_app/data/offline_cache.dart';

class MemoryCacheStore implements CacheStore {
  final entries = <String, String>{};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<void> delete(String key) async => entries.remove(key);

  @override
  Future<List<String>> keys() async => entries.keys.toList();
}
