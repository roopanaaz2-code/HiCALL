-- Keep per-user call-history clearing independent of call participants.
-- This preserves the other participant's call history and call-session integrity.
create table if not exists public.call_history_clears (
  user_id uuid primary key references auth.users(id) on delete cascade,
  cleared_at timestamptz not null default now()
);
alter table public.call_history_clears enable row level security;
revoke all on table public.call_history_clears from public, anon, authenticated;
