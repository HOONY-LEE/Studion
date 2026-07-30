-- 001_schema.sql을 이미 실행한 프로젝트에 적용하는 수정.
-- 가입 시 "Database error saving new user"가 뜨는 버그를 고친다 — 원인은
-- dev_handle_new_user()가 search_path를 안 정해서 auth 스키마 트리거 컨텍스트에서
-- "dev_profiles"를 못 찾은 것. Supabase SQL Editor에 붙여넣고 한 번 실행하면 된다.
--
-- create or replace라서 기존 트리거(dev_on_auth_user_created)는 그대로 두고
-- 함수 본문만 바뀐다 — 트리거를 다시 만들 필요가 없다.
create or replace function dev_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.dev_profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;
