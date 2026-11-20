create index if not exists user_blocks_blocked_id_idx on public.user_blocks (blocked_id);
create index if not exists user_reports_reported_id_idx on public.user_reports (reported_id);
create index if not exists user_reports_reporter_id_idx on public.user_reports (reporter_id);
