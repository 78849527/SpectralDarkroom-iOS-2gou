import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@main
struct SpectralDarkroomApp: App {
    var body: some Scene {
        WindowGroup {
            EditorView()
        }
    }
}

private struct RenderedFrame: Sendable {
    let pixels: Data
    let width: Int
    let height: Int

    func image() throws -> CGImage {
        guard let provider = CGDataProvider(data: pixels as CFData),
              let p3 = CGColorSpace(name: CGColorSpace.displayP3),
              let image = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: p3,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true,
                intent: .defaultIntent
              )
        else { throw RenderError.message("无法显示渲染结果") }
        return image
    }
}

private enum RenderError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case let .message(text) = self { return text }
        return nil
    }
}

// All engine calls stay on this actor. C's thread-local error string must be
// copied before another operation; the rgba16 result is copied before release.
private actor FilmEngine {
    private var engine: OpaquePointer?
    private var session: OpaquePointer?
    private var frameURL: URL?
    private var pixels: [Float] = []
    private var width = 0
    private var height = 0

    func render(url: URL, film: String, paper: String,
                exposure: Double, printExposure: Double,
                grain: Double, tier: String) throws -> RenderedFrame {
        if engine == nil {
            guard let resources = Bundle.main.resourceURL?.appendingPathComponent("engine"),
                  let created = spk_engine_create(resources.path, nil) else {
                throw RenderError.message("胶片引擎启动失败：\(String(cString: spk_last_error(nil)))")
            }
            engine = created
        }
        if frameURL != url {
            try decode(url)
            frameURL = url
        }
        if let session { spk_session_release(session) }
        session = nil

        let settings: [String: Any] = [
            "film_stock": film,
            "print_stock": paper,
            "input_color_space": "sRGB",
            "input_cctf_decoding": false,
            "output_color_space": "Display P3",
            "preview_long_edge": 1600,
            "exposure_compensation_ev": exposure,
            "print_exposure": printExposure,
            "grain_amount": grain,
        ]
        let json = try JSONSerialization.data(withJSONObject: settings)
        guard let delta = String(data: json, encoding: .utf8) else {
            throw RenderError.message("无法编码胶片设置")
        }
        var reply: UnsafeMutablePointer<CChar>?
        let opened = pixels.withUnsafeBufferPointer { buffer -> OpaquePointer? in
            var input = spk_image(data: buffer.baseAddress,
                                  width: UInt32(width), height: UInt32(height),
                                  channels: 4)
            return spk_open(engine, &input, delta, &reply)
        }
        if let reply { spk_string_free(reply) }
        guard let opened else { throw failure("无法打开照片") }
        session = opened
        var result = spk_result()
        guard spk_reprint(opened, tier, &result) == SPK_OK else {
            throw failure("冲印失败")
        }
        defer { spk_result_free(&result) }
        guard let source = result.rgba16, result.width > 0, result.height > 0 else {
            throw RenderError.message("引擎没有返回像素")
        }
        let w = Int(result.width)
        let h = Int(result.height)
        let stride = Int(result.row_stride_px)
        var bytes = Data(count: w * h * 4)
        bytes.withUnsafeMutableBytes { raw in
            guard let destination = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<h {
                for x in 0..<w {
                    let input = (y * stride + x) * 4
                    let output = (y * w + x) * 4
                    destination[output] = UInt8(truncatingIfNeeded: source[input] >> 8)
                    destination[output + 1] = UInt8(truncatingIfNeeded: source[input + 1] >> 8)
                    destination[output + 2] = UInt8(truncatingIfNeeded: source[input + 2] >> 8)
                    destination[output + 3] = 255
                }
            }
        }
        return RenderedFrame(pixels: bytes, width: w, height: h)
    }

    private func failure(_ prefix: String) -> RenderError {
        .message("\(prefix)：\(String(cString: spk_last_error(engine)))")
    }

    private func decode(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard var image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
            throw RenderError.message("无法解码照片；请尝试 JPEG、HEIC 或受系统支持的 RAW")
        }
        let longEdge = max(image.extent.width, image.extent.height)
        if longEdge > 4096 {
            image = image.transformed(by: CGAffineTransform(scaleX: 4096 / longEdge,
                                                             y: 4096 / longEdge))
        }
        let bounds = image.extent.integral
        let w = Int(bounds.width)
        let h = Int(bounds.height)
        guard w > 0, h > 0, let linear = CGColorSpace(name: CGColorSpace.linearSRGB) else {
            throw RenderError.message("照片尺寸或色彩空间无效")
        }
        var decoded = [Float](repeating: 0, count: w * h * 4)
        let context = CIContext(options: [.workingColorSpace: linear, .outputColorSpace: linear])
        context.render(image, toBitmap: &decoded, rowBytes: w * 4 * MemoryLayout<Float>.size,
                       bounds: bounds, format: .RGBAf, colorSpace: linear)
        pixels = decoded
        width = w
        height = h
    }
}

