# 10. 개발자 탭 — 팀 내부 메신저

> 이 문서는 `개발자` 탭의 데이터 모델과 동작을 정의한다.
> [08](08-question-bank.md)(문제집 공유)과 이 문서 둘 다 Supabase를 쓰지만 **서로 다른 프로젝트,
> 다른 목적**이다. 착각하지 않도록 여기서 분명히 한다 → §0.

---

## 0. 이게 뭐고, 뭐가 아닌가

**개발 기간 동안 이 앱을 만드는 팀(개발자들)이 서로 연락하는 임시 도구.**
학생 사용자를 위한 기능이 아니다.

| | 이 기능 (개발자 메신저) | [08] 문제집 공유 |
|---|---|---|
| 사용자 | 앱 개발팀 (소수, 서로 아는 사람) | 학생·교사 (불특정 다수) |
| 존재 기간 | 개발 기간만. 출시본에는 없음 | 출시 후에도 계속 |
| 컨텐츠 | 자유 텍스트 채팅 | 구조화된 문제집 |
| 검수 필요성 | 없음 (팀원끼리만) | 필요 (→ [08] §0, 신고+사후조치) |
| Supabase 프로젝트 | **별도 프로젝트** 권장 (§7) | 별도 프로젝트 |

**왜 원칙과 충돌하는데 만드는가** — [00](00-product-principles.md) 원칙 3은 "채팅을 만들지 않는다"고
못박고 있다. 이건 그 원칙에 대한 **명시적 예외**이며, 예외가 성립하는 조건은:

1. **DEBUG 빌드에서만 화면·로직이 컴파일된다** (`#if DEBUG`, → §6). Release(App Store 제출본)에는
   이 기능의 Swift 코드가 없다.
2. 학생 데이터가 아니다 — 팀원 본인들이 스스로 만드는 대화다.
3. 이 예외를 근거로 학생 대상 채팅·소셜 기능을 만들지 않는다.

**출시 체크리스트**: App Store 제출 직전, `project.yml`에서 `supabase-swift` 패키지 의존성 자체를
제거한다 (§6에서 설명하는 이유로, `#if DEBUG`만으로는 서드파티 바이너리 링크까지는 못 뗀다).

---

## 1. 범위

**들어가는 것**

- 이메일/비밀번호로 팀원 계정 생성·로그인
- 유저 검색 (표시 이름 또는 이메일 일부로)
- 1:1 대화, 그룹 대화(채팅방) 생성
- 기존 채팅방에 유저 초대
- 텍스트 메시지 전송/수신 (실시간)
- 애플 메시지와 비슷한 느낌의 UI (말풍선, 좌/우 정렬, 채팅방 목록)

**안 들어가는 것 (1차)**

- 이미지/파일 첨부 — 나중에 필요해지면 추가
- 읽음 표시, 타이핑 인디케이터
- 푸시 알림 — 앱을 열어야 확인 가능
- 메시지 삭제/수정, 채팅방 나가기 (DB에서 수동으로 처리)
- 프로필 사진
- 팀원이 아닌 사람의 가입 차단 로직 (§7에서 논의 — 1차는 수동 관리)

---

## 2. 인증

- Supabase Auth, **이메일/비밀번호** 방식.
- 팀 내부용이라 소셜 로그인·매직링크는 필요 없다. 가장 단순한 방식으로 시작한다.
- 가입 자체를 막지는 않는다 (Supabase 프로젝트 URL/키를 아는 사람만 접근 가능하다는 것이
  1차 방어선). 실제로는 앱 내 개발자 탭에만 있는 기능이라 접근 자체가 제한적이다.
- 세션은 Supabase SDK가 키체인에 보관, 자동 갱신.

> 이 인증은 **Sign in with Apple(→ [06](06-sync-and-backup.md))과 완전히 별개**다.
> 학생용 CloudKit 동기화 계정과 섞이지 않는다 — 개발자 탭은 자체 Supabase 세션을 쓴다.

---

## 3. 데이터 모델 (Supabase Postgres)

테이블 이름에 `dev_` 접두사를 붙여, 나중에 [08]의 문제집 공유용 테이블과
같은 프로젝트에 놓이더라도(권장하진 않지만) 헷갈리지 않게 한다.

