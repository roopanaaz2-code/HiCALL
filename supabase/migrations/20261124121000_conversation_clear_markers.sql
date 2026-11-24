-- Let each participant hide old messages from their own chat view without
-- deleting the other participant's history.
create table if not exists public.conversation_clears (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
  cleared_at timestamptz not null default now(),
  primary key (user_id, conversation_id)
);

alter table public.conversation_clears enable row level security;
revoke all on table public.conversation_clears from public, anon, authenticated;
grant select, insert, update on table public.conversation_clears to authenticated;

create policy "Users can read their own conversation clear markers"
  on public.conversation_clears for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can create their own conversation clear markers"
  on public.conversation_clears for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.direct_conversations c
      where c.id = conversation_id
        and ((select auth.uid()) = c.user_a or (select auth.uid()) = c.user_b)
    )
  );

create policy "Users can update their own conversation clear markers"
  on public.conversation_clears for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
