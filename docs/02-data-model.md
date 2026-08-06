# 02. 데이터 모델

이 문서와 `Studion/Models/`의 `@Model` 코드는 **항상 1:1로 대응**해야 한다. 한쪽만 바꾸지 않는다.

## CloudKit 호환 제약 (모든 엔티티가 지켜야 함)

7단계에서 CloudKit Private Database와 연결하려면 SwiftData 스키마가 아래를 만족해야 한다. **1단계부터 지켜서 설계했고, 이후 모델 변경 시에도 반드시 유지한다.**

| 제약 | 이유 |
|---|---|
| 모든 저장 속성에 **기본값**이 있거나 옵셔널 | CloudKit은 스키마 마이그레이션 시 기존 레코드를 채울 값이 필요 |
| 모든 **관계는 옵셔널** | CloudKit은 필수 관계를 지원하지 않음 |
| `@Attribute(.unique)` **사용 금지** | CloudKit이 유니크 제약을 지원하지 않음 |
| 관계는 항상 **양방향** (`inverse:` 명시) | CloudKit 동기화 시 역참조 필요 |
| enum은 **rawValue(String) 저장 + computed property**로 노출 | CloudKit이 Swift enum을 직접 저장 못 함 |

enum 저장 패턴 (전 엔티티 공통):

```swift
var evaluationTypeRaw: String = SchoolSubjectEvaluationType.achievementAndRank.rawValue

var evaluationType: SchoolSubjectEvaluationType {
    get { SchoolSubjectEvaluationType(rawValue: evaluationTypeRaw) ?? .achievementAndRank }
    set { evaluationTypeRaw = newValue.rawValue }
}
```

---

## 엔티티 관계도

```
AcademicProfile  (단일 인스턴스 — 앱 전역 설정)

Semester ─1:N─ SchoolSubjectRecord ─1:N─ WrongAnswerNote
                                              │
MockExamSession ─1:N─ MockExamSubjectRecord ─1:N┘
   (WrongAnswerNote는 둘 중 한쪽에만 연결됨 — 양쪽 다 옵셔널)

TimetableEntry   (독립)
PlanItem         (독립)
```

---

## Enum 정의 — `Models/GradingSystemType.swift`

### `GradingSystemType`
내신 등급 산출 제도.

| case | 의미 | 누적 경계값 |
|---|---|---|
| `fiveTier` | 5등급제 (2025년 고1 입학생~) | `[0.10, 0.34, 0.66, 0.90, 1.00]` |
| `nineTier` | 9등급제 (2024년 이전 입학생) | `[0.04, 0.11, 0.23, 0.40, 0.60, 0.77, 0.89, 0.96, 1.00]` |

`cumulativeBoundaries`는 **상위 누적 비율의 오름차순**이며 마지막 값은 항상 `1.00`이다.
`tierCount`는 경계값 개수(5 또는 9).

### `SchoolSubjectEvaluationType`
내신 과목의 등급 산출 방식. **하드코딩된 과목 매핑표를 두지 않고 사용자가 과목 등록 시 직접 지정한다.**

| case | 의미 | 해당 과목 예 |
|---|---|---|
| `achievementAndRank` | 성취도(A~E) + 석차등급 둘 다 | 일반 과목 |
| `achievementOnly` | 성취도만 (등급 입력 필드 자체를 숨김) | 사회·과학 융합선택 9과목, 체육·예술·교양, 과학탐구실험 |

### `AchievementLevel`
`A` / `B` / `C` / `D` / `E`. rawValue는 대문자 알파벳.

### `WrongAnswerCauseTag`
오답 원인. `dontKnow`(몰라서) / `mistake`(실수) / `timeShortage`(시간부족) / `trap`(함정)

### `EnglishSubcategory`
영어 과목 오답노트 필터용. `reading` / `grammar` / `vocabulary` / `listening`

### `TimetableEntryType`
`school` / `academy`. 캘린더에서 색상으로 구분.

---

