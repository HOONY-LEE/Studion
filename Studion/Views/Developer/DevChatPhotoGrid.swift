#if DEBUG
import SwiftUI
import Supabase

/// 첨부 이미지 한 장. Storage에서 받아 캐시에 담고, 캐시에 있으면 첫 프레임부터 그린다
/// (목록을 스크롤할 때 사진이 깜빡이거나 행 높이가 뒤늦게 바뀌지 않게).
struct DevChatAttachmentImage: View {
    let path: String
    let client: SupabaseClient
    /// `.fit`은 원본 비율 그대로(단일 사진), `.fill`은 칸을 꽉 채운다(그리드 셀 — 바깥에서 clipped).
    var contentMode: ContentMode = .fit
    /// 로딩 중 자리를 잡아둘 가로세로비. 크기가 바깥에서 확정되는 그리드 셀은 nil.
    var reservedAspect: CGFloat?

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if failed {
                placeholder(systemImage: "exclamationmark.triangle")
            } else {
                placeholder(systemImage: nil)
            }
        }
        .task(id: path) { await load() }
    }

    @ViewBuilder
    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Rectangle().fill(Color(.tertiarySystemFill))
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .aspectRatio(reservedAspect, contentMode: .fit)
    }

    private func load() async {
        if let cached = DevChatStorage.shared.cached(path) {
            image = UIImage(data: cached)
            return
        }
        guard let data = await DevChatStorage.shared.data(for: path, client: client),
              let decoded = UIImage(data: data) else {
            failed = true
            return
        }
        image = decoded
    }
}

/// 연속으로 온 사진들을 하나의 앨범 블록으로 보여준다. 1장이면 원본 비율 그대로,
/// 2장은 반반, 3장은 큰 것 1장 + 작은 것 2장, 4장 이상은 `rowPlan`이 정한 유동 행 구성.
/// 어떤 사진을 탭해도 핀치줌 되는 전체화면 뷰어로 넘어간다.
struct DevChatPhotoGrid: View {
    let messages: [DevMessage]
    let client: SupabaseClient
    var maxWidth: CGFloat = 300

    @State private var viewerIndex = 0
    @State private var showViewer = false

    private static let spacing: CGFloat = 3

    private var paths: [String] { messages.compactMap(\.attachmentPath) }
    private var halfWidth: CGFloat { (maxWidth - Self.spacing) / 2 }

    /// 사진 개수를 행별 장수로 쪼갠다. 마지막 줄에 1장만 남지 않도록 나머지가 1이면
    /// 3장 행 하나를 헐어 2·2로 만든다.
    /// 4→[2,2] · 5→[3,2] · 6→[3,3] · 7→[3,2,2] · 8→[3,3,2] · 9→[3,3,3]
    static func rowPlan(for count: Int) -> [Int] {
        switch count % 3 {
        case 0:
            return Array(repeating: 3, count: count / 3)
        case 2:
            return Array(repeating: 3, count: (count - 2) / 3) + [2]
        default:
            return Array(repeating: 3, count: (count - 4) / 3) + [2, 2]
        }
    }

