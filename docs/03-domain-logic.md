# 03. 핵심 도메인 로직

`Studion/Utilities/`에 **순수 Swift**로 구현한다. SwiftData·SwiftUI를 import하지 않는다 (→ [01](01-architecture.md)).
이 문서의 테스트 벡터는 그대로 단위 테스트가 되고, 추후 Kotlin 포팅 시 참조 명세가 된다.

---

## 0. 용어

| 용어 | 정의 |
|---|---|
| **상위 누적 비율** (`topRatio`) | 전체 중 자신보다 위(포함)에 있는 비율. `0 < topRatio ≤ 1`. 작을수록 성적이 좋다 |
| **석차등급** | `topRatio`를 등급 경계에 매핑한 값. 작을수록 좋다 (1등급이 최상) |
| **성취도** | 절대평가 A~E |
| **이수단위** | 과목의 학점 가중치 |

---

## 1. 등급 산출 — `GradeCalculator.swift`

### 1-1. 누적 비율 → 등급 (핵심, 확정값)

```swift
/// 상위 누적 비율을 석차등급으로 변환한다.
/// - Parameter topRatio: 상위 누적 비율 (0 < topRatio <= 1)
/// - Returns: 1부터 시작하는 등급. topRatio가 범위를 벗어나면 nil
func grade(forTopRatio topRatio: Double, system: GradingSystemType) -> Int?
```

**규칙**: 경계값 배열을 앞에서부터 훑어 **`topRatio <= boundary`를 처음 만족하는 인덱스 + 1**이 등급이다.
즉 경계값은 **해당 등급에 포함**된다 (상위 10%까지가 1등급).

| 제도 | 경계값 (누적) |
|---|---|
| 5등급제 | 1등급 ≤ 0.10, 2등급 ≤ 0.34, 3등급 ≤ 0.66, 4등급 ≤ 0.90, 5등급 ≤ 1.00 |
| 9등급제 | ≤ 0.04, 0.11, 0.23, 0.40, 0.60, 0.77, 0.89, 0.96, 1.00 |

**테스트 벡터 (5등급제)**

| topRatio | 기대 등급 | 비고 |
|---|---|---|
| 0.01 | 1 | |
| 0.10 | 1 | **경계 포함** |
| 0.1001 | 2 | 경계 직후 |
| 0.34 | 2 | 경계 포함 |
| 0.50 | 3 | |
| 0.90 | 4 | 경계 포함 |
| 0.95 | 5 | |
| 1.00 | 5 | 최하 경계 |
| 0.0 | nil | 범위 밖 |
| 1.01 | nil | 범위 밖 |
| -0.1 | nil | 범위 밖 |

**테스트 벡터 (9등급제)**

| topRatio | 기대 등급 |
|---|---|
| 0.04 | 1 |
| 0.0401 | 2 |
| 0.11 | 2 |
| 0.23 | 3 |
| 0.40 | 4 |
| 0.60 | 5 |
| 0.77 | 6 |
| 0.89 | 7 |
| 0.96 | 8 |
| 1.00 | 9 |

### 1-2. 석차 → 등급

```swift
/// 석차와 수강인원으로 등급을 구한다.
/// - Parameters:
///   - rank: 석차 (1부터). 동점자가 있으면 그중 가장 높은 석차
///   - studentCount: 수강인원
///   - tieCount: 동점자 수 (동점 없으면 1)
/// - Returns: 등급. 입력이 유효하지 않으면 nil
func grade(rank: Int, studentCount: Int, tieCount: Int = 1,
           system: GradingSystemType) -> Int?
```

**동석차 처리**: 학교생활기록부 규칙에 따라 동점자는 **가장 불리한 위치**를 기준으로 누적 비율을 계산한다.

```
topRatio = (rank + tieCount - 1) / studentCount
```

동점자가 없으면 `tieCount = 1`이므로 `topRatio = rank / studentCount`로 자연스럽게 환원된다.

**유효성**: `rank >= 1`, `studentCount >= 1`, `tieCount >= 1`, `rank + tieCount - 1 <= studentCount`. 하나라도 위반이면 `nil`.

