# 06. 동기화 · 백업

7단계(Sign in with Apple + CloudKit)와 8단계(JSON 백업)의 설계 근거.

---

## 1. 핵심 입장

> **"계정이 없다"가 아니라 "계정 인프라를 애플이 대신 운영하게 한다."**

개발자는 사용자 비밀번호나 개인정보 DB를 직접 다루지 않는다. 데이터는 사용자 본인의 iCloud 계정 아래 저장되고, 개발자에게는 그것을 열람할 서버도 권한도 없다.

| 하지 않는 것 | 하는 것 |
|---|---|
| 자체 REST 백엔드 | CloudKit Private Database |
| 이메일/비밀번호 회원가입 | Sign in with Apple |
| 소셜 로그인 (카카오/구글) | — |
| 사용자 DB 보유 | 애플이 제공하는 식별자만 사용 |
| 애널리틱스·크래시 리포터 | 없음 |

---

## 2. 로그인은 선택 기능이다 (엄격)

**앱의 모든 핵심 기능은 로그인 없이 100% 동작해야 한다.** 이것은 편의가 아니라 요구사항이다.

### 검증 기준 (7단계 완료 조건)

1. 로그인하지 않은 상태에서 성적 입력·계획 관리·오답노트 생성·복습이 **전부** 동작한다.
2. 로그인 화면이 앱 첫 진입·온보딩·모달로 **뜨지 않는다.** 설정 탭 안에만 존재한다.
3. 잠금 아이콘, 업셀 배너, "로그인하면 더 좋아요" 유도가 **없다.**
4. 로그인 문구가 목적을 말한다 — "로그인하세요" ❌ / "기기를 바꿔도 데이터를 유지하려면 켜세요" ✅

### 로그인의 유일한 목적

**기기 변경 시 데이터 이전.** 그 외의 기능을 로그인 뒤에 두지 않는다.

---

## 3. CloudKit 연동 설계

### 스키마 제약 — 1단계부터 이미 지키고 있음

