// BeautyOfFractals
//
// ContentView.swift
//
// Main macOS user interface and render orchestration.
//
// This file owns the interactive fractal experience: navigation, controls,
// favorites, progressive rendering, render status, export, and coordination
// between the Metal preview and high-precision CPU rendering.
//
// Mathematical primitives and deep-zoom engines deliberately live in their
// own files so the UI layer can remain focused on interaction and state.
import SwiftUI
import Foundation
import Dispatch
import CoreGraphics
import AppKit
import UniformTypeIdentifiers
import simd
import Combine

private let highPrecisionScaleLimit: Double = 0.006

nonisolated private func perturbationCoverageRadiusPixels(
    scale: Double,
    viewportWidth: Int
) -> Double {
    let zoom = 3.0 / max(scale, 1e-30)

    switch zoom {
    case ..<1e8:
        return 256.0
    case ..<1e9:
        return 384.0
    case ..<1e11:
        return 640.0
    case ..<1e12:
        return 768.0
    case ..<1e14:
        return 896.0
    default:
        return 1024.0
    }
}


// Below this scale a Float-based Metal preview can no longer reliably represent
// the current viewport. Keep the last completed CPU image visible instead and
// refine the new viewport in two CPU stages using the same Double coordinates.
private let deepCPUPreviewScaleLimit: Double = 0.00001

private let highPrecisionPreviewMaxPixelWidth: Int = 1800
private let highPrecisionPreviewMaxPixelHeight: Int = 1200
private let deepCPUPreviewMaxPixelWidth: Int = 720
private let deepCPUPreviewMaxPixelHeight: Int = 480
private let deepCPUPreviewIterationCap: Int = 2_500