**테스트 벡터**

| rank | N | tieCount | 제도 | topRatio | 기대 등급 |
|---|---|---|---|---|---|
| 30 | 300 | 1 | 5등급 | 0.100 | 1 |
| 31 | 300 | 1 | 5등급 | 0.1033 | 2 |
| 28 | 300 | 5 | 5등급 | 0.1067 | 2 (동점 불이익) |
| 1 | 300 | 1 | 9등급 | 0.0033 | 1 |
| 300 | 300 | 1 | 9등급 | 1.000 | 9 |
| 0 | 300 | 1 | — | — | nil |
| 30 | 0 | 1 | — | — | nil |
| 299 | 300 | 5 | — | — | nil (범위 초과) |

### 1-3. 원점수 → 예상 등급 (★ 추정치)

학교가 제공하는 원점수·과목평균·표준편차로 정규분포를 가정해 상위 비율을 추정한다.

```swift
struct GradeEstimate {
    let zScore: Double
    let estimatedTopRatio: Double
    let estimatedGrade: Int
    /// 항상 true. 호출부는 이 값을 근거로 "추정" 레이블을 반드시 표시한다.
    let isEstimate: Bool
}

/// 원점수·과목평균·표준편차로 등급을 추정한다.
/// ⚠️ 정규분포 가정에 기반한 추정치다. 확정 등급이 아니다.
/// - Returns: stdDev <= 0 이면 nil
func estimateGrade(rawScore: Double, subjectAverage: Double, stdDeviation: Double,
                   system: GradingSystemType) -> GradeEstimate?
```

**계산식**

```
z        = (rawScore - subjectAverage) / stdDeviation
Φ(z)     = 0.5 * (1 + erf(z / √2))        // 표준정규 누적분포
topRatio = 1 - Φ(z)
grade    = grade(forTopRatio: topRatio, system:)
```

`erf`는 Foundation에서 제공된다 (별도 구현 금지).
`topRatio`가 `0`이 되는 극단값은 `grade(forTopRatio:)`가 nil을 반환하므로, **아주 작은 하한(예: 1e-9)으로 클램프**한 뒤 매핑한다.

**테스트 벡터** (허용 오차 `±0.0001`)

| rawScore | 평균 | 표준편차 | z | topRatio | 5등급제 | 9등급제 |
|---|---|---|---|---|---|---|
| 90 | 70 | 10 | +2.0 | 0.02275 | 1 | 1 |
| 80 | 70 | 10 | +1.0 | 0.15866 | 2 | 3 |
| 70 | 70 | 10 | 0.0 | 0.50000 | 3 | 5 |
| 60 | 70 | 10 | −1.0 | 0.84134 | 4 | 7 |
| 50 | 70 | 10 | −2.0 | 0.97725 | 5 | 9 |
| 85 | 70 | 0 | — | — | nil | nil |
| 85 | 70 | −5 | — | — | nil | nil |

> **UI 계약**: 이 함수의 결과를 화면에 표시할 때는 반드시 "추정" 배지와 근거(정규분포 가정)를 함께 보여준다. 사용자가 입력한 확정 `rankGrade`가 있으면 **확정값을 우선 표시**하고 추정치는 보조로만 둔다.

### 1-4. 이수단위 가중 평균 등급

```swift
struct WeightedGradeInput {
    let grade: Int
    let creditUnits: Double
}

/// 이수단위로 가중한 평균 등급.
/// 성취도만 기재하는 과목(등급 없음)은 호출부에서 제외해 전달한다.
/// - Returns: 유효 입력이 없거나 총 이수단위가 0이면 nil
func weightedAverageGrade(_ inputs: [WeightedGradeInput]) -> Double?
```

```
Σ(grade × creditUnits) / Σ(creditUnits)
```

**중요**: `achievementOnly` 과목은 **분모에서도 제외**한다. 등급이 없는 과목의 이수단위를 분모에 넣으면 평균이 왜곡된다.

