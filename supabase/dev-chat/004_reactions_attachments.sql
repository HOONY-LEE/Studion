-- 리액션 · 첨부(이미지/파일) · 답장 · 수정/삭제 · 읽음 표시.
-- WorkChat iOS(clients/ios)의 채팅 UI와 같은 기능을 담기 위해 필요한 스키마.
-- Supabase SQL Editor에 붙여넣고 한 번 실행한다.

-- ── 메시지 확장 ────────────────────────────────────────────────────────────
-- 첨부만 있고 본문이 빈 메시지(사진 전송)가 가능해야 하므로 본문 길이 제약을 바꾼다.
-- 원래 제약은 `char_length(body) between 1 and 4000` 이라 빈 본문을 막았다.
alter table dev_messages drop constraint if exists dev_messages_body_check;
alter table dev_messages alter column body set default '';
alter table dev_messages add constraint dev_messages_body_check
  check (char_length(body) <= 4000);

alter table dev_messages
  add column if not exists message_type text not null default 'TEXT'
    check (message_type in ('TEXT', 'IMAGE', 'FILE')),
  -- 첨부는 Storage 버킷의 경로만 담는다(파일 자체는 버킷에). 경로 규칙은 §아래 정책 참고.
  add column if not exists attachment_path text,
  add column if not exists attachment_name text,
  add column if not exists attachment_size bigint,
  add column if not exists attachment_mime text,
  -- 답장 대상. 원본이 지워져도 답장은 남아야 하므로 on delete set null.
  add column if not exists reply_to_id uuid references dev_messages(id) on delete set null,
  -- 지운 메시지는 행을 없애지 않고 표시만 남긴다("삭제된 메시지"로 보여주기 위해).
  add column if not exists deleted_at timestamptz,
  add column if not exists edited_at timestamptz;

-- 첨부 메시지는 경로가 반드시 있어야 하고, 텍스트 메시지는 본문이 있어야 한다.
-- (삭제된 메시지는 둘 다 비어 있을 수 있으니 예외로 둔다.)
alter table dev_messages drop constraint if exists dev_messages_payload_check;
alter table dev_messages add constraint dev_messages_payload_check check (
  deleted_at is not null
  or (message_type = 'TEXT' and char_length(btrim(body)) > 0)
  or (message_type in ('IMAGE', 'FILE') and attachment_path is not null)
);

-- ── 리액션 ────────────────────────────────────────────────────────────────
-- 한 사람이 같은 메시지에 같은 이모지를 두 번 남길 수 없다(기본키로 보장).
-- 집계(이모지별 개수)는 클라이언트에서 하지 않고 아래 뷰/함수로 받는다.
create table if not exists dev_message_reactions (
  message_id uuid not null references dev_messages(id) on delete cascade,
  user_id uuid not null references dev_profiles(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

create index if not exists dev_message_reactions_message_idx
  on dev_message_reactions (message_id);

alter table dev_message_reactions enable row level security;

-- 리액션은 그 메시지가 있는 방의 멤버만 보고 남길 수 있다.
-- dev_is_room_member(003) 를 거치므로 정책이 자기 테이블을 다시 조회하지 않는다.
create or replace function dev_can_touch_message(target_message_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from dev_messages m
    where m.id = target_message_id
      and dev_is_room_member(m.room_id, auth.uid())
  );
$$;

drop policy if exists "members can view reactions" on dev_message_reactions;
create policy "members can view reactions"
  on dev_message_reactions for select to authenticated using (
    dev_can_touch_message(message_id)
  );

drop policy if exists "members can react as themselves" on dev_message_reactions;
create policy "members can react as themselves"
  on dev_message_reactions for insert to authenticated with check (
    user_id = auth.uid() and dev_can_touch_message(message_id)
  );

drop policy if exists "members can remove own reactions" on dev_message_reactions;
create policy "members can remove own reactions"
  on dev_message_reactions for delete to authenticated using (
    user_id = auth.uid()
  );

-- ── 메시지 수정/삭제 ───────────────────────────────────────────────────────
-- 본인 메시지만. 보낸 사람을 바꿔치기할 수 없도록 with check 에서 sender_id 도 고정한다.
drop policy if exists "senders can edit own messages" on dev_messages;
create policy "senders can edit own messages"
  on dev_messages for update to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

-- ── 읽음 표시 ─────────────────────────────────────────────────────────────
alter table dev_chat_room_members
  add column if not exists last_read_at timestamptz not null default now();

-- 방을 열 때 호출한다. 내 멤버십 행만 갱신하므로 별도 update 정책이 필요 없다
-- (security definer 로 실행되며 auth.uid() 로 대상을 스스로 제한한다).
create or replace function dev_mark_room_read(target_room_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update dev_chat_room_members
  set last_read_at = now()
  where room_id = target_room_id and user_id = auth.uid();
$$;

-- 방별 안 읽은 개수. 내가 보낸 메시지와 지운 메시지는 세지 않는다.
create or replace function dev_unread_counts()
returns table (room_id uuid, unread_count bigint)
language sql
security definer
set search_path = public
stable
as $$
  select m.room_id, count(*)::bigint
  from dev_messages m
  join dev_chat_room_members mem
    on mem.room_id = m.room_id and mem.user_id = auth.uid()
  where m.created_at > mem.last_read_at
    and m.sender_id <> auth.uid()
    and m.deleted_at is null
  group by m.room_id;
$$;

-- ── 첨부 저장소 ───────────────────────────────────────────────────────────
-- 비공개 버킷. 경로는 반드시 `<room_id>/<파일명>` 으로 만든다 — 아래 정책이 첫 번째
-- 폴더명을 방 id 로 읽어 "그 방의 멤버인가"를 검사하기 때문이다.
insert into storage.buckets (id, name, public)
values ('dev-chat', 'dev-chat', false)
on conflict (id) do nothing;

drop policy if exists "room members can read dev-chat files" on storage.objects;
create policy "room members can read dev-chat files"
  on storage.objects for select to authenticated using (
    bucket_id = 'dev-chat'
    and dev_is_room_member(((storage.foldername(name))[1])::uuid, auth.uid())
  );

drop policy if exists "room members can upload dev-chat files" on storage.objects;
create policy "room members can upload dev-chat files"
  on storage.objects for insert to authenticated with check (
    bucket_id = 'dev-chat'
    and dev_is_room_member(((storage.foldername(name))[1])::uuid, auth.uid())
  );
