-- Production-oriented schema blueprint.
-- Apply with migrations in the backend, not directly from the APK.

create table agencies (
  id uuid primary key,
  name text not null,
  currency text not null default 'EGP',
  created_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key,
  agency_id uuid not null references agencies(id),
  full_name text not null,
  role text not null check (role in ('owner','media_buyer','client')),
  client_id uuid,
  created_at timestamptz not null default now()
);

create table clients (
  id uuid primary key,
  agency_id uuid not null references agencies(id),
  company_name text not null,
  contact_name text,
  phone text,
  industry text,
  status text not null default 'active',
  start_date date,
  notes text,
  created_at timestamptz not null default now()
);

create table client_assignments (
  id uuid primary key,
  client_id uuid not null references clients(id),
  profile_id uuid not null references profiles(id),
  unique(client_id, profile_id)
);

create table meta_connections (
  id uuid primary key,
  agency_id uuid not null references agencies(id),
  owner_profile_id uuid not null references profiles(id),
  provider text not null default 'meta',
  status text not null default 'pending',
  external_user_id text,
  last_sync_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create table ad_accounts (
  id uuid primary key,
  connection_id uuid not null references meta_connections(id),
  client_id uuid references clients(id),
  external_account_id text not null,
  account_name text,
  currency text,
  status text,
  unique(connection_id, external_account_id)
);

create table campaigns (
  id uuid primary key,
  ad_account_id uuid not null references ad_accounts(id),
  external_id text not null,
  name text not null,
  status text,
  objective text,
  daily_budget numeric,
  lifetime_budget numeric,
  unique(ad_account_id, external_id)
);

create table ad_sets (
  id uuid primary key,
  campaign_id uuid not null references campaigns(id),
  external_id text not null,
  name text not null,
  status text,
  budget numeric,
  unique(campaign_id, external_id)
);

create table ads (
  id uuid primary key,
  ad_set_id uuid not null references ad_sets(id),
  external_id text not null,
  name text not null,
  status text,
  creative_id text,
  unique(ad_set_id, external_id)
);

create table daily_metrics (
  id uuid primary key,
  client_id uuid not null references clients(id),
  metric_date date not null,
  spend numeric not null default 0,
  sales numeric not null default 0,
  orders integer not null default 0,
  leads integer not null default 0,
  impressions bigint not null default 0,
  clicks bigint not null default 0,
  unique(client_id, metric_date)
);

create table campaign_metrics (
  id uuid primary key,
  campaign_id uuid not null references campaigns(id),
  metric_date date not null,
  spend numeric not null default 0,
  sales numeric not null default 0,
  orders integer not null default 0,
  impressions bigint not null default 0,
  clicks bigint not null default 0,
  unique(campaign_id, metric_date)
);

create table commissions (
  id uuid primary key,
  client_id uuid not null references clients(id),
  period_start date not null,
  period_end date not null,
  spend_base numeric not null default 0,
  sales_base numeric not null default 0,
  spend_rate numeric not null default 0.20,
  sales_rate numeric not null default 0.10,
  spend_commission numeric not null default 0,
  sales_commission numeric not null default 0,
  total_commission numeric not null default 0,
  paid_amount numeric not null default 0,
  unique(client_id, period_start, period_end)
);

create table monthly_snapshots (
  id uuid primary key,
  client_id uuid not null references clients(id),
  month_start date not null,
  spend numeric not null default 0,
  sales numeric not null default 0,
  orders integer not null default 0,
  roas numeric not null default 0,
  commission numeric not null default 0,
  health_score integer,
  unique(client_id, month_start)
);

create table alerts (
  id uuid primary key,
  client_id uuid references clients(id),
  severity text not null,
  category text not null,
  title text not null,
  message text not null,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

create table audit_logs (
  id uuid primary key,
  agency_id uuid not null references agencies(id),
  actor_profile_id uuid references profiles(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- Production deployment must add RLS policies that restrict every tenant
-- by agency_id and every client user to their own client_id.
