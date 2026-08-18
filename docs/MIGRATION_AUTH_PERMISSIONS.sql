
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists permissions jsonb not null default '{}'::jsonb;
create unique index if not exists profiles_username_unique on public.profiles(lower(username));

create or replace function public.bootstrap_owner(p_username text)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare aid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists(select 1 from public.profiles) then raise exception 'owner already initialized'; end if;
  insert into public.agencies(name) values ('poost') returning id into aid;
  insert into public.profiles(id, agency_id, full_name, username, role, permissions)
  values(auth.uid(), aid, p_username, p_username, 'owner',
         '{"dashboard":true,"clients":true,"campaigns":true,"finance":true,"reports":true,"meta":true,"users":true,"settings":true}'::jsonb);
  return aid;
end $$;

-- The create-app-user Edge Function performs privileged creation of auth users
-- and profile rows after validating the caller is an owner.