```sql
-- 팀원 프로필. auth.users의 확장.
create table dev_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  email text,                      -- 팀원 찾기 목록에 표시. `006_add_profile_email.sql` 참고.
  created_at timestamptz not null default now()
);

-- 채팅방. 1:1도 그룹도 같은 테이블 — is_group으로 구분.
create table dev_chat_rooms (
  id uuid primary key default gen_random_uuid(),
  name text,                       -- 그룹만 사용. 1:1은 상대방 이름을 클라이언트가 표시.
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
```

### 회원가입 시 프로필 자동 생성

```sql
create function dev_handle_new_user()
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

create trigger dev_on_auth_user_created
  after insert on auth.users
  for each row execute function dev_handle_new_user();
```

**겪은 버그.** `set search_path = public`과 `public.dev_profiles`처럼 스키마를 명시하지
않으면, 이 트리거가 `auth` 스키마 쪽 컨텍스트에서 실행될 때 `dev_profiles`를 못 찾아
가입 자체가 실패한다 — Supabase Auth는 원인을 감추고 클라이언트에는 그냥
"Database error saving new user"만 돌려준다. 이미 001_schema.sql을 실행한 프로젝트는
`002_fix_new_user_trigger.sql`을 SQL Editor에서 한 번 더 실행하면 된다
(`create or replace function`이라 트리거는 그대로 두고 함수 본문만 바뀐다).

### 채팅방 생성을 원자적으로 — RPC 함수

클라이언트에서 "방 만들기"와 "만든 사람을 멤버로 추가"를 각각 insert 두 번으로 하면
그 사이에 RLS 때문에 실패할 수 있다 (방 select 정책이 "멤버인 방만"이라 방금 만든 방을
자기 자신도 못 보는 순간이 생김). 하나의 `security definer` 함수로 묶는다.

```sql
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
```

클라이언트는 방을 직접 insert하지 않고 이 함수만 호출한다 (`supabase.rpc("dev_create_room", ...)`).
초대(기존 방에 멤버 추가)는 §4의 RLS 정책이 허용하는 한 `dev_chat_room_members`에 직접 insert한다.

---

## 4. RLS (Row Level Security)

전 테이블 `enable row level security` 후 아래 정책만 허용한다. 기본은 전면 차단.

```sql
alter table dev_profiles enable row level security;
alter table dev_chat_rooms enable row level security;
alter table dev_chat_room_members enable row level security;
alter table dev_messages enable row level security;

-- 프로필: 로그인한 사람은 전부 볼 수 있다 (유저 검색용). 본인 것만 수정.
create policy "profiles are visible to authenticated users"
  on dev_profiles for select to authenticated using (true);

create policy "users can update own profile"
  on dev_profiles for update to authenticated using (id = auth.uid());

-- 멤버 여부 확인은 이 함수를 거친다 — dev_chat_room_members 정책이 자기 자신을
-- 직접 조회하면 그 조회도 같은 정책을 다시 타서 "infinite recursion detected in
-- policy for relation dev_chat_room_members"가 난다 (겪은 버그). security definer
-- 함수는 테이블 소유자 권한으로 실행되어 RLS를 다시 타지 않으므로 재귀가 끊긴다.
create function dev_is_room_member(target_room_id uuid, target_user_id uuid)
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

-- 채팅방: 멤버인 방만 보인다.
create policy "members can view their rooms"
  on dev_chat_rooms for select to authenticated using (
    dev_is_room_member(id, auth.uid())
  );

-- 채팅방 멤버십: 같은 방 멤버만 멤버 목록을 본다. 초대는 기존 멤버만 할 수 있다.
create policy "members can view room membership"
  on dev_chat_room_members for select to authenticated using (
    dev_is_room_member(room_id, auth.uid())
  );

create policy "existing members can invite others"
  on dev_chat_room_members for insert to authenticated with check (
    dev_is_room_member(room_id, auth.uid())
  );

-- 메시지: 멤버만 읽고, 멤버만(그리고 본인 이름으로만) 쓴다.
create policy "members can read messages"
  on dev_messages for select to authenticated using (
    dev_is_room_member(room_id, auth.uid())
  );

create policy "members can send messages as themselves"
  on dev_messages for insert to authenticated with check (
    sender_id = auth.uid() and dev_is_room_member(room_id, auth.uid())
  );
```

