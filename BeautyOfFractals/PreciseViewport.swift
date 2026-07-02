import Foundation

/// A high-precision Mandelbrot viewport.
///
/// This intentionally has no SwiftUI or CoreGraphics dependency. UI gestures
/// convert their coordinates to normalized Double fractions before calling it.
/// The current Double-based UI and Metal preview can use `doubleProjection`;
/// a later extreme-zoom CPU renderer can consume the precise values directly.

nonisolated struct PreciseViewport: Sendable, Equatable {
    var centerX: DoubleDouble
    var centerY: DoubleDouble
    var scale: DoubleDouble

    init(
        centerX: Double,
        centerY: Double,
        scale: Double
    ) {
        self.centerX = DoubleDouble(centerX)
        self.centerY = DoubleDouble(centerY)
        self.scale = DoubleDouble(scale)
    }

    init(
        centerX: DoubleDouble,
        centerY: DoubleDouble,
        scale: DoubleDouble
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
    }

    var doubleProjection: (centerX: Double, centerY: Double, scale: Double) {
        (
            centerX.doubleValue,
            centerY.doubleValue,
            scale.doubleValue
        )
    }

    /// Returns the complex coordinate at a normalized viewport location.
    ///
    /// `horizontalFraction` and `verticalFraction` use the same convention as
    /// the existing renderer: 0.0 is the left/top edge and 1.0 the right/bottom.
    func complexPoint(
        horizontalFraction: Double,
        verticalFraction: Double,
        aspectRatio: Double
    ) -> (x: DoubleDouble, y: DoubleDouble) {
        let horizontalOffset =
            (horizontalFraction - 0.5) * aspectRatio
        let verticalOffset = verticalFraction - 0.5

        return (
            centerX + scale * horizontalOffset,
            centerY + scale * verticalOffset
        )
    }

    /// Returns the viewport after a pan expressed as fractions of the current
    /// viewport width and height.
    func panned(
        horizontalFraction: Double,
        verticalFraction: Double,
        aspectRatio: Double
    ) -> PreciseViewport {
        PreciseViewport(
            centerX: centerX - scale * (horizontalFraction * aspectRatio),
            centerY: centerY - scale * verticalFraction,
            scale: scale
        )
    }

    /// Returns the viewport after a selection zoom.
    ///
    /// The supplied normalized point is the selected rectangle's centre.
    /// `zoomFactor` is normally max(selectionWidth/viewWidth,
    /// selectionHeight/viewHeight), matching the existing UI behaviour.
    func zoomed(
        toHorizontalFraction horizontalFraction: Double,
        verticalFraction: Double,
        aspectRatio: Double,
        zoomFactor: Double
    ) -> PreciseViewport {
        let newCenter = complexPoint(
            horizontalFraction: horizontalFraction,
            verticalFraction: verticalFraction,
            aspectRatio: aspectRatio
        )

        return PreciseViewport(
            centerX: newCenter.x,
            centerY: newCenter.y,
            scale: scale * zoomFactor
        )
    }

    func zoomed(by factor: Double) -> PreciseViewport {
        PreciseViewport(
            centerX: centerX,
            centerY: centerY,
            scale: scale * factor
        )
    }
}
