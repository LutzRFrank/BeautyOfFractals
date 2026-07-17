import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let unit = TripleDouble(1.0)
let epsilon1 = Double.ulpOfOne / 2.0
let epsilon2 = epsilon1 * epsilon1

let enriched = unit + epsilon1 + epsilon2
require(enriched.hi == 1.0, "high component")
require(enriched.mid == epsilon1, "middle component")
require(enriched.lo == epsilon2, "low component")
require(enriched - unit - epsilon1 == TripleDouble(epsilon2), "three-level subtraction")

let cancellation = (unit + epsilon1 + epsilon2) - unit
require(cancellation == TripleDouble(hi: epsilon1, mid: epsilon2, lo: 0.0), "cancellation")

let product = (unit + epsilon1 + epsilon2) * (unit - epsilon1 + epsilon2)
let expectedProduct = unit + epsilon2 + epsilon2 * epsilon2
require(product == expectedProduct, "compensated multiplication")

let divided = TripleDouble(1.0) / 10.0
let recovered = divided * 10.0
require((recovered - unit).magnitude < 1e-47, "division recovery")

let ordered = TripleDouble(hi: 1.0, mid: epsilon1, lo: epsilon2)
require(ordered > unit, "lexicographic comparison")
require(ordered.isFinite, "finite value")

let maximumIterations = 2_000
require(
    calculateMandelbrotIterationTripleDouble(
        cX: .zero,
        cY: .zero,
        maxIterations: maximumIterations
    ) == maximumIterations,
    "origin remains inside"
)
require(
    calculateMandelbrotIterationTripleDouble(
        cX: TripleDouble(-1.0),
        cY: .zero,
        maxIterations: maximumIterations
    ) == maximumIterations,
    "period-two bulb remains inside"
)
require(
    calculateMandelbrotIterationTripleDouble(
        cX: TripleDouble(2.0),
        cY: .zero,
        maxIterations: maximumIterations
    ) == 2,
    "outside point escapes"
)

let comparisonPoints: [(Double, Double)] = [
    (-0.75, 0.1),
    (-0.743643887037151, 0.131825904205330),
    (-1.25066, 0.02012),
    (0.3, 0.5),
    (-1.75, 0.0)
]

for point in comparisonPoints {
    let doubleDoubleIteration = calculateMandelbrotIterationDoubleDouble(
        cX: DoubleDouble(point.0),
        cY: DoubleDouble(point.1),
        maxIterations: maximumIterations
    )
    let tripleDoubleIteration = calculateMandelbrotIterationTripleDouble(
        cX: TripleDouble(point.0),
        cY: TripleDouble(point.1),
        maxIterations: maximumIterations
    )
    require(
        tripleDoubleIteration == doubleDoubleIteration,
        "iterator comparison at \(point)"
    )
}

let deepScale = TripleDouble(hi: 1e-30, mid: 1e-46, lo: 1e-62)
let deepViewport = TripleDoubleViewport(
    centerX: TripleDouble(hi: -0.75, mid: 1e-30, lo: 1e-46),
    centerY: TripleDouble(hi: 0.1, mid: -1e-30, lo: 1e-46),
    scale: deepScale
)
let deepPoint = deepViewport.complexPoint(
    horizontalFraction: 0.75,
    verticalFraction: 0.25,
    aspectRatio: 2.0
)
require(deepPoint.x != deepViewport.centerX, "deep horizontal pixel offset")
require(deepPoint.y != deepViewport.centerY, "deep vertical pixel offset")

let deepZoom = deepViewport.zoomed(
    toHorizontalFraction: 0.75,
    verticalFraction: 0.25,
    aspectRatio: 2.0,
    zoomFactor: 0.5
)
require(deepZoom.centerX == deepPoint.x, "deep zoom center x")
require(deepZoom.centerY == deepPoint.y, "deep zoom center y")
require(deepZoom.scale == deepScale * 0.5, "deep zoom scale")