`dev_create_room` RPC는 `security definer`라 이 정책들을 우회해 방을 만들지만,
그 안에서 하는 일(방 생성 + 생성자를 멤버로 추가)은 정확히 정책이 허용하는 범위와 같다.

**겪은 버그.** 처음 버전은 `dev_chat_room_members` 정책 안에서 `dev_chat_room_members`를
`exists (select 1 from dev_chat_room_members m where ...)`로 직접 조회했다. RLS가 걸린
테이블을 정책 **안에서** 다시 조회하면 그 조회에도 같은 정책이 적용되어 무한히 반복된다.
이미 `001_schema.sql`을 실행한 프로젝트는 `003_fix_membership_recursion.sql`을 한 번 더
실행한다 (기존 정책을 지우고 안전한 버전으로 다시 만든다).

---

## 5. 실시간

Supabase Realtime의 `postgres_changes`를 구독한다. 대화 화면이 열려 있는 동안만이며,
방을 나가면 채널을 정리한다.

| 채널 | 구독 대상 | 필터 |
|---|---|---|
| `dev_messages:room_<id>` | `dev_messages` insert + update | `room_id = 현재 방` |
| `dev_reactions:room_<id>` | `dev_message_reactions` insert + delete | 없음(테이블에 room_id가 없다) |

**메시지와 리액션을 반드시 서로 다른 채널에 둔다.** 한 채널에 얹으면 한쪽 구독이
잘못돼도 **채널 전체의 이벤트가 끊긴다.** 리액션 테이블을 발행 목록에 넣지 않은 채
같은 채널에 얹었더니 `subscribeWithError()`는 성공했다고 돌아오면서 메시지 이벤트까지
조용히 오지 않았다 (실제로 겪은 버그 — 보낸 사진이 화면에 안 나타나는 증상이었다).

채널을 나눈 뒤의 실패 처리도 다르다:

- **메시지 채널 실패** → 화면 상단에 띠로 알린다. 안 알리면 "상대가 조용한 것"과
  구분되지 않는다.
- **리액션 채널 실패** → 알리지 않고 넘어간다. 알약은 방을 다시 열 때 조회로 채워지므로
  사용자가 할 일이 없다.

**보낸 메시지는 실시간 수신에 의존하지 않는다.** insert에 `.select().single()`을 붙여
넣은 행을 돌려받아 바로 목록에 붙인다 — 구독이 어떤 이유로든 끊겨 있으면 보낸 사람
화면에서만 메시지가 사라진 것처럼 보이기 때문이다.

새 테이블을 구독 대상에 추가할 때는 **발행 목록에 넣는 SQL을 같이 써야 한다**:
`alter publication supabase_realtime add table <이름>;`

푸시 알림은 범위 밖(§1). 앱이 포그라운드에 있을 때만 실시간 수신이 의미가 있다.
대화 목록은 실시간 구독 없이 화면 진입·당겨서 새로고침으로 갱신한다.

---

## 6. 클라이언트 구조

```
Studion/Utilities/DeveloperChat/          (전부 #if DEBUG)
  ├─ DevChatConfig.swift                  Supabase URL/anon key. .gitignore 대상 (§7)
  ├─ DevChatClient.swift                  SupabaseClient 싱글턴 래핑
  ├─ DevChatAuthService.swift             가입/로그인/로그아웃/세션
  ├─ DevChatRoomService.swift             방 생성(RPC 호출)/목록/초대
  ├─ DevChatMessageService.swift          메시지 조회/전송/실시간 구독
  ├─ DevChatModels.swift                  DevProfile/DevChatRoom/DevMessage (Codable)
  ├─ DevChatLayout.swift                  말풍선 묶음·시각 구분선 계산 (순수 로직, 테스트 있음)
  ├─ DevChatTimestamp.swift               오늘/어제/요일/날짜 표기 (순수 로직, 테스트 있음)
  └─ DevChatStrings.swift                 문자열을 조립할 때 쓰는 번역 조회

Studion/Views/Developer/                  (전부 #if DEBUG)
  ├─ DeveloperChatView.swift              루트 — 로그인 여부에 따라 분기
  ├─ DevChatAuthView.swift                로그인/가입 폼
  ├─ DevChatRoomListView.swift            대화 목록 (아바타·미리보기·시각·검색)
  ├─ DevUserSearchView.swift              유저 검색 → 방 만들기/초대
  ├─ DevChatRoomView.swift                대화 화면 (말풍선 배치·입력창)
  ├─ DevChatBubble.swift                  말풍선 모양(꼬리 포함)과 색
  └─ DevChatAvatar.swift                  이름 첫 글자 원형 아바타
```

