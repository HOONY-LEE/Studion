-- 팀원 찾기 화면에 이메일을 보여주기 위해 dev_profiles에 email을 추가한다.
-- Supabase SQL Editor에 붙여넣고 한 번 실행한다.

alter table dev_profiles add column if not exists email text;

-- 기존 계정은 가입 트리거를 타지 않았으니 auth.users에서 백필한다.
update dev_profiles p
set email = u.email
from auth.users u
where p.id = u.id and p.email is null;

-- 새 가입자는 이메일도 같이 저장하도록 트리거를 갱신한다.
create or replace function dev_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.dev_profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    new.email
  );
  return new;
end;
$$;