let perturbationCenterX = TripleDouble(-0.743643887037151)
let perturbationCenterY = TripleDouble(0.131825904205330)
let perturbationReference = TripleDoublePerturbation.makeReferenceOrbit(
    centerX: perturbationCenterX,
    centerY: perturbationCenterY,
    maxIterations: maximumIterations
)
for delta in [1e-9, 1e-12, 1e-15] {
    let direct = calculateMandelbrotIterationTripleDouble(
        cX: perturbationCenterX + delta,
        cY: perturbationCenterY - delta * 0.5,
        maxIterations: maximumIterations
    )
    let perturbed = TripleDoublePerturbation.iteration(
        deltaX: delta,
        deltaY: -delta * 0.5,
        reference: perturbationReference,
        maxIterations: maximumIterations
    )
    require(abs(direct - perturbed) <= 2, "TripleDouble perturbation at \(delta)")
}

let perturbationGrid = TripleDoublePerturbation.makeReferenceGrid(
    viewport: TripleDoubleViewport(
        centerX: perturbationCenterX,
        centerY: perturbationCenterY,
        scale: TripleDouble(1e-12)
    ),
    aspectRatio: 1.6,
    maxIterations: maximumIterations
)
require(perturbationGrid.count == 9, "3x3 TripleDouble reference grid")
let cornerReference = TripleDoublePerturbation.nearestReference(
    horizontalOffset: 0.79,
    verticalOffset: 0.49,
    references: perturbationGrid
)
require(cornerReference?.horizontalOffset == 0.8, "nearest horizontal reference")
require(cornerReference?.verticalOffset == 0.5, "nearest vertical reference")

let centralReference = perturbationGrid.first {
    $0.horizontalOffset == 0.0 && $0.verticalOffset == 0.0
}
let seriesApproximation = centralReference.flatMap {
    TripleDoublePerturbation.makeSeriesApproximation(
        scale: 1e-12,
        aspectRatio: 1.6,
        reference: $0.orbit,
        maxIterations: maximumIterations
    )
}
require(seriesApproximation != nil, "series approximation is available")
require((seriesApproximation?.iteration ?? 0) >= 16, "series approximation skips work")
let seriesApproximations = centralReference.map {
    TripleDoublePerturbation.makeSeriesApproximations(
        scale: 1e-12,
        aspectRatio: 1.6,
        reference: $0.orbit,
        maxIterations: maximumIterations
    )
} ?? []
require(seriesApproximations.count > 1, "series checkpoint ladder is available")

for offset in [(-0.7, -0.35), (0.2, 0.15), (0.65, 0.4)] {
    let scale = 1e-12
    let direct = calculateMandelbrotIterationTripleDouble(
        cX: perturbationCenterX + scale * offset.0,
        cY: perturbationCenterY + scale * offset.1,
        maxIterations: maximumIterations
    )
    let rebased = TripleDoublePerturbation.iterationWithLocalRebase(
        horizontalOffset: offset.0,
        verticalOffset: offset.1,
        scale: scale,
        references: perturbationGrid,
        maxIterations: maximumIterations
    )
    require(abs(direct - rebased) <= 2, "local rebase at \(offset)")

    let accelerated = TripleDoublePerturbation.acceleratedIterationWithLocalRebase(
        horizontalOffset: offset.0,
        verticalOffset: offset.1,
        scale: scale,
        references: perturbationGrid,
        approximation: seriesApproximation,
        maxIterations: maximumIterations
    )
    require(
        abs(direct - accelerated.iteration) <= 2,
        "series approximation at \(offset)"
    )

    let adaptive = TripleDoublePerturbation.acceleratedIterationWithLocalRebase(
        horizontalOffset: offset.0,
        verticalOffset: offset.1,
        scale: scale,
        references: perturbationGrid,
        approximations: seriesApproximations,
        maxIterations: maximumIterations
    )
    require(abs(direct - adaptive.iteration) <= 2, "adaptive series at \(offset)")
}

print("TripleDouble self-test passed")
