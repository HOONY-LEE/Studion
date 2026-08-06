-- 이메일/비밀번호 가입을 없애고 Apple 로그인 하나로 합친다.
-- Supabase SQL Editor에 붙여넣고 한 번 실행한다.
--
-- 먼저 Supabase 대시보드에서 Authentication → Providers → Apple을 활성화해야 한다.
-- Client ID(Service ID)에는 앱의 번들 ID(com.studion.app)를 넣는다 — iOS 네이티브
-- Sign in with Apple은 웹용 Service ID가 아니라 번들 ID를 그대로 쓴다.
--
-- 이메일/비밀번호로 만들어졌던 기존 팀원 계정은 전부 지운다(합의됨 — 채팅 기록을
-- 잃어도 괜찮다는 전제). 트리거(dev_handle_new_user)는 손대지 않는다 — Apple 로그인도
-- auth.users에 새 행이 생기면 똑같이 이 트리거를 타서 dev_profiles를 만들기 때문이다.
delete from dev_messages;
delete from dev_chat_room_members;
delete from dev_chat_rooms;
delete from dev_profiles;
delete from auth.users;
