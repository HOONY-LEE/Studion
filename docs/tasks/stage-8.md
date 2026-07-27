# 8단계 — 설정 (테마 / 언어 / 데이터 관리)

## 1. 목표

2단계에서 플레이스홀더로 남겨둔 설정 탭을 `Form` 기반으로 완성한다.
**다크/라이트/시스템 테마 전환**, **String Catalog 기반 다국어(한국어/영어)**, **이수 과목 관리**, **JSON 백업/복원**이 이 단계의 네 축이다.

이 단계가 끝나면 사용자는 앱 모양과 언어를 직접 고르고, 학사 정보와 이수 과목을 관리하고, **로그인 없이도 기기 변경에 대응**할 수 있다.

> JSON 백업은 CloudKit의 대체재가 아니라 **독립 수단**이다. 7단계 동기화를 켜지 않은 사용자에게도 데이터 이전 경로가 있어야 한다.

## 2. 선행 조건

- 7단계 완료 (설정 탭에 **동기화(Apple로 로그인) 항목**이 이미 존재)
- 2~6단계 완료 — 백업 대상 엔티티(`Semester`, `SchoolSubjectRecord`, `MockExamSession`, `MockExamSubjectRecord`, `WrongAnswerNote`, `TimetableEntry`, `PlanItem`, `AcademicProfile`)가 **전부 확정**되어 있어야 한다
- `Studion/Views/Settings/SettingsView.swift`가 2단계의 `EmptyStateView` 플레이스홀더 상태 — **이 단계에서 `Form`으로 교체한다**
- `Studion/Views/RootView.swift`가 탭 구성만 하고 있음 — **테마·로케일 적용을 여기에 추가한다**
- `Studion/Resources/`에 `Localizable.xcstrings`가 **아직 없다** — 이 단계에서 생성한다
- `project.yml`에 `SWIFT_EMIT_LOC_STRINGS: YES`가 **이미 설정되어 있다.** 다시 넣지 않는다

## 3. 참조 문서

| 문서 | 섹션 | 중요도 |
|---|---|---|
| [05-localization-a11y.md](../05-localization-a11y.md) | §1 다국어 **전체**, §2 접근성, §3 컬러 팔레트·다크모드 | ★ 필수 |
| [06-sync-and-backup.md](../06-sync-and-backup.md) | §4 JSON 백업/복원 **전체**, §2 로그인은 선택 기능 | ★ 필수 |
| [04-ui-spec.md](../04-ui-spec.md) | §4 설정 탭, §테마 적용 규칙, §8 입력 검증 | ★ 필수 |
| [02-data-model.md](../02-data-model.md) | `AcademicProfile` 및 **전 엔티티 속성표** (DTO 설계 근거) | ★ 필수 |
| [01-architecture.md](../01-architecture.md) | §Utilities는 순수해야 한다 | |
| [00-product-principles.md](../00-product-principles.md) | 사용자 데이터 서버 없음 | |

## 4. 만들 파일

**신규**
```
Studion/Views/Settings/AppAppearance.swift               # 테마·언어 enum + @AppStorage 키
Studion/Views/Settings/AcademicProfileSection.swift      # 학사 정보 섹션
Studion/Views/Settings/SubjectManagementView.swift       # 이수 과목 추가/삭제/이름 변경
Studion/Views/Settings/Backup/BackupDTO.swift            # 순수 Codable DTO (백업 전용)
Studion/Views/Settings/Backup/BackupService.swift        # 모델 ↔ DTO 변환, 검증, 적용
Studion/Views/Settings/Backup/BackupDocument.swift       # FileDocument (fileExporter용)
Studion/Views/Settings/Backup/DataSection.swift          # 데이터 섹션 UI (내보내기/가져오기)
StudionTests/BackupDTOTests.swift
```

**수정**
```
Studion/Views/Settings/SettingsView.swift   # 플레이스홀더 → Form 기반 7개 섹션
Studion/Views/RootView.swift                # .preferredColorScheme + .environment(\.locale)
```

**Resources 추가**
```
Studion/Resources/Localizable.xcstrings     # String Catalog (한국어 base + 영어 구조)
```

**최소 수정 허용 (문자열 형태 교정에 한함)**
```
Studion/Views/**/*.swift   # 보간 문자열 → 포맷 인자 분리, 하드코딩 포맷 → FormatStyle
```

