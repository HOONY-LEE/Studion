# 6단계 — 오답노트 + OCR + 스페이스드 리피티션

## 1. 목표

**먼저 순수 Swift로 복습 스케줄 로직(`ReviewScheduler`)을 구현하고 단위 테스트로 검증한 뒤**, 그 위에 오답노트 UI를 올린다.
Vision 온디바이스 OCR로 틀린 문제를 찍어 오답카드를 만들고, Leitner box로 복습일을 관리하며, 플래시카드로 복습한다.
과목 상세 화면(3뎁스 구조의 2뎁스)도 이 단계에서 만든다.

이 단계가 끝나면 과목을 탭해 상세로 들어가고, 문제 사진에서 텍스트를 뽑아 오답카드를 저장하고, 오늘 복습할 카드를 넘기며 복습할 수 있다.

> **순서를 지킨다: 로직 → 테스트 → UI.** UI를 먼저 만들고 스케줄 로직을 끼워 넣지 않는다.

## 2. 선행 조건

- 3단계 완료 — `GradeCalculator`, `SemesterListView`, `SubjectFormView`, `GradeBadge`, `EstimateLabel` 존재
- 4단계 완료 — `ProgressCalculator`, `ProgressGauge`, Swift Charts 기반 추이 차트 존재. **이 단계에서 새로 만들지 않고 재사용한다**
- 모델 `WrongAnswerNote`, enum `WrongAnswerCauseTag`, `EnglishSubcategory` 존재 (1단계)
- **이 단계에서 SwiftData 모델을 바꾸지 않는다.** 1단계 스키마로 충분하다

## 3. 참조 문서

| 문서 | 섹션 | 중요도 |
|---|---|---|
| [03-domain-logic.md](../03-domain-logic.md) | §3 스페이스드 리피티션 **전체**, §4 날짜 처리 공통 규칙, §5 테스트 요구사항 | ★ 필수 |
| [04-ui-spec.md](../04-ui-spec.md) | §3-3 과목 상세 화면, §5 오답노트 생성 플로우 + 복습 플래시카드, §8 입력 검증 | ★ 필수 |
| [02-data-model.md](../02-data-model.md) | `WrongAnswerNote`, `WrongAnswerCauseTag`, `EnglishSubcategory` | ★ 필수 |
| [01-architecture.md](../01-architecture.md) | §Utilities는 순수해야 한다 | ★ 필수 |
| [05-localization-a11y.md](../05-localization-a11y.md) | §문구(UX Writing) 원칙, §접근성, §타이포그래피 | ★ 필수 |
| [06-sync-and-backup.md](../06-sync-and-backup.md) | §이미지 자산 처리 — 미해결 과제 | 배경 이해용 |

## 4. 만들 파일

**신규**
```
Studion/Utilities/ReviewScheduler.swift              # 순수 Swift. Foundation만
Studion/Utilities/TextRecognizer.swift               # Vision을 import하는 유일한 파일
Studion/Utilities/NoteImageStore.swift               # 이미지 파일 저장·조회. Foundation만
Studion/Views/Grades/SubjectDetailView.swift         # 과목 상세 (2뎁스)
Studion/Views/Grades/WrongAnswerNoteFormView.swift   # 오답노트 생성 6단계 플로우
Studion/Views/Grades/WrongAnswerNoteDetailView.swift # 오답노트 상세 (3뎁스)
Studion/Views/Grades/ReviewSessionView.swift         # 플래시카드 복습 (3뎁스)
Studion/Views/Components/WrongAnswerCard.swift
Studion/Views/Components/CameraPicker.swift          # UIImagePickerController 래퍼
StudionTests/ReviewSchedulerTests.swift
```

**수정**
```
Studion/Views/Grades/SemesterListView.swift   # 과목 행 → SubjectDetailView 진입 링크만 추가
project.yml                                   # Info.plist에 카메라·사진첩 권한 문구 추가
```

> 4단계에서 만든 모의고사 회차 상세 화면에도 과목 행 → `SubjectDetailView` 진입 링크를 붙인다.
> **진입 링크 외의 로직은 건드리지 않는다.** 4단계 산출물의 파일명이 예상과 다르면 새로 만들지 말고 §9를 따른다.

