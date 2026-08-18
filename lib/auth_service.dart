
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuth {
  final SupabaseClient db;
  AppAuth(this.db);

  String _emailFor(String username) {
    final normalized = username.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '-');
    return '$normalized@auth.poost.app';
  }

  Future<AuthResponse> signIn(String username, String password) {
    return db.auth.signInWithPassword(
      email: _emailFor(username),
      password: password,
    );
  }

  Future<AuthResponse> signUpOwner(String username, String password) {
    return db.auth.signUp(
      email: _emailFor(username),
      password: password,
      data: {'username': username.trim(), 'role': 'owner'},
    );
  }

  Future<void> signOut() => db.auth.signOut();
}
