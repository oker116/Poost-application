# Connect-now checklist

The source is configured for the supplied Supabase project.

## One-time Supabase setup
- Run `MIGRATION_AUTH_PERMISSIONS.sql`.
- In Authentication settings, enable password sign-in and disable email confirmation for the synthetic-email username flow.
- Deploy `supabase/functions/create-app-user` with JWT verification.

## First launch
Username: `yosef aped`
Password: use the Owner password chosen for the production account.
Tap `تهيئة Owner لأول مرة` once, then login.

## User creation
Owner creates Media Buyers/Clients from the app. The protected Edge Function creates their Auth accounts and profile/permissions.

## Meta
Create a Meta Developer App, configure OAuth redirect to the backend function, then connect each ad account from the app. Do not place a long-lived access token in the APK.
