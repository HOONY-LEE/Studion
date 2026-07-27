# 05. 다국어 · 접근성 · 비주얼

---

## 1. 다국어 (Localization)

### 도구: String Catalog (`Localizable.xcstrings`)

`Resources/Localizable.xcstrings` 하나로 관리한다. `.strings`/`.stringsdict` 파일을 새로 만들지 않는다.

**1차 지원 언어**: 한국어(base) + 영어. 한국어를 우선 채우고 영어는 구조만 갖춘다.

### 코드 규칙

```swift
// ✅ SwiftUI 자동 로컬라이징 — 리터럴을 그대로 쓰면 자동 추출된다
Text("오늘 할 일")
Button("과목 추가") { ... }

// ✅ 문자열 변수로 다뤄야 할 때
let title = String(localized: "오늘 할 일")

// ❌ 보간된 문자열을 통째로 넘기지 않는다 — 추출 불가
Text("\(subjectName) 과목")

// ✅ 포맷 인자로 분리
Text("\(subjectName) 과목", comment: "과목 상세 화면 제목")
// 또는
Text(String(localized: "\(subjectName) 과목"))
```

`SWIFT_EMIT_LOC_STRINGS: YES`가 이미 `project.yml`에 설정되어 있어 빌드 시 자동 추출된다.

### 한국 교육 특화 용어 — 별도 취급

"내신", "수능", "석차등급", "이수단위", "학평" 같은 용어는 **영어로 직역하면 의미가 사라진다.**

- String Catalog에서 이 용어들에 **`education-terms` 코멘트를 붙여 구분**한다.
- 영어 번역은 직역이 아니라 **음차 + 짧은 설명** 방식을 검토한다 (예: `Naesin (school GPA)`).
- 실제 영문 번역 문구 확정은 1차 범위 밖이다. **구조만 잡고 한국어를 채운다.**

### 로케일 의존 포맷

하드코딩된 날짜/숫자 포맷을 쓰지 않는다.

```swift
// ✅
date.formatted(.dateTime.year().month().day())
value.formatted(.number.precision(.fractionLength(2)))

// ❌
DateFormatter().apply { $0.dateFormat = "yyyy년 M월 d일" }
String(format: "%.2f", value)
```

**주의**: 학기 표기("고1-1학기")와 요일 순서는 로케일에 따라 다르게 표시되어야 한다. 요일은 `Calendar.current.firstWeekday`를 참조한다 (한국은 일요일 시작이지만 시간표 UI는 월요일 시작이 관례 — 이 차이를 View에서 명시적으로 처리한다).

### 앱 자체 언어 전환

설정에서 시스템 언어와 **별개로** 강제 전환할 수 있어야 한다.
`@AppStorage`에 선택 언어를 저장하고 최상위에서 `.environment(\.locale, ...)`로 주입한다. 8단계에서 구현.

---

## 2. 접근성

### Dynamic Type — 필수

```swift
// ✅ 시맨틱 스타일만 사용
.font(.body) .font(.headline) .font(.caption)

// ❌ 고정 포인트 금지
.font(.system(size: 17))
```

- **최대 접근성 크기(AX5)에서 레이아웃이 깨지지 않아야 한다.** 각 화면 구현 후 이 크기로 확인한다.
- 고정 높이 컨테이너 안에 텍스트를 가두지 않는다.
- 가로 공간이 부족해지는 행은 `ViewThatFits`로 세로 스택 대안을 제공한다.

### VoiceOver

- 모든 상호작용 요소에 의미 있는 레이블을 붙인다. 아이콘 전용 버튼은 `.accessibilityLabel` 필수.
- 등급 배지처럼 시각 정보가 압축된 요소는 `.accessibilityLabel("수학, 2등급, 목표 대비 1등급 남음")` 처럼 **문장으로** 읽히게 한다.
- 차트는 `.accessibilityChartDescriptor` 또는 최소한 요약 레이블을 제공한다.
- 장식용 이미지는 `.accessibilityHidden(true)`.

### 색상에만 의존하지 않기

색맹 사용자를 위해 **색상은 항상 보조 수단**이다.

| 구분 | 색상 | 함께 제공하는 비색상 단서 |
|---|---|---|
| 학교 vs 학원 일정 | 두 가지 색 | 아이콘 + 텍스트 레이블 |
| 목표 달성 vs 미달 | 그린 vs 그레이 | 체크 아이콘 + "달성" 텍스트 |
| 월간 완료율 히트맵 | 농도 5단계 | 셀 탭 시 수치 표시 |
| 확정 등급 vs 추정 | — | **"추정" 텍스트 배지** (색으로 구분하지 않음) |

