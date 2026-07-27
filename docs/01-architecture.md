# 01. 아키텍처

## 기술 스택

| 영역 | 선택 | 근거 |
|---|---|---|
| UI | SwiftUI 100% | UIKit은 SwiftUI로 불가능/명백히 열등할 때만 `UIViewRepresentable`, **주석으로 이유 명시 필수** |
| 최소 타깃 | iOS 17.0 | SwiftData, Observation, NavigationStack |
| 개인 데이터 | SwiftData `@Model` | SwiftUI 통합. Core Data 직접 사용 금지 |
| 동기화 | SwiftData + CloudKit Private DB | 7단계. 개발자 접근 불가 저장소 |
| 식별 | Sign in with Apple | 선택 기능. 자체 사용자 DB 없음 |
| 차트 | Swift Charts | 4단계 |
| OCR | Vision (`VNRecognizeTextRequest`, `.accurate`) | 온디바이스. 네트워크 없음 |
| 알림 | UNUserNotificationCenter | 로컬 스케줄링만. 푸시 서버 없음 |
| 다국어 | String Catalog (`.xcstrings`) | 8단계 |
| 테스트 | Swift Testing (`@Test`/`#expect`) | XCTest 신규 작성 금지 |
| 프로젝트 생성 | XcodeGen (`project.yml`) | `.xcodeproj`는 생성물, 직접 편집 금지 |

## 레이어 구조

```
┌─────────────────────────────────────────────┐
│ Views/            SwiftUI 화면              │
│                   @Query로 SwiftData 직접 관찰 │
├─────────────────────────────────────────────┤
│ Models/           SwiftData @Model + enum    │
│                   저장 스키마. 로직 최소화     │
├─────────────────────────────────────────────┤
│ Utilities/        순수 Swift 도메인 로직      │
│                   ★ SwiftData·SwiftUI import 금지 │
└─────────────────────────────────────────────┘
```

### 경량 MV 패턴 — ViewModel을 기본으로 두지 않는다

Apple 권장 방식이자 SwiftData와 자연스럽게 맞물리는 구조다.

```swift
// ✅ 이렇게
struct SubjectListView: View {
    @Query(sort: \SchoolSubjectRecord.createdAt) private var records: [SchoolSubjectRecord]
    @Environment(\.modelContext) private var context
    // ...
}

// ❌ 이렇게 하지 않는다 — 불필요한 레이어
@Observable final class SubjectListViewModel {
    var records: [SchoolSubjectRecord] = []
    func load() { /* context.fetch(...) */ }
}
```

**예외**: 여러 화면이 공유하는 복잡한 상태(예: 온보딩 마법사의 다단계 입력, OCR 진행 상태)는 `@Observable` 클래스로 뽑아도 된다. 단 그것은 **화면 상태**이지 데이터 저장소 래퍼가 아니다.

### Utilities는 순수해야 한다 — 가장 중요한 경계

`Utilities/`의 파일은 `import Foundation` 외에 **SwiftData·SwiftUI를 import하지 않는다.**

이유 두 가지:
1. **테스트 가능성** — ModelContainer 없이 단위 테스트가 돌아간다.
2. **Android 이식** — 이 폴더가 Kotlin 포팅 시 참조 문서가 된다. SwiftData 타입이 섞이면 그 가치가 사라진다.

따라서 도메인 함수는 `@Model` 객체가 아니라 **값 타입 입력**을 받는다.

```swift
// ✅ 순수 — 테스트도 이식도 쉽다
struct GradeInput { let rawScore: Double; let mean: Double; let stdDev: Double }
func estimateGrade(_ input: GradeInput, system: GradingSystemType) -> GradeEstimate

// ❌ SwiftData에 결합됨
func estimateGrade(for record: SchoolSubjectRecord) -> Int
```

`@Model` → 값 타입 변환은 **View 또는 Model의 computed property**에서 한다. 이 변환 지점이 두 세계의 유일한 접점이다.

## 폴더 구조