## `AcademicProfile`

사용자의 학년/입학연도/기본 등급제. **앱 전체에서 단일 인스턴스**로 사용한다 (없으면 생성).

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `admissionYear` | `Int` | `2025` | 입학연도. 등급제 자동 제안의 근거 |
| `gradeLevel` | `Int` | `1` | 학년 (1~3) |
| `gradingSystemTypeRaw` | `String` | `fiveTier` | 기본 등급제. **사용자가 수동 덮어쓰기 가능** |
| `createdAt` | `Date` | `Date()` | |

**등급제 자동 제안 규칙**: `admissionYear >= 2025` → `fiveTier`, 그 미만 → `nineTier`.
제안일 뿐이며 사용자가 설정에서 바꿀 수 있다 (형/누나 등 다른 학년대 사용자 대응).

---

## `Semester`

학기 단위(예: 고1-1학기). 내신 과목 기록을 묶는다.

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `year` | `Int` | `2025` | |
| `term` | `Int` | `1` | 1 또는 2 |
| `gradingSystemTypeRaw` | `String` | `fiveTier` | **학기별로 등급제를 고정 저장**한다 |
| `createdAt` | `Date` | `Date()` | |
| `subjectRecords` | `[SchoolSubjectRecord]?` | `[]` | cascade 삭제 |

> **왜 학기마다 등급제를 저장하나**: 제도 전환기에는 한 사용자가 서로 다른 등급제의 학기를 동시에 가질 수 있다. 프로필 값을 매번 참조하면 과거 학기 기록이 소급 변경되어 버린다. 학기 생성 시 프로필 값을 복사해 고정한다.

---

## `SchoolSubjectRecord`

내신 과목 하나의 학기별 성적.

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `subjectName` | `String` | `""` | 사용자 자유 입력 |
| `creditUnits` | `Double` | `0` | 이수단위. 가중평균 계산에 사용 |
| `rawScore` | `Double?` | nil | 원점수 |
| `subjectAverage` | `Double?` | nil | 과목평균 |
| `stdDeviation` | `Double?` | nil | 표준편차 |
| `studentCount` | `Int?` | nil | 수강인원 |
| `evaluationTypeRaw` | `String` | `achievementAndRank` | 등급 산출 여부 분기 |
| `achievementLevelRaw` | `String?` | nil | 성취도 A~E |
| `rankGrade` | `Int?` | nil | 석차등급. `achievementOnly`면 **항상 nil** |
| `targetGrade` | `Int?` | nil | 이 학기 목표 등급 (사용자 입력) |
| `createdAt` | `Date` | `Date()` | |
| `semester` | `Semester?` | nil | |
| `wrongAnswerNotes` | `[WrongAnswerNote]?` | `[]` | cascade 삭제 |

**불변식**
- `evaluationType == .achievementOnly` → `rankGrade == nil`, `targetGrade == nil` (UI에서 입력 필드 자체를 숨긴다)
- `rankGrade` 유효 범위는 `1...semester.gradingSystemType.tierCount`

---

## `MockExamSession`

모의고사 회차. 등급컷 데이터를 앱이 보유하지 않으므로 **회차명은 항상 사용자 입력**이다 (예: "2026년 6월 학평").

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `name` | `String` | `""` | 사용자 입력 |
| `examDate` | `Date` | `Date()` | 추이 그래프의 x축 |
| `createdAt` | `Date` | `Date()` | |
| `subjectRecords` | `[MockExamSubjectRecord]?` | `[]` | cascade 삭제 |

---

## `MockExamSubjectRecord`

회차 내 과목별 성적. **네 값 모두 사용자 직접 입력**이며 앱이 서로 환산하거나 추정하지 않는다.

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `subjectName` | `String` | `""` | |
| `rawScore` | `Double?` | nil | 원점수 |
| `standardScore` | `Double?` | nil | 표준점수 |
| `percentile` | `Double?` | nil | 백분위 |
| `grade` | `Int?` | nil | 등급 (1~9 고정 — 수능은 9등급 유지) |
| `createdAt` | `Date` | `Date()` | |
| `session` | `MockExamSession?` | nil | |
| `wrongAnswerNotes` | `[WrongAnswerNote]?` | `[]` | cascade 삭제 |

