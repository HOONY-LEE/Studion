# 9단계 — 온보딩 + 빈 상태 + 마무리 다듬기

## 1. 목표

최초 실행 온보딩 마법사, 전 화면 빈 상태, 로컬 알림 설정을 붙이고, **1~8단계에서 만든 모든 화면을 HIG·접근성·문구 기준으로 훑어 다듬는다.**

**이 단계가 1차 개발의 마지막이다.** 새 기능을 붙이는 단계가 아니라 **이미 있는 것을 완성도로 끌어올리는 단계**다. 다듬기 도중 "이것도 있으면 좋겠다"가 떠오르면 만들지 말고 §8에 남긴다.

이 단계가 끝나면 앱을 처음 설치한 사용자가 온보딩을 거쳐(또는 전부 건너뛰고) 바로 쓸 수 있고, 데이터가 없는 화면이 하나도 비어 보이지 않으며, 원하면 오늘 계획·복습 알림을 받는다.

## 2. 선행 조건

- **8단계까지 전부 완료.** 이 단계는 앞 단계 결과물 전체를 대상으로 하므로 미완 단계가 있으면 착수하지 않는다.
- `EmptyStateView` 존재 (2단계)
- `SettingsView`가 `Form` 기반으로 교체되어 있음 (8단계)
- 시간표 등록 화면 존재 (5단계) — 온보딩 ③에서 **재사용**한다
- 복습 대상(due) 판정 로직 `ReviewScheduler.isDue` 존재 (6단계)
- `AcademicProfile`·`Semester`·`SchoolSubjectRecord`·`TimetableEntry` 모델 존재 (1단계)

## 3. 참조 문서

| 문서 | 섹션 | 중요도 |
|---|---|---|
| [04-ui-spec.md](../04-ui-spec.md) | §6 온보딩, §빈 상태 표, §7 화면 전환, §8 입력 검증 | ★ 필수 |
| [05-localization-a11y.md](../05-localization-a11y.md) | §2 접근성 **전체**, §5 문구(UX Writing) 원칙 | ★ 필수 |
| [00-product-principles.md](../00-product-principles.md) | §디자인 철학, §색채 원칙, §의사결정 기준 | ★ 필수 |
| [01-architecture.md](../01-architecture.md) | §Utilities는 순수해야 한다, §에러 처리 원칙 | ★ 필수 |
| [03-domain-logic.md](../03-domain-logic.md) | §3 스페이스드 리피티션 (복습 알림의 근거), §4 날짜 처리 공통 규칙 | ★ 필수 |
| [02-data-model.md](../02-data-model.md) | `AcademicProfile`, `Semester`, `WrongAnswerNote.nextReviewDate` | |
| [06-sync-and-backup.md](../06-sync-and-backup.md) | §2 로그인은 선택 기능이다, §5 프라이버시 표기 | |

## 4. 만들 파일

**신규**
```
Studion/Views/Onboarding/OnboardingView.swift            # 마법사 컨테이너 (4스텝)
Studion/Views/Onboarding/OnboardingDraft.swift           # @Observable 마법사 입력 상태
Studion/Views/Onboarding/OnboardingProfileStep.swift     # ① 학년/입학연도 → 등급제 제안
Studion/Views/Onboarding/OnboardingSubjectsStep.swift    # ② 이수 과목 [건너뛰기]
Studion/Views/Onboarding/OnboardingTimetableStep.swift   # ③ 시간표 [건너뛰기]
Studion/Views/Onboarding/OnboardingDoneStep.swift        # ④ 완료
Studion/Views/Settings/NotificationSettingsView.swift
Studion/Utilities/NotificationScheduler.swift
StudionTests/NotificationSchedulerTests.swift
```

**수정**
```
Studion/App/StudionApp.swift                # 온보딩 게이트 + scenePhase 알림 재스케줄
Studion/Views/Settings/SettingsView.swift   # "알림" 섹션 → NotificationSettingsView 연결
docs/tasks/README.md                        # 진행 상황 표 갱신
```

**다듬기 대상 (`Studion/Views/**` 전체)**

빈 상태 누락분 추가와 §5-5·§5-6의 다듬기 항목에 한해 기존 View 파일을 고칠 수 있다.
**기능·데이터 흐름·모델을 바꾸지 않는다.** 허용되는 변경은 아래뿐이다.

- `EmptyStateView` 추가/문구 교체
- 사용자 표시 문자열 교체 (문구 원칙 적용)
- 접근성 modifier 추가 (`.accessibilityLabel`, `.accessibilityHidden`, `.accessibilityElement`)
- 터치 타깃 확보 (`.frame(minWidth: 44, minHeight: 44)`), `.monospacedDigit()` 누락 보완
- `@Environment(\.accessibilityReduceMotion)` 분기 추가

이 범위를 넘는 수정이 필요해 보이면 **고치지 말고 §9에 따라 기록하고 묻는다.**

