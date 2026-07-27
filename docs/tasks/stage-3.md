# 3단계 — 내신 (등급 계산 로직 + UI)

## 1. 목표

**먼저 순수 Swift로 등급 계산 로직을 구현하고 단위 테스트로 검증한 뒤**, 그 위에 내신 서브탭 UI를 올린다.
5등급제/9등급제 전환과 예외 과목(성취도만) 처리를 반드시 포함한다.

이 단계가 끝나면 학기를 만들고, 과목을 추가하고, 성적을 입력해 등급을 확인할 수 있다.

> **순서를 지킨다: 로직 → 테스트 → UI.** UI를 먼저 만들고 로직을 끼워 넣지 않는다.

## 2. 선행 조건

- 2단계 완료 (`RootView` 4탭, `EmptyStateView` 존재)
- `GradesView`가 빈 상태 플레이스홀더 — **이 단계에서 내용을 채운다**
- 모델 `Semester`, `SchoolSubjectRecord`, `GradingSystemType`, `SchoolSubjectEvaluationType`, `AchievementLevel` 존재 (1단계)

## 3. 참조 문서

| 문서 | 섹션 | 중요도 |
|---|---|---|
| [03-domain-logic.md](../03-domain-logic.md) | §1 등급 산출 **전체**, §4 날짜 규칙, §5 테스트 요구사항 | ★ 필수 |
| [04-ui-spec.md](../04-ui-spec.md) | §3-1 내신 서브탭, §8 입력 검증 | ★ 필수 |
| [02-data-model.md](../02-data-model.md) | `Semester`, `SchoolSubjectRecord`, enum 정의 | ★ 필수 |
| [01-architecture.md](../01-architecture.md) | §Utilities는 순수해야 한다 | ★ 필수 |
| [05-localization-a11y.md](../05-localization-a11y.md) | §컬러 팔레트, §색상에만 의존하지 않기 | |

## 4. 만들 파일

**신규**
```
Studion/Utilities/GradeCalculator.swift
Studion/Views/Grades/SemesterListView.swift          # 학기 선택 + 과목 리스트
Studion/Views/Grades/SubjectFormView.swift           # 과목 추가/편집
Studion/Views/Components/GradeBadge.swift
Studion/Views/Components/EstimateLabel.swift
StudionTests/GradeCalculatorTests.swift
```

**수정**
```
Studion/Views/Grades/GradesView.swift    # 내신/모의고사 세그먼트 + 내신 서브탭 연결
```

**Assets 추가**
```
Resources/Assets.xcassets/GoalAchieved.colorset      # Light/Dark 둘 다 정의
```

> 모의고사 서브탭은 4단계 소관이다. 이 단계에서는 세그먼트에 자리만 만들고 플레이스홀더를 둔다.

## 5. 구현 명세

### 5-1. `GradeCalculator.swift` — 순수 Swift (★ 가장 중요)