여기 없는 파일을 건드리지 않는다. 파일 추가 후 `xcodegen generate`를 반드시 실행한다.

## 5. 구현 명세

### 5-1. `ReviewScheduler.swift` — 순수 Swift (★ 가장 중요)

[03-domain-logic.md §3](../03-domain-logic.md#3-스페이스드-리피티션--reviewschedulerswift)의 명세를 **그대로** 구현한다. 시그니처를 임의로 바꾸지 않는다.

구현할 것:

| 심볼 | 명세 |
|---|---|
| `enum ReviewOutcome { case correct, incorrect }` | §3 |
| `struct ReviewSchedule { boxIndex, nextReviewDate }` | §3 |
| `static let intervals: [Int] = [1, 3, 7, 14, 30]` | box 0→1일 … 4→30일 |
| `nextSchedule(currentBox:outcome:reviewedAt:calendar:)` | §3 규칙 표 |
| `initialSchedule(createdAt:calendar:)` | 신규 카드 |
| `isDue(nextReviewDate:on:calendar:)` | §3 due 판정 |

**규칙**

| 결과 | 새 박스 | 다음 복습일 |
|---|---|---|
| `correct` | `min(currentBox + 1, 4)` | `startOfDay(reviewedAt) + intervals[새 박스]일` |
| `incorrect` | `0` | `startOfDay(reviewedAt) + 1일` |

**철칙**
- `import Foundation`만. **SwiftData·SwiftUI·Vision·UIKit을 import하지 않는다.**
- `@Model` 객체를 파라미터로 받지 않는다. 값 타입만 받는다.
- `currentBox`를 **먼저 `0...4`로 클램프**한 뒤 전이를 계산한다. 범위 밖 입력(`-1`, `99`)에도 크래시하지 않는다.
- 신규 카드는 **생성 당일 복습 대상에 넣지 않는다** (방금 봤으므로). `initialSchedule` = box 0, `startOfDay(createdAt) + 1일`.
- `isDue`는 `startOfDay(nextReviewDate) <= startOfDay(date)`. **지난 카드도 계속 due로 남는다** — 밀린 복습이 조용히 사라지지 않게 한다. 이건 의도된 동작이다.
- 날짜 덧셈은 `calendar.date(byAdding: .day, value:to:)`를 쓴다. **`86400 * n` 같은 초 단위 산술 금지** (DST·타임존).
- 날짜 계산은 **항상 주입받은 `Calendar`** 를 쓴다. 함수 안에서 `Calendar.current`를 참조하지 않는다 ([03 §4](../03-domain-logic.md#4-날짜-처리-공통-규칙)).
- 반환값에 `nil`이 없다. 어떤 입력이 와도 유효한 `ReviewSchedule`을 돌려준다.
- SM-2·EF 계수·난이도 가중치 같은 걸 추가하지 않는다. **단순 Leitner box가 전부다.**

### 5-2. `ReviewSchedulerTests.swift`

[03-domain-logic.md §3](../03-domain-logic.md#3-스페이스드-리피티션--reviewschedulerswift)의 **테스트 벡터 표를 한 행도 빠짐없이** 테스트로 옮긴다 (기준일 2026-03-10).

| currentBox | outcome | 새 박스 | 다음 복습일 |
|---|---|---|---|
| 0 | correct | 1 | 2026-03-13 |
| 1 | correct | 2 | 2026-03-17 |
| 3 | correct | 4 | 2026-04-09 |
| 4 | correct | 4 | 2026-04-09 (상한 유지) |
| 2 | incorrect | 0 | 2026-03-11 |
| 4 | incorrect | 0 | 2026-03-11 |
| 0 | incorrect | 0 | 2026-03-11 |
| 99 | correct | 4 | 2026-04-09 (클램프) |
| −1 | correct | 1 | 2026-03-13 (클램프) |

추가로 반드시 포함:

- `initialSchedule`: 2026-03-10 생성 → box 0, 2026-03-11. **생성 당일이 아니다.**
- `isDue` 경계 3종: 같은 날 → `true`, 하루 전(내일이 복습일) → `false`, 하루 지남 → `true`.
- 밀린 카드: 복습일이 30일 지난 카드도 `isDue == true`.
- **시각 무관성**: 같은 날 00:00과 23:59에 호출한 결과의 `nextReviewDate`가 동일하다 (`startOfDay` 정규화 검증).

**철칙**
- Swift Testing (`@Test` / `#expect`). XCTest 금지.
- **고정 타임존 `Asia/Seoul`의 `Calendar`를 주입**한다.
  ```swift
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
  ```
- 날짜는 `DateComponents`로 만든다. 문자열 파싱·`Date()` 현재 시각 사용 금지 (테스트가 실행 날짜에 의존하면 안 된다).
- 표를 옮길 때 파라미터화 테스트(`@Test(arguments:)`)를 쓰면 좋다.

**이 테스트가 통과한 뒤에 UI 작업을 시작한다.**

### 5-3. `TextRecognizer.swift` — Vision 온디바이스 OCR

**이 파일이 `import Vision`을 하는 유일한 파일이다.** 다른 어떤 파일도 Vision을 import하지 않는다.

```swift
func recognizeText(in cgImage: CGImage,
                   orientation: CGImagePropertyOrientation) async throws -> String
```

**요구사항**
- `VNRecognizeTextRequest` 사용. `recognitionLevel = .accurate`, `revision`은 사용 가능한 최신 revision을 명시적으로 지정한다.
- `recognitionLanguages = ["ko-KR", "en-US"]`, `usesLanguageCorrection = true`.
- **온디바이스 전용.** `URLSession`·`Network`를 쓰지 않고, 외부 OCR SDK·서버 API를 추가하지 않는다 ([CLAUDE.md §1](../../CLAUDE.md) 원칙 1·2).
- `VNImageRequestHandler`의 `perform`은 동기 호출이므로 백그라운드에서 실행하고 `async`로 감싼다. 메인 스레드를 막지 않는다.
- 각 `VNRecognizedTextObservation`의 `topCandidates(1).first?.string`을 **읽기 순서대로 줄바꿈으로 이어 붙인다.**
- **인식 결과를 후처리하지 않는다.** 맞춤법 교정·정규식 치환·수식 복원 같은 걸 만들지 않는다. 사람이 다음 단계에서 고친다.
- 인식된 텍스트가 없으면 **오류가 아니라 빈 문자열**을 반환한다. 호출부가 빈 텍스트 필드로 자연스럽게 이어간다.
- 오류 타입은 이 파일 안에 `enum`으로 정의한다. 오류 문구는 무엇을 하면 되는지 알려준다 ([05 §문구 원칙](../05-localization-a11y.md#5-문구ux-writing-원칙)).
- SwiftUI·SwiftData를 import하지 않는다. `Foundation` + `Vision` + `CoreGraphics`까지만.

> **수학 기호·LaTeX는 1차 범위 밖이다.** 텍스트 위주 문제를 대상으로 한다. 수식 인식을 시도하는 코드를 넣지 않는다 ([04 §5](../04-ui-spec.md#5-오답노트-생성-플로우-6단계)).

### 5-4. `NoteImageStore.swift` — 이미지 파일 저장

원본 이미지는 SwiftData BLOB이 아니라 **파일 시스템**에 둔다 ([02 §WrongAnswerNote](../02-data-model.md#wronganswernote)).

```swift
func save(_ data: Data) throws -> String      // 반환값은 "파일명"
func url(for fileName: String) -> URL
func delete(fileName: String) throws
```

**철칙**
- **모델에는 파일명만 저장한다. 전체 경로를 저장하지 않는다.** 앱 컨테이너 경로는 재설치·기기변경 시 바뀌므로 저장된 절대경로는 반드시 깨진다.
- `url(for:)`는 호출할 때마다 **현재** 컨테이너 경로로 다시 계산한다. 경로를 캐시하지 않는다.
- 파일명은 `UUID().uuidString + 확장자`. 저장 디렉터리는 없으면 만든다.
- `Foundation`만 import한다. **UIKit을 import하지 않는다** — `UIImage → Data` 변환(JPEG 압축)은 호출부(View)의 책임이다.
- 이 파일도 `Utilities/`이므로 SwiftData·SwiftUI를 모른다.

### 5-5. `SubjectDetailView` — 과목 상세 (2뎁스)

[04 §3-3](../04-ui-spec.md#3-3-과목-상세-화면-내신모의고사-공통-진입점) 구조 그대로.

```
① 성적 추이 (해당 과목)
② 목표 대비 진척 게이지
③ 오답노트 리스트 (카드형)
```

**① 성적 추이**
- 4단계에서 만든 차트 표현을 재사용한다. **새 차트 컴포넌트를 만들지 않는다.**
- 내신: 같은 `subjectName`을 가진 다른 학기의 `SchoolSubjectRecord`를 `Semester.year` → `term` 순으로 잇는다.
- 모의고사: 같은 `subjectName`의 회차별 기록을 `examDate` 순으로 잇는다.
- **과목 동일성 판정은 [02 §과목 동일성 판정 규칙](../02-data-model.md#과목-동일성-판정-규칙)을 따른다** — trim 후 완전 일치, 유사도 추측 금지, 내신/모의고사는 별도 네임스페이스.
- 등급 추이는 **y축을 뒤집어** 1등급이 위로 오게 한다 ([04 §3-2](../04-ui-spec.md#3-2-모의고사-서브탭)).
- 데이터가 1개뿐이면 차트 대신 현재 값만 표시한다. 점 하나짜리 차트를 그리지 않는다.

**② 목표 진척 게이지**
- 4단계의 `ProgressCalculator` + `ProgressGauge`를 그대로 쓴다.
- `targetGrade`나 확정 등급이 없으면 **게이지 섹션 자체를 숨긴다.** 0% 게이지를 그리지 않는다.
- `achievementOnly` 과목은 목표 등급이 없으므로 게이지가 없다 ([02 §SchoolSubjectRecord](../02-data-model.md#schoolsubjectrecord) 불변식).
- 미달을 빨간색으로 표시하지 않는다. 달성=`GoalAchieved`, 미달=뉴트럴 그레이 + "목표까지 N등급" 같은 중립 문구.

**③ 오답노트 리스트**
- `WrongAnswerCard` 카드형 리스트. `createdAt` 내림차순.
- 빈 상태: `doc.text.image` / "틀린 문제를 찍어 오답노트를 만들어 보세요" / 동작 "사진으로 추가" ([04 §빈 상태](../04-ui-spec.md#빈-상태empty-state는-전-화면-필수)).
- **영어 하위 카테고리 필터 (★ 주의)**: 노출 조건은 `notes.contains { $0.englishSubcategory != nil }` 이다.
  **과목명 문자열 매칭으로 판단하지 않는다.** `subjectName.contains("영어")` 같은 코드를 쓰지 않는다. 과목명은 사용자 자유 입력이고 앱은 그 의미를 모른다.
- 툴바에 오답노트 추가 `+` **하나만.** 플로팅 버튼을 함께 두지 않는다.
- due 카드가 있으면 리스트 상단에 복습 진입 버튼을 둔다. 문구는 **"복습할 카드 N장"**.
  **"밀렸습니다", "N일째 밀림", "밀린 복습" 같은 압박 문구를 쓰지 않는다** ([05 §문구 원칙](../05-localization-a11y.md#5-문구ux-writing-원칙)).

**내비게이션 깊이**: 과목 상세(2) → 오답노트 상세/복습(3)에서 끝난다. **더 깊이 들어가지 않는다.**

### 5-6. `WrongAnswerNoteFormView` — 생성 6단계 플로우 (★ 핵심)

[04 §5](../04-ui-spec.md#5-오답노트-생성-플로우-6단계)의 순서를 그대로 따른다.

```
① 사진 선택 (카메라 / 사진첩)
      ↓
② Vision OCR — 온디바이스, 진행 표시
      ↓
③ 추출 텍스트 확인·수정          ← 건너뛸 수 없다
      ↓
④ 오답 원인 태그 선택 (몰라서/실수/시간부족/함정)
      ↓
⑤ (선택) 영어 하위 카테고리
      ↓
⑥ 저장 → box 0, 다음 날부터 복습 대상
```

하나의 시트 안에서 단계 상태(enum)로 전환한다. 단계마다 새 화면을 push해 내비게이션을 깊게 만들지 않는다.

**① 사진 선택**
- 사진첩: `PhotosPicker` (PhotosUI).
- 카메라: SwiftUI에 카메라 캡처 API가 없으므로 `UIImagePickerController`를 `UIViewRepresentable`로 감싼 `CameraPicker`를 쓴다. **왜 UIKit이 필요했는지 파일 상단에 주석을 남긴다** ([CLAUDE.md §2](../../CLAUDE.md)).
- 카메라를 쓸 수 없는 기기·시뮬레이터에서는 카메라 항목을 감춘다 (`UIImagePickerController.isSourceTypeAvailable`). 눌러서 실패하게 두지 않는다.

**② OCR**
- `ProgressView`로 진행을 표시한다. **앱 전체에서 스피너를 두는 유일한 지점이다** ([04 §7](../04-ui-spec.md#7-화면-전환애니메이션)).
- 취소 가능하게 한다. 사용자를 잡아두지 않는다.

**③ 텍스트 확인·수정 (★ 절대 건너뛰지 않는다)**
- `TextEditor`에 OCR 결과를 넣고 사용자가 고친다. **"바로 저장" 같은 우회 경로를 만들지 않는다. OCR은 틀린다.**
- **OCR이 실패했거나 인식된 글자가 0자여도 얼럿을 띄우지 않는다.** 빈 텍스트 필드와 함께 "인식된 글자가 없어요. 직접 입력해 보세요." 안내를 보여주고 그대로 이 단계로 들어온다. 실패가 막다른 길이 되지 않게 한다.
- 원본 이미지를 이 화면에 함께 보여준다 (보면서 고칠 수 있게).

**④ 원인 태그**
- `WrongAnswerCauseTag` 4택. 단일 선택. 칩의 터치 타깃은 **최소 44×44pt**.
- 색상만으로 선택 상태를 구분하지 않는다 (텍스트·체크 아이콘 병기).

**⑤ 영어 하위 카테고리**
- **과목명으로 자동 판정하지 않는다.** "영어 하위 분류 지정" 토글을 사용자가 켰을 때만 `EnglishSubcategory` 4택을 노출한다. 기본은 꺼짐 → `englishSubcategoryRaw = nil`.

**⑥ 저장**
- `ocrRawText`에 **OCR 원본을 그대로** 넣는다. 이후 어디서도 이 값을 덮어쓰지 않는다.
- `userEditedText`에 사용자 확인본을 넣는다. **화면 표시에는 항상 `userEditedText`를 쓴다.**
- 이미지: View에서 `UIImage → Data`(JPEG)로 변환 → `NoteImageStore.save` → 반환된 **파일명만** `imageFileName`에 저장.
- `ReviewScheduler.initialSchedule(createdAt:calendar:)`로 `leitnerBoxIndex = 0`, `nextReviewDate`를 채운다. **직접 날짜를 계산하지 않는다.**
- **`schoolSubject`와 `mockExamSubject` 중 정확히 하나만 non-nil로 설정한다** ([02 §WrongAnswerNote](../02-data-model.md#wronganswernote) 불변식). 스키마로 강제할 수 없으므로 **생성 코드에서 보장한다** — 두 관계를 동시에 받는 생성 경로를 아예 만들지 않는다(둘 중 하나를 받는 팩토리/이니셜라이저 하나만 노출).

**검증** ([04 §8](../04-ui-spec.md#8-입력-검증-정책))
- `userEditedText`가 공백만이면 **저장 버튼 비활성화.** 얼럿을 쓰지 않는다.
- 중간에 취소하면 이미 저장한 이미지 파일을 지운다. 고아 파일을 남기지 않는다.

### 5-7. `ReviewSessionView` — 플래시카드 복습 (3뎁스)

- 세션 시작 시점에 `ReviewScheduler.isDue`로 due 카드 목록을 만들고 **그 목록을 고정한다.** 복습 중에 목록이 흔들리지 않게 한다.
- 카드 표시: `userEditedText` + (있으면) 이미지 + 원인 태그.
- **동작은 "맞음 / 틀림" 두 개뿐이다.** 난이도 5단계, "쉬움/보통/어려움", 자신감 슬라이더 같은 걸 만들지 않는다.
- 결과 → `ReviewScheduler.nextSchedule` → `leitnerBoxIndex`, `nextReviewDate`, `lastReviewedAt` 갱신 후 **즉시 저장**. 별도 저장 버튼 없음.
- 진행 표시는 "3 / 8" 같은 **중립 표기**. 정답률·연속 일수(스트릭)·점수를 계산하거나 보여주지 않는다.
- due 카드가 없으면 빈 상태: `checkmark.circle` / "오늘 복습할 카드가 없어요" / **동작 버튼 없음**.
- 세션 종료 문구도 담담하게. 느낌표로 압박하지 않고, 틀린 개수를 강조하지 않는다.
- 카드 넘김 애니메이션은 `@Environment(\.accessibilityReduceMotion)`을 존중한다.

### 5-8. `WrongAnswerNoteDetailView` — 오답노트 상세 (3뎁스)

- 이미지 전체 보기 + `userEditedText` + 원인 태그 + 다음 복습일.
- `ocrRawText`는 **기본으로 감추고** "원본 인식 결과 보기"로 펼친다. **읽기 전용이며 수정 경로를 만들지 않는다** (보존이 목적).
- 텍스트·태그 편집 허용. 삭제 시 `NoteImageStore.delete`로 이미지 파일도 함께 지운다.

### 5-9. `WrongAnswerCard` 컴포넌트

- 구성: 텍스트 발췌(`userEditedText`) + 원인 태그 칩 + 복습 상태 + (있으면) 썸네일.
- 태그는 **색상만으로 구분하지 않는다.** 텍스트 레이블을 항상 함께 둔다 ([05 §색상에만 의존하지 않기](../05-localization-a11y.md#색상에만-의존하지-않기)).
- 복습 상태는 **진도 표시**이지 성취 점수가 아니다. "박스 2/5", "다음 복습 3월 17일" 같은 중립 서술.
- 고정 width/height 금지. 썸네일이 없으면 자리를 비운다(빈 플레이스홀더 아이콘을 강제로 채우지 않는다).
- 카드 전체를 하나의 접근성 요소로 묶어 **문장으로** 읽히게 한다 (`.accessibilityElement(children: .combine)` + 요약 레이블).
- 발췌 줄 수를 제한하더라도 Dynamic Type AX5에서 잘리지 않는지 확인한다.

### 5-10. `project.yml` — 권한 문구

`targets.Studion.info.properties`에 추가한다.

| 키 | 초안 문구 |
|---|---|
| `NSCameraUsageDescription` | 틀린 문제를 촬영해 오답노트를 만들 때 카메라를 사용합니다. |
| `NSPhotoLibraryUsageDescription` | 저장된 문제 사진을 불러와 오답노트를 만들 때 사진 보관함을 사용합니다. |

- **위 문구는 초안이다. 최종 문구는 사용자 확인을 받는다** (→ §9).
- `NSPhotoLibraryAddUsageDescription`은 **추가하지 않는다.** 앨범에 쓰지 않는다.
- CloudKit entitlement를 여기서 건드리지 않는다 (7단계 소관).

## 6. 수용 기준

- [ ] `ReviewScheduler.swift`가 `Foundation`만 import한다 (SwiftData·SwiftUI·Vision·UIKit 없음)
- [ ] [03 §3](../03-domain-logic.md#3-스페이스드-리피티션--reviewschedulerswift)의 **테스트 벡터 표 9행 전부**가 테스트로 존재하고 통과한다
- [ ] `box 4 + correct → 4` 상한, `box 99 / −1` 클램프가 테스트로 검증된다
- [ ] `initialSchedule`이 **생성 당일이 아니라 다음 날**을 반환하고, 그것이 테스트된다
- [ ] `isDue` 경계 3종(같은 날·하루 전·하루 후)과 밀린 카드 케이스가 테스트된다
- [ ] 날짜 테스트가 고정 타임존(`Asia/Seoul`) `Calendar`를 주입한다
- [ ] 날짜 계산이 `Calendar`를 통해서만 이뤄진다 (`86400` 산술 없음, 함수 내 `Calendar.current` 없음)
- [ ] `TextRecognizer.swift`가 **Vision을 import하는 유일한 파일**이다
- [ ] OCR이 온디바이스이며 `URLSession`·외부 OCR SDK를 쓰지 않는다
- [ ] 인식 언어가 한국어 + 영어이고, 수식/LaTeX 처리를 시도하지 않는다
- [ ] 생성 플로우에서 **텍스트 확인·수정 단계를 건너뛸 수 없다**
- [ ] OCR 실패·0자 인식이 얼럿이 아니라 **빈 텍스트 필드 + 직접 입력 안내**로 이어진다
- [ ] `ocrRawText`와 `userEditedText`가 둘 다 저장되고, 표시에는 `userEditedText`가 쓰인다
- [ ] `imageFileName`에 **파일명만** 저장된다 (전체 경로 없음)
- [ ] `NoteImageStore`가 `Foundation`만 import한다 (UIKit 없음)
- [ ] 저장 시 `schoolSubject`/`mockExamSubject` 중 **정확히 하나만** non-nil이고, 둘 다 넣을 수 있는 생성 경로가 없다
- [ ] 신규 카드가 box 0, 다음 날 복습으로 저장된다
- [ ] 영어 하위 카테고리 필터가 **과목명 문자열 매칭이 아니라** `englishSubcategory` 존재 여부로 노출된다
- [ ] 플래시카드에 **"맞음/틀림" 두 개 동작만** 있다 (난이도 단계 없음)
- [ ] 밀린 카드가 계속 due로 남고, **압박 문구가 없다** (문구를 눈으로 검수했다)
- [ ] 정답률·스트릭·점수 같은 통계를 만들지 않았다
- [ ] 과목 상세가 성적 추이 + 진척 게이지 + 오답노트 리스트 3섹션이고, 4단계 컴포넌트를 재사용했다
- [ ] 내비게이션 깊이가 3을 넘지 않는다
- [ ] 목표 미달이 빨간색으로 표시되지 않는다
- [ ] `project.yml`에 카메라·사진첩 권한 문구가 있고 `xcodegen generate` 후 Info.plist에 반영된다
- [ ] SwiftData 모델을 변경하지 않았다
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

Vision import가 한 파일에만 있는지 확인:

```bash
grep -rn "import Vision" Studion/ | grep -v "Utilities/TextRecognizer.swift"   # 출력이 없어야 한다
grep -rn "import UIKit\|import SwiftUI\|import SwiftData" Studion/Utilities/    # 출력이 없어야 한다
```

### OCR 테스트용 이미지 준비 (시뮬레이터에는 카메라가 없다)

시뮬레이터는 카메라를 지원하지 않는다. **사진첩에 이미지를 넣어 테스트한다.**

```bash
# 1) 한국어+영어 텍스트가 있는 화면을 캡처해 샘플 이미지를 만든다
#    (시중 교재·기출문제 사진을 쓰지 않는다 — 제3자 저작물 금지)
screencapture -x /tmp/ocr-sample.png

# 2) 부팅된 시뮬레이터의 사진첩에 추가
xcrun simctl addmedia booted /tmp/ocr-sample.png
```

카메라 경로는 시뮬레이터에서 검증할 수 없다. **카메라 항목이 시뮬레이터에서 숨겨지는지**만 확인하고, 실제 촬영 동작은 코드 리뷰로 확인한다.

### 시뮬레이터 시나리오 검증 (스크린샷 필수)

1. 과목 리스트에서 과목 탭 → **과목 상세 3섹션**이 보이는지 (추이 / 게이지 / 오답노트 빈 상태)
2. 툴바 `+` → 사진첩에서 위에서 넣은 샘플 이미지 선택 → **OCR 진행 표시**가 뜨는지
3. **텍스트 확인 단계가 반드시 나타나는지** — 이 단계를 건너뛸 방법이 없는지 직접 시도
4. 텍스트를 일부 수정 → 원인 태그 선택 → 저장 → 리스트에 `WrongAnswerCard`가 나타나는지
5. 저장된 카드 상세 → "원본 인식 결과 보기"를 펼쳐 **`ocrRawText`가 수정 전 값 그대로**인지
6. **인식할 글자가 없는 이미지**(단색 배경)로 다시 시도 → 얼럿 없이 **빈 필드 + 안내 문구**로 넘어가는지
7. 영어 하위 카테고리를 지정한 카드를 하나 만들고, 그때만 **필터가 나타나는지** (지정 전에는 안 보여야 함)
8. 복습 진입 → 방금 만든 카드는 **오늘 due가 아니어야** 하므로 "오늘 복습할 카드가 없어요"가 뜨는지
9. `nextReviewDate`를 과거로 만든 카드로 복습 세션 → **"맞음/틀림" 두 버튼만** 있는지, 누른 뒤 다음 복습일이 갱신되는지
10. 화면 전체 문구에 "밀렸습니다" 류 압박 표현이 없는지 눈으로 검수
11. 다크모드 확인
12. Dynamic Type AX5에서 카드·플래시카드 레이아웃 확인

## 8. 범위 밖 (하지 않는다)

- **복습 알림 스케줄링 (`UNUserNotificationCenter`) — 9단계.** 알림 권한 요청도 이 단계에서 하지 않는다
- 이미지 CloudKit 동기화 방식 결정·구현 — **7단계** ([06 §이미지 자산 처리](../06-sync-and-backup.md#이미지-자산-처리--미해결-과제))
- Sign in with Apple, CloudKit entitlement, `ModelConfiguration` 변경 — 7단계
- JSON 백업/복원, 설정 탭의 알림 on/off·테마·언어 — 8단계
- 온보딩, 빈 상태 전수 다듬기 — 9단계
- 수학 기호·LaTeX 인식, 손글씨 특화 처리, 이미지 자동 크롭·원근 보정
- OCR 결과 자동 교정·정규식 후처리
- 오답 통계 대시보드, 정답률, 연속 학습일(스트릭), 게임화 요소
- 다중 이미지 첨부, 이미지 위 필기 주석
- 오답노트 검색·전역 태그 관리 화면
- 서버 OCR·외부 OCR SDK (원칙 위반)
- String Catalog 파일 생성 — 8단계
- 4단계 산출물(모의고사 화면·차트·`ProgressGauge`)의 기능 변경 — 진입 링크 외 수정 금지

## 9. 막히면

- **카메라·사진첩 권한 문구 (사용자 확인 필요)**: §5-10의 초안을 제시하고 **승인을 받은 뒤** `project.yml`에 넣는다. 임의 확정하지 않는다. [tasks/README.md](README.md)의 단계 표에도 "카메라 권한 문구"가 사용자 확인 항목으로 명시돼 있다.
- **이미지 CloudKit 동기화 (미해결 과제)**: 파일 시스템 이미지는 CloudKit으로 자동 동기화되지 않는다. A(`@Attribute(.externalStorage) Data`로 이전) / B(동기화 안 함을 명시) / C(`CKAsset` 직접 관리) 세 안이 있고 **7단계 착수 시 사용자에게 물어 결정한다** ([06 §이미지 자산 처리](../06-sync-and-backup.md#이미지-자산-처리--미해결-과제)). **6단계에서 임의로 스키마를 A로 바꾸지 않는다.** 현재의 "파일명만 참조" 형태를 그대로 유지해야 나중에 어느 쪽으로든 갈 수 있다.
- **OCR 정확도가 낮을 때**: 후처리 보정 로직을 만들지 않는다. 텍스트 확인·수정 단계(③)가 바로 그 역할이다. 정확도를 코드로 메우려 하지 않는다.
- **신규 카드를 생성 당일 복습에 넣을지**: 넣지 않는다 ([03 §3](../03-domain-logic.md#3-스페이스드-리피티션--reviewschedulerswift)). 방금 본 문제다.
- **밀린 카드를 어떻게 처리할지**: 계속 due로 남긴다. 자동으로 사라지게 하거나, 개수를 경고로 강조하거나, 압박 문구를 붙이지 않는다.
- **영어 과목인지 판정해야 할 것 같을 때**: 판정하지 않는다. `englishSubcategory`가 설정된 노트가 있는지만 본다. 과목명 문자열 매칭은 하드코딩된 과목 지식이며 설계 원칙 위반이다.
- **성적 추이를 동일 과목명으로 묶는 규칙**이 사용자 기대와 다를 것 같으면 묻는다. 과목 마스터 테이블을 새로 만들어 해결하려 하지 않는다.
- **4단계 산출물의 파일·심볼 이름이 이 스펙과 다르면**: 같은 것을 새로 만들지 말고 실제 이름을 확인해 재사용한다. 애매하면 묻는다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**
