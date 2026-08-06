-- "Database error saving new user" — Apple 로그인에서 재발한 원인을 고친다.
--
-- 이메일/비밀번호 가입과 Apple id_token 로그인은 채워지는 값이 다르다:
--   - fullName은 애플이 클라이언트(ASAuthorizationAppleIDCredential)에만 주고
--     토큰(JWT)에는 절대 담기지 않는다 → raw_user_meta_data->>'display_name'은
--     Apple 로그인에서 항상 NULL이다.
--   - email도 이 앱(번들 ID)에 이미 한 번 권한을 준 적이 있으면(예: 온보딩의
--     "Apple로 시작하기" 단계를 먼저 거친 경우) 두 번째 인증부터는 애플이
--     다시 내려주지 않을 수 있다.
-- 두 값이 모두 없으면 옛 트리거의 coalesce가 NULL을 반환해 display_name의
-- not null 제약을 위반하고, auth.users insert 자체가(트리거가 같은 트랜잭션
-- 안에서 실행되므로) 롤백된다 — 이게 "Database error saving new user"의 원인이다.
-- 마지막에 하드코드 기본값을 두어 항상 값이 있게 만든다.
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
    coalesce(
      nullif(new.raw_user_meta_data->>'display_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      '팀원'
    ),
    new.email
  );
  return new;
end;
$$;