// The direct renderer is beneficial before the perturbation experiment's
// tighter threshold. This includes roughly 1.5 billion-times magnification
// for Mandelbrot's default scale of 3.0.
nonisolated private let directDeepMandelbrotScaleLimit: Double = 2e-9

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
    case eightRainbows = 9
    case celtic = 10

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
        case .eightRainbows:
            return "Eight Rainbows"
        case .celtic:
            return "Celtic Mandelbrot"
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
        case .eightRainbows:
            return "Rainbows"
        case .celtic:
            return "Celtic"
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
        case .eightRainbows:
            return "EightRainbows"
        case .celtic:
            return "CelticMandelbrot"
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
        case .eightRainbows:
            return 0.0
        case .celtic:
            return -0.5
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
        case .eightRainbows:
            return 0.0
        case .celtic:
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
        case .eightRainbows:
            return 3.0
        case .celtic:
            return 3.0
        }
    }

    var supportsHighPrecisionPreview: Bool {
        switch self {
        case .mandelbrot, .julia, .burningShip, .tricorn, .kleinian, .newton, .eightRainbows, .celtic:
            return true
        case .mandelbrotRelief, .mandelbulb3D, .mandelbox3D:
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
    case rainbows = 10
    case abyss = 11
    case deepCurrent = 12
    case auric = 13
    case aurora = 14

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
        case .rainbows:
            return "Rainbows"
        case .abyss:
            return "Abyss"
        case .deepCurrent:
            return "Deep Current"
        case .auric:
            return "Auric"
        case .aurora:
            return "Aurora"
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
        case .rainbows:
            return "Rainbows"
        case .abyss:
            return "Abyss"
        case .deepCurrent:
            return "DeepCurrent"
        case .auric:
            return "Auric"
        case .aurora:
            return "Aurora"
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


struct FavoriteSpot: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var modeRawValue: Int
    var paletteRawValue: Int
    var centerX: Double
    var centerY: Double
    var scale: Double

    /// Exact DoubleDouble viewport components. They are optional so favorites
    /// written by earlier versions remain fully readable.
    var centerXHi: Double? = nil
    var centerXLo: Double? = nil
    var centerYHi: Double? = nil
    var centerYLo: Double? = nil
    var scaleHi: Double? = nil
    var scaleLo: Double? = nil

    var iterations: Int
    var created: Date = Date()
    var updated: Date = Date()
    var deleted: Bool = false
    var schemaVersion: Int = 2
    var thumbnailPNG: Data? = nil
    var usageCount: Int = 0

    /// Restores the exact saved viewport where available. Older favorites
    /// gracefully fall back to their original Double coordinates.
    var storedPreciseViewport: PreciseViewport {
        guard
            let centerXHi,
            let centerXLo,
            let centerYHi,
            let centerYLo,
            let scaleHi,
            let scaleLo
        else {
            return PreciseViewport(
                centerX: centerX,
                centerY: centerY,
                scale: scale
            )
        }

        return PreciseViewport(
            centerX: DoubleDouble(hi: centerXHi, lo: centerXLo),
            centerY: DoubleDouble(hi: centerYHi, lo: centerYLo),
            scale: DoubleDouble(hi: scaleHi, lo: scaleLo)
        )
    }

    var mode: FractalMode {
        FractalMode(rawValue: modeRawValue) ?? .mandelbrot
    }

    var palette: FractalPalette {
        FractalPalette(rawValue: paletteRawValue) ?? .deepBlue
    }

    var zoomText: String {
        guard let scaleHi, let scaleLo else {
            return formatMagnification(mode.defaultScale / max(scale, 1e-18))
        }

        let preciseScale = scaleHi + scaleLo
        let scaleMagnitude = abs(preciseScale)

        guard scaleMagnitude.isFinite, scaleMagnitude > 0 else {
            return formatMagnification(mode.defaultScale / max(scale, 1e-18))
        }

        return formatCompactPreciseMagnification(mode.defaultScale / scaleMagnitude)
    }
}

nonisolated struct FavoriteSpotsCloudFile: Codable, Sendable {
    var schemaVersion: Int = 1
    var updated: Date = Date()
    var favorites: [FavoriteSpot]
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


    private var cloudFileURL: URL? {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.com.lutzrfrank.BeautyOfFractals"
        ) else {
            return nil
        }

        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        return documentsURL.appendingPathComponent("FavoriteSpotsCloud.json")
    }

    init() {
        load()
    }

    func spots(for mode: FractalMode) -> [FavoriteSpot] {
        spots.filter { $0.mode == mode && !$0.deleted }
            .sorted { $0.created > $1.created }
    }

    func add(_ spot: FavoriteSpot) {
        var newSpot = spot
        let now = Date()
        newSpot.created = now
        newSpot.updated = now
        newSpot.deleted = false
        newSpot.schemaVersion = 1
        spots.insert(newSpot, at: 0)
        save()
    }

    func delete(_ spot: FavoriteSpot) {
        guard let index = spots.firstIndex(where: { $0.id == spot.id }) else {
            return
        }

        spots[index].deleted = true
        spots[index].updated = Date()
        save()
    }

    func rename(_ spot: FavoriteSpot, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = spots.firstIndex(where: { $0.id == spot.id }) else {
            return
        }

        spots[index].name = trimmedName
        spots[index].updated = Date()
        save()
    }

    func incrementUsage(for spot: FavoriteSpot) {
        guard let index = spots.firstIndex(where: { $0.id == spot.id }) else {
            return
        }

        spots[index].usageCount += 1
        spots[index].updated = Date()
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

    func syncWithCloud() -> Bool {
        guard let cloudFileURL else {
            #if DEBUG
            print("☁️ Favorites iCloud: container unavailable")
            #endif
            return false
        }

        let localSnapshot = spots

        Task.detached(priority: .utility) {
            #if DEBUG
            print("☁️ Favorites iCloud file:", cloudFileURL.path)
            #endif

            try? FileManager.default.startDownloadingUbiquitousItem(at: cloudFileURL)

            let cloudSpots: [FavoriteSpot]
            let cloudReadSucceeded: Bool

            if let data = try? Data(contentsOf: cloudFileURL),
               let cloudFile = try? JSONDecoder().decode(FavoriteSpotsCloudFile.self, from: data) {
                cloudSpots = cloudFile.favorites
                cloudReadSucceeded = true
            } else {
                cloudSpots = []
                cloudReadSucceeded = false
            }

            if localSnapshot.isEmpty && cloudSpots.isEmpty && !cloudReadSucceeded {
                #if DEBUG
                print("☁️ Favorites iCloud skipped empty overwrite because cloud read failed")
                #endif
                return
            }

            var mergedByID: [UUID: FavoriteSpot] = [:]

            for spot in localSnapshot {
                mergedByID[spot.id] = spot
            }

            for cloudSpot in cloudSpots {
                if let localSpot = mergedByID[cloudSpot.id] {
                    mergedByID[cloudSpot.id] = cloudSpot.updated > localSpot.updated ? cloudSpot : localSpot
                } else {
                    mergedByID[cloudSpot.id] = cloudSpot
                }
            }

            let mergedSpots = Array(mergedByID.values)
                .sorted { $0.created > $1.created }

            await MainActor.run {
                self.spots = mergedSpots
                self.saveLocalOnly()
            }

            #if DEBUG
            print("☁️ Favorites iCloud merged", mergedSpots.count, "spots")
            #endif
        }

        return true
    }

    private func save() {
        saveLocalOnly()
        saveCloudOnly()
    }

    private func saveLocalOnly() {
        guard let data = try? JSONEncoder().encode(spots) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func saveCloudOnly() {
        guard let cloudFileURL else {
            return
        }

        let cloudFile = FavoriteSpotsCloudFile(
            schemaVersion: 1,
            updated: Date(),
            favorites: spots
        )

        guard let data = try? JSONEncoder().encode(cloudFile) else { return }
        do {
            try data.write(to: cloudFileURL, options: .atomic)
            print("☁️ Favorites iCloud wrote", spots.count, "spots to", cloudFileURL.path)
        } catch {
            print("☁️ Favorites iCloud write failed:", error)
        }
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


enum FloatingRenderPanel {
    case renderStatus
    case diagnostics
}

enum DeepRenderMethod: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case directDouble = "Direct"
    case perturbation = "Deep Reference"
    case doubleDouble = "Maximum Precision"

    var id: String { rawValue }
}

/// Selects the fastest safe deep-render path. Automatic starts with Direct
/// Double while adjacent screen pixels still map to distinct Double coordinates,
/// moves to Deep Reference near the Direct safety threshold, then uses Maximum
/// Precision when pixel spacing approaches the coordinate ULP more closely.
nonisolated private func automaticDeepRenderMethod(
    preciseViewport: PreciseViewport,
    viewportHeight: Int
) -> DeepRenderMethod {
    let pixelScale = abs(preciseViewport.scale.hi) / Double(max(viewportHeight, 1))
    let coordinateMagnitude = max(
        abs(preciseViewport.centerX.hi),
        abs(preciseViewport.centerY.hi),
        1.0
    )

    // Keep a margin above one ULP so Automatic switches before coordinate
    // rounding can become visible in a deep viewport.
    let maximumPrecisionResolution = coordinateMagnitude.ulp * 4.0
    let directSafetyMargin = 16.0
    let directResolution = coordinateMagnitude.ulp * directSafetyMargin

    if pixelScale <= maximumPrecisionResolution {
        return .doubleDouble
    } else if pixelScale <= directResolution {
        return .perturbation
    } else {
        return .directDouble
    }
}

/// Main macOS fractal explorer interface.
///
/// Coordinates UI state, navigation, render scheduling, favorites,
/// quality selection, export, and presentation of progressive render results.
struct ContentView: View {
    @State private var fractalMode: FractalMode = .mandelbrot
    @State private var fractalPalette: FractalPalette = .deepBlue
    @State private var renderQuality: RenderQuality = .high
    @State private var deepRenderMethod: DeepRenderMethod = .automatic
    @State private var showPerturbationStats: Bool = false
    @State private var lastPerturbationStatsText: String? = "No Deep Reference diagnostics captured yet.\nSelect Deep Reference for a deep Mandelbrot CPU render."
    @State private var perturbationStatsOffset: CGSize = .zero
    @State private var perturbationStatsDragStartOffset: CGSize = .zero

    @State private var centerX: Double = FractalMode.mandelbrot.defaultCenterX
    @State private var centerY: Double = FractalMode.mandelbrot.defaultCenterY
    @State private var scale: Double = FractalMode.mandelbrot.defaultScale
    @State private var preciseViewport = PreciseViewport(
        centerX: FractalMode.mandelbrot.defaultCenterX,
        centerY: FractalMode.mandelbrot.defaultCenterY,
        scale: FractalMode.mandelbrot.defaultScale
    )

    @State private var maxIterations: Int = 300
    @State private var isSavingSnapshot: Bool = false
    @State private var exportStartDate: Date?
    @State private var exportStatusText: String?
    @State private var showHelp: Bool = false
    @State private var showControls: Bool = true
    @State private var showFavoritesPanel: Bool = false
    @State private var favoriteName: String = ""
    @State private var isSyncingFavorites: Bool = false
    @State private var favoriteSort: FavoriteSort = .newest
    @State private var hoveredFavoriteSpot: FavoriteSpot?
    @State private var spotToRename: FavoriteSpot?
    @State private var renameFavoriteText: String = ""
    @StateObject private var favoritesStore = FavoritesStore()
    @State private var latestHighPrecisionThumbnailPNG: Data?
    @State private var navigationHistory: [ViewportSnapshot] = []
    @State private var navigationRevision: UInt = 0
    @State private var activeFloatingPanel: FloatingRenderPanel = .renderStatus

    private let maximumNavigationHistory = 100

    private struct ViewportSnapshot: Equatable {
        let centerX: Double
        let centerY: Double
        let scale: Double
        let preciseViewport: PreciseViewport
        let maxIterations: Int
    }

    private var preciseMagnificationFactor: Double? {
        let preciseScale = preciseViewport.scale.hi + preciseViewport.scale.lo
        let scaleMagnitude = abs(preciseScale)

        guard scaleMagnitude.isFinite, scaleMagnitude > 0 else {
            return nil
        }

        return fractalMode.defaultScale / scaleMagnitude
    }

    private var diagnosticsZoomText: String {
        guard let zoom = preciseMagnificationFactor else {
            return "Zoom exact: unavailable\nDepth: log10 unavailable"
        }

        return String(
            format: "Zoom exact: ×%.6e\nDepth: log10 %.4f",
            zoom,
            log10(zoom)
        )
    }

    private var preciseViewportDiagnosticsText: String {
        [
            diagnosticsZoomText,
            String(format: "X hi: %+.17e", preciseViewport.centerX.hi),
            String(format: "X lo: %+.17e", preciseViewport.centerX.lo),
            String(format: "Y hi: %+.17e", preciseViewport.centerY.hi),
            String(format: "Y lo: %+.17e", preciseViewport.centerY.lo),
            String(format: "S hi: %+.17e", preciseViewport.scale.hi),
            String(format: "S lo: %+.17e", preciseViewport.scale.lo)
        ].joined(separator: "\n")
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

    private var ultraExportUnavailableInDeepZoom: Bool {
        guard fractalMode == .mandelbrot else { return false }
        return automaticDeepRenderMethod(
            preciseViewport: preciseViewport,
            viewportHeight: 1600 * 2
        ) != .directDouble
    }

    private func exportElapsedText(since startDate: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(startDate))
        let minutes = Int(elapsed) / 60
        let seconds = elapsed.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%04.1f", minutes, seconds)
    }

    private func clearExportStatus() {
        exportStartDate = nil
        exportStatusText = nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MandelbrotView(
                fractalMode: fractalMode,
                fractalPalette: fractalPalette,
                centerX: $centerX,
                centerY: $centerY,
                scale: $scale,
                preciseViewport: $preciseViewport,
                maxIterations: $maxIterations,
                renderQuality: renderQuality,
                deepRenderMethod: deepRenderMethod,
                navigationStarted: recordNavigationStep,
                clearExportStatus: clearExportStatus,
                navigationRevision: navigationRevision,
                latestHighPrecisionThumbnailPNG: $latestHighPrecisionThumbnailPNG,
                exportStatusText: exportStatusText,
                showDiagnostics: showPerturbationStats,
                diagnosticsOffset: perturbationStatsOffset,
                activeFloatingPanel: $activeFloatingPanel,
                diagnosticsPanel: { AnyView(perturbationStatsPanel) },
                onPerturbationStatsPublished: { lastPerturbationStatsText = $0 }
            )
            .frame(minWidth: 760, minHeight: 650)
            .ignoresSafeArea()
            .overlay(alignment: .bottomTrailing) {
                if showFavoritesPanel {
                    favoritesPanel
                        // Align the lower edge with Render Diagnostics.
                        .padding(.trailing, 28)
                        .padding(.bottom, 34)
                        .offset(y: 40)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            if showControls {
                controlsOverlay
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showControls)
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleFractalControls)) { _ in
            showControls.toggle()
        }
        .focusedValue(\.fractalActions, FractalActions(
            snap: {
                saveSnapshot(width: 2560, height: 1600)
            },
            zoomIn: zoomIn,
            zoomOut: zoomOut,
            reset: resetView
        ))
        .alert("Rename Favorite", isPresented: Binding(
            get: { spotToRename != nil },
            set: { if !$0 { spotToRename = nil } }
        )) {
            TextField("Name", text: $renameFavoriteText)

            Button("Cancel", role: .cancel) {
                spotToRename = nil
                renameFavoriteText = ""
            }

            Button("Save") {
                if let spotToRename {
                    favoritesStore.rename(spotToRename, to: renameFavoriteText)
                }
                spotToRename = nil
                renameFavoriteText = ""
            }
        } message: {
            Text("Enter a new name for this favorite spot.")
        }
        .alert("Controls", isPresented: $showHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
Modes:
Explore Mandelbrot, Celtic Mandelbrot, Julia, Eight Rainbows, Burning Ship, Tricorn, Kleinian Relief, Mandelbrot Relief, Mandelbulb 3D, Mandelbox 3D and Newton Fractal.

Palettes:
Choose a palette from the Palette menu. Available palettes depend on the selected mode.
Julia supports Solar Pop and Rainbows. Eight Rainbows opens with the Rainbows palette.
Auric adds metallic gold with medallion-like Mandelbrot interiors, ornamental Julia spirals and polished Relief highlights.

Quality and iterations:
Choose Fast, High or Deep. Quality and zoom depth adjust the effective iteration budget shown below the controls.
Deep 2D locations use High Precision Preview automatically. At extreme zoom levels, CPU Deep Zoom progressively refines the image.

Navigation:
Drag to select an area and zoom in.
⌥ Option + Drag moves the view.
+ / − zoom in and out.
⌘R resets the current mode.
⌘⇧P shows or hides render status.

Favorites:
Use the star button to open Favorite Spots.
Saving a view preserves its mode, palette, location, zoom, iteration setting and thumbnail.

Export:
⌘S exports a 2560 × 1600 PNG.
Normal exports render at the selected size.
Ultra exports render internally at 2× resolution and downsample for cleaner detail.
Live preview is capped at 50,000 iterations; normal export at 80,000; Ultra export at 120,000.

The zoom overlay is visible only in the app and is not included in exports.
3D exports are CPU raymarched and may take longer.
""")
        }
    }

    private func displayDiagnosticsText(_ text: String) -> String {
        let isPerturbationDiagnostics = text.contains("Perturbation:")

        if isPerturbationDiagnostics {
            let renderPath = deepRenderMethod == .automatic
                ? "Automatic · Deep Reference"
                : "Deep Reference"

            return "\(renderPath)\n\n" + text
        }

        guard deepRenderMethod == .automatic else {
            return text
        }

        return text.replacingOccurrences(
            of: "Direct Double Refinement",
            with: "Automatic · Direct"
        )
    }

    private var perturbationStatsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Render Diagnostics", systemImage: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                Button {
                    showPerturbationStats = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Precise Viewport")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                Text(preciseViewportDiagnosticsText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.78))
                .textSelection(.enabled)
            }

            if let stats = lastPerturbationStatsText,
               let parsed = parsePerturbationStats(stats) {
                perturbationStatsContent(
                    ParsedPerturbationStats(
                        coverage: parsed.coverage,
                        stability: parsed.stability,
                        details: displayDiagnosticsText(parsed.details)
                    )
                )
            } else {
                Text(
                    displayDiagnosticsText(
                        lastPerturbationStatsText ?? "No render diagnostics available yet."
                    )
                )
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .textSelection(.enabled)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(width: 330, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 12)
        .simultaneousGesture(
            TapGesture().onEnded {
                activeFloatingPanel = .diagnostics
            }
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    activeFloatingPanel = .diagnostics
                    perturbationStatsOffset = CGSize(
                        width: perturbationStatsDragStartOffset.width + value.translation.width,
                        height: perturbationStatsDragStartOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    perturbationStatsDragStartOffset = perturbationStatsOffset
                }
        )
    }


    private struct ParsedPerturbationStats {
        let coverage: Double
        let stability: Double
        let details: String
    }

    private func parsePerturbationStats(_ text: String) -> ParsedPerturbationStats? {
        func value(after label: String) -> Double? {
            guard let line = text.split(separator: "\n").first(where: { $0.contains(label) }) else {
                return nil
            }
            guard let percentRange = line.range(of: "%") else { return nil }
            let beforePercent = line[..<percentRange.lowerBound]
            let number = beforePercent
                .split(separator: " ")
                .last
                .map(String.init)?
                .replacingOccurrences(of: ",", with: ".")
            return number.flatMap(Double.init)
        }

        guard let coverage = value(after: "Coverage"),
              let stability = value(after: "Stability") else {
            return nil
        }

        let detailLines = text
            .split(separator: "\n")
            .filter { !$0.contains("Coverage") && !$0.contains("Stability") }
            .joined(separator: "\n")

        return ParsedPerturbationStats(
            coverage: coverage,
            stability: stability,
            details: detailLines
        )
    }

    private func perturbationStatsContent(_ stats: ParsedPerturbationStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            perturbationMetricRow(title: "Coverage", value: stats.coverage)
            perturbationMetricRow(title: "Stability", value: stats.stability)

            Text(stats.details)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.78))
                .textSelection(.enabled)
        }
    }

    private func perturbationMetricRow(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.86))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.14))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * min(max(value / 100.0, 0.0), 1.0)
                        )
                }
            }
            .frame(height: 8)
        }
    }

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    Button {
                        undoView()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(navigationHistory.isEmpty)
                    .keyboardShortcut("z", modifiers: .command)
                    .help("Undo last zoom, pan or reset")

                    Button {
                        zoomOut()
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .keyboardShortcut("-", modifiers: [])
                    .help("Zoom Out")

                    Button {
                        zoomIn()
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .keyboardShortcut("+", modifiers: [])
                    .keyboardShortcut("=", modifiers: [])
                    .help("Zoom In")

                    Button {
                        resetView()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Reset View")

                    Spacer(minLength: 190)

                    Menu {
                        ForEach(RenderQuality.allCases) { quality in
                            Button {
                                clearExportStatus()
                                renderQuality = quality
                            } label: {
                                Text("\(renderQuality == quality ? "✓ " : "   ")\(quality.rawValue)")
                            }
                        }
                    } label: {
                        Image(systemName: "dial.medium")
                    }
                    .help("Quality: \(renderQuality.rawValue)")

                    Menu {
                        ForEach(DeepRenderMethod.allCases) { method in
                            Button {
                                deepRenderMethod = method
                                latestHighPrecisionThumbnailPNG = nil
                                lastPerturbationStatsText = nil
                                navigationRevision &+= 1
                            } label: {
                                Text("\(deepRenderMethod == method ? "◉" : "○")  \(method.rawValue)")
                            }
                            .disabled(fractalMode != .mandelbrot)
                        }

                        Divider()

                        Button("Show Diagnostics") {
                            showPerturbationStats = true
                        }
                    } label: {
                        Image(systemName: "waveform.path.ecg")
                    }
                    .help("Render diagnostics")

                    Button {
                        showFavoritesPanel.toggle()
                    } label: {
                        Image(systemName: showFavoritesPanel ? "star.fill" : "star")
                    }
                    .help("Favorite Spots")

                    Menu {
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

                        if ultraExportUnavailableInDeepZoom {
                            Text("Use normal export for deep zoom")
                        }

                        Button("Ultra Export 1440 × 900 PNG · 2×") {
                            saveSnapshot(width: 1440, height: 900, supersampling: 2)
                        }
                        .disabled(ultraExportUnavailableInDeepZoom)

                        Button("Ultra Export 2560 × 1600 PNG · 2×") {
                            saveSnapshot(width: 2560, height: 1600, supersampling: 2)
                        }
                        .disabled(ultraExportUnavailableInDeepZoom)
                    } label: {
                        Image(systemName: isSavingSnapshot ? "hourglass" : "square.and.arrow.up")
                    }
                    .disabled(isSavingSnapshot)
                    .help(isSavingSnapshot ? "Rendering…" : "Export")

                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .help("Show controls")
                }
                .font(.system(size: 17, weight: .semibold))
                .buttonStyle(.plain)

                HStack(spacing: 9) {
                    Image(systemName: "hurricane")
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)

                    Menu {
                        modeMenuButton(.mandelbrot)
                        modeMenuButton(.celtic)
                        modeMenuButton(.julia)
                        modeMenuButton(.eightRainbows)

                        Divider()

                        modeMenuButton(.burningShip)
                        modeMenuButton(.tricorn)
                        modeMenuButton(.kleinian)
                        modeMenuButton(.mandelbrotRelief)

                        Divider()

                        modeMenuButton(.mandelbulb3D)
                        modeMenuButton(.mandelbox3D)

                        Divider()

                        modeMenuButton(.newton)
                    } label: {
                        Text(fractalMode.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Choose fractal mode")
                }
            }
            .padding(.horizontal, 24)
            .frame(height: 64)

            Divider()
                .overlay(.white.opacity(0.12))
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Menu {
                    let availablePalettes: [FractalPalette] =
                        fractalMode == .julia
                        ? [.solarPop, .rainbows, .abyss, .deepCurrent, .auric]
                        : FractalPalette.allCases

                    ForEach(availablePalettes) { palette in
                        Button {
                            clearExportStatus()
                            fractalPalette = palette
                        } label: {
                            Text(
                                "\(fractalPalette == palette ? "✓ " : "   ")\(palette.displayName)"
                            )
                        }
                    }
                } label: {
                    Label(fractalPalette.displayName, systemImage: "paintpalette")
                        .frame(width: 154, alignment: .leading)
                }
                .help("Choose color palette")
                Spacer()

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
                            clearExportStatus()
                            maxIterations = Int(($0 / 100).rounded()) * 100
                        }
                    ),
                    in: 300...24000
                )
                .frame(width: 260)

                Stepper(
                    "",
                    value: Binding(
                        get: { maxIterations },
                        set: {
                            clearExportStatus()
                            maxIterations = $0
                        }
                    ),
                    in: 300...24000,
                    step: 100
                )
                .labelsHidden()

                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 48)
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .frame(maxWidth: 900)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.42), radius: 26, x: 0, y: 12)
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

                Button {
                    isSyncingFavorites = true
                    _ = favoritesStore.syncWithCloud()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        _ = favoritesStore.syncWithCloud()
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        _ = favoritesStore.syncWithCloud()
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        isSyncingFavorites = false
                    }
                } label: {
                    Image(systemName: isSyncingFavorites ? "icloud" : "icloud.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(isSyncingFavorites)
                .help(isSyncingFavorites ? "Syncing…" : "Sync with iCloud")
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
        .overlay(alignment: .leading) {
            if let hoveredFavoriteSpot {
                favoriteHoverPreview(hoveredFavoriteSpot)
                    .offset(x: -300, y: 86)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.16), value: hoveredFavoriteSpot?.id)
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



    private func favoriteHoverPreview(_ spot: FavoriteSpot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let thumbnailPNG = spot.thumbnailPNG,
               let thumbnail = NSImage(data: thumbnailPNG) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 260, height: 162)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.7))
                    )
                    .frame(width: 260, height: 162)
            }

            Text(spot.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)

            HStack {
                Text("Zoom \(spot.zoomText)")
                Spacer()
                Text("\(spot.iterations.formatted()) iterations")
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)

            if spot.usageCount > 0 {
                Text("Opened \(spot.usageCount)x")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 288)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 14)
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
                    spotToRename = spot
                    renameFavoriteText = spot.name
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Rename Favorite")

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
        .onHover { isHovering in
            hoveredFavoriteSpot = isHovering ? spot : nil
        }
        .contextMenu {
            Button("Load") {
                loadFavorite(spot)
            }

            Button("Rename") {
                spotToRename = spot
                renameFavoriteText = spot.name
            }

            Divider()

            Button("Delete", role: .destructive) {
                favoritesStore.delete(spot)
            }
        }
    }


    private func currentHighPrecisionThumbnailForFavorite() -> Data? {
        guard fractalMode.supportsHighPrecisionPreview else {
            return nil
        }

        return latestHighPrecisionThumbnailPNG
    }



    private func fallbackThumbnailForCurrentFavorite() -> Data? {
        switch fractalMode {
        case .mandelbrot, .celtic, .julia, .burningShip, .tricorn, .newton, .eightRainbows:
            return makeFavoriteThumbnailPNG(
                mode: fractalMode,
                palette: fractalPalette,
                centerX: centerX,
                centerY: centerY,
                scale: scale,
                iterations: maxIterations
            )
        case .kleinian, .mandelbulb3D, .mandelbrotRelief, .mandelbox3D:
            return nil
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
                centerXHi: preciseViewport.centerX.hi,
                centerXLo: preciseViewport.centerX.lo,
                centerYHi: preciseViewport.centerY.hi,
                centerYLo: preciseViewport.centerY.lo,
                scaleHi: preciseViewport.scale.hi,
                scaleLo: preciseViewport.scale.lo,
                iterations: maxIterations,
                thumbnailPNG: fractalMode == .mandelbrotRelief ? nil : (currentHighPrecisionThumbnailForFavorite() ?? fallbackThumbnailForCurrentFavorite())
            )
        )

        favoriteName = ""
    }

    private func loadFavorite(_ spot: FavoriteSpot) {
        recordNavigationStep()

        // A thumbnail belongs to the former viewport. Do not let it be reused
        // while the favorite's first exact CPU frame is being prepared.
        latestHighPrecisionThumbnailPNG = nil
        lastPerturbationStatsText = nil

        fractalMode = spot.mode
        fractalPalette = spot.palette
        applyPreciseViewport(spot.storedPreciseViewport)
        maxIterations = spot.iterations
        navigationRevision &+= 1
        favoritesStore.incrementUsage(for: spot)
    }


    private func applyPreciseViewport(_ viewport: PreciseViewport) {
        clearExportStatus()
        preciseViewport = viewport

        let projection = viewport.doubleProjection
        centerX = projection.centerX
        centerY = projection.centerY
        scale = projection.scale
    }

    private func currentViewportSnapshot() -> ViewportSnapshot {
        ViewportSnapshot(
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            preciseViewport: preciseViewport,
            maxIterations: maxIterations
        )
    }

    private func recordNavigationStep() {
        clearExportStatus()

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
        applyPreciseViewport(previous.preciseViewport)
        maxIterations = previous.maxIterations
    }

    private func modeMenuButton(_ mode: FractalMode) -> some View {
        Button {
            setMode(mode)
        } label: {
            Text("\(fractalMode == mode ? "✓ " : "   ")\(mode.displayName)")
        }
    }

    private func setMode(_ mode: FractalMode) {
        switch mode {
        case .julia, .newton:
            fractalPalette = .solarPop

        case .mandelbrot, .tricorn, .celtic:
            fractalPalette = .deepBlue

        case .eightRainbows:
            fractalPalette = .rainbows

        default:
            break
        }

        fractalMode = mode

        applyPreciseViewport(
            PreciseViewport(
                centerX: mode.defaultCenterX,
                centerY: mode.defaultCenterY,
                scale: mode.defaultScale
            )
        )
        maxIterations = 300
        navigationHistory.removeAll()
        navigationRevision &+= 1
    }

    private func zoomIn() {
        recordNavigationStep()
        navigationRevision &+= 1
        applyPreciseViewport(preciseViewport.zoomed(by: 0.5))
        increaseIterationsForZoom()
    }

    private func zoomOut() {
        recordNavigationStep()
        navigationRevision &+= 1
        applyPreciseViewport(preciseViewport.zoomed(by: 2.0))
        decreaseIterationsForZoom()
    }

    private func resetView() {
        recordNavigationStep()
        navigationRevision &+= 1
        applyPreciseViewport(
            PreciseViewport(
                centerX: fractalMode.defaultCenterX,
                centerY: fractalMode.defaultCenterY,
                scale: fractalMode.defaultScale
            )
        )
        maxIterations = 300
    }

    private func increaseIterationsForZoom() {
        if maxIterations < 2_500 {
            maxIterations += 400
        } else if maxIterations < 10_000 {
            maxIterations += 600
        } else {
            maxIterations += 800
        }

        maxIterations = min(maxIterations, 24_000)
    }

    private func decreaseIterationsForZoom() {
        if maxIterations > 10_000 {
            maxIterations -= 400
        } else if maxIterations > 2_500 {
            maxIterations -= 300
        } else {
            maxIterations -= 200
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
        let snapshotPreciseViewport = preciseViewport
        let snapshotSupersampling = max(1, min(supersampling, 2))
        let snapshotIterations = snapshotSupersampling > 1 ? ultraExportEffectiveIterations : exportEffectiveIterations
        let snapshotExportSuffix = snapshotSupersampling > 1 ? "-Ultra\(snapshotSupersampling)x" : ""
        let snapshotDeepRenderMethod = snapshotSupersampling == 1
            ? automaticDeepRenderMethod(
                preciseViewport: snapshotPreciseViewport,
                viewportHeight: exportHeight
            )
            : .directDouble

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue =
            "BeautyOfFractals-\(snapshotMode.fileName)-\(snapshotPalette.fileName)-\(snapshotIterations)-iterations\(snapshotExportSuffix)-\(exportWidth)x\(exportHeight).png"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            isSavingSnapshot = true
            exportStartDate = Date()
            exportStatusText = nil

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
                        preciseViewport: snapshotPreciseViewport,
                        maxIterations: snapshotIterations,
                        perturbationEnabled: snapshotDeepRenderMethod == .perturbation,
                        doubleDoubleEnabled: snapshotDeepRenderMethod == .doubleDouble
                    )
                }

                guard let finalImage = cgImage else {
                    await MainActor.run {
                        isSavingSnapshot = false
                        exportStartDate = nil
                        exportStatusText = "failed"
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
                        exportStartDate = nil
                        exportStatusText = "failed"
                    }
                    return
                }

                let exportSucceeded: Bool
                do {
                    try pngData.write(to: url)
                    exportSucceeded = true
                } catch {
                    print("Snapshot konnte nicht gespeichert werden:", error)
                    exportSucceeded = false
                }

                await MainActor.run {
                    if exportSucceeded, let exportStartDate {
                        exportStatusText = exportElapsedText(since: exportStartDate)
                    } else {
                        exportStatusText = "failed"
                    }
                    exportStartDate = nil
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
    let preciseViewport: PreciseViewport
    let iterations: Int
    let thumbnailPNG: Data? = nil
}


struct MandelbrotView: View {
    let fractalMode: FractalMode
    let fractalPalette: FractalPalette

    @Binding var centerX: Double
    @Binding var centerY: Double
    @Binding var scale: Double
    @Binding var preciseViewport: PreciseViewport
    @Binding var maxIterations: Int
    let renderQuality: RenderQuality
    let deepRenderMethod: DeepRenderMethod
    let navigationStarted: () -> Void
    let clearExportStatus: () -> Void
    let navigationRevision: UInt
    @Binding var latestHighPrecisionThumbnailPNG: Data?
    let exportStatusText: String?
    let showDiagnostics: Bool
    let diagnosticsOffset: CGSize
    @Binding var activeFloatingPanel: FloatingRenderPanel
    let diagnosticsPanel: () -> AnyView
    let onPerturbationStatsPublished: (String?) -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    @State private var isOptionPressed: Bool = false
    @State private var isPanning: Bool = false
    @State private var panStartPreciseViewport: PreciseViewport?

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

    private var preciseMagnificationFactor: Double? {
        let preciseScale = preciseViewport.scale.hi + preciseViewport.scale.lo
        let scaleMagnitude = abs(preciseScale)

        guard scaleMagnitude.isFinite, scaleMagnitude > 0 else {
            return nil
        }

        return fractalMode.defaultScale / scaleMagnitude
    }

    private var magnificationText: String {
        formatMagnification(magnificationFactor)
    }

    private var preciseMagnificationText: String {
        guard let preciseMagnificationFactor else {
            return magnificationText
        }

        return formatCompactPreciseMagnification(preciseMagnificationFactor)
    }

    private var precisionStatusText: String? {
        if !fractalMode.supportsHighPrecisionPreview {
            return nil
        }

        if useDeepCPUPreview {
            // Deep Reference, Direct and Maximum Precision currently apply
            // only to Mandelbrot's dedicated perturbation / Double-Double paths.
            guard fractalMode == .mandelbrot else {
                return "High Precision · CPU Deep Zoom"
            }

            switch deepRenderMethod {
            case .automatic:
                return "High Precision · CPU Deep Zoom · Automatic"

            case .perturbation:
                return "High Precision · CPU Deep Zoom · Deep Reference"

            case .doubleDouble:
                return "High Precision · CPU Deep Zoom · Maximum Precision"

            case .directDouble:
                return "High Precision · CPU Deep Zoom · Direct"
            }
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
        // z⁸ + c escapes very quickly for most pixels. Keeping its full
        // iteration budget makes the Rainbows palette visually stable while
        // a selection is dragged, instead of shifting its spectral phase on release.
        if fractalMode == .eightRainbows {
            return effectiveIterations
        }

        return max(300, min(effectiveIterations, Int(Double(effectiveIterations) * 0.25)))
    }

    private var metalDisplayedIterations: Int {
        isInteractionPreviewActive ? interactionPreviewIterations : effectiveIterations
    }

    private var currentViewportState: HighPrecisionViewportState {
        HighPrecisionViewportState(
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            preciseViewport: preciseViewport,
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
                            preciseViewport: state.preciseViewport,
                            maxIterations: state.iterations,
                            displayIterations: effectiveIterations,
                            viewSize: geometry.size,
                            viewportAspectRatio: viewportAspectRatio,
                            progressiveCPUPreview: useDeepCPUPreview,
                            refinementEnabled: !isInteractionPreviewActive,
                            renderEpoch: highPrecisionRenderEpoch,
                            renderRevision: navigationRevision,
                            renderQualityKey: renderQuality.rawValue,
                            deepRenderMethod: deepRenderMethod,
                            exportStatusText: exportStatusText,
                            clearExportStatus: clearExportStatus,
                            showDiagnostics: showDiagnostics,
                            diagnosticsOffset: diagnosticsOffset,
                            activeFloatingPanel: $activeFloatingPanel,
                            diagnosticsPanel: diagnosticsPanel,
                            onImagePublished: { visibleState in
                                // Navigation must be calculated against the frame the user
                                // can actually see, not against a newer frame still rendering.
                                visibleHighPrecisionState = visibleState
                            },
                            onThumbnailPublished: { thumbnailPNG in
                                latestHighPrecisionThumbnailPNG = thumbnailPNG
                            },
                            onPerturbationStatsPublished: onPerturbationStatsPublished
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
                    Text("Zoom \(preciseMagnificationText)")
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
                    panStartPreciseViewport = preciseViewport

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
                applyPreciseViewport(visibleState.preciseViewport)
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
        panStartPreciseViewport = nil

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

    private func applyPreciseViewport(_ viewport: PreciseViewport) {
        clearExportStatus()
        preciseViewport = viewport

        let projection = viewport.doubleProjection
        centerX = projection.centerX
        centerY = projection.centerY
        scale = projection.scale
    }

    private func panView(from start: CGPoint, to current: CGPoint, viewSize: CGSize) {
        guard let startViewport = panStartPreciseViewport else {
            return
        }

        let width = max(Double(viewSize.width), 1.0)
        let height = max(Double(viewSize.height), 1.0)
        let horizontalFraction = Double(current.x - start.x) / width
        let verticalFraction = Double(current.y - start.y) / height
        let aspectRatio = width / height

        applyPreciseViewport(
            startViewport.panned(
                horizontalFraction: horizontalFraction,
                verticalFraction: verticalFraction,
                aspectRatio: aspectRatio
            )
        )

        dragCurrent = current
    }

    private func zoomToSelection(rect: CGRect, viewSize: CGSize) {
        let viewWidth = max(Double(viewSize.width), 1.0)
        let viewHeight = max(Double(viewSize.height), 1.0)
        let aspectRatio = viewWidth / viewHeight
        let zoomFactorX = Double(rect.width) / viewWidth
        let zoomFactorY = Double(rect.height) / viewHeight
        let zoomFactor = max(zoomFactorX, zoomFactorY)

        applyPreciseViewport(
            preciseViewport.zoomed(
                toHorizontalFraction: Double(rect.midX) / viewWidth,
                verticalFraction: Double(rect.midY) / viewHeight,
                aspectRatio: aspectRatio,
                zoomFactor: zoomFactor
            )
        )

        increaseIterationsForZoom()
    }

    private func increaseIterationsForZoom() {
        if maxIterations < 2_500 {
            maxIterations += 400
        } else if maxIterations < 10_000 {
            maxIterations += 600
        } else {
            maxIterations += 800
        }

        maxIterations = min(maxIterations, 24_000)
    }
}

struct HighPrecisionFractalPreview: View {
    let fractalMode: FractalMode
    let fractalPalette: FractalPalette
    let centerX: Double
    let centerY: Double
    let scale: Double
    let preciseViewport: PreciseViewport
    let maxIterations: Int
    let displayIterations: Int
    let viewSize: CGSize
    let viewportAspectRatio: Double
    /// Requests a fast CPU frame before the full CPU refinement. Both stages use
    /// Double precision and therefore cannot jump relative to one another.
    let progressiveCPUPreview: Bool
    let refinementEnabled: Bool
    let renderEpoch: UInt
    /// Explicit external-navigation identity. This ensures Favorites, Reset,
    /// Undo and toolbar navigation always start a fresh CPU render request.
    let renderRevision: UInt
    let renderQualityKey: String
    let deepRenderMethod: DeepRenderMethod
    let exportStatusText: String?
    let clearExportStatus: () -> Void
    let showDiagnostics: Bool
    let diagnosticsOffset: CGSize
    @Binding var activeFloatingPanel: FloatingRenderPanel
    let diagnosticsPanel: () -> AnyView
    let onImagePublished: (HighPrecisionViewportState) -> Void
    let onThumbnailPublished: (Data?) -> Void
    let onPerturbationStatsPublished: (String?) -> Void

    @State private var image: NSImage?
    @State private var isRendering: Bool = false
    @State private var renderProgress: Double = 0.0
    @State private var completedRenderIterations: Int?
    @State private var showRenderStatus: Bool = false
    @State private var renderStartDate: Date?
    @State private var lastRenderDurationText: String?
    @State private var renderStatusOffset: CGSize = .zero
    @State private var renderStatusDragStartOffset: CGSize = .zero

    private var renderID: String {
        [
            fractalMode.rawValue.description,
            fractalPalette.rawValue.description,
            String(format: "%.18f", centerX),
            String(format: "%.18f", centerY),
            String(format: "%.18f", scale),
            String(preciseViewport.centerX.hi.bitPattern, radix: 16),
            String(preciseViewport.centerX.lo.bitPattern, radix: 16),
            String(preciseViewport.centerY.hi.bitPattern, radix: 16),
            String(preciseViewport.centerY.lo.bitPattern, radix: 16),
            String(preciseViewport.scale.hi.bitPattern, radix: 16),
            String(preciseViewport.scale.lo.bitPattern, radix: 16),
            maxIterations.description,
            displayIterations.description,
            Int(viewSize.width).description,
            Int(viewSize.height).description,
            progressiveCPUPreview.description,
            refinementEnabled.description,
            renderEpoch.description,
            renderRevision.description,
            renderQualityKey,
            deepRenderMethod.rawValue,
            effectiveDeepRenderMethod.rawValue
        ].joined(separator: "|")
    }

    private var effectiveDeepRenderMethod: DeepRenderMethod {
        guard deepRenderMethod == .automatic else {
            return deepRenderMethod
        }

        return automaticDeepRenderMethod(
            preciseViewport: preciseViewport,
            viewportHeight: max(Int(viewSize.height.rounded()), 1)
        )
    }

    private var clampedRenderProgress: Double {
        min(max(renderProgress, 0.0), 1.0)
    }

    private var renderPercentText: String {
        "\(Int((clampedRenderProgress * 100.0).rounded()))%"
    }

    private var renderIterationText: String {
        if !isRendering, let completedRenderIterations {
            return "\(completedRenderIterations.formatted()) / \(displayIterations.formatted())"
        }

        let current = Int(Double(displayIterations) * clampedRenderProgress)
        return "\(current.formatted()) / \(displayIterations.formatted())"
    }

    private var renderIterationCaption: String {
        guard fractalMode == .celtic,
              !isRendering,
              let completedRenderIterations,
              completedRenderIterations < displayIterations else {
            return "Iterations"
        }

        return "Atmospheric Finish"
    }

    private func elapsedText(at date: Date) -> String {
        guard let renderStartDate else { return "00:00.0" }
        let elapsed = max(0, date.timeIntervalSince(renderStartDate))
        let minutes = Int(elapsed) / 60
        let seconds = elapsed.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%04.1f", minutes, seconds)
    }

    private func toggleRenderStatusPin() {
        if showRenderStatus {
            showRenderStatus = false
            if exportStatusText != nil {
                clearExportStatus()
            }
        } else {
            showRenderStatus = true
        }
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

            if showDiagnostics {
                diagnosticsPanel()
                    // Align the default diagnostics position with the controls
                    // container while keeping the panel freely draggable.
                    .padding(.leading, 90)
                    .padding(.bottom, 154)
                    .offset(diagnosticsOffset)
                    .zIndex(
                        activeFloatingPanel == .diagnostics ? 2 : 1
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottomLeading
                    )
            }

            if isRendering || showRenderStatus || exportStatusText != nil {
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
                                Text(isRendering ? "Rendering…" : (exportStatusText == nil ? "Render Status" : (exportStatusText == "failed" ? "Export failed" : "Export ready")))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.82))

                                Text(isRendering || exportStatusText == nil ? renderPercentText : "Done")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text(renderIterationText)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))

                                Text(renderIterationCaption)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                        .frame(width: 158, height: 158)

                        VStack(spacing: 2) {
                            Text(isRendering ? "Elapsed: \(elapsedText(at: timeline.date))" : (exportStatusText == nil ? "Ready" : (exportStatusText == "failed" ? "Export failed" : "Export finished")))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))

                            if !isRendering, let exportStatusText, exportStatusText != "failed" {
                                Text("Time: \(exportStatusText)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.58))
                            } else if !isRendering, let lastRenderDurationText, exportStatusText == nil {
                                Text("Time: \(lastRenderDurationText)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                        }
                    }
                    .padding(22)
                    .frame(width: 230)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            toggleRenderStatusPin()
                        } label: {
                            Image(systemName: showRenderStatus ? "pin.fill" : "pin")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(showRenderStatus ? 0.9 : 0.45))
                                .padding(10)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Render Status")
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 12)
                    .contentShape(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            activeFloatingPanel = .renderStatus
                        }
                    )
                    .padding(.leading, 28)
                    .padding(.top, 72)
                    .offset(renderStatusOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                activeFloatingPanel = .renderStatus
                                renderStatusOffset = CGSize(
                                    width: renderStatusDragStartOffset.width + value.translation.width,
                                    height: renderStatusDragStartOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                renderStatusDragStartOffset = renderStatusOffset
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .zIndex(
                    activeFloatingPanel == .renderStatus ? 2 : 1
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRenderStatus)) { _ in
            toggleRenderStatusPin()
        }
        .task(id: exportStatusText) {
            guard exportStatusText != nil else { return }

            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled, !showRenderStatus, !isRendering else {
                return
            }

            clearExportStatus()
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
        let precise = preciseViewport
        let fullIterations = maxIterations

        // Normally the final full-resolution frame uses all requested
        // iterations. During progressive deep rendering it adopts the exact
        // iteration count of the last preview stage instead, preserving the
        // atmospheric colour state seen immediately before final refinement.
        var finalRenderIterations = fullIterations

        renderProgress = 0.01
        completedRenderIterations = nil
        renderStartDate = Date()
        lastRenderDurationText = nil
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

            // Celtic benefits visually from retaining the atmospheric final
            // preview stage with the expressive palettes. Deep Blue and all
            // other modes continue to their full requested iteration target.
            let usesAtmosphericFinish =
                mode == .celtic
                && (palette == .rainbows || palette == .solarPop)

            if usesAtmosphericFinish, let lastPreviewStage = previewStages.last {
                finalRenderIterations = max(
                    300,
                    min(
                        fullIterations,
                        min(
                            deepCPUPreviewIterationCap,
                            Int(
                                Double(fullIterations)
                                    * lastPreviewStage.iterationScale
                            )
                        )
                    )
                )
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
                    preciseViewport: precise,
                    maxIterations: previewIterations,
                    requestID: requestID,
                    perturbationEnabled: effectiveDeepRenderMethod == .perturbation,
                    doubleDoubleEnabled: false,
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
                            preciseViewport: precise,
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
            preciseViewport: precise,
            maxIterations: finalRenderIterations,
            requestID: requestID,
            progressStart: 0.82,
            perturbationEnabled: effectiveDeepRenderMethod == .perturbation,
            doubleDoubleEnabled: effectiveDeepRenderMethod == .doubleDouble,
            isFinalRender: true,
            progressEnd: 0.995,
            statsCallback: { stats in
                Task { @MainActor in
                    onPerturbationStatsPublished(stats)
                }
            }
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
                    preciseViewport: precise,
                    iterations: finalRenderIterations
                )
            )
            onThumbnailPublished(makeFavoriteThumbnailPNG(from: finalImage))
            completedRenderIterations = finalRenderIterations

            renderProgress = 1.0
        }

        guard !Task.isCancelled,
              refinementEnabled,
              requestID == renderID else {
            return
        }

        if renderStartDate != nil {
            lastRenderDurationText = elapsedText(at: Date())
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
        preciseViewport: PreciseViewport,
        maxIterations: Int,
        requestID: String,
        progressStart: Double? = nil,
        perturbationEnabled: Bool,
        doubleDoubleEnabled: Bool = false,
        isFinalRender: Bool = false,
        progressEnd: Double? = nil,
        statsCallback: (@MainActor @Sendable (String?) -> Void)? = nil
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
                preciseViewport: preciseViewport,
                maxIterations: maxIterations,
                viewportAspectRatio: aspectRatio,
                perturbationEnabled: perturbationEnabled,
                doubleDoubleEnabled: doubleDoubleEnabled && isFinalRender,
                statsCallback: { stats in
                    Task { @MainActor in
                        guard requestID == renderID else { return }
                        statsCallback?(stats)
                    }
                },
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


nonisolated private final class DirectRenderPixelStorage: @unchecked Sendable {
    let pointer: UnsafeMutablePointer<UInt8>
    let byteCount: Int

    init(byteCount: Int) {
        self.byteCount = byteCount
        self.pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
    }

    deinit {
        pointer.deallocate()
    }
}

nonisolated private final class DirectRenderBandProgress: @unchecked Sendable {
    private let lock = NSLock()
    private let totalBands: Int
    private var completedBands = 0
    private let report: @Sendable (Double) -> Void

    init(
        totalBands: Int,
        report: @escaping @Sendable (Double) -> Void
    ) {
        self.totalBands = max(totalBands, 1)
        self.report = report
    }

    func finishBand() {
        lock.lock()
        completedBands += 1
        let progress = Double(completedBands) / Double(totalBands)
        lock.unlock()

        report(progress)
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
    preciseViewport: PreciseViewport? = nil,
    maxIterations: Int,
    perturbationEnabled: Bool = true,
    doubleDoubleEnabled: Bool = false
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
            preciseViewport: preciseViewport,
            maxIterations: maxIterations,
            perturbationEnabled: perturbationEnabled,
            doubleDoubleEnabled: doubleDoubleEnabled
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
                            if palette == .auric,
                               mode == .mandelbrot || mode == .mandelbrotRelief {
                                color = auricInteriorColor(
                                    normalizedX: sampleX / Double(sampleWidth),
                                    normalizedY: sampleY / Double(sampleHeight)
                                )
                            } else {
                                color = insideColor(mode: mode, palette: palette)
                            }
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


private struct DirectRefinementStats: Sendable {
    var refinedPixels = 0
    var initialInsidePixels = 0
    var lateEscapePixels = 0
    var escapedAfterRefinement = 0
    var insideAfterRefinement = 0

    nonisolated init(
        refinedPixels: Int = 0,
        initialInsidePixels: Int = 0,
        lateEscapePixels: Int = 0,
        escapedAfterRefinement: Int = 0,
        insideAfterRefinement: Int = 0
    ) {
        self.refinedPixels = refinedPixels
        self.initialInsidePixels = initialInsidePixels
        self.lateEscapePixels = lateEscapePixels
        self.escapedAfterRefinement = escapedAfterRefinement
        self.insideAfterRefinement = insideAfterRefinement
    }
}

nonisolated private final class DirectRefinementStatsAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var totals = DirectRefinementStats()

    func add(_ values: DirectRefinementStats) {
        lock.lock()
        totals.refinedPixels += values.refinedPixels
        totals.initialInsidePixels += values.initialInsidePixels
        totals.lateEscapePixels += values.lateEscapePixels
        totals.escapedAfterRefinement += values.escapedAfterRefinement
        totals.insideAfterRefinement += values.insideAfterRefinement
        lock.unlock()
    }

    func snapshot() -> DirectRefinementStats {
        lock.lock()
        let result = totals
        lock.unlock()
        return result
    }
}

nonisolated private func calculateMandelbrotIterationState(
    cX: Double,
    cY: Double,
    maxIterations: Int
) -> (iteration: Int, x: Double, y: Double) {
    var x = 0.0
    var y = 0.0
    var iteration = 0

    while x * x + y * y <= 4.0 && iteration < maxIterations {
        let nextX = x * x - y * y + cX
        y = 2.0 * x * y + cY
        x = nextX
        iteration += 1
    }

    return (iteration, x, y)
}

nonisolated private func continueMandelbrotIteration(
    cX: Double,
    cY: Double,
    x: Double,
    y: Double,
    iteration: Int,
    maxIterations: Int
) -> Int {
    var x = x
    var y = y
    var iteration = iteration

    while x * x + y * y <= 4.0 && iteration < maxIterations {
        let nextX = x * x - y * y + cX
        y = 2.0 * x * y + cY
        x = nextX
        iteration += 1
    }

    return iteration
}

nonisolated private func renderDirectMandelbrotParallel(
    width: Int,
    height: Int,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double,
    maxIterations: Int,
    viewportAspectRatio: Double,
    statsCallback: (@Sendable (String?) -> Void)? = nil,
    progressCallback: (@Sendable (Double) -> Void)? = nil
) -> CGImage? {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8
    let byteCount = width * height * bytesPerPixel

    let storage = DirectRenderPixelStorage(byteCount: byteCount)

    // Use more bands than performance cores so uneven boundary-heavy regions
    // do not leave one worker with all of the expensive pixels.
    let processorCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
    let bandCount = min(height, max(2, processorCount * 3))
    let rowsPerBand = (height + bandCount - 1) / bandCount
    let bandProgress = progressCallback.map {
        DirectRenderBandProgress(totalBands: bandCount, report: $0)
    }
    let refinementStats = DirectRefinementStatsAccumulator()

    DispatchQueue.concurrentPerform(iterations: bandCount) { bandIndex in
        let startRow = bandIndex * rowsPerBand
        let endRow = min(startRow + rowsPerBand, height)

        guard startRow < endRow else { return }

        var bandStats = DirectRefinementStats()

        for py in startRow..<endRow {
            if Task.isCancelled { return }

            for px in 0..<width {
                if px.isMultiple(of: 64), Task.isCancelled { return }

                let x0 = centerX
                    + ((Double(px) + 0.5) / Double(width) - 0.5)
                    * scale
                    * viewportAspectRatio

                let y0 = centerY
                    + ((Double(py) + 0.5) / Double(height) - 0.5)
                    * scale

                var localMaxIterations = maxIterations
                let initialOrbit = calculateMandelbrotIterationState(
                    cX: x0,
                    cY: y0,
                    maxIterations: localMaxIterations
                )
                var iteration = initialOrbit.iteration

                if shouldApplyAdaptiveIterationRefinement(
                    mode: .mandelbrot,
                    width: width,
                    maxIterations: maxIterations,
                    iteration: iteration
                ) {
                    bandStats.refinedPixels += 1

                    if iteration == maxIterations {
                        bandStats.initialInsidePixels += 1
                    } else {
                        bandStats.lateEscapePixels += 1
                    }

                    localMaxIterations = min(
                        maxIterations + maxIterations / 2,
                        120_000
                    )

                    // A pixel that has already escaped has a final iteration
                    // count. Keep that count, but normalize its color against
                    // the higher refinement limit exactly as before.
                    if iteration == maxIterations {
                        iteration = continueMandelbrotIteration(
                            cX: x0,
                            cY: y0,
                            x: initialOrbit.x,
                            y: initialOrbit.y,
                            iteration: initialOrbit.iteration,
                            maxIterations: localMaxIterations
                        )
                    }

                    if iteration == localMaxIterations {
                        bandStats.insideAfterRefinement += 1
                    } else {
                        bandStats.escapedAfterRefinement += 1
                    }
                }

                let color: (r: Double, g: Double, b: Double)

                if iteration == localMaxIterations {
                    if palette == .auric {
                        color = auricInteriorColor(
                            normalizedX: (Double(px) + 0.5) / Double(width),
                            normalizedY: (Double(py) + 0.5) / Double(height)
                        )
                    } else {
                        color = insideColor(mode: .mandelbrot, palette: palette)
                    }
                } else {
                    let t = Double(iteration) / Double(localMaxIterations)
                    color = cpuPaletteColor(
                        t: t,
                        mode: .mandelbrot,
                        palette: palette
                    )
                }

                let offset = (py * width + px) * bytesPerPixel

                storage.pointer[offset + 0] = UInt8(clamp01(color.r) * 255.0)
                storage.pointer[offset + 1] = UInt8(clamp01(color.g) * 255.0)
                storage.pointer[offset + 2] = UInt8(clamp01(color.b) * 255.0)
                storage.pointer[offset + 3] = 255
            }
        }

        if !Task.isCancelled {
            refinementStats.add(bandStats)
        }

        bandProgress?.finishBand()
    }

    guard !Task.isCancelled else {
        return nil
    }

    let totals = refinementStats.snapshot()
    let totalPixels = max(width * height, 1)
    let refinementShare = 100.0
        * Double(totals.refinedPixels)
        / Double(totalPixels)

    statsCallback?("""
    Direct Double Refinement

    Iterations:        \(maxIterations)
    Size:              \(width) × \(height)
    Refined px:        \(totals.refinedPixels) / \(totalPixels)
    Refinement share:  \(String(format: "%.1f", refinementShare))%
    Initial inside:    \(totals.initialInsidePixels)
    Late escape:       \(totals.lateEscapePixels)
    Escaped after:     \(totals.escapedAfterRefinement)
    Inside after:      \(totals.insideAfterRefinement)
    """)

    let pixels = Array(
        UnsafeBufferPointer(
            start: storage.pointer,
            count: storage.byteCount
        )
    )

    return makeCGImage(
        pixels: pixels,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        bitsPerComponent: bitsPerComponent,
        bytesPerPixel: bytesPerPixel
    )
}

private struct PerturbationParallelRowStats: Sendable {
    var perturbationPixels = 0
    var fallbackPixels = 0
    var unreliablePixels = 0
    var rebasedPixels = 0
    var rebaseCount = 0
    var firstRebaseIterationSum = 0
}

nonisolated private final class PerturbationParallelStats: @unchecked Sendable {
    private let lock = NSLock()

    private var perturbationPixels = 0
    private var fallbackPixels = 0
    private var unreliablePixels = 0
    private var rebasedPixels = 0
    private var rebaseCount = 0
    private var firstRebaseIterationSum = 0

    func add(_ row: PerturbationParallelRowStats) {
        lock.lock()
        perturbationPixels += row.perturbationPixels
        fallbackPixels += row.fallbackPixels
        unreliablePixels += row.unreliablePixels
        rebasedPixels += row.rebasedPixels
        rebaseCount += row.rebaseCount
        firstRebaseIterationSum += row.firstRebaseIterationSum
        lock.unlock()
    }

    func snapshot() -> PerturbationParallelRowStats {
        lock.lock()
        let result = PerturbationParallelRowStats(
            perturbationPixels: perturbationPixels,
            fallbackPixels: fallbackPixels,
            unreliablePixels: unreliablePixels,
            rebasedPixels: rebasedPixels,
            rebaseCount: rebaseCount,
            firstRebaseIterationSum: firstRebaseIterationSum
        )
        lock.unlock()
        return result
    }
}

nonisolated private func renderPerturbationMandelbrotParallel(
    width: Int,
    height: Int,
    palette: FractalPalette,
    centerX: Double,
    centerY: Double,
    scale: Double,
    maxIterations: Int,
    viewportAspectRatio: Double,
    statsCallback: (@Sendable (String?) -> Void)? = nil,
    progressCallback: (@Sendable (Double) -> Void)? = nil
) -> CGImage? {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8
    let byteCount = width * height * bytesPerPixel
    let storage = DirectRenderPixelStorage(byteCount: byteCount)

    let referenceCache = PerturbationReferenceCache(
        references: PerturbationEngine.makeReferenceGrid(
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            aspectRatio: viewportAspectRatio,
            maxIterations: maxIterations
        )
    )

    let maximumRowLocalPerturbationReferences =
        referenceCache.count + 16

    let perturbationRadiusPixels = perturbationCoverageRadiusPixels(
        scale: scale,
        viewportWidth: width
    )

    let pixelScale = scale / Double(max(width, height))
    let maxReferenceDistance = pixelScale * perturbationRadiusPixels
    let maxReferenceDistance2 = maxReferenceDistance * maxReferenceDistance

    let stats = PerturbationParallelStats()
    let rowProgress = progressCallback.map {
        DirectRenderBandProgress(totalBands: height, report: $0)
    }

    DispatchQueue.concurrentPerform(iterations: height) { py in
        if Task.isCancelled { return }

        var rowCache = referenceCache
        var rowStats = PerturbationParallelRowStats()

        for px in 0..<width {
            if px.isMultiple(of: 64), Task.isCancelled { return }

            let x0 = centerX
                + ((Double(px) + 0.5) / Double(width) - 0.5)
                * scale
                * viewportAspectRatio

            let y0 = centerY
                + ((Double(py) + 0.5) / Double(height) - 0.5)
                * scale

            var localMaxIterations = maxIterations
            var iteration: Int

            let referenceDistance2 = rowCache.nearestReferenceDistanceSquared(
                forX: x0,
                y: y0
            )

            if referenceDistance2 <= maxReferenceDistance2 {
                let perturbationResult =
                    PerturbationEngine.perturbationIterationWithCachedRebase(
                        x0: x0,
                        y0: y0,
                        cache: &rowCache,
                        maxIterations: localMaxIterations,
                        maximumCachedReferences: maximumRowLocalPerturbationReferences
                    )

                if perturbationResult.reliable {
                    let shouldPulseCheck =
                        px.isMultiple(of: 32) &&
                        py.isMultiple(of: 32)

                    if shouldPulseCheck {
                        let directIteration = calculateFractalIteration(
                            mode: .mandelbrot,
                            x0: x0,
                            y0: y0,
                            maxIterations: localMaxIterations
                        )

                        if abs(directIteration - perturbationResult.iteration) > 8 {
                            rowStats.unreliablePixels += 1
                            rowStats.fallbackPixels += 1
                            iteration = directIteration
                        } else {
                            rowStats.perturbationPixels += 1

                            if perturbationResult.rebaseCount > 0 {
                                rowStats.rebasedPixels += 1
                                rowStats.rebaseCount += perturbationResult.rebaseCount

                                if let firstRebaseIteration =
                                    perturbationResult.firstRebaseIteration {
                                    rowStats.firstRebaseIterationSum += firstRebaseIteration
                                }
                            }

                            iteration = perturbationResult.iteration
                        }
                    } else {
                        rowStats.perturbationPixels += 1

                        if perturbationResult.rebaseCount > 0 {
                            rowStats.rebasedPixels += 1
                            rowStats.rebaseCount += perturbationResult.rebaseCount

                            if let firstRebaseIteration =
                                perturbationResult.firstRebaseIteration {
                                rowStats.firstRebaseIterationSum += firstRebaseIteration
                            }
                        }

                        iteration = perturbationResult.iteration
                    }
                } else {
                    rowStats.unreliablePixels += 1
                    rowStats.fallbackPixels += 1
                    iteration = calculateFractalIteration(
                        mode: .mandelbrot,
                        x0: x0,
                        y0: y0,
                        maxIterations: localMaxIterations
                    )
                }
            } else {
                rowStats.fallbackPixels += 1
                iteration = calculateFractalIteration(
                    mode: .mandelbrot,
                    x0: x0,
                    y0: y0,
                    maxIterations: localMaxIterations
                )
            }

            if shouldApplyAdaptiveIterationRefinement(
                mode: .mandelbrot,
                width: width,
                maxIterations: maxIterations,
                iteration: iteration
            ) {
                localMaxIterations = min(
                    maxIterations + maxIterations / 2,
                    120_000
                )

                iteration = calculateFractalIteration(
                    mode: .mandelbrot,
                    x0: x0,
                    y0: y0,
                    maxIterations: localMaxIterations
                )
            }

            let color: (r: Double, g: Double, b: Double)

            if iteration == localMaxIterations {
                if palette == .auric {
                    color = auricInteriorColor(
                        normalizedX: (Double(px) + 0.5) / Double(width),
                        normalizedY: (Double(py) + 0.5) / Double(height)
                    )
                } else {
                    color = insideColor(mode: .mandelbrot, palette: palette)
                }
            } else {
                let t = Double(iteration) / Double(localMaxIterations)

                color = cpuPaletteColor(
                    t: t,
                    mode: .mandelbrot,
                    palette: palette
                )
            }

            let offset = (py * width + px) * bytesPerPixel
            storage.pointer[offset + 0] = UInt8(clamp01(color.r) * 255.0)
            storage.pointer[offset + 1] = UInt8(clamp01(color.g) * 255.0)
            storage.pointer[offset + 2] = UInt8(clamp01(color.b) * 255.0)
            storage.pointer[offset + 3] = 255
        }

        if !Task.isCancelled {
            stats.add(rowStats)
            rowProgress?.finishBand()
        }
    }

    guard !Task.isCancelled else {
        return nil
    }

    let totals = stats.snapshot()
    let totalPixels = width * height
    let coverage = 100.0 * Double(totals.perturbationPixels) / Double(totalPixels)
    let checkedPixels = max(totals.perturbationPixels + totals.unreliablePixels, 1)
    let stability = 100.0 * Double(totals.perturbationPixels) / Double(checkedPixels)

    let averageFirstRebaseIteration = totals.rebasedPixels > 0
        ? String(
            Int(
                (
                    Double(totals.firstRebaseIterationSum)
                    / Double(totals.rebasedPixels)
                ).rounded()
            )
        )
        : "none"

    func bar(_ value: Double) -> String {
        let filled = Int((value / 10.0).rounded())
        let clamped = min(max(filled, 0), 10)

        return String(repeating: "█", count: clamped)
            + String(repeating: "░", count: 10 - clamped)
    }

    statsCallback?("""
    Coverage  \(bar(coverage)) \(String(format: "%.1f", coverage))%
    Stability \(bar(stability)) \(String(format: "%.1f", stability))%

    Iterations:   \(maxIterations)
    Size:         \(width) × \(height)

    Perturbation: \(totals.perturbationPixels) / \(totalPixels)
    Direct CPU:    \(totals.fallbackPixels)
    Unreliable:    \(totals.unreliablePixels)
    Rebased px:    \(totals.rebasedPixels)
    Rebases:       \(totals.rebaseCount)
    First rebase:  \(averageFirstRebaseIteration)

    References:    \(referenceCache.count) + 0
    Radius:        Auto \(Int(perturbationRadiusPixels)) px
    """)

    let pixels = Array(
        UnsafeBufferPointer(
            start: storage.pointer,
            count: storage.byteCount
        )
    )

    return makeCGImage(
        pixels: pixels,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        bitsPerComponent: bitsPerComponent,
        bytesPerPixel: bytesPerPixel
    )
}

nonisolated private func renderDirectMandelbrotDoubleDoubleParallel(
    width: Int,
    height: Int,
    palette: FractalPalette,
    preciseViewport: PreciseViewport,
    maxIterations: Int,
    viewportAspectRatio: Double,
    progressCallback: (@Sendable (Double) -> Void)? = nil
) -> CGImage? {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8
    let byteCount = width * height * bytesPerPixel

    let storage = DirectRenderPixelStorage(byteCount: byteCount)

    let processorCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
    let bandCount = min(height, max(2, processorCount * 3))
    let rowsPerBand = (height + bandCount - 1) / bandCount
    let bandProgress = progressCallback.map {
        DirectRenderBandProgress(totalBands: bandCount, report: $0)
    }

    let pixelWidth = Double(width)
    let pixelHeight = Double(height)

    DispatchQueue.concurrentPerform(iterations: bandCount) { bandIndex in
        let startRow = bandIndex * rowsPerBand
        let endRow = min(startRow + rowsPerBand, height)

        guard startRow < endRow else { return }

        for py in startRow..<endRow {
            if Task.isCancelled { return }

            let verticalOffset =
                (Double(py) + 0.5) / pixelHeight - 0.5

            let y0 = preciseViewport.centerY
                + preciseViewport.scale * verticalOffset

            for px in 0..<width {
                if px.isMultiple(of: 64), Task.isCancelled { return }

                let horizontalOffset =
                    ((Double(px) + 0.5) / pixelWidth - 0.5)
                    * viewportAspectRatio

                let x0 = preciseViewport.centerX
                    + preciseViewport.scale * horizontalOffset

                var localMaxIterations = maxIterations
                var iteration = calculateMandelbrotIterationDoubleDouble(
                    cX: x0,
                    cY: y0,
                    maxIterations: localMaxIterations
                )

                if shouldApplyAdaptiveIterationRefinement(
                    mode: .mandelbrot,
                    width: width,
                    maxIterations: maxIterations,
                    iteration: iteration
                ) {
                    localMaxIterations = min(
                        maxIterations + maxIterations / 2,
                        120_000
                    )

                    iteration = calculateMandelbrotIterationDoubleDouble(
                        cX: x0,
                        cY: y0,
                        maxIterations: localMaxIterations
                    )
                }

                let color: (r: Double, g: Double, b: Double)

                if iteration == localMaxIterations {
                    if palette == .auric {
                        color = auricInteriorColor(
                            normalizedX: (Double(px) + 0.5) / Double(width),
                            normalizedY: (Double(py) + 0.5) / Double(height)
                        )
                    } else {
                        color = insideColor(
                            mode: .mandelbrot,
                            palette: palette
                        )
                    }
                } else {
                    let t = Double(iteration) / Double(maxIterations)

                    color = cpuPaletteColor(
                        t: t,
                        mode: .mandelbrot,
                        palette: palette
                    )
                }

                let offset = (py * width + px) * bytesPerPixel

                storage.pointer[offset + 0] =
                    UInt8(clamp01(color.r) * 255.0)
                storage.pointer[offset + 1] =
                    UInt8(clamp01(color.g) * 255.0)
                storage.pointer[offset + 2] =
                    UInt8(clamp01(color.b) * 255.0)
                storage.pointer[offset + 3] = 255
            }
        }

        bandProgress?.finishBand()
    }

    guard !Task.isCancelled else {
        return nil
    }

    let pixels = Array(
        UnsafeBufferPointer(
            start: storage.pointer,
            count: storage.byteCount
        )
    )

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
    preciseViewport: PreciseViewport? = nil,
    maxIterations: Int,
    viewportAspectRatio: Double? = nil,
    perturbationEnabled: Bool = true,
    doubleDoubleEnabled: Bool = false,
    statsCallback: (@Sendable (String?) -> Void)? = nil,
    progressCallback: (@Sendable (Double) -> Void)? = nil
) -> CGImage? {

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8

    var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

    // The preview can be rendered at a capped bitmap size. Its mathematical
    // viewport must nevertheless retain the exact aspect ratio of the SwiftUI view.
    let aspectRatio = viewportAspectRatio ?? (Double(width) / Double(height))

    let usePerturbation = perturbationEnabled &&
        mode == .mandelbrot &&
        scale < 1e-9

    // Temporary opt-in comparison path. The normal deep renderer remains
    // Double unless this switch is enabled and a precise snapshot is available.
    if doubleDoubleEnabled,
       !usePerturbation,
       mode == .mandelbrot,
       let preciseViewport,
       scale < directDeepMandelbrotScaleLimit,
       width >= 512,
       height >= 256,
       maxIterations >= 8_000 {
        return renderDirectMandelbrotDoubleDoubleParallel(
            width: width,
            height: height,
            palette: palette,
            preciseViewport: preciseViewport,
            maxIterations: maxIterations,
            viewportAspectRatio: aspectRatio,
            progressCallback: progressCallback
        )
    }

    // Release deep zoom currently uses the proven direct Double renderer.
    // Split only this expensive exact path across CPU cores; all other modes,
    // normal zoom levels, and experimental perturbation remain unchanged.
    if !usePerturbation,
       mode == .mandelbrot,
       scale < directDeepMandelbrotScaleLimit,
       width >= 512,
       height >= 256,
       maxIterations >= 8_000 {
        return renderDirectMandelbrotParallel(
            width: width,
            height: height,
            palette: palette,
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            maxIterations: maxIterations,
            viewportAspectRatio: aspectRatio,
            statsCallback: statsCallback,
            progressCallback: progressCallback
        )
    }

    if usePerturbation,
       mode == .mandelbrot,
       width >= 512,
       height >= 256,
       maxIterations >= 8_000 {
        return renderPerturbationMandelbrotParallel(
            width: width,
            height: height,
            palette: palette,
            centerX: centerX,
            centerY: centerY,
            scale: scale,
            maxIterations: maxIterations,
            viewportAspectRatio: aspectRatio,
            statsCallback: statsCallback,
            progressCallback: progressCallback
        )
    }

    let perturbationReferenceCache = PerturbationReferenceCache(
        references: usePerturbation
            ? PerturbationEngine.makeReferenceGrid(
                centerX: centerX,
                centerY: centerY,
                scale: scale,
                aspectRatio: aspectRatio,
                maxIterations: maxIterations
            )
            : []
    )

    // Local rebases are cached only within a single image row.
    // This lets neighboring pixels reuse local reference orbits without
    // leaking them globally, which avoids the old bubble artifacts.
    let maximumRowLocalPerturbationReferences =
        perturbationReferenceCache.count + 16

    let perturbationRadiusPixels = perturbationCoverageRadiusPixels(
        scale: scale,
        viewportWidth: width
    )
    var perturbationPixels = 0
    var fallbackPixels = 0
    var unreliablePerturbationPixels = 0
    var perturbationRebasePixels = 0
    var totalPerturbationRebases = 0
    var firstRebaseIterationSum = 0
    var totalRowLocalReferences = 0
    var peakRowLocalReferences = 0
    var saturatedPerturbationRows = 0
    var localReferenceStartPixels = 0
    var localReferenceReusePixels = 0
    var localReferenceFallbackPixels = 0
    var initialReferenceFirstRebaseCount = 0
    var initialReferenceFirstRebaseIterationSum = 0
    var localReferenceFirstRebaseCount = 0
    var localReferenceFirstRebaseIterationSum = 0
    let initialPerturbationReferenceCount = perturbationReferenceCache.count

    for py in 0..<height {
        var rowPerturbationReferenceCache = perturbationReferenceCache

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
                var iteration: Int

                if perturbationReferenceCache.count > 0 {
                    let referenceDistance2 = rowPerturbationReferenceCache.nearestReferenceDistanceSquared(
                        forX: x0,
                        y: y0
                    )

                    let pixelScale = scale / Double(max(width, height))
                    let maxReferenceDistance = pixelScale * perturbationRadiusPixels
                    let maxReferenceDistance2 = maxReferenceDistance * maxReferenceDistance

                    if referenceDistance2 <= maxReferenceDistance2 {
                        let startedFromLocalReference =
                            rowPerturbationReferenceCache.nearestReferenceIsLocal(
                                forX: x0,
                                y: y0
                            )

                        if startedFromLocalReference {
                            localReferenceStartPixels += 1
                        }

                        let perturbationResult = PerturbationEngine.perturbationIterationWithCachedRebase(
                            x0: x0,
                            y0: y0,
                            cache: &rowPerturbationReferenceCache,
                            maxIterations: localMaxIterations,
                            maximumCachedReferences: maximumRowLocalPerturbationReferences
                        )

                        if let firstRebaseIteration =
                            perturbationResult.firstRebaseIteration {
                            if startedFromLocalReference {
                                localReferenceFirstRebaseCount += 1
                                localReferenceFirstRebaseIterationSum +=
                                    firstRebaseIteration
                            } else {
                                initialReferenceFirstRebaseCount += 1
                                initialReferenceFirstRebaseIterationSum +=
                                    firstRebaseIteration
                            }
                        }

                        if perturbationResult.reliable {
                            let shouldPulseCheck =
                                px.isMultiple(of: 32) &&
                                py.isMultiple(of: 32)

                            if shouldPulseCheck {
                                let directIteration = calculateFractalIteration(
                                    mode: mode,
                                    x0: x0,
                                    y0: y0,
                                    maxIterations: localMaxIterations
                                )

                                if abs(directIteration - perturbationResult.iteration) > 8 {
                                    unreliablePerturbationPixels += 1
                                    fallbackPixels += 1
                                    if startedFromLocalReference {
                                        localReferenceFallbackPixels += 1
                                    }
                                    iteration = directIteration
                                } else {
                                    perturbationPixels += 1
                                    if perturbationResult.rebaseCount > 0 {
                                        perturbationRebasePixels += 1
                                        totalPerturbationRebases += perturbationResult.rebaseCount
                                        if let firstRebaseIteration = perturbationResult.firstRebaseIteration {
                                            firstRebaseIterationSum += firstRebaseIteration
                                        }
                                    }
                                    if startedFromLocalReference,
                                       perturbationResult.rebaseCount == 0 {
                                        localReferenceReusePixels += 1
                                    }
                                    iteration = perturbationResult.iteration
                                }
                            } else {
                                perturbationPixels += 1
                                if perturbationResult.rebaseCount > 0 {
                                    perturbationRebasePixels += 1
                                    totalPerturbationRebases += perturbationResult.rebaseCount
                                    if let firstRebaseIteration = perturbationResult.firstRebaseIteration {
                                        firstRebaseIterationSum += firstRebaseIteration
                                    }
                                }
                                if startedFromLocalReference,
                                   perturbationResult.rebaseCount == 0 {
                                    localReferenceReusePixels += 1
                                }
                                iteration = perturbationResult.iteration
                            }
                        } else {
                            unreliablePerturbationPixels += 1
                            fallbackPixels += 1
                            if startedFromLocalReference {
                                localReferenceFallbackPixels += 1
                            }
                            iteration = calculateFractalIteration(
                                mode: mode,
                                x0: x0,
                                y0: y0,
                                maxIterations: localMaxIterations
                            )
                        }
                    } else {
                        fallbackPixels += 1
                        iteration = calculateFractalIteration(
                            mode: mode,
                            x0: x0,
                            y0: y0,
                            maxIterations: localMaxIterations
                        )
                    }
                } else {
                    if usePerturbation {
                        fallbackPixels += 1
                    }
                    iteration = calculateFractalIteration(
                        mode: mode,
                        x0: x0,
                        y0: y0,
                        maxIterations: localMaxIterations
                    )
                }

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
                    if palette == .auric,
                       mode == .mandelbrot || mode == .mandelbrotRelief {
                        color = auricInteriorColor(
                            normalizedX: (Double(px) + 0.5) / Double(width),
                            normalizedY: (Double(py) + 0.5) / Double(height)
                        )
                    } else {
                        color = insideColor(mode: mode, palette: palette)
                    }
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

        if usePerturbation {
            let rowLocalReferences =
                rowPerturbationReferenceCache.localReferenceCount

            totalRowLocalReferences += rowLocalReferences
            peakRowLocalReferences = max(
                peakRowLocalReferences,
                rowLocalReferences
            )

            if rowPerturbationReferenceCache.count >=
                maximumRowLocalPerturbationReferences {
                saturatedPerturbationRows += 1
            }
        }
    }

    if usePerturbation {
        let totalPixels = width * height
        let averageRowLocalReferences = height > 0
            ? Double(totalRowLocalReferences) / Double(height)
            : 0.0

        func averageIterationText(sum: Int, count: Int) -> String {
            guard count > 0 else { return "none" }
            return String(
                Int((Double(sum) / Double(count)).rounded())
            )
        }

        let initialReferenceFirstRebaseAverage = averageIterationText(
            sum: initialReferenceFirstRebaseIterationSum,
            count: initialReferenceFirstRebaseCount
        )
        let localReferenceFirstRebaseAverage = averageIterationText(
            sum: localReferenceFirstRebaseIterationSum,
            count: localReferenceFirstRebaseCount
        )

        let coverage = 100.0 * Double(perturbationPixels) / Double(totalPixels)
        let checkedPerturbationPixels = max(perturbationPixels + unreliablePerturbationPixels, 1)
        let stability = 100.0 * Double(perturbationPixels) / Double(checkedPerturbationPixels)
        let averageFirstRebaseIteration = perturbationRebasePixels > 0
            ? String(Int((Double(firstRebaseIterationSum) / Double(perturbationRebasePixels)).rounded()))
            : "none"
        func bar(_ value: Double) -> String {
            let filled = Int((value / 10.0).rounded())
            let clamped = min(max(filled, 0), 10)
            return String(repeating: "█", count: clamped)
                + String(repeating: "░", count: 10 - clamped)
        }

        statsCallback?("""
        Coverage  \(bar(coverage)) \(String(format: "%.1f", coverage))%
        Stability \(bar(stability)) \(String(format: "%.1f", stability))%

        Iterations:   \(maxIterations)
        Size:         \(width) × \(height)

        Perturbation: \(perturbationPixels) / \(totalPixels)
        Direct CPU:    \(fallbackPixels)
        Unreliable:    \(unreliablePerturbationPixels)
        Rebased px:    \(perturbationRebasePixels)
        Rebases:       \(totalPerturbationRebases)
        First rebase:  \(averageFirstRebaseIteration)

        Initial refs:  \(initialPerturbationReferenceCount)
        Row locals:    \(totalRowLocalReferences) total
        Avg / row:     \(String(format: "%.1f", averageRowLocalReferences))
        Peak / row:    \(peakRowLocalReferences)
        Saturated:     \(saturatedPerturbationRows) / \(height) rows
        Local starts:  \(localReferenceStartPixels)
        Local reuse:   \(localReferenceReusePixels)
        Local fallback:\(localReferenceFallbackPixels)

        Grid 1st rb:   \(initialReferenceFirstRebaseAverage)
        Grid rb px:    \(initialReferenceFirstRebaseCount)
        Local 1st rb:  \(localReferenceFirstRebaseAverage)
        Local rb px:   \(localReferenceFirstRebaseCount)
        Radius:        Auto \(Int(perturbationRadiusPixels)) px
        """)
    } else {
        statsCallback?(nil)
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
    case .rainbows:
        colors = [
            (1.00, 0.08, 0.16),
            (1.00, 0.80, 0.05),
            (0.12, 1.00, 0.38),
            (0.05, 0.62, 1.00),
            (0.72, 0.12, 1.00)
        ]
    case .abyss:
        colors = [
            (0.00, 0.14, 0.42),
            (0.00, 0.72, 0.98),
            (0.78, 0.98, 1.00),
            (0.02, 0.04, 0.16),
            (1.00, 0.62, 0.12)
        ]
    case .deepCurrent:
        colors = [
            (0.01, 0.08, 0.30),
            (0.02, 0.64, 0.92),
            (0.88, 0.98, 1.00),
            (0.92, 0.62, 0.16),
            (1.00, 0.30, 0.04)
        ]
    case .auric:
        colors = [
            (0.03, 0.025, 0.020),
            (0.36, 0.18, 0.045),
            (0.95, 0.66, 0.14),
            (1.00, 0.92, 0.68),
            (0.12, 0.16, 0.19)
        ]
    case .aurora:
        colors = [
            (0.01, 0.08, 0.30),
            (0.04, 0.68, 0.96),
            (0.48, 0.10, 0.82),
            (0.94, 0.10, 0.62),
            (1.00, 0.68, 0.08)
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
    case .mandelbrot, .mandelbrotRelief, .celtic:
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

    case .mandelbulb3D, .mandelbox3D, .newton, .eightRainbows:
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

        case .celtic:
            let realSquared = x * x - y * y
            let imaginarySquared = 2.0 * x * y
            x = abs(realSquared) + cx
            y = imaginarySquared + cy

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

        case .eightRainbows:
            let x2 = x * x - y * y
            let y2 = 2.0 * x * y
            let x4 = x2 * x2 - y2 * y2
            let y4 = 2.0 * x2 * y2

            x = x4 * x4 - y4 * y4 + cx
            y = 2.0 * x4 * y4 + cy

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

    case .aurora:
        // Keep the deep-blue atmosphere while lifting midtones and fine information edges.
        let body = pow(relief, 0.56)
        let detail = pow(ridge, 1.35)
        let light = pow(glow, 1.15)
        let rawPhase = 0.10 + 3.60 * pow(relief, 0.62) + 5.40 * ridge + 0.55 * glow
        let phase = rawPhase - floor(rawPhase)

        let cyanBand = smoothstep(edge0: 0.01, edge1: 0.06, x: phase)
            * (1.0 - smoothstep(edge0: 0.12, edge1: 0.17, x: phase))
        let violetBand = smoothstep(edge0: 0.19, edge1: 0.24, x: phase)
            * (1.0 - smoothstep(edge0: 0.31, edge1: 0.36, x: phase))
        let magentaBand = smoothstep(edge0: 0.40, edge1: 0.45, x: phase)
            * (1.0 - smoothstep(edge0: 0.53, edge1: 0.58, x: phase))
        let greenBand = smoothstep(edge0: 0.60, edge1: 0.64, x: phase)
            * (1.0 - smoothstep(edge0: 0.69, edge1: 0.73, x: phase))
        let warmBand = smoothstep(edge0: 0.76, edge1: 0.82, x: phase)
            * (1.0 - smoothstep(edge0: 0.88, edge1: 0.94, x: phase))

        var r = 0.006 + 0.036 * body + 0.31 * light
        var g = 0.022 + 0.50 * body + 0.40 * light
        var b = 0.135 + 0.91 * body + 0.11 * light
        let accent = detail * (0.30 + 0.78 * body)

        r += accent * (0.03 * cyanBand + 0.62 * violetBand + 1.02 * magentaBand + 0.14 * greenBand + 1.08 * warmBand)
        g += accent * (0.78 * cyanBand + 0.08 * violetBand + 0.08 * magentaBand + 1.02 * greenBand + 0.62 * warmBand)
        b += accent * (1.12 * cyanBand + 0.90 * violetBand + 0.82 * magentaBand + 0.18 * greenBand + 0.03 * warmBand)

        return (clamp01(r), clamp01(g), clamp01(b))

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

    case .rainbows:
        // Rainbows:
        // Explicit spectral cycles: red → yellow → green → cyan → blue → magenta.
        // The stronger phase variation prevents the usual low-escape region
        // from collapsing into a mostly teal image.
        let phase = (0.08 + 5.20 * pow(relief, 0.58) + 0.72 * ridge + 0.35 * glow)
            .truncatingRemainder(dividingBy: 1.0)
        let h6 = phase * 6.0

        let red = clamp01(abs(h6 - 3.0) - 1.0)
        let green = clamp01(2.0 - abs(h6 - 2.0))
        let blue = clamp01(2.0 - abs(h6 - 4.0))

        let brightness = 0.58 + 0.48 * pow(relief, 0.32) + 0.18 * glow
        let sparkle = 0.10 + 0.20 * pow(ridge, 1.60)

        return (
            clamp01(red * brightness + sparkle),
            clamp01(green * brightness + sparkle),
            clamp01(blue * brightness + sparkle)
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

    case .abyss:
        // Abyss:
        // Deep navy water, cyan and ice reefs, balanced by broad sand-gold
        // and amber currents inspired by a warm ocean-floor glow.
        let body = pow(relief, 0.46)
        let detail = pow(ridge, 0.64)
        let iceGlow = pow(glow, 0.74)

        let rawPhase = 0.08 + 2.30 * relief + 1.90 * glow + 3.35 * ridge
        let phase = rawPhase - floor(rawPhase)

        let iceBand = smoothstep(edge0: 0.24, edge1: 0.38, x: phase)
            * (1.0 - smoothstep(edge0: 0.57, edge1: 0.72, x: phase))

        let goldBand = smoothstep(edge0: 0.80, edge1: 0.87, x: phase)
            * (1.0 - smoothstep(edge0: 0.94, edge1: 0.990, x: phase))

        let warmRawPhase = 0.16 + 0.82 * relief + 0.46 * glow + 0.74 * ridge
        let warmPhase = warmRawPhase - floor(warmRawPhase)

        let warmBody = smoothstep(edge0: 0.18, edge1: 0.34, x: warmPhase)
            * (1.0 - smoothstep(edge0: 0.62, edge1: 0.80, x: warmPhase))

        let midnight = (0.003, 0.014, 0.070)
        let cobalt = (0.010, 0.145, 0.470)
        let cyan = (0.000, 0.860, 1.000)
        let ice = (0.880, 1.000, 1.000)
        let sandGold = (0.82, 0.66, 0.30)

        var r = midnight.0
        var g = midnight.1
        var b = midnight.2

        let cobaltMix = min(0.88, 0.44 + 0.34 * body)
        r = r + (cobalt.0 - r) * cobaltMix
        g = g + (cobalt.1 - g) * cobaltMix
        b = b + (cobalt.2 - b) * cobaltMix

        let cyanMix = min(0.78, 0.44 * body + 0.32 * detail + 0.16 * iceGlow)
        r = r + (cyan.0 - r) * cyanMix
        g = g + (cyan.1 - g) * cyanMix
        b = b + (cyan.2 - b) * cyanMix

        let broadGoldMix = 0.46 * warmBody * (0.36 + 0.64 * body)
        r = r + (sandGold.0 - r) * broadGoldMix
        g = g + (sandGold.1 - g) * broadGoldMix
        b = b + (sandGold.2 - b) * broadGoldMix

        let iceMix = min(
            0.88,
            0.72 * iceBand * (0.24 + 0.76 * detail) + 0.50 * iceGlow
        )
        r = r + (ice.0 - r) * iceMix
        g = g + (ice.1 - g) * iceMix
        b = b + (ice.2 - b) * iceMix

        let amberGlow = 0.44 * goldBand * (0.24 + 0.76 * detail)
        let reefSpark = 0.16 * pow(detail, 1.38) + 0.14 * iceGlow
        let lift = 0.66 + 0.50 * body + 0.34 * iceGlow

        return (
            clamp01(r * lift + 0.52 * amberGlow + 0.05 * reefSpark),
            clamp01(g * lift + 0.26 * amberGlow + 0.23 * reefSpark),
            clamp01(b * lift + 0.03 * amberGlow + 0.30 * reefSpark)
        )

    case .deepCurrent:
        // Deep Current:
        // A deliberate blue-gold ocean ramp. Each color owns a real range
        // of the phase, so sand and amber stay broad and saturated.
        let detail = pow(ridge, 0.72)
        let iceGlow = pow(glow, 0.82)

        let rawPhase = 0.04 + 1.12 * relief + 0.42 * glow + 0.84 * ridge
        let phase = rawPhase - floor(rawPhase)

        let midnight = (0.004, 0.018, 0.085)
        let cobalt = (0.010, 0.155, 0.520)
        let cyan = (0.000, 0.720, 0.980)
        let ice = (0.850, 0.980, 1.000)
        let deepBlue = (0.010, 0.080, 0.260)
        let sandGold = (0.88, 0.64, 0.22)
        let amber = (1.000, 0.300, 0.045)

        func blend(
            _ a: (Double, Double, Double),
            _ b: (Double, Double, Double),
            _ amount: Double
        ) -> (Double, Double, Double) {
            (
                a.0 + (b.0 - a.0) * amount,
                a.1 + (b.1 - a.1) * amount,
                a.2 + (b.2 - a.2) * amount
            )
        }

        let base: (Double, Double, Double)
        switch phase {
        case ..<0.14:
            base = blend(midnight, cobalt, phase / 0.14)
        case ..<0.28:
            base = blend(cobalt, cyan, (phase - 0.14) / 0.14)
        case ..<0.42:
            base = blend(cyan, ice, (phase - 0.28) / 0.14)
        case ..<0.54:
            base = blend(ice, deepBlue, (phase - 0.42) / 0.12)
        case ..<0.68:
            base = blend(deepBlue, sandGold, (phase - 0.54) / 0.14)
        case ..<0.84:
            base = blend(sandGold, amber, (phase - 0.68) / 0.16)
        default:
            base = blend(amber, midnight, (phase - 0.84) / 0.16)
        }

        let iceEdge = 0.22 * pow(detail, 1.38) * (0.28 + 0.72 * iceGlow)
        let goldEdge = 0.14 * pow(detail, 1.18)
            * smoothstep(edge0: 0.62, edge1: 0.86, x: phase)
        let lift = 0.54 + 0.34 * pow(relief, 0.48) + 0.24 * iceGlow

        return (
            clamp01(base.0 * lift + 0.48 * iceEdge + 0.58 * goldEdge),
            clamp01(base.1 * lift + 0.72 * iceEdge + 0.31 * goldEdge),
            clamp01(base.2 * lift + 0.80 * iceEdge + 0.05 * goldEdge)
        )

    case .auric:
        let body = pow(relief, 0.58)
        let ridgeGold = pow(ridge, 2.40)
        let ridgeHot = pow(ridge, 5.20)
        let ridgeChampagne = pow(ridge, 10.0)
        let glowGold = pow(glow, 1.10)
        let phase = (0.05 + 1.10 * relief + 1.35 * glow + 5.80 * ridge)
            .truncatingRemainder(dividingBy: 1.0)
        let band = smoothstep(edge0: 0.26, edge1: 0.44, x: phase)
            * (1.0 - smoothstep(edge0: 0.72, edge1: 0.90, x: phase))
        let darkCrack = pow(1.0 - clamp01(relief * 0.84 + glow * 0.36), 2.10) * pow(ridge, 1.25)
        let facet = 0.5 + 0.5 * cos(96.0 * ridge + 23.0 * glow - 11.0 * relief)

        func blend(
            _ a: (Double, Double, Double),
            _ b: (Double, Double, Double),
            _ amount: Double
        ) -> (Double, Double, Double) {
            (
                a.0 + (b.0 - a.0) * amount,
                a.1 + (b.1 - a.1) * amount,
                a.2 + (b.2 - a.2) * amount
            )
        }

        let shadow = (0.015, 0.010, 0.004)
        let darkBronze = (0.120, 0.055, 0.010)
        let bronze = (0.360, 0.180, 0.035)
        let antiqueGold = (0.780, 0.480, 0.090)
        let hotGold = (1.000, 0.720, 0.160)
        let champagne = (1.000, 0.940, 0.700)

        var color: (Double, Double, Double)
        let ramp = clamp01(0.10 + 0.66 * body + 0.16 * glowGold)
        if ramp < 0.22 {
            color = blend(shadow, darkBronze, ramp / 0.22)
        } else if ramp < 0.46 {
            color = blend(darkBronze, bronze, (ramp - 0.22) / 0.24)
        } else if ramp < 0.72 {
            color = blend(bronze, antiqueGold, (ramp - 0.46) / 0.26)
        } else {
            color = blend(antiqueGold, hotGold, (ramp - 0.72) / 0.28)
        }

        color = blend(color, antiqueGold, 0.34 * band * (0.40 + 0.60 * ridgeGold))
        color = blend(color, hotGold, 0.58 * ridgeGold * (0.35 + 0.65 * glowGold))
        color = blend(color, champagne, 0.86 * ridgeChampagne * (0.45 + 0.55 * facet))
        color = blend(color, shadow, 0.46 * darkCrack)

        return (
            clamp01(color.0 + 0.24 * ridgeHot + 0.04 * ridgeGold),
            clamp01(color.1 + 0.19 * ridgeHot + 0.03 * ridgeGold),
            clamp01(color.2 + 0.10 * ridgeHot + 0.015 * ridgeGold)
        )
    }
}

nonisolated private func insideColor(
    mode: FractalMode,
    palette: FractalPalette
) -> (r: Double, g: Double, b: Double) {

    if mode == .mandelbrot || mode == .mandelbrotRelief {
        if palette == .auric {
            return (0.560, 0.345, 0.085)
        }

        return (0.0, 0.0, 0.0)
    }

    if mode == .eightRainbows {
        return (0.018, 0.004, 0.055)
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
        case .rainbows:
            return (0.018, 0.008, 0.065)
        case .abyss:
            return (0.003, 0.012, 0.060)
        case .deepCurrent:
            return (0.004, 0.016, 0.072)
        case .auric:
            return (0.560, 0.345, 0.085)
        case .aurora:
            return (0.004, 0.010, 0.060)
        }
    }

    return (0.0, 0.0, 0.0)
}

nonisolated private func auricInteriorColor(
    normalizedX: Double,
    normalizedY: Double
) -> (r: Double, g: Double, b: Double) {
    let x = normalizedX * 2.0 - 1.0
    let y = normalizedY * 2.0 - 1.0
    let radius = min(sqrt(x * x + y * y), 1.35)

    let body = (0.550, 0.340, 0.080)
    let shadow = (0.160, 0.075, 0.015)
    let hotGold = (0.950, 0.650, 0.160)
    let champagne = (1.000, 0.920, 0.650)

    func blend(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double),
        _ t: Double
    ) -> (Double, Double, Double) {
        let amount = clamp01(t)
        return (
            a.0 + (b.0 - a.0) * amount,
            a.1 + (b.1 - a.1) * amount,
            a.2 + (b.2 - a.2) * amount
        )
    }

    let diagonal = 1.0 - smoothstep(edge0: 0.08, edge1: 0.62, x: abs(x - y + 0.18))
    let upperLeftGlow = exp(-5.2 * ((x + 0.42) * (x + 0.42) + (y + 0.38) * (y + 0.38)))
    let edgeShadow = smoothstep(edge0: 0.48, edge1: 1.12, x: radius)
    let lowerShadow = smoothstep(edge0: -0.18, edge1: 0.92, x: y)
    let facet = 0.5 + 0.5 * cos(18.0 * x - 13.0 * y + 7.0 * radius)
    let band = 0.5 + 0.5 * cos(24.0 * (x - y) + 5.0 * radius)

    var color = blend(shadow, body, 0.84 + 0.10 * facet)
    color = blend(color, shadow, 0.34 * edgeShadow + 0.18 * lowerShadow)
    color = blend(color, hotGold, 0.28 * diagonal + 0.18 * upperLeftGlow + 0.06 * band)
    color = blend(color, champagne, 0.24 * pow(diagonal, 3.2) * (0.45 + 0.55 * facet))

    return (clamp01(color.0), clamp01(color.1), clamp01(color.2))
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

nonisolated private func formatCompactPreciseMagnification(_ value: Double) -> String {
    if value < 1_000_000_000_000_000_000 {
        return formatMagnification(value)
    }

    return "×" + String(format: "%.3e", value)
        .replacingOccurrences(of: "e+", with: "e")
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
