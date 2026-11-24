-- Device-specific FCM tokens used only by authenticated call participants.
create table if not exists public.call_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null unique,
  platform text not null default 'android' check (platform in ('android')),
  updated_at timestamptz not null default now()
);

create index if not exists call_device_tokens_user_id_idx
  on public.call_device_tokens (user_id);

alter table public.call_device_tokens enable row level security;

create policy "Users can read their own call device tokens"
  on public.call_device_tokens for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can register their own call device tokens"
  on public.call_device_tokens for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own call device tokens"
  on public.call_device_tokens for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can remove their own call device tokens"
  on public.call_device_tokens for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.call_device_tokens to authenticated;
