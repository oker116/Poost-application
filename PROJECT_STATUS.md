# poost Media Buying OS — latest source build

This package includes:
- Android Flutter source
- Supabase client configuration
- Username/password login mapped internally to a non-user-facing synthetic email
- First-run Owner bootstrap flow (`yosef aped` / password entered by owner)
- Owner-created user architecture through a protected Edge Function
- Role/permission schema migration
- Meta settings UI and OAuth architecture
- Agency/client/campaign/finance/report schema
- GitHub Actions APK build workflow

## Important production prerequisites
1. Apply `docs/MIGRATION_AUTH_PERMISSIONS.sql` to the Supabase project.
2. Configure Supabase Auth email/password with email confirmation disabled if using the first-run bootstrap flow; the synthetic email is never shown to the user.
3. Deploy `supabase/functions/create-app-user` with JWT verification enabled and the project's service-role secret configured by Supabase.
4. Complete Meta Developer App/OAuth configuration.
5. Build/sign the release APK.

The package does not contain a service-role key or Meta secret.
