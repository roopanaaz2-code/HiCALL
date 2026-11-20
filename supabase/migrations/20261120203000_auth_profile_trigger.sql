create or replace function public.handle_new_hicall_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chosen_username text;
begin
  chosen_username := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    'user_' || substr(new.id::text, 1, 8)
  );
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    chosen_username,
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_hicall on auth.users;
create trigger on_auth_user_created_hicall
after insert on auth.users
for each row execute procedure public.handle_new_hicall_user();
