-- Add private verified-phone discovery, contacts, direct messaging, and its rate limit.
-- All phone-number storage remains outside public profiles and client writes are denied.

create table if not exists public.user_phone_numbers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_e164 text not null unique,
  verified_at timestamptz not null,
  discoverable boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint user_phone_numbers_e164_format check (phone_e164 ~ '^[+][1-9][0-9]{7,14}$')
);

alter table public.user_phone_numbers enable row level security;
revoke all on table public.user_phone_numbers from public, anon, authenticated;
grant select on table public.user_phone_numbers to authenticated, service_role;

drop policy if exists "Users can read their own verified phone" on public.user_phone_numbers;
create policy "Users can read their own verified phone"
  on public.user_phone_numbers for select to authenticated
  using ((select auth.uid()) = user_id);

-- Keep this table synchronized only from confirmed Supabase Auth phone data.
create or replace function public.sync_hicall_user_phone_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.phone is not null and new.phone_confirmed_at is not null then
    insert into public.user_phone_numbers (user_id, phone_e164, verified_at, discoverable, updated_at)
    values (new.id, new.phone, new.phone_confirmed_at, false, pg_catalog.clock_timestamp())
    on conflict (user_id) do update
      set phone_e164 = excluded.phone_e164,
          verified_at = excluded.verified_at,
          discoverable = case
            when public.user_phone_numbers.phone_e164 = excluded.phone_e164
              then public.user_phone_numbers.discoverable
            else false
          end,
          updated_at = pg_catalog.clock_timestamp();
  else
    -- A removed or newly unverified number must no longer be discoverable.
    delete from public.user_phone_numbers where user_id = new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_hicall_user_phone_number() from public, anon, authenticated, service_role;

drop trigger if exists on_auth_user_phone_changed_hicall on auth.users;
create trigger on_auth_user_phone_changed_hicall
after insert or update of phone, phone_confirmed_at on auth.users
for each row execute procedure public.sync_hicall_user_phone_number();

-- Preserve previously confirmed numbers for the owner's profile, but keep them hidden
-- from search until the owner explicitly opts in. Verification for account security
-- alone is not consent to phone-number discovery.
insert into public.user_phone_numbers (user_id, phone_e164, verified_at, discoverable, updated_at)
select id, phone, phone_confirmed_at, false, pg_catalog.clock_timestamp()
from auth.users
where phone is not null and phone_confirmed_at is not null
on conflict (user_id) do update
      set phone_e164 = excluded.phone_e164,
          verified_at = excluded.verified_at,
      discoverable = case
        when public.user_phone_numbers.phone_e164 = excluded.phone_e164
          then public.user_phone_numbers.discoverable
        else false
      end,
      updated_at = pg_catalog.clock_timestamp();

create table if not exists public.user_contacts (
  owner_id uuid not null references auth.users(id) on delete cascade,
  contact_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, contact_id),
  constraint user_contacts_no_self check (owner_id <> contact_id)
);

create index if not exists user_contacts_contact_idx
  on public.user_contacts (contact_id, owner_id);

-- Policy helper can inspect both block directions, but only for a pair containing
-- the caller. Keep it outside PostgREST's default-exposed public schema.
create schema if not exists hicall_private;
revoke all on schema hicall_private from public, anon, authenticated;
grant usage on schema hicall_private to authenticated;

create or replace function hicall_private.users_block_each_other(p_user_a uuid, p_user_b uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or (auth.uid() <> p_user_a and auth.uid() <> p_user_b)
     or p_user_a is null or p_user_b is null then
    return true;
  end if;

  return exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_user_a and b.blocked_id = p_user_b)
       or (b.blocker_id = p_user_b and b.blocked_id = p_user_a)
  );
end;
$$;
revoke all on function hicall_private.users_block_each_other(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function hicall_private.users_block_each_other(uuid, uuid) to authenticated;

alter table public.user_contacts enable row level security;
revoke all on table public.user_contacts from public, anon, authenticated;
grant select, insert, delete on table public.user_contacts to authenticated;

drop policy if exists "Owners can read unblocked contacts" on public.user_contacts;
create policy "Owners can read unblocked contacts"
  on public.user_contacts for select to authenticated
  using (
    owner_id = (select auth.uid())
    and not hicall_private.users_block_each_other(owner_id, contact_id)
  );

drop policy if exists "Owners can add unblocked contacts" on public.user_contacts;
create policy "Owners can add unblocked contacts"
  on public.user_contacts for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and owner_id <> contact_id
    and not hicall_private.users_block_each_other(owner_id, contact_id)
  );

