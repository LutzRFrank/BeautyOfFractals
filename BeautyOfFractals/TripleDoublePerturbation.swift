import Foundation

nonisolated struct TripleDoubleReferenceOrbit: Sendable {
    let x: [Double]
    let y: [Double]
    let escapedAt: Int
}

nonisolated struct TripleDoublePerturbationReference: Sendable {
    let horizontalOffset: Double
    let verticalOffset: Double
    let orbit: TripleDoubleReferenceOrbit
}

nonisolated struct TripleDoubleSeriesApproximation: Sendable {
    let iteration: Int
    let coefficientX: [Double]
    let coefficientY: [Double]
}

nonisolated struct TripleDoubleIterationResult: Sendable {
    let iteration: Int
    let skippedIterations: Int
}

nonisolated private final class TripleDoubleReferenceResults: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [TripleDoublePerturbationReference?]

    init(count: Int) {
        storage = [TripleDoublePerturbationReference?](repeating: nil, count: count)
    }

    func set(_ reference: TripleDoublePerturbationReference, at index: Int) {
        lock.lock()
        storage[index] = reference
        lock.unlock()
    }

    var values: [TripleDoublePerturbationReference] {
        lock.lock()
        defer { lock.unlock() }
        return storage.compactMap { $0 }
    }
}

