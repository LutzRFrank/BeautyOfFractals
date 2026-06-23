import SwiftUI
import CoreGraphics
import AppKit
import UniformTypeIdentifiers
import simd
import Combine

private let highPrecisionScaleLimit: Double = 0.006

// Below this scale a Float-based Metal preview can no longer reliably represent
// the current viewport. Keep the last completed CPU image visible instead and
// refine the new viewport in two CPU stages using the same Double coordinates.
private let deepCPUPreviewScaleLimit: Double = 0.00001

private let highPrecisionPreviewMaxPixelWidth: Int = 1800
private let highPrecisionPreviewMaxPixelHeight: Int = 1200
private let deepCPUPreviewMaxPixelWidth: Int = 720
private let deepCPUPreviewMaxPixelHeight: Int = 480
private let deepCPUPreviewIterationCap: Int = 2_500

enum FractalMode: Int, CaseIterable, Identifiable {
    case mandelbrot = 0
    case julia = 1
    case burningShip = 2
    case tricorn = 3
    case kleinian = 4
    case mandelbulb3D = 5
    case mandelbrotRelief = 6
    case mandelbox3D = 7
    case newton = 8
    
    var id: Int {
        rawValue
    }
    
    var displayName: String {
        switch self {
        case .mandelbrot:
            return "Mandelbrot"
        case .julia:
            return "Julia"
        case .burningShip:
            return "Burning Ship"
        case .tricorn:
            return "Tricorn"
        case .kleinian:
            return "Kleinian Relief"
        case .mandelbulb3D:
            return "Mandelbulb 3D"
        case .mandelbrotRelief:
            return "Mandelbrot Relief"
        case .mandelbox3D:
            return "Mandelbox 3D"
        case .newton:
            return "Newton Fractal"
        }
    }
    
    var shortName: String {
        switch self {
        case .mandelbrot:
            return "Mandelbrot"
        case .julia:
            return "Julia"
        case .burningShip:
            return "Burning"
        case .tricorn:
            return "Tricorn"
        case .kleinian:
            return "Kleinian"
        case .mandelbulb3D:
            return "Mandelbulb"
        case .mandelbrotRelief:
            return "Relief"
        case .mandelbox3D:
            return "Mandelbox"
        case .newton:
            return "Newton"
        }
    }
    
    var fileName: String {
        switch self {
        case .mandelbrot:
            return "Mandelbrot"
        case .julia:
            return "Julia"
        case .burningShip:
            return "BurningShip"
        case .tricorn:
            return "Tricorn"
        case .kleinian:
            return "KleinianRelief"
        case .mandelbulb3D:
            return "Mandelbulb3D"
        case .mandelbrotRelief:
            return "MandelbrotRelief"
        case .mandelbox3D:
            return "Mandelbox3D"
        case .newton:
            return "Newton"
        }
    }
    
    var defaultCenterX: Double {
        switch self {
        case .mandelbrot:
            return -0.5
        case .julia:
            return 0.0
        case .burningShip:
            return -0.5
        case .tricorn:
            return 0.0
        case .kleinian:
            return 0.0
        case .mandelbulb3D:
            return 0.0
        case .mandelbrotRelief:
            return -0.5
        case .mandelbox3D:
            return 0.0
        case .newton:
            return 0.0
        }
    }
    
    var defaultCenterY: Double {
        switch self {
        case .mandelbrot:
            return 0.0
        case .julia:
            return 0.0
        case .burningShip:
            return -0.5
        case .tricorn:
            return 0.0
        case .kleinian:
            return 0.0
        case .mandelbulb3D:
            return 0.0
        case .mandelbrotRelief:
            return 0.0
        case .mandelbox3D:
            return 0.0
        case .newton:
            return 0.0
        }
    }
    
    var defaultScale: Double {
        switch self {
        case .mandelbrot:
            return 3.0
        case .julia:
            return 3.0
        case .burningShip:
            return 3.2
        case .tricorn:
            return 3.2
        case .kleinian:
            return 3.0
        case .mandelbulb3D:
            return 2.8
        case .mandelbrotRelief:
            return 3.0
        case .mandelbox3D:
            return 2.8
        case .newton:
            return 3.2
        }
    }
    
    var supportsHighPrecisionPreview: Bool {
        switch self {
        case .mandelbrot, .mandelbrotRelief, .julia, .burningShip, .tricorn, .kleinian, .newton:
            return true
        case .mandelbulb3D, .mandelbox3D:
            return false
        }
    }
}

enum FractalPalette: Int, CaseIterable, Identifiable {
    case ocean = 0
    case electric = 1
    case fire = 2
    case ice = 3
    case gold = 4
    case violet = 5
    case deepBlue = 6
    case solarCoral = 7
    case infernoCoral = 8
    case solarPop = 9
    
    var id: Int {
        rawValue
    }
    
    var displayName: String {
        switch self {
        case .ocean:
            return "Ocean"
        case .electric:
            return "Electric"
        case .fire:
            return "Fire"
        case .ice:
            return "Ice"
        case .gold:
            return "Gold"
        case .violet:
            return "Violet"
        case .deepBlue:
            return "Deep Blue"
        case .solarCoral:
            return "Solar Coral"
        case .infernoCoral:
            return "Inferno Coral"
        case .solarPop:
            return "Solar Pop"
        }
    }
    
    var fileName: String {
        switch self {
        case .ocean:
            return "Ocean"
        case .electric:
            return "Electric"
        case .fire:
            return "Fire"
        case .ice:
            return "Ice"
        case .gold:
            return "Gold"
        case .violet:
            return "Violet"
        case .deepBlue:
            return "DeepBlue"
        case .solarCoral:
            return "SolarCoral"
        case .infernoCoral:
            return "InfernoCoral"
        case .solarPop:
            return "SolarPop"
        }
    }
}

enum RenderQuality: String, CaseIterable, Identifiable {
    case fast = "Fast"
    case high = "High"
    case deep = "Deep"
    
    var id: String { rawValue }
    
    var iterationMultiplier: Double {
        switch self {
        case .fast:
            return 1.0
        case .high:
            return 1.6
        case .deep:
            return 2.5
        }
    }
}

private func effectiveIterationCount(
    baseIterations: Int,
    renderQuality: RenderQuality,
    scale: Double,
    defaultScale: Double,
    cap: Int = 80_000
) -> Int {
    let zoomLevel = defaultScale / max(scale, 0.000000000000000001)
    let zoomBoost: Double
    
    if zoomLevel > 100_000_000 {
        zoomBoost = 1.6
    } else if zoomLevel > 10_000_000 {
        zoomBoost = 1.35
    } else if zoomLevel > 1_000_000 {
        zoomBoost = 1.2
    } else {
        zoomBoost = 1.0
    }
    
    let value = Double(baseIterations) * renderQuality.iterationMultiplier * zoomBoost
    return min(max(Int(value.rounded()), 300), cap)
}


struct FavoriteSpot: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var modeRawValue: Int
    var paletteRawValue: Int
    var centerX: Double
    var centerY: Double
    var scale: Double
    var iterations: Int
    var created: Date = Date()
    var thumbnailPNG: Data? = nil
    var usageCount: Int = 0

    var mode: FractalMode {
        FractalMode(rawValue: modeRawValue) ?? .mandelbrot
    }

    var palette: FractalPalette {
        FractalPalette(rawValue: paletteRawValue) ?? .deepBlue
    }

    var zoomText: String {
        formatMagnification(mode.defaultScale / max(scale, 1e-18))
    }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var spots: [FavoriteSpot] = []

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("BeautyOfFractals", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("FavoriteSpots.json")
    }

    init() {
        load()
    }

    func spots(for mode: FractalMode) -> [FavoriteSpot] {
        spots.filter { $0.mode == mode }
            .sorted { $0.created > $1.created }
    }

    func add(_ spot: FavoriteSpot) {
        spots.insert(spot, at: 0)
        save()
    }

    func delete(_ spot: FavoriteSpot) {
        spots.removeAll { $0.id == spot.id }
        save()
    }

    func incrementUsage(for spot: FavoriteSpot) {
        guard let index = spots.firstIndex(where: { $0.id == spot.id }) else {
            return
        }

        spots[index].usageCount += 1
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([FavoriteSpot].self, from: data) else {
            spots = []
            return
        }
        spots = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(spots) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}




private func makeFavoriteThumbnailPNG(from image: CGImage) -> Data? {
    let sourceWidth = image.width
    let sourceHeight = image.height
    let targetWidth = 220
    let targetHeight = 138

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: targetWidth,
        height: targetHeight,
        bitsPerComponent: 8,
        bytesPerRow: targetWidth * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.interpolationQuality = .high

    let sourceAspect = CGFloat(sourceWidth) / CGFloat(max(sourceHeight, 1))
    let targetAspect = CGFloat(targetWidth) / CGFloat(targetHeight)

    var drawRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)

    if sourceAspect > targetAspect {
        let drawHeight = CGFloat(targetHeight)
        let drawWidth = drawHeight * sourceAspect
        drawRect = CGRect(x: (CGFloat(targetWidth) - drawWidth) / 2, y: 0, width: drawWidth, height: drawHeight)
    } else {
        let drawWidth = CGFloat(targetWidth)
        let drawHeight = drawWidth / max(sourceAspect, 0.0001)
        drawRect = CGRect(x: 0, y: (CGFloat(targetHeight) - drawHeight) / 2, width: drawWidth, height: drawHeight)
    }

    context.draw(image, in: drawRect)

    guard let thumb = context.makeImage() else { return nil }
    let bitmap = NSBitmapImageRep(cgImage: thumb)
    return bitmap.representation(using: .png, properties: [:])
}


private func makeFavoriteThumbnailPNG(
    mode: FractalMode,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double,
    iterations: Int,
    viewportAspectRatio: Double = 16.0 / 10.0
) -> Data? {
    guard let image = renderFractal(
        width: 220,
        height: 138,
        mode: mode,
        palette: palette,
        centerX: centerX,
        centerY: centerY,
        scale: scale,
        maxIterations: max(300, min(iterations, 3_000)),
        viewportAspectRatio: viewportAspectRatio
    ) else {
        return nil
    }

    let bitmap = NSBitmapImageRep(cgImage: image)
    return bitmap.representation(using: .png, properties: [:])
}



enum FavoriteSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case mostUsed = "Most Used"
    case name = "Name A–Z"
    case zoom = "Zoom Level"
    case iterations = "Iterations"

    var id: String { rawValue }
}


struct ContentView: View {
    @State private var fractalMode: FractalMode = .mandelbrot
    @State private var fractalPalette: FractalPalette = .deepBlue
    @State private var renderQuality: RenderQuality = .high
    