private struct Stock: Identifiable {
    let id: String
    let label: String
    let originalName: String
}

private enum DarkroomStyle {
    static let background = Color(red: 0.055, green: 0.060, blue: 0.064)
    static let panel = Color(red: 0.105, green: 0.110, blue: 0.114)
    static let accent = Color(red: 0.91, green: 0.72, blue: 0.47)
    static let muted = Color(red: 0.62, green: 0.63, blue: 0.62)
}

// Use SwiftUI APIs available since iOS 16. The newer glass styles are
// deliberately excluded from this compatibility branch so Xcode 16 can build it.
private struct GlassActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.bordered)
    }
}

private struct NavigationGlass: ViewModifier {
    func body(content: Content) -> some View {
        content.background(.ultraThinMaterial, in: Capsule())
    }
}

private struct ExportRecord: Identifiable {
    let url: URL
    let date: Date
    var id: URL { url }

    var thumbnail: UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 480,
                kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

private enum EditPanel: String, CaseIterable {
    case film = "胶片"
    case paper = "相纸"
    case adjust = "微调"

    var symbol: String {
        switch self {
        case .film: "camera.aperture"
        case .paper: "square.stack.3d.up"
        case .adjust: "slider.horizontal.3"
        }
    }
}

private struct EditorView: View {
    @State private var selectedURL: URL?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var preview: CGImage?
    @State private var showingHistory = false
    @State private var records: [ExportRecord] = []
    @State private var selectedRecord: ExportRecord?
    @State private var isWorking = false
    @State private var error: String?
    @State private var activePanel: EditPanel = .film
    @State private var film = "kodak_portra_400"
    @State private var paper = "kodak_portra_endura"
    @State private var exposure = 0.0
    @State private var printExposure = 1.0
    @State private var grain = 1.0
    @State private var engine = FilmEngine()

