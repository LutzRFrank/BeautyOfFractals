import Foundation

nonisolated struct MandelbrotPrecisionComparison: Sendable {
    let sampleWidth: Int
    let sampleHeight: Int
    let differingSamples: Int
    let largestIterationDelta: Int
    let firstDifference: (x: Int, y: Int, double: Int, doubleDouble: Int)?
    let largestDifference: (x: Int, y: Int, double: Int, doubleDouble: Int)?

    var report: String {
        var lines = [
            "Double / DoubleDouble Comparison",
            "Samples: \(sampleWidth * sampleHeight) (\(sampleWidth) × \(sampleHeight))",
            "Different: \(differingSamples)",
            "Largest Δ: \(largestIterationDelta)"
        ]

        if let firstDifference {
            lines.append(
                "First diff: (\(firstDifference.x), \(firstDifference.y)) " +
                "D \(firstDifference.double) · DD \(firstDifference.doubleDouble)"
            )
        } else {
            lines.append("First diff: none")
        }

        if let largestDifference {
            lines.append(
                "Largest diff: (\(largestDifference.x), \(largestDifference.y)) " +
                "D \(largestDifference.double) · DD \(largestDifference.doubleDouble)"
            )
        }

        return lines.joined(separator: "\n")
    }
}

nonisolated func compareMandelbrotDoubleAndDoubleDouble(
    preciseViewport: PreciseViewport,
    maxIterations: Int,
    viewportAspectRatio: Double,
    sampleWidth: Int = 64,
    sampleHeight: Int = 36
) -> MandelbrotPrecisionComparison {
    let width = max(sampleWidth, 1)
    let height = max(sampleHeight, 1)
    let doubleViewport = preciseViewport.doubleProjection

    var differingSamples = 0
    var largestIterationDelta = 0
    var firstDifference: (x: Int, y: Int, double: Int, doubleDouble: Int)?
    var largestDifference: (x: Int, y: Int, double: Int, doubleDouble: Int)?

    for py in 0..<height {
        let verticalOffset =
            (Double(py) + 0.5) / Double(height) - 0.5

        let doubleY = doubleViewport.centerY
            + doubleViewport.scale * verticalOffset

        let doubleDoubleY = preciseViewport.centerY
            + preciseViewport.scale * verticalOffset

        for px in 0..<width {
            let horizontalOffset =
                ((Double(px) + 0.5) / Double(width) - 0.5)
                * viewportAspectRatio

            let doubleX = doubleViewport.centerX
                + doubleViewport.scale * horizontalOffset

            let doubleDoubleX = preciseViewport.centerX
                + preciseViewport.scale * horizontalOffset

            let doubleIteration = calculateMandelbrotIterationDouble(
                cX: doubleX,
                cY: doubleY,
                maxIterations: maxIterations
            )

            let doubleDoubleIteration =
                calculateMandelbrotIterationDoubleDouble(
                    cX: doubleDoubleX,
                    cY: doubleDoubleY,
                    maxIterations: maxIterations
                )

            let delta = abs(doubleIteration - doubleDoubleIteration)

            guard delta > 0 else { continue }

            differingSamples += 1

            if firstDifference == nil {
                firstDifference = (
                    x: px,
                    y: py,
                    double: doubleIteration,
                    doubleDouble: doubleDoubleIteration
                )
            }

            if delta > largestIterationDelta {
                largestIterationDelta = delta
                largestDifference = (
                    x: px,
                    y: py,
                    double: doubleIteration,
                    doubleDouble: doubleDoubleIteration
                )
            }
        }
    }

    return MandelbrotPrecisionComparison(
        sampleWidth: width,
        sampleHeight: height,
        differingSamples: differingSamples,
        largestIterationDelta: largestIterationDelta,
        firstDifference: firstDifference,
        largestDifference: largestDifference
    )
}

nonisolated private func calculateMandelbrotIterationDouble(
    cX: Double,
    cY: Double,
    maxIterations: Int
) -> Int {
    var x = 0.0
    var y = 0.0
    var iteration = 0

    while iteration < maxIterations {
        let magnitudeSquared = x * x + y * y

        if magnitudeSquared > 4.0 {
            break
        }

        let nextX = x * x - y * y + cX
        let nextY = 2.0 * x * y + cY

        x = nextX
        y = nextY
        iteration += 1
    }

    return iteration
}
