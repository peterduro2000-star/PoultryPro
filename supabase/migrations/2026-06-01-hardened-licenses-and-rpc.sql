-- Migration: Hardened licenses schema and idempotent RPC
-- Created: 2026-06-01

-- 1) licenses table (single row per user, hardened)
create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,

  tier text not null check (tier in ('free','pro')) default 'free',

  activated_at timestamptz,
  expires_at timestamptz,

  provider text,
  provider_order_id text unique,
  provider_purchase_token text unique,
  provider_subscription_id text,

  client_limit int not null default 5,
  clients_used int not null default 0,

  is_active boolean default true,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_licenses_user_id on public.licenses (user_id);

-- 2) license_events table (audit + diagnostics)
create table if not exists public.license_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  event_type text not null,
  payload jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_license_events_user_id on public.license_events (user_id);

alter table public.licenses enable row level security;
alter table public.license_events enable row level security;

drop policy if exists "Users can read their own license" on public.licenses;
create policy "Users can read their own license"
on public.licenses
for select
using (auth.uid() = user_id);

drop policy if exists "Users cannot write licenses directly" on public.licenses;
create policy "Users cannot write licenses directly"
on public.licenses
for all
using (false)
with check (false);

drop policy if exists "Users can read their own license events" on public.license_events;
create policy "Users can read their own license events"
on public.license_events
for select
using (auth.uid() = user_id);

-- 3) Idempotent RPC: activate_license_from_iap
-- DB-only, atomic, idempotent. Does NOT call external services.
create or replace function public.activate_license_from_iap(
  p_user_id uuid,
  p_tier text,
  p_expires_at timestamptz,
  p_provider text,
  p_order_id text,
  p_purchase_token text,
  p_subscription_id text
) returns public.licenses
language plpgsql
security definer
as $$
declare
  existing public.licenses%rowtype;
  evt jsonb;
begin

  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  if p_tier is null then
    p_tier := 'pro';
  end if;

  evt := jsonb_build_object(
    'tier', p_tier,
    'expires_at', to_jsonb(p_expires_at),
    'provider', p_provider,
    'order_id', p_order_id,
    'purchase_token', p_purchase_token,
    'subscription_id', p_subscription_id,
    'ts', now()
  );

  -- Try to insert audit event. Use unique constraints on provider fields
  -- to help with idempotency at the event level if desired upstream.
  begin
    insert into public.license_events(user_id, event_type, payload)
    values (p_user_id, 'activation', evt);
  exception when others then
    -- swallow; events are best-effort for diagnostics
    null;
  end;

  -- Idempotency: if this purchase token already exists, return existing
  if p_purchase_token is not null then
    select * into existing from public.licenses where provider_purchase_token = p_purchase_token;
    if found then
      return existing;
    end if;
  end if;

  -- Lock any existing license row for this user to avoid races
  select * into existing from public.licenses where user_id = p_user_id for update;

  if not found then
    insert into public.licenses (
      user_id, tier, activated_at, expires_at, provider, provider_order_id,
      provider_purchase_token, provider_subscription_id, client_limit, clients_used, is_active, created_at, updated_at
    ) values (
      p_user_id, p_tier, now(), p_expires_at, p_provider, p_order_id,
      p_purchase_token, p_subscription_id,
      case when p_tier = 'pro' then 500 else 5 end,
      0, true, now(), now()
    ) returning * into existing;
    return existing;
  else
    -- If order_id/purchase_token already applied to this user's license, return
    if existing.provider_order_id is not null and p_order_id is not null and existing.provider_order_id = p_order_id then
      return existing;
    end if;
    if existing.provider_purchase_token is not null and p_purchase_token is not null and existing.provider_purchase_token = p_purchase_token then
      return existing;
    end if;

    -- Only update if this activation appears newer or extends expiry
    if p_expires_at is not null and (existing.expires_at is null or p_expires_at > existing.expires_at) then
      update public.licenses set
        tier = p_tier,
        activated_at = now(),
        expires_at = p_expires_at,
        provider = p_provider,
        provider_order_id = p_order_id,
        provider_purchase_token = p_purchase_token,
        provider_subscription_id = p_subscription_id,
        client_limit = case when p_tier = 'pro' then 500 else 5 end,
        is_active = true,
        updated_at = now()
      where user_id = p_user_id
      returning * into existing;

      return existing;
    else
      -- Incoming activation is not newer; return current row
      return existing;
    end if;
  end if;
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
  v_license public.licenses%rowtype;
begin
  if v_user_id is null then
    return query select false, 'Authentication required'::text, null::text, null::integer, null::integer, null::timestamptz, null::boolean, null::text;
    return;
  end if;

  insert into public.licenses (
    user_id, tier, activated_at, expires_at, client_limit, clients_used, is_active, created_at, updated_at
  )
  values (
    v_user_id, 'free', now(), null, 5, 0, true, now(), now()
  )
  on conflict (user_id) do update
  set updated_at = public.licenses.updated_at
  returning * into v_license;

  return query
  select
    true,
    'Free license ensured'::text,
    v_license.tier,
    v_license.client_limit,
    v_license.clients_used,
    v_license.expires_at,
    v_license.is_active,
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
    l.id,
    l.tier,
    l.client_limit,
    l.clients_used,
    l.expires_at,
    (
      l.is_active
      and (
        l.expires_at is null
        or l.expires_at > now()
      )
    ) as is_active,
    null::text as license_key,
    l.activated_at
  from public.licenses l
  where l.user_id = v_user_id
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
  v_license public.licenses%rowtype;
begin
  if v_user_id is null then
    return query select false, 'Authentication required'::text, null::integer, null::integer;
    return;
  end if;

  select *
  into v_license
  from public.licenses
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

  update public.licenses
  set clients_used = clients_used + 1,
      updated_at = now()
  where id = v_license.id
  returning * into v_license;

  return query select true, 'Client count updated'::text, v_license.clients_used, v_license.client_limit;
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
  v_license public.licenses%rowtype;
begin
  if v_user_id is null then
    return query select false, 'Authentication required'::text, null::integer, null::integer;
    return;
  end if;

  select *
  into v_license
  from public.licenses
  where user_id = v_user_id
  limit 1;

  if v_license.id is null then
    return query select false, 'No active license found'::text, null::integer, null::integer;
    return;
  end if;

  update public.licenses
  set clients_used = greatest(clients_used - 1, 0),
      updated_at = now()
  where id = v_license.id
  returning * into v_license;

  return query select true, 'Client count updated'::text, v_license.clients_used, v_license.client_limit;
end;
$$;

grant execute on function public.activate_license_from_iap(uuid, text, timestamptz, text, text, text, text) to service_role;
grant execute on function public.create_free_license() to authenticated;
grant execute on function public.get_current_license() to authenticated;
grant execute on function public.increment_license_client_count() to authenticated;
grant execute on function public.decrement_license_client_count() to authenticated;