[03-domain-logic.md §1](../03-domain-logic.md#1-등급-산출--gradecalculatorswift)의 명세를 **그대로** 구현한다. 시그니처를 임의로 바꾸지 않는다.

구현할 함수 4개:

| 함수 | 명세 위치 |
|---|---|
| `grade(forTopRatio:system:)` | §1-1 |
| `grade(rank:studentCount:tieCount:system:)` | §1-2 |
| `estimateGrade(rawScore:subjectAverage:stdDeviation:system:)` | §1-3 |
| `weightedAverageGrade(_:)` | §1-4 |

**철칙**
- `import Foundation`만. **SwiftData·SwiftUI를 import하지 않는다.**
- `@Model` 객체를 파라미터로 받지 않는다. 값 타입만 받는다.
- `erf`는 Foundation 제공 함수를 쓴다. 직접 구현하지 않는다.
- 유효하지 않은 입력에 `nil`을 반환한다. 크래시하거나 0을 반환하지 않는다.
- `estimateGrade`의 `GradeEstimate.isEstimate`는 **항상 `true`** 다. 호출부가 이 값을 근거로 "추정" 배지를 붙인다.

### 5-2. `GradeCalculatorTests.swift`

[03-domain-logic.md §1](../03-domain-logic.md#1-등급-산출--gradecalculatorswift)의 **모든 테스트 벡터 표를 빠짐없이** 테스트로 옮긴다.

- Swift Testing (`@Test` / `#expect`). XCTest 금지.
- 부동소수 비교는 허용 오차 `0.0001`을 명시한다.
- 경계값 테스트(0.10 → 1등급, 0.1001 → 2등급)를 반드시 포함한다. 이게 이 로직의 핵심이다.
- `nil` 반환 케이스(범위 밖 입력, `stdDev <= 0`, 빈 배열)를 전부 테스트한다.
- 파라미터화 테스트(`@Test(arguments:)`)를 쓰면 표를 그대로 옮기기 좋다.

### 5-3. 내신 UI

#### `GradesView` — 최상단 세그먼트

```
Picker("", selection: $tab) { "내신" / "모의고사" }.pickerStyle(.segmented)
```
- 내신 선택 시 `SemesterListView`, 모의고사는 **4단계 플레이스홀더**(`EmptyStateView`).

#### `SemesterListView` — 학기 선택 + 과목 리스트

- 학기 선택: `Picker` 또는 상단 스크롤 칩. 학기가 없으면 빈 상태 + "학기 추가".
- 학기 생성 시 **`AcademicProfile.gradingSystemType`을 복사해 `Semester`에 고정 저장**한다 ([02 §Semester](../02-data-model.md#semester) 참조 — 과거 학기가 소급 변경되지 않게).
- 과목 리스트: 각 행에 과목명, `GradeBadge`, 이수단위. 스와이프 삭제 지원.
- 학기 헤더에 **이수단위 가중 평균 등급**을 표시하고, `achievementOnly` 과목이 제외되었다는 각주를 단다.
- 과목이 없으면 `EmptyStateView`("이수 과목을 추가해 보세요" + 추가 버튼).
- 툴바에 `+` (과목 추가) **하나만**.

#### `SubjectFormView` — 과목 추가/편집 (★ 핵심 분기)

**가장 먼저 묻는다: "이 과목은 석차등급이 산출되나요?"**

| 선택 | `evaluationType` | 표시할 필드 |
|---|---|---|
| 예 | `achievementAndRank` | 이수단위, 원점수, 과목평균, 표준편차, 수강인원, 성취도, 석차등급, 목표등급 |
| 아니오 | `achievementOnly` | 이수단위, 원점수, 과목평균, 성취도 |

- "아니오"면 등급 관련 필드를 **화면에서 제거**한다. 비활성화(disabled)가 아니라 제거다.
- 석차등급·목표등급은 `Picker`/`Stepper`로 **`1...tierCount` 범위를 벗어날 수 없게** 한다 (자유 입력 금지).
- 검증 ([04 §8](../04-ui-spec.md#8-입력-검증-정책)): 과목명 공백 불가, 이수단위 > 0. 위반 시 **저장 버튼 비활성화**. 얼럿 쓰지 않는다.
- 원점수·평균은 범위를 강제하지 않는다 (학교마다 만점이 다름).

> **하드코딩된 과목-분류 매핑표를 만들지 않는다.** 앱은 어떤 과목이 융합선택인지 알지 못하며, 알려고 하지 않는다.

#### `GradeBadge` / `EstimateLabel`

- `GradeBadge`: 확정 등급, 성취도, 또는 추정 등급을 표시. 숫자는 `.monospacedDigit()`.
- `EstimateLabel`: **"추정" 텍스트 배지.** 색상만으로 구분하지 않는다.
- 표시 우선순위: 사용자 입력 `rankGrade`가 있으면 **확정값을 크게**, 추정치는 보조로 + `EstimateLabel` 필수.
- 확정값과 추정값이 다를 수 있다. **오류로 취급하지 않는다** (정규분포 가정의 한계).

#### 색상

- `GoalAchieved.colorset`을 Light/Dark 둘 다 정의. 그린 계열, 절제된 톤.
- **목표 미달은 뉴트럴 그레이.** 빨간색을 쓰지 않는다.
- 코드에 RGB 하드코딩 금지 — `Color("GoalAchieved")`.

## 6. 수용 기준

- [ ] `GradeCalculator.swift`가 `Foundation`만 import한다 (SwiftData·SwiftUI 없음)
- [ ] [03 §1](../03-domain-logic.md#1-등급-산출--gradecalculatorswift)의 **모든 테스트 벡터**가 테스트로 존재하고 통과한다
- [ ] 경계값(0.10 → 1등급, 0.1001 → 2등급)이 테스트로 검증된다
- [ ] `nil` 반환 케이스가 전부 테스트된다
- [ ] 5등급제/9등급제가 학기별로 고정 저장되고 전환이 동작한다
- [ ] "석차등급이 산출되나요?" 분기가 존재하고, "아니오"에서 등급 필드가 **화면에서 사라진다**
- [ ] 석차등급 입력이 `1...tierCount` 범위를 벗어날 수 없다
- [ ] 이수단위 가중 평균이 `achievementOnly` 과목을 분모에서도 제외한다
- [ ] 추정 등급에 **"추정" 텍스트 배지**가 붙는다
- [ ] 확정 등급이 있으면 확정값이 우선 표시된다
- [ ] 과목 목록·과목 분류 매핑표를 하드코딩하지 않았다
- [ ] 목표 미달이 빨간색으로 표시되지 않는다
- [ ] 커스텀 색상이 Light/Dark 둘 다 정의되어 있다
- [ ] 저장 버튼 비활성화로 검증하며 얼럿을 남발하지 않는다
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

시뮬레이터 시나리오 검증 (스크린샷 필수):
1. 학기 추가 → 5등급제로 생성되는지
2. 과목 추가, "석차등급 산출 **예**" → 전체 필드 표시 → 성적 입력 → 등급 배지 확인
3. 과목 추가, "석차등급 산출 **아니오**" → **등급 필드가 없는지 확인**
4. 학기 헤더의 가중 평균 등급이 3번 과목을 제외했는지
5. 표준편차 입력 시 "추정" 배지가 붙는지
6. 다크모드 확인

## 8. 범위 밖 (하지 않는다)

- 모의고사 서브탭 (4단계) — 플레이스홀더만
- 목표 vs 실제 비교 **그래프** (4단계) — 목표 등급 **입력 필드**까지가 3단계
- 과목 상세 화면 (4단계에서 성적 추이·목표 게이지, 6단계에서 오답노트 — [단계 간 공유 파일](README.md#여러-단계가-나눠-갖는-파일) 참조)
- Swift Charts (4단계)
- 오늘 탭의 진척 요약 카드 (4단계 이후)
- 이수 과목 관리 화면 (8단계 설정)
- String Catalog 파일 생성 (8단계)

## 9. 막히면

- **학기 등급제를 프로필에서 매번 읽을지, 학기에 고정할지**: **학기에 고정**한다 ([02 §Semester](../02-data-model.md#semester)). 이유가 문서에 있다.
- **확정 등급과 추정 등급이 다를 때**: 둘 다 보여주고 확정값을 우선한다. 경고를 띄우지 않는다.
- **`achievementOnly` 과목에 목표 등급을 허용할지**: 허용하지 않는다 (`targetGrade == nil`).
- **어떤 과목이 융합선택인지 판단해야 할 것 같을 때**: 판단하지 않는다. 사용자가 지정한다. 이건 설계 원칙이다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**
