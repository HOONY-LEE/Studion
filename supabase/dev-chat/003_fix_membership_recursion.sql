-- "infinite recursion detected in policy for relation dev_chat_room_members" 수정.
--
-- 원인: dev_chat_room_members의 SELECT/INSERT 정책이 dev_chat_room_members
-- 자신을 다시 조회했다. 그 조회도 똑같은 RLS를 통과해야 하니 정책이 정책을
-- 무한히 다시 부른다. 다른 테이블(dev_chat_rooms, dev_messages)의 정책도
-- 같은 테이블을 조회하니 근본 원인은 같다.
--
-- 해법: RLS를 우회하는 security definer 함수 하나로 "이 유저가 이 방의
-- 멤버인가"를 물어보게 한다. 함수 내부 조회는 테이블 소유자 권한으로 실행되어
-- RLS 정책을 다시 타지 않으므로 재귀가 끊긴다.
--
-- Supabase SQL Editor에서 한 번 실행하면 된다. 기존 정책을 지우고 다시 만든다.
create or replace function dev_is_room_member(target_room_id uuid, target_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from dev_chat_room_members
    where room_id = target_room_id and user_id = target_user_id
  );
$$;

drop policy if exists "members can view their rooms" on dev_chat_rooms;
create policy "members can view their rooms"
  on dev_chat_rooms for select to authenticated using (
    dev_is_room_member(id, auth.uid())
  );

drop policy if exists "members can view room membership" on dev_chat_room_members;
create policy "members can view room membership"
  on dev_chat_room_members for select to authenticated using (
    dev_is_room_member(room_id, auth.uid())
  );

drop policy if exists "existing members can invite others" on dev_chat_room_members;
create policy "existing members can invite others"
  on dev_chat_room_members for insert to authenticated with check (
    dev_is_room_member(room_id, auth.uid())
  );

drop policy if exists "members can read messages" on dev_messages;
create policy "members can read messages"
  on dev_messages for select to authenticated using (
    dev_is_room_member(room_id, auth.uid())
  );

drop policy if exists "members can send messages as themselves" on dev_messages;
create policy "members can send messages as themselves"
  on dev_messages for insert to authenticated with check (
    sender_id = auth.uid() and dev_is_room_member(room_id, auth.uid())
  );
