# 2단계 — 내비게이션 셸

## 1. 목표

오늘·플래너·성적·설정 4개 탭 구조를 만든다. 각 탭은 빈 화면이어도 되며, **탭 전환과 기본 레이아웃**이 동작하는 것이 이 단계의 전부다.
동시에 이후 모든 단계가 재사용할 **공통 컴포넌트 뼈대**(빈 상태 뷰)를 만든다.

이 단계가 끝나면 앱을 열어 네 탭을 오갈 수 있고, 각 탭이 자기 이름과 빈 상태를 보여준다.

## 2. 선행 조건

- 1단계 완료 (SwiftData 모델 8종, `xcodegen`으로 빌드 성공)
- `Studion/Views/ContentView.swift`가 임시 플레이스홀더 상태 — **이 단계에서 교체한다**

## 3. 참조 문서

| 문서 | 섹션 |
|---|---|
| [04-ui-spec.md](../04-ui-spec.md) | §정보구조(IA), §공통 컴포넌트, §빈 상태 |
| [01-architecture.md](../01-architecture.md) | §폴더 구조, §iPad 이식 전략 |
| [05-localization-a11y.md](../05-localization-a11y.md) | §다국어 코드 규칙, §타이포그래피 |

## 4. 만들 파일

**신규**
```
Studion/Views/RootView.swift
Studion/Views/Components/EmptyStateView.swift
Studion/Views/Today/TodayView.swift
Studion/Views/Planner/PlannerView.swift
Studion/Views/Grades/GradesView.swift
Studion/Views/Settings/SettingsView.swift
```

**수정**
```
Studion/App/StudionApp.swift    # ContentView → RootView
```

**삭제**
```
Studion/Views/ContentView.swift  # RootView로 대체
```

여기 없는 파일을 건드리지 않는다.

## 5. 구현 명세

### 5-1. `RootView`

```swift
struct RootView: View {
    var body: some View {
        TabView {
            TodayView()   .tabItem { Label("오늘",   systemImage: "house") }
            PlannerView() .tabItem { Label("플래너", systemImage: "calendar") }
            GradesView()  .tabItem { Label("성적",   systemImage: "chart.bar") }
            SettingsView().tabItem { Label("설정",   systemImage: "gearshape") }
        }
    }
}
```

**요구사항**
- 탭은 **정확히 4개.** 늘리지 않는다.
- SF Symbols만 사용한다.
- 탭 콘텐츠를 `RootView` 안에 인라인으로 쓰지 않는다. **각 탭은 독립 View 파일**이어야 한다 — iPad에서 `NavigationSplitView`로 교체할 때 `RootView`만 고치면 되게 하기 위함이다.
- `RootView`는 탭 구성 외의 책임을 갖지 않는다. 테마 적용은 8단계에서 여기에 추가된다.

### 5-2. 각 탭 View

이 단계에서는 **껍데기**만 만든다.

```swift
struct TodayView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "checklist",
                title: "오늘 할 일이 없어요",
                message: "할 일을 추가하면 여기에 표시됩니다.",
                actionTitle: nil,
                action: nil
            )
            .navigationTitle("오늘")
        }
    }
}
```

**요구사항**
- 각 탭은 자체 `NavigationStack`을 갖는다 (탭별 독립 내비게이션 스택).
- `navigationTitle`을 설정한다: 오늘 / 플래너 / 성적 / 설정.
- 본문은 `EmptyStateView`로 채운다. 각 탭의 문구는 아래 표를 쓴다.
- **툴바 버튼·세그먼트 컨트롤을 이 단계에서 만들지 않는다.** 각각 3~5단계 소관이다.

| 탭 | systemImage | title | message |
|---|---|---|---|
| 오늘 | `checklist` | 오늘 할 일이 없어요 | 할 일을 추가하면 여기에 표시됩니다. |
| 플래너 | `calendar` | 등록된 시간표가 없어요 | 시간표를 등록하면 일정이 표시됩니다. |
| 성적 | `book.closed` | 아직 성적 기록이 없어요 | 이수 과목을 추가해 성적을 관리해 보세요. |
| 설정 | `gearshape` | 설정 | 앱 설정은 다음 단계에서 추가됩니다. |