    @State private var centerX: Double = FractalMode.mandelbrot.defaultCenterX
    @State private var centerY: Double = FractalMode.mandelbrot.defaultCenterY
    @State private var scale: Double = FractalMode.mandelbrot.defaultScale
    
    @State private var maxIterations: Int = 300
    @State private var isSavingSnapshot: Bool = false
    @State private var showHelp: Bool = false
    @State private var showFavoritesPanel: Bool = false
    @State private var favoriteName: String = ""
    @State private var favoriteSort: FavoriteSort = .newest
    @StateObject private var favoritesStore = FavoritesStore()
    @State private var latestHighPrecisionThumbnailPNG: Data?
    @State private var navigationHistory: [ViewportSnapshot] = []
    @State private var navigationRevision: UInt = 0

    private let maximumNavigationHistory = 100

    private struct ViewportSnapshot: Equatable {
        let centerX: Double
        let centerY: Double
        let scale: Double
        let maxIterations: Int
    }
    
    private var effectiveIterations: Int {
        effectiveIterationCount(
            baseIterations: maxIterations,
            renderQuality: renderQuality,
            scale: scale,
            defaultScale: fractalMode.defaultScale,
            cap: renderQuality == .deep ? 100_000 : 80_000
        )
    }
    
    private var exportEffectiveIterations: Int {
        effectiveIterationCount(
            baseIterations: maxIterations,
            renderQuality: renderQuality,
            scale: scale,
            defaultScale: fractalMode.defaultScale,
            cap: renderQuality == .deep ? 100_000 : 80_000
        )
    }
    