```
Studion/
  App/
    StudionApp.swift          # @main, ModelContainer 구성
  Models/
    GradingSystemType.swift   # 등급제·평가방식·태그 enum 모음
    AcademicProfile.swift
    Semester.swift
    SchoolSubjectRecord.swift
    MockExamSession.swift
    MockExamSubjectRecord.swift
    WrongAnswerNote.swift
    TimetableEntry.swift
    PlanItem.swift
  Views/
    RootView.swift            # TabView (→ iPad에서 NavigationSplitView로 교체)
    Today/
    Planner/
    Grades/
    Settings/
    Components/               # 탭 간 공유 컴포넌트 (빈 상태, 카드, 게이지 등)
  Utilities/
    GradeCalculator.swift     # 등급 산출·환산
    ProgressCalculator.swift  # 목표 대비 진척
    ReviewScheduler.swift     # 스페이스드 리피티션
    TextRecognizer.swift      # Vision 래퍼 (여기만 Vision import)
  Resources/
    Assets.xcassets
    Localizable.xcstrings
StudionTests/
```

**파일 추가/삭제 후 반드시 `xcodegen generate`.**

## 저장소 분리 — 개인 데이터 vs 콘텐츠

```
SwiftData ModelContainer          장기: 콘텐츠 캐시 (별도 컨테이너)
├─ 개인 데이터 (성적·계획·오답)     ├─ 단어장·듣기·문제은행
└─ CloudKit Private DB 동기화      └─ 정적 CDN 다운로드, 인증 없음
```

이 둘은 **같은 저장소를 공유하지 않는다.** 경계가 흐려지면 "사용자 데이터를 서버에 올리지 않는다"는 원칙이 지켜지는지 판단할 수 없게 된다. 상세 → [07](07-content-system-future.md).

## iPad 이식 전략 (2단계 대비, 지금은 구조만)

1차에서 지켜야 할 것:

- **최상위 내비게이션을 격리한다.** `RootView`가 `TabView`를 소유하고, 각 탭 콘텐츠는 독립 View다. `TabView` → `NavigationSplitView` 교체 시 `RootView`만 고치면 되게 한다.
- **하드코딩된 width/height 금지.** `ViewThatFits`, size class, `GeometryReader`를 쓴다.
- **컴포넌트를 재사용 가능하게 쪼갠다.** 오답카드·성적 그래프·과목 행은 컨테이너 너비에 반응하는 독립 View로 만든다. iPad 2단 레이아웃에서 그대로 재사용된다.

## Android 이식 전략 (3단계, 지금은 설계 원칙만)

이식 대상은 `Utilities/` 전부다. 그래서 이 폴더는:

- 순수 Swift만 사용 (Foundation 수준)
- 부작용 없는 함수 위주
- 각 함수에 **입출력 명세를 주석으로** 남긴다 (→ [03](03-domain-logic.md)의 테스트 벡터가 그대로 Kotlin 테스트가 된다)

CloudKit은 Android에서 동작하지 않으므로 동기화 체계는 그 시점에 별도 검토한다. **지금 설계하지 않는다.**

## 의존성 정책

**서드파티 의존성을 추가하지 않는다.** SPM 패키지를 넣기 전에 사용자에게 묻는다.

이 앱이 필요로 하는 것은 전부 애플 1st-party 프레임워크로 충족된다. 의존성은 원칙 1(데이터 외부 유출 없음)을 검증하기 어렵게 만드는 비용이기도 하다.

## 에러 처리 원칙

- **사용자 데이터 손실 가능성이 있는 실패는 조용히 넘어가지 않는다.** 저장 실패는 사용자에게 알린다.
- `try!` / `fatalError`는 앱 시작 시 ModelContainer 구성 실패 외에는 쓰지 않는다.
- OCR 실패, 알림 권한 거부처럼 **복구 가능한 실패는 빈 상태 + 재시도 경로**로 처리한다. 얼럿을 남발하지 않는다.
