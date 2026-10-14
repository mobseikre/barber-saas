import 'dart:async';

import 'package:shared/shared.dart';

/// Signs in and out in memory and records each call.
class FakeAuthRepo implements AuthRepository {
  FakeAuthRepo({this.userId, this.role = UserRole.customer, this.newUserId = 'customer-1'});

  String? userId;
  UserRole role;
  final String newUserId;
  final calls = <String>[];
  Object? signInError;
  Object? signUpError;
  Object? changePasswordError;
  Completer<void>? changePasswordGate;
  @override
  bool mustChangePassword = false;

  /// Plays signing in with a temporary password from an admin reset.
  bool signInWithTemporaryPassword = false;
  Object? completePasswordChangeError;
  Completer<void>? completePasswordChangeGate;
  Completer<void>? signUpGate;
  final _changes = StreamController<AuthState>.broadcast();

  void _emit(AuthChangeEvent event) => _changes.add(AuthState(event, null));

  @override
  Stream<AuthState> get onAuthStateChange => _changes.stream;

  @override
  String? get currentUserId => userId;

  @override
  Future<void> signIn({required String phone, required String password}) async {
    calls.add('signIn:$phone');
    if (signInError != null) throw signInError!;
    userId = newUserId;
    mustChangePassword = signInWithTemporaryPassword;
    _emit(AuthChangeEvent.signedIn);
  }

  @override
  Future<void> signUp({
    required String phone,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    calls.add('signUp:$phone:$fullName:${role.name}');
    await signUpGate?.future;
    if (signUpError != null) throw signUpError!;
    userId = newUserId;
    this.role = role;
    _emit(AuthChangeEvent.signedIn);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    userId = null;
    mustChangePassword = false;
    _emit(AuthChangeEvent.signedOut);
  }

  @override
  Future<Profile?> currentProfile() async => userId == null
      ? null
      : Profile(id: userId!, role: role, fullName: 'خالد المقريف', phone: '218911002030', createdAt: DateTime(2026));

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    calls.add('changePassword:$currentPassword:$newPassword');
    await changePasswordGate?.future;
    if (changePasswordError != null) throw changePasswordError!;
  }

  @override
  Future<void> completePasswordChange(String newPassword) async {
    calls.add('completePasswordChange:$newPassword');
    await completePasswordChangeGate?.future;
    if (completePasswordChangeError != null) throw completePasswordChangeError!;
    mustChangePassword = false;
    _emit(AuthChangeEvent.tokenRefreshed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
