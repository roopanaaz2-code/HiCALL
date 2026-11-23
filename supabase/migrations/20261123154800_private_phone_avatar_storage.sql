-- Store no-code phone entries privately without granting verification or discoverability.
create table if not exists public.user_private_phone_entries (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_e164 text not null,
  updated_at timestamptz not null default now(),
  constraint user_private_phone_entries_e164_format
    check (phone_e164 ~ '^[+][1-9][0-9]{7,14}$')
);

alter table public.user_private_phone_entries enable row level security;
revoke all on table public.user_private_phone_entries from public, anon, authenticated;
grant select, insert, update, delete on table public.user_private_phone_entries to authenticated;

drop policy if exists "Owners manage their private unverified phone entry"
  on public.user_private_phone_entries;
create policy "Owners manage their private unverified phone entry"
  on public.user_private_phone_entries
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Public reads are appropriate for user-chosen profile pictures. Storage still
-- checks RLS for writes, so each account can only modify objects in its own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'hicall-avatars',
  'hicall-avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set name = excluded.name,
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "HiCALL users upload avatars to their own folder"
  on storage.objects;
create policy "HiCALL users upload avatars to their own folder"
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'hicall-avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "HiCALL users delete avatars from their own folder"
  on storage.objects;
create policy "HiCALL users delete avatars from their own folder"
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'hicall-avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
