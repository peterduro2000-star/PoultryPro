-- Secure licensing foundation for TailorPro.
-- This migration moves license issuance and activation trust to Supabase.

create extension if not exists pgcrypto;

create table if not exists public.tier_config (
  tier text primary key,
  client_limit integer not null check (client_limit >= 0),
  duration_days integer,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tier_config_tier_check check (tier in ('free', 'pro'))
);

insert into public.tier_config (tier, client_limit, duration_days)
values
  ('free', 5, null),
  ('pro', 500, null)
on conflict (tier) do update
set client_limit = excluded.client_limit,
    duration_days = excluded.duration_days,
    is_active = true,
    updated_at = now();

create table if not exists public.license_keys (
  id uuid primary key default gen_random_uuid(),
  key_code text unique not null,
  tier text not null,
  issued_to_user_id uuid references auth.users(id),
  created_by_user_id uuid references auth.users(id),
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  expires_at timestamptz,
  is_revoked boolean not null default false,
  redemption_count integer not null default 0,
  max_redemptions integer not null default 1,
  metadata jsonb not null default '{}'::jsonb,
  constraint license_keys_tier_check check (tier in ('free', 'pro')),
  constraint license_keys_redemption_check check (redemption_count >= 0 and max_redemptions > 0)
);

create table if not exists public.user_licenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) unique,
  license_key_id uuid references public.license_keys(id),
  tier text not null,
  activated_at timestamptz not null default now(),
  expires_at timestamptz,
  client_limit integer not null check (client_limit >= 0),
  clients_used integer not null default 0 check (clients_used >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_licenses_tier_check check (tier in ('free', 'pro'))
);

create index if not exists idx_license_keys_issued_to_user_id
  on public.license_keys (issued_to_user_id);

create index if not exists idx_user_licenses_user_id
  on public.user_licenses (user_id);

create table if not exists public.license_audit_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  action text not null,
  tier text,
  created_at timestamptz not null default now(),
  details jsonb not null default '{}'::jsonb
);

