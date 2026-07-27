# 4단계 — 모의고사 + 목표 대비 진척 (진척 로직 + 차트 UI)

## 1. 목표

**먼저 순수 Swift로 목표 진척·추이 요약 로직을 구현하고 단위 테스트로 검증한 뒤**, 그 위에 모의고사 서브탭과 Swift Charts 그래프를 올린다.
모의고사 회차/과목 성적을 입력하고, 회차별 추이를 보고, 내신 목표 등급 대비 진척을 확인할 수 있게 만든다.

이 단계가 끝나면 회차를 추가해 과목 성적을 입력하고, 등급/백분위/표준점수 추이를 그래프로 보고, 오늘 탭에서 이번 학기 진척 요약을 볼 수 있다.

> **순서를 지킨다: 로직 → 테스트 → UI.** 차트를 먼저 그리고 계산을 끼워 넣지 않는다.

## 2. 선행 조건

- 3단계 완료 (`GradeCalculator` + 테스트 통과, 내신 서브탭 동작)
- `GradesView`에 내신/모의고사 세그먼트가 있고 **모의고사 쪽이 플레이스홀더** — 이 단계에서 내용을 채운다
- `SemesterListView`, `SubjectFormView`, `GradeBadge`, `EstimateLabel` 존재 (3단계)
- `Assets.xcassets/GoalAchieved.colorset`이 Light/Dark 둘 다 정의된 채로 존재 (3단계) — **이 단계에서 새로 만들지 않고 재사용한다**
- 모델 `MockExamSession`, `MockExamSubjectRecord`, `Semester`, `SchoolSubjectRecord` 존재 (1단계)

## 3. 참조 문서

| 문서 | 섹션 | 중요도 |
|---|---|---|
| [03-domain-logic.md](../03-domain-logic.md) | **§2 목표 대비 진척 전체** (§2-1 등급 격차, §2-2 모의고사 추이), §4 날짜 규칙, §5 테스트 요구사항 | ★ 필수 |
| [04-ui-spec.md](../04-ui-spec.md) | §3-2 모의고사 서브탭, §3-3 과목 상세, §1 오늘 탭 ③, §8 입력 검증 | ★ 필수 |
| [02-data-model.md](../02-data-model.md) | `MockExamSession`, `MockExamSubjectRecord`, `SchoolSubjectRecord.targetGrade` | ★ 필수 |
| [01-architecture.md](../01-architecture.md) | §Utilities는 순수해야 한다 | ★ 필수 |
| [05-localization-a11y.md](../05-localization-a11y.md) | §컬러 팔레트, §VoiceOver(차트), §색상에만 의존하지 않기, §문구 원칙 | ★ 필수 |

## 4. 만들 파일

**신규**
```
Studion/Utilities/ProgressCalculator.swift
Studion/Views/Grades/MockExamListView.swift           # 회차 리스트 + 추이 진입
Studion/Views/Grades/MockExamSessionFormView.swift    # 회차 추가/편집 (회차명·시험일)
Studion/Views/Grades/MockExamDetailView.swift         # 회차 상세: 과목별 기록 리스트
Studion/Views/Grades/MockExamSubjectFormView.swift    # 과목 성적 입력 (4값 전부 옵셔널)
Studion/Views/Grades/MockExamTrendView.swift          # 추이 그래프 (지표 선택)
Studion/Views/Grades/GoalProgressView.swift           # 목표 설정 + 목표 vs 실제 비교
Studion/Views/Grades/SubjectDetailView.swift          # 내신 과목 상세 ①추이 ②게이지
Studion/Views/Components/ProgressGauge.swift
Studion/Views/Components/SemesterProgressCard.swift   # 오늘 탭 ③ 요약 카드
StudionTests/ProgressCalculatorTests.swift
```

**수정**
```
Studion/Views/Grades/GradesView.swift        # 모의고사 세그먼트 플레이스홀더 → MockExamListView
Studion/Views/Grades/SemesterListView.swift  # 목표 진척 화면 진입 + 과목 행 → SubjectDetailView
Studion/Views/Today/TodayView.swift          # ③ 이번 학기 진척 요약 카드만 연결
```