**테스트 벡터**

| 입력 | 기대값 |
|---|---|
| `[(2, 4), (3, 4), (1, 4)]` | `2.0` |
| `[(1, 3), (3, 4)]` | `15/7 ≈ 2.142857` |
| `[(2, 4)]` | `2.0` |
| `[]` | nil |
| `[(2, 0)]` | nil (총 이수단위 0) |

---

## 2. 목표 대비 진척 — `ProgressCalculator.swift`

### 2-1. 등급 격차

```swift
struct GradeProgress {
    /// 목표까지 남은 등급 수. 0 이하이면 달성
    let remainingTiers: Int
    let isAchieved: Bool
    /// 게이지 표시용 0...1
    let ratio: Double
}

func progress(current: Int, target: Int, system: GradingSystemType) -> GradeProgress?
```

**등급은 작을수록 좋다.** 따라서:

```
remainingTiers = current - target
isAchieved     = current <= target
worst          = system.tierCount

ratio = target >= worst
      ? (current <= target ? 1.0 : 0.0)          // 0으로 나누기 방지
      : clamp((worst - current) / (worst - target), 0...1)
```

**유효성**: `current`, `target` 모두 `1...tierCount` 범위여야 한다. 아니면 `nil`.

**테스트 벡터 (5등급제)**

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