**Assets 추가**: 없음. 이 단계에서 새 색상을 정의하지 않는다.

**`project.yml` / `Info.plist`**: **둘 다 수정하지 않는다.** 근거는 §5-4 맨 아래.

## 5. 구현 명세

### 5-1. 온보딩 마법사

[04-ui-spec.md §6](../04-ui-spec.md#6-온보딩-9단계)이 명세다. 스텝을 늘리거나 줄이지 않는다.

```
① 학년 / 입학연도 → 등급제 자동 제안 (수동 변경 가능)
② 이수 과목 등록              [건너뛰기]
③ 학교/학원 시간표 최초 등록   [건너뛰기]
④ 완료
```

#### ★ 절대 지킬 것

- **로그인(Sign in with Apple) 단계를 넣지 않는다.** 버튼도, 안내 문구도, "나중에 로그인" 링크도 두지 않는다. 로그인은 설정 탭 안에만 존재한다 ([00 §2](../00-product-principles.md#2-로컬-우선), [06 §2](../06-sync-and-backup.md#2-로그인은-선택-기능이다-엄격)).
- **전부 건너뛰어도 앱이 100% 정상 동작한다.** 필수 입력으로 진행을 막지 않는다. ①도 손대지 않고 통과할 수 있다(기본값으로 저장).
- 잠금 아이콘·업셀 배너·"설정을 마쳐야 시작할 수 있어요" 류 문구를 두지 않는다.

#### `OnboardingView` — 컨테이너

- `TabView(selection:)` + `.tabViewStyle(.page(indexDisplayMode: .always))`. **커스텀 트랜지션을 만들지 않는다** ([04 §7](../04-ui-spec.md#7-화면-전환애니메이션)).
- 하단 주 버튼 1개: "다음" (④에서는 "시작하기").
- ②·③ 스텝에만 "건너뛰기"를 둔다. 위치를 두 스텝에서 동일하게 맞춘다.
- 스와이프·"이전"으로 되돌아갈 수 있다.
- 페이지 인디케이터는 장식이 아니라 진행 정보다. `.accessibilityLabel("4단계 중 2단계")` 형태로 현재 위치를 읽히게 한다.

#### `OnboardingDraft` — `@Observable` 화면 상태

[01 §경량 MV의 예외](../01-architecture.md#경량-mv-패턴--viewmodel을-기본으로-두지-않는다)가 명시적으로 허용하는 케이스다(다단계 입력). 단 **데이터 저장소 래퍼가 아니다** — `@Query` 결과를 담아두거나 `ModelContext`를 소유하지 않는다. 스텝 간 공유되는 입력값(학년·입학연도·등급제 선택·학기 term)만 갖는다.

#### ① `OnboardingProfileStep`

- 학년: `Picker` 1~3.
- 입학연도: `Picker` 또는 `Stepper`. **연도 목록을 하드코딩하지 않는다** — 현재 연도 기준으로 범위를 계산한다.
- **등급제 자동 제안**: `admissionYear >= 2025` → `fiveTier`, 미만 → `nineTier` ([02 §AcademicProfile](../02-data-model.md#academicprofile)).
  - 제안 결과를 **문장으로** 보여준다. 예: "2025년 입학이면 5등급제로 시작해요."
  - 바로 아래에 등급제 `Picker`를 두어 **수동으로 덮어쓸 수 있게** 한다. 제안은 제안일 뿐이다.
- 저장: "다음"을 누를 때 `AcademicProfile` **단일 인스턴스**를 갱신(없으면 생성)한다.

#### ② `OnboardingSubjectsStep`

- 과목이 들어갈 **학기를 화면에 명시**한다. 초기값: 연도 = `admissionYear + gradeLevel - 1`(계산값이지 추측이 아니다), 학기 = 1. 학기 1/2는 사용자가 그 자리에서 고른다.
  - **현재 월로 학기를 추측하지 않는다** ([00 §의사결정 기준 4](../00-product-principles.md#의사결정-기준-막혔을-때-이-순서로-판단)).
- 학기 생성 시 `AcademicProfile.gradingSystemType`을 **복사해 `Semester`에 고정 저장**한다 ([02 §Semester](../02-data-model.md#semester)).
- 입력 필드는 **과목명 + 이수단위 두 개뿐**이다. 원점수·성취도·석차등급을 온보딩에서 묻지 않는다(아직 시험을 보지 않았다). 상세 입력은 성적 탭에서 한다.
- `evaluationType`은 기본값(`achievementAndRank`)으로 저장한다. **"석차등급이 산출되나요?" 분기를 온보딩에서 묻지 않는다** — 3단계 과목 편집 화면에서 바꾼다.
- 검증은 3단계와 동일: 과목명 공백 불가, 이수단위 > 0 → **추가 버튼 비활성화**. 얼럿 금지 ([04 §8](../04-ui-spec.md#8-입력-검증-정책)).
- **과목 목록을 예시로도 내장하지 않는다.** "국어/수학/영어" 같은 추천 칩을 두지 않는다 ([00 원칙 7](../00-product-principles.md#7-과목-목록을-내장하지-않는다)).
- 추가한 과목이 0개여도 "다음"으로 넘어간다.

#### ③ `OnboardingTimetableStep`

- **5단계가 만든 시간표 등록 화면을 시트로 재사용한다.** 온보딩 전용 입력 폼을 새로 복제하지 않는다. 파일명이 스펙과 다르면 실제 존재하는 그 화면을 쓴다.
- 등록된 항목을 요약 리스트로 보여준다. 0개여도 "다음"으로 넘어간다.

#### ④ `OnboardingDoneStep`

- 입력한 것을 짧게 요약한다. 건너뛴 항목은 **"나중에 설정에서 추가할 수 있어요"** 로 안내한다. 미완료를 결함처럼 표시하지 않는다.
- "시작하기" → `hasCompletedOnboarding = true`.

#### 저장 시점과 완료 플래그

- **각 스텝에서 즉시 저장한다.** 마지막에 몰아서 저장하지 않는다(중도 이탈 시 유실 방지).
- 완료 플래그: `@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false`. 키 이름을 바꾸지 않는다.
- `StudionApp`에서 분기한다. `RootView`는 탭 구성 외의 책임을 갖지 않는다(2단계 규칙 유지).

```swift
// StudionApp.swift — 게이트는 여기 한 곳에만 둔다
if hasCompletedOnboarding { RootView() } else { OnboardingView() }
```

- 온보딩을 마치지 않고 앱을 종료하면 다음 실행에 처음부터 다시 보여준다. 단 **이미 저장된 값은 폼에 채워져 있어야** 한다.
- 설정에 "온보딩 다시 보기" 항목을 만들지 않는다 ([04 §4](../04-ui-spec.md#4-설정-settings-탭)의 섹션 표에 없다).

### 5-2. 빈 상태 전수 점검

[04-ui-spec.md §빈 상태](../04-ui-spec.md#빈-상태empty-state는-전-화면-필수)의 **표 7개를 하나씩 실제 화면에서 확인**한다. 이미 있으면 문구를 표와 **글자 그대로** 일치시키고, 없으면 추가한다.

| 화면 | 아이콘 | 문구 | 동작 |
|---|---|---|---|
| 오늘 – 할 일 | `checklist` | 오늘 할 일이 없어요 | 할 일 추가 |
| 오늘 – 시간표 | `calendar.badge.plus` | 시간표를 등록하면 오늘 일정이 보여요 | 시간표 등록 |
| 플래너 – 시간표 | `calendar` | 등록된 시간표가 없어요 | 시간표 추가 |
| 성적 – 내신 | `book.closed` | 이수 과목을 추가해 보세요 | 과목 추가 |
| 성적 – 모의고사 | `chart.line.uptrend.xyaxis` | 첫 모의고사 회차를 추가해 보세요 | 회차 추가 |
| 과목 상세 – 오답노트 | `doc.text.image` | 틀린 문제를 찍어 오답노트를 만들어 보세요 | 사진으로 추가 |
| 복습 – due 없음 | `checkmark.circle` | 오늘 복습할 카드가 없어요 | (동작 없음) |

**규칙**

- 각 빈 상태는 **아이콘 + 제목 + 설명 + 기본 동작 버튼 1개**다. 버튼을 2개 두지 않는다.
- 마지막 행(복습 due 없음)만 버튼이 없다. 없는 것이 정답이다 — 할 일이 없는데 일감을 만들어주지 않는다.
- 빈 리스트를 그냥 보여주는 화면이 하나도 남지 않아야 한다.
- 추가로 [04 §1](../04-ui-spec.md#1-오늘-today-탭): **오늘 탭의 세 섹션이 모두 비어 있으면 섹션별 빈 상태 3개를 쌓지 말고 통합 빈 상태 1개**를 보여준다. 이때 동작은 "시간표 등록"으로 보낸다(온보딩을 다시 띄우지 않는다).

### 5-3. `NotificationScheduler` — 로컬 알림

`Studion/Utilities/`에 둔다. **`import Foundation` + `import UserNotifications`만.** SwiftData·SwiftUI를 import하지 않고 `@Model` 객체를 파라미터로 받지 않는다 — `TextRecognizer`가 Vision만 import하는 것과 같은 예외 형태다 ([01 §Utilities는 순수해야 한다](../01-architecture.md#utilities는-순수해야-한다--가장-중요한-경계)).

**푸시 서버 없음. `UNUserNotificationCenter` 로컬 스케줄링만 한다.** APNs·원격 알림·Background Modes를 건드리지 않는다.

#### 인터페이스

| 멤버 | 역할 |
|---|---|
| `requestAuthorization() async -> Bool` | 권한 요청 |
| `authorizationStatus() async -> UNAuthorizationStatus` | 현재 상태 조회 |
| `schedulePlanReminder(hour:minute:) async` | 오늘 계획 리마인드 (매일 반복) |
| `scheduleReviewReminder(dueCardCount:hour:minute:) async` | 오답 복습 알림 |
| `cancelPlanReminder()` / `cancelReviewReminder()` | 취소 |
| `static func reviewReminderBody(dueCardCount:) -> String?` | 순수 함수. 문구 조립 |
| `static func triggerComponents(hour:minute:) -> DateComponents` | 순수 함수. 트리거 구성 |

**규칙**

- 권한 옵션은 `[.alert, .sound]`. **`.badge`를 요청하지 않는다.** 앱 아이콘에 밀린 카드 수를 띄우는 것은 압박이다 ([05 §5](../05-localization-a11y.md#5-문구ux-writing-원칙)).
- 알림 식별자는 **고정 상수 2개**(`plan-reminder`, `review-reminder`). 재스케줄 시 `removePendingNotificationRequests(withIdentifiers:)`로 먼저 지우고 다시 등록한다. **요청이 누적되어 알림이 여러 번 울리는 일이 없게 한다.**
- 계획 리마인드: `UNCalendarNotificationTrigger(dateMatching:repeats: true)`.
- 복습 알림: **due 카드가 있을 때만** 스케줄한다. `dueCardCount == 0`이면 스케줄하지 않고 기존 요청을 제거한다. due 판정은 `ReviewScheduler.isDue`(6단계)를 쓴다 — **판정 로직을 여기서 다시 구현하지 않는다** ([03 §3](../03-domain-logic.md#3-스페이스드-리피티션--reviewschedulerswift)).
- `dueCardCount`는 호출부(View)가 `@Query` 결과로 계산해 **Int로 넘긴다.** 스케줄러는 SwiftData를 모른다.
- 재스케줄 트리거는 **`StudionApp`의 `.onChange(of: scenePhase)` 한 곳**으로 모은다. 복습 화면·설정 화면 등 여러 곳에서 각자 부르지 않는다.

#### 문구 (★ 여기서 원칙이 가장 잘 드러난다)

| 하지 않는다 | 대신 |
|---|---|
| "3일째 복습을 밀렸습니다!" | "복습할 카드 5장" |
| "오늘 계획을 아직 안 세웠어요!" | "오늘 계획 확인하기" |
| "목표에 미달했습니다" | "목표까지 1등급" |

- **느낌표를 쓰지 않는다.** 담담한 평서문.
- `reviewReminderBody(dueCardCount:)`는 `0`이면 `nil`을 반환한다. 호출부는 `nil`이면 스케줄하지 않는다.
- 카드 수는 **사실만 말한다.** 밀린 일수·연속 기록·독려 문구를 넣지 않는다.

### 5-4. `NotificationSettingsView` — 알림 설정

[04 §4](../04-ui-spec.md#4-설정-settings-탭)의 "알림" 섹션 항목: **오늘 계획 리마인드 시간, 오답 복습 알림 on/off.** 항목을 늘리지 않는다.

- 저장은 `@AppStorage`. **`Date`는 `@AppStorage`가 직접 지원하지 않으므로** 시/분을 `Int` 두 개로 저장한다.

| 키 | 타입 | 기본값 |
|---|---|---|
| `planReminderEnabled` | `Bool` | `false` |
| `planReminderHour` / `planReminderMinute` | `Int` | 사용자가 고른 값. 앱이 임의의 "적당한 시간"을 밀어붙이지 않는다 |
| `reviewReminderEnabled` | `Bool` | `false` |
| `reviewReminderHour` / `reviewReminderMinute` | `Int` | 상동 |

- 토글을 켤 때 권한을 요청한다. 앱 첫 실행이나 온보딩에서 미리 요청하지 않는다 — **필요한 순간에 맥락과 함께** 묻는다.
- 시간 선택은 `DatePicker(displayedComponents: .hourAndMinute)`. 표시값은 로케일에 맡긴다(`formatted` 사용, 포맷 문자열 하드코딩 금지).

#### 권한 거부 처리 — 복구 가능한 실패다

[01 §에러 처리 원칙](../01-architecture.md#에러-처리-원칙): "알림 권한 거부처럼 복구 가능한 실패는 빈 상태 + 재시도 경로로 처리한다. 얼럿을 남발하지 않는다."

- **얼럿을 띄우지 않는다.** 거부해도 앱은 그대로 동작한다.
- 상태가 `.denied`일 때만 섹션 하단에 **인라인 안내 행 1개**를 노출한다. 무엇을 하면 되는지 알려준다:
  - 예: "iOS 설정에서 알림을 켜면 여기서 시간을 정할 수 있어요." + "설정 열기" 링크
  - `UIApplication.openSettingsURLString` 사용. View 파일에서 `import UIKit`이 필요하다(Views이므로 허용, Utilities에는 넣지 않는다).
- 거부 상태에서는 토글이 켜진 것처럼 보이지 않게 한다. 실제로 알림이 안 오는데 켜져 있는 UI가 최악이다.
- 권한 상태는 화면이 나타날 때(`.task`)와 앱이 foreground로 돌아올 때 갱신한다 — 사용자가 iOS 설정에서 바꾸고 돌아올 수 있다.

#### Info.plist / project.yml 수정 필요 여부 — **불필요**

명시적으로 확인하고 넘어간다.

- 로컬 알림은 **usage description 키를 요구하지 않는다.** `Info.plist`에 아무것도 추가하지 않는다. (카메라·사진 권한 문구는 6단계 소관이며 이 단계에서 건드리지 않는다.)
- Background Modes / Push Notifications entitlement **모두 불필요**하다. 로컬 스케줄링만 하기 때문이다. 추가하면 원격 알림 인프라가 있는 것처럼 보여 [06 §5 프라이버시 표기](../06-sync-and-backup.md#5-프라이버시-표기-배포-시)와 어긋난다.
- Provisional(임시) 알림·Critical Alert를 쓰지 않는다.
- `project.yml`의 `sources: path Studion`이 새 파일을 자동으로 포함하므로 **`project.yml` 자체는 편집하지 않고 `xcodegen generate`만 실행**한다.

### 5-5. 문구(UX Writing) 전면 점검

[05 §5](../05-localization-a11y.md#5-문구ux-writing-원칙)를 **전 화면에 소급 적용**한다. 이 앱은 성적을 다룬다. 문구가 압박이 되면 그것이 버그다.

| 하지 않는다 | 대신 |
|---|---|
| "목표에 미달했습니다" | "목표까지 1등급" |
| "3일째 밀렸습니다" | "복습할 카드 5장" |
| "실패", "부족", "경고", "주의" | 중립 서술 또는 다음 행동 제시 |
| 느낌표로 압박 | 담담한 평서문 |

- **빈 상태 문구는 다음 행동을 제안한다.** "아직 없습니다" ❌ → "틀린 문제를 찍어 오답노트를 만들어 보세요" ✅
- **에러 문구는 무엇을 하면 되는지 알려준다.** 원인만 말하고 끝내지 않는다.
- 전 화면 grep으로 잡아낸다 (§7의 감사 커맨드 참조).
- 문구를 바꿀 때도 **로컬라이징 가능한 리터럴**을 유지한다. 보간 문자열을 통째로 `Text`에 넘기지 않는다 ([05 §1](../05-localization-a11y.md#코드-규칙)).

### 5-6. HIG 다듬기 체크리스트

전 화면을 하나씩 열어 확인한다. 위반을 발견하면 §4의 "다듬기 대상" 범위 안에서 고치고, 범위를 넘으면 기록만 남긴다.

#### 구조

- 화면당 핵심 동작이 **1~2개**인가. 툴바에 버튼이 3개 이상 있는 화면이 있는가.
- 내비게이션 깊이가 **3뎁스 이내**인가 (성적 탭 → 과목 리스트 → 과목 상세 → 오답노트).
- 탭이 **정확히 4개**인가. 8단계까지 오면서 늘어나지 않았는지 확인한다.
- 추가 버튼이 화면당 1개인가 (플로팅 버튼과 툴바 버튼을 동시에 두지 않는다).

#### 애니메이션

- **커스텀 트랜지션이 하나도 없어야 한다.** 시스템 기본 전환만 쓴다.
- 리스트 추가/삭제는 SwiftData 변경에 따른 기본 애니메이션에 맡긴다.
- 스피너는 OCR **한 곳뿐**이다. 로컬 DB 조회에 로딩 표시를 두지 않는다.
- `@Environment(\.accessibilityReduceMotion)`을 존중한다. **플래시카드 넘김**(6단계)이 주 확인 대상 — `true`면 `withAnimation`을 생략한다.

#### 접근성

| 항목 | 확인 방법 |
|---|---|
| 아이콘 전용 버튼 | `.accessibilityLabel` **필수**. 툴바 `+`, 삭제, 세그먼트 아이콘 전부 |
| 등급 배지 | `.accessibilityLabel("수학, 2등급, 목표까지 1등급")` 처럼 **문장으로** 읽히게. 문구 원칙을 여기에도 적용 |
| 추정 등급 | 레이블에 "추정"이 **들리게** 한다. 시각 배지만으로 끝내지 않는다 |
| 차트 (4단계) | `.accessibilityChartDescriptor` 또는 최소한 요약 레이블 |
| 장식 이미지 | `.accessibilityHidden(true)` — `EmptyStateView` 아이콘 포함 |
| 터치 타깃 | 최소 **44×44pt**. 체크박스, 태그 칩, 히트맵 셀이 주 위험 지점. `.frame(minWidth: 44, minHeight: 44)`는 고정 크기가 아니라 접근성 최소치이므로 허용된다 |
| Dynamic Type | **AX5에서 전 화면 레이아웃 유지.** 고정 높이 컨테이너에 텍스트가 갇히지 않는가. 잘리는 행은 `ViewThatFits`로 세로 스택 대안 제공 |

#### 색상

- **색상에만 의존하는 구분이 없는지 재점검** ([05 §색상에만 의존하지 않기](../05-localization-a11y.md#색상에만-의존하지-않기)):

| 구분 | 함께 있어야 하는 비색상 단서 |
|---|---|
| 학교 vs 학원 일정 | 아이콘 + 텍스트 레이블 |
| 목표 달성 vs 미달 | 체크 아이콘 + "달성" 텍스트 |
| 월간 완료율 히트맵 | 셀 탭 시 수치 표시 |
| 확정 등급 vs 추정 | **"추정" 텍스트 배지** |

- **목표 미달을 의미색으로 표시하지 않는다** — 재확인. accent 빨강은 브랜드 강조색이며 경고가 아니다. 파괴적 동작은 아이콘·문구로 구분한다.
- 라이트/다크 **전 화면** 확인. 모든 커스텀 색상에 Light/Dark 두 값이 정의되어 있는가.
- 대비율 WCAG AA: 본문 4.5:1, 큰 텍스트 3:1. 다크모드에서 `.secondary` 위에 얹은 텍스트가 주 위험 지점이다.

### 5-7. 최종 원칙 감사

1차 개발 마지막 단계이므로 **전 코드베이스를 대상으로** 원칙 위반을 훑는다. 커맨드는 §7에 있다.

- `URLSession`·`Network` 프레임워크 코드가 **없다** (CloudKit 제외)
- 서드파티 의존성이 **없다** (`project.yml`에 `packages:` 없음)
- 하드코딩된 과목 목록·과목 분류 매핑표·등급컷 데이터가 **없다**
- 모든 추정치에 **"추정" 레이블**이 붙어 있다
- **애널리틱스·크래시 리포터가 없다** — [06 §5](../06-sync-and-backup.md#5-프라이버시-표기-배포-시)의 "수집하는 데이터: 없음" 표기가 **사실로 유지되는지** 확인한다. 이 표기를 사실로 유지하는 것이 원칙 1의 실질적 의미다
- `Utilities/`가 SwiftData·SwiftUI를 import하지 않는다 (`NotificationScheduler`의 `UserNotifications`, `TextRecognizer`의 `Vision`은 허용된 예외)
- 고정 폰트 크기(`.font(.system(size:))`)·코드 RGB(`Color(red:`)가 없다
- 로그인이 설정 탭 밖에 노출되지 않는다 (온보딩 포함)

## 6. 수용 기준

- [ ] 온보딩이 **4스텝**이고 [04 §6](../04-ui-spec.md#6-온보딩-9단계)의 순서와 일치한다
- [ ] 온보딩 어디에도 **로그인 단계·로그인 버튼·로그인 안내 문구가 없다**
- [ ] ②·③에 "건너뛰기"가 있고, **전부 건너뛰어도** 앱의 모든 기능이 동작한다
- [ ] ①도 값을 바꾸지 않고 통과할 수 있다 (필수 입력으로 막지 않는다)
- [ ] 입학연도 → 등급제 자동 제안이 동작하고 **수동으로 덮어쓸 수 있다**
- [ ] 온보딩에서 만든 학기에 `gradingSystemType`이 **복사되어 고정 저장**된다
- [ ] 온보딩이 과목 예시·추천 목록을 내장하지 않는다
- [ ] 완료 여부가 `@AppStorage("hasCompletedOnboarding")`로 관리되고, 게이트가 `StudionApp` 한 곳에만 있다
- [ ] 온보딩 중 각 스텝 값이 즉시 저장되고, 중도 종료 후 재진입 시 폼에 반영된다
- [ ] [04 빈 상태 표](../04-ui-spec.md#빈-상태empty-state는-전-화면-필수)의 **7개 화면 전부**에 빈 상태가 존재하고 문구가 표와 일치한다
- [ ] 각 빈 상태가 아이콘+제목+설명+기본 동작 버튼 **1개** 구성이다 (복습 due 없음만 버튼 없음)
- [ ] 오늘 탭 세 섹션이 모두 비었을 때 **통합 빈 상태 1개**가 나온다
- [ ] `NotificationScheduler`가 `Foundation`+`UserNotifications`만 import한다 (SwiftData·SwiftUI 없음)
- [ ] 알림 권한 옵션에 **`.badge`가 없다**
- [ ] 고정 식별자로 재스케줄하며 **요청이 중복 누적되지 않는다**
- [ ] 복습 알림이 **due 카드가 있을 때만** 스케줄된다 (`dueCardCount == 0`이면 기존 요청 제거)
- [ ] 알림 문구에 **느낌표와 압박 표현이 없다** ("복습할 카드 5장" 형태)
- [ ] 권한 거부 시 **얼럿을 띄우지 않고** 인라인 안내 + 설정 열기 경로를 제공한다
- [ ] 권한 거부 상태에서 토글이 켜진 것처럼 보이지 않는다
- [ ] `Info.plist`·`project.yml`을 수정하지 않았다 (§5-4 근거)
- [ ] 금지 문구("미달", "실패", "부족", "경고", "밀렸", 느낌표)가 전 화면에서 사라졌다
- [ ] 화면당 핵심 동작 1~2개, 내비게이션 3뎁스 이내, 탭 4개가 유지된다
- [ ] 커스텀 트랜지션이 없고, 스피너가 OCR 한 곳에만 있다
- [ ] 아이콘 전용 버튼 전부에 `.accessibilityLabel`이 있다
- [ ] 등급 배지가 문장으로 읽히고, 추정치는 레이블에서도 "추정"이 들린다
- [ ] 장식 이미지에 `.accessibilityHidden(true)`가 붙어 있다
- [ ] 모든 터치 타깃이 44×44pt 이상이다
- [ ] Dynamic Type **AX5에서 전 화면** 레이아웃이 유지된다
- [ ] `accessibilityReduceMotion`이 존중된다 (플래시카드 넘김 확인)
- [ ] 색상에만 의존하는 구분이 없다 (학교/학원, 달성/미달, 히트맵, 확정/추정)
- [ ] 라이트/다크 **전 화면** 스크린샷을 확인했고 대비율이 WCAG AA를 만족한다
- [ ] 목표 미달이 빨간색으로 표시되지 않는다
- [ ] `URLSession`·네트워크 코드가 없다 (CloudKit 제외)
- [ ] 서드파티 의존성이 없다 (`project.yml`에 `packages:` 없음)
- [ ] 애널리틱스·크래시 리포터가 없어 [06 §5](../06-sync-and-backup.md#5-프라이버시-표기-배포-시) 프라이버시 표기가 **사실로 유지된다**
- [ ] 하드코딩된 과목 목록·등급컷이 없다
- [ ] 로그인이 설정 탭 밖에 노출되지 않는다
- [ ] [tasks/README.md](README.md#진행-상황)의 진행 상황 표를 갱신했다
- [ ] 원칙 체크 ([tasks/README.md](README.md#3-원칙-체크-매-단계-필수)) 통과

## 7. 검증 절차

```bash
cd /Users/sunghoon/Desktop/Studion
xcodegen generate
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|warning:|BUILD"
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -40
```

### 최종 원칙 감사 (전부 "결과 없음"이어야 한다)

```bash
cd /Users/sunghoon/Desktop/Studion
grep -rn "URLSession\|NWConnection\|import Network" Studion/          # 네트워크 없음
grep -rn "Firebase\|Crashlytics\|Sentry\|Amplitude\|Analytics" Studion/  # 트래커 없음
grep -rn "Color(red:" Studion/                                        # RGB 하드코딩 없음
grep -rn "font(.system(size:" Studion/                                # 고정 폰트 없음
grep -rn "\.frame(width:\|\.frame(height:" Studion/                   # 고정 크기 없음
grep -rn "import SwiftData\|import SwiftUI" Studion/Utilities/        # Utilities 순수성
grep -n "packages:" project.yml                                       # SPM 의존성 없음
grep -rn "미달\|실패했\|부족합\|경고\|밀렸\|!" Studion/Views/           # 압박 문구·느낌표 없음
```

마지막 grep은 오탐이 나온다(`!` 는 Swift 문법에도 쓰인다). **사용자에게 표시되는 문자열만** 골라 판단한다.

### 온보딩 시나리오 (스크린샷 필수)

시뮬레이터에서 **앱을 삭제 후 재설치**해 최초 실행 상태로 만든다.

1. 최초 실행 → 온보딩 ①이 나오는가. **로그인 화면이 뜨지 않는가**
2. ①에서 입학연도 2025 → "5등급제" 제안, 2024 → "9등급제" 제안
3. ①에서 제안을 수동으로 뒤집을 수 있는가
4. ②·③을 **모두 건너뛰기** → ④ → "시작하기" → 앱이 정상 동작하는가
5. 앱 삭제 후 재설치 → 이번엔 ②에서 과목 2개, ③에서 시간표 1개 등록 → 성적/플래너 탭에 실제로 반영되는가
6. 온보딩 ②까지 진행하고 앱 강제 종료 → 재실행 시 온보딩이 다시 나오되 **입력값이 남아 있는가**
7. 완료 후 재실행 → 온보딩이 다시 나오지 않는가

### 빈 상태 시나리오

8. 데이터가 하나도 없는 상태에서 **7개 화면을 모두 방문**해 빈 상태와 문구를 표와 대조
9. 오늘 탭 세 섹션이 모두 빌 때 통합 빈 상태 1개가 나오는가

### 알림 시나리오

10. 설정 → 알림 → 계획 리마인드 토글 ON → 권한 다이얼로그 → **허용** → 시간 선택 반영
11. 앱 삭제 후 재설치 → 토글 ON → 권한 **거부** → 얼럿이 뜨지 않고 인라인 안내가 나오는가, 토글이 꺼진 상태로 남는가
12. iOS 설정에서 알림을 켜고 돌아왔을 때 안내가 사라지는가
13. due 카드 0장에서 복습 알림 토글 ON → 알림이 스케줄되지 않는가 (`getPendingNotificationRequests` 로그로 확인)
14. due 카드 3장 생성 후 → "복습할 카드 3장" 문구로 스케줄되는가
15. 설정 화면을 여러 번 오가도 pending 요청이 **각 1개씩만** 남는가

### 접근성·표시 검증

16. **전 화면 스크린샷을 라이트/다크 둘 다** 남긴다 (최종 검토 자료)
17. Dynamic Type **AX5**로 전 화면 순회 — 잘림·겹침 없음
18. VoiceOver로 오늘·성적·복습 탭 순회 — 아이콘 버튼과 등급 배지가 의미 있게 읽히는가
19. Reduce Motion ON → 플래시카드 넘김 확인

> 스크린샷은 검토용이다. **저장소에 커밋하지 않는다.**

## 8. 범위 밖 (하지 않는다)

- **콘텐츠 시스템**(단어장·듣기·문제은행) — [07-content-system-future.md](../07-content-system-future.md), 1차 범위 밖
- **iPad 최적화** (`TabView` → `NavigationSplitView`) — 2차 플랫폼 단계
- **Android** — 3차 플랫폼 단계
- **위젯 / 워치앱 / 라이브 액티비티**
- **인앱결제**
- **리포트 외부 공유** (OS 공유 시트 포함)
- **실제 영문 번역 문구 확정** — 8단계에서 String Catalog 구조만 잡았다. 번역은 1차 범위 밖 ([05 §1](../05-localization-a11y.md#한국-교육-특화-용어--별도-취급))
- 원격 푸시 알림·APNs·Background Modes
- 설정의 "온보딩 다시 보기" 항목
- 다듬기 중 발견한 **기능 개선 아이디어** — 구현하지 말고 기록만 남긴다

## 9. 막히면

- **알림 권한 요청 문구 (★ 사용자 확인 필요)**: 시스템 권한 다이얼로그 위에 사전 안내(pre-permission) 화면을 둘지, 어떤 문구로 목적을 설명할지는 **임의로 정하지 않는다.** 이 앱은 압박 문구를 엄격히 금지하므로 문구 톤에 사용자 판단이 필요하다. 초안을 만들어 확인받고 진행한다.
- **온보딩에서 권한을 미리 요청하고 싶어질 때**: 하지 않는다. 설정에서 토글을 켜는 순간에만 요청한다.
- **온보딩에 로그인을 넣으면 편할 것 같을 때**: 넣지 않는다. 이건 협상 대상이 아니다 ([00 §2](../00-product-principles.md#2-로컬-우선), [06 §2](../06-sync-and-backup.md#2-로그인은-선택-기능이다-엄격)).
- **온보딩 ②에서 과목 예시를 보여주면 친절할 것 같을 때**: 보여주지 않는다. 과목 목록을 내장하지 않는다는 원칙 7이 UI 힌트에도 적용된다.
- **빈 상태 문구를 더 다듬고 싶을 때**: [04 표](../04-ui-spec.md#빈-상태empty-state는-전-화면-필수)의 문구를 그대로 쓴다. 표에 없는 새 빈 상태가 필요하면 문구를 지어내지 말고 묻는다.
- **다듬다가 구조를 바꿔야 할 것 같을 때**: 바꾸지 않는다. §4의 다듬기 범위를 넘는 변경은 기록하고 묻는다. 마지막 단계에서 구조를 흔들면 앞 단계 검증이 무효가 된다.
- **AX5에서 도저히 안 들어가는 레이아웃**: 폰트를 줄이지 않는다. `ViewThatFits`로 세로 스택 대안을 준다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**

---

## 1차 개발 완료 후 — 다음 후보

이 단계를 마치면 1차(iPhone) 개발이 끝난다. 이후 순서는 [00 §플랫폼 로드맵](../00-product-principles.md#플랫폼-로드맵) 기준으로:

1. **iPad 최적화** — `TabView` → `NavigationSplitView`. `RootView`만 고치면 되도록 1차에서 격리해 두었다
2. **콘텐츠 시스템** — [07-content-system-future.md](../07-content-system-future.md). 개인 데이터 저장소와 분리된 별도 컨테이너
3. **Android** — `Utilities/`의 순수 Swift를 Kotlin으로 포팅. 동기화 체계는 그 시점에 별도 검토

**착수 전에 사용자에게 확인받는다.** 순서를 자의로 정하지 않는다.
