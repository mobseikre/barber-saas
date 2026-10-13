import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';

class DeviceTokenRepository {
  DeviceTokenRepository(this._client);

  final SupabaseClient _client;

  Future<void> register(String token, DevicePlatform platform) =>
      _client.rpc<void>('register_device_token', params: {'p_token': token, 'p_platform': platform.name});

  Future<void> unregister(String token) => _client.from('device_tokens').delete().eq('token', token);
}