> 모의고사는 **항상 9등급제**다. 내신 등급제 설정과 무관하다.

---

## `WrongAnswerNote`

오답노트 카드. 내신 과목과 모의고사 과목 중 **한쪽에만** 연결된다 (양쪽 다 옵셔널 — CloudKit 제약).

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `ocrRawText` | `String` | `""` | OCR 원본. 보존용(수정하지 않음) |
| `userEditedText` | `String` | `""` | 지문·문제·선택지를 합친 통짜 텍스트. 목록 미리보기와 백업이 쓴다. 저장 시 아래 칸들로부터 다시 만든다 |
| `passageText` | `String` | `""` | 문제 앞에 딸려오는 지문 |
| `promptText` | `String` | `""` | 실제로 묻는 문장. **저장하려면 이 칸이 비어 있지 않아야 한다** |
| `choices` | `[String]` | `[]` | 객관식 선택지. 서술형이면 빈 배열 |
| `explanation` | `String` | `""` | 해설 메모 (선택) |
| `isMultipleChoice` | `Bool` | `false` | 선택지가 2개 이상일 때만 참 |
| `correctChoiceIndex` | `Int?` | nil | 사용자가 지정한 정답. **앱이 추정하지 않는다** |
| `causeTagRaw` | `String` | `dontKnow` | 오답 원인 |
| `englishSubcategoryRaw` | `String?` | nil | 영어 과목에서만 사용 |
| `imageData` | `Data?` | nil | `@Attribute(.externalStorage)`. SwiftData가 파일로 분리 저장하고 CloudKit이 자산으로 동기화한다 |
| `createdAt` | `Date` | `Date()` | |
| `leitnerBoxIndex` | `Int` | `0` | 0~4 |
| `nextReviewDate` | `Date` | `Date()` | 복습 알림 스케줄 기준 |
| `lastReviewedAt` | `Date?` | nil | |
| `schoolSubject` | `SchoolSubjectRecord?` | nil | |
| `mockExamSubject` | `MockExamSubjectRecord?` | nil | |

**불변식**: `schoolSubject`와 `mockExamSubject` 중 정확히 하나만 non-nil. (스키마로 강제 못 하므로 생성 시점 코드에서 보장한다.)

**칸 나누기**: OCR로 읽은 통짜 텍스트를 `OCRQuestionSplitter`가 지문/문제/선택지로 나눠 폼에 채운다. 나눔은 제안일 뿐이고 모든 칸은 손으로 고칠 수 있다. 칸을 나누기 전에 만든 옛 노트는 구조화 필드가 비어 있는데, 모델의 `content` 프로퍼티가 그럴 때 `userEditedText`를 그때그때 나눠 돌려준다 — 일괄 마이그레이션 없이 옛 노트도 새 화면에서 제대로 보이고, 사용자가 그 노트를 열어 저장하면 그때 정착된다.