nonisolated enum TripleDoublePerturbation {
    /// Builds a low-order polynomial for the perturbation delta around the
    /// central reference. Eight independent viewport probes determine the last
    /// iteration at which the polynomial still agrees with the exact recurrence.
    static func makeSeriesApproximation(
        scale: Double,
        aspectRatio: Double,
        reference: TripleDoubleReferenceOrbit,
        maxIterations: Int,
        termCount: Int = 6
    ) -> TripleDoubleSeriesApproximation? {
        makeSeriesApproximations(
            scale: scale,
            aspectRatio: aspectRatio,
            reference: reference,
            maxIterations: maxIterations,
            termCount: termCount
        ).last
    }

    /// Builds a sparse ladder of safe checkpoints. Each pixel may use the
    /// latest checkpoint that remains well inside the escape radius.
    static func makeSeriesApproximations(
        scale: Double,
        aspectRatio: Double,
        reference: TripleDoubleReferenceOrbit,
        maxIterations: Int,
        termCount: Int = 6
    ) -> [TripleDoubleSeriesApproximation] {
        guard termCount >= 2,
              scale.isFinite,
              scale != 0 else { return [] }

        let probes = [
            (-0.5 * aspectRatio, -0.5), (0.0, -0.5),
            (0.5 * aspectRatio, -0.5), (-0.5 * aspectRatio, 0.0),
            (0.5 * aspectRatio, 0.0), (-0.5 * aspectRatio, 0.5),
            (0.0, 0.5), (0.5 * aspectRatio, 0.5)
        ]
        var exactDeltas = probes.map { _ in (x: 0.0, y: 0.0) }
        var coefficientX = [Double](repeating: 0.0, count: termCount)
        var coefficientY = [Double](repeating: 0.0, count: termCount)
        var checkpoints: [TripleDoubleSeriesApproximation] = []
        var latestValid: TripleDoubleSeriesApproximation?
        let limit = min(maxIterations, reference.x.count - 1)

        for iteration in 0..<limit {
            let referenceX = reference.x[iteration]
            let referenceY = reference.y[iteration]
            var nextX = [Double](repeating: 0.0, count: termCount)
            var nextY = [Double](repeating: 0.0, count: termCount)

            for order in 0..<termCount {
                nextX[order] = 2.0 * (
                    referenceX * coefficientX[order]
                        - referenceY * coefficientY[order]
                )
                nextY[order] = 2.0 * (
                    referenceX * coefficientY[order]
                        + referenceY * coefficientX[order]
                )

                if order > 0 {
                    for left in 0..<order {
                        let right = order - 1 - left
                        nextX[order] += coefficientX[left] * coefficientX[right]
                            - coefficientY[left] * coefficientY[right]
                        nextY[order] += coefficientX[left] * coefficientY[right]
                            + coefficientY[left] * coefficientX[right]
                    }
                }
            }
            nextX[0] += 1.0
            coefficientX = nextX
            coefficientY = nextY

            var valid = true
            for probeIndex in probes.indices {
                let dcX = scale * probes[probeIndex].0
                let dcY = scale * probes[probeIndex].1
                let old = exactDeltas[probeIndex]
                let exactX = 2.0 * (referenceX * old.x - referenceY * old.y)
                    + old.x * old.x - old.y * old.y + dcX
                let exactY = 2.0 * (referenceX * old.y + referenceY * old.x)
                    + 2.0 * old.x * old.y + dcY
                exactDeltas[probeIndex] = (exactX, exactY)

                let estimated = evaluateSeries(
                    coefficientX: coefficientX,
                    coefficientY: coefficientY,
                    deltaX: dcX,
                    deltaY: dcY
                )
                let error = hypot(estimated.x - exactX, estimated.y - exactY)
                let tolerance = max(2e-15, hypot(exactX, exactY) * 1e-11)
                if !error.isFinite || error > tolerance {
                    valid = false
                    break
                }
            }

            guard valid else { break }
            let completedIteration = iteration + 1
            if completedIteration >= 16 {
                latestValid = TripleDoubleSeriesApproximation(
                    iteration: completedIteration,
                    coefficientX: coefficientX,
                    coefficientY: coefficientY
                )
            }
            let previous = checkpoints.last?.iteration
            let spacing = max(16, (previous ?? 0) / 3)
            if completedIteration >= 16,
               previous == nil || completedIteration >= previous! + spacing {
                checkpoints.append(latestValid!)
            }
        }

        if let latestValid,
           checkpoints.last?.iteration != latestValid.iteration {
            checkpoints.append(latestValid)
        }
        return checkpoints
    }

    private static func evaluateSeries(
        coefficientX: [Double],
        coefficientY: [Double],
        deltaX: Double,
        deltaY: Double
    ) -> (x: Double, y: Double) {
        var resultX = 0.0
        var resultY = 0.0

        for index in coefficientX.indices.reversed() {
            let multipliedX = resultX * deltaX - resultY * deltaY
            let multipliedY = resultX * deltaY + resultY * deltaX
            resultX = multipliedX + coefficientX[index]
            resultY = multipliedY + coefficientY[index]
        }

        return (
            resultX * deltaX - resultY * deltaY,
            resultX * deltaY + resultY * deltaX
        )
    }

    static func makeReferenceGrid(
        viewport: TripleDoubleViewport,
        aspectRatio: Double,
        maxIterations: Int
    ) -> [TripleDoublePerturbationReference] {
        let offsets = [-0.5, 0.0, 0.5]

        return offsets.flatMap { verticalOffset in
            offsets.map { horizontalFraction in
                let horizontalOffset = horizontalFraction * aspectRatio
                return TripleDoublePerturbationReference(
                    horizontalOffset: horizontalOffset,
                    verticalOffset: verticalOffset,
                    orbit: makeReferenceOrbit(
                        centerX: viewport.centerX
                            + viewport.scale * horizontalOffset,
                        centerY: viewport.centerY
                            + viewport.scale * verticalOffset,
                        maxIterations: maxIterations
                    )
                )
            }
        }
    }

    /// Builds one reference orbit with guard precision, then projects the
    /// orbit to Double for the inexpensive per-pixel perturbation recurrence.
    /// The extra components are deliberately confined to reference creation.
    static func makeGuardedReference(
        viewport: TripleDoubleViewport,
        horizontalOffset: Double,
        verticalOffset: Double,
        maxIterations: Int,
        componentLimit: Int = 6
    ) -> TripleDoublePerturbationReference {
        let precisionScale = VariablePrecisionFloat(
            viewport.scale,
            componentLimit: componentLimit
        )
        let cx = VariablePrecisionFloat(
            viewport.centerX,
            componentLimit: componentLimit
        ) + precisionScale * horizontalOffset
        let cy = VariablePrecisionFloat(
            viewport.centerY,
            componentLimit: componentLimit
        ) + precisionScale * verticalOffset
        var zx = VariablePrecisionFloat(0, componentLimit: componentLimit)
        var zy = VariablePrecisionFloat(0, componentLimit: componentLimit)
        var orbitX = [0.0]
        var orbitY = [0.0]
        orbitX.reserveCapacity(maxIterations + 1)
        orbitY.reserveCapacity(maxIterations + 1)
        var escapedAt = maxIterations

        for iteration in 0..<maxIterations {
            let nextX = zx.squared() - zy.squared() + cx
            let nextY = 2.0 * zx * zy + cy
            zx = nextX
            zy = nextY
            orbitX.append(zx.doubleValue)
            orbitY.append(zy.doubleValue)

            if zx.squared() + zy.squared()
                > VariablePrecisionFloat(4, componentLimit: componentLimit) {
                escapedAt = iteration + 1
                break
            }
        }

        return TripleDoublePerturbationReference(
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            orbit: TripleDoubleReferenceOrbit(
                x: orbitX,
                y: orbitY,
                escapedAt: escapedAt
            )
        )
    }

    static func makeGuardedCentralReference(
        viewport: TripleDoubleViewport,
        maxIterations: Int,
        componentLimit: Int = 6
    ) -> TripleDoublePerturbationReference {
        makeGuardedReference(
            viewport: viewport,
            horizontalOffset: 0,
            verticalOffset: 0,
            maxIterations: maxIterations,
            componentLimit: componentLimit
        )
    }

    private static func makeGuardedReferences(
        viewport: TripleDoubleViewport,
        offsets: [(Double, Double)],
        maxIterations: Int,
        componentLimit: Int
    ) -> [TripleDoublePerturbationReference] {
        let results = TripleDoubleReferenceResults(count: offsets.count)

        DispatchQueue.concurrentPerform(iterations: offsets.count) { index in
            let offset = offsets[index]
            results.set(
                makeGuardedReference(
                    viewport: viewport,
                    horizontalOffset: offset.0,
                    verticalOffset: offset.1,
                    maxIterations: maxIterations,
                    componentLimit: componentLimit
                ),
                at: index
            )
        }
        return results.values
    }

    /// Eight concurrent candidates cover a stable 3×3 viewport grid around
    /// the separately generated centre reference.
    static func makeGuardedSatelliteReferences(
        viewport: TripleDoubleViewport,
        aspectRatio: Double,
        maxIterations: Int,
        componentLimit: Int = 6
    ) -> [TripleDoublePerturbationReference] {
        let fractions = [-0.36, 0.0, 0.36]
        let offsets = fractions.flatMap { verticalFraction in
            fractions.compactMap { horizontalFraction
                -> (Double, Double)? in
                guard horizontalFraction != 0 || verticalFraction != 0 else {
                    return nil
                }
                return (
                    horizontalFraction * aspectRatio,
                    verticalFraction
                )
            }
        }
        return makeGuardedReferences(
            viewport: viewport,
            offsets: offsets,
            maxIterations: maxIterations,
            componentLimit: componentLimit
        )
    }

    static func nearestReference(
        horizontalOffset: Double,
        verticalOffset: Double,
        references: [TripleDoublePerturbationReference]
    ) -> TripleDoublePerturbationReference? {
        references.min {
            let leftX = horizontalOffset - $0.horizontalOffset
            let leftY = verticalOffset - $0.verticalOffset
            let rightX = horizontalOffset - $1.horizontalOffset
            let rightY = verticalOffset - $1.verticalOffset
            return leftX * leftX + leftY * leftY
                < rightX * rightX + rightY * rightY
        }
    }

    /// Perturbs every pixel from the same central reference and transfers the
    /// current orbit delta to a neighboring reference only when it grows too
    /// large. The transfer happens at the same iteration and in orbit space,
    /// so no screen-space reference tiles are introduced.
    static func iterationWithLocalRebase(
        horizontalOffset: Double,
        verticalOffset: Double,
        scale: Double,
        references: [TripleDoublePerturbationReference],
        maxIterations: Int
    ) -> Int {
        acceleratedIterationWithLocalRebase(
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            scale: scale,
            references: references,
            approximation: nil,
            maxIterations: maxIterations
        ).iteration
    }

    static func acceleratedIterationWithLocalRebase(
        horizontalOffset: Double,
        verticalOffset: Double,
        scale: Double,
        references: [TripleDoublePerturbationReference],
        approximation: TripleDoubleSeriesApproximation?,
        maxIterations: Int
    ) -> TripleDoubleIterationResult {
        acceleratedIterationWithLocalRebase(
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            scale: scale,
            references: references,
            approximations: approximation.map { [$0] } ?? [],
            maxIterations: maxIterations
        )
    }

    static func acceleratedIterationWithLocalRebase(
        horizontalOffset: Double,
        verticalOffset: Double,
        scale: Double,
        references: [TripleDoublePerturbationReference],
        approximations: [TripleDoubleSeriesApproximation],
        maxIterations: Int
    ) -> TripleDoubleIterationResult {
        // Every pixel starts from the same reference. Screen-space selection
        // creates visible Voronoi tiles when two projected reference orbits
        // accumulate slightly different rounding errors. At guarded depths the
        // longest-lived orbit is the best-conditioned global anchor; the other
        // orbits are used only for state-preserving rebases. Series coefficients
        // are built around the centre, so their shallower path remains central.
        let initialReference = approximations.isEmpty
            ? references.max { $0.orbit.escapedAt < $1.orbit.escapedAt }
            : references.first(where: {
                $0.horizontalOffset == 0.0 && $0.verticalOffset == 0.0
            }) ?? references.first
        guard var reference = initialReference else {
            return TripleDoubleIterationResult(
                iteration: maxIterations,
                skippedIterations: 0
            )
        }

        var dx = 0.0
        var dy = 0.0
        var rebaseCount = 0
        var startIteration = 0
        let centralDeltaX = scale * horizontalOffset
        let centralDeltaY = scale * verticalOffset

        for approximation in approximations.reversed()
        where approximation.iteration < reference.orbit.x.count
            && approximation.iteration < reference.orbit.y.count {
            let estimated = evaluateSeries(
                coefficientX: approximation.coefficientX,
                coefficientY: approximation.coefficientY,
                deltaX: centralDeltaX,
                deltaY: centralDeltaY
            )
            let fullX = reference.orbit.x[approximation.iteration] + estimated.x
            let fullY = reference.orbit.y[approximation.iteration] + estimated.y
            let magnitude2 = fullX * fullX + fullY * fullY

            // A generous margin below the escape radius keeps boundary pixels
            // on the exact recurrence, where their escape iteration matters.
            if estimated.x.isFinite, estimated.y.isFinite, magnitude2 < 3.0 {
                dx = estimated.x
                dy = estimated.y
                startIteration = approximation.iteration
                break
            }
        }

        for iteration in startIteration..<maxIterations {
            if iteration + 1 >= reference.orbit.x.count
                || iteration + 1 >= reference.orbit.y.count {
                let currentX = reference.orbit.x[iteration] + dx
                let currentY = reference.orbit.y[iteration] + dy
                let candidate = references
                    .filter {
                        iteration + 1 < $0.orbit.x.count
                            && iteration + 1 < $0.orbit.y.count
                    }
                    .min {
                        let leftX = currentX - $0.orbit.x[iteration]
                        let leftY = currentY - $0.orbit.y[iteration]
                        let rightX = currentX - $1.orbit.x[iteration]
                        let rightY = currentY - $1.orbit.y[iteration]
                        return leftX * leftX + leftY * leftY
                            < rightX * rightX + rightY * rightY
                    }

                guard let candidate else {
                    return TripleDoubleIterationResult(
                        iteration: maxIterations,
                        skippedIterations: startIteration
                    )
                }
                reference = candidate
                dx = currentX - candidate.orbit.x[iteration]
                dy = currentY - candidate.orbit.y[iteration]
                rebaseCount += 1
            }

            guard iteration + 1 < reference.orbit.x.count,
                  iteration + 1 < reference.orbit.y.count else {
                return TripleDoubleIterationResult(
                    iteration: reference.orbit.escapedAt < maxIterations
                        ? reference.orbit.escapedAt
                        : maxIterations,
                    skippedIterations: startIteration
                )
            }

            let deltaX = scale
                * (horizontalOffset - reference.horizontalOffset)
            let deltaY = scale
                * (verticalOffset - reference.verticalOffset)
            let rx = reference.orbit.x[iteration]
            let ry = reference.orbit.y[iteration]
            let nextDX = 2.0 * (rx * dx - ry * dy)
                + (dx * dx - dy * dy)
                + deltaX
            let nextDY = 2.0 * (rx * dy + ry * dx)
                + 2.0 * dx * dy
                + deltaY

            dx = nextDX
            dy = nextDY

            let fullX = reference.orbit.x[iteration + 1] + dx
            let fullY = reference.orbit.y[iteration + 1] + dy
            if fullX * fullX + fullY * fullY > 4.0 {
                return TripleDoubleIterationResult(
                    iteration: iteration + 1,
                    skippedIterations: startIteration
                )
            }

            let currentDeltaSquared = dx * dx + dy * dy
            guard currentDeltaSquared.isFinite else {
                return TripleDoubleIterationResult(
                    iteration: iteration + 1,
                    skippedIterations: startIteration
                )
            }

            if currentDeltaSquared > 0.00001, rebaseCount < 8 {
                let candidate = references
                    .filter {
                        iteration + 1 < $0.orbit.x.count
                            && iteration + 1 < $0.orbit.y.count
                    }
                    .min {
                        let leftX = fullX - $0.orbit.x[iteration + 1]
                        let leftY = fullY - $0.orbit.y[iteration + 1]
                        let rightX = fullX - $1.orbit.x[iteration + 1]
                        let rightY = fullY - $1.orbit.y[iteration + 1]
                        return leftX * leftX + leftY * leftY
                            < rightX * rightX + rightY * rightY
                    }

                if let candidate {
                    let rebasedDX = fullX - candidate.orbit.x[iteration + 1]
                    let rebasedDY = fullY - candidate.orbit.y[iteration + 1]
                    let rebasedDeltaSquared =
                        rebasedDX * rebasedDX + rebasedDY * rebasedDY

                    if rebasedDeltaSquared < currentDeltaSquared {
                        reference = candidate
                        dx = rebasedDX
                        dy = rebasedDY
                        rebaseCount += 1
                    }
                }
            }
        }

        return TripleDoubleIterationResult(
            iteration: maxIterations,
            skippedIterations: startIteration
        )
    }


    /// Builds one reference orbit with TripleDouble arithmetic and stores its
    /// projected positions as Double. Orbit positions are normally order one;
    /// the extra precision is needed when adding the tiny viewport centre on
    /// every reference step, not when applying pixel-sized deltas afterward.
    static func makeReferenceOrbit(
        centerX: TripleDouble,
        centerY: TripleDouble,
        maxIterations: Int
    ) -> TripleDoubleReferenceOrbit {
        var xs: [Double] = [0.0]
        var ys: [Double] = [0.0]
        xs.reserveCapacity(maxIterations + 1)
        ys.reserveCapacity(maxIterations + 1)

        var x = TripleDouble.zero
        var y = TripleDouble.zero
        var escapedAt = maxIterations

        for iteration in 0..<maxIterations {
            let nextX = x.squared() - y.squared() + centerX
            let nextY = 2.0 * x * y + centerY
            x = nextX
            y = nextY
            xs.append(x.doubleValue)
            ys.append(y.doubleValue)

            if x.squared() + y.squared() > TripleDouble(4.0) {
                escapedAt = iteration + 1
                break
            }
        }

        return TripleDoubleReferenceOrbit(
            x: xs,
            y: ys,
            escapedAt: escapedAt
        )
    }

    /// Iterates a pixel delta around the TripleDouble reference orbit.
    static func iteration(
        deltaX: Double,
        deltaY: Double,
        reference: TripleDoubleReferenceOrbit,
        maxIterations: Int
    ) -> Int {
        var dx = 0.0
        var dy = 0.0
        let limit = min(maxIterations, reference.x.count - 1)

        for iteration in 0..<limit {
            let rx = reference.x[iteration]
            let ry = reference.y[iteration]
            let nextDX = 2.0 * (rx * dx - ry * dy)
                + (dx * dx - dy * dy)
                + deltaX
            let nextDY = 2.0 * (rx * dy + ry * dx)
                + 2.0 * dx * dy
                + deltaY
            dx = nextDX
            dy = nextDY

            let fullX = reference.x[iteration + 1] + dx
            let fullY = reference.y[iteration + 1] + dy
            if fullX * fullX + fullY * fullY > 4.0 {
                return iteration + 1
            }
        }

        return reference.escapedAt < maxIterations
            ? reference.escapedAt
            : maxIterations
    }

}