drop policy if exists "Owners can remove unblocked contacts" on public.user_contacts;
create policy "Owners can remove unblocked contacts"
  on public.user_contacts for delete to authenticated
  using (owner_id = (select auth.uid()));

create table if not exists public.direct_conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint direct_conversations_canonical_pair check (user_a < user_b),
  constraint direct_conversations_pair_unique unique (user_a, user_b)
);

alter table public.direct_conversations enable row level security;
revoke all on table public.direct_conversations from public, anon, authenticated;
grant select, insert on table public.direct_conversations to authenticated;

drop policy if exists "Conversation participants can read direct conversations" on public.direct_conversations;
create policy "Conversation participants can read direct conversations"
  on public.direct_conversations for select to authenticated
  using (
    ((select auth.uid()) = user_a or (select auth.uid()) = user_b)
    and not hicall_private.users_block_each_other(user_a, user_b)
  );

drop policy if exists "Members can create conversations with unblocked contacts" on public.direct_conversations;
create policy "Members can create conversations with unblocked contacts"
  on public.direct_conversations for insert to authenticated
  with check (
    ((select auth.uid()) = user_a or (select auth.uid()) = user_b)
    and exists (
      select 1 from public.user_contacts c
      where c.owner_id = (select auth.uid())
        and c.contact_id = case
          when (select auth.uid()) = user_a then user_b
          else user_a
        end
    )
    and not hicall_private.users_block_each_other(user_a, user_b)
  );

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint messages_body_valid check (
    char_length(body) between 1 and 4000 and char_length(btrim(body)) > 0
  )
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);

alter table public.messages enable row level security;
revoke all on table public.messages from public, anon, authenticated;
grant select on table public.messages to authenticated;
grant insert (conversation_id, sender_id, body) on table public.messages to authenticated;

drop policy if exists "Conversation participants can read messages" on public.messages;
create policy "Conversation participants can read messages"
  on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.direct_conversations c
      where c.id = messages.conversation_id
        and ((select auth.uid()) = c.user_a or (select auth.uid()) = c.user_b)
        and not hicall_private.users_block_each_other(c.user_a, c.user_b)
    )
  );

drop policy if exists "Participants can send their own messages" on public.messages;
create policy "Participants can send their own messages"
  on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1 from public.direct_conversations c
      where c.id = messages.conversation_id
        and ((select auth.uid()) = c.user_a or (select auth.uid()) = c.user_b)
        and not hicall_private.users_block_each_other(c.user_a, c.user_b)
    )
  );

-- Store timestamp-only events. Per-user advisory locking makes check-and-insert atomic.
create table if not exists public.phone_search_rate_limits (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  requested_at timestamptz not null
);

create index if not exists phone_search_rate_limits_user_time_idx
  on public.phone_search_rate_limits (user_id, requested_at desc);

alter table public.phone_search_rate_limits enable row level security;
revoke all on table public.phone_search_rate_limits from public, anon, authenticated, service_role;
revoke all on sequence public.phone_search_rate_limits_id_seq from public, anon, authenticated, service_role;

create or replace function public.consume_phone_search_rate_limit(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_time timestamptz;
  recent_count integer;
begin
  if p_user_id is null then
    return false;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );
  request_time := pg_catalog.clock_timestamp();

  delete from public.phone_search_rate_limits
  where user_id = p_user_id
    and requested_at <= request_time - interval '60 seconds';

  select pg_catalog.count(*)::integer into recent_count
  from public.phone_search_rate_limits
  where user_id = p_user_id
    and requested_at > request_time - interval '60 seconds';

  if recent_count >= 10 then
    return false;
  end if;

  insert into public.phone_search_rate_limits (user_id, requested_at)
  values (p_user_id, request_time);
  return true;
end;
$$;
revoke all on function public.consume_phone_search_rate_limit(uuid) from public, anon, authenticated;
grant execute on function public.consume_phone_search_rate_limit(uuid) to service_role;

-- Add messages to the existing Supabase Realtime publication once, when available.
do $$
begin
  if exists (select 1 from pg_catalog.pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_catalog.pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'messages'
     ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
