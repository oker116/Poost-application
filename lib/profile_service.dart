import 'package:supabase_flutter/supabase_flutter.dart';

/// Roles as stored in `profiles.role` (see docs/DATABASE_SCHEMA.sql).
enum AppRole { owner, mediaBuyer, client, unknown }

AppRole roleFromString(String? value) {
  switch (value) {
    case 'owner':
      return AppRole.owner;
    case 'media_buyer':
      return AppRole.mediaBuyer;
    case 'client':
      return AppRole.client;
    default:
      return AppRole.unknown;
  }
}

class AppProfile {
  final String id;
  final String agencyId;
  final String fullName;
  final AppRole role;
  final String? clientId;
  final Map<String, dynamic> permissions;

  const AppProfile({
    required this.id,
    required this.agencyId,
    required this.fullName,
    required this.role,
    required this.clientId,
    required this.permissions,
  });

  factory AppProfile.fromRow(Map<String, dynamic> row) => AppProfile(
        id: row['id'] as String,
        agencyId: row['agency_id'] as String,
        fullName: (row['full_name'] as String?) ?? '',
        role: roleFromString(row['role'] as String?),
        clientId: row['client_id'] as String?,
        permissions: (row['permissions'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  bool get canSeeFinance => role == AppRole.owner || permissions['finance'] == true;
}

class ProfileService {
  final SupabaseClient db;
  ProfileService(this.db);

  /// Fetches the profile row for the currently authenticated user.
  /// Returns null if the user has no profile yet (e.g. mid-bootstrap).
  /// Relies on RLS: a signed-in user can always read their own profile row
  /// (see docs/MIGRATION_RLS_POLICIES.sql, policy `profiles_select_self`).
  Future<AppProfile?> currentProfile() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await db
        .from('profiles')
        .select('id,agency_id,full_name,role,client_id,permissions')
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return AppProfile.fromRow(row);
  }
}