    var body: some View {
        Group {
            switch paths.count {
            case 0:
                EmptyView()
            case 1:
                cell(paths[0], index: 0, mode: .fit, reservedAspect: 4.0 / 3.0)
                    .frame(maxWidth: maxWidth, maxHeight: 360)
            case 2:
                HStack(spacing: Self.spacing) {
                    cell(paths[0], index: 0, mode: .fill).frame(width: halfWidth, height: 200).clipped()
                    cell(paths[1], index: 1, mode: .fill).frame(width: halfWidth, height: 200).clipped()
                }
            case 3:
                HStack(spacing: Self.spacing) {
                    cell(paths[0], index: 0, mode: .fill).frame(width: halfWidth, height: 200).clipped()
                    VStack(spacing: Self.spacing) {
                        cell(paths[1], index: 1, mode: .fill)
                            .frame(width: halfWidth, height: (200 - Self.spacing) / 2).clipped()
                        cell(paths[2], index: 2, mode: .fill)
                            .frame(width: halfWidth, height: (200 - Self.spacing) / 2).clipped()
                    }
                }
            default:
                // 행마다 장수가 달라 열 수가 고정이 아니므로 그리드 대신 HStack을 쌓는다.
                // 셀 크기는 그 행의 장수로부터 확정한다 — 크기를 정하지 않으면 이미지의
                // aspectRatio 때문에 옆 칸을 침범해 그려진다.
                VStack(spacing: Self.spacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        let side = (maxWidth - Self.spacing * CGFloat(row.count - 1)) / CGFloat(row.count)
                        HStack(spacing: Self.spacing) {
                            ForEach(row, id: \.self) { index in
                                cell(paths[index], index: index, mode: .fill)
                                    .frame(width: side, height: side)
                                    .clipped()
                            }
                        }
                    }
                }
                .frame(width: maxWidth)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5))
        .fullScreenCover(isPresented: $showViewer) {
            DevChatImageViewer(paths: paths, client: client, startIndex: viewerIndex)
        }
    }

    /// `rowPlan`을 실제 인덱스 묶음으로 펼친다 (5장 → [[0,1,2],[3,4]]).
    private var rows: [[Int]] {
        var result: [[Int]] = []
        var cursor = 0
        for size in Self.rowPlan(for: paths.count) {
            result.append(Array(cursor..<min(cursor + size, paths.count)))
            cursor += size
        }
        return result.filter { !$0.isEmpty }
    }

    @ViewBuilder
    private func cell(
        _ path: String, index: Int, mode: ContentMode, reservedAspect: CGFloat? = nil
    ) -> some View {
        DevChatAttachmentImage(
            path: path, client: client, contentMode: mode, reservedAspect: reservedAspect
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewerIndex = index
            showViewer = true
        }
    }
}

/// 전체화면 뷰어 — 앨범 안 사진을 좌우로 넘기고, 각 사진은 핀치·더블탭으로 확대한다.
struct DevChatImageViewer: View {
    let paths: [String]
    let client: SupabaseClient
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(paths: [String], client: SupabaseClient, startIndex: Int) {
        self.paths = paths
        self.client = client
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $currentIndex) {
                ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                    // 페이지를 넘기면 이전 사진의 확대 상태가 남아 있으면 안 된다.
                    DevChatZoomableImage(
                        path: path, client: client, isActive: index == currentIndex
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: paths.count > 1 ? .always : .never))
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding()
            .accessibilityLabel("닫기")
        }
    }
}

/// 핀치로 확대/축소, 확대된 상태에서 드래그로 이동, 더블탭으로 확대·원복.
private struct DevChatZoomableImage: View {
    let path: String
    let client: SupabaseClient
    var isActive: Bool = true

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var isZoomed: Bool { scale > 1 }

    var body: some View {
        DevChatAttachmentImage(path: path, client: client, contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = max(1, min(4, lastScale * value.magnification)) }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1 {
                            withAnimation { offset = .zero; lastOffset = .zero }
                        }
                    }
            )
            // 확대된 상태에서만 드래그 제스처를 **붙인다**. 항상 붙여두고 안에서 배율을 검사하면
            // 1배에서도 제스처가 인식돼 TabView의 페이지 스와이프를 먹어버려 사진이 안 넘어간다.
            .modifier(PanWhenZoomed(enabled: isZoomed, offset: $offset, lastOffset: $lastOffset))
            .onTapGesture(count: 2) {
                withAnimation {
                    if isZoomed { reset() } else { scale = 2.5; lastScale = 2.5 }
                }
            }
            // 다른 사진으로 넘어가면 확대를 풀어둔다 — 그대로 두면 돌아왔을 때 드래그 제스처가
            // 붙어 있어 그 페이지에서 스와이프가 다시 막힌다.
            .onChange(of: isActive) { _, active in
                if !active { reset() }
            }
    }

    private func reset() {
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
    }
}

private struct PanWhenZoomed: ViewModifier {
    let enabled: Bool
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastOffset = offset }
            )
        } else {
            content
        }
    }
}
#endif
