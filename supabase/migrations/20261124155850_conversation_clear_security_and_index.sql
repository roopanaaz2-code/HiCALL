drop policy if exists "Users can update their own conversation clear markers" on public.conversation_clears;
create policy "Users can update their own conversation clear markers"
  on public.conversation_clears for update to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.direct_conversations c
      where c.id = conversation_id
        and ((select auth.uid()) = c.user_a or (select auth.uid()) = c.user_b)
    )
  )
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.direct_conversations c
      where c.id = conversation_id
        and ((select auth.uid()) = c.user_a or (select auth.uid()) = c.user_b)
    )
  );
create index if not exists conversation_clears_conversation_id_idx
  on public.conversation_clears (conversation_id);
create or replace function public.clear_hicall_conversation(p_conversation_id uuid)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_cleared_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if not exists (
    select 1 from public.direct_conversations c
    where c.id = p_conversation_id
      and (c.user_a = v_user_id or c.user_b = v_user_id)
  ) then
    raise exception 'Conversation not found';
  end if;
  insert into public.conversation_clears (user_id, conversation_id, cleared_at)
  values (v_user_id, p_conversation_id, pg_catalog.clock_timestamp())
  on conflict (user_id, conversation_id)
  do update set cleared_at = excluded.cleared_at
  returning cleared_at into v_cleared_at;
  return v_cleared_at;
end;
$$;
revoke all on function public.clear_hicall_conversation(uuid) from public, anon;
grant execute on function public.clear_hicall_conversation(uuid) to authenticated;