> 위 "최소 수정"은 **문자열/포맷 표현만** 고치는 것이다. 레이아웃·로직·계층 구조를 이 단계에서 바꾸지 않는다.
> `project.yml`은 건드리지 않는다. `sources: Studion` 전체가 포함되므로 `Localizable.xcstrings`는 `xcodegen generate`만으로 타깃에 들어간다.
> 알림 섹션은 **자리만** 만든다. 실제 로컬 알림 스케줄링은 9단계 소관이다.

## 5. 구현 명세

### 5-1. `SettingsView` — `Form` 기반 7개 섹션

[04 §4](../04-ui-spec.md#4-설정-settings-탭)의 **섹션 순서를 그대로** 따른다. 순서를 바꾸지 않는다.

| # | 섹션 | 내용 | 담당 |
|---|---|---|---|
| 1 | 동기화 | Apple로 로그인 (7단계 산출물) | 그대로 유지 |
| 2 | 모양 | 라이트 / 다크 / 시스템 Picker | 5-2 |
| 3 | 언어 | 한국어 / English / 시스템 Picker | 5-3 |
| 4 | 학사 정보 | 학년, 입학연도 → 등급제 제안 + 수동 덮어쓰기 | 5-5 |
| 5 | 이수 과목 | 추가 / 삭제 / 이름 변경 (하위 화면) | 5-6 |
| 6 | 알림 | **자리만** — 9단계 안내 문구 | — |
| 7 | 데이터 | JSON 내보내기 / 가져오기 | 5-7 |

**규칙**
- 1번 섹션의 로그인 항목을 **위치 이동하거나 문구를 바꾸지 않는다.** 잠금 아이콘·업셀 배너를 추가하지 않는다 ([06 §2](../06-sync-and-backup.md#2-로그인은-선택-기능이다-엄격)).
- 각 섹션은 `Section` + 필요 시 `footer`로 설명을 단다. 얼럿으로 설명하지 않는다.
- 설정 탭도 자체 `NavigationStack`을 유지한다 (2단계 구조 보존). `navigationTitle("설정")`.
- 6번 알림 섹션은 비활성 행 + "알림은 다음 업데이트에서 추가됩니다" 수준의 안내만 둔다. **`UNUserNotificationCenter`를 import하지 않는다.**

### 5-2. 테마 — `AppAppearance` (★ 규칙이 명시적이다)

```swift
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var colorScheme: ColorScheme? { ... }   // system → nil
}
```

- `@AppStorage("appAppearance")`에 rawValue를 저장한다.
- 적용은 **`RootView` 한 곳에서만** 한다. 개별 화면에 `.preferredColorScheme`을 흩뿌리지 않는다.

```swift
// ★ "시스템 설정 따르기"일 때는 modifier를 아예 적용하지 않는다 (nil 전달)
.preferredColorScheme(appearance == .system ? nil : appearance.colorScheme)
```

- `.system`일 때 `.light`를 기본값으로 밀어 넣지 않는다. **`nil`이어야** iOS가 시스템 설정을 그대로 따른다.
- Picker는 `.pickerStyle(.segmented)` 또는 `.menu`. 3택 외의 옵션(예: "자동 스케줄")을 만들지 않는다.

### 5-3. 언어 — `AppLanguage`

```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, korean, english
    var locale: Locale? { ... }   // system → nil
}
```

- `@AppStorage("appLanguage")` 저장, `RootView` 최상위에서 `.environment(\.locale, ...)` 주입.
- **시스템 언어와 별개로 강제 전환**되어야 한다 ([05 §앱 자체 언어 전환](../05-localization-a11y.md#앱-자체-언어-전환)).
- `.system`이면 환경 로케일을 덮어쓰지 않는다 (테마와 동일한 nil 원칙).
- 언어 전환 시 **앱 재시작을 요구하지 않는다.** 재시작 안내 얼럿을 만들지 않는다. 즉시 반영되지 않는 부분이 있으면 그 사실을 보고한다(임의 회피 코드 작성 금지).
- 섹션 footer에 "시스템 언어와 다르게 설정할 수 있습니다" 정도의 목적 설명을 둔다.

### 5-4. String Catalog — `Localizable.xcstrings` (★ 이 단계의 절반)

- `Studion/Resources/Localizable.xcstrings` **하나만** 만든다. `.strings`·`.stringsdict`를 새로 만들지 않는다 ([05 §1](../05-localization-a11y.md#1-다국어-localization)).
- 언어: **한국어(base) + 영어**. 한국어를 채우고 **영어는 구조만** 갖춘다.
- 기존 전 화면(2~7단계)의 하드코딩 문자열을 훑어 **추출 가능한 형태인지 점검**한다.

```swift
// ❌ 보간을 통째로 넘기면 추출되지 않는다
Text("\(subjectName) 과목")
// ✅ 포맷 인자로 분리하거나 comment를 명시
Text("\(subjectName) 과목", comment: "과목 상세 화면 제목")
```

**한국 교육 특화 용어 — 별도 취급**

"내신", "수능", "석차등급", "이수단위", "학평" 등은 직역하면 의미가 사라진다.

- String Catalog에서 이 키들에 **`education-terms` 코멘트를 붙여 구분**한다. 코멘트 문자열을 통일한다.
- 영어는 직역이 아니라 **음차 + 짧은 설명** 방식을 검토한다 (예: `Naesin (school GPA)`).
- **실제 영문 번역 문구 확정은 1차 범위 밖이다.** 구조(키·코멘트·영어 슬롯)만 잡고 한국어를 채운다. 기계 번역으로 영어 칸을 임의로 메우지 않는다.

**로케일 의존 포맷**

| 하지 않는다 | 대신 |
|---|---|
| `DateFormatter().dateFormat = "yyyy년 M월 d일"` | `date.formatted(.dateTime.year().month().day())` |
| `String(format: "%.2f", value)` | `value.formatted(.number.precision(.fractionLength(2)))` |

- 요일 순서는 `Calendar.current.firstWeekday`를 참조한다. 다만 **시간표 UI는 월요일 시작이 관례**다.
- 이 차이를 숨기지 말고 **View에서 명시적으로 처리**하고 주석으로 이유를 남긴다 ([05 §로케일 의존 포맷](../05-localization-a11y.md#로케일-의존-포맷)).
- 백업 JSON의 날짜는 **로케일과 무관한 ISO8601**이다. 표시용 포맷과 혼동하지 않는다 (5-7 참조).

### 5-5. 학사 정보 — 자동 제안, 강제 아님

`AcademicProfile`은 **단일 인스턴스**다. 없으면 생성한다 ([02 §AcademicProfile](../02-data-model.md#academicprofile)).

| 항목 | 컨트롤 | 규칙 |
|---|---|---|
| 학년 | `Picker` 1~3 | 자유 입력 금지 |
| 입학연도 | `Picker` 또는 `Stepper` | 합리적 범위로 제한 |
| 등급제 | `Picker` 5등급제 / 9등급제 | **수동 덮어쓰기 가능** |

**자동 제안 규칙**: `admissionYear >= 2025` → `fiveTier`, 미만 → `nineTier`.

- 입학연도를 바꾸면 등급제를 **제안**한다. 사용자가 직접 고른 값을 **덮어쓰지 않는다**.
- 제안과 현재 값이 다르면 인라인 안내 + "제안값으로 변경" 버튼 정도로 둔다. 자동 변경·얼럿 강요를 하지 않는다.
- 형/누나 등 다른 학년대 사용자가 있으므로 **수동 선택이 항상 우선**이다.
- ⚠️ 프로필 등급제를 바꿔도 **이미 만들어진 `Semester`의 등급제는 바뀌지 않는다** ([02 §Semester](../02-data-model.md#semester)). 이 사실을 footer로 한 줄 알린다. 소급 변경 코드를 작성하지 않는다.

### 5-6. 이수 과목 관리 — `SubjectManagementView`

- 학기를 고르고, 그 학기의 `SchoolSubjectRecord` 목록을 **추가 / 삭제 / 이름 변경**한다.
- **과목 마스터 테이블을 만들지 않는다.** 과목명은 사용자 자유 입력이며, 앱이 과목 목록을 내장하지 않는다 (절대 원칙 7).
- 이름 변경은 해당 학기 레코드에만 적용된다. 다른 학기 동일 이름 과목을 함께 바꾸지 않는다.
- 검증 ([04 §8](../04-ui-spec.md#8-입력-검증-정책)): 과목명 공백 불가 → **저장 버튼 비활성화**. 얼럿을 쓰지 않는다.
- 삭제는 `WrongAnswerNote`까지 cascade된다. **삭제 확인 다이얼로그를 거치고**, 연결된 오답노트가 함께 지워진다는 사실을 문구로 알린다.
- 성적 값 편집은 여기서 하지 않는다. 3단계 `SubjectFormView`가 담당한다. **기능을 중복 구현하지 않는다.**

### 5-7. JSON 백업 / 복원 (★ 가장 위험한 부분)

[06 §4](../06-sync-and-backup.md#4-json-백업--복원-8단계)의 명세를 그대로 구현한다.

#### 포맷

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-07-27T14:00:00Z",
  "academicProfile": { ... },
  "semesters": [ { ..., "subjectRecords": [ ... ] } ],
  "mockExamSessions": [ { ..., "subjectRecords": [ ... ] } ],
  "wrongAnswerNotes": [ ... ],
  "timetableEntries": [ ... ],
  "planItems": [ ... ]
}
```

- **최상위 `schemaVersion` 필드 필수.** 과거 백업 파일을 읽을 수 있어야 한다. 현재 값은 `1`.
- `schemaVersion`이 앱이 아는 값보다 크면 **읽지 않고 거부**한다("더 최신 버전에서 만든 백업입니다" + 다음 행동 안내).
- 날짜는 ISO8601로 인코딩한다. `JSONEncoder.dateEncodingStrategy = .iso8601`, 디코딩도 대칭으로 맞춘다.
- 사람이 열어볼 수 있게 `.prettyPrinted` + `.sortedKeys`를 쓴다.

#### DTO 규칙 (★)

- **SwiftData `@Model`을 직접 `Codable`로 만들지 않는다.** 별도 순수 DTO 구조체를 정의하고 변환한다. 모델 변경이 백업 포맷을 깨지 않게 하기 위함이다.
- DTO는 `Utilities/`가 **아니라** 백업 전용 파일(`Views/Settings/Backup/BackupDTO.swift`)에 둔다. 도메인 로직이 아니다.
- DTO는 `import Foundation`만 한다. **SwiftData·SwiftUI를 import하지 않는다.**
- enum은 rawValue(String)로 직렬화한다. 모델의 `~Raw` 속성을 그대로 옮긴다.
- 관계는 **중첩(nesting)** 으로 표현한다 (위 스케치대로). SwiftData 내부 ID를 백업에 노출하지 않는다.
- `WrongAnswerNote`는 `schoolSubject` / `mockExamSubject` 중 **정확히 하나**에만 매달린다. 이 불변식을 내보내기·가져오기 양쪽에서 유지한다.
- **이미지는 1차 백업 범위에서 제외한다.** `imageFileName`을 넣더라도 파일 실물은 백업되지 않는다. **그 사실을 데이터 섹션 footer에 명시**한다.

#### 내보내기

- `.fileExporter` + `FileDocument`(`BackupDocument`). Files 앱 연동.
- 기본 파일명에 날짜를 넣되 **하드코딩 포맷을 쓰지 않는다** (`.iso8601` 또는 `FormatStyle`).
- 내보내기 중 진행 표시. 실패 시 인라인 상태 문구로 알린다.

#### 가져오기 — 검증 먼저, 쓰기는 나중에 (★ 원자성)

```
① .fileImporter 로 파일 선택
      ↓
② 디코딩 + schemaVersion 확인 + 불변식 검증   ← 여기까지 실패하면 DB를 건드리지 않는다
      ↓
③ 요약 표시 (학기 n개 / 과목 n개 / 오답노트 n장 …)
      ↓
④ 덮어쓰기 / 병합 선택
      ↓
⑤ 확인 다이얼로그
      ↓
⑥ 적용
```

- **검증을 전부 먼저 수행하고, 통과한 뒤에 쓰기를 시작한다.** 복원이 실패해도 **부분 적용된 상태로 남지 않아야** 한다.
- 검증 항목: `schemaVersion` 범위, 필수 필드 존재, enum rawValue 유효성, `rankGrade`가 학기 `tierCount` 범위 내, `WrongAnswerNote` 소속 불변식, `startTime < endTime`.
- 검증 실패 시 **무엇이 왜 잘못됐는지 + 다음에 할 일**을 알린다. 원인만 말하고 끝내지 않는다 ([05 §5](../05-localization-a11y.md#5-문구ux-writing-원칙)).

#### 복원 정책 — 사용자에게 선택시킨다

| 방식 | 동작 | 확인 스타일 |
|---|---|---|
| 덮어쓰기 | 기존 데이터를 지우고 백업으로 교체 | **`.destructive` (시스템 red)** |
| 병합 | 기존 데이터를 두고 백업 내용을 추가 | 일반 |

- **파괴적 동작이므로 확인 다이얼로그(`confirmationDialog`) 필수.**
- 덮어쓰기 확인은 이 앱에서 **시스템 red를 쓰는 몇 안 되는 지점**이다 ([05 §3](../05-localization-a11y.md#3-컬러-팔레트)). 이 예외를 다른 화면으로 확대하지 않는다.
- 병합의 중복 판정 규칙을 임의로 정교화하지 않는다. **단순 추가**가 1차 동작이며, 그 결과(중복 가능)를 문구로 미리 알린다.
- 어느 쪽을 기본 선택으로 미리 체크해두지 않는다. 사용자가 고르게 한다.

### 5-8. `BackupDTOTests.swift` (권장, 강력히 권함)

- Swift Testing (`@Test` / `#expect`). XCTest 금지.
- **라운드트립 테스트**: DTO → JSON → DTO 후 값이 동일한지. 전 엔티티를 채운 픽스처로 검증한다.
- `schemaVersion` 누락·미래 버전 JSON이 **거부**되는지.
- 잘못된 enum rawValue, 범위 밖 `rankGrade`가 **검증 단계에서 걸리는지**.
- 날짜가 ISO8601로 대칭 인코딩/디코딩되는지 (로케일에 흔들리지 않는지).
- DTO 테스트는 `ModelContainer` 없이 돌아야 한다. 순수 값 타입만 다룬다.

### 5-9. 앱 전역 재점검

- **Dynamic Type AX5**에서 설정 Form의 Picker·행이 깨지지 않는지. 가로가 좁아지는 행은 `ViewThatFits`로 세로 대안을 준다.
- **다크모드**에서 전 화면을 다시 훑는다. 커스텀 색상(`GoalAchieved`, `ScheduleSchool`, `ScheduleAcademy`)이 Light/Dark 둘 다 정의되어 있는지 확인한다.
- 아이콘 전용 버튼에 `.accessibilityLabel`이 있는지, 터치 타깃이 44×44pt 이상인지.
- **목표 미달을 의미색으로 표시하지 않는다** (뉴트럴 그레이). 덮어쓰기 확인은 색이 아니라 아이콘·문구·확인 다이얼로그로 파괴성을 드러낸다.

## 6. 수용 기준

- [ ] 설정 탭이 `Form` 기반이고 섹션 순서가 동기화·모양·언어·학사 정보·이수 과목·알림·데이터다
- [ ] 7단계 로그인 항목이 위치·문구 그대로 유지되고, 잠금 아이콘·업셀 배너가 없다
- [ ] 테마 3택이 `@AppStorage`에 저장되고 `RootView`에서만 적용된다
- [ ] **"시스템"일 때 `.preferredColorScheme`에 `nil`이 전달된다** (기본값으로 light를 밀어 넣지 않았다)
- [ ] 언어 3택이 `@AppStorage` + `.environment(\.locale, ...)`로 즉시 반영되고, 재시작 안내를 띄우지 않는다
- [ ] `Studion/Resources/Localizable.xcstrings`가 존재하고 한국어가 채워져 있다
- [ ] `.strings`/`.stringsdict`를 새로 만들지 않았다
- [ ] 교육 특화 용어에 **`education-terms` 코멘트**가 붙어 있다
- [ ] 영어 칸은 **구조만** 잡혀 있고 기계 번역으로 임의로 메우지 않았다
- [ ] 하드코딩 날짜/숫자 포맷이 없다 (`DateFormatter.dateFormat`·`String(format:)` 미사용)
- [ ] 요일 순서에서 `Calendar.firstWeekday`와 시간표 월요일 시작 관례의 차이를 View에서 명시적으로 처리했다
- [ ] 입학연도 변경 시 등급제를 **제안**하며, 사용자 선택을 자동으로 덮어쓰지 않는다
- [ ] 프로필 등급제 변경이 기존 `Semester`에 소급 적용되지 않는다
- [ ] 이수 과목 추가/삭제/이름 변경이 동작하고, 과목 목록을 하드코딩하지 않았다
- [ ] 백업 JSON 최상위에 **`schemaVersion`** 이 있고, 미래 버전 파일을 거부한다
- [ ] `@Model`에 `Codable`을 직접 붙이지 않았고, **별도 DTO**로 변환한다
- [ ] DTO 파일이 `Utilities/`가 아닌 백업 전용 경로에 있고 SwiftData·SwiftUI를 import하지 않는다
- [ ] 이미지가 백업에서 제외된다는 사실이 **UI 문구로 명시**되어 있다
- [ ] 가져오기가 **검증 전부 통과 후에만** 쓰기를 시작한다 (부분 적용 상태가 남지 않는다)
- [ ] 덮어쓰기 / 병합을 사용자가 고르며, 기본 선택이 미리 체크되어 있지 않다
- [ ] 덮어쓰기 확인이 `.destructive`이고, red가 이 지점 외에 쓰이지 않았다
- [ ] DTO 라운드트립 테스트가 존재하고 통과한다
- [ ] 알림 섹션은 자리만 있고 `UNUserNotificationCenter`를 import하지 않았다
- [ ] `URLSession`·네트워크 코드를 추가하지 않았다 (백업은 로컬 파일 I/O만)
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

**DTO 라운드트립 테스트가 통과한 뒤에 복원 UI를 붙인다.** 검증되지 않은 복원 코드를 실데이터에 연결하지 않는다.

시뮬레이터 시나리오 검증 (스크린샷 필수):
1. 설정 탭 → **7개 섹션 순서** 확인
2. 모양 → **라이트 / 다크 / 시스템 3택을 모두 전환**하며 각각 스크린샷. 시스템 선택 후 iOS 외관을 바꿔 **따라가는지** 확인
3. 언어 → 한국어 ↔ English 전환. **시스템 언어와 다르게** 설정되는지 확인
4. 학사 정보 → 입학연도를 2024로 바꿔 9등급제 제안이 뜨는지, 수동으로 5등급제를 골랐을 때 **덮어쓰이지 않는지**
5. 이수 과목 → 추가 / 이름 변경 / 삭제(확인 다이얼로그 포함)
6. 데이터 → **내보내기** → Files에 저장 → 앱 데이터 일부 변경 → **가져오기(덮어쓰기)** → 원래 데이터로 복구되는지 **왕복 확인**
7. 가져오기(병합)로 한 번 더 — 중복 추가 동작이 문구대로인지
8. 손상된 JSON(필드 삭제)을 가져와 **DB가 변경되지 않는지** 확인
9. 다크모드 + Dynamic Type AX5에서 설정 화면 확인

## 8. 범위 밖 (하지 않는다)

- 온보딩 · 빈 상태 최종 마무리 (9단계)
- **로컬 알림 스케줄링·권한 요청** (9단계) — 알림 섹션은 자리만
- **실제 영문 번역 문구 확정** — 구조와 코멘트까지가 8단계
- 이미지(오답노트 사진) 백업 — 1차 범위 제외, UI에 명시만
- 콘텐츠 시스템 ([07-content-system-future.md](../07-content-system-future.md))
- CloudKit 동기화 로직 (7단계) — 백업은 CloudKit과 **독립적**이다
- 백업 자동화·스케줄 백업·클라우드 업로드
- `VersionedSchema` / `SchemaMigrationPlan` ([02 §마이그레이션 정책](../02-data-model.md#마이그레이션-정책) — 첫 배포 이후)
- 성적 값 편집 UI (3·4단계) — 이수 과목 관리는 이름·목록까지

## 9. 막히면

- **"시스템" 테마에서 무엇을 넘길지**: `nil`이다. `.light`를 기본값으로 두지 않는다. 문서에 명시되어 있다 ([04 §테마 적용 규칙](../04-ui-spec.md#테마-적용-규칙)).
- **언어 전환이 일부 화면에 즉시 반영되지 않을 때**: 우회 코드(앱 재시작 유도, 번들 스위칭)를 만들지 않는다. 어디가 반영되지 않는지 그대로 보고한다.
- **영어 번역을 어떻게 쓸지 모를 때**: 쓰지 않는다. 한국어를 채우고 영어는 비워 둔다. 기계 번역으로 메우지 않는다.
- **`@Model`에 `Codable`을 붙이면 편할 것 같을 때**: 붙이지 않는다. 모델 변경이 백업 포맷을 깨는 걸 막는 게 DTO의 존재 이유다.
- **병합 시 중복 판정 규칙이 필요해 보일 때**: 1차는 **단순 추가**다. 정교한 매칭 규칙을 임의로 설계하지 않는다. 필요하다고 판단되면 사용자에게 묻는다.
- **복원 중간에 실패했을 때**: 부분 적용을 허용하지 않는다. 검증을 앞으로 당기는 방향으로 고친다.
- **`schemaVersion`을 올려야 할 것 같을 때**: 이 단계에서는 `1`이다. 모델을 바꾸지 않았다면 올리지 않는다.
- **이수 과목이 과목 마스터 테이블을 필요로 하는 것처럼 보일 때**: 만들지 않는다. 과목은 항상 사용자가 추가한다. 설계 원칙이다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**
