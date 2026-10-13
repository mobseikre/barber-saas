import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/phone.dart';
import '../models/enums.dart';
import '../models/profile.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
  Session? get currentSession => _client.auth.currentSession;
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<void> signIn({required String phone, required String password}) async {
    await _client.auth.signInWithPassword(email: phoneToAuthEmail(phone), password: password);
  }

  Future<void> signUp({
    required String phone,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    await _client.auth.signUp(
      email: phoneToAuthEmail(phone),
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': role.name},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Checks [currentPassword] by signing in again, then sets [newPassword].
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw const AuthException('not_signed_in', code: 'not_authenticated');
    await _client.auth.signInWithPassword(email: email, password: currentPassword);
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<Profile?> currentProfile() async {
    final id = currentUserId;
    if (id == null) return null;
    final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }
}
