import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// When the cached answer on screen was saved, while the network is unreachable; null when online.
final offlineStatus = ValueNotifier<DateTime?>(null);

abstract interface class CacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<List<String>> keys();
}

class PreferencesCacheStore implements CacheStore {
  static const _prefix = 'http_cache|';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _prefs).getString('$_prefix$key');

  @override
  Future<void> write(String key, String value) async => (await _prefs).setString('$_prefix$key', value);

  @override
  Future<void> delete(String key) async => (await _prefs).remove('$_prefix$key');

  @override
  Future<List<String>> keys() async => [
    for (final k in (await _prefs).getKeys())
      if (k.startsWith(_prefix)) k.substring(_prefix.length),
  ];
}

/// Serves the last good answer of each PostgREST read, per user, when the network is unreachable.
class CachingHttpClient extends http.BaseClient {
  CachingHttpClient(
    this._inner,
    this._store, {
    ValueNotifier<DateTime?>? status,
    this.timeout = const Duration(seconds: 12),
    this.maxEntries = 80,
  }) : status = status ?? offlineStatus;

  static const _anonymous = 'anon';

  final http.Client _inner;
  final CacheStore _store;
  final ValueNotifier<DateTime?> status;
  final Duration timeout;
  final int maxEntries;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET' || !request.url.path.startsWith('/rest/v1/')) return _inner.send(request);
    final key = '${_userOf(request)}|${request.url}';
    try {
      final response = await http.Response.fromStream(await _inner.send(request).timeout(timeout));
      status.value = null;
      if (response.statusCode == 200) await _save(key, response);
      return _streamed(response.bodyBytes, response.statusCode, response.headers, request);
    } on http.ClientException {
      final cached = await _cached(key, request);
      if (cached == null) rethrow;
      return cached;
    } on TimeoutException {
      final cached = await _cached(key, request);
      if (cached == null) rethrow;
      return cached;
    }
  }

  /// Forgets everything stored for signed-in users, e.g. after sign-out.
  Future<void> clearUserEntries() async {
    status.value = null;
    for (final key in await _store.keys()) {
      if (!key.startsWith('$_anonymous|')) await _store.delete(key);
    }
  }

  Future<http.StreamedResponse?> _cached(String key, http.BaseRequest request) async {
    final raw = await _store.read(key);
    if (raw == null) return null;
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final savedAt = DateTime.tryParse(entry['at'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc();
    final shown = status.value;
    status.value = shown == null || savedAt.isBefore(shown) ? savedAt : shown;
    return _streamed(utf8.encode(entry['body'] as String), 200, const {
      'content-type': 'application/json; charset=utf-8',
    }, request);
  }

  Future<void> _save(String key, http.Response response) async {
    await _store.write(
      key,
      jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'body': utf8.decode(response.bodyBytes)}),
    );
    final keys = await _store.keys();
    if (keys.length <= maxEntries) return;
    final saved = <String, String>{};
    for (final k in keys) {
      saved[k] = (jsonDecode(await _store.read(k) ?? '{}') as Map<String, dynamic>)['at'] as String? ?? '';
    }
    final oldest = saved.keys.toList()..sort((a, b) => saved[a]!.compareTo(saved[b]!));
    for (final k in oldest.take(keys.length - maxEntries)) {
      await _store.delete(k);
    }
  }

  http.StreamedResponse _streamed(List<int> bytes, int status, Map<String, String> headers, http.BaseRequest request) =>
      http.StreamedResponse(Stream.value(bytes), status, headers: headers, request: request);

  String _userOf(http.BaseRequest request) {
    final parts = (request.headers['Authorization'] ?? '').replaceFirst('Bearer ', '').split('.');
    if (parts.length != 3) return _anonymous;
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
      return claims['sub'] as String? ?? _anonymous;
    } on FormatException {
      return _anonymous;
    }
  }
}
