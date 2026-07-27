# 5단계 — 플래너 (시간표 + 일간/주간/월간)

## 1. 목표

**먼저 날짜·시간 계산을 순수 Swift 헬퍼로 뽑아 단위 테스트로 검증한 뒤**, 그 위에 플래너 탭 UI를 올린다.
시간표 등록과 일간/주간/월간 뷰 전환, 그리고 오늘 탭의 시간표 요약·할 일 섹션 연결까지가 이 단계다.

이 단계가 끝나면 학교/학원 시간표를 등록하고, 일간 타임라인에서 오늘 일정과 할 일을 보고,
좌우 스와이프로 날짜를 옮기고, 주간·월간으로 전환해 완료율을 한눈에 볼 수 있다.

> **순서를 지킨다: 날짜 헬퍼 → 테스트 → UI.** 뷰 안에서 날짜 계산을 즉석으로 짜지 않는다.
> 이 앱의 버그는 대부분 날짜·타임존에서 나온다 ([03 §4](../03-domain-logic.md#4-날짜-처리-공통-규칙)).

## 2. 선행 조건

- 2단계 완료 (`RootView` 4탭, `EmptyStateView` 존재)
- `PlannerView`·`TodayView`가 빈 상태 플레이스홀더 — **이 단계에서 내용을 채운다**
- 모델 `TimetableEntry`, `PlanItem`, `TimetableEntryType` 존재 (1단계)

> **5단계는 3·4단계와 파일이 겹치지 않아 병렬 실행이 가능하다.**
> 3·4단계는 `Views/Grades/`·`Utilities/GradeCalculator`·`ProgressCalculator`를 건드리고,
> 5단계는 `Views/Planner/`·`Views/Today/`·`Utilities/PlannerDateHelper`를 건드린다.
> 겹치는 것은 `project.yml`(양쪽이 파일을 추가하므로)과 `Views/Components/` 폴더뿐이다.
> 다른 워크트리에서 병렬로 돌린다면 **머지 시 `project.yml` 충돌을 반드시 확인**한다
> ([tasks/README.md §병렬](README.md#병렬-5단계만-해당)).
> 오늘 탭의 **③ 이번 학기 진척 요약**은 4단계 소관이므로 이 단계에서 만들지 않는다.

## 3. 참조 문서

| 문서 | 섹션 | 중요도 |
|---|---|---|
| [03-domain-logic.md](../03-domain-logic.md) | §4 날짜 처리 공통 규칙 **전체**, §5 테스트 요구사항 | ★ 필수 |
| [04-ui-spec.md](../04-ui-spec.md) | §2 플래너 탭 **전체**, §1 오늘 탭 ①②, §8 입력 검증 | ★ 필수 |
| [02-data-model.md](../02-data-model.md) | `TimetableEntry`, `PlanItem`, `TimetableEntryType` | ★ 필수 |
| [01-architecture.md](../01-architecture.md) | §Utilities는 순수해야 한다, §iPad 이식 전략 | ★ 필수 |
| [05-localization-a11y.md](../05-localization-a11y.md) | §색상에만 의존하지 않기, §컬러 팔레트, §터치 타깃 | ★ 필수 |

## 4. 만들 파일

**신규**
```
Studion/Utilities/PlannerDateHelper.swift            # 순수 Swift. Calendar 주입
Studion/Views/Planner/DailyPlannerView.swift         # 타임라인 + 해당일 할 일
Studion/Views/Planner/WeeklyPlannerView.swift        # 요일별 컬럼
Studion/Views/Planner/MonthlyPlannerView.swift       # 캘린더 그리드 + 농도
Studion/Views/Planner/TimetableFormView.swift        # 시간표 등록/편집
Studion/Views/Planner/TimetableListView.swift        # 등록된 시간표 관리(삭제·편집 진입)
Studion/Views/Today/PlanItemFormView.swift           # 할 일 추가/편집
Studion/Views/Components/TimetableBlockView.swift    # 시간표 블록 1개 (아이콘+레이블+색)
Studion/Views/Components/PlanItemRow.swift           # 체크박스 + 제목
Studion/Views/Components/CompletionHeatCell.swift    # 월간 그리드 한 칸
StudionTests/PlannerDateHelperTests.swift
```

**수정**
```
Studion/Views/Planner/PlannerView.swift   # 일간/주간/월간 세그먼트 + 3뷰 연결
Studion/Views/Today/TodayView.swift       # ① 오늘의 시간표 요약 + ② 오늘의 할 일 연결
```

**Assets 추가**
```
Resources/Assets.xcassets/ScheduleSchool.colorset    # Light/Dark 둘 다 정의
Resources/Assets.xcassets/ScheduleAcademy.colorset   # Light/Dark 둘 다 정의
```

여기 없는 파일을 건드리지 않는다. 특히 `Views/Grades/`와 `Models/`는 이 단계에서 손대지 않는다.

## 5. 구현 명세

### 5-1. `PlannerDateHelper.swift` — 순수 Swift (★ 가장 중요)

[03 §4](../03-domain-logic.md#4-날짜-처리-공통-규칙)의 5개 규칙을 **코드로 강제하는 지점**이다. 뷰가 날짜를 직접 계산하지 않고 전부 여기를 거치게 한다.

**철칙**
- `import Foundation`만. **SwiftData·SwiftUI를 import하지 않는다.**
- `@Model` 객체를 파라미터로 받지 않는다. 값 타입만 받는다.
- **`Calendar`를 반드시 파라미터로 주입받는다.** 함수 안에서 `Calendar.current`를 참조하지 않는다.
- 유효하지 않은 입력에 `nil` 또는 빈 배열을 반환한다. 크래시하지 않는다.

구현할 것:

| 시그니처 | 규칙 |
|---|---|
| `func startOfDay(_ date: Date, calendar: Calendar) -> Date` | 저장·비교의 단일 관문 |
| `func isSameDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool` | `startOfDay` 정규화 후 비교. `Date` 직접 비교 금지 |
| `func addingDays(_ days: Int, to date: Date, calendar: Calendar) -> Date` | 결과도 `startOfDay` 정규화 |
| `func calendarWeekday(of date: Date, calendar: Calendar) -> Int` | **1=일요일 … 7=토요일** (Calendar 컨벤션) |
| `func displayIndex(forCalendarWeekday weekday: Int) -> Int` | 표시 순서 **월요일 시작**: 월=0 … 일=6. `(weekday + 5) % 7` |
| `func calendarWeekday(forDisplayIndex index: Int) -> Int` | 위의 역변환. 왕복 항등이어야 한다 |
| `func weekDates(containing date: Date, calendar: Calendar) -> [Date]` | 월요일부터 7일. 전부 `startOfDay` 정규화 |
| `func monthGridDates(for date: Date, calendar: Calendar) -> [Date]` | 월요일 시작 그리드. 앞뒤 이웃 달 날짜로 채워 **7의 배수** 길이 |
| `func minutesOfDay(_ date: Date, calendar: Calendar) -> Int` | **시·분 컴포넌트만** 추출해 `hour * 60 + minute` |
| `func isValidTimeRange(start: Date, end: Date, calendar: Calendar) -> Bool` | `minutesOfDay(start) < minutesOfDay(end)`. 날짜 부분은 무시 |
| `func layout(_ ranges: [TimeRange]) -> [BlockLayout]` | 겹침 → 나란히 배치 (아래) |
| `func heatLevel(completed: Int, total: Int) -> Int` | 완료율 → 농도 단계 (아래) |

**요일 변환이 이 단계의 핵심 함정이다.** 모델은 Calendar 컨벤션(1=일)으로 저장하고, 화면은 월요일부터 보여준다.
변환은 **View가 아니라 이 헬퍼에서만** 한다. 뷰 코드에 `% 7` 같은 산술이 흩어지면 안 된다.

#### 겹침 배치 — `layout(_:)`

```swift
struct TimeRange {
    let id: UUID
    let startMinutes: Int   // minutesOfDay 결과
    let endMinutes: Int
}

struct BlockLayout {
    let id: UUID
    let column: Int         // 0부터
    let columnCount: Int    // 같은 겹침 그룹의 총 컬럼 수
}
```

- 시작 시각 오름차순(같으면 종료 시각 오름차순)으로 정렬한 뒤, **겹치지 않는 가장 작은 인덱스 컬럼**에 배치한다.
- 서로 이어진 겹침 그룹(연결 성분) 단위로 `columnCount`를 계산해, 그룹 안의 블록이 **모두 같은 너비**를 갖게 한다.
- **겹침을 숨기거나 병합하지 않는다.** 3개가 겹치면 3열로 나란히 나온다 ([04 §2](../04-ui-spec.md#2-플래너-planner-탭)).
- 경계 접촉(`a.end == b.start`)은 **겹침이 아니다.**

#### 완료율 농도 — `heatLevel(completed:total:)`

월간 히트맵의 유일한 진입점. 반환값 `0...5`.

| 조건 | 단계 | 표시 |
|---|---|---|
| `total <= 0` | 0 | **색 없음. 테두리만** |
| `r == 0` | 1 | 가장 옅음 |
| `0 < r < 0.5` | 2 | |
| `0.5 <= r < 0.75` | 3 | |
| `0.75 <= r < 1.0` | 4 | |
| `r >= 1.0` | 5 | 가장 진함 |

`r = completed / total`. `completed`는 `0...total`로 클램프한다(음수·초과 입력도 크래시 없이 처리).
**단계 → 투명도 매핑은 View의 책임이다.** 헬퍼는 색을 모른다(SwiftUI import 금지).

### 5-2. `PlannerDateHelperTests.swift`

- Swift Testing (`@Test` / `#expect`). XCTest 금지.
- **고정 캘린더를 주입한다**: `Calendar(identifier: .gregorian)` + `timeZone = TimeZone(identifier: "Asia/Seoul")!` + `locale = Locale(identifier: "ko_KR")`.
  타임존을 고정하지 않으면 이 테스트는 CI에서 무의미해진다.
- 최소 테스트 목록:

| 대상 | 케이스 |
|---|---|
| `isSameDay` | 같은 날 00:00 vs 23:59 → `true`, 자정 직전/직후 → `false` |
| 요일 변환 | 일요일(1)→6, 월요일(2)→0, 토요일(7)→5. `1...7` 전부 왕복 항등 |
| `weekDates` | 결과 7개, 첫 원소가 월요일, 전부 `startOfDay`, 오름차순 |
| `weekDates` | **일요일을 넣었을 때** 그 주의 월요일이 나오는지 (가장 틀리기 쉬운 케이스) |
| `monthGridDates` | 길이가 7의 배수, 첫 원소가 월요일, 해당 월 1일과 말일을 모두 포함 |
| `monthGridDates` | **월 1일이 일요일인 달**과 **말일이 월요일인 달** 경계 |
| `minutesOfDay` | 09:30 → 570. **날짜가 달라도 같은 값**이 나오는지 |
| `isValidTimeRange` | 09:00~10:00 `true`, 10:00~10:00 `false`, 10:00~09:00 `false`, **날짜가 서로 다른 두 Date여도 시·분만으로 판정** |
| `layout` | 겹침 없음 → 전부 `column 0`, `columnCount 1` |
| `layout` | 2개 완전 겹침 → `columnCount 2`, 컬럼 0/1 |
| `layout` | 3개 겹침 → `columnCount 3` |
| `layout` | 경계 접촉(`10:00~11:00`, `11:00~12:00`) → 겹침 아님 |
| `heatLevel` | 위 표 6행 전부 + `completed > total` 클램프 + 음수 클램프 |
| `addingDays` | +1 / −1 / 0, **월말·연말 넘김**, 결과가 정규화되어 있는지 |

> **DST가 없는 `Asia/Seoul`이라 안전해 보여도 `addingDays`를 `+86400`으로 구현하지 않는다.** 반드시 `calendar.date(byAdding:)`을 쓴다.

**테스트가 먼저 통과해야 UI 작업을 시작한다.**

### 5-3. `PlannerView` — 상단 세그먼트

```
Picker("", selection: $mode) { "일간" / "주간" / "월간" }.pickerStyle(.segmented)
```

- 세 뷰가 **하나의 선택 날짜 상태(`@State private var selectedDate: Date`)를 공유**한다.
  주간에서 셀을 탭해 일간으로 가면 그 날짜가 유지되고, 월간에서 날짜를 탭하면 일간으로 전환된다.
- `selectedDate`는 항상 `PlannerDateHelper.startOfDay`로 정규화된 값만 담는다.
- 툴바에 `+` **버튼 1개**. 탭하면 `Menu`로 "시간표 추가" / "할 일 추가"를 고른다.
  플로팅 버튼을 추가하지 않는다 ([04 §1 규칙](../04-ui-spec.md#1-오늘-today-탭)).
- 툴바에 "시간표 관리"(`TimetableListView`) 진입점을 하나 둔다. 세그먼트와 겹치지 않게 배치한다.
- 세그먼트 선택값은 화면 상태다. 영속화하지 않는다(`@AppStorage` 쓰지 않는다 — 8단계 소관).

### 5-4. `DailyPlannerView` — 타임라인 + 할 일

**구성 (위 → 아래)**
1. 날짜 헤더 (`date.formatted(.dateTime.year().month().day().weekday())`)
2. 시간대별 타임라인 — 해당 요일의 `TimetableEntry` 블록
3. 해당일 할 일 리스트 — `PlanItem`

**타임라인**
- `@Query`로 `TimetableEntry` 전체를 가져와 `calendarWeekday(of: selectedDate)`와 `dayOfWeek`가 같은 것만 거른다.
- 표시 시간 범위는 **하드코딩하지 않는다.** 그날 등록된 블록의 최소 시작 ~ 최대 종료를 시간 단위로 올림/내림해 결정한다.
  블록이 없으면 타임라인 대신 `EmptyStateView`(`calendar`, "등록된 시간표가 없어요", 동작: 시간표 추가).
- 블록 배치는 `PlannerDateHelper.layout(_:)` 결과를 그대로 쓴다. 뷰에서 겹침을 다시 계산하지 않는다.
- 세로 축 스케일은 **고정 pt가 아니라 `@ScaledMetric`** 으로 잡는다.
  ```swift
  @ScaledMetric(relativeTo: .body) private var hourHeight: CGFloat = 56
  ```
  가로 폭은 `GeometryReader`로 컨테이너 너비를 받아 `columnCount`로 나눈다. **고정 width 금지** (iPad 대비).
- 블록이 너무 짧아 글자가 잘리는 경우를 대비해 **최소 높이도 `@ScaledMetric`** 으로 준다.

**할 일 리스트**
- `@Query`로 `PlanItem`을 가져와 `isSameDay(item.date, selectedDate)`로 거른다.
  **`Date` 직접 비교나 `>=`/`<` 구간 비교를 쓰지 않는다.**
- 각 행은 `PlanItemRow`. 탭하면 완료 토글, **즉시 저장**한다. 별도 저장 버튼을 두지 않는다.
- 스와이프 삭제 지원. 할 일이 없으면 `EmptyStateView`(`checklist`, "오늘 할 일이 없어요", 동작: 할 일 추가).

**좌우 스와이프로 전날/다음날**
- `TabView(selection:).tabViewStyle(.page(indexDisplayMode: .never))` 또는 `DragGesture` + `withAnimation`.
- 날짜 이동은 `PlannerDateHelper.addingDays(±1, to:)`만 쓴다.
- 스와이프 외에 **좌우 화살표 버튼도 제공**한다. 제스처만으로 접근 가능한 기능을 두지 않는다(VoiceOver·스위치 컨트롤 사용자).
- 날짜가 바뀌면 `.accessibilityAnnouncement` 수준으로 새 날짜가 읽히게 헤더에 `.accessibilityLabel`을 단다.

### 5-5. `WeeklyPlannerView` — 요일별 컬럼

- `weekDates(containing: selectedDate)`로 **월요일 시작 7일**을 얻는다.
- 컬럼 헤더: 요일 약칭 + 일. 오늘 날짜 컬럼을 시각적으로 강조하되 **색상만으로 구분하지 않는다**(굵기/테두리 병행).
- 각 셀에 표시할 것:
  - 할 일 **개수** (`3개`)
  - **완료율** (`2/3`) — `.monospacedDigit()`
  - 해당 요일 시간표 블록 요약 (제목 최대 몇 개 + "외 N개")
- 셀을 탭하면 `selectedDate`를 그 날로 바꾸고 **일간 뷰로 전환**한다.
- 가로 7컬럼이 좁으므로 `ViewThatFits`로 **세로 리스트 대안**을 제공한다 (Dynamic Type AX5·좁은 화면 대응).
- 좌우 스와이프로 전주/다음주 이동을 지원한다면 `addingDays(±7,)`을 쓴다.

### 5-6. `MonthlyPlannerView` — 캘린더 그리드 + 색 농도

- `monthGridDates(for: selectedDate)`를 `LazyVGrid(columns: 7)`에 그대로 흘린다. 그리드 칸 수를 뷰에서 계산하지 않는다.
- 요일 헤더는 **월요일 시작**. `calendarWeekday(forDisplayIndex:)`로 심볼을 얻는다.
- 각 칸은 `CompletionHeatCell`. 농도는 `heatLevel(completed:total:)` 결과를 투명도로 매핑한다.

| level | 채움 |
|---|---|
| 0 | **채움 없음. 테두리만** (데이터 없는 날) |
| 1 | `Color.accentColor.opacity(0.12)` |
| 2 | `opacity(0.28)` |
| 3 | `opacity(0.45)` |
| 4 | `opacity(0.65)` |
| 5 | `opacity(0.90)` |

- **accent color(`#FF212B`) 단색 농도만** 쓴다. 여러 색을 섞지 않는다 ([04 §2](../04-ui-spec.md#2-플래너-planner-탭), [05 §3](../05-localization-a11y.md#3-컬러-팔레트)).
- 코드에 RGB 하드코딩 금지. `Color.accentColor` 또는 `Color("AccentColor")`.
- **색상만으로 정보를 전달하지 않는다**: 칸을 탭하면 수치를 보여주고(선택 → 하단에 `2/3 완료` 표시 후 일간 진입),
  각 칸에 `.accessibilityLabel("3월 12일, 할 일 3개 중 2개 완료")` 형태의 문장 레이블을 단다 ([05 §색상에만 의존하지 않기](../05-localization-a11y.md#색상에만-의존하지-않기)).
- 이웃 달 채움 날짜는 `.foregroundStyle(.tertiary)`로 낮추되 탭은 허용한다.
- 칸 크기는 `LazyVGrid`의 `.flexible()`과 `.aspectRatio(1, contentMode: .fit)`로 잡는다. **고정 width/height 금지.**
- 터치 타깃 44×44pt 미만이 되지 않게 한다. 좁아지면 `ViewThatFits`로 대안을 준다.

### 5-7. `TimetableFormView` — 시간표 등록/편집

입력 필드 ([04 §2](../04-ui-spec.md#2-플래너-planner-탭), [02 §TimetableEntry](../02-data-model.md#timetableentry)):

| 필드 | 컨트롤 | 기본값 |
|---|---|---|
| 유형 | `Picker`(세그먼트) 학교 / 학원 | 학교 |
| 과목명·학원명 | `TextField` | 빈 문자열 |
| 요일 | `Picker` — **표시는 월~일 순서**, 저장은 Calendar 컨벤션 | 오늘 요일 |
| 시작 시간 | `DatePicker(displayedComponents: .hourAndMinute)` | |
| 종료 시간 | `DatePicker(displayedComponents: .hourAndMinute)` | |
| 매주 반복 | `Toggle` | **`true` (기본값 매주 반복)** |

**검증** ([04 §8](../04-ui-spec.md#8-입력-검증-정책))
- 제목이 공백만이면 **저장 버튼 비활성화**.
- `isValidTimeRange(start:end:)`가 `false`면 **저장 버튼 비활성화 + 인라인 안내 문구**.
  얼럿을 띄우지 않는다.
- **자정 넘김(예: 22:00~01:00)은 1차 범위 밖이다.** 입력 시점에 막고 인라인으로 안내한다.
  안내 문구는 원인만 말하지 말고 다음 행동을 준다: "종료 시간은 시작 시간보다 뒤여야 해요. 자정을 넘는 일정은 두 개로 나눠 등록해 주세요."
- 요일 Picker는 표시 순서와 저장값을 **반드시 헬퍼로 변환**한다. `tag`에 표시 인덱스를 그대로 넣고 저장하는 실수를 하지 않는다.

### 5-8. `TimetableListView` — 등록된 시간표 관리

- 요일별(월요일 시작) 섹션으로 묶어 보여준다. 각 행은 시간 · 제목 · 유형 아이콘+레이블.
- 스와이프 삭제, 탭하면 `TimetableFormView` 편집 모드.
- 비어 있으면 `EmptyStateView`(`calendar`, "등록된 시간표가 없어요", 동작: 시간표 추가).
- `repeatsWeekly == false`인 항목은 행에 "반복 안 함" 보조 레이블을 단다 (→ §9).

### 5-9. `PlanItemFormView` — 할 일 추가/편집

| 필드 | 컨트롤 |
|---|---|
| 제목 | `TextField` |
| 날짜 | `DatePicker(displayedComponents: .date)` |
| 관련 과목 (선택) | `TextField` — 자유 입력 |

- **제목이 공백만이면 저장 버튼 비활성화.**
- **`date`는 저장 직전에 `PlannerDateHelper.startOfDay`로 정규화한다** ([03 §4-2](../03-domain-logic.md#4-날짜-처리-공통-규칙)). 이 정규화를 빠뜨리면 하루 단위 조회가 조용히 어긋난다.
- 관련 과목은 자유 입력이다. **과목 마스터 테이블이나 하드코딩된 과목 목록을 만들지 않는다.**

### 5-10. 공통 컴포넌트

#### `TimetableBlockView`
- 표시: **SF Symbol 아이콘 + 유형 텍스트 레이블 + 제목 + 시간**.
- 배경색은 유형별 색(`ScheduleSchool` / `ScheduleAcademy`).
- **색상만으로 학교/학원을 구분하지 않는다.** 아이콘과 텍스트 레이블을 항상 함께 둔다 ([05 §색상에만 의존하지 않기](../05-localization-a11y.md#색상에만-의존하지-않기)).
  - 학교: `building.columns` + "학교"
  - 학원: `book` + "학원"
- 블록이 좁을 때를 대비해 `ViewThatFits`로 축약 레이아웃을 제공한다. 텍스트를 고정 높이에 가두지 않는다.
- `.accessibilityElement(children: .combine)` + 문장 레이블: `"학교, 수학, 오전 9시 ~ 오전 9시 50분"`.

#### `PlanItemRow`
- 체크박스(`circle` / `checkmark.circle.fill`) + 제목 + 관련 과목(있으면 `.caption` `.secondary`).
- 완료 항목은 `.strikethrough()` + `.secondary`. **완료/미완료를 색상만으로 구분하지 않는다.**
- 미완료를 빨간색으로 표시하지 않는다.
- 터치 타깃 **44×44pt 이상**을 보장한다 ([05 §터치 타깃](../05-localization-a11y.md#터치-타깃)).
- 토글은 즉시 반영·즉시 저장.

#### `CompletionHeatCell`
- 입력: 날짜, `completed`, `total`, `isInCurrentMonth`, `isSelected`, `isToday`.
- 농도 매핑은 5-6의 표를 따른다. **level 계산을 뷰에서 하지 않고 헬퍼 결과를 받는다.**
- 숫자는 `.monospacedDigit()`.

### 5-11. `TodayView` 연결 (04 §1 ①②)

이 단계에서 **①과 ②만** 채운다. ③ 이번 학기 진척 요약은 **4단계 소관이므로 만들지 않는다.**

- **① 오늘의 시간표 요약**
  - 오늘 요일의 `TimetableEntry`를 시작 시각 순으로. `TimetableBlockView` 재사용.
  - "최대 높이 제한"은 **고정 height가 아니라 표시 개수 제한**으로 구현한다.
    진행 중·다음 일정 우선 최대 3개 + "외 N개". 고정 프레임으로 자르지 않는다.
  - 비어 있으면 `EmptyStateView`(`calendar.badge.plus`, "시간표를 등록하면 오늘 일정이 보여요", 동작: 시간표 등록).
- **② 오늘의 할 일**
  - `isSameDay(item.date, Date())`로 거른 `PlanItem` 리스트. `PlanItemRow` 재사용.
  - **체크는 즉시 저장.** 별도 저장 버튼 없음.
  - 비어 있으면 `EmptyStateView`(`checklist`, "오늘 할 일이 없어요", 동작: 할 일 추가).
- **툴바 `+` 버튼은 1개.** 탭하면 **"할 일 추가" 시트**(`PlanItemFormView`)를 연다.
  시간표 등록 진입은 ① 섹션의 빈 상태 버튼으로만 제공한다. **플로팅 버튼과 툴바 버튼을 동시에 두지 않는다.**
- 세 섹션이 모두 비었을 때의 통합 빈 상태(온보딩 유도)는 **9단계 소관**이다. 여기서는 섹션별 빈 상태까지만.

### 5-12. 색상 / Assets

```
Resources/Assets.xcassets/ScheduleSchool.colorset
Resources/Assets.xcassets/ScheduleAcademy.colorset
```

- **Light/Dark 두 값을 모두 정의**한다. 한쪽만 채우지 않는다.
- 농도만으로 완료율을 나타낸다. 단계별로 색상(hue)을 바꾸지 않는다.
- 두 색은 **명도까지 다르게** 잡는다(색상만 다르면 색맹 사용자에게 동일하게 보인다). 색은 어디까지나 보조이며, 구분의 1차 수단은 아이콘+레이블이다.
- 블록 위 텍스트 대비율 4.5:1 이상 (WCAG AA). Light/Dark 각각에서 확인한다.
- 코드에 RGB 하드코딩 금지 — `Color("ScheduleSchool")`.

## 6. 수용 기준

체크리스트. **항목별로 자기 점검한 결과를 보고한다.**

- [ ] `PlannerDateHelper.swift`가 `Foundation`만 import한다 (SwiftData·SwiftUI 없음)
- [ ] 헬퍼의 모든 날짜 함수가 `Calendar`를 **파라미터로 주입**받는다 (`Calendar.current` 내부 참조 없음)
- [ ] 테스트가 **고정 타임존(`Asia/Seoul`) 캘린더**를 주입한다
- [ ] 5-2의 테스트 목록이 빠짐없이 존재하고 전부 통과한다
- [ ] 요일 변환(1=일 … 7=토 ↔ 월요일 시작 표시)이 `1...7` 전 범위에서 왕복 항등이다
- [ ] `PlanItem.date`가 **저장 시점에** `startOfDay`로 정규화된다
- [ ] 하루 단위 비교가 전부 `isSameDay`/`startOfDay`를 거친다 (`Date` 직접 비교 없음)
- [ ] `TimetableEntry`의 시간 비교가 **시·분 컴포넌트만** 사용한다 (날짜 부분 무시)
- [ ] 일간/주간/월간 세그먼트가 동작하고 **선택 날짜가 세 뷰 간에 유지된다**
- [ ] 일간 뷰에서 좌우 스와이프로 전날/다음날 이동이 되고, **버튼 대안도 있다**
- [ ] 주간 뷰의 각 셀에 할 일 개수와 완료율이 표시된다
- [ ] 월간 뷰가 완료율을 **accent color 투명도 5단계**로 표시한다
- [ ] **데이터 없는 날은 채움 없이 테두리만** 표시된다
- [ ] 월간 히트맵이 **accent color 단색 농도만** 쓴다 (여러 색을 섞지 않음)
- [ ] 학교/학원이 **아이콘 + 텍스트 레이블**로도 구분된다 (색상만으로 구분하지 않음)
- [ ] 겹치는 일정이 **나란히 배치**되고 숨겨지지 않는다 (3개 겹침도 3열로)
- [ ] 시간표 등록에 요일·시작/종료·제목·유형·반복 필드가 있고 **반복 기본값이 매주 반복(`true`)** 이다
- [ ] `startTime >= endTime`이면 저장 버튼이 비활성화되고 **인라인 안내**가 뜬다 (얼럿 아님)
- [ ] 자정 넘김 입력이 저장되지 않는다
- [ ] 할 일 체크가 **즉시 저장**되고 별도 저장 버튼이 없다
- [ ] 오늘 탭에 ① 시간표 요약과 ② 오늘의 할 일이 표시되고, **툴바 `+` 버튼이 1개**다
- [ ] 오늘 탭 ③ 진척 요약을 **만들지 않았다** (4단계 소관)
- [ ] 각 빈 화면에 `EmptyStateView`가 있다 (빈 리스트를 그냥 보여주지 않음)
- [ ] 고정 폰트 크기·고정 width/height가 없다 (`@ScaledMetric`·`GeometryReader`·`ViewThatFits` 사용)
- [ ] 터치 타깃이 44×44pt 이상이다
- [ ] 커스텀 색상 2종이 Light/Dark 둘 다 정의되어 있다
- [ ] 코드에 RGB 하드코딩이 없다
- [ ] 모든 사용자 표시 문자열이 로컬라이징 가능한 리터럴이다
- [ ] 날짜·숫자 포맷에 `DateFormatter(dateFormat:)`·`String(format:)`을 쓰지 않았다
- [ ] 히트맵 칸·시간표 블록에 문장형 `.accessibilityLabel`이 있다
- [ ] 라이트/다크 스크린샷 확인, Dynamic Type AX5에서 레이아웃 유지
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

**테스트가 먼저 통과해야 UI 작업을 시작한다.**

순수성 자가 점검 (아무것도 출력되지 않아야 한다):

```bash
grep -nE "import (SwiftUI|SwiftData)" Studion/Utilities/PlannerDateHelper.swift
grep -n "Calendar.current" Studion/Utilities/PlannerDateHelper.swift
```

시뮬레이터 시나리오 검증 (스크린샷 필수):
1. 플래너 탭 → 빈 상태 확인 → "시간표 추가"로 **학교** 일정 등록 (월 09:00~09:50)
2. 같은 요일·같은 시간대에 **학원** 일정 등록 → 일간 뷰에서 **두 블록이 나란히** 보이는지
3. 세 번째 겹치는 일정 추가 → **3열로 나뉘는지** (숨겨지지 않는지)
4. 종료 시간을 시작 시간보다 앞으로 → **저장 버튼 비활성화 + 인라인 안내** 확인
5. 종료 시간을 자정 넘김으로 → **막히는지** 확인
6. 할 일 3개 추가 후 2개 체크 → **즉시 반영**되는지 (앱 재실행 후에도 유지)
7. 일간 뷰에서 **좌우 스와이프** → 전날/다음날로 이동하고 데이터가 바뀌는지
8. 주간 뷰 → 해당 요일 셀에 **개수·완료율(2/3)** 이 보이는지 → 셀 탭 → 일간으로 그 날짜 유지되며 전환되는지
9. 월간 뷰 → 데이터 있는 날에 **농도**가, 없는 날에 **테두리만** 보이는지
10. 월간 그리드가 **월요일부터** 시작하는지 (일요일 시작이면 요일 변환 버그)
11. 오늘 탭 → ① 시간표 요약과 ② 할 일이 보이고, **툴바 `+` 가 1개**이며 할 일 추가 시트가 뜨는지
12. 다크모드 확인 — 학교/학원 색, 히트맵 농도가 모두 판별되는지
13. Dynamic Type AX5 — 주간 컬럼·월간 그리드가 깨지지 않는지 (`ViewThatFits` 대안이 뜨는지)

## 8. 범위 밖 (하지 않는다)

- **오답노트·Vision OCR·복습 플래시카드 (6단계)**
- **CloudKit 동기화·Sign in with Apple (7단계)**
- **테마 전환·다국어 전환·JSON 백업 (8단계)** — `String Catalog` 파일 생성도 8단계
- **온보딩 마법사·통합 빈 상태·로컬 알림/리마인더 (9단계)** — 플래너에 알림 스케줄링 코드를 넣지 않는다
- 오늘 탭 **③ 이번 학기 진척 요약 카드** (4단계) — ①② 까지가 5단계
- 성적 탭 관련 일체 (3·4단계) — `Views/Grades/`를 열지 않는다
- Swift Charts (4단계) — 월간 히트맵은 차트 라이브러리 없이 `LazyVGrid`로 만든다
- 시간표 예외 처리 (공휴일·시험기간·특정 주만 휴강) — 1차 범위 밖
- 격주·특정 주 반복 등 커스텀 반복 규칙 — `repeatsWeekly` Bool 하나가 전부다
- 자정 넘김 일정 — 입력에서 막는 것까지만 한다
- 드래그로 일정 이동/리사이즈, 캘린더 앱(EventKit) 연동
- 할 일 반복·하위 항목·우선순위·태그
- iPad `NavigationSplitView` 레이아웃 (2차 플랫폼 단계) — **구조만** 반응형으로 둔다
- **모델(`Models/`) 수정** — 필드를 추가하고 싶어지면 §9를 따른다

## 9. 막히면

- **`repeatsWeekly == false`를 어떻게 표시할지**: `TimetableEntry`에는 일회성 날짜를 담을 필드가 없다.
  **모델을 임의로 확장하지 않는다.** 1차 동작은 "요일 기준으로 표시하되 목록에 '반복 안 함' 보조 레이블"이다.
  이것이 부족하다고 판단되면 임의로 필드를 추가하지 말고 **멈추고 사용자에게 묻는다.**
- **요일 순서를 월요일로 할지 일요일로 할지**: **저장은 Calendar 컨벤션(1=일), 표시는 월요일 시작**이다.
  [03 §4-5](../03-domain-logic.md#4-날짜-처리-공통-규칙)에 확정되어 있다. `Calendar.current.firstWeekday`로 자동 판단하지 않는다
  (한국 로케일은 일요일 시작이지만 시간표 UI 관례는 월요일이다 — [05 §로케일 의존 포맷](../05-localization-a11y.md#로케일-의존-포맷)).
- **`PlanItem` 조회를 `@Query` predicate로 날짜 필터링하려는데 잘 안 될 때**: SwiftData predicate 안에서 `Calendar` 연산은 쓸 수 없다.
  **전체를 가져와 `isSameDay`로 거르는 방식**을 기본으로 한다. 1차 데이터 규모에서 성능 문제가 없다.
  최적화를 이유로 `date >= a && date < b` 구간 비교를 쓰고 싶다면, 저장 시 정규화가 보장된다는 전제를 확인한 뒤에만 한다.
- **완료율 농도를 몇 단계로 나눌지**: 5단계로 확정되어 있다 ([04 §2](../04-ui-spec.md#2-플래너-planner-탭)). 임의로 늘리거나 줄이지 않는다.
- **히트맵 색을 바꾸고 싶어질 때**: accent color 농도만 쓴다. 브랜드 빨강은 경고가 아니라 강조색이며, 많이 한 날이 진해지는 방향이라 미달을 부각하지 않는다 ([05 §3](../05-localization-a11y.md#3-컬러-팔레트)).
- **겹치는 일정이 많아 화면이 좁아질 때**: 그래도 **숨기지 않는다.** 가로 스크롤이나 축약 레이아웃으로 해결한다.
- **타임라인 시간 범위를 정하지 못할 때**: 하드코딩(6~24시)하지 말고 그날 데이터의 최소~최대에서 유도한다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**