**Assets**
```
추가 없음. GoalAchieved.colorset(3단계 생성)을 그대로 쓴다.
```

> `import Charts`는 **애플 기본 프레임워크**다. `project.yml`에 의존성을 추가하지 않는다. 서드파티 차트 라이브러리를 넣지 않는다.
> 여기 없는 파일을 건드리지 않는다. 특히 `Models/`는 **수정하지 않는다** — 필요한 속성이 이미 전부 있다.

## 5. 구현 명세

### 5-1. `ProgressCalculator.swift` — 순수 Swift (★ 가장 중요)

[03-domain-logic.md §2](../03-domain-logic.md#2-목표-대비-진척--progresscalculatorswift)의 명세를 **그대로** 구현한다. 시그니처를 임의로 바꾸지 않는다.

구현할 타입·함수:

| 대상 | 명세 위치 |
|---|---|
| `struct GradeProgress { remainingTiers, isAchieved, ratio }` | §2-1 |
| `progress(current:target:system:) -> GradeProgress?` | §2-1 |
| `struct TrendPoint { date, value }` | §2-2 |
| `struct TrendSummary { average, stdDeviation, latestDelta }` | §2-2 |
| `summarize(_:) -> TrendSummary?` | §2-2 |

**철칙**

- `import Foundation`만. **SwiftData·SwiftUI·Charts를 import하지 않는다.**
- `@Model` 객체를 파라미터로 받지 않는다. 값 타입만 받는다. `MockExamSubjectRecord` → `[TrendPoint]` 변환은 **View 쪽 책임**이다.
- 유효하지 않은 입력에 `nil`을 반환한다. 크래시하거나 0을 반환하지 않는다.
- **등급은 작을수록 좋다.** `remainingTiers = current - target`, `isAchieved = current <= target`.
- `ratio`는 `target >= system.tierCount`일 때 **0으로 나누기를 분기로 피한다** (§2-1의 식을 그대로 옮긴다). 그 외에는 `clamp((worst - current) / (worst - target), 0...1)`.
- `summarize`는 **모표준편차(n)** 를 쓴다. 표본 표준편차(n−1)가 아니다.
- `summarize`는 입력을 **내부에서 date 오름차순 정렬**한다. 호출부가 정렬해 주기를 기대하지 않는다.
- `latestDelta = 최신값 - 직전값`. 점이 1개 이하이면 `nil`. 빈 배열이면 함수 전체가 `nil`.
- **`latestDelta`의 의미를 함수 안에서 뒤집지 않는다.** 등급 추이에서 `3 → 2`는 `latestDelta = -1`이지만 **향상**이다. 부호 해석과 문구 반전은 **호출부(UI)의 책임**이며, 이 사실을 doc comment에 명시한다.

### 5-2. `ProgressCalculatorTests.swift`

[03-domain-logic.md §2](../03-domain-logic.md#2-목표-대비-진척--progresscalculatorswift)의 **모든 테스트 벡터 표를 빠짐없이** 테스트로 옮긴다.

**§2-1 표 (5등급제) — 9행 전부**

| current | target | remaining | achieved | ratio |
|---|---|---|---|---|
| 3 | 2 | 1 | false | 0.6667 |
| 2 | 2 | 0 | true | 1.0 |
| 1 | 2 | −1 | true | 1.0 (클램프) |
| 5 | 2 | 3 | false | 0.0 |
| 3 | 1 | 2 | false | 0.5 |
| 5 | 5 | 0 | true | 1.0 (분모 0 분기) |
| 4 | 5 | −1 | true | 1.0 |
| 0 | 2 | — | — | nil |
| 6 | 2 | — | — | nil |

**§2-2 표 — 4행 전부**

| 입력 값 (날짜순) | average | stdDev | latestDelta |
|---|---|---|---|
| `[3, 3, 2]` | 2.6667 | 0.4714 | −1.0 (등급이면 **향상**) |
| `[3, 2, 2]` | 2.3333 | 0.4714 | 0.0 (최근 두 회차가 같음) |
| `[80]` | 80.0 | 0.0 | nil |
| `[]` | — | — | nil (전체가 nil) |
| `[1, 2]` | 1.5 | 0.5 | +1.0 |

**요구사항**

- Swift Testing (`@Test` / `#expect`). XCTest 신규 작성 금지.
- 부동소수 비교는 허용 오차 `0.0001`을 명시한다 (`abs(a - b) < 0.0001`).
- **9등급제 범위 검증도 추가한다**: `current/target`이 `1...9` 밖이면 `nil` (예: `10 → nil`, `0 → nil`).
- `ratio` 클램프 케이스(`1 → 2`가 1.0을 넘지 않음, `5 → 2`가 0.0 아래로 안 감)를 명시적으로 검증한다.
- `summarize`의 **정렬 무관성**을 테스트한다: 같은 점들을 날짜 역순으로 넣어도 `latestDelta`가 동일해야 한다. 이게 이 함수의 함정이다.
- 날짜는 고정 타임존(`Asia/Seoul`) 기준의 결정적 `Date` 값을 만들어 쓴다. `Date()`를 테스트에 쓰지 않는다.
- 파라미터화 테스트(`@Test(arguments:)`)를 쓰면 표를 그대로 옮기기 좋다.

### 5-3. 모의고사 서브탭 UI

#### `GradesView` 수정

세그먼트의 "모의고사" 선택 시 3단계 플레이스홀더 대신 `MockExamListView`를 띄운다. **세그먼트 구조 자체는 바꾸지 않는다.**

#### `MockExamListView` — 회차 리스트

- `@Query`로 `MockExamSession`을 **`examDate` 내림차순**(최신 우선) 정렬해 관찰한다.
- 각 행: 회차명, 시험일(`date.formatted(.dateTime.year().month().day())`), 입력된 과목 수. 스와이프 삭제 지원.
- 비면 `EmptyStateView(systemImage: "chart.line.uptrend.xyaxis", title: "첫 모의고사 회차를 추가해 보세요", actionTitle: "회차 추가")`.
- 툴바: `+`(회차 추가) **하나만**, 그리고 추이 그래프 진입(`MockExamTrendView`) 링크. 추이 진입은 툴바 아이콘 대신 리스트 상단의 명시적 행/버튼으로 두어도 된다. 어느 쪽이든 **추가 버튼은 1개**를 유지한다.
- 회차가 0개면 추이 진입을 노출하지 않는다.

#### `MockExamSessionFormView` — 회차 추가/편집

- 필드: **회차명(사용자 자유 입력)**, 시험일(`DatePicker`, `.date`만).
- 회차명 예시는 placeholder로만 보여준다 (예: "2026년 6월 학평"). **회차명 목록을 앱에 내장하지 않는다.**
- 검증 ([04 §8](../04-ui-spec.md#8-입력-검증-정책)): 회차명 공백만 입력 불가 → **저장 버튼 비활성화**. 얼럿 쓰지 않는다.

#### `MockExamDetailView` — 회차 상세

- 해당 회차의 `subjectRecords`를 과목명 순으로 나열. 각 행에 입력된 값만 요약 표시(원점수/표준점수/백분위/등급).
- 비면 `EmptyStateView` + "과목 추가".
- 툴바 `+` → `MockExamSubjectFormView`. 스와이프 삭제 지원.

#### `MockExamSubjectFormView` — 과목 성적 입력 (★ 핵심 규칙)

| 필드 | 타입 | 규칙 |
|---|---|---|
| 과목명 | `String` | 자유 입력. 공백만이면 저장 버튼 비활성화 |
| 원점수 | `Double?` | 옵셔널. 범위 강제하지 않음 |
| 표준점수 | `Double?` | 옵셔널. 범위 강제하지 않음 |
| 백분위 | `Double?` | 옵셔널. `0...100` 권장이나 강제하지 않음 |
| 등급 | `Int?` | 옵셔널. **`1...9` 고정** Picker |

**철칙 (이 단계에서 가장 어기기 쉬운 부분)**

- **모의고사는 항상 9등급제다.** 내신 `Semester.gradingSystemType`·`AcademicProfile` 설정을 **참조하지 않는다.** 등급 Picker는 `1...9` 하드 고정.
- **네 값 모두 사용자 직접 입력이며 전부 옵셔널이다.** 하나만 넣어도 저장된다.
- **앱이 값들을 서로 환산하지 않는다.** 원점수 → 등급, 표준점수 → 백분위 같은 변환을 하지 않는다. 등급컷을 추정하지 않는다. 빈 칸을 자동으로 채워주지 않는다.
- 값을 지우면 `nil`로 되돌아가야 한다. 0으로 채우지 않는다.
- **`GradeCalculator.estimateGrade`를 모의고사에 쓰지 않는다.** 그건 내신 원점수·평균·표준편차 전용이다.

#### `MockExamTrendView` — 추이 그래프 (Swift Charts)

- 지표 선택: **등급 / 백분위 / 표준점수** 세그먼트. 화면 내부 `enum`(예: `TrendMetric`)으로 두고, `@Model`이나 저장 속성으로 만들지 않는다.
- 과목 선택: 입력된 과목명 중에서 고른다(`Picker`). 과목 목록은 저장된 기록에서 **동적으로 수집**한다. 하드코딩 금지.
- x축 = `MockExamSession.examDate`, y축 = 선택한 지표. 값이 `nil`인 회차는 **점을 그리지 않는다** (0으로 대체 금지).
- **등급 추이는 y축을 뒤집는다.** 1등급이 위로 오게 한다. 뒤집지 않으면 향상이 하락처럼 보인다.
  - `.chartYScale(domain: .automatic(reversed: true))` 또는 명시적 도메인 반전. 등급 축 눈금은 정수(1…9)로 고정.
  - **백분위·표준점수는 뒤집지 않는다.** 값이 클수록 좋다.
- 요약 영역: `ProgressCalculator.summarize`의 `average` / `stdDeviation` / `latestDelta`를 표시한다.
  - **등급 지표일 때 `latestDelta`의 문구를 뒤집는다.** `latestDelta == -1` → "1등급 향상", `+1` → "1등급 하락". 백분위·표준점수는 `+`가 향상.
  - 문구는 [05 §5](../05-localization-a11y.md#5-문구ux-writing-원칙)를 따른다. 담담한 평서문, 느낌표 없음, 하락을 빨간색으로 강조하지 않는다.
- **접근성**: 차트에 `.accessibilityChartDescriptor`를 붙이거나, 최소한 `.accessibilityLabel`로 요약 문장을 제공한다 ("수학 등급 추이, 3회차, 평균 2.3등급, 최근 1등급 향상"). 차트를 시각 정보만으로 두지 않는다.
- 점이 1개 이하면 선 대신 점만 그리고, `latestDelta` 문구를 숨긴다.

### 5-4. 목표 대비 진척 UI

#### `ProgressGauge` — 공통 컴포넌트

```swift
struct ProgressGauge: View {
    let progress: GradeProgress   // ProgressCalculator의 결과를 그대로 받는다
    let label: String
}
```

- 달성(`isAchieved == true`) = `Color("GoalAchieved")` + **체크 아이콘 + "달성" 텍스트**.
- 미달 = **뉴트럴 그레이**. **빨간색을 쓰지 않는다.** 시스템 red는 삭제 확인에서만 쓴다 ([05 §3](../05-localization-a11y.md#3-컬러-팔레트)).
- 색상만으로 구분하지 않는다. 아이콘/텍스트 단서를 항상 함께 둔다.
- 미달 문구는 "목표에 미달했습니다"가 아니라 **"목표까지 1등급"**.
- 게이지 길이는 `progress.ratio`(0…1)에 비례. **고정 width를 쓰지 않는다** — 컨테이너 너비에 반응하게.
- 숫자는 `.monospacedDigit()`. VoiceOver 레이블은 문장으로: `"수학, 3등급, 목표 2등급, 1등급 남음"`.
- 코드에 RGB 하드코딩 금지 — `Color("GoalAchieved")`.

#### `GoalProgressView` — 목표 설정 + 목표 vs 실제 비교

`SemesterListView`에서 진입한다. 학기 하나를 대상으로 한다.

1. **목표 설정 구역**: 학기 내 과목별 목표 등급을 한 화면에서 `Picker`로 편집. 범위는 `1...semester.gradingSystemType.tierCount` — 자유 입력 금지.
   - `evaluationType == .achievementOnly` 과목은 **목록에서 제외**한다 (`targetGrade == nil` 불변식, [02](../02-data-model.md#schoolsubjectrecord)).
2. **목표 vs 실제 비교 그래프** (Swift Charts, **과목별 막대**):
   - 과목마다 목표 등급 막대와 실제 `rankGrade` 막대를 나란히 둔다.
   - **등급 축은 여기서도 뒤집어** 1등급이 위(또는 긴 쪽)로 오게 한다. 축 방향을 추이 그래프와 일관되게 한다.
   - `rankGrade`가 없는 과목은 실제 막대를 그리지 않는다. 추정 등급으로 대체하지 않는다.
   - `.accessibilityChartDescriptor` 또는 요약 레이블 필수.
3. **과목별 `ProgressGauge` 리스트**: `ProgressCalculator.progress(current:target:system:)` 결과를 그대로 넘긴다. `system`은 **학기에 고정 저장된 등급제**를 쓴다 (프로필 값을 다시 읽지 않는다).
   - `current`(=`rankGrade`)나 `target`이 없으면 게이지 대신 "목표를 설정하면 진척이 보여요" 같은 안내를 둔다. 0으로 채우지 않는다.

#### `SubjectDetailView` — 내신 과목 상세 ([04 §3-3](../04-ui-spec.md#3-3-과목-상세-화면-내신모의고사-공통-진입점) ①②만)

`SemesterListView`의 과목 행을 탭하면 진입한다. 내비게이션 깊이 2를 넘기지 않는다.

- ① 성적 추이: 해당 과목명이 여러 학기에 걸쳐 있으면 학기별 `rankGrade` 추이를 `summarize`로 요약해 보여준다. 학기가 1개면 요약만 표시하고 차트는 생략한다.
- ② 목표 대비 진척 게이지: `ProgressGauge` 재사용.
- ③ 오답노트 리스트는 **6단계 소관**이다. 이 단계에서는 자리만 두거나 아예 두지 않는다. `WrongAnswerNote`를 읽거나 쓰지 않는다.

### 5-5. 오늘 탭 ③ — `SemesterProgressCard`

[04 §1 ③](../04-ui-spec.md#1-오늘-today-탭)의 "이번 학기 진척 요약"을 연결한다.

- 가장 최근 `Semester`의 과목 중 **목표와 실제가 모두 있는 것만** 골라, 목표까지 남은 등급이 큰 순으로 **상위 3~5개**만 보여준다. 전체 나열하지 않는다 — 요약이다.
- 각 행은 `ProgressGauge`를 재사용한다. 새 게이지를 따로 만들지 않는다.
- 카드를 탭하면 성적 탭의 `GoalProgressView`로 넘긴다는 안내(또는 "성적에서 자세히 보기" 링크)를 둔다. 탭 간 프로그래매틱 이동이 복잡하면 **링크 없이 요약만** 두고 넘어간다. 이 단계에서 탭 라우팅 구조를 새로 만들지 않는다.
- 데이터가 없으면 카드 자체를 숨긴다. 빈 카드를 그리지 않는다.
- **`TodayView`에서 ③ 구역만 건드린다.** ① 시간표 요약과 ② 할 일 리스트는 **5단계 소관**이다. 툴바 `+` 버튼을 만들지 않는다.

## 6. 수용 기준

체크리스트. **항목별로 자기 점검한 결과를 보고한다.**

- [ ] `ProgressCalculator.swift`가 `Foundation`만 import한다 (SwiftData·SwiftUI·Charts 없음)
- [ ] [03 §2](../03-domain-logic.md#2-목표-대비-진척--progresscalculatorswift)의 **모든 테스트 벡터**(§2-1 9행, §2-2 4행)가 테스트로 존재하고 통과한다
- [ ] `ratio`의 클램프와 **분모 0 분기(`target == tierCount`)** 가 테스트로 검증된다
- [ ] `current`/`target` 범위 밖 입력이 `nil`을 반환하고 테스트된다 (5·9등급제 둘 다)
- [ ] `summarize`가 **모표준편차(n)** 를 쓰고, 입력 순서와 무관하게 같은 결과를 낸다 (테스트 포함)
- [ ] `summarize`가 빈 배열에 `nil`, 1개 입력에 `latestDelta == nil`을 반환한다
- [ ] 모의고사 등급 입력이 **항상 `1...9`** 이며 내신 등급제 설정을 참조하지 않는다
- [ ] 원점수/표준점수/백분위/등급이 **전부 옵셔널**이고, 하나만 입력해도 저장된다
- [ ] 앱이 네 값을 서로 환산하거나 등급컷을 추정해 빈 칸을 채우지 않는다
- [ ] 회차명이 사용자 자유 입력이고, 회차명 목록을 하드코딩하지 않았다
- [ ] 추이 그래프에서 **등급/백분위/표준점수를 선택**해 볼 수 있다
- [ ] **등급 추이 그래프의 y축이 뒤집혀 1등급이 위**에 있다 (스크린샷으로 확인)
- [ ] 백분위·표준점수 축은 뒤집지 않았다
- [ ] `latestDelta`가 등급일 때 UI 문구가 뒤집혀 표시된다 (`-1` → "향상")
- [ ] 값이 `nil`인 회차를 0으로 대체해 그리지 않는다
- [ ] 목표 vs 실제 비교 그래프가 **과목별 막대**로 존재한다
- [ ] `ProgressGauge`가 달성=`Color("GoalAchieved")`, 미달=뉴트럴 그레이이며 **빨간색을 쓰지 않는다**
- [ ] 달성/미달을 색상만으로 구분하지 않는다 (아이콘 + 텍스트 병기)
- [ ] 목표 등급 입력이 `1...tierCount` 범위를 벗어날 수 없고, `achievementOnly` 과목은 목표 설정 대상에서 제외된다
- [ ] 모든 차트에 `.accessibilityChartDescriptor` 또는 요약 레이블이 있다
- [ ] 오늘 탭에 이번 학기 진척 요약 카드가 연결되고, 상위 몇 개만 보여준다
- [ ] `TodayView`의 ①②(시간표·할 일)를 건드리지 않았다
- [ ] 회차명 공백만 입력 시 저장 버튼이 비활성화된다 (얼럿 아님)
- [ ] `Models/`와 `project.yml`의 의존성을 수정하지 않았다 (서드파티 차트 라이브러리 없음)
- [ ] 고정 폰트 크기·고정 width/height가 없고, 숫자에 `.monospacedDigit()`을 붙였다
- [ ] 라이트/다크 스크린샷 확인, Dynamic Type AX5에서 차트와 게이지 레이아웃 유지
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

**테스트가 먼저 통과해야 UI 작업을 시작한다.** 3단계의 `GradeCalculatorTests`도 함께 통과해야 한다 (회귀 확인).

시뮬레이터 시나리오 검증 (스크린샷 필수):

1. 성적 탭 → 모의고사 세그먼트 → **빈 상태**("첫 모의고사 회차를 추가해 보세요") 확인
2. 회차 추가 → 회차명을 공백만 입력 → **저장 버튼 비활성화** 확인 → "2026년 6월 학평"으로 저장
3. 회차 상세 → 과목 추가 → **등급만 입력하고 저장** → 나머지 세 값이 비어 있는 채로 저장되는지 확인 (앱이 채워주지 않는지)
4. 회차 2개 이상 만들어 같은 과목 등급을 `3 → 2`로 입력 → 추이 그래프에서 **1등급이 위**에 있고, 요약 문구가 **"향상"** 으로 나오는지 확인 (핵심 확인 지점)
5. 지표를 백분위로 전환 → 축이 뒤집히지 **않는지** 확인
6. 내신 학기에서 목표 등급 설정 → 목표 vs 실제 막대 그래프 확인 → 달성 과목이 그린, 미달 과목이 **그레이(빨강 아님)** 인지 확인
7. 오늘 탭 → 이번 학기 진척 요약 카드가 보이는지 확인
8. 다크모드 스크린샷 (차트 색상·게이지 대비 확인)
9. Dynamic Type AX5에서 차트 축 레이블과 게이지가 깨지지 않는지 확인

## 8. 범위 밖 (하지 않는다)

- **예측 알고리즘** — "다음 시험에 필요한 점수 역산", 회귀선, 추세 외삽. 이 앱은 통계 요약만 한다 ([03 §2-2](../03-domain-logic.md#2-2-모의고사-추이) 경고)
- **등급컷 추정·환산표 내장** — 원점수로 등급을 채워주지 않는다. 어느 단계에서도 하지 않는다
- 오늘 탭의 ① 시간표 요약, ② 할 일 리스트, 툴바 `+` 시트 (5단계)
- 시간표 등록·일/주/월간 뷰·월간 히트맵 (5단계)
- 오답노트, Vision OCR, 복습 플래시카드, `ReviewScheduler`, `WrongAnswerCard` (6단계) — `SubjectDetailView`의 ③ 구역 포함
- Sign in with Apple, CloudKit 동기화 (7단계)
- 설정 탭 `Form`, 테마 전환, 언어 전환, 이수 과목 관리 화면, JSON 백업 (8단계)
- String Catalog(`Localizable.xcstrings`) 파일 생성 (8단계) — 리터럴을 로컬라이징 가능한 형태로만 쓴다
- 온보딩 마법사, 알림 권한·스케줄링 (9단계)
- `NavigationSplitView` / iPad 전용 레이아웃 (2차 플랫폼 단계)
- 모델(`Models/`) 스키마 변경 — 필요한 속성이 이미 전부 있다. 없다고 판단되면 **멈추고 묻는다**

## 9. 막히면

- **모의고사 등급제를 내신 설정에서 읽어야 할 것 같을 때**: 읽지 않는다. **모의고사는 항상 9등급제**다 ([02 §MockExamSubjectRecord](../02-data-model.md#mockexamsubjectrecord)). 이건 설계 원칙이다.
- **원점수만 입력됐을 때 등급을 채워주고 싶을 때**: 채우지 않는다. 앱은 등급컷을 모른다 ([CLAUDE.md §1](../../CLAUDE.md) 원칙 6).
- **등급 추이의 delta 부호가 헷갈릴 때**: `ProgressCalculator`는 순수 뺄셈 결과만 낸다. **뒤집는 책임은 UI에 있다.** 계산 함수 안에서 부호를 바꾸지 않는다 — 백분위·표준점수에서 반대로 틀어진다.
- **등급 축 반전이 Swift Charts에서 잘 안 될 때**: 값 자체를 `10 - grade` 같은 식으로 변환해 우회하지 않는다. 축 도메인을 반전하고 눈금 레이블은 원래 등급 숫자를 유지한다. 그래도 막히면 그 사실을 그대로 보고한다.
- **`rankGrade`가 없는 과목의 진척을 어떻게 표시할지**: 게이지를 그리지 않고 안내 문구를 둔다. 추정 등급으로 대체하지 않는다 ([04 §3-1](../04-ui-spec.md#3-1-내신-서브탭) 표시 규칙 — 추정은 내신 화면의 보조 표시 용도다).
- **`achievementOnly` 과목에 목표를 설정하고 싶을 때**: 설정하지 않는다 ([02 §SchoolSubjectRecord](../02-data-model.md#schoolsubjectrecord) 불변식).
- **오늘 탭 카드에서 성적 탭으로 프로그래매틱 이동이 필요할 때**: 탭 라우팅 구조를 새로 만들 만큼 중요하지 않다. 요약만 두고 넘어간다.
- **3단계 스펙이 "과목 상세 화면은 6단계"라고 한 것과 충돌해 보일 때**: 이 단계에서는 [04 §3-3](../04-ui-spec.md#3-3-과목-상세-화면-내신모의고사-공통-진입점)의 **①추이·②게이지까지만** 만든다. ③오답노트는 6단계다. 6단계가 이 화면을 전제로 하므로([tasks/README.md](README.md#단계-목록과-의존-관계)) 껍데기를 여기서 만든다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**
