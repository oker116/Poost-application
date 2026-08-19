# Connect-now checklist

The source is configured for the supplied Supabase project.

## One-time Supabase setup
- Run `DATABASE_SCHEMA.sql`.
- Run `MIGRATION_AUTH_PERMISSIONS.sql`.
- Run `MIGRATION_RLS_POLICIES.sql`. **Do not skip this.** Without it, every
  table is readable/writable by anyone holding the app's publishable (anon)
  key, which ships inside the APK by design.
- In Authentication settings, enable password sign-in and disable email
  confirmation for the synthetic-email username flow.
- Deploy `supabase/functions/create-app-user` with JWT verification.

## First launch
Pick any Owner username and a strong password yourself when you first open
the app — the login screen ships empty on purpose, there is no default
username/password baked into the source. Type your chosen credentials into
the Username/Password fields, tap `تهيئة Owner لأول مرة` once to bootstrap
the account, then log in normally.

## User creation
Owner creates Media Buyers/Clients from the app. The protected Edge Function creates their Auth accounts and profile/permissions.

## Meta
Create a Meta Developer App, configure OAuth redirect to the backend function, then connect each ad account from the app. Do not place a long-lived access token in the APK.
