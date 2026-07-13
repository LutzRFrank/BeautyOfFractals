import Foundation

/// A three-component viewport for the 3.0 extreme-precision renderer.
///
/// It mirrors `PreciseViewport` while remaining opt-in. This lets the
/// correctness and persistence work land before the production UI switches
/// from DoubleDouble to TripleDouble.
nonisolated struct TripleDoubleViewport: Sendable, Equatable {
    var centerX: TripleDouble
    var centerY: TripleDouble
    var scale: TripleDouble

    init(centerX: Double, centerY: Double, scale: Double) {
        self.centerX = TripleDouble(centerX)
        self.centerY = TripleDouble(centerY)
        self.scale = TripleDouble(scale)
    }

    init(
        centerX: TripleDouble,
        centerY: TripleDouble,
        scale: TripleDouble
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
    }

    init(_ viewport: PreciseViewport) {
        centerX = viewport.centerX
        centerY = viewport.centerY
        scale = viewport.scale
    }

    var doubleProjection: (centerX: Double, centerY: Double, scale: Double) {
        (centerX.doubleValue, centerY.doubleValue, scale.doubleValue)
    }

    var doubleDoubleProjection: PreciseViewport {
        PreciseViewport(
            centerX: centerX.doubleDoubleValue,
            centerY: centerY.doubleDoubleValue,
            scale: scale.doubleDoubleValue
        )
    }

    func complexPoint(
        horizontalFraction: Double,
        verticalFraction: Double,
        aspectRatio: Double
    ) -> (x: TripleDouble, y: TripleDouble) {
        let horizontalOffset = (horizontalFraction - 0.5) * aspectRatio
        let verticalOffset = verticalFraction - 0.5

        return (
            centerX + scale * horizontalOffset,
            centerY + scale * verticalOffset
        )
    }

    func panned(
        horizontalFraction: Double,
        verticalFraction: Double,
        aspectRatio: Double
    ) -> TripleDoubleViewport {
        TripleDoubleViewport(
            centerX: centerX - scale * (horizontalFraction * aspectRatio),
            centerY: centerY - scale * verticalFraction,
            scale: scale
        )
    }

    func zoomed(
        toHorizontalFraction horizontalFraction: Double,
        verticalFraction: Double,
        aspectRatio: Double,
        zoomFactor: Double
    ) -> TripleDoubleViewport {
        let newCenter = complexPoint(
            horizontalFraction: horizontalFraction,
            verticalFraction: verticalFraction,
            aspectRatio: aspectRatio
        )

        return TripleDoubleViewport(
            centerX: newCenter.x,
            centerY: newCenter.y,
            scale: scale * zoomFactor
        )
    }

    func zoomed(by factor: Double) -> TripleDoubleViewport {
        TripleDoubleViewport(
            centerX: centerX,
            centerY: centerY,
            scale: scale * factor
        )
    }
}
