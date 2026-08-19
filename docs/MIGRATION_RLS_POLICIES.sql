-- =============================================================================
-- RLS lockdown for poost Media Buying OS.
--
-- WHY THIS FILE EXISTS
-- DATABASE_SCHEMA.sql creates every table WITHOUT enabling row level
-- security. In Supabase, tables without RLS are readable/writable by
-- anyone holding the publishable (anon) key — which ships inside the APK
-- by design (lib/supabase_config.dart). That means, before this migration,
-- any user could pull the anon key out of the app and read/write every
-- agency's clients, commissions and metrics directly via the REST API,
-- without ever signing in.
--
-- Apply this AFTER docs/DATABASE_SCHEMA.sql and
-- docs/MIGRATION_AUTH_PERMISSIONS.sql.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Helper functions (security definer so they can read `profiles` without
-- recursively triggering the RLS policy defined ON `profiles` itself —
-- this is Supabase's documented pattern for role-lookup helpers).
-- -----------------------------------------------------------------------------

create or replace function public.current_agency_id() returns uuid
language sql stable security definer set search_path = public as $$
  select agency_id from public.profiles where id = auth.uid();
$$;

create or replace function public.current_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_client_id() returns uuid
language sql stable security definer set search_path = public as $$
  select client_id from public.profiles where id = auth.uid();
$$;

-- True if the signed-in user is allowed to see the given client, based on
-- their role: owner -> any client in their agency; media_buyer -> only
-- assigned clients; client -> only their own client row.
create or replace function public.can_access_client(p_client_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select case public.current_role()
    when 'owner' then exists(
      select 1 from public.clients c
      where c.id = p_client_id and c.agency_id = public.current_agency_id()
    )
    when 'media_buyer' then exists(
      select 1 from public.client_assignments ca
      where ca.client_id = p_client_id and ca.profile_id = auth.uid()
    )
    when 'client' then p_client_id = public.current_client_id()
    else false
  end;
$$;

create or replace function public.client_id_for_ad_account(p_ad_account_id uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select client_id from public.ad_accounts where id = p_ad_account_id;
$$;

create or replace function public.client_id_for_campaign(p_campaign_id uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select public.client_id_for_ad_account(ad_account_id) from public.campaigns where id = p_campaign_id;
$$;

create or replace function public.client_id_for_ad_set(p_ad_set_id uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select public.client_id_for_campaign(campaign_id) from public.ad_sets where id = p_ad_set_id;
$$;

-- -----------------------------------------------------------------------------
-- agencies
-- -----------------------------------------------------------------------------
alter table public.agencies enable row level security;

create policy agencies_select on public.agencies
  for select using (id = public.current_agency_id());
-- No insert/update/delete policy: agency rows are only created by the
-- security-definer bootstrap_owner() function during first-run setup.

-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy profiles_select_self on public.profiles
  for select using (id = auth.uid());

create policy profiles_select_owner on public.profiles
  for select using (public.current_role() = 'owner' and agency_id = public.current_agency_id());

create policy profiles_update_self on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
-- No client-side insert policy: profile creation happens via
-- bootstrap_owner() (first owner) or the create-app-user Edge Function
-- (everyone else), both of which run with elevated privileges after
-- validating the caller server-side.

-- -----------------------------------------------------------------------------
-- clients
-- -----------------------------------------------------------------------------
alter table public.clients enable row level security;

create policy clients_select on public.clients
  for select using (public.can_access_client(id));

create policy clients_owner_insert on public.clients
  for insert with check (public.current_role() = 'owner' and agency_id = public.current_agency_id());

create policy clients_owner_update on public.clients
  for update using (public.current_role() = 'owner' and agency_id = public.current_agency_id())
  with check (agency_id = public.current_agency_id());

create policy clients_owner_delete on public.clients
  for delete using (public.current_role() = 'owner' and agency_id = public.current_agency_id());

-- -----------------------------------------------------------------------------
-- client_assignments
-- -----------------------------------------------------------------------------
alter table public.client_assignments enable row level security;

create policy client_assignments_select_owner on public.client_assignments
  for select using (
    public.current_role() = 'owner'
    and exists(select 1 from public.clients c where c.id = client_id and c.agency_id = public.current_agency_id())
  );

create policy client_assignments_select_self on public.client_assignments
  for select using (profile_id = auth.uid());

create policy client_assignments_owner_write on public.client_assignments
  for insert with check (
    public.current_role() = 'owner'
    and exists(select 1 from public.clients c where c.id = client_id and c.agency_id = public.current_agency_id())
  );

create policy client_assignments_owner_delete on public.client_assignments
  for delete using (
    public.current_role() = 'owner'
    and exists(select 1 from public.clients c where c.id = client_id and c.agency_id = public.current_agency_id())
  );

-- -----------------------------------------------------------------------------
-- meta_connections / ad_accounts / campaigns / ad_sets / ads / campaign_metrics
-- -----------------------------------------------------------------------------
alter table public.meta_connections enable row level security;
create policy meta_connections_owner on public.meta_connections
  for select using (public.current_role() = 'owner' and agency_id = public.current_agency_id());

alter table public.ad_accounts enable row level security;
create policy ad_accounts_select on public.ad_accounts
  for select using (
    (client_id is not null and public.can_access_client(client_id))
    or (
      client_id is null and public.current_role() = 'owner'
      and exists(select 1 from public.meta_connections mc where mc.id = connection_id and mc.agency_id = public.current_agency_id())
    )
  );

alter table public.campaigns enable row level security;
create policy campaigns_select on public.campaigns
  for select using (public.can_access_client(public.client_id_for_ad_account(ad_account_id)));

alter table public.ad_sets enable row level security;
create policy ad_sets_select on public.ad_sets
  for select using (public.can_access_client(public.client_id_for_campaign(campaign_id)));

alter table public.ads enable row level security;
create policy ads_select on public.ads
  for select using (public.can_access_client(public.client_id_for_ad_set(ad_set_id)));

alter table public.campaign_metrics enable row level security;
create policy campaign_metrics_select on public.campaign_metrics
  for select using (public.can_access_client(public.client_id_for_campaign(campaign_id)));

-- -----------------------------------------------------------------------------
-- daily_metrics / monthly_snapshots / alerts
-- (visible to owner, assigned media buyer, and the client themselves)
-- -----------------------------------------------------------------------------
alter table public.daily_metrics enable row level security;
create policy daily_metrics_select on public.daily_metrics
  for select using (public.can_access_client(client_id));

alter table public.monthly_snapshots enable row level security;
create policy monthly_snapshots_select on public.monthly_snapshots
  for select using (public.can_access_client(client_id));

alter table public.alerts enable row level security;
create policy alerts_select on public.alerts
  for select using (
    (client_id is not null and public.can_access_client(client_id))
    or (client_id is null and public.current_role() = 'owner')
  );

-- -----------------------------------------------------------------------------
-- commissions — financial data. Per docs/PRODUCT_SPEC.md § Roles, clients
-- must NEVER see commission figures, and media buyers get no financial
-- visibility either. Owner only.
-- -----------------------------------------------------------------------------
alter table public.commissions enable row level security;
create policy commissions_owner_only on public.commissions
  for select using (
    public.current_role() = 'owner'
    and exists(select 1 from public.clients c where c.id = client_id and c.agency_id = public.current_agency_id())
  );

-- -----------------------------------------------------------------------------
-- audit_logs — owner only, read-only from the client. Writes happen via
-- service-role backend code (e.g. the create-app-user Edge Function),
-- which bypasses RLS, so no insert policy is needed here.
-- -----------------------------------------------------------------------------
alter table public.audit_logs enable row level security;
create policy audit_logs_owner_select on public.audit_logs
  for select using (public.current_role() = 'owner' and agency_id = public.current_agency_id());

-- -----------------------------------------------------------------------------
-- Notes for whoever extends this later:
-- * Every table above now defaults to DENY for any operation without a
--   matching policy. Add narrowly-scoped insert/update/delete policies as
--   each feature (e.g. media buyer editing campaign notes) is actually
--   built — don't widen `using (true)` anywhere.
-- * Tables fed exclusively by backend sync jobs (ad_accounts, campaigns,
--   ad_sets, ads, campaign_metrics, daily_metrics) intentionally have no
--   client-side write policy; the sync job should run with the
--   service-role key, which bypasses RLS entirely.
-- =============================================================================
