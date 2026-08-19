# poost Media Buying OS — latest source build

This package includes:
- Android Flutter source
- Supabase client configuration
- Username/password login mapped internally to a non-user-facing synthetic email
- First-run Owner bootstrap flow (username/password chosen by the owner at first launch — nothing is hardcoded in source)
- Owner-created user architecture through a protected Edge Function
- Role/permission schema migration
- Row Level Security policies enforcing agency/client tenant isolation (`docs/MIGRATION_RLS_POLICIES.sql`)
- Role-based routing in the app (Owner / Media Buyer / Client each land on a different home screen; commission data is only ever rendered on the Owner screen)
- Meta settings UI and OAuth architecture
- Agency/client/campaign/finance/report schema
- GitHub Actions APK build workflow

## Important production prerequisites
1. Apply `docs/DATABASE_SCHEMA.sql` to the Supabase project.
2. Apply `docs/MIGRATION_AUTH_PERMISSIONS.sql`.
3. Apply `docs/MIGRATION_RLS_POLICIES.sql` — **required before real data goes in.** Without it, the anon key shipped in the APK can read/write every table directly.
4. Configure Supabase Auth email/password with email confirmation disabled if using the first-run bootstrap flow; the synthetic email is never shown to the user.
5. Deploy `supabase/functions/create-app-user` with JWT verification enabled and the project's service-role secret configured by Supabase.
6. Complete Meta Developer App/OAuth configuration.
7. Build/sign the release APK.

The package does not contain a service-role key or Meta secret.
