-- HiCALL initial schema. Apply only to a dedicated HiCALL Supabase project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text not null default '',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[A-Za-z0-9_]{3,24}$')
);

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username));

create table if not exists public.call_sessions (
  id uuid primary key default gen_random_uuid(),
  room_name text not null unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  call_type text not null check (call_type in ('audio', 'video')),
  call_scope text not null check (call_scope in ('direct', 'group')),
  status text not null default 'ringing'
    check (status in ('ringing', 'active', 'ended', 'declined', 'missed', 'cancelled')),
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz,
  expires_at timestamptz not null
);

create index if not exists call_sessions_created_by_created_at_idx
  on public.call_sessions (created_by, created_at desc);

create table if not exists public.call_participants (
  call_id uuid not null references public.call_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  participant_role text not null default 'member'
    check (participant_role in ('host', 'member')),
  invited_at timestamptz not null default now(),
  joined_at timestamptz,
  left_at timestamptz,
  primary key (call_id, user_id)
);

create index if not exists call_participants_user_call_idx
  on public.call_participants (user_id, call_id);

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('harassment', 'spam', 'impersonation', 'safety', 'other')),
  details text not null default '' check (char_length(details) <= 2000),
  created_at timestamptz not null default now(),
  constraint user_reports_no_self check (reporter_id <> reported_id)
);

alter table public.profiles enable row level security;
alter table public.call_sessions enable row level security;
alter table public.call_participants enable row level security;
alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;

-- Only authenticated users can discover public profile fields. No email/phone columns exist here.
create policy "Authenticated users can view profiles"
  on public.profiles for select to authenticated
  using (true);

create policy "Users can create their own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Call records are created/changed only by trusted Edge Functions using server-side credentials.
create policy "Call members can read their call sessions"
  on public.call_sessions for select to authenticated
  using (
    exists (
      select 1 from public.call_participants cp
      where cp.call_id = call_sessions.id
        and cp.user_id = (select auth.uid())
    )
  );

-- A user can read only their own participant row. Participant lists and mutations are server mediated.
create policy "Users can read their own call participation"
  on public.call_participants for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can view blocks they created"
  on public.user_blocks for select to authenticated
  using ((select auth.uid()) = blocker_id);

create policy "Users can block accounts"
  on public.user_blocks for insert to authenticated
  with check ((select auth.uid()) = blocker_id);

create policy "Users can unblock accounts"
  on public.user_blocks for delete to authenticated
  using ((select auth.uid()) = blocker_id);

create policy "Users can submit reports"
  on public.user_reports for insert to authenticated
  with check (
    (select auth.uid()) = reporter_id
    and reporter_id <> reported_id
  );

create policy "Users can view reports they submitted"
  on public.user_reports for select to authenticated
  using ((select auth.uid()) = reporter_id);

grant select, insert, update on public.profiles to authenticated;
grant select on public.call_sessions to authenticated;
grant select on public.call_participants to authenticated;
grant select, insert, delete on public.user_blocks to authenticated;
grant select, insert on public.user_reports to authenticated;

revoke all on public.call_sessions from anon;
revoke all on public.call_participants from anon;
revoke all on public.user_blocks from anon;
revoke all on public.user_reports from anon;
