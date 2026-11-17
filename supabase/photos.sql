-- Photos on visits for the Tri-Cities map.
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Needs setup.sql to have been run first (it creates public.is_member()).

-- A private bucket: only signed-in team members can see or add photos
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('visit-photos', 'visit-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg'];

drop policy if exists "members see photos" on storage.objects;
drop policy if exists "members add photos" on storage.objects;
drop policy if exists "members remove photos" on storage.objects;
create policy "members see photos" on storage.objects for select to authenticated
  using (bucket_id = 'visit-photos' and public.is_member());
create policy "members add photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'visit-photos' and public.is_member());
create policy "members remove photos" on storage.objects for delete to authenticated
  using (bucket_id = 'visit-photos' and public.is_member());
