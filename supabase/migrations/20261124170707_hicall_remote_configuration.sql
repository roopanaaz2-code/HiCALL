-- Public, read-only runtime configuration for HiCALL.
-- Only trusted project administrators may write values through the Supabase dashboard/SQL.
create table if not exists public.app_remote_config (
  config_key text primary key
    check (config_key ~ '^[a-z][a-z0-9_.-]{0,99}$'),
  config_value jsonb not null,
  description text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_remote_config enable row level security;

revoke all on table public.app_remote_config from public, anon, authenticated;
grant select on table public.app_remote_config to anon, authenticated;

drop policy if exists "Anyone can read HiCALL remote configuration"
  on public.app_remote_config;
create policy "Anyone can read HiCALL remote configuration"
  on public.app_remote_config
  for select
  to anon, authenticated
  using (true);

insert into public.app_remote_config (config_key, config_value, description)
values
  ('maintenance_mode', 'false'::jsonb, 'When true, clients should show a maintenance notice'),
  ('announcement_enabled', 'false'::jsonb, 'Whether the in-app announcement is visible'),
  ('announcement_text', '""'::jsonb, 'Announcement copy displayed when enabled'),
  ('minimum_supported_version', '"1.0.0+1"'::jsonb, 'Minimum supported app version; informational until enforced by the client'),
  ('feature_calls_enabled', 'true'::jsonb, 'Master switch for calling features'),
  ('feature_video_enabled', 'true'::jsonb, 'Switch for video calling'),
  ('feature_chat_enabled', 'true'::jsonb, 'Switch for direct messaging')
on conflict (config_key) do nothing;