기존 프로젝트 관례(순수 Swift 로직 vs SwiftUI 뷰 분리, → [01](01-architecture.md))를 따르되,
이 기능 전체를 **다른 기능과 완전히 분리된 디렉터리**에 두는 이유는 하나다 — 나중에
이 기능을 통째로 들어내야 할 때(§0의 출시 체크리스트) 다른 파일을 건드릴 일이 없게.

### `#if DEBUG`로 못 막는 것 — 알아둘 점

우리가 짠 Swift 코드는 `#if DEBUG`로 감싸면 Release 컴파일에서 완전히 빠진다
(오답노트 샘플 데이터 시더 때 `strings`로 검증한 방식 그대로). 하지만 **`supabase-swift`
패키지 자체**는 Xcode의 타깃-패키지 의존성이 빌드 구성(Debug/Release)별로 분리되지 않는
구조라 Release 아카이브에도 정적으로 링크된다. 호출되는 코드가 없을 뿐 바이너리 크기는
늘어난다는 뜻이다. 이걸 완전히 없애려면 출시 직전 `project.yml`에서 패키지 의존성 자체를
지우고 재생성해야 한다 (§0 체크리스트).

같은 이유로 **String Catalog(`Localizable.xcstrings`)의 키/번역 텍스트도 코드와는 별개다** —
Xcode가 카탈로그를 `.strings` 리소스로 컴파일하는 과정은 어떤 Swift 파일이 그 키를
실제로 참조하는지와 무관하게 카탈로그 전체를 변환한다. 즉 이 문서에서 쓰는 한국어/영어
UI 문구 자체는 Release 번들에도 리소스로 남는다 — 기능은 없고 텍스트 데이터만 남는
정도라 위험하지는 않지만, "완전히 흔적이 없다"는 뜻은 아니라는 걸 밝혀둔다.

### DevChatConfig — 자격 증명을 커밋하지 않는다

실제 구현: `Config/DevChatSecrets.xcconfig`(커밋, 값은 비어 있음)가
`Config/DevChatSecrets.local.xcconfig`(gitignore 대상, 실제 값)를 `#include?`로 끌어오고,
그 값을 Debug 전용 Info.plist 키(`DevChatSupabaseURL`/`DevChatSupabaseAnonKey`)로 흘려보낸다.
`DevChatConfig`는 `Bundle.main`에서 그 키를 읽기만 한다 — 값이 없으면 `nil`을 반환하고,
그러면 `DevChatClient.shared`도 `nil`이 되어 개발자 탭은 안내 화면만 보여준다(크래시하지 않는다).

`AGENTS.md`의 "비밀값을 커밋하지 않는다" 규칙 그대로 — anon key는 공개돼도 RLS가 지켜주는
설계지만(Supabase의 표준 모델), 그래도 저장소에는 두지 않고 로컬 설정 파일(`.gitignore` 대상)로
분리한다.

**겪은 버그 — xcconfig의 `//` 주석 규칙.** `DevChatSecrets.local.xcconfig`에
`DEV_CHAT_SUPABASE_URL = https://xxx.supabase.co`라고 그대로 쓰면 xcconfig가 `//`를
(문자열 안이든 어디든) 주석 시작으로 읽어 값이 `https:`로 잘린다. 그 결과 앱이
"개발자" 탭을 열자마자 `SupabaseClient` 초기화에서 `Fatal error: supabaseURL must have a
valid host`로 즉시 크래시했다 — 시뮬레이터에서 탭을 눌렀는데 홈 화면으로 튕기는
증상으로 나타났다. `https:$()//host`처럼 빈 매크로 참조 `$()`로 슬래시 두 개를
갈라놓아야 한다.

