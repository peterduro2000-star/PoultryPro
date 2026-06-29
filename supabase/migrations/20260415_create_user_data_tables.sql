-- Create tables for user data sync with Supabase

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  phone text not null,
  gender text not null,
  email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customers_user_phone_unique unique(user_id, phone)
);

create table if not exists public.measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  measurement_type text not null,
  measurements jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  order_number text not null,
  order_title text not null,
  status text not null,
  stage text,
  total_amount real not null,
  paid_amount real default 0,
  created_at timestamptz not null default now(),
  delivery_date text not null,
  actual_delivery_date text,
  notes text,
  measurement_id uuid references public.measurements(id) on delete set null,
  item_type text,
  quantity integer default 1,
  fabric_details text,
  updated_at timestamptz not null default now(),
  constraint orders_user_ordernumber_unique unique(user_id, order_number)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  amount real not null,
  payment_method text not null,
  payment_date text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create indexes for better query performance
create index if not exists idx_customers_user_id on public.customers(user_id);
create index if not exists idx_customers_phone on public.customers(user_id, phone);
create index if not exists idx_measurements_user_id on public.measurements(user_id);
create index if not exists idx_measurements_customer_id on public.measurements(customer_id);
create index if not exists idx_orders_user_id on public.orders(user_id);
create index if not exists idx_orders_customer_id on public.orders(customer_id);
create index if not exists idx_orders_status on public.orders(user_id, status);
create index if not exists idx_payments_user_id on public.payments(user_id);
create index if not exists idx_payments_order_id on public.payments(order_id);
create index if not exists idx_payments_customer_id on public.payments(customer_id);

-- Enable Row Level Security
alter table public.customers enable row level security;
alter table public.measurements enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;

-- Create RLS policies (users can only see their own data)
create policy "Users can view their own customers" on public.customers
  for select using (auth.uid() = user_id);

create policy "Users can insert their own customers" on public.customers
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own customers" on public.customers
  for update using (auth.uid() = user_id);

create policy "Users can delete their own customers" on public.customers
  for delete using (auth.uid() = user_id);

create policy "Users can view their own measurements" on public.measurements
  for select using (auth.uid() = user_id);

create policy "Users can insert their own measurements" on public.measurements
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own measurements" on public.measurements
  for update using (auth.uid() = user_id);

create policy "Users can delete their own measurements" on public.measurements
  for delete using (auth.uid() = user_id);

create policy "Users can view their own orders" on public.orders
  for select using (auth.uid() = user_id);

create policy "Users can insert their own orders" on public.orders
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own orders" on public.orders
  for update using (auth.uid() = user_id);

create policy "Users can delete their own orders" on public.orders
  for delete using (auth.uid() = user_id);

create policy "Users can view their own payments" on public.payments
  for select using (auth.uid() = user_id);

create policy "Users can insert their own payments" on public.payments
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own payments" on public.payments
  for update using (auth.uid() = user_id);

create policy "Users can delete their own payments" on public.payments
  for delete using (auth.uid() = user_id);
