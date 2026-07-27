# Studion

한국 고등학생(입시 준비생)을 위한 **로컬 우선(local-first) 자기관리 앱**.
학교·학원 시간표, 일/주/월간 계획, 과목별 목표 대비 성적, 내신(5등급제)·모의고사(9등급제) 분리 관리, 온디바이스 OCR 오답노트.

**iOS 17+ · SwiftUI · SwiftData**

---

## 이 앱이 하지 않는 것

- 개인 데이터(성적·계획·오답노트)를 개발자가 접근 가능한 서버에 보내지 않는다
- 커뮤니티·랭킹·친구 같은 소셜 기능이 없다
- 광고·인앱결제가 없다
- 등급컷을 추정해 단정하지 않는다 (모의고사 등급은 사용자 입력이 원천)

동기화는 **Sign in with Apple + CloudKit Private Database**로 처리한다.
계정 인프라를 애플이 대신 운영하게 하는 방식이며, 개발자에게는 사용자 데이터를 열람할 서버도 권한도 없다.
**로그인하지 않아도 모든 핵심 기능이 100% 동작한다.**

자세한 원칙 → [docs/00-product-principles.md](docs/00-product-principles.md)

---

## 시작하기

### 요구사항

- Xcode 26 이상 (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

### 빌드

```bash
git clone <repo> && cd Studion
xcodegen generate
open Studion.xcodeproj
```

`.xcodeproj`는 **생성물**이다. 버전 관리 대상은 `project.yml`이며, `.xcodeproj`를 직접 편집하지 않는다.
파일을 추가·삭제한 뒤에는 항상 `xcodegen generate`를 다시 실행한다.

### 커맨드라인 빌드·테스트

```bash
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'generic/platform=iOS Simulator' build
```

```bash
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## 프로젝트 구조

```
project.yml            프로젝트 정의의 원천
Studion/
  App/                 엔트리 포인트, ModelContainer 구성
  Models/              SwiftData @Model + enum
  Views/               화면 (탭별 하위 폴더)
  Utilities/           순수 Swift 도메인 로직 — SwiftData·SwiftUI import 금지
  Resources/           Assets.xcassets, Localizable.xcstrings
StudionTests/          Swift Testing
docs/                  설계 문서 (단일 진실 소스)
docs/tasks/            단계별 실행 스펙
```

`Utilities/`가 순수해야 하는 이유는 두 가지다 — ModelContainer 없이 테스트가 돌아가야 하고, 추후 Android 포팅 시 이 폴더가 참조 명세가 된다.

---

## 문서

| 문서 | 내용 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | AI 에이전트 작업 규칙, 빌드 커맨드, 완료 정의 |
| [docs/README.md](docs/README.md) | 설계 문서 인덱스 |
| [docs/tasks/README.md](docs/tasks/README.md) | 단계별 실행 스펙, 배치 실행 프로토콜 |

핵심 설계:
[제품 원칙](docs/00-product-principles.md) ·
[아키텍처](docs/01-architecture.md) ·
[데이터 모델](docs/02-data-model.md) ·
[도메인 로직](docs/03-domain-logic.md) ·
[UI 명세](docs/04-ui-spec.md) ·
[다국어·접근성](docs/05-localization-a11y.md) ·
[동기화·백업](docs/06-sync-and-backup.md)

---

## 개발 로드맵

| 단계 | 내용 | 상태 |
|---|---|---|
| 1 | 프로젝트 스캐폴딩 + SwiftData 모델 | ✅ |
| 2 | 4탭 내비게이션 셸 | ✅ |
| 3 | 내신 (등급 계산 로직 + UI) | ✅ |
| 4 | 모의고사 + 목표 대비 진척 | ✅ |
| 5 | 플래너 (시간표 + 일/주/월간) | ⬜ |
| 6 | 오답노트 + OCR + 복습 | ⬜ |
| 7 | Sign in with Apple + CloudKit | ⬜ |
| 8 | 설정 (테마·다국어·백업) | ⬜ |
| 9 | 온보딩 + 빈 상태 + 마무리 | ⬜ |

1차 개발 완료 이후 후보: **iPad 최적화 → 콘텐츠 시스템 → Android**.

플랫폼 순서는 iPhone에 집중하되, 데이터 모델과 도메인 로직은 처음부터 이식을 염두에 두고 설계한다.

---

## 프라이버시

수집하는 데이터가 **없다.** 서드파티 SDK, 애널리틱스, 크래시 리포터를 사용하지 않는다.
CloudKit Private Database는 사용자 본인의 iCloud 저장소이며 개발자가 접근할 수 없다.

이 표기를 사실로 유지하는 것이 이 프로젝트의 핵심 제약이다.