> 설정 탭은 빈 상태가 어색하므로 단순 플레이스홀더로 두어도 된다. 8단계에서 `Form`으로 교체된다.

### 5-3. `EmptyStateView` — 이후 전 단계가 재사용

```swift
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}
```

**요구사항**
- 레이아웃: SF Symbol 아이콘 → 제목(`.headline`) → 설명(`.callout` + `.secondary`) → 액션 버튼(옵셔널)
- `actionTitle`과 `action`이 **둘 다 있을 때만** 버튼을 렌더한다.
- 아이콘 크기는 고정 포인트가 아니라 `.font(.largeTitle)` 등 **시맨틱 스타일**로 지정한다.
- 아이콘은 장식이므로 `.accessibilityHidden(true)`.
- 가로 여백은 컨테이너에 반응하게 둔다. **고정 width를 쓰지 않는다.**
- 텍스트는 `.multilineTextAlignment(.center)`, 줄 수를 제한하지 않는다 (Dynamic Type AX5 대응).

### 5-4. `StudionApp` 수정

`ContentView()` → `RootView()`. `modelContainer` 구성은 그대로 둔다.

## 6. 수용 기준

체크리스트. **항목별로 자기 점검한 결과를 보고한다.**

- [ ] 탭이 정확히 4개이고 순서가 오늘·플래너·성적·설정이다
- [ ] 네 탭 모두 전환되며 각각 올바른 `navigationTitle`을 보여준다
- [ ] 각 탭 콘텐츠가 독립 View 파일로 분리되어 있다 (`RootView`에 인라인 없음)
- [ ] `EmptyStateView`가 재사용 가능한 형태이고 액션 버튼이 옵셔널이다
- [ ] `ContentView.swift`가 삭제되고 참조가 남아 있지 않다
- [ ] SF Symbols만 사용했다
- [ ] 고정 폰트 크기·고정 width/height가 없다
- [ ] 모든 사용자 표시 문자열이 로컬라이징 가능한 리터럴이다
- [ ] 라이트/다크 모드 스크린샷을 모두 확인했다
- [ ] Dynamic Type 최대 크기(AX5)에서 레이아웃이 깨지지 않는다
- [ ] 원칙 체크 ([tasks/README.md](README.md#3-원칙-체크-매-단계-필수)) 통과

## 7. 검증 절차

```bash
cd /Users/sunghoon/Desktop/Studion
xcodegen generate
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|warning:|BUILD"
xcodebuild -project Studion.xcodeproj -scheme Studion \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -20
```

시뮬레이터 검증 (iOS Simulator MCP):
1. `attach`
2. `launch` — `.app` 경로는 `~/Library/Developer/Xcode/DerivedData/Studion-*/Build/Products/Debug-iphonesimulator/Studion.app`, bundle id `com.studion.app`
3. **네 탭을 각각 탭해 스크린샷** — 전환이 실제로 동작하는지 확인
4. 다크모드로 전환해 최소 1장 추가 확인

## 8. 범위 밖 (하지 않는다)

- 각 탭의 실제 콘텐츠 (3~9단계)
- 세그먼트 컨트롤 (성적·플래너 — 3·5단계)
- 툴바 `+` 버튼과 추가 시트 (3·5단계)
- 테마 전환·`.preferredColorScheme` (8단계)
- `NavigationSplitView` / iPad 레이아웃 (2차 플랫폼 단계)
- `EmptyStateView` 외의 공통 컴포넌트 (`GradeBadge`, `ProgressGauge` 등 — 필요한 단계에서 만든다)
- String Catalog 파일 생성 (8단계)

## 9. 막히면

- **탭 아이콘 선택이 애매할 때**: 위 표의 SF Symbol을 그대로 쓴다. 임의로 바꾸지 않는다.
- **설정 탭 빈 상태가 어색할 때**: 플레이스홀더로 두고 넘어간다. 8단계에서 교체된다.
- 스펙과 설계 문서가 충돌하면 **멈추고 사용자에게 묻는다.**