> **표시 규칙**: 미달을 빨간색으로 표시하지 않는다. 달성=그린, 미달=뉴트럴 그레이 (→ [00](00-product-principles.md#색채-원칙--실패를-빨간색으로-강조하지-않는다)).

### 2-2. 모의고사 추이

```swift
struct TrendPoint { let date: Date; let value: Double }
struct TrendSummary {
    let average: Double
    let stdDeviation: Double
    /// 최신값 - 직전값. 데이터가 1개 이하이면 nil
    let latestDelta: Double?
}

/// 회차별 추이 요약. 입력은 date 오름차순으로 정렬해 전달하지 않아도 된다(내부 정렬).
func summarize(_ points: [TrendPoint]) -> TrendSummary?
```

- 표본 표준편차(n−1)가 아니라 **모표준편차(n)** 를 쓴다 (전체 회차가 모집단이므로).
- `points`가 비면 `nil`. 1개면 `average = 그 값`, `stdDeviation = 0`, `latestDelta = nil`.
- **등급 추이에서는 delta의 부호가 반대 의미**임에 주의한다. 등급이 3 → 2로 가면 `latestDelta = -1`이지만 **향상**이다. UI에서 문구를 뒤집는 책임은 호출부에 있다.

**테스트 벡터**

| 입력 값 (날짜순) | average | stdDev | latestDelta |
|---|---|---|---|
| `[3, 3, 2]` | 2.6667 | 0.4714 | −1.0 (등급이면 **향상**) |
| `[3, 2, 2]` | 2.3333 | 0.4714 | 0.0 (최근 두 회차가 같음) |
| `[80]` | 80.0 | 0.0 | nil |
| `[]` | — | — | nil (전체가 nil) |
| `[1, 2]` | 1.5 | 0.5 | +1.0 |

`latestDelta`는 **마지막 두 값의 차**다. 전체 추세가 아니라 직전 회차 대비 변화만 본다.

> ⚠️ **앱이 등급컷을 추정하지 않는다.** 이 함수는 사용자가 입력한 값의 통계 요약일 뿐이며, 다음 시험 점수를 예측하지 않는다. 예측 알고리즘은 1차 범위 밖이다.

---

## 3. 스페이스드 리피티션 — `ReviewScheduler.swift`

단순 Leitner box 방식. 복잡한 SM-2 알고리즘을 쓰지 않는다.

```swift
enum ReviewOutcome { case correct, incorrect }

struct ReviewSchedule {
    let boxIndex: Int
    let nextReviewDate: Date
}

/// 간격(일): box 0→1, 1→3, 2→7, 3→14, 4→30
static let intervals: [Int] = [1, 3, 7, 14, 30]

/// 복습 결과를 반영해 다음 박스와 복습일을 계산한다.
/// - Parameter reviewedAt: 복습 시각. 내부에서 startOfDay로 정규화한다
func nextSchedule(currentBox: Int, outcome: ReviewOutcome,
                  reviewedAt: Date, calendar: Calendar) -> ReviewSchedule

/// 신규 카드의 최초 스케줄. box 0, 다음 날부터 복습 대상
func initialSchedule(createdAt: Date, calendar: Calendar) -> ReviewSchedule
```

**규칙**

| 결과 | 새 박스 | 다음 복습일 |
|---|---|---|
| `correct` | `min(currentBox + 1, 4)` | `startOfDay(reviewedAt) + intervals[새 박스]일` |
| `incorrect` | `0` | `startOfDay(reviewedAt) + 1일` |

- `currentBox`는 `0...4`로 클램프한다 (범위 밖 입력도 크래시 없이 처리).
- 신규 카드는 **생성 당일 복습 대상에 넣지 않는다** (방금 봤으므로). `initialSchedule`은 box 0, `startOfDay(createdAt) + 1일`.
- 날짜 계산은 항상 주입받은 `Calendar`를 쓴다. **테스트에서 고정 캘린더·타임존을 주입할 수 있어야 한다.**

**테스트 벡터** (기준일 = 2026-03-10, `startOfDay`)

| currentBox | outcome | 새 박스 | 다음 복습일 |
|---|---|---|---|
| 0 | correct | 1 | 2026-03-13 (+3일) |
| 1 | correct | 2 | 2026-03-17 (+7일) |
| 3 | correct | 4 | 2026-04-09 (+30일) |
| 4 | correct | 4 | 2026-04-09 (상한 유지) |
| 2 | incorrect | 0 | 2026-03-11 (+1일) |
| 4 | incorrect | 0 | 2026-03-11 |
| 0 | incorrect | 0 | 2026-03-11 |
| 99 | correct | 4 | 2026-04-09 (클램프) |
| −1 | correct | 1 | 2026-03-13 (클램프) |

**오늘 복습할 카드 판정**

```swift
func isDue(nextReviewDate: Date, on date: Date, calendar: Calendar) -> Bool
```
`startOfDay(nextReviewDate) <= startOfDay(date)` 이면 due. **지난 카드도 계속 due**로 남는다 (밀린 복습이 사라지지 않게).

---

## 4. 날짜 처리 공통 규칙

이 앱에서 날짜 버그는 대부분 시각·타임존에서 나온다. 아래를 전 코드에서 지킨다.

1. **하루 단위 비교는 항상 `Calendar.startOfDay(for:)`로 정규화한 뒤** 한다. `Date` 직접 비교 금지.
2. `PlanItem.date`는 **저장 시점에** 정규화한다.
3. 도메인 함수는 `Calendar`를 **파라미터로 주입**받는다. `Calendar.current`를 함수 안에서 직접 참조하지 않는다 (테스트 재현성).
4. `TimetableEntry`의 `startTime`/`endTime`은 **시각만** 의미 있다. 비교 시 시·분 컴포넌트만 추출한다.
5. 요일은 **Calendar 컨벤션(1=일요일 … 7=토요일)** 을 따른다. 표시 순서(월요일 시작)는 View에서 변환한다.

---

## 5. 테스트 요구사항

| 파일 | 최소 테스트 |
|---|---|
| `GradeCalculator` | §1-1 표 전체(5·9등급제), §1-2, §1-3, §1-4 각 표 전체 |
| `ProgressCalculator` | §2-1 표 전체, §2-2 표 전체 |
| `ReviewScheduler` | §3 표 전체 + `isDue` 경계(같은 날, 하루 전, 하루 후) |

- Swift Testing (`@Test` / `#expect`) 사용. XCTest 신규 작성 금지.
- 부동소수 비교는 허용 오차를 명시한다 (`abs(a - b) < 0.0001`).
- 날짜 테스트는 **고정 타임존(`Asia/Seoul`)의 `Calendar`를 주입**한다.
