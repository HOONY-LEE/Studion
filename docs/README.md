# Studion 설계 문서

이 디렉터리는 Studion의 **설계 단일 진실 소스(single source of truth)** 다.
코드와 문서가 어긋나면 문서를 먼저 고치고, 그다음 코드를 맞춘다. 문서 없이 설계를 즉흥으로 정하지 않는다.

## 읽는 순서

| 문서 | 내용 | 주로 필요한 단계 |
|---|---|---|
| [00-product-principles.md](00-product-principles.md) | 제품 원칙, 하지 않을 것, 의사결정 기준 | 전 단계 |
| [01-architecture.md](01-architecture.md) | 레이어 구조, 모듈 경계, iPad/Android 이식 전략 | 전 단계 |
| [02-data-model.md](02-data-model.md) | SwiftData 엔티티 전체 명세, CloudKit 제약 | 1·3·4·5·6·7 |
| [03-domain-logic.md](03-domain-logic.md) | 등급 계산·진척률·복습 스케줄 명세 + 테스트 벡터 | 3·4·6 |
| [04-ui-spec.md](04-ui-spec.md) | 화면별 IA·레이아웃·상호작용·빈 상태 | 2·3·4·5·6·8·9 |
| [05-localization-a11y.md](05-localization-a11y.md) | 다국어, Dynamic Type, 접근성, 색상 팔레트 | 2·8·9 |
| [06-sync-and-backup.md](06-sync-and-backup.md) | Sign in with Apple, CloudKit, JSON 백업 | 7·8 |
| [07-content-system-future.md](07-content-system-future.md) | 콘텐츠 시스템 (장기 로드맵, 1차 구현 안 함) | — |

## 단계별 실행 스펙

[tasks/README.md](tasks/README.md) — 배치 실행 프로토콜과 단계 목록.

각 `tasks/stage-N.md`는 **그 파일 하나만 읽고도 독립 실행 가능**하도록 작성되어 있다.
(필요한 설계 문서 섹션을 명시적으로 참조하고, 수용 기준과 검증 커맨드를 자체 포함한다.)

## 문서 수정 규칙

- 구현 중 설계를 바꿔야 한다고 판단되면, **코드를 먼저 고치지 말고** 해당 문서를 고친 뒤 사용자에게 변경 사실을 알린다.
- 데이터 모델 변경은 `02-data-model.md`와 실제 `@Model` 코드가 항상 1:1로 대응해야 한다.
- 도메인 로직 변경은 `03-domain-logic.md`의 테스트 벡터를 함께 갱신한다.
