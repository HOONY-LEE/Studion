import Foundation

/// 시간표 칸 색을 과목에 나눠준다.
///
/// 색을 이름 해시로 정하지 않는다 — 해시는 과목이 10개만 돼도 서로 같은 색을 받기 쉬운데,
/// "과목별로 색이 다르다"는 것이 이 기능의 전부다. 대신 **지금 쓰이고 있는 색을 보고
/// 가장 덜 쓰인 색을 준다.** 사진으로 한 번에 넣을 때 색이 골고루 퍼진다.
///
/// 같은 과목은 언제나 같은 색이어야 한다 — 월요일 국어와 수요일 국어가 다른 색이면
/// 색으로 과목을 알아보는 의미가 없다.
enum TimetableColorAssigner {

    /// 고를 수 있는 색의 수. `TimetableColorPalette`와 같아야 한다.
    static let paletteCount = 10

    /// 과목 이름을 색 짝짓기의 열쇠로 바꾼다.
    ///
    /// "확률과 통계"와 "확률과통계"는 같은 과목이다 — 사진에서 읽은 이름과 손으로 적은
    /// 이름이 띄어쓰기만 다른 경우가 흔하다.
    static func key(for title: String) -> String {
        title.trimmed
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    /// 새 과목들에 색을 나눠준다.
    ///
    /// - Parameters:
    ///   - titles: 색을 정할 과목 이름들. 순서대로 처리하므로 결과가 매번 같다.
    ///   - existing: 이미 색이 정해진 과목들 (`key(for:)`로 만든 열쇠 → 색 번호).
    /// - Returns: `titles`에 나온 모든 과목의 열쇠 → 색 번호. 이미 있던 과목은 그 색 그대로.
    static func assign(titles: [String], existing: [String: Int] = [:]) -> [String: Int] {
        var assigned = existing
        var usage = [Int](repeating: 0, count: paletteCount)
        for index in existing.values where usage.indices.contains(index) {
            usage[index] += 1
        }

        for title in titles {
            let key = key(for: title)
            guard !key.isEmpty, assigned[key] == nil else { continue }

            // 가장 덜 쓰인 색. 같으면 앞 번호를 써서 결과가 매번 같게 한다.
            let next = usage.indices.min { left, right in
                usage[left] != usage[right] ? usage[left] < usage[right] : left < right
            } ?? 0

            assigned[key] = next
            usage[next] += 1
        }
        return assigned
    }

    /// 이미 있는 수업들에서 "과목 → 색" 짝을 모은다.
    ///
    /// 같은 과목에 색이 여러 개 붙어 있으면(옛 데이터 등) **가장 작은 번호**로 통일한다 —
    /// 무엇을 고르든 상관없지만 매번 같은 답이 나와야 화면이 깜빡이지 않는다.
    static func existingAssignments(from pairs: [(title: String, colorIndex: Int)]) -> [String: Int] {
        var result: [String: Int] = [:]
        for pair in pairs {
            let key = key(for: pair.title)
            guard !key.isEmpty, (0..<paletteCount).contains(pair.colorIndex) else { continue }
            if let current = result[key] {
                result[key] = min(current, pair.colorIndex)
            } else {
                result[key] = pair.colorIndex
            }
        }
        return result
    }
}
