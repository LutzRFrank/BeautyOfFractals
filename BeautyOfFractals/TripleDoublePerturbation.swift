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

nonisolated enum TripleDoublePerturbation {
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
        guard var reference = references.first(where: {
            $0.horizontalOffset == 0.0 && $0.verticalOffset == 0.0
        }) ?? references.first else {
            return maxIterations
        }

        var dx = 0.0
        var dy = 0.0
        var rebaseCount = 0

        for iteration in 0..<maxIterations {
            guard iteration + 1 < reference.orbit.x.count,
                  iteration + 1 < reference.orbit.y.count else {
                return reference.orbit.escapedAt < maxIterations
                    ? reference.orbit.escapedAt
                    : maxIterations
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
                return iteration + 1
            }

            let currentDeltaSquared = dx * dx + dy * dy
            guard currentDeltaSquared.isFinite else {
                return iteration + 1
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

        return maxIterations
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
