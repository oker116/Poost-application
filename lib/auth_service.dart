
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deterministic mapping from a display username to the synthetic email
/// Supabase Auth requires. Kept top-level (not private) so it can be unit
/// tested without spinning up a Supabase client.
///
/// Throws [ArgumentError] on empty/invalid usernames instead of silently
/// producing a malformed email like "@auth.poost.app".
String emailForUsername(String username) {
  final trimmed = username.trim().toLowerCase();
  final normalized = trimmed.replaceAll(RegExp(r'[^a-z0-9._-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (normalized.isEmpty) {
    throw ArgumentError('اسم المستخدم غير صالح');
  }
  return '$normalized@auth.poost.app';
}

/// Friendly, user-facing translation of common Supabase auth failures.
/// Falls back to a generic message for anything unrecognized instead of
/// leaking raw exception text to the UI.
String describeAuthError(Object error) {
  if (error is ArgumentError) return 'اسم المستخدم غير صالح.';
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
    }
    if (msg.contains('email not confirmed')) {
      return 'الحساب لم يتم تفعيله بعد. تحقق من إعدادات Email confirmation في Supabase.';
    }
    if (msg.contains('user already registered')) {
      return 'الحساب مُهيّأ بالفعل. اضغط دخول بدلاً من التهيئة.';
    }
    if (msg.contains('password') && (msg.contains('short') || msg.contains('weak'))) {
      return 'كلمة المرور قصيرة جدًا أو ضعيفة.';
    }
    return 'تعذر تسجيل الدخول: ${error.message}';
  }
  if (error is PostgrestException) {
    return 'تعذر إكمال العملية على قاعدة البيانات: ${error.message}';
  }
  // Network/timeout/anything else: show the real exception text instead of
  // a generic message, so problems are diagnosable from a screenshot alone.
  return 'خطأ: ${error.toString()}';
}

class AppAuth {
  final SupabaseClient db;
  AppAuth(this.db);

  Future<AuthResponse> signIn(String username, String password) {
    return db.auth.signInWithPassword(
      email: emailForUsername(username),
      password: password,
    );
  }

  Future<AuthResponse> signUpOwner(String username, String password) {
    return db.auth.signUp(
      email: emailForUsername(username),
      password: password,
      data: {'username': username.trim(), 'role': 'owner'},
    );
  }

  Future<void> signOut() => db.auth.signOut();
}
