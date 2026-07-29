# Studion — AI 작업 규칙

한국 고등학생용 **로컬 우선(local-first) 자기관리 앱**. iOS 17+ / SwiftUI / SwiftData.

이 파일은 이 저장소에서 작업하는 모든 AI 에이전트가 **매 세션 시작 시 읽는 운영 규칙**이다.
제품 설계의 단일 진실 소스는 [`docs/`](docs/README.md) 이며, 규칙과 설계가 충돌하면 `docs/`가 우선한다.

---

## 1. 절대 원칙 (위반 시 작업 중단하고 사용자에게 질문)

1. **사용자 데이터 서버 없음.** 성적·계획·오답노트를 개발자가 접근 가능한 서버/DB로 보내는 코드를 작성하지 않는다. REST 클라이언트, 백엔드 SDK, 애널리틱스, 크래시 리포터를 추가하지 않는다.
2. **네트워크 호출 금지 (1차 범위).** `URLSession`·`Network` 프레임워크를 사용하는 코드를 만들지 않는다. 유일한 예외는 7단계의 CloudKit(애플 인프라)이다.
3. **성적으로 남과 비교당하지 않는다.** 랭킹·점수 경쟁·친구·채팅·성적 피드를 만들지 않는다. (학습 탭의 문제집 공유는 예외 — 공유되는 것은 학습 자료이지 성적이 아니다. → `docs/08-question-bank.md`)
4. **광고·인앱결제 없음** (1차 범위).
5. **제3자 저작물 없음.** 시중 교재·기출문제 원문·가사 등을 코드나 시드 데이터에 포함하지 않는다.
6. **등급컷을 추정해 단정하지 않는다.** 모의고사 등급은 사용자 입력이 원천이다. 통계 기반 추정치를 보여줄 때는 반드시 "추정" 레이블을 함께 표시한다 (`docs/03-domain-logic.md` 참조).
7. **과목은 제안하되 단정하지 않는다.** 고1 공통과목(국가 교육과정)과 석차등급 산출 여부(교육부 훈령)는 프리셋으로 제공하되 **전부 수정 가능**해야 하고, 직접 입력 경로가 항상 열려 있어야 한다. 2·3학년 선택과목은 학교마다 다르므로 프리셋이 아니라 **이름 추천**만 한다. (→ `Studion/Utilities/CurriculumPreset.swift`)

## 2. 기술 규약

| 항목 | 규칙 |
|---|---|
| UI | SwiftUI 100%. UIKit은 SwiftUI로 불가능할 때만 `UIViewRepresentable`로 감싸고, **왜 불가능했는지 주석 필수** |
| 최소 타깃 | iOS 17.0 |
| 저장소 | SwiftData `@Model`. Core Data 직접 사용 금지 |
| 아키텍처 | 경량 MV. View가 `@Query`로 직접 관찰한다. **ViewModel 레이어를 기본으로 두지 않는다** |
| 도메인 로직 | `Studion/Utilities/`에 **순수 Swift**로 분리. SwiftData·SwiftUI를 import하지 않는다 (Android 이식 대비) |
| 문자열 | 하드코딩 금지. `String(localized:)` 또는 SwiftUI 자동 로컬라이징 리터럴 |
| 폰트 | `.font(.body)` 등 시맨틱 스타일만. 고정 포인트 크기 금지 (Dynamic Type) |
| 색상 | Asset Catalog Color Set. 코드에 `Color(red:green:blue:)` 하드코딩 금지 |
| 레이아웃 | 하드코딩된 width/height 금지. `ViewThatFits`·size class·`GeometryReader` 사용 (iPad 대비) |
| 아이콘 | SF Symbols만 |

## 3. 프로젝트 구조

```
project.yml              # 프로젝트 정의의 원천. .xcodeproj는 생성물이며 직접 편집하지 않는다
Studion/
  App/                   # 엔트리 포인트, ModelContainer 구성
  Models/                # SwiftData @Model + enum
  Views/                 # 화면. 탭별 하위 폴더로 분리
  Utilities/             # 순수 Swift 도메인 로직 (SwiftData/SwiftUI import 금지)
  Resources/             # Assets.xcassets, Localizable.xcstrings
StudionTests/            # Swift Testing (#expect / @Test). XCTest 신규 작성 금지
docs/                    # 설계 문서 (단일 진실 소스)
docs/tasks/              # 단계별 배치 태스크 스펙
```

**파일을 추가/삭제한 뒤에는 반드시 `xcodegen generate`를 실행한다.** `.xcodeproj`를 손으로 고치지 않는다.

## 4. 빌드·테스트·검증 커맨드

```bash
cd /Users/sunghoon/Desktop/Studion

# 프로젝트 재생성 (파일 추가/삭제 후 필수)
xcodegen generate

# 빌드
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'generic/platform=iOS Simulator' build

# 테스트
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# 빌드 산출물 경로 (시뮬레이터 설치용)
# ~/Library/Developer/Xcode/DerivedData/Studion-*/Build/Products/Debug-iphonesimulator/Studion.app
```

빌드 로그가 길다. 실패 원인을 찾을 때는 `2>&1 | grep -E "error:|warning:|BUILD|TEST"` 로 필터링한다.

**시뮬레이터 실행·스크린샷 검증**: iOS Simulator MCP 도구를 사용한다. `attach` → `launch`(위 `.app` 경로, bundle id `com.studion.app`) → `screenshot` 순서.

## 5. 단계 완료의 정의 (Definition of Done)

한 단계는 아래를 **모두** 만족해야 완료로 보고한다.

1. `xcodegen generate` 후 빌드 성공 (신규 경고 0)
2. 테스트 전체 통과 (해당 단계가 요구한 테스트 포함)
3. 시뮬레이터에 설치·실행하여 **스크린샷으로 화면 확인** (UI가 없는 단계는 생략)
4. 해당 단계 태스크 스펙(`docs/tasks/stage-N.md`)의 **수용 기준을 항목별로 자기 점검**
5. 원칙 위반 없음 (§1 체크)

빌드나 테스트가 실패한 채로 "완료"라고 보고하지 않는다. 막히면 무엇이 왜 막혔는지 그대로 보고한다.

## 6. 배치 실행 규칙

각 단계는 `docs/tasks/stage-N.md` 하나만 읽고도 독립 실행 가능하도록 작성되어 있다. 배치로 실행할 때:

- **단계 순서를 지킨다.** 2 → 3 → … → 9. 앞 단계가 미완인 채로 뒤 단계를 시작하지 않는다.
- 단계 간 **경계를 넘지 않는다.** 해당 단계 스펙에 명시된 파일만 만들고 고친다. 다음 단계 것을 미리 만들지 않는다.
- 스펙이 모호하거나 설계 문서와 충돌하면 **임의로 정하지 말고 그 사실을 기록하고 사용자에게 질문한다.**
- 커밋은 단계 단위로 한다. 커밋 메시지: `[stage-N] 요약` (한국어).

## 7. 사용자와의 소통

- 응답 언어는 **한국어**.
- 각 단계 완료 후 결과물(변경 파일, 검증 결과, 스크린샷)을 요약하고 **다음 단계로 진행할지 확인받는다.**
- 추정이나 임의 결정을 했다면 반드시 그 사실을 드러낸다.