CloudKit과 연결하려면 SwiftData 스키마가 아래를 만족해야 한다. 상세 → [02](02-data-model.md#cloudkit-호환-제약-모든-엔티티가-지켜야-함).

- 모든 저장 속성에 기본값 또는 옵셔널
- 모든 관계는 옵셔널 + 양방향(`inverse:`)
- `@Attribute(.unique)` 사용 금지
- enum은 rawValue(String) 저장

**모델을 새로 추가하거나 고칠 때 이 제약을 깨면 7단계에서 동기화가 통째로 실패한다.** 각 단계에서 모델을 건드릴 때마다 확인한다.

### 현재 상태 (1단계 완료 시점)

```swift
// StudionApp.swift — 지금은 로컬 전용
let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
```

`project.yml`에 entitlements를 **의도적으로 넣지 않았다.** 실제 개발자 팀 ID와 iCloud 컨테이너가 필요하므로 7단계에서 추가한다.

### 7단계에서 할 일

1. **Xcode 프로젝트 설정**
   - `project.yml`에 entitlements 추가: `com.apple.developer.icloud-container-identifiers`, `com.apple.developer.icloud-services: [CloudKit]`
   - Signing & Capabilities에 iCloud + Background Modes(Remote notifications)
   - ⚠️ **실제 Apple Developer 팀 ID가 필요하다.** 사용자에게 확인받고 진행한다.

2. **ModelConfiguration 전환**
   ```swift
   ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.studion.app"))
   ```

3. **동기화 on/off 처리 방식 — 결정됨: 항상 CloudKit 컨테이너**

   SwiftData는 런타임에 CloudKit을 켜고 끄는 API를 제공하지 않는다. 컨테이너 구성 시점에 결정된다.

   **채택: 컨테이너를 항상 `.private`로 구성한다.** iCloud 계정이 없거나 로그인하지 않은 기기에서는 CloudKit 동기화가 자연스럽게 비활성 상태가 되고 로컬 저장소로만 동작한다.

   | 결과 | 내용 |
   |---|---|
   | 앱 재시작 | 필요 없음 |
   | 미로그인 동작 | 로컬 전용으로 완전히 동작 (원칙 2 유지) |
   | 트레이드오프 | 사용자가 동기화를 명시적으로 "끌" 수는 없다 — iCloud 계정 유무가 곧 동기화 여부다 |

   설정 화면의 "Apple로 로그인"은 **동기화 스위치가 아니라 사용자 식별·상태 표시**다.
   토글로 오해할 문구("동기화 켜기/끄기")를 쓰지 않고, 현재 iCloud 상태를 그대로 알려준다.

4. **Sign in with Apple**
   - `AuthenticationServices`의 `SignInWithAppleButton` 사용
   - 받은 `userIdentifier`는 Keychain에 저장. **이메일·이름을 저장하지 않는다** (필요 없다)
   - `ASAuthorizationAppleIDProvider.getCredentialState`로 앱 시작 시 유효성 확인

### 이미지 자산 처리 — 결정됨: SwiftData 외부 저장

**채택: 오답노트 이미지를 `@Attribute(.externalStorage) var imageData: Data?`로 저장한다.**

SwiftData가 큰 바이너리를 파일로 분리해 관리하고, CloudKit이 이를 자산으로 동기화한다. 기기를 바꿔도 이미지가 함께 따라온다.

| 항목 | 내용 |
|---|---|
| 저장 위치 | SwiftData 외부 저장소 (앱이 경로를 직접 다루지 않음) |
| 동기화 | CloudKit 자산으로 자동 |
| 대가 | 사용자 iCloud 용량을 소모한다 |

**6단계 구현 규칙**
- 이미지는 처음부터 `imageData`로 저장한다. 파일 시스템에 직접 쓰지 않는다.
- 저장 전 **긴 변을 기준으로 리사이즈하고 JPEG로 압축**해 용량을 억제한다 (원본 해상도를 그대로 넣지 않는다).
- `UIImage` ↔ `Data` 변환은 View 계층의 책임이다. `Utilities/`는 `Data`만 다룬다.

> 이 결정으로 `WrongAnswerNote.imageFileName`(파일명 참조)은 **쓰지 않는다.** → [02](02-data-model.md#wronganswernote)

### 충돌 해결

SwiftData + CloudKit은 기본적으로 **마지막 쓰기 우선(last-writer-wins)** 이다. 1차 범위에서는 이를 그대로 수용한다. 커스텀 병합 로직을 만들지 않는다.

이 앱은 한 사용자가 여러 기기에서 동시에 같은 레코드를 고칠 가능성이 낮다.

---

## 4. JSON 백업 / 복원 (8단계)

CloudKit과 **독립적인** 수단이다. 로그인하지 않는 사용자도 기기 변경에 대응할 수 있어야 한다.

### 요구사항

- 내보내기: 전체 개인 데이터를 **단일 JSON 파일**로. Files 앱 연동(`.fileExporter`)
- 가져오기: JSON 파일 선택 → 검증 → 복원 (`.fileImporter`)
- 앱 버전이 올라가도 **과거 백업 파일을 읽을 수 있어야 한다** → 최상위에 `schemaVersion` 필드 필수

### 포맷 스케치

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

- SwiftData `@Model`을 직접 `Codable`로 만들지 않는다. **별도의 순수 DTO 구조체**를 정의해 변환한다 (모델 변경이 백업 포맷을 깨지 않게).
- DTO는 `Utilities/`가 아니라 백업 전용 파일에 둔다 (도메인 로직이 아니므로).
- 이미지는 1차 백업 범위에서 **제외**한다. 그 사실을 UI에 명시한다.

### 복원 정책 — 사용자에게 선택시킨다

| 방식 | 동작 |
|---|---|
| 덮어쓰기 | 기존 데이터를 지우고 백업으로 교체 |
| 병합 | 기존 데이터를 두고 백업 내용을 추가 |

**파괴적 동작이므로 반드시 확인 다이얼로그를 거친다.** 덮어쓰기 확인은 destructive 스타일(시스템 red)을 쓰는 유일한 지점 중 하나다.

복원 실패 시 **부분 적용된 상태로 남지 않게** 한다. 검증을 먼저 전부 수행하고, 통과한 뒤에 쓰기를 시작한다.

---

## 5. 프라이버시 표기 (배포 시)

App Store Privacy Nutrition Label에 신고할 내용:

- **수집하는 데이터: 없음.** 개발자가 접근하는 데이터가 없다.
- CloudKit Private Database는 사용자 본인 iCloud 저장소이며 개발자 접근 불가.
- 서드파티 SDK 없음 → 추적 없음.

이 표기를 사실로 유지하는 것이 원칙 1의 실질적 의미다. **애널리틱스나 크래시 리포터를 추가하는 순간 이 표기가 거짓이 된다.**
