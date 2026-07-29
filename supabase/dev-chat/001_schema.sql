-- 개발자 탭(팀 내부 메신저) 스키마.
-- docs/10-developer-chat.md §3, §4를 그대로 옮긴 것 — 문서가 원본이다.
-- Supabase 대시보드 → SQL Editor에 붙여넣고 실행한다. 한 번만 실행하면 된다.

-- 팀원 프로필. auth.users의 확장.
create table dev_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now()
);

-- 채팅방. 1:1도 그룹도 같은 테이블 — is_group으로 구분.
create table dev_chat_rooms (
  id uuid primary key default gen_random_uuid(),
  name text,
  is_group boolean not null default false,
  created_by uuid not null references dev_profiles(id),
  created_at timestamptz not null default now()
);

-- 채팅방 소속. 초대 = 이 테이블에 행 추가.
create table dev_chat_room_members (
  room_id uuid not null references dev_chat_rooms(id) on delete cascade,
  user_id uuid not null references dev_profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

-- 메시지.
create table dev_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references dev_chat_rooms(id) on delete cascade,
  sender_id uuid not null references dev_profiles(id),
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index dev_messages_room_created_idx on dev_messages (room_id, created_at);

-- 회원가입 시 프로필 자동 생성.
create function dev_handle_new_user() returns trigger as $$
begin
  insert into dev_profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  return new;
end;
$$ language plpgsql security definer;

create trigger dev_on_auth_user_created
  after insert on auth.users
  for each row execute function dev_handle_new_user();

-- 채팅방 생성을 원자적으로 처리 — 방 생성 + 생성자를 멤버로 추가를 한 트랜잭션으로.
create function dev_create_room(room_name text, is_group boolean, member_ids uuid[])
returns uuid as $$
declare
  new_room_id uuid;
begin
  insert into dev_chat_rooms (name, is_group, created_by)
  values (room_name, is_group, auth.uid())
  returning id into new_room_id;

  insert into dev_chat_room_members (room_id, user_id)
  select new_room_id, unnest(array_append(member_ids, auth.uid()));

  return new_room_id;
end;
$$ language plpgsql security definer;

-- RLS. 전 테이블 기본은 전면 차단, 아래 정책만 허용.
alter table dev_profiles enable row level security;
alter table dev_chat_rooms enable row level security;
alter table dev_chat_room_members enable row level security;
alter table dev_messages enable row level security;

create policy "profiles are visible to authenticated users"
  on dev_profiles for select to authenticated using (true);

create policy "users can update own profile"
  on dev_profiles for update to authenticated using (id = auth.uid());

create policy "members can view their rooms"
  on dev_chat_rooms for select to authenticated using (
    exists (
      select 1 from dev_chat_room_members m
      where m.room_id = id and m.user_id = auth.uid()
    )
  );

create policy "members can view room membership"
  on dev_chat_room_members for select to authenticated using (
    exists (
      select 1 from dev_chat_room_members m
      where m.room_id = dev_chat_room_members.room_id and m.user_id = auth.uid()
    )
  );

create policy "existing members can invite others"
  on dev_chat_room_members for insert to authenticated with check (
    exists (
      select 1 from dev_chat_room_members m
      where m.room_id = dev_chat_room_members.room_id and m.user_id = auth.uid()
    )
  );

create policy "members can read messages"
  on dev_messages for select to authenticated using (
    exists (
      select 1 from dev_chat_room_members m
      where m.room_id = dev_messages.room_id and m.user_id = auth.uid()
    )
  );

create policy "members can send messages as themselves"
  on dev_messages for insert to authenticated with check (
    sender_id = auth.uid() and exists (
      select 1 from dev_chat_room_members m
      where m.room_id = dev_messages.room_id and m.user_id = auth.uid()
    )
  );

-- Realtime이 이 테이블의 변경을 방송하게 한다 (postgres_changes 구독용).
alter publication supabase_realtime add table dev_messages;
