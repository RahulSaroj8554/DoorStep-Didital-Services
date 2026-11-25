-- PrintDesk Supabase setup. Run this entire file in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  access_token text not null unique,
  customer_name text not null,
  customer_phone text not null,
  fulfillment text not null check (fulfillment in ('pickup','delivery')),
  delivery_address text,
  payment_method text not null check (payment_method in ('cash','online')),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed')),
  payment_reference text,
  status text not null default 'pending' check (status in ('pending','printing','printed','ready','completed','cancelled')),
  page_count integer not null check (page_count > 0),
  total_amount integer not null check (total_amount >= 0),
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.orders enable row level security;
-- Anyone can submit a new order. Customers cannot list or read orders directly.
drop policy if exists "public can create orders" on public.orders;
create policy "public can create orders" on public.orders for insert to anon, authenticated with check (true);
drop policy if exists "admins can read orders" on public.orders;
create policy "admins can read orders" on public.orders for select to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists "admins can update orders" on public.orders;
create policy "admins can update orders" on public.orders for update to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin') with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Customer order lookup by unguessable access token. Only returns the matching order.
create or replace function public.get_order_by_token(p_token text)
returns setof public.orders language sql security definer set search_path = public
as $$ select * from public.orders where access_token = p_token limit 1; $$;
revoke all on function public.get_order_by_token(text) from public;
grant execute on function public.get_order_by_token(text) to anon, authenticated;

-- Private bucket for customer documents.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('printdesk-orders', 'printdesk-orders', false, 20971520, array['application/pdf','image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = false, file_size_limit = 20971520;
drop policy if exists "customers can upload print files" on storage.objects;
create policy "customers can upload print files" on storage.objects for insert to anon, authenticated with check (bucket_id = 'printdesk-orders');
drop policy if exists "admins can read print files" on storage.objects;
create policy "admins can read print files" on storage.objects for select to authenticated using (bucket_id = 'printdesk-orders' and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Enforce the fixed ₹10/page price and prevent clients marking their own orders paid/completed.
create or replace function public.validate_printdesk_order()
returns trigger language plpgsql set search_path = public
as $$
declare calculated_pages integer; calculated_total integer;
begin
  if jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) < 1 or jsonb_array_length(new.items) > 10 then
    raise exception 'An order must contain between 1 and 10 files';
  end if;
  select coalesce(sum((x->>'pages')::integer * (x->>'copies')::integer),0)
    into calculated_pages from jsonb_array_elements(new.items) x;
  if exists (select 1 from jsonb_array_elements(new.items) x where coalesce((x->>'pages')::integer,0) < 1 or coalesce((x->>'pages')::integer,0) > 9999 or coalesce((x->>'copies')::integer,0) < 1 or coalesce((x->>'copies')::integer,0) > 99 or coalesce(x->>'storage_path','') = '') then
    raise exception 'Invalid order file details';
  end if;
  calculated_total := calculated_pages * 10;
  if new.page_count <> calculated_pages or new.total_amount <> calculated_total then
    raise exception 'Order total must equal ₹10 per printed page';
  end if;
  new.status := 'pending';
  new.payment_status := 'pending';
  new.payment_reference := null;
  return new;
end; $$;
drop trigger if exists validate_printdesk_order_before_insert on public.orders;
create trigger validate_printdesk_order_before_insert before insert on public.orders
for each row execute function public.validate_printdesk_order();
