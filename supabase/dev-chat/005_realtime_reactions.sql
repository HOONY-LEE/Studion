-- 리액션 테이블을 Realtime 발행 목록에 추가한다.
--
-- 004를 실행한 프로젝트에 적용하는 수정. 클라이언트가 dev_message_reactions 변경을
-- 구독하는데 이 테이블이 발행 목록에 없으면 **채널 구독 자체가 실패한다** — 그러면
-- 같은 채널에 얹은 dev_messages 구독까지 죽어서 새 메시지가 실시간으로 안 온다
-- (내가 보낸 사진이 화면에 안 나타나는 증상으로 겪었다).
alter publication supabase_realtime add table dev_message_reactions;
