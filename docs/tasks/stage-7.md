# 7단계 — Sign in with Apple + CloudKit 동기화

## 1. 목표

설정 탭에 **선택 기능**으로 Apple 로그인 항목을 추가하고, SwiftData 모델을 CloudKit **Private Database**와 동기화한다.

이 단계가 끝나면 사용자는 기기를 바꿔도 성적·계획·오답노트를 그대로 이어받을 수 있다.
동시에, **로그인하지 않은 사용자는 아무것도 잃지 않는다** — 성적 입력·계획 관리·오답노트 생성·복습이 전부 로컬로 100% 동작한다.

> **이 단계의 성공 기준은 "동기화가 된다"가 아니라 "로그인하지 않아도 앱이 완전하다"이다.**
> 동기화를 붙이면서 미로그인 사용자의 경험을 한 줄이라도 열등하게 만들면 이 단계는 실패다 ([00 원칙 2](../00-product-principles.md#2-로컬-우선)).

## 2. 선행 조건

- 2~6단계 완료. **전 모델이 확정된 뒤에 착수한다** (스키마가 흔들리면 CloudKit 레코드 타입이 깨진다)
- `Studion/Views/Settings/SettingsView.swift`가 존재 (2단계) — 이 단계에서 **동기화 섹션을 추가**한다
- `StudionApp.swift`가 `cloudKitDatabase: .none`으로 로컬 전용 구성 중 — 이 단계에서 전환한다
- `project.yml`에 entitlements가 **의도적으로 없는** 상태 ([06 §3](../06-sync-and-backup.md#3-cloudkit-연동-설계))
- 유료 Apple Developer Program 멤버십 (iCloud 컨테이너 생성에 필요)

---

> ## ⚠️ 착수 전 사용자에게 반드시 물어볼 3가지
>
> 이 단계는 **혼자 결정할 수 없는 항목이 3개** 있다. "막히면"까지 가서 묻는 게 아니라, **첫 파일을 건드리기 전에** 세 개를 한 번에 묻고 답을 받은 뒤 시작한다. 임의로 정하고 진행하지 않는다.
>
> ### ① Apple Developer 팀 ID / iCloud 컨테이너 식별자
>
> entitlements에 실제 값이 필요하다. 확인할 것:
> - **Team ID** (10자리, Developer 포털 Membership)
> - **iCloud 컨테이너 식별자** — 문서의 예시는 `iCloud.com.studion.app`이지만, 실제로 개발자 계정에 생성된 컨테이너인지 확인받는다
> - 컨테이너가 아직 없다면 사용자가 Developer 포털에서 먼저 생성해야 한다
>
> **추측한 팀 ID로 entitlements를 채우지 않는다.** 빌드는 통과해도 서명·동기화가 실패한다.
>
> ### ② 동기화 on/off 처리 방식 (A / B / C)
>
> SwiftData는 **런타임에 CloudKit을 켜고 끄는 API가 없다.** `ModelContainer` 구성 시점에 결정된다.
> [06 §3-3](../06-sync-and-backup.md#3-cloudkit-연동-설계)의 표를 사용자에게 그대로 보여주고 고르게 한다.
>
> | 방안 | 장점 | 단점 |
> |---|---|---|
> | **A.** 토글 시 컨테이너 재생성 + 앱 재시작 안내 | 구현 단순 | 재시작 안내가 거칠다 |
> | **B.** 항상 CloudKit 컨테이너, 미로그인 시 iCloud 계정 없음으로 자연 동작 | 재시작 없음 | on/off가 사용자 통제 밖 |
> | **C.** 로컬/클라우드 두 컨테이너 + 전환 시 마이그레이션 | 완전한 통제 | 구현 복잡, **데이터 손실 위험** |
>
> 선택에 따라 §5-2와 §5-4의 구현이 달라진다. 답을 받기 전에 `StudionApp.swift`를 고치지 않는다.
>
> ### ③ 오답노트 이미지 동기화 방식 (A / B / C)
>
> 현재 이미지는 파일 시스템에 있고 `WrongAnswerNote.imageFileName`으로 참조한다. **파일 시스템은 CloudKit으로 동기화되지 않는다** — 기기를 바꾸면 텍스트만 오고 이미지가 사라진다.
> [06 §3 이미지 자산 처리](../06-sync-and-backup.md#이미지-자산-처리--미해결-과제)의 선택지를 그대로 제시한다.
>
> | 방안 | 내용 | 대가 |
> |---|---|---|
> | **A.** `@Attribute(.externalStorage) Data`로 이전 | CloudKit이 자산으로 동기화 | iCloud 용량 소모, **모델 변경 + 기존 파일 마이그레이션 필요** |
> | **B.** 이미지는 동기화하지 않고 그 사실을 UI에 명시 | 구현 단순 | 사용자 기대와 어긋날 수 있음 |
> | **C.** `CKAsset` 직접 관리 | 세밀한 통제 | SwiftData와 이원화, 복잡도 급증 |
>
> **A를 고르면 모델 변경이 발생하므로** `WrongAnswerNote`와 6단계 이미지 저장/로드 코드까지 손대야 한다. 그 범위를 사용자에게 미리 알리고 승인받는다.
>
> **세 답이 모두 확정되기 전에는 코드를 쓰지 않는다.** 답을 받으면 그 내용을 이 단계의 작업 로그(또는 커밋 메시지)에 남긴다.

---

## 3. 참조 문서

| 문서 | 섹션 | 중요도 |
|---|---|---|
| [06-sync-and-backup.md](../06-sync-and-backup.md) | **전체** — §1 핵심 입장, §2 로그인은 선택 기능, §3 CloudKit 연동 설계 | ★ 필수 |
| [02-data-model.md](../02-data-model.md) | [§CloudKit 호환 제약](../02-data-model.md#cloudkit-호환-제약-모든-엔티티가-지켜야-함), 전 엔티티 정의 | ★ 필수 |
| [04-ui-spec.md](../04-ui-spec.md) | [§4 설정 탭](../04-ui-spec.md#4-설정-settings-탭) — 특히 **로그인 UI 규칙 (엄격)** | ★ 필수 |
| [00-product-principles.md](../00-product-principles.md) | 원칙 1 (사용자 데이터 서버 없음), 원칙 2 (로컬 우선) | ★ 필수 |
| [01-architecture.md](../01-architecture.md) | §Utilities는 순수해야 한다, ModelContainer 구성 | |
| [05-localization-a11y.md](../05-localization-a11y.md) | §문자열 로컬라이징, §VoiceOver | |

## 4. 만들 파일

**신규**
```
Studion/App/Studion.entitlements                  # iCloud + CloudKit
Studion/App/SyncSettingsStore.swift               # 동기화/로그인 상태 (@AppStorage + Keychain)
Studion/Utilities/KeychainStore.swift             # 순수 Swift (Foundation + Security만)
Studion/Views/Settings/AppleSignInSection.swift   # 설정 탭 '동기화' 섹션
StudionTests/KeychainStoreTests.swift
```

**수정**
```
project.yml                              # entitlements, Background Modes(remote-notification)
Studion/App/StudionApp.swift             # ModelConfiguration을 .private(...)로 전환
Studion/Views/Settings/SettingsView.swift # 최상단에 '동기화' 섹션 삽입
```

**조건부 수정** — ③에서 **A**를 선택한 경우에만
```
Studion/Models/WrongAnswerNote.swift      # imageFileName → @Attribute(.externalStorage) Data?
Studion/Views/WrongNotes/**               # 6단계 이미지 저장/로드 경로 (해당 파일만)
```

> B 또는 C를 선택하면 모델과 6단계 파일을 **건드리지 않는다.** 위 목록에 없는 파일은 이 단계에서 만들거나 고치지 않는다.

## 5. 구현 명세

### 5-0. 스키마 사전 점검 (★ 가장 먼저, 코드 작성 전)

CloudKit 연결은 **스키마가 제약을 어기면 통째로 실패**한다. `Studion/Models/` 전 파일을 열어 아래를 한 항목씩 확인한다.

| 점검 항목 | 근거 |
|---|---|
| 모든 저장 속성에 **기본값이 있거나 옵셔널**인가 | [02 §제약](../02-data-model.md#cloudkit-호환-제약-모든-엔티티가-지켜야-함) |
| 모든 **관계가 옵셔널**인가 (`?` 또는 `[T]?` / 기본값 `[]`) | 〃 |
| 모든 관계에 **양방향 `inverse:`** 가 명시돼 있는가 | 〃 |
| `@Attribute(.unique)` 가 **한 곳도 없는가** | 〃 |
| enum이 **rawValue(String) 저장 + computed property** 형태인가 | 〃 |

**위반을 발견하면 CloudKit 전환보다 먼저 고친다.** 고친 내용은 보고에 명시한다.
점검 결과를 표로 남긴다 — "확인했다"가 아니라 **엔티티 8개 × 항목 5개**를 실제로 훑은 결과여야 한다.

대상 엔티티: `AcademicProfile`, `Semester`, `SchoolSubjectRecord`, `MockExamSession`, `MockExamSubjectRecord`, `WrongAnswerNote`, `TimetableEntry`, `PlanItem`.

### 5-1. `project.yml` + entitlements

`Studion/App/Studion.entitlements` (①에서 받은 실제 컨테이너 식별자를 넣는다):

- `com.apple.developer.icloud-container-identifiers` → `[iCloud.<컨테이너>]`
- `com.apple.developer.icloud-services` → `[CloudKit]`
- `com.apple.developer.ubiquity-kvstore-identifier` 는 **넣지 않는다** (쓰지 않음)

`project.yml`의 `Studion` 타깃에:

- `settings.base.CODE_SIGN_ENTITLEMENTS: Studion/App/Studion.entitlements`
- `settings.base.DEVELOPMENT_TEAM: <팀 ID>` — ①에서 받은 값
- `info.properties.UIBackgroundModes: [remote-notification]`

> `.xcodeproj`를 손으로 고치지 않는다. `project.yml` 수정 후 반드시 `xcodegen generate`.
> entitlements 파일에 팀 ID·컨테이너를 넣기 전에 ①의 답을 받았는지 다시 확인한다.

### 5-2. `StudionApp.swift` — ModelConfiguration 전환

```swift
ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.studion.app"))
```

- 컨테이너 식별자는 **①에서 받은 실제 값**을 쓴다. 문자열은 한 곳(상수)에만 둔다.
- ②의 선택에 따라 분기:
  - **A** → 동기화 설정값을 읽어 `.private(...)` / `.none`을 고르고, 토글 변경 시 재시작 안내
  - **B** → 항상 `.private(...)`. iCloud 계정이 없으면 로컬로 동작 (분기 없음)
  - **C** → 로컬/클라우드 두 구성 + 전환 마이그레이션. **데이터 손실 위험을 사용자에게 다시 확인**
- **`fatalError`를 남기지 않는다.** 현재 코드의 `fatalError("ModelContainer 생성 실패")`는 iCloud 계정이 없는 시뮬레이터/기기에서 크래시 원인이 된다. CloudKit 구성 실패 시 **로컬 전용 구성으로 폴백**하고, 실패 사실만 설정 화면 상태로 노출한다.
- 앱은 **iCloud 계정이 없어도, 네트워크가 없어도 정상 실행**되어야 한다.

### 5-3. `KeychainStore.swift` — 순수 Swift

- `import Foundation` + `import Security`만. **SwiftData·SwiftUI·AuthenticationServices를 import하지 않는다** ([CLAUDE.md §2](../../CLAUDE.md)).
- API는 최소로: `save(_:for:)` / `read(for:)` / `delete(for:)`. 값은 `String`.
- 저장하는 것은 **`userIdentifier` 하나뿐**이다.
- **이메일·이름을 저장하지 않는다.** Sign in with Apple이 첫 로그인 시 이름/이메일을 주더라도 **받아서 버린다** ([06 §3-4](../06-sync-and-backup.md#3-cloudkit-연동-설계)). 필요 없다.
- 접근성 속성은 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- 실패 시 `throw` 또는 `nil`. 크래시하지 않는다.

### 5-4. `SyncSettingsStore.swift` + `AppleSignInSection.swift`

#### 인증

- `AuthenticationServices`의 **`SignInWithAppleButton`** 을 쓴다. 커스텀 버튼을 그리지 않는다 (HIG 요구사항).
- `requestedScopes`는 **비워두거나 최소로**. 이름·이메일을 요구하지 않는다.
- 성공 시 `ASAuthorizationAppleIDCredential.user`(= `userIdentifier`)만 Keychain에 저장.
- 앱 시작 시 `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)`로 유효성 확인:
  - `.authorized` → 유지
  - `.revoked` / `.notFound` → Keychain 값을 지우고 로그아웃 상태로. **얼럿을 띄우지 않는다.** 설정 화면에 상태만 반영한다
- **로컬 데이터를 지우지 않는다.** 로그아웃·자격 실효는 동기화만 끊는다. 이건 절대 규칙이다.

#### UI (★ 규칙이 엄격하다 — [04 §4 로그인 UI 규칙](../04-ui-spec.md#4-설정-settings-탭))

- 위치: **`SettingsView`의 `Form` 안 '동기화' 섹션. 오직 여기에만 존재한다.**
- 첫 진입·온보딩·모달·`.sheet`로 **띄우지 않는다.** 다른 화면에서 이 섹션으로 유도하지 않는다.
- **잠금 아이콘 금지. 업셀 배너 금지. "로그인하면 더 좋아요" 류 유도 문구 금지.** 뱃지·점(dot)·느낌표로 주의를 끌지 않는다.
- 문구는 **목적을 말한다**:

  | ❌ 쓰지 않는다 | ✅ 쓴다 |
  |---|---|
  | "로그인하세요" | "기기를 바꿔도 데이터를 유지하려면 켜세요" |
  | "로그인하고 모든 기능 사용하기" | "동기화는 선택입니다. 켜지 않아도 모든 기능이 그대로 동작합니다." |
  | "계정을 만들어 데이터를 보호하세요" | "데이터는 내 iCloud에만 저장됩니다. 개발자는 볼 수 없습니다." |

- 섹션 구성(권장):
  - 로그인 전: 목적 설명 1~2줄 + `SignInWithAppleButton`
  - 로그인 후: 상태 행(마지막 동기화 시각 또는 "동기화 중"), 로그아웃 버튼
  - ③에서 **B**를 선택했다면 "이미지는 동기화되지 않습니다" 각주를 이 섹션에 명시
  - iCloud 계정이 없거나 CloudKit 구성이 실패했다면 **중립적인 안내 한 줄**. 경고 색·빨간색을 쓰지 않는다
- 문자열은 전부 로컬라이징 가능한 형태. 고정 폰트 크기·고정 width/height 금지.
- 로그아웃 버튼은 destructive 스타일을 쓰지 않는다 (데이터를 지우지 않으므로).

### 5-5. 충돌 해결

- SwiftData + CloudKit 기본 동작인 **last-writer-wins를 그대로 수용**한다 ([06 §충돌 해결](../06-sync-and-backup.md#충돌-해결)).
- **커스텀 병합 로직을 만들지 않는다.** 버전 벡터·수동 충돌 UI·"어느 쪽을 쓸까요?" 다이얼로그 전부 범위 밖이다.

### 5-6. 하지 않는 것 (원칙 위반 방지)

- 자체 REST 백엔드·`URLSession` 추가 금지. 유일한 네트워크는 CloudKit이다 ([00 원칙 1](../00-product-principles.md#1-사용자-데이터-서버-없음)).
- 소셜 로그인(카카오/구글/이메일 가입) 추가 금지.
- 애널리틱스·크래시 리포터·서드파티 SDK 추가 금지. 추가하는 순간 App Store 프라이버시 표기가 거짓이 된다 ([06 §5](../06-sync-and-backup.md#5-프라이버시-표기-배포-시)).
- 로그인 여부로 기능을 잠그는 코드를 **한 줄도** 쓰지 않는다.

## 6. 수용 기준

- [ ] 착수 전 **3가지 결정(팀 ID·컨테이너 / 동기화 on-off 방식 / 이미지 방식)** 을 사용자에게 묻고 답을 받았으며, 그 내용이 기록돼 있다
- [ ] 엔티티 8개 전부에 대해 CloudKit 제약 5항목을 점검한 결과가 표로 보고됐다
- [ ] `@Attribute(.unique)`가 프로젝트 전체에 존재하지 않는다
- [ ] 모든 관계가 옵셔널 + 양방향 `inverse:` 다
- [ ] 모든 enum이 rawValue(String)로 저장된다
- [ ] `project.yml`에 `com.apple.developer.icloud-container-identifiers`, `com.apple.developer.icloud-services: [CloudKit]`, Background Modes(remote-notification)가 반영됐고 `xcodegen generate` 후 빌드된다
- [ ] `ModelConfiguration(schema:cloudKitDatabase: .private(...))`로 전환됐다
- [ ] **iCloud 계정이 없는 시뮬레이터에서 앱이 크래시하지 않고 정상 실행된다** (`fatalError` 경로 제거 또는 폴백)
- [ ] `KeychainStore.swift`가 `Foundation`/`Security`만 import한다 (SwiftData·SwiftUI 없음)
- [ ] Keychain에 **`userIdentifier`만** 저장되고 **이메일·이름이 저장되지 않는다**
- [ ] 앱 시작 시 `getCredentialState`로 유효성을 확인하고, `.revoked`/`.notFound`면 조용히 로그아웃 상태가 된다
- [ ] 로그아웃·자격 실효 시 **로컬 데이터가 삭제되지 않는다**
- [ ] 로그인 UI가 **설정 탭 안에만** 있고, 첫 진입·온보딩·모달로 뜨지 않는다
- [ ] 잠금 아이콘·업셀 배너·"로그인하면 더 좋아요" 유도가 **하나도 없다**
- [ ] 로그인 문구가 목적을 말한다 ("로그인하세요"가 아니라 "기기를 바꿔도 데이터를 유지하려면 켜세요")
- [ ] **로그인하지 않은 상태에서 성적 입력·계획 관리·오답노트 생성·복습이 전부 동작한다** (스크린샷으로 증명)
- [ ] 로그인 여부로 잠기는 기능이 0개다
- [ ] 커스텀 충돌 병합 로직을 만들지 않았다 (last-writer-wins 수용)
- [ ] `URLSession`·자체 백엔드·소셜 로그인·애널리틱스를 추가하지 않았다
- [ ] 이미지 동기화 방식이 ③의 선택대로 구현됐고, **B를 골랐다면 그 사실이 UI에 명시**돼 있다
- [ ] 라이트/다크 스크린샷 확인, Dynamic Type AX5에서 설정 화면 레이아웃 유지
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

추가 확인:

```bash
# 금지 패턴이 남아있지 않은지
grep -rn "@Attribute(.unique)" Studion/
grep -rn "URLSession" Studion/
```

### 시뮬레이터 시나리오 검증 (스크린샷 필수)

**① 미로그인 전 기능 동작 — 이 단계의 핵심 검증이다**

시뮬레이터를 **iCloud에 로그인하지 않은 상태**로 두고 (Settings 앱에서 로그인하지 않는다):

1. 앱 실행 → **크래시하지 않는지**
2. 학기 추가 → 과목 추가 → 성적 입력 → 등급 배지 확인
3. 계획 추가 → 완료 체크 → 날짜 이동
4. 오답노트 생성 → 복습 큐 동작
5. 설정 탭 진입 → 동기화 섹션이 **거기에만** 있는지, 잠금/업셀이 없는지
6. 다른 탭·화면에 로그인 유도가 **하나도 없는지** 훑어 확인
7. 다크모드 확인

**2~4번이 전부 동작해야 한다. 하나라도 로그인을 요구하면 이 단계는 실패다.**

**② 로그인 흐름**

8. 설정 탭에서 Sign in with Apple 버튼 탭 → 시스템 시트가 뜨는지
9. 앱 재시작 후 `getCredentialState`가 상태를 올바르게 복원하는지
10. 로그아웃 → **로컬 데이터가 남아 있는지 확인** (성적·계획·오답노트)

**③ 한계 — 반드시 보고에 명시한다**

- **실제 CloudKit 동기화는 시뮬레이터만으로 검증할 수 없다.** 기기 간 데이터 이전을 확인하려면 **같은 iCloud 계정으로 로그인한 실기기 2대**(또는 실기기 1대 + iCloud 로그인된 시뮬레이터)와 유효한 개발자 계정·프로비저닝이 필요하다.
- CloudKit Dashboard에서 레코드 타입이 생성됐는지 확인하는 것도 개발자 계정이 있어야 가능하다.
- 이 환경이 없으면 **"동기화 검증 미완"으로 정확히 보고한다.** 빌드가 통과했다는 이유로 "동기화 동작 확인"이라고 쓰지 않는다.
- 검증 가능한 범위: 스키마 제약 준수, entitlements 반영, 미로그인 전 기능 동작, iCloud 계정 없는 환경에서의 무크래시 실행, 로그인 UI 규칙 준수.

## 8. 범위 밖 (하지 않는다)

- **JSON 백업 / 복원** (8단계) — [06 §4](../06-sync-and-backup.md#4-json-백업--복원-8단계)는 이 단계와 독립적인 8단계 소관이다
- **테마(라이트/다크/시스템)·다국어 전환** (8단계) — 설정 탭의 다른 섹션을 이 단계에서 채우지 않는다
- 학사 정보·이수 과목 관리·알림 설정 섹션 (8·9단계)
- **온보딩** (9단계) — 온보딩에 로그인을 넣지 않는 것이 이 단계의 규칙이기도 하다
- **Android 동기화 체계** (3차 플랫폼) — CloudKit은 애플 플랫폼 전용이다. 크로스 플랫폼 대안을 설계하지 않는다
- 커스텀 충돌 병합 UI, 동기화 진행률 상세 화면, 수동 "지금 동기화" 강제 트리거
- 공유 데이터베이스(`.shared`)·가족 공유 — 이 앱에는 다른 사람이 등장하지 않는다 ([00 원칙 3](../00-product-principles.md#3-커뮤니티소셜-기능-없음))

## 9. 막히면

- **팀 ID·컨테이너를 모를 때**: 추측하지 않는다. §2의 ①로 돌아가 사용자에게 묻는다. 플레이스홀더로 빌드만 통과시키고 넘어가지 않는다.
- **동기화 on/off를 코드로 못 하겠을 때**: 맞다, SwiftData에 그 API가 없다. ②의 A/B/C 중 사용자가 고른 것을 따른다. 리플렉션이나 사설 API로 우회하지 않는다.
- **이미지가 동기화되지 않는 걸 발견했을 때**: 알려진 문제다. ③의 선택을 따른다. 임의로 `CKAsset` 코드를 쓰지 않는다.
- **iCloud 계정이 없어 앱이 크래시할 때**: `fatalError`가 원인이다. 로컬 전용 구성으로 폴백한다 (§5-2). 사용자에게 iCloud 로그인을 요구하지 않는다.
- **"로그인하면 동기화된다는 걸 사용자가 모를 것 같을 때"**: 그래도 배너·팝업·뱃지를 만들지 않는다. 설정 탭의 문구 한 줄이 전부다. 이건 설계 원칙이다 ([06 §2](../06-sync-and-backup.md#2-로그인은-선택-기능이다-엄격)).
- **동기화 상태를 정확히 알고 싶을 때**: SwiftData는 상세한 동기화 상태 API를 공개하지 않는다. 없는 상태를 그럴듯하게 지어내 표시하지 않는다. 표시할 수 없으면 표시하지 않는다.
- **스키마 제약 위반을 발견했는데 고치면 기존 데이터가 깨질 것 같을 때**: **멈추고 사용자에게 묻는다.** 마이그레이션 전략은 임의로 정하지 않는다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**