create index if not exists idx_license_audit_log_user_id
  on public.license_audit_log (user_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_tier_config_updated_at on public.tier_config;
create trigger trg_tier_config_updated_at
before update on public.tier_config
for each row
execute function public.set_updated_at();

drop trigger if exists trg_user_licenses_updated_at on public.user_licenses;
create trigger trg_user_licenses_updated_at
before update on public.user_licenses
for each row
execute function public.set_updated_at();

alter table public.license_keys enable row level security;
alter table public.user_licenses enable row level security;
alter table public.license_audit_log enable row level security;
alter table public.tier_config enable row level security;

drop policy if exists "Users can view their own issued license keys" on public.license_keys;
create policy "Users can view their own issued license keys"
on public.license_keys
for select
using (auth.uid() = issued_to_user_id);

drop policy if exists "Users can only see their own license" on public.user_licenses;
create policy "Users can only see their own license"
on public.user_licenses
for select
using (auth.uid() = user_id);

drop policy if exists "Users cannot write licenses directly" on public.user_licenses;
create policy "Users cannot write licenses directly"
on public.user_licenses
for all
using (false)
with check (false);

drop policy if exists "Users can read their own audit log" on public.license_audit_log;
create policy "Users can read their own audit log"
on public.license_audit_log
for select
using (auth.uid() = user_id);

drop policy if exists "Users can read tier config" on public.tier_config;
create policy "Users can read tier config"
on public.tier_config
for select
using (true);

create or replace function public.activate_license_key(p_key_code text)
returns table (
  success boolean,
  message text,
  tier text,
  client_limit integer,
  clients_used integer,
  expires_at timestamptz,
  is_active boolean,
  license_key text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_license_key public.license_keys%rowtype;
  v_tier public.tier_config%rowtype;
begin
  if v_user_id is null then
    return query select false, 'Authentication required'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  select *
  into v_license_key
  from public.license_keys
  where key_code = trim(p_key_code)
    and is_revoked = false
    and (
      issued_to_user_id is null
      or issued_to_user_id = v_user_id
    )
  limit 1;

  if v_license_key.id is null then
    return query select false, 'Invalid license key'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  if v_license_key.activated_at is not null or v_license_key.redemption_count >= v_license_key.max_redemptions then
    return query select false, 'License key already activated'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  if v_license_key.expires_at is not null and v_license_key.expires_at <= now() then
    return query select false, 'License key has expired'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  select *
  into v_tier
  from public.tier_config tc
  where tc.tier = v_license_key.tier
    and tc.is_active = true
  limit 1;

  if v_tier.tier is null then
    return query select false, 'License tier is not available'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  insert into public.user_licenses (
    user_id,
    license_key_id,
    tier,
    activated_at,
    expires_at,
    client_limit,
    clients_used,
    is_active
  )
  values (
    v_user_id,
    v_license_key.id,
    v_license_key.tier,
    now(),
    v_license_key.expires_at,
    v_tier.client_limit,
    0,
    true
  )
  on conflict (user_id) do update
  set license_key_id = excluded.license_key_id,
      tier = excluded.tier,
      activated_at = excluded.activated_at,
      expires_at = excluded.expires_at,
      client_limit = excluded.client_limit,
      clients_used = least(public.user_licenses.clients_used, excluded.client_limit),
      is_active = true,
      updated_at = now();

  update public.license_keys
  set activated_at = now(),
      redemption_count = redemption_count + 1,
      issued_to_user_id = coalesce(issued_to_user_id, v_user_id)
  where id = v_license_key.id;

  insert into public.license_audit_log (user_id, action, tier, details)
  values (
    v_user_id,
    'activated',
    v_license_key.tier,
    jsonb_build_object('key_code', v_license_key.key_code, 'license_key_id', v_license_key.id)
  );

  return query
  select
    true,
    'License activated successfully'::text,
    v_license_key.tier,
    v_tier.client_limit,
    0,
    v_license_key.expires_at,
    true,
    v_license_key.key_code;
end;
$$;

create or replace function public.create_free_license()
returns table (
  success boolean,
  message text,
  tier text,
  client_limit integer,
  clients_used integer,
  expires_at timestamptz,
  is_active boolean,
  license_key text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_tier public.tier_config%rowtype;
begin
  if v_user_id is null then
    return query select false, 'Authentication required'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  select *
  into v_tier
  from public.tier_config tc
  where tc.tier = 'free'
    and tc.is_active = true
  limit 1;

  if v_tier.tier is null then
    return query select false, 'Free tier is not configured'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  insert into public.user_licenses (
    user_id,
    license_key_id,
    tier,
    activated_at,
    expires_at,
    client_limit,
    clients_used,
    is_active
  )
  values (
    v_user_id,
    null,
    'free',
    now(),
    null,
    v_tier.client_limit,
    0,
    true
  )
  on conflict (user_id) do nothing;

  insert into public.license_audit_log (user_id, action, tier, details)
  values (
    v_user_id,
    'created',
    'free',
    jsonb_build_object('source', 'create_free_license')
  );

  return query
  select
    true,
    'Free license ensured'::text,
    'free'::text,
    v_tier.client_limit,
    0,
    null::timestamptz,
    true,
    null::text;
end;
$$;

create or replace function public.get_current_license()
returns table (
  id uuid,
  tier text,
  client_limit integer,
  clients_used integer,
  expires_at timestamptz,
  is_active boolean,
  license_key text,
  activated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return;
  end if;

  return query
  select
    ul.id,
    ul.tier,
    ul.client_limit,
    ul.clients_used,
    ul.expires_at,
    (
      ul.is_active
      and (
        ul.expires_at is null
        or ul.expires_at > now()
      )
    ) as is_active,
    lk.key_code as license_key,
    ul.activated_at
  from public.user_licenses ul
  left join public.license_keys lk on lk.id = ul.license_key_id
  where ul.user_id = v_user_id
  limit 1;
end;
$$;

create or replace function public.increment_license_client_count()
returns table (
  success boolean,
  message text,
  clients_used integer,
  client_limit integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_license public.user_licenses%rowtype;
begin
  if v_user_id is null then
    return query select false, 'Authentication required'::text, null::integer, null::integer;
    return;
  end if;

  select *
  into v_license
  from public.user_licenses
  where user_id = v_user_id
  limit 1;

  if v_license.id is null then
    return query select false, 'No active license found'::text, null::integer, null::integer;
    return;
  end if;

  if not v_license.is_active or (v_license.expires_at is not null and v_license.expires_at <= now()) then
    return query select false, 'License is inactive or expired'::text, v_license.clients_used, v_license.client_limit;
    return;
  end if;

  if v_license.clients_used >= v_license.client_limit then
    return query select false, 'Client limit reached'::text, v_license.clients_used, v_license.client_limit;
    return;
  end if;

  update public.user_licenses
  set clients_used = clients_used + 1,
      updated_at = now()
  where id = v_license.id;

  insert into public.license_audit_log (user_id, action, tier, details)
  values (
    v_user_id,
    'client_incremented',
    v_license.tier,
    jsonb_build_object('previous_clients_used', v_license.clients_used, 'new_clients_used', v_license.clients_used + 1)
  );

  return query select true, 'Client count updated'::text, v_license.clients_used + 1, v_license.client_limit;
end;
$$;

create or replace function public.decrement_license_client_count()
returns table (
  success boolean,
  message text,
  clients_used integer,
  client_limit integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_license public.user_licenses%rowtype;
  v_new_count integer;
begin
  if v_user_id is null then
    return query select false, 'Authentication required'::text, null::integer, null::integer;
    return;
  end if;

  select *
  into v_license
  from public.user_licenses
  where user_id = v_user_id
  limit 1;

  if v_license.id is null then
    return query select false, 'No active license found'::text, null::integer, null::integer;
    return;
  end if;

  v_new_count := greatest(v_license.clients_used - 1, 0);

  update public.user_licenses
  set clients_used = v_new_count,
      updated_at = now()
  where id = v_license.id;

  insert into public.license_audit_log (user_id, action, tier, details)
  values (
    v_user_id,
    'client_decremented',
    v_license.tier,
    jsonb_build_object('previous_clients_used', v_license.clients_used, 'new_clients_used', v_new_count)
  );

  return query select true, 'Client count updated'::text, v_new_count, v_license.client_limit;
end;
$$;

revoke all on public.license_keys from anon, authenticated;
revoke all on public.user_licenses from anon, authenticated;
revoke all on public.license_audit_log from anon, authenticated;

grant select on public.tier_config to authenticated;
grant execute on function public.activate_license_key(text) to authenticated;
grant execute on function public.create_free_license() to authenticated;
grant execute on function public.get_current_license() to authenticated;
grant execute on function public.increment_license_client_count() to authenticated;
grant execute on function public.decrement_license_client_count() to authenticated;