### 터치 타깃

최소 **44×44pt**. 리스트 행의 체크박스, 카드의 태그 칩 등이 이보다 작아지지 않게 한다.

### 모션

`@Environment(\.accessibilityReduceMotion)`을 존중한다. 애니메이션을 절제하므로 대부분 문제되지 않지만, 플래시카드 넘김처럼 동작이 있는 곳에서는 확인한다.

---

## 3. 컬러 팔레트

### 원칙

- **accent color 1개(`#FF212B`) + 중립 그레이스케일**이 기본.
- 의미색은 **등급/성취도 표시에만 제한적으로** 사용한다.
- **실패를 부정적 색채로 강조하지 않는다.** 학생 대상 앱에서 부정적 색채 강조는 지양한다.

| 상태 | 색 |
|---|---|
| 목표 달성 | 그린 계열 (절제된 톤) |
| 목표 미달 | **뉴트럴 그레이** — 의미색을 쓰지 않는다 |
| 강조/선택 | AccentColor (`#FF212B`) |
| 월간 완료율 히트맵 | AccentColor 투명도 5단계 |
| 파괴적 동작 (삭제 확인) | **색으로 구분하지 않는다** — 휴지통 아이콘 + 확인 다이얼로그 |

> accent가 빨강이므로 "빨강 = 위험"을 색만으로 전달할 수 없다.
> 파괴적 동작은 아이콘·문구·확인 절차로 드러낸다. 색상에만 의존하지 않는 원칙과 일치한다.

### 관리 방식

Asset Catalog의 **Color Set으로 Light/Dark를 각각 정의**한다.

```
Resources/Assets.xcassets/
  AccentColor.colorset       ✅ 1단계에서 생성됨 (Light/Dark 정의)
  GoalAchieved.colorset      → 3·4단계에서 추가
  ScheduleSchool.colorset    → 5단계에서 추가
  ScheduleAcademy.colorset   → 5단계에서 추가
```

```swift
// ✅
Color("GoalAchieved")
// ❌ 코드에 RGB 하드코딩 금지
Color(red: 0.2, green: 0.7, blue: 0.4)
```

시스템 시맨틱 색상(`.primary`, `.secondary`, `Color(.systemBackground)`)을 우선 쓰고, 커스텀 색은 위 표의 의미색에만 추가한다.

### 다크모드

- 모든 커스텀 색상은 **Light/Dark 두 값을 반드시 정의**한다.
- 각 화면 구현 후 **다크모드에서도 스크린샷으로 확인**한다 (완료 정의에 포함).
- 대비율: 본문 텍스트 4.5:1, 큰 텍스트 3:1 이상 (WCAG AA).

---

## 4. 타이포그래피

| 용도 | 스타일 |
|---|---|
| 화면 제목 | `.largeTitle` / `.title` (navigationTitle 기본값 활용) |
| 섹션 헤더 | `.headline` |
| 본문 | `.body` |
| 보조 설명 | `.callout` / `.subheadline` + `.foregroundStyle(.secondary)` |
| 배지·각주 | `.caption` / `.caption2` |
| 숫자 강조 (등급 등) | `.title2` + `.monospacedDigit()` |

숫자가 바뀌며 흔들리는 곳(등급, 완료율, 타이머)은 **`.monospacedDigit()`** 을 붙인다.

---

## 5. 문구(UX Writing) 원칙

이 앱은 성적을 다룬다. 문구가 압박이 되지 않게 한다.

| 하지 않는다 | 대신 |
|---|---|
| "목표에 미달했습니다" | "목표까지 1등급" |
| "3일째 밀렸습니다" | "복습할 카드 5장" |
| "실패", "부족", "경고" | 중립 서술 또는 다음 행동 제시 |
| 느낌표로 압박 | 담담한 평서문 |

- 빈 상태 문구는 **다음 행동을 제안**한다 ("아직 없습니다" ❌ → "틀린 문제를 찍어 오답노트를 만들어 보세요" ✅).
- 에러 문구는 **무엇을 하면 되는지** 알려준다. 원인만 말하고 끝내지 않는다.
- 상세 문구 표 → [04](04-ui-spec.md#빈-상태empty-state는-전-화면-필수).