**Leitner 간격**: box 0→1일, 1→3일, 2→7일, 3→14일, 4→30일. 상세 → [03](03-domain-logic.md#3-스페이스드-리피티션).

**이미지 저장 전략**: `@Attribute(.externalStorage)`로 SwiftData 외부 저장소에 둔다. SwiftData가 큰 바이너리를 파일로 분리 관리하고 CloudKit이 자산으로 동기화하므로, 기기를 바꿔도 이미지가 따라온다.
저장 전 리사이즈·JPEG 압축으로 용량을 억제한다 (→ [06](06-sync-and-backup.md#이미지-자산-처리--결정됨-swiftdata-외부-저장)).

---

## `TimetableEntry`

학교/학원 시간표 한 칸.

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `dayOfWeek` | `Int` | `2` | **Calendar 컨벤션: 1=일요일 … 7=토요일** |
| `startTime` | `Date` | `Date()` | 시각(시:분)만 의미 있음. 날짜 부분 무시 |
| `endTime` | `Date` | `Date()` | 동일 |
| `title` | `String` | `""` | 과목명 또는 학원명 |
| `typeRaw` | `String` | `school` | 캘린더 색상 구분 |
| `repeatsWeekly` | `Bool` | `true` | 기본값 매주 반복 |
| `createdAt` | `Date` | `Date()` | |

**불변식**: `startTime < endTime` (자정 넘김은 1차 범위에서 지원하지 않음. 입력 시 검증한다.)

---

## `PlanItem`

일간 계획/할 일.

| 속성 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `title` | `String` | `""` | |
| `date` | `Date` | `Date()` | **하루 단위 비교** — 시각 무시, `Calendar.startOfDay` 기준 |
| `isDone` | `Bool` | `false` | |
| `relatedSubjectName` | `String?` | nil | 자유 입력. 과목 마스터 테이블 없음 |
| `createdAt` | `Date` | `Date()` | |

> `date`를 하루 단위로 다룰 때는 항상 `Calendar.current.startOfDay(for:)`로 정규화한 뒤 비교한다. 저장 시에도 정규화한다.

---

## 과목 동일성 판정 규칙

이 앱에는 **과목 마스터 테이블이 없다.** 고교학점제로 학생마다 이수 과목이 다르기 때문이다 (→ [00](00-product-principles.md) 원칙 7).

교육과정 프리셋(`CurriculumPreset`)은 **입력을 돕는 값일 뿐 마스터 테이블이 아니다.** 프리셋으로 넣은 과목도 저장되고 나면 사용자가 직접 만든 과목과 완전히 같으며, 이름을 바꾸면 그때부터 다른 과목이 된다.

따라서 "같은 과목"인지는 **`subjectName` 문자열로 판정**한다. 학기를 가로지르는 성적 추이, 과목 상세 화면의 데이터 수집이 전부 이 규칙에 의존한다.

### 규칙

1. 비교 전 **앞뒤 공백을 제거**(`trimmingCharacters(in: .whitespacesAndNewlines)`)한 뒤 **완전 일치**로 판정한다.
2. 저장 시점에도 trim한다. 비교할 때만 trim하지 않는다.
3. `SchoolSubjectRecord.subjectName`과 `MockExamSubjectRecord.subjectName`은 **서로 다른 네임스페이스**다. 내신 "수학"과 모의고사 "수학"을 자동으로 같은 과목으로 묶지 않는다 (평가 체계가 다르므로).

### 한계 — 그대로 수용한다

- 사용자가 "수학"과 "수학 I"을 섞어 입력하면 **다른 과목으로 취급**된다. 앱이 유사도로 추측해 병합하지 않는다. 잘못 묶는 것이 안 묶는 것보다 나쁘다.
- 이 한계를 UI에서 자동 교정하려 하지 말고, **과목 추가 시 기존 과목명을 자동완성으로 제안**해 입력 단계에서 표기를 통일시킨다.

### 이름 변경 시 (8단계 이수 과목 관리)

과목명을 바꾸면 **같은 이름을 쓰던 기존 레코드도 함께 갱신**해야 한다. 그러지 않으면 추이가 두 갈래로 쪼개진다.
변경 전에 영향받는 레코드 수를 사용자에게 알린다.

---

## 마이그레이션 정책

1차 개발 중에는 스키마가 자주 바뀐다. **정식 배포 전까지는** SwiftData 자동 경량 마이그레이션에 의존하고, 호환 불가한 변경 시 시뮬레이터 앱을 삭제해 초기화한다.

**첫 App Store 배포 이후**에는 `VersionedSchema` + `SchemaMigrationPlan`을 도입한다. 그 시점 전까지 스키마 버전 관리 코드를 미리 만들지 않는다.