    private let films = [
        Stock(id: "kodak_portra_400", label: "柯达人像 400", originalName: "Portra 400"),
        Stock(id: "kodak_portra_160", label: "柯达人像 160", originalName: "Portra 160"),
        Stock(id: "kodak_gold_200", label: "柯达金 200", originalName: "Gold 200"),
        Stock(id: "fujifilm_pro_400h", label: "富士专业 400H", originalName: "Pro 400H"),
    ]
    private let papers = [
        Stock(id: "kodak_portra_endura", label: "柯达人像 Endura", originalName: "Portra Endura"),
        Stock(id: "fujifilm_crystal_archive_typeii", label: "富士晶彩 II",
              originalName: "Crystal Archive Type II"),
        Stock(id: "kodak_2383", label: "柯达 2383", originalName: "Kodak 2383"),
    ]

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 690
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                photoStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                controls
                    .frame(height: compact ? 174 : 212)
                    .frame(maxWidth: .infinity)
                    .background(DarkroomStyle.panel, in: RoundedRectangle(cornerRadius: 28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                bottomNavigation
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DarkroomStyle.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .tint(DarkroomStyle.accent)
            .onChange(of: selectedPhoto) { item in
                guard let item else { return }
                importPhoto(item)
            }
            .sheet(isPresented: $showingHistory) {
                historyView
            }
            .alert("无法完成冲印", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("好") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SPECTRAL")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(3.8)
                    .foregroundStyle(DarkroomStyle.accent)
                Text("暗房")
                    .font(.system(size: 29, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }
            Spacer()
            PhotosPicker(selection: $selectedPhoto, matching: .images,
                         preferredItemEncoding: .current) {
                Label("相册", systemImage: "photo.badge.plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 36, height: 36)
            }
            .modifier(GlassActionStyle())
            .accessibilityLabel("从相册选取照片")
            Button {
                process(tier: "full")
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 36, height: 36)
            }
            .modifier(GlassActionStyle())
            .accessibilityLabel("导出到相册")
            .disabled(selectedURL == nil || isWorking)
        }
    }

    private var photoStage: some View {
        GeometryReader { area in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.38))
                if let preview {
                    Image(decorative: preview, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: area.size.width - 24, maxHeight: area.size.height - 24)
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 9)
                        .accessibilityLabel("冲印预览")
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 42, weight: .ultraLight))
                            .foregroundStyle(DarkroomStyle.accent.opacity(0.8))
                        VStack(spacing: 7) {
                            Text("把照片带进暗房")
                                .font(.system(size: 22, weight: .medium, design: .serif))
                                .foregroundStyle(.white)
                            Text("从相册选一张照片，试试胶片与相纸的组合")
                                .font(.system(size: 13))
                                .foregroundStyle(DarkroomStyle.muted)
                                .multilineTextAlignment(.center)
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images,
                                     preferredItemEncoding: .current) {
                            Label("从相册选取", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DarkroomStyle.accent)
                        .foregroundStyle(.black)
                    }
                    .padding(18)
                }
                if isWorking {
                    Color.black.opacity(0.35)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    ProgressView("正在冲印")
                        .tint(DarkroomStyle.accent)
                        .padding(18)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .frame(width: area.size.width, height: area.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .topLeading) {
                if preview != nil {
                    Text("LIVE PREVIEW")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(12)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack {
                Text(activePanel.rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Spacer()
                Text(activePanel == .adjust ? "松开滑块后冲印" : "点选后自动冲印")
                    .font(.system(size: 11))
                    .foregroundStyle(DarkroomStyle.muted)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            ScrollView {
                Group {
                    switch activePanel {
                    case .film: stockChoices(films, selection: $film, subtitle: "FILM STOCK")
                    case .paper: stockChoices(papers, selection: $paper, subtitle: "PRINT PAPER")
                    case .adjust:
                        VStack(spacing: 9) {
                            adjustment("胶片曝光", value: $exposure, range: -4...4,
                                       format: "%.1f EV")
                            adjustment("印相曝光", value: $printExposure, range: 0.5...2,
                                       format: "%.2f")
                            adjustment("颗粒", value: $grain, range: 0...2,
                                       format: "%.1f")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 13)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 7) {
                Circle()
                    .fill(selectedURL == nil ? DarkroomStyle.muted : DarkroomStyle.accent)
                    .frame(width: 6, height: 6)
                Text(selectedURL == nil ? "等待照片" : "已载入 · 调整后自动冲印")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("原片保留")
                    .font(.system(size: 11))
            }
            .foregroundStyle(DarkroomStyle.muted)
            .padding(.horizontal, 24)
            .padding(.bottom, 9)
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 10) {
            navigationItems
                .frame(maxWidth: .infinity)
                .modifier(NavigationGlass())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { gesture in
                            guard abs(gesture.translation.width) > 36,
                                  abs(gesture.translation.width) > abs(gesture.translation.height)
                            else { return }
                            let panels = EditPanel.allCases
                            guard let current = panels.firstIndex(of: activePanel) else { return }
                            let next = min(max(current + (gesture.translation.width < 0 ? 1 : -1),
                                               0), panels.count - 1)
                            withAnimation(.snappy(duration: 0.24)) {
                                activePanel = panels[next]
                            }
                        }
                )
            Button {
                records = loadRecords()
                showingHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .modifier(NavigationGlass())
            .accessibilityLabel("导出记录")
        }
        .padding(.horizontal, 18)
        .frame(height: 78)
        .frame(maxWidth: .infinity)
        .background(DarkroomStyle.background)
    }

    private var navigationItems: some View {
        HStack(spacing: 0) {
            ForEach(EditPanel.allCases, id: \.self) { panel in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { activePanel = panel }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: panel.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .frame(height: 23)
                        Text(panel.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                        .foregroundStyle(activePanel == panel ? DarkroomStyle.accent : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(activePanel == panel ? .white.opacity(0.14) : .clear,
                                    in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .id(panel)
                .accessibilityAddTraits(activePanel == panel ? .isSelected : [])
            }
        }
        .padding(3)
    }

    private func stockChoices(_ stocks: [Stock], selection: Binding<String>,
                              subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subtitle)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(DarkroomStyle.muted)
                .padding(.horizontal, 24)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(stocks) { stock in
                        let chosen = selection.wrappedValue == stock.id
                        Button {
                            selection.wrappedValue = stock.id
                            if selectedURL != nil { process(tier: "live") }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 15))
                                    .foregroundStyle(chosen ? DarkroomStyle.accent : .white.opacity(0.3))
                                Spacer(minLength: 0)
                                Text(stock.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(stock.originalName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(DarkroomStyle.muted)
                                    .lineLimit(1)
                            }
                            .frame(width: 136, height: 90, alignment: .leading)
                            .padding(12)
                            .background(
                                LinearGradient(
                                    colors: chosen
                                        ? [Color(red: 0.31, green: 0.26, blue: 0.20),
                                           Color(red: 0.18, green: 0.18, blue: 0.17)]
                                        : [Color.white.opacity(0.09), Color.white.opacity(0.045)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 15)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 15)
                                    .strokeBorder(chosen ? DarkroomStyle.accent.opacity(0.6)
                                                         : .white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func adjustment(_ title: String, value: Binding<Double>,
                            range: ClosedRange<Double>, format: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(DarkroomStyle.accent)
            }
            .font(.system(size: 13, weight: .medium))
            Slider(value: value, in: range) { editing in
                if !editing && selectedURL != nil { process(tier: "live") }
            }
        }
        .padding(.horizontal, 24)
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        isWorking = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                    throw RenderError.message("无法读取这张照片，请选择 JPEG、HEIC 或系统支持的 RAW")
                }
                let contentType = CGImageSourceGetType(source).map { $0 as String }
                let ext = contentType.flatMap { UTType($0)?.preferredFilenameExtension } ?? "img"
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("spectral-photo-\(UUID().uuidString)")
                    .appendingPathExtension(ext)
                try data.write(to: url, options: .atomic)
                selectedURL = url
                selectedPhoto = nil
                preview = nil
                isWorking = false
                process(tier: "live")
            } catch {
                isWorking = false
                self.error = error.localizedDescription
            }
        }
    }

    private func process(tier: String) {
        guard let url = selectedURL else { return }
        isWorking = true
        let film = film, paper = paper, exposure = exposure
        let printExposure = printExposure, grain = grain
        Task {
            do {
                let result = try await engine.render(
                    url: url, film: film, paper: paper, exposure: exposure,
                    printExposure: printExposure, grain: grain, tier: tier
                )
                let picture = try result.image()
                preview = picture
                if tier == "full" {
                    let target = FileManager.default.temporaryDirectory
                        .appendingPathComponent("SpectralDarkroom-\(UUID().uuidString).jpg")
                    guard let destination = CGImageDestinationCreateWithURL(
                        target as CFURL, UTType.jpeg.identifier as CFString, 1, nil
                    ) else { throw RenderError.message("无法创建 JPEG 文件") }
                    CGImageDestinationAddImage(destination, picture, [
                        kCGImageDestinationLossyCompressionQuality: 0.95
                    ] as CFDictionary)
                    guard CGImageDestinationFinalize(destination) else {
                        throw RenderError.message("无法写入 JPEG 文件")
                    }
                    try await saveToPhotos(target)
                    let historyURL = try historyDirectory()
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    try FileManager.default.copyItem(at: target, to: historyURL)
                    records = loadRecords()
                }
            } catch {
                self.error = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func saveToPhotos(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw RenderError.message("没有保存到相册的权限；请在系统设置中允许添加照片")
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        }
    }

    private func historyDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask, appropriateFor: nil,
                                               create: true)
            .appendingPathComponent("ExportHistory", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func loadRecords() -> [ExportRecord] {
        guard let directory = try? historyDirectory(),
              let urls = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }
        return urls.filter { $0.pathExtension.lowercased() == "jpg" }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
                    ?? .distantPast
                return ExportRecord(url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    private var historyView: some View {
        NavigationStack {
            ScrollView {
                if records.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 35))
                            .foregroundStyle(DarkroomStyle.muted)
                        Text("暂无导出记录")
                            .font(.headline)
                        Text("保存到相册的照片会显示在这里")
                            .font(.subheadline)
                            .foregroundStyle(DarkroomStyle.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 70)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                              spacing: 14) {
                        ForEach(records) { record in
                            Button { selectedRecord = record } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    if let thumbnail = record.thumbnail {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 170)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    Text(record.date, format: .dateTime.year().month().day()
                                        .hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(DarkroomStyle.muted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
            .background(DarkroomStyle.background)
            .navigationTitle("导出记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showingHistory = false }
                }
            }
        }
        .sheet(item: $selectedRecord) { record in
            recordDetail(record)
        }
    }

    private func recordDetail(_ record: ExportRecord) -> some View {
        NavigationStack {
            GeometryReader { area in
                if let image = UIImage(contentsOfFile: record.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: area.size.width, height: area.size.height)
                }
            }
            .background(DarkroomStyle.background)
            .navigationTitle("已保存到相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { selectedRecord = nil }
                }
            }
        }
    }
}
