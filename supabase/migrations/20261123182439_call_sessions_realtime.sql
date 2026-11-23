-- Enable call-session UPDATE events so both participants leave the call UI
-- immediately when either participant ends or declines a call.
do $$
begin
  if exists (select 1 from pg_catalog.pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_catalog.pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'call_sessions'
     ) then
    alter publication supabase_realtime add table public.call_sessions;
  end if;
end;
$$;