### 애플 메시지처럼 보이게 하는 규칙

배치 판단을 뷰에 흩어놓지 않고 `DevChatLayout`에 모았다. 뷰는 "이 말풍선에 꼬리를
달아야 하나"를 스스로 묻지 않고 계산된 결과만 그린다.

| 규칙 | 값 | 이유 |
|---|---|---|
| 같은 사람이 연달아 보내면 한 묶음 | 5분 이내 | 애플 메시지와 같은 묶음 감각 |
| 묶음의 **마지막에만** 꼬리 | — | 애플 메시지도 묶음 끝에만 꼬리가 있다 |
| 묶음 안 간격 / 묶음 사이 간격 | 2pt / 8pt | 묶여 보이려면 안쪽이 훨씬 촘촘해야 한다 |
| 시각 구분선 | 1시간 이상 벌어질 때 + 첫 메시지 | 매 메시지에 시각을 붙이면 지저분하다 |
| 구분선이 들어가면 묶음을 끊는다 | — | 안 끊으면 구분선이 꼬리 없는 말풍선 사이에 낀다 |
| 보낸 사람 이름·아바타 | 그룹 대화의 받은 메시지만 | 1:1에서는 누가 보냈는지 자명하다 |

**겪은 버그 두 개** (둘 다 `DevChatBubble.swift` 주석에 남겼다):

1. **모서리가 파였다.** 본체와 꼬리를 각각 `Path`로 그려 겹쳤더니, 두 하위 경로의 회전
   방향이 어긋난 쪽에서 nonzero winding 규칙이 겹친 영역을 구멍으로 판단했다. 좌우가
   거울상이라 **받은 말풍선만** 파여 보여 더 헷갈렸다. 지금은 시계 방향으로 한 바퀴 도는
   **하나의 외곽선**으로 그린다.
2. **꼬리가 지느러미처럼 보였다.** 꼬리 끝에서 밑면으로 돌아오는 곡선의 조절점 y를 두
   끝점과 같게 두어 곡선이 직선이 됐다. 조절점을 위로 올려 **오목한 갈고리**를 만들어야
   꼬리로 읽힌다.

---

## 7. 시작하기 전에 필요한 것

이 문서의 스키마·정책은 SQL 파일로 준비할 수 있지만, **실제로 동작하려면 Supabase
프로젝트가 있어야 한다.** 다음이 없으면 §6 코드는 실행되지 않는다.

1. **Supabase 프로젝트** — supabase.com에서 새로 만든다. **[08]의 문제집 공유용과는
   별도 프로젝트를 권장한다** — 목적이 다르고(팀 내부 vs 사용자 대상), 나중에 이 기능을
   통째로 지울 때 문제집 데이터에 영향이 없어야 하기 때문이다.
2. **Project URL / anon key** — Settings → API에서 확인. `DevChatConfig`에 넣을 값.
3. **§3의 SQL을 SQL Editor에서 실행** — 테이블/함수/정책 생성.
4. **팀원 계정을 누가 셋업할지** — 1차는 각자 앱 안에서 가입 화면으로 만들면 된다
   (§1에서 정한 대로 가입 자체는 막지 않으므로).

이 네 가지가 준비되면 §6 구현(태스크 #30)에 들어간다.

---

## 8. 나중에 재검토할 것

- 지금은 팀 규모가 작다는 전제로 "가입 제한 없음"을 택했다. 팀이 커지거나 프로젝트 URL이
  새어나가는 게 걱정되면 이메일 도메인 화이트리스트를 `dev_handle_new_user()` 트리거에
  추가한다.
- 메시지 삭제/편집, 채팅방 나가기는 필요해지면 추가한다 — 지금은 "개발 중 소통"이 목적이라
  과설계하지 않는다.