    private var ultraExportEffectiveIterations: Int {
        min(
            Int(Double(exportEffectiveIterations) * 1.5),
            120_000
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MandelbrotView(
                fractalMode: fractalMode,
                fractalPalette: fractalPalette,
                centerX: $centerX,
                centerY: $centerY,
                scale: $scale,
                maxIterations: $maxIterations,
                renderQuality: renderQuality,
                navigationStarted: recordNavigationStep,
                navigationRevision: navigationRevision,
                latestHighPrecisionThumbnailPNG: $latestHighPrecisionThumbnailPNG
            )
            .frame(minWidth: 760, minHeight: 650)
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                if showFavoritesPanel {
                    favoritesPanel
                        .padding(.trailing, 28)
                        .padding(.top, 72)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            controlsOverlay
                .padding(.bottom, 26)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showFavoritesPanel)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .exportDefaultFractal)) { _ in
            saveSnapshot(width: 2560, height: 1600)
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomInFractal)) { _ in
            zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOutFractal)) { _ in
            zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetFractal)) { _ in
            resetView()
        }
        .focusedValue(\.fractalActions, FractalActions(
            snap: {
                saveSnapshot(width: 2560, height: 1600)
            },
            zoomIn: zoomIn,
            zoomOut: zoomOut,
            reset: resetView
        ))
        .alert("Controls", isPresented: $showHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
Choose a fractal mode from the Mode menu:
Mandelbrot, Mandelbrot Relief, Julia, Burning Ship, Tricorn, Kleinian Relief, Mandelbulb 3D, Mandelbox 3D or Newton Fractal.

Choose a color palette from the Palette menu:
Ocean, Electric, Fire, Ice, Gold, Violet or Deep Blue.

Choose render quality from the Quality menu:
Fast, High or Deep. Deep renders more detail at high zooms.

Drag: select an area and zoom in

⌥ Option + Drag: move the view

+ / -: zoom in and out

⌘R: reset view

⌘S: export 2560 × 1600 PNG

Deep 2D zooms automatically use High Precision Preview.
At very deep zooms the app shows Near Limit or Extreme Zoom so precision artifacts are easier to recognize.

Export menu:
Normal exports render at the selected size.
Ultra exports render internally at 2× resolution and downsample for cleaner images.
Live preview is capped at 50,000 iterations; normal export at 80,000; Ultra export at 120,000.

The zoom factor overlay is only visible in the app and is not included in exports.
3D exports are CPU raymarched and may take longer.
""")
        }
    }
    
    private var controlsOverlay: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(FractalMode.allCases) { mode in
                        Button {
                            setMode(mode)
                        } label: {
                            Text("\(fractalMode == mode ? "✓ " : "   ")\(mode.displayName)")
                        }
                    }
                } label: {
                    Text("Mode: \(fractalMode.shortName)")
                        .frame(width: 135, alignment: .leading)
                }
                .help("Choose fractal mode")
                
                Menu {
                    ForEach(FractalPalette.allCases) { palette in
                        Button {
                            fractalPalette = palette
                        } label: {
                            Text("\(fractalPalette == palette ? "✓ " : "   ")\(palette.displayName)")
                        }
                    }
                } label: {
                    Text("Palette: \(fractalPalette.displayName)")
                        .frame(width: 130, alignment: .leading)
                }
                .help("Choose color palette")
                
                Menu {
                    ForEach(RenderQuality.allCases) { quality in
                        Button {
                            renderQuality = quality
                        } label: {
                            Text("\(renderQuality == quality ? "✓ " : "   ")\(quality.rawValue)")
                        }
                    }
                } label: {
                    Text("Quality: \(renderQuality.rawValue)")
                        .frame(width: 104, alignment: .leading)
                }
                .help("Choose render quality")
                
                Button {
                    zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .frame(width: 20)
                }
                .keyboardShortcut("-", modifiers: [])
                .help("Zoom Out")
                
                Button {
                    zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .frame(width: 20)
                }
                .keyboardShortcut("+", modifiers: [])
                .keyboardShortcut("=", modifiers: [])
                .help("Zoom In")
                
                Button {
                    undoView()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 20)
                }
                .disabled(navigationHistory.isEmpty)
                .keyboardShortcut("z", modifiers: .command)
                .help("Undo last zoom, pan or reset")

                Button {
                    resetView()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 20)
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Reset View")
                
                Menu(isSavingSnapshot ? "Rendering…" : "Export") {
                    Button("Export 1440 × 900 PNG") {
                        saveSnapshot(width: 1440, height: 900)
                    }
                    
                    Button("Export 2560 × 1600 PNG") {
                        saveSnapshot(width: 2560, height: 1600)
                    }
                    
                    Button("Export 2880 × 1800 PNG") {
                        saveSnapshot(width: 2880, height: 1800)
                    }
                    
                    Divider()
                    
                    Button("Ultra Export 1440 × 900 PNG · 2×") {
                        saveSnapshot(width: 1440, height: 900, supersampling: 2)
                    }
                    
                    Button("Ultra Export 2560 × 1600 PNG · 2×") {
                        saveSnapshot(width: 2560, height: 1600, supersampling: 2)
                    }
                    
                    // 2880 × 1800 stays normal export only.
                    // Ultra 2× at this size allocates a 5760 × 3600 render buffer and can stall macOS on smaller systems.
                }
                .disabled(isSavingSnapshot)
                
                Button {
                    showFavoritesPanel.toggle()
                } label: {
                    Image(systemName: showFavoritesPanel ? "star.fill" : "star")
                        .frame(width: 20)
                }
                .help("Favorite Spots")

                Button("?") {
                    showHelp = true
                }
                .help("Show controls")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            HStack(spacing: 10) {
                Text("Iterations: \(effectiveIterations.formatted())")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .frame(width: 130, alignment: .trailing)
                
                Slider(
                    value: Binding(
                        get: {
                            Double(maxIterations)
                        },
                        set: {
                            maxIterations = Int(($0 / 100).rounded()) * 100
                        }
                    ),
                    in: 300...24000
                )
                .frame(width: 220)
                
                Stepper(
                    "",
                    value: $maxIterations,
                    in: 300...24000,
                    step: 100
                )
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 24)
    }
    

    private var favoritesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Favorite Spots", systemImage: "star.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Spacer()

                Button {
                    showFavoritesPanel = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close")
            }

            HStack {
                Text(fractalMode.displayName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(FavoriteSort.allCases) { sort in
                        Button {
                            favoriteSort = sort
                        } label: {
                            Text("\(favoriteSort == sort ? "✓ " : "   ")\(sort.rawValue)")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(favoriteSort.rawValue)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                }
                .help("Sort favorites")
            }

            HStack(spacing: 8) {
                TextField("Name this view", text: $favoriteName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveCurrentFavorite()
                    }

                Button {
                    saveCurrentFavorite()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(favoriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Save Current View")
            }

            Divider()

            let modeSpots = favoritesStore.spots(for: fractalMode)
            let sortedSpots = sortedFavoriteSpots(modeSpots)

            if sortedSpots.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    Text("No saved spots yet")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("Zoom into a beautiful region and save it here.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sortedSpots) { spot in
                            favoriteSpotRow(spot)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 360)
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }


    private func sortedFavoriteSpots(_ spots: [FavoriteSpot]) -> [FavoriteSpot] {
        switch favoriteSort {
        case .newest:
            return spots.sorted { $0.created > $1.created }
        case .mostUsed:
            return spots.sorted {
                if $0.usageCount == $1.usageCount {
                    return $0.created > $1.created
                }
                return $0.usageCount > $1.usageCount
            }
        case .name:
            return spots.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .zoom:
            return spots.sorted { $0.scale < $1.scale }
        case .iterations:
            return spots.sorted {
                if $0.iterations == $1.iterations {
                    return $0.created > $1.created
                }
                return $0.iterations > $1.iterations
            }
        }
    }


    private func favoriteSpotRow(_ spot: FavoriteSpot) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .cyan.opacity(0.42),
                                .blue.opacity(0.24),
                                .black.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let thumbnailPNG = spot.thumbnailPNG,
                   let thumbnail = NSImage(data: thumbnailPNG) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 82, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: 82, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text("Zoom \(spot.zoomText)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text("\(spot.iterations.formatted()) iterations")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)

                if spot.usageCount > 0 {
                    Text("Opened \(spot.usageCount)x")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 6) {
                Button {
                    loadFavorite(spot)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Load Favorite")

                Button {
                    favoritesStore.delete(spot)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red.opacity(0.85))
                .help("Delete Favorite")
            }
        }
        .padding(10)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(count: 2) {
            loadFavorite(spot)
        }
        .help("Double-click to load this favorite")
        .contextMenu {
            Button("Load") {
                loadFavorite(spot)
            }

            Divider()

            Button("Delete", role: .destructive) {
                favoritesStore.delete(spot)
            }
        }
    }

    private func saveCurrentFavorite() {
        let trimmed = favoriteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        favoritesStore.add(
            FavoriteSpot(
                name: trimmed,
                modeRawValue: fractalMode.rawValue,
                paletteRawValue: fractalPalette.rawValue,
                centerX: centerX,
                centerY: centerY,
                scale: scale,
                iterations: maxIterations,
                thumbnailPNG: latestHighPrecisionThumbnailPNG ?? makeFavoriteThumbnailPNG(
                    mode: fractalMode,
                    palette: fractalPalette,
                    centerX: centerX,
                    centerY: centerY,
                    scale: scale,
                    iterations: maxIterations
                )
            )
        )

        favoriteName = ""
    }

    private func loadFavorite(_ spot: FavoriteSpot) {
        recordNavigationStep()
        fractalMode = spot.mode
        fractalPalette = spot.palette
        centerX = spot.centerX
        centerY = spot.centerY
        scale = spot.scale
        maxIterations = spot.iterations
        navigationRevision &+= 1
        favoritesStore.incrementUsage(for: spot)
    }


    private func currentViewportSnapshot() -> ViewportSnapshot {
        ViewportSnapshot(
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            maxIterations: maxIterations
        )
    }

    private func recordNavigationStep() {
        let snapshot = currentViewportSnapshot()

        guard navigationHistory.last != snapshot else { return }

        navigationHistory.append(snapshot)
        if navigationHistory.count > maximumNavigationHistory {
            navigationHistory.removeFirst(navigationHistory.count - maximumNavigationHistory)
        }
    }

    private func undoView() {
        guard let previous = navigationHistory.popLast() else { return }

        // Tell the live renderer to invalidate a pending debounce/CPU refinement
        // before restoring the older viewport.
        navigationRevision &+= 1
        centerX = previous.centerX
        centerY = previous.centerY
        scale = previous.scale
        maxIterations = previous.maxIterations
    }

    private func setMode(_ mode: FractalMode) {
        fractalMode = mode
        centerX = mode.defaultCenterX
        centerY = mode.defaultCenterY
        scale = mode.defaultScale
        maxIterations = 300
        navigationHistory.removeAll()
        navigationRevision &+= 1
    }
    
    private func zoomIn() {
        recordNavigationStep()
        navigationRevision &+= 1
        scale *= 0.5
        increaseIterationsForZoom()
    }
    
    private func zoomOut() {
        recordNavigationStep()
        navigationRevision &+= 1
        scale *= 2.0
        decreaseIterationsForZoom()
    }
    
    private func resetView() {
        recordNavigationStep()
        navigationRevision &+= 1
        centerX = fractalMode.defaultCenterX
        centerY = fractalMode.defaultCenterY
        scale = fractalMode.defaultScale
        maxIterations = 300
    }
    
    private func increaseIterationsForZoom() {
        if maxIterations < 500 {
            maxIterations += 400
        } else if maxIterations < 1000 {
            maxIterations += 700
        } else if maxIterations < 2500 {
            maxIterations += 1200
        } else if maxIterations < 5000 {
            maxIterations += 1500
        } else if maxIterations < 8000 {
            maxIterations += 2000
        } else if maxIterations < 12000 {
            maxIterations += 3000
        } else if maxIterations < 18000 {
            maxIterations += 4000
        } else {
            maxIterations += 6000
        }
        
        maxIterations = min(maxIterations, 24000)
    }
    
    private func decreaseIterationsForZoom() {
        if maxIterations > 20000 {
            maxIterations -= 6000
        } else if maxIterations > 16000 {
            maxIterations -= 4000
        } else if maxIterations > 10000 {
            maxIterations -= 3000
        } else if maxIterations > 7000 {
            maxIterations -= 2000
        } else if maxIterations > 3500 {
            maxIterations -= 1500
        } else if maxIterations > 2500 {
            maxIterations -= 1200
        } else if maxIterations > 1000 {
            maxIterations -= 700
        } else {
            maxIterations -= 400
        }
        
        maxIterations = max(maxIterations, 300)
    }
    
    
    private func saveSnapshot(width exportWidth: Int = 2560, height exportHeight: Int = 1600, supersampling: Int = 1) {
        if isSavingSnapshot {
            return
        }
        
        let snapshotMode = fractalMode
        let snapshotPalette = fractalPalette
        let snapshotCenterX = centerX
        let snapshotCenterY = centerY
        let snapshotScale = scale
        let snapshotSupersampling = max(1, min(supersampling, 2))
        let snapshotIterations = snapshotSupersampling > 1 ? ultraExportEffectiveIterations : exportEffectiveIterations
        let snapshotExportSuffix = snapshotSupersampling > 1 ? "-Ultra\(snapshotSupersampling)x" : ""
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue =
            "BeautyOfFractals-\(snapshotMode.fileName)-\(snapshotPalette.fileName)-\(snapshotIterations)-iterations\(snapshotExportSuffix)-\(exportWidth)x\(exportHeight).png"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            
            isSavingSnapshot = true
            
            Task.detached(priority: .userInitiated) {
                let cgImage: CGImage?
                
                if snapshotMode == .mandelbulb3D {
                    cgImage = renderMandelbulb3DImage(
                        width: exportWidth,
                        height: exportHeight,
                        palette: snapshotPalette,
                        centerX: snapshotCenterX,
                        centerY: snapshotCenterY,
                        scale: snapshotScale
                    )
                } else if snapshotMode == .mandelbox3D {
                    cgImage = renderMandelbox3DImage(
                        width: exportWidth,
                        height: exportHeight,
                        palette: snapshotPalette,
                        centerX: snapshotCenterX,
                        centerY: snapshotCenterY,
                        scale: snapshotScale
                    )
                } else {
                    cgImage = renderFractalSupersampled(
                        width: exportWidth,
                        height: exportHeight,
                        supersampling: snapshotSupersampling,
                        mode: snapshotMode,
                        palette: snapshotPalette,
                        centerX: snapshotCenterX,
                        centerY: snapshotCenterY,
                        scale: snapshotScale,
                        maxIterations: snapshotIterations
                    )
                }
                
                guard let finalImage = cgImage else {
                    await MainActor.run {
                        isSavingSnapshot = false
                    }
                    return
                }
                
                let bitmapRep = NSBitmapImageRep(cgImage: finalImage)
                
                guard let pngData = bitmapRep.representation(
                    using: .png,
                    properties: [:]
                ) else {
                    await MainActor.run {
                        isSavingSnapshot = false
                    }
                    return
                }
                
                do {
                    try pngData.write(to: url)
                } catch {
                    print("Snapshot konnte nicht gespeichert werden:", error)
                }
                
                await MainActor.run {
                    isSavingSnapshot = false
                }
            }
        }
    }
}

struct HighPrecisionViewportState: Equatable {
    let centerX: Double
    let centerY: Double
    let scale: Double
    let iterations: Int
    let thumbnailPNG: Data? = nil
}

private struct FractalViewportTransform {
    let centerX: Double
    let centerY: Double
    let scale: Double
    let viewSize: CGSize

    private var width: Double { max(Double(viewSize.width), 1.0) }
    private var height: Double { max(Double(viewSize.height), 1.0) }
    var aspectRatio: Double { width / height }

    /// Converts a SwiftUI point (origin at the top-left) to the exact complex-plane
    /// coordinate used by the live preview and high-precision renderer.
    func complexPoint(at point: CGPoint) -> (x: Double, y: Double) {
        (
            centerX + (Double(point.x) / width - 0.5) * scale * aspectRatio,
            centerY + (Double(point.y) / height - 0.5) * scale
        )
    }

    func centerAfterPan(from start: CGPoint, to current: CGPoint) -> (x: Double, y: Double) {
        let dx = Double(current.x - start.x)
        let dy = Double(current.y - start.y)

        return (
            centerX - (dx / width) * scale * aspectRatio,
            centerY - (dy / height) * scale
        )
    }
}

struct MandelbrotView: View {
    let fractalMode: FractalMode
    let fractalPalette: FractalPalette
    
    @Binding var centerX: Double
    @Binding var centerY: Double
    @Binding var scale: Double
    @Binding var maxIterations: Int
    let renderQuality: RenderQuality
    let navigationStarted: () -> Void
    let navigationRevision: UInt
    @Binding var latestHighPrecisionThumbnailPNG: Data?
    
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    
    @State private var isOptionPressed: Bool = false
    @State private var isPanning: Bool = false
    @State private var panStartCenterX: Double = -0.5
    @State private var panStartCenterY: Double = 0.0
    
    @State private var keyMonitor: Any?
    // Safe progressive rendering: keep the last completed high-precision image
    // visible while panning instead of falling back to GPU at extreme zoom.
    @State private var isInteractionPreviewActive: Bool = false
    // The viewport of the CPU image that is actually on screen. It can be older
    // than centerX/centerY/scale while a newer request is still rendering.
    @State private var visibleHighPrecisionState: HighPrecisionViewportState?
    @State private var frozenHighPrecisionState: HighPrecisionViewportState?
    @State private var refineTask: Task<Void, Never>?
    // Invalidates a pending high-precision worker when a new interaction starts.
    @State private var highPrecisionRenderEpoch: UInt = 0

    
    private var useHighPrecisionPreview: Bool {
        fractalMode.supportsHighPrecisionPreview && scale < highPrecisionScaleLimit
    }

    /// At very deep zoom levels the Metal shader's Float uniforms are no longer
    /// trustworthy as a live viewport preview. The CPU renderer then publishes a
    /// quick Double-precision preview before its full refinement.
    private var useDeepCPUPreview: Bool {
        fractalMode.supportsHighPrecisionPreview && scale < deepCPUPreviewScaleLimit
    }
    
    private var magnificationFactor: Double {
        fractalMode.defaultScale / max(scale, 0.000000000000000001)
    }
    
    private var magnificationText: String {
        formatMagnification(magnificationFactor)
    }
    
    private var precisionStatusText: String? {
        if !fractalMode.supportsHighPrecisionPreview {
            return nil
        }
        
        if useDeepCPUPreview {
            return "High Precision · CPU Deep Zoom"
        }

        if magnificationFactor >= 50_000_000_000 {
            return "High Precision · Extreme Zoom"
        }
        
        if magnificationFactor >= 10_000_000_000 {
            return "High Precision · Near Limit"
        }
        
        if useHighPrecisionPreview {
            return "High Precision"
        }
        
        return nil
    }
    
    private var effectiveIterations: Int {
        effectiveIterationCount(
            baseIterations: maxIterations,
            renderQuality: renderQuality,
            scale: scale,
            defaultScale: fractalMode.defaultScale,
            cap: renderQuality == .deep ? 100_000 : 80_000
        )
    }

    private var interactionPreviewIterations: Int {
        max(300, min(effectiveIterations, Int(Double(effectiveIterations) * 0.25)))
    }

    private var metalDisplayedIterations: Int {
        isInteractionPreviewActive ? interactionPreviewIterations : effectiveIterations
    }

    private var currentViewportState: HighPrecisionViewportState {
        HighPrecisionViewportState(
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            iterations: effectiveIterations
        )
    }

    private var highPrecisionDisplayState: HighPrecisionViewportState {
        if isInteractionPreviewActive, let frozenHighPrecisionState {
            return frozenHighPrecisionState
        }

        return currentViewportState
    }

    private var interactionStatusText: String? {
        guard isInteractionPreviewActive else { return nil }

        if useHighPrecisionPreview, frozenHighPrecisionState != nil {
            return "Preview held · release to refine"
        }

        return "Preview · refining detail…"
    }
    
    var body: some View {
        GeometryReader { geometry in
            // One aspect ratio is shared by navigation, Metal and CPU refinement.
            // This avoids a drift caused by independent rounding of the MTK drawable
            // and the capped high-precision bitmap.
            let viewportAspectRatio = Double(max(geometry.size.width, 1.0)) /
                Double(max(geometry.size.height, 1.0))

            ZStack(alignment: .topTrailing) {
                ZStack {
                    // Keep Metal visible as the fallback while the first CPU frame is built.
                    MetalMandelbrotView(
                        fractalMode: fractalMode,
                        fractalPalette: fractalPalette,
                        centerX: centerX,
                        centerY: centerY,
                        scale: scale,
                        maxIterations: metalDisplayedIterations,
                        viewportAspectRatio: viewportAspectRatio
                    )

                    if useHighPrecisionPreview {
                        let state = highPrecisionDisplayState

                        HighPrecisionFractalPreview(
                            fractalMode: fractalMode,
                            fractalPalette: fractalPalette,
                            centerX: state.centerX,
                            centerY: state.centerY,
                            scale: state.scale,
                            maxIterations: state.iterations,
                            displayIterations: effectiveIterations,
                            viewSize: geometry.size,
                            viewportAspectRatio: viewportAspectRatio,
                            progressiveCPUPreview: useDeepCPUPreview,
                            refinementEnabled: !isInteractionPreviewActive,
                            renderEpoch: highPrecisionRenderEpoch,
                            renderQualityKey: renderQuality.rawValue,
                            onImagePublished: { visibleState in
                                // Navigation must be calculated against the frame the user
                                // can actually see, not against a newer frame still rendering.
                                visibleHighPrecisionState = visibleState
                            },
                            onThumbnailPublished: { thumbnailPNG in
                                latestHighPrecisionThumbnailPNG = thumbnailPNG
                            }
                        )
                    }
                    
                }

                if let rect = selectionRect, !isPanning {
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .background(
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                
                HStack {
                    Text("Zoom \(magnificationText)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 16)
                        .padding(.leading, 18)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        if let interactionStatusText {
                            Text(interactionStatusText)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }

                        if let precisionStatusText {
                            Text(precisionStatusText)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 18)
                }
            }
            .contentShape(Rectangle())
            // Attach the drag recognizer to the stable parent ZStack. A transparent overlay
            // can stop receiving mouse events after AppKit replaces a Metal/Image frame.
            .gesture(selectionDragGesture(viewSize: geometry.size))
            .onAppear {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                    isOptionPressed = event.modifierFlags.contains(.option)
                    
                    if isOptionPressed {
                        NSCursor.openHand.set()
                    } else {
                        NSCursor.crosshair.set()
                    }
                    
                    return event
                }
            }
            .onChange(of: navigationRevision) {
                // External navigation (Undo, toolbar zoom, Reset or a mode change)
                // must never allow a pending refinement for the former viewport to win.
                refineTask?.cancel()
                refineTask = nil
                isInteractionPreviewActive = false
                frozenHighPrecisionState = nil
                highPrecisionRenderEpoch &+= 1
            }
            .onDisappear {
                refineTask?.cancel()
                refineTask = nil

                if let keyMonitor {
                    NSEvent.removeMonitor(keyMonitor)
                    self.keyMonitor = nil
                }
            }
            .onHover { hovering in
                if hovering {
                    if isOptionPressed {
                        NSCursor.openHand.push()
                    } else {
                        NSCursor.crosshair.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
    
    private func selectionDragGesture(viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStart == nil {
                    // The CPU layer intentionally keeps its last complete image visible
                    // while a newer frame is calculated. Before interpreting a new gesture,
                    // reconcile the model with that visible image. This makes selection
                    // during refinement WYSIWYG instead of applying it to an invisible,
                    // pending viewport.
                    beginInteractionPreview()

                    dragStart = value.startLocation
                    dragCurrent = value.location
                    isPanning = isOptionPressed
                    panStartCenterX = centerX
                    panStartCenterY = centerY

                    // A pan changes the viewport continuously, so record its starting
                    // position exactly once when the drag begins.
                    if isPanning {
                        navigationStarted()
                    }
                }

                guard let start = dragStart else { return }

                if isPanning {
                    NSCursor.closedHand.set()
                    panView(from: start, to: value.location, viewSize: viewSize)
                } else {
                    // Update on every event; this keeps the frame live even while an
                    // underlying refinement view publishes a completed image.
                    dragCurrent = value.location
                    NSCursor.crosshair.set()
                }
            }
            .onEnded { value in
                defer { resetDragState() }

                guard let start = dragStart else { return }

                if isPanning {
                    finishInteractionPreview()
                    return
                }

                let rect = makeRect(from: start, to: value.location)
                guard rect.width > 10, rect.height > 10 else {
                    finishInteractionPreview()
                    return
                }

                // Selection zoom is a single completed navigation step. At this point
                // center/scale already describe the frame shown beneath the selection.
                navigationStarted()
                zoomToSelection(rect: rect, viewSize: viewSize)
                finishInteractionPreview()
            }
    }

    private func beginInteractionPreview() {
        refineTask?.cancel()
        refineTask = nil

        // Freeze once per gesture. If a completed CPU frame is still on screen,
        // that frame is the only valid coordinate basis for the new gesture.
        if !isInteractionPreviewActive {
            highPrecisionRenderEpoch &+= 1

            if useHighPrecisionPreview {
                let visibleState = visibleHighPrecisionState ?? currentViewportState
                frozenHighPrecisionState = visibleState

                // A pending target may be newer than the picture on screen. Discard that
                // invisible target so the rectangle maps exactly to what is visible.
                centerX = visibleState.centerX
                centerY = visibleState.centerY
                scale = visibleState.scale
            } else {
                frozenHighPrecisionState = nil
            }
        }

        isInteractionPreviewActive = true
    }

    private func finishInteractionPreview() {
        refineTask?.cancel()

        refineTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }

            // The final viewport becomes a new, single refinement request.
            isInteractionPreviewActive = false
            frozenHighPrecisionState = nil
            highPrecisionRenderEpoch &+= 1
            refineTask = nil
        }
    }

    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else {
            return nil
        }
        
        return makeRect(from: start, to: current)
    }
    
    private func resetDragState() {
        dragStart = nil
        dragCurrent = nil
        isPanning = false
        
        if isOptionPressed {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }
    
    private func makeRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
    
    private func panView(from start: CGPoint, to current: CGPoint, viewSize: CGSize) {
        let startViewport = FractalViewportTransform(
            centerX: panStartCenterX,
            centerY: panStartCenterY,
            scale: scale,
            viewSize: viewSize
        )
        let newCenter = startViewport.centerAfterPan(from: start, to: current)

        centerX = newCenter.x
        centerY = newCenter.y
        dragCurrent = current
    }
    
    private func zoomToSelection(rect: CGRect, viewSize: CGSize) {
        let oldScale = scale
        let viewport = FractalViewportTransform(
            centerX: centerX,
            centerY: centerY,
            scale: oldScale,
            viewSize: viewSize
        )
        let newCenter = viewport.complexPoint(at: CGPoint(x: rect.midX, y: rect.midY))

        let viewWidth = max(Double(viewSize.width), 1.0)
        let viewHeight = max(Double(viewSize.height), 1.0)
        let zoomFactorX = Double(rect.width) / viewWidth
        let zoomFactorY = Double(rect.height) / viewHeight
        let zoomFactor = max(zoomFactorX, zoomFactorY)
        
        centerX = newCenter.x
        centerY = newCenter.y
        scale = oldScale * zoomFactor
        increaseIterationsForZoom()
    }
    
    private func increaseIterationsForZoom() {
        if maxIterations < 500 {
            maxIterations += 400
        } else if maxIterations < 1000 {
            maxIterations += 700
        } else if maxIterations < 2500 {
            maxIterations += 1200
        } else if maxIterations < 5000 {
            maxIterations += 1500
        } else if maxIterations < 8000 {
            maxIterations += 2000
        } else {
            maxIterations += 3000
        }
        
        maxIterations = min(maxIterations, 24000)
    }
}

struct HighPrecisionFractalPreview: View {
    let fractalMode: FractalMode
    let fractalPalette: FractalPalette
    let centerX: Double
    let centerY: Double
    let scale: Double
    let maxIterations: Int
    let displayIterations: Int
    let viewSize: CGSize
    let viewportAspectRatio: Double
    /// Requests a fast CPU frame before the full CPU refinement. Both stages use
    /// Double precision and therefore cannot jump relative to one another.
    let progressiveCPUPreview: Bool
    let refinementEnabled: Bool
    let renderEpoch: UInt
    let renderQualityKey: String
    let onImagePublished: (HighPrecisionViewportState) -> Void
    let onThumbnailPublished: (Data?) -> Void
    
    @State private var image: NSImage?
    @State private var isRendering: Bool = false
    @State private var renderProgress: Double = 0.0
    @State private var renderStartDate: Date?
    
    private var renderID: String {
        [
            fractalMode.rawValue.description,
            fractalPalette.rawValue.description,
            String(format: "%.18f", centerX),
            String(format: "%.18f", centerY),
            String(format: "%.18f", scale),
            maxIterations.description,
            displayIterations.description,
            Int(viewSize.width).description,
            Int(viewSize.height).description,
            progressiveCPUPreview.description,
            refinementEnabled.description,
            renderEpoch.description,
            renderQualityKey,
            renderQualityKey
        ].joined(separator: "|")
    }
    
    private var clampedRenderProgress: Double {
        min(max(renderProgress, 0.0), 1.0)
    }

    private var renderPercentText: String {
        "\(Int((clampedRenderProgress * 100.0).rounded()))%"
    }

    private var renderIterationText: String {
        let current = Int(Double(displayIterations) * clampedRenderProgress)
        return "\(current.formatted()) / \(displayIterations.formatted())"
    }

    private func elapsedText(at date: Date) -> String {
        guard let renderStartDate else { return "00:00.0" }
        let elapsed = max(0, date.timeIntervalSince(renderStartDate))
        let minutes = Int(elapsed) / 60
        let seconds = elapsed.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%04.1f", minutes, seconds)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    // The pixels encode the full mathematical viewport. Stretching this
                    // capped bitmap to the SwiftUI bounds keeps its edges exactly aligned
                    // with Metal instead of cropping a fraction of a source pixel.
                    .frame(width: viewSize.width, height: viewSize.height)
                    .clipped()
            }
            
            if isRendering {
                TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.16), lineWidth: 14)

                            Circle()
                                .trim(from: 0, to: clampedRenderProgress)
                                .stroke(
                                    AngularGradient(
                                        colors: [
                                            .cyan,
                                            .blue,
                                            .cyan
                                        ],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 5) {
                                Text("Rendering…")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.82))

                                Text(renderPercentText)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text(renderIterationText)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))

                                Text("Iterations")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                        .frame(width: 158, height: 158)

                        Text("Elapsed: \(elapsedText(at: timeline.date))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(22)
                    .frame(width: 230)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 12)
                    .padding(.leading, 28)
                    .padding(.top, 72)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .task(id: renderID) {
            await renderPreview()
        }
    }
    
    @MainActor
    private func renderPreview() async {
        guard refinementEnabled else {
            isRendering = false
            return
        }

        let requestID = renderID
        let mode = fractalMode
        let palette = fractalPalette
        let cx = centerX
        let cy = centerY
        let currentScale = scale
        let fullIterations = maxIterations

        renderProgress = 0.01
        renderStartDate = Date()
        isRendering = true

        // At deep zoom, publish a small pyramid of CPU previews before the full
        // refinement. This avoids a single huge block preview followed by a long
        // wait, while keeping every stage mapped to the exact same viewport.
        if progressiveCPUPreview {
            let zoomLevel = fractalMode.defaultScale / max(scale, 1e-18)
            let previewStages: [(width: Int, height: Int, iterationScale: Double)]

            if zoomLevel > 1_000_000_000_000 {
                previewStages = [
                    (48, 30, 0.025),
                    (64, 40, 0.035),
                    (80, 50, 0.045),
                    (96, 60, 0.055),
                    (112, 70, 0.070),
                    (128, 80, 0.085),
                    (160, 100, 0.110),
                    (192, 120, 0.140),
                    (256, 160, 0.180),
                    (320, 200, 0.230),
                    (400, 250, 0.300),
                    (512, 320, 0.390),
                    (640, 400, 0.500),
                    (800, 500, 0.620),
                    (1024, 640, 0.760),
                    (deepCPUPreviewMaxPixelWidth, deepCPUPreviewMaxPixelHeight, 0.880)
                ]
            } else if zoomLevel > 200_000_000 {
                previewStages = [
                    (64, 40, 0.035),
                    (88, 55, 0.050),
                    (112, 70, 0.065),
                    (144, 90, 0.085),
                    (180, 113, 0.110),
                    (230, 144, 0.145),
                    (300, 188, 0.190),
                    (390, 244, 0.250),
                    (500, 313, 0.330),
                    (640, 400, 0.430),
                    (800, 500, 0.550),
                    (960, 600, 0.680),
                    (deepCPUPreviewMaxPixelWidth, deepCPUPreviewMaxPixelHeight, 0.820)
                ]
            } else if zoomLevel > 20_000_000 {
                previewStages = [
                    (64, 40, 0.04),
                    (96, 60, 0.06),
                    (128, 80, 0.08),
                    (160, 100, 0.10),
                    (220, 138, 0.14),
                    (300, 188, 0.20),
                    (400, 250, 0.28),
                    (540, 338, 0.38),
                    (720, 450, 0.52),
                    (900, 563, 0.66),
                    (deepCPUPreviewMaxPixelWidth, deepCPUPreviewMaxPixelHeight, 0.78)
                ]
            } else {
                previewStages = [
                    (96, 60, 0.06),
                    (160, 100, 0.10),
                    (240, 150, 0.16),
                    (360, 225, 0.24),
                    (540, 338, 0.36),
                    (720, 450, 0.50),
                    (deepCPUPreviewMaxPixelWidth, deepCPUPreviewMaxPixelHeight, 0.70)
                ]
            }

            for (stageIndex, stage) in previewStages.enumerated() {
                guard !Task.isCancelled,
                      refinementEnabled,
                      requestID == renderID else {
                    return
                }

                renderProgress = max(
                    renderProgress,
                    0.04 + 0.72 * (Double(stageIndex) / Double(max(previewStages.count, 1)))
                )

                let previewSize = cappedRenderSize(
                    for: viewSize,
                    maxWidth: stage.width,
                    maxHeight: stage.height
                )

                let previewIterations = max(
                    300,
                    min(
                        fullIterations,
                        min(
                            deepCPUPreviewIterationCap,
                            Int(Double(fullIterations) * stage.iterationScale)
                        )
                    )
                )

                if let quickImage = await renderImage(
                    width: previewSize.width,
                    height: previewSize.height,
                    mode: mode,
                    palette: palette,
                    centerX: cx,
                    centerY: cy,
                    scale: currentScale,
                    maxIterations: previewIterations,
                    requestID: requestID
                ) {
                    image = NSImage(
                        cgImage: quickImage,
                        size: NSSize(width: previewSize.width, height: previewSize.height)
                    )
                    onImagePublished(
                        HighPrecisionViewportState(
                            centerX: cx,
                            centerY: cy,
                            scale: currentScale,
                            iterations: previewIterations
                        )
                    )

                    renderProgress = max(
                        renderProgress,
                        0.04 + 0.72 * (Double(stageIndex + 1) / Double(max(previewStages.count, 1)))
                    )
                }
            }

            guard !Task.isCancelled,
                  refinementEnabled,
                  requestID == renderID else {
                return
            }
        }

        let fullSize = cappedRenderSize(
            for: viewSize,
            maxWidth: highPrecisionPreviewMaxPixelWidth,
            maxHeight: highPrecisionPreviewMaxPixelHeight
        )

        renderProgress = max(renderProgress, 0.82)

        if let finalImage = await renderImage(
            width: fullSize.width,
            height: fullSize.height,
            mode: mode,
            palette: palette,
            centerX: cx,
            centerY: cy,
            scale: currentScale,
            maxIterations: fullIterations,
            requestID: requestID,
            progressStart: 0.82,
            progressEnd: 0.995
        ) {
            image = NSImage(
                cgImage: finalImage,
                size: NSSize(width: fullSize.width, height: fullSize.height)
            )
            onImagePublished(
                HighPrecisionViewportState(
                    centerX: cx,
                    centerY: cy,
                    scale: currentScale,
                    iterations: fullIterations
                )
            )
            onThumbnailPublished(makeFavoriteThumbnailPNG(from: finalImage))

            renderProgress = 1.0
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { }
        }

        guard !Task.isCancelled,
              refinementEnabled,
              requestID == renderID else {
            return
        }

        isRendering = false
    }

    @MainActor
    private func renderImage(
        width: Int,
        height: Int,
        mode: FractalMode,
        palette: FractalPalette,
        centerX: Double,
        centerY: Double,
        scale: Double,
        maxIterations: Int,
        requestID: String,
        progressStart: Double? = nil,
        progressEnd: Double? = nil
    ) async -> CGImage? {
        guard width > 8, height > 8 else { return nil }

        let aspectRatio = viewportAspectRatio
        let worker = Task.detached(priority: .userInitiated) {
            renderFractal(
                width: width,
                height: height,
                mode: mode,
                palette: palette,
                centerX: centerX,
                centerY: centerY,
                scale: scale,
                maxIterations: maxIterations,
                viewportAspectRatio: aspectRatio,
                progressCallback: { progress in
                    guard let progressStart, let progressEnd else { return }
                    Task { @MainActor in
                        guard !Task.isCancelled, requestID == renderID else { return }
                        renderProgress = max(
                            renderProgress,
                            progressStart + (progressEnd - progressStart) * progress
                        )
                    }
                }
            )
        }

        let cgImage = await withTaskCancellationHandler(
            operation: { await worker.value },
            onCancel: { worker.cancel() }
        )

        guard !Task.isCancelled,
              refinementEnabled,
              requestID == renderID else {
            return nil
        }

        return cgImage
    }

    private func cappedRenderSize(
        for viewSize: CGSize,
        maxWidth: Int,
        maxHeight: Int
    ) -> (width: Int, height: Int) {
        let width = max(1.0, viewSize.width)
        let height = max(1.0, viewSize.height)
        let aspectRatio = width / height

        var targetWidth = min(Int(width.rounded()), maxWidth)
        var targetHeight = Int((Double(targetWidth) / aspectRatio).rounded())

        if targetHeight > maxHeight {
            targetHeight = maxHeight
            targetWidth = Int((Double(targetHeight) * aspectRatio).rounded())
        }

        return (
            max(16, targetWidth),
            max(16, targetHeight)
        )
    }
}

nonisolated func renderFractalSupersampled(
    width: Int,
    height: Int,
    supersampling: Int,
    mode: FractalMode,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double,
    maxIterations: Int
) -> CGImage? {
    let factor = max(1, min(supersampling, 3))
    
    guard factor > 1 else {
        return renderFractal(
            width: width,
            height: height,
            mode: mode,
            palette: palette,
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            maxIterations: maxIterations
        )
    }
    
    guard mode != .mandelbulb3D, mode != .mandelbox3D else {
        return renderFractal(
            width: width,
            height: height,
            mode: mode,
            palette: palette,
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            maxIterations: maxIterations
        )
    }
    
    let sampleWidth = width * factor
    let sampleHeight = height * factor
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8
    let aspectRatio = Double(width) / Double(height)
    
    var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
    let samplesPerPixel = Double(factor * factor)
    
    for py in 0..<height {
        for px in 0..<width {
            var r = 0.0
            var g = 0.0
            var b = 0.0
            
            for sy in 0..<factor {
                for sx in 0..<factor {
                    let sampleX = Double(px * factor + sx) + 0.5
                    let sampleY = Double(py * factor + sy) + 0.5
                    
                    let x0 = centerX + (sampleX / Double(sampleWidth) - 0.5) * scale * aspectRatio
                    let y0 = centerY + (sampleY / Double(sampleHeight) - 0.5) * scale
                    
                    let color: (r: Double, g: Double, b: Double)
                    
                    if mode == .newton {
                        color = calculateNewtonColor(
                            x0: x0,
                            y0: y0,
                            palette: palette,
                            maxIterations: maxIterations
                        )
                    } else {
                        let iteration = calculateFractalIteration(
                            mode: mode,
                            x0: x0,
                            y0: y0,
                            maxIterations: maxIterations
                        )
                        
                        if iteration == maxIterations {
                            color = insideColor(mode: mode, palette: palette)
                        } else {
                            let t = Double(iteration) / Double(maxIterations)
                            color = cpuPaletteColor(
                                t: t,
                                mode: mode,
                                palette: palette
                            )
                        }
                    }
                    
                    r += color.r
                    g += color.g
                    b += color.b
                }
            }
            
            let offset = (py * width + px) * bytesPerPixel
            pixels[offset + 0] = UInt8(clamp01(r / samplesPerPixel) * 255.0)
            pixels[offset + 1] = UInt8(clamp01(g / samplesPerPixel) * 255.0)
            pixels[offset + 2] = UInt8(clamp01(b / samplesPerPixel) * 255.0)
            pixels[offset + 3] = 255
        }
    }
    
    return makeCGImage(
        pixels: pixels,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        bitsPerComponent: bitsPerComponent,
        bytesPerPixel: bytesPerPixel
    )
}

nonisolated func renderFractal(
    width: Int,
    height: Int,
    mode: FractalMode,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double,
    maxIterations: Int,
    viewportAspectRatio: Double? = nil,
    progressCallback: ((Double) -> Void)? = nil
) -> CGImage? {
    
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8
    
    var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
    
    // The preview can be rendered at a capped bitmap size. Its mathematical
    // viewport must nevertheless retain the exact aspect ratio of the SwiftUI view.
    let aspectRatio = viewportAspectRatio ?? (Double(width) / Double(height))
    
    for py in 0..<height {
        // The high-precision worker is cancelled as soon as a new drag begins.
        if Task.isCancelled { return nil }

        if py.isMultiple(of: 8) {
            progressCallback?(Double(py) / Double(max(height - 1, 1)))
        }

        for px in 0..<width {
            if px.isMultiple(of: 64), Task.isCancelled { return nil }

            // Sample at the centre of the same raster pixel represented by Metal.
            // CGImage row 0 is the top edge, which corresponds to uv.y == 1 in
            // the fullscreen Metal triangle and therefore to the negative Y half-plane.
            let x0 = centerX + ((Double(px) + 0.5) / Double(width) - 0.5) * scale * aspectRatio
            let y0 = centerY + ((Double(py) + 0.5) / Double(height) - 0.5) * scale
            
            let color: (r: Double, g: Double, b: Double)
            
            if mode == .newton {
                color = calculateNewtonColor(
                    x0: x0,
                    y0: y0,
                    palette: palette,
                    maxIterations: maxIterations
                )
            } else {
                var localMaxIterations = maxIterations
                var iteration = calculateFractalIteration(
                    mode: mode,
                    x0: x0,
                    y0: y0,
                    maxIterations: localMaxIterations
                )

                if shouldApplyAdaptiveIterationRefinement(
                    mode: mode,
                    width: width,
                    maxIterations: maxIterations,
                    iteration: iteration
                ) {
                    localMaxIterations = min(maxIterations + maxIterations / 2, 120_000)
                    iteration = calculateFractalIteration(
                        mode: mode,
                        x0: x0,
                        y0: y0,
                        maxIterations: localMaxIterations
                    )
                }
                
                if iteration == localMaxIterations {
                    color = insideColor(mode: mode, palette: palette)
                } else {
                    let t = Double(iteration) / Double(localMaxIterations)
                    color = cpuPaletteColor(
                        t: t,
                        mode: mode,
                        palette: palette
                    )
                }
            }
            
            let offset = (py * width + px) * bytesPerPixel
            
            pixels[offset + 0] = UInt8(clamp01(color.r) * 255.0)
            pixels[offset + 1] = UInt8(clamp01(color.g) * 255.0)
            pixels[offset + 2] = UInt8(clamp01(color.b) * 255.0)
            pixels[offset + 3] = 255
        }
    }
    
    return makeCGImage(
        pixels: pixels,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        bitsPerComponent: bitsPerComponent,
        bytesPerPixel: bytesPerPixel
    )
}

nonisolated func renderMandelbulb3DImage(
    width: Int,
    height: Int,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double
) -> CGImage? {
    renderRaymarched3DImage(
        width: width,
        height: height,
        palette: palette,
        centerX: centerX,
        centerY: centerY,
        scale: scale,
        mode: .mandelbulb3D
    )
}

nonisolated func renderMandelbox3DImage(
    width: Int,
    height: Int,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double
) -> CGImage? {
    renderRaymarched3DImage(
        width: width,
        height: height,
        palette: palette,
        centerX: centerX,
        centerY: centerY,
        scale: scale,
        mode: .mandelbox3D
    )
}

nonisolated private func renderRaymarched3DImage(
    width: Int,
    height: Int,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double,
    mode: FractalMode
) -> CGImage? {
    
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8
    
    var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
    let aspectRatio = Double(width) / Double(height)
    
    for py in 0..<height {
        for px in 0..<width {
            let uvX = Double(px) / Double(width)
            let uvY = 1.0 - Double(py) / Double(height)
            
            let color = renderRaymarched3DPixel(
                uvX: uvX,
                uvY: uvY,
                aspectRatio: aspectRatio,
                palette: palette,
                centerX: centerX,
                centerY: centerY,
                scale: scale,
                mode: mode
            )
            
            let offset = (py * width + px) * bytesPerPixel
            
            pixels[offset + 0] = UInt8(clamp01(color.r) * 255.0)
            pixels[offset + 1] = UInt8(clamp01(color.g) * 255.0)
            pixels[offset + 2] = UInt8(clamp01(color.b) * 255.0)
            pixels[offset + 3] = 255
        }
    }
    
    return makeCGImage(
        pixels: pixels,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        bitsPerComponent: bitsPerComponent,
        bytesPerPixel: bytesPerPixel
    )
}

nonisolated private func renderRaymarched3DPixel(
    uvX: Double,
    uvY: Double,
    aspectRatio: Double,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double,
    mode: FractalMode
) -> (r: Double, g: Double, b: Double) {
    
    var px = (uvX - 0.5) * 2.0 * aspectRatio
    var py = (uvY - 0.5) * 2.0
    
    let zoom = scale / 2.8
    px *= zoom
    py *= zoom
    
    px += centerX
    py += centerY
    
    let rayOrigin = SIMD3<Double>(0.0, 0.0, -4.2)
    let rayDirection = simd_normalize(SIMD3<Double>(px, py, 1.65))
    
    var totalDistance = 0.0
    var hit = false
    var hitDistance = 0.0
    var hitPoint = SIMD3<Double>(0.0, 0.0, 0.0)
    
    for _ in 0..<120 {
        let position = rayOrigin + rayDirection * totalDistance
        
        let distance: Double
        if mode == .mandelbox3D {
            distance = mandelboxDistance(position)
        } else {
            distance = mandelbulbDistance(position)
        }
        
        if distance < 0.0012 {
            hit = true
            hitDistance = totalDistance
            hitPoint = position
            break
        }
        
        totalDistance += distance
        
        if totalDistance > 9.0 {
            break
        }
    }
    
    if !hit {
        let vignette = 1.0 - smoothstep(edge0: 0.2, edge1: 1.7, x: sqrt(px * px + py * py))
        let glow = exp(-0.35 * totalDistance)
        
        let background = paletteBaseColor(
            relief: 0.22 + 0.18 * glow,
            ridge: vignette,
            glow: glow,
            palette: palette
        )
        
        return (
            background.r * 0.28,
            background.g * 0.28,
            background.b * 0.28
        )
    }
    
    let normal: SIMD3<Double>
    if mode == .mandelbox3D {
        normal = mandelboxNormal(hitPoint)
    } else {
        normal = mandelbulbNormal(hitPoint)
    }
    
    let lightDir = simd_normalize(SIMD3<Double>(-0.45, 0.65, -0.8))
    let viewDir = simd_normalize(rayOrigin - hitPoint)
    let halfDir = simd_normalize(lightDir + viewDir)
    
    let diffuse = max(simd_dot(normal, lightDir), 0.0)
    let specular = pow(max(simd_dot(normal, halfDir), 0.0), 48.0)
    let rim = pow(1.0 - max(simd_dot(normal, viewDir), 0.0), 2.2)
    
    let depth = clamp01(hitDistance / 6.5)
    let ao = clamp(value: 1.0 - hitDistance * 0.08, minValue: 0.25, maxValue: 1.0)
    
    let stripe = 0.5 + 0.5 * sin(28.0 * hitPoint.y + 18.0 * hitPoint.x)
    
    var color = paletteBaseColor(
        relief: mode == .mandelbox3D ? 0.78 : 0.65,
        ridge: stripe,
        glow: 0.35,
        palette: palette
    )
    
    color.r *= 0.18 + 1.05 * diffuse
    color.g *= 0.18 + 1.05 * diffuse
    color.b *= 0.18 + 1.05 * diffuse
    
    color.r += 1.0 * specular * 0.85
    color.g += 0.75 * specular * 0.85
    color.b += 0.25 * specular * 0.85
    
    let rimColor = paletteBaseColor(
        relief: 0.9,
        ridge: 1.0,
        glow: 0.7,
        palette: palette
    )
    
    color.r += rimColor.r * rim * 0.45
    color.g += rimColor.g * rim * 0.45
    color.b += rimColor.b * rim * 0.45
    
    color.r *= ao
    color.g *= ao
    color.b *= ao
    
    color.r = mix(color.r, 0.01, depth * 0.35)
    color.g = mix(color.g, 0.02, depth * 0.35)
    color.b = mix(color.b, 0.08, depth * 0.35)
    
    return color
}

nonisolated private func mandelbulbDistance(_ point: SIMD3<Double>) -> Double {
    var z = point
    var dr = 1.0
    var r = 0.0
    let power = 8.0
    
    for _ in 0..<9 {
        r = simd_length(z)
        
        if r > 2.0 {
            break
        }
        
        let theta = acos(clamp(value: z.z / max(r, 0.000001), minValue: -1.0, maxValue: 1.0))
        let phi = atan2(z.y, z.x)
        
        dr = pow(r, power - 1.0) * power * dr + 1.0
        
        let zr = pow(r, power)
        let newTheta = theta * power
        let newPhi = phi * power
        
        z = zr * SIMD3<Double>(
            sin(newTheta) * cos(newPhi),
            sin(newPhi) * sin(newTheta),
            cos(newTheta)
        )
        
        z += point
    }
    
    return 0.5 * log(r) * r / dr
}

nonisolated private func mandelboxDistance(_ point: SIMD3<Double>) -> Double {
    var z = point
    let scaleFactor = 2.4
    var dr = 1.0
    
    let minRadius = 0.45
    let fixedRadius = 1.0
    
    for _ in 0..<12 {
        z.x = clamp(value: z.x, minValue: -1.0, maxValue: 1.0) * 2.0 - z.x
        z.y = clamp(value: z.y, minValue: -1.0, maxValue: 1.0) * 2.0 - z.y
        z.z = clamp(value: z.z, minValue: -1.0, maxValue: 1.0) * 2.0 - z.z
        
        let r2 = simd_length_squared(z)
        
        if r2 < minRadius * minRadius {
            let factor = fixedRadius * fixedRadius / (minRadius * minRadius)
            z *= factor
            dr *= factor
        } else if r2 < fixedRadius * fixedRadius {
            let factor = fixedRadius * fixedRadius / r2
            z *= factor
            dr *= factor
        }
        
        z = z * scaleFactor + point
        dr = dr * abs(scaleFactor) + 1.0
    }
    
    return simd_length(z) / abs(dr)
}

nonisolated private func mandelbulbNormal(_ point: SIMD3<Double>) -> SIMD3<Double> {
    estimateNormal(point) { mandelbulbDistance($0) }
}

nonisolated private func mandelboxNormal(_ point: SIMD3<Double>) -> SIMD3<Double> {
    estimateNormal(point) { mandelboxDistance($0) }
}

nonisolated private func estimateNormal(
    _ point: SIMD3<Double>,
    distance: (SIMD3<Double>) -> Double
) -> SIMD3<Double> {
    
    let epsilon = 0.0015
    
    let dx = distance(point + SIMD3<Double>(epsilon, 0.0, 0.0)) -
             distance(point - SIMD3<Double>(epsilon, 0.0, 0.0))
    
    let dy = distance(point + SIMD3<Double>(0.0, epsilon, 0.0)) -
             distance(point - SIMD3<Double>(0.0, epsilon, 0.0))
    
    let dz = distance(point + SIMD3<Double>(0.0, 0.0, epsilon)) -
             distance(point - SIMD3<Double>(0.0, 0.0, epsilon))
    
    return simd_normalize(SIMD3<Double>(dx, dy, dz))
}

nonisolated private func calculateNewtonColor(
    x0: Double,
    y0: Double,
    palette: FractalPalette,
    maxIterations: Int
) -> (r: Double, g: Double, b: Double) {
    
    // Newton Pop:
    // z^5 - 1 gives five attraction basins instead of three.
    // The root index drives strong local color zones; iteration count adds dark borders and glow.
    var z = SIMD2<Double>(x0, y0)
    let roots = [
        SIMD2<Double>( 1.0000000000,  0.0000000000),
        SIMD2<Double>( 0.3090169944,  0.9510565163),
        SIMD2<Double>(-0.8090169944,  0.5877852523),
        SIMD2<Double>(-0.8090169944, -0.5877852523),
        SIMD2<Double>( 0.3090169944, -0.9510565163)
    ]
    
    var iteration = 0
    
    while iteration < maxIterations {
        let z2 = complexMul(z, z)
        let z4 = complexMul(z2, z2)
        let z5 = complexMul(z4, z)
        
        let numerator = SIMD2<Double>(z5.x - 1.0, z5.y)
        let denominator = SIMD2<Double>(5.0 * z4.x, 5.0 * z4.y)
        let correction = complexDiv(numerator, denominator)
        z -= correction
        
        if simd_length(correction) < 0.000001 {
            break
        }
        
        if !z.x.isFinite || !z.y.isFinite {
            break
        }
        
        iteration += 1
    }
    
    var nearestRootIndex = 0
    var nearestDistance = Double.greatestFiniteMagnitude
    
    for index in 0..<roots.count {
        let distance = simd_length(z - roots[index])
        if distance < nearestDistance {
            nearestDistance = distance
            nearestRootIndex = index
        }
    }
    
    let t = clamp01(Double(iteration) / Double(maxIterations))
    let boundary = pow(clamp01(t * 4.2), 0.62)
    let convergence = pow(1.0 - t, 0.32)
    let rings = 0.5 + 0.5 * sin(Double(iteration) * 2.35 + Double(nearestRootIndex) * 1.70)
    let fine = 0.5 + 0.5 * sin(Double(iteration) * 6.10 + atan2(y0, x0) * 3.0)
    let angle = 0.5 + 0.5 * sin(7.0 * atan2(y0, x0) + Double(nearestRootIndex) * 2.1)
    
    let colors: [(Double, Double, Double)]
    
    switch palette {
    case .ocean:
        colors = [
            (0.00, 0.95, 1.00),
            (0.00, 0.30, 1.00),
            (0.00, 1.00, 0.58),
            (0.08, 0.05, 0.55),
            (0.78, 1.00, 0.12)
        ]
    case .electric:
        colors = [
            (0.00, 1.00, 1.00),
            (1.00, 0.00, 0.95),
            (0.15, 0.20, 1.00),
            (0.00, 1.00, 0.35),
            (1.00, 0.95, 0.00)
        ]
    case .fire:
        colors = [
            (1.00, 0.08, 0.00),
            (1.00, 0.62, 0.00),
            (1.00, 0.98, 0.08),
            (0.48, 0.02, 0.00),
            (1.00, 0.25, 0.02)
        ]
    case .ice:
        colors = [
            (0.86, 1.00, 1.00),
            (0.18, 0.62, 1.00),
            (0.56, 0.92, 1.00),
            (0.04, 0.10, 0.45),
            (1.00, 1.00, 0.92)
        ]
    case .gold:
        colors = [
            (1.00, 0.84, 0.05),
            (1.00, 0.34, 0.02),
            (0.74, 1.00, 0.05),
            (0.44, 0.16, 0.02),
            (1.00, 0.96, 0.62)
        ]
    case .violet:
        colors = [
            (0.96, 0.05, 1.00),
            (0.26, 0.10, 1.00),
            (1.00, 0.40, 0.76),
            (0.04, 0.02, 0.25),
            (1.00, 0.92, 0.18)
        ]
    case .deepBlue:
        colors = [
            (0.00, 0.92, 1.00),
            (0.02, 0.22, 1.00),
            (0.80, 1.00, 0.08),
            (0.00, 0.03, 0.22),
            (0.78, 0.92, 1.00)
        ]
    case .solarCoral:
        colors = [
            (1.00, 0.88, 0.12),
            (1.00, 0.22, 0.06),
            (1.00, 0.55, 0.05),
            (0.42, 0.18, 0.04),
            (1.00, 0.94, 0.68)
        ]
    case .infernoCoral:
        colors = [
            (1.00, 0.12, 0.02),
            (1.00, 0.50, 0.02),
            (1.00, 0.86, 0.08),
            (0.06, 0.01, 0.00),
            (0.70, 0.16, 0.05)
        ]
    case .solarPop:
        colors = [
            (1.00, 0.96, 0.02),
            (1.00, 0.08, 0.02),
            (1.00, 0.48, 0.02),
            (0.05, 0.035, 0.025),
            (1.00, 0.94, 0.68)
        ]
    }
    
    let base = colors[nearestRootIndex]
    let next = colors[(nearestRootIndex + 1) % colors.count]
    let mixAmount = 0.12 + 0.28 * pow(angle, 2.0) * boundary
    
    var r = base.0 + (next.0 - base.0) * mixAmount
    var g = base.1 + (next.1 - base.1) * mixAmount
    var b = base.2 + (next.2 - base.2) * mixAmount
    
    let bright = 0.40 + 0.92 * convergence + 0.35 * pow(rings, 5.0) * boundary
    r *= bright
    g *= bright
    b *= bright
    
    let ink = pow(boundary, 1.85) * (0.42 + 0.30 * (1.0 - fine))
    r *= (1.0 - ink)
    g *= (1.0 - ink)
    b *= (1.0 - ink)
    
    let goldEdge = pow(rings, 10.0) * boundary * 0.48
    let whiteSpark = pow(fine, 18.0) * boundary * 0.25
    
    return (
        clamp01(r + 0.95 * goldEdge + whiteSpark),
        clamp01(g + 0.74 * goldEdge + whiteSpark),
        clamp01(b + 0.18 * goldEdge + whiteSpark)
    )
}


nonisolated private func shouldApplyAdaptiveIterationRefinement(
    mode: FractalMode,
    width: Int,
    maxIterations: Int,
    iteration: Int
) -> Bool {
    guard mode == .mandelbrot || mode == .mandelbrotRelief || mode == .burningShip || mode == .tricorn else {
        return false
    }

    // Keep early previews fast. Adaptive refinement is mainly useful for final
    // high-precision CPU passes where boundary pixels otherwise blur into black.
    guard width >= 512, maxIterations >= 8_000 else {
        return false
    }

    // Only spend extra work near the escape boundary / near-inside regions.
    return iteration >= Int(Double(maxIterations) * 0.72)
}


nonisolated private func calculateFractalIteration(
    mode: FractalMode,
    x0: Double,
    y0: Double,
    maxIterations: Int
) -> Int {
    
    var x: Double
    var y: Double
    var cx: Double
    var cy: Double
    
    switch mode {
    case .mandelbrot, .mandelbrotRelief:
        x = 0.0
        y = 0.0
        cx = x0
        cy = y0
        
    case .julia:
        x = x0
        y = y0
        cx = -0.8
        cy = 0.156
        
    case .burningShip:
        x = 0.0
        y = 0.0
        cx = x0
        cy = y0
        
    case .tricorn:
        x = 0.0
        y = 0.0
        cx = x0
        cy = y0
        
    case .kleinian:
        x = x0
        y = y0
        cx = 0.0
        cy = 0.0
        
    case .mandelbulb3D, .mandelbox3D, .newton:
        x = 0.0
        y = 0.0
        cx = x0
        cy = y0
    }
    
    var iteration = 0
    
    while x * x + y * y <= 4.0 && iteration < maxIterations {
        switch mode {
        case .mandelbrot, .julia, .mandelbulb3D, .mandelbrotRelief, .mandelbox3D, .newton:
            let xtemp = x * x - y * y + cx
            y = 2.0 * x * y + cy
            x = xtemp
            
        case .burningShip:
            let ax = abs(x)
            let ay = abs(y)
            let xtemp = ax * ax - ay * ay + cx
            y = 2.0 * ax * ay + cy
            x = xtemp
            
        case .tricorn:
            let xtemp = x * x - y * y + cx
            y = -2.0 * x * y + cy
            x = xtemp
            
        case .kleinian:
            let r2 = x * x + y * y + 0.000001
            
            x = x / r2
            y = y / r2
            
            x = abs(x)
            y = abs(y)
            
            x = x - 1.0
            y = y - 0.5
            
            let angle = 0.45
            let cosA = cos(angle)
            let sinA = sin(angle)
            
            let rx = x * cosA - y * sinA
            let ry = x * sinA + y * cosA
            
            x = rx
            y = ry
        }
        
        iteration += 1
    }
    
    return iteration
}

nonisolated private func cpuPaletteColor(
    t: Double,
    mode: FractalMode,
    palette: FractalPalette
) -> (r: Double, g: Double, b: Double) {
    
    let k = sqrt(t)
    
    let relief: Double
    let ridge: Double
    let glow: Double
    
    if mode == .kleinian {
        relief = pow(k, 0.38)
        ridge = 0.5 + 0.5 * sin(70.0 * k)
        glow = exp(-8.0 * abs(k - 0.42))
    } else if mode == .mandelbrotRelief {
        relief = pow(k, 0.42)
        ridge = 0.5 + 0.5 * sin(55.0 * k)
        glow = exp(-7.0 * abs(k - 0.48))
    } else {
        relief = t
        ridge = 0.5 + 0.5 * sin(38.0 * k)
        glow = exp(-7.0 * abs(k - 0.45))
    }
    
    let base = paletteBaseColor(
        relief: relief,
        ridge: ridge,
        glow: glow,
        palette: palette
    )
    
    if mode == .kleinian || mode == .mandelbrotRelief {
        return (
            clamp01(base.r * 1.15),
            clamp01(base.g * 1.15),
            clamp01(base.b * 1.15)
        )
    }
    
    return base
}

nonisolated private func paletteBaseColor(
    relief: Double,
    ridge: Double,
    glow: Double,
    palette: FractalPalette
) -> (r: Double, g: Double, b: Double) {
    
    switch palette {
    case .ocean:
        return (
            clamp01(0.02 + 0.18 * relief + 0.18 * glow + 0.10 * ridge),
            clamp01(0.08 + 0.65 * relief + 0.28 * glow + 0.12 * ridge),
            clamp01(0.22 + 1.05 * relief + 0.30 * glow)
        )
        
    case .electric:
        return (
            clamp01(0.01 + 0.08 * relief + 0.16 * glow),
            clamp01(0.10 + 0.95 * relief + 0.40 * glow + 0.10 * ridge),
            clamp01(0.28 + 1.20 * relief + 0.25 * ridge)
        )
        
    case .fire:
        return (
            clamp01(0.20 + 1.20 * relief + 0.35 * glow),
            clamp01(0.04 + 0.45 * relief + 0.28 * glow + 0.18 * ridge),
            clamp01(0.01 + 0.08 * relief + 0.05 * glow)
        )
        
    case .ice:
        return (
            clamp01(0.16 + 0.62 * relief + 0.20 * glow),
            clamp01(0.32 + 0.95 * relief + 0.25 * ridge),
            clamp01(0.55 + 1.10 * relief + 0.20 * glow)
        )
        
    case .gold:
        return (
            clamp01(0.22 + 1.00 * relief + 0.35 * glow),
            clamp01(0.12 + 0.62 * relief + 0.20 * ridge),
            clamp01(0.02 + 0.18 * relief + 0.06 * glow)
        )
        
    case .violet:
        return (
            clamp01(0.12 + 0.75 * relief + 0.25 * glow),
            clamp01(0.02 + 0.18 * relief + 0.08 * ridge),
            clamp01(0.24 + 1.05 * relief + 0.35 * glow)
        )
        
    case .deepBlue:
        let yellowSpark = pow(glow, 1.35)
        let cyanEdge = pow(relief, 0.55)
        
        return (
            clamp01(0.00 + 0.05 * cyanEdge + 0.80 * yellowSpark + 0.10 * ridge),
            clamp01(0.04 + 0.70 * cyanEdge + 0.95 * yellowSpark + 0.20 * ridge),
            clamp01(0.18 + 1.05 * cyanEdge + 0.18 * yellowSpark + 0.18 * ridge)
        )
        
    case .solarCoral:
        let detail = pow(ridge, 0.72)
        let warmBody = pow(relief, 0.58)
        let hotGlow = pow(glow, 0.82)
        let darkFiligree = pow(1.0 - clamp01(relief + glow * 0.35), 2.8) * ridge
        
        return (
            clamp01(0.40 + 0.82 * warmBody + 0.60 * hotGlow + 0.42 * detail - 0.30 * darkFiligree),
            clamp01(0.28 + 0.78 * warmBody + 0.42 * hotGlow + 0.12 * detail - 0.36 * darkFiligree),
            clamp01(0.08 + 0.24 * warmBody + 0.05 * hotGlow + 0.04 * detail - 0.22 * darkFiligree)
        )
        
    case .infernoCoral:
        let detail = pow(ridge, 0.58)
        let warmBody = pow(relief, 0.52)
        let ember = pow(glow, 0.72)
        let darkFiligree = pow(1.0 - clamp01(relief * 0.8 + glow * 0.45), 2.2) * ridge
        
        return (
            clamp01(0.18 + 1.10 * warmBody + 0.92 * ember + 0.58 * detail - 0.40 * darkFiligree),
            clamp01(0.05 + 0.45 * warmBody + 0.36 * ember + 0.16 * detail - 0.32 * darkFiligree),
            clamp01(0.01 + 0.10 * warmBody + 0.04 * ember + 0.04 * detail - 0.20 * darkFiligree)
        )
        
    case .solarPop:
        // Solar Pop:
        // high-contrast lemon, ivory, coral-red and charcoal bands.
        // More colorful and stepped than Solar Coral.
        let detail = pow(ridge, 0.50)
        let body = pow(relief, 0.44)
        let light = pow(glow, 0.60)
        
        let rawPhase = 0.06 + 2.75 * relief + 4.15 * glow + 6.80 * ridge
        let phase = rawPhase - floor(rawPhase)
        let micro = 0.5 + 0.5 * cos(62.0 * ridge + 15.0 * glow - 9.0 * relief)
        
        let redBand = smoothstep(edge0: 0.08, edge1: 0.18, x: phase) * (1.0 - smoothstep(edge0: 0.30, edge1: 0.44, x: phase))
        let lemonBand = smoothstep(edge0: 0.28, edge1: 0.42, x: phase) * (1.0 - smoothstep(edge0: 0.56, edge1: 0.70, x: phase))
        let ivoryBand = smoothstep(edge0: 0.58, edge1: 0.72, x: phase) * (1.0 - smoothstep(edge0: 0.82, edge1: 0.96, x: phase))
        let darkBand = smoothstep(edge0: 0.80, edge1: 0.94, x: phase)
        
        let warmOrange = (1.00, 0.50, 0.02)
        let lemon = (1.00, 0.95, 0.04)
        let coralRed = (1.00, 0.08, 0.025)
        let ivory = (1.00, 0.94, 0.74)
        let charcoal = (0.050, 0.038, 0.030)
        
        var r = warmOrange.0
        var g = warmOrange.1
        var b = warmOrange.2
        
        r = r + (lemon.0 - r) * (0.78 * lemonBand)
        g = g + (lemon.1 - g) * (0.78 * lemonBand)
        b = b + (lemon.2 - b) * (0.78 * lemonBand)
        
        r = r + (coralRed.0 - r) * (0.70 * redBand)
        g = g + (coralRed.1 - g) * (0.70 * redBand)
        b = b + (coralRed.2 - b) * (0.70 * redBand)
        
        r = r + (ivory.0 - r) * (0.58 * ivoryBand * (0.35 + 0.65 * detail))
        g = g + (ivory.1 - g) * (0.58 * ivoryBand * (0.35 + 0.65 * detail))
        b = b + (ivory.2 - b) * (0.58 * ivoryBand * (0.35 + 0.65 * detail))
        
        r = r + (charcoal.0 - r) * (0.36 * darkBand * detail)
        g = g + (charcoal.1 - g) * (0.36 * darkBand * detail)
        b = b + (charcoal.2 - b) * (0.36 * darkBand * detail)
        
        let edgeSpark = pow(detail, 0.68) * (0.50 + 0.50 * micro)
        let lift = 0.56 + 0.72 * body + 0.44 * light
        
        return (
            clamp01(r * lift + 0.48 * edgeSpark + 0.38 * redBand * detail),
            clamp01(g * lift + 0.32 * edgeSpark + 0.04 * redBand * detail),
            clamp01(b * lift + 0.07 * edgeSpark + 0.02 * redBand * detail)
        )
    }
}

nonisolated private func insideColor(
    mode: FractalMode,
    palette: FractalPalette
) -> (r: Double, g: Double, b: Double) {
    
    if mode == .mandelbrot || mode == .mandelbrotRelief {
        return (0.0, 0.0, 0.0)
    }
    
    if mode == .kleinian {
        switch palette {
        case .ocean:
            return (0.02, 0.04, 0.11)
        case .electric:
            return (0.00, 0.03, 0.12)
        case .fire:
            return (0.08, 0.01, 0.00)
        case .ice:
            return (0.04, 0.08, 0.12)
        case .gold:
            return (0.08, 0.04, 0.00)
        case .violet:
            return (0.05, 0.00, 0.10)
        case .deepBlue:
            return (0.00, 0.01, 0.08)
        case .solarCoral:
            return (0.10, 0.055, 0.020)
        case .infernoCoral:
            return (0.075, 0.020, 0.010)
        case .solarPop:
            return (0.090, 0.040, 0.018)
        }
    }
    
    return (0.0, 0.0, 0.0)
}

nonisolated private func complexMul(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> SIMD2<Double> {
    SIMD2<Double>(
        a.x * b.x - a.y * b.y,
        a.x * b.y + a.y * b.x
    )
}

nonisolated private func complexDiv(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> SIMD2<Double> {
    let denominator = b.x * b.x + b.y * b.y + 0.000000001
    
    return SIMD2<Double>(
        (a.x * b.x + a.y * b.y) / denominator,
        (a.y * b.x - a.x * b.y) / denominator
    )
}

nonisolated private func formatMagnification(_ value: Double) -> String {
    if value < 1_000 {
        return "×\(String(format: "%.0f", value))"
    }
    
    if value < 1_000_000 {
        return "×\(String(format: "%.1f", value / 1_000.0))K"
    }
    
    if value < 1_000_000_000 {
        return "×\(String(format: "%.1f", value / 1_000_000.0))M"
    }
    
    if value < 1_000_000_000_000 {
        return "×\(String(format: "%.1f", value / 1_000_000_000.0))B"
    }
    
    return "×\(String(format: "%.2e", value))"
}

nonisolated private func makeCGImage(
    pixels: [UInt8],
    width: Int,
    height: Int,
    bytesPerRow: Int,
    bitsPerComponent: Int,
    bytesPerPixel: Int
) -> CGImage? {
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let data = Data(pixels)
    
    guard let provider = CGDataProvider(data: data as CFData) else {
        return nil
    }
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
    
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerComponent * bytesPerPixel,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
}

nonisolated private func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
    let t = clamp01((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)
}

nonisolated private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a * (1.0 - t) + b * t
}

nonisolated private func clamp(value: Double, minValue: Double, maxValue: Double) -> Double {
    min(maxValue, max(minValue, value))
}

nonisolated private func clamp01(_ value: Double) -> Double {
    min(1.0, max(0.0, value))
}
