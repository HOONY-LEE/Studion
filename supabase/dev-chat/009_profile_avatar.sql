-- 프로필 사진과 이름 바꾸기.
-- Supabase SQL Editor에 붙여넣고 한 번 실행한다.
--
-- Apple 로그인은 이름을 **최초 인증 한 번만** 내려준다. 그때를 놓치면(온보딩을 건너뛰었거나
-- 이미 이 앱에 권한을 준 적이 있으면) 이름이 이메일 앞부분이나 '팀원'으로 남는데,
-- 지금까지는 그걸 고칠 방법이 없었다. 이제 앱에서 직접 바꾼다.

-- 프로필 사진. 버킷 안 경로만 담는다(원본 바이트는 Storage에).
alter table dev_profiles add column if not exists avatar_path text;

-- 사진 버킷. 비공개이며, 로그인한 팀원끼리는 서로의 사진을 볼 수 있어야 한다
-- (대화 목록·말풍선 옆에 상대 사진이 떠야 하므로).
insert into storage.buckets (id, name, public)
values ('dev-avatars', 'dev-avatars', false)
on conflict (id) do nothing;

-- 경로 규칙은 `<user_id>/<uuid>.jpg`. 첫 폴더명을 본인 id로 강제해 남의 사진을
-- 덮어쓰지 못하게 한다 (첨부파일 버킷이 방 id로 하는 것과 같은 방식).
--
-- **겪은 버그.** 첫 폴더명을 `text`로 비교하면 안 된다 — Swift의 `UUID.uuidString`은
-- 대문자를, Postgres의 `auth.uid()::text`는 소문자를 주므로 늘 어긋나서
-- "new row violates row-level security policy"로 업로드가 전부 막힌다.
-- `::uuid`로 캐스팅해 비교하면 대소문자와 무관해진다 (004의 첨부파일 정책과 같은 방식).
drop policy if exists "team members can view avatars" on storage.objects;
create policy "team members can view avatars"
  on storage.objects for select to authenticated
  using (bucket_id = 'dev-avatars');

drop policy if exists "users can upload own avatar" on storage.objects;
create policy "users can upload own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'dev-avatars'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
  );

drop policy if exists "users can replace own avatar" on storage.objects;
create policy "users can replace own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'dev-avatars'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
  );

drop policy if exists "users can delete own avatar" on storage.objects;
create policy "users can delete own avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'dev-avatars'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
  );
