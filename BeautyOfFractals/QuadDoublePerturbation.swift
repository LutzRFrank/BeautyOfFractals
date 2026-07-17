import Foundation

nonisolated struct QuadDoubleReferenceOrbit: Sendable {
    let x: [QuadDouble]
    let y: [QuadDouble]
    let escapedAt: Int
}

nonisolated enum QuadDoublePerturbation {
    static func makeReferenceOrbit(
        centerX: QuadDouble,
        centerY: QuadDouble,
        maxIterations: Int
    ) -> QuadDoubleReferenceOrbit {
        var xs = [QuadDouble.zero]
        var ys = [QuadDouble.zero]
        xs.reserveCapacity(maxIterations + 1)
        ys.reserveCapacity(maxIterations + 1)

        var x = QuadDouble.zero
        var y = QuadDouble.zero
        var escapedAt = maxIterations
        for iteration in 0..<maxIterations {
            let nextX = x.squared() - y.squared() + centerX
            let nextY = 2.0 * x * y + centerY
            x = nextX
            y = nextY
            xs.append(x)
            ys.append(y)
            if x.squared() + y.squared() > QuadDouble(4.0) {
                escapedAt = iteration + 1
                break
            }
        }
        return QuadDoubleReferenceOrbit(x: xs, y: ys, escapedAt: escapedAt)
    }

    static func iteration(
        deltaX: QuadDouble,
        deltaY: QuadDouble,
        reference: QuadDoubleReferenceOrbit,
        maxIterations: Int
    ) -> Int {
        var dx = QuadDouble.zero
        var dy = QuadDouble.zero
        let limit = min(maxIterations, reference.x.count - 1)

        for iteration in 0..<limit {
            let rx = reference.x[iteration]
            let ry = reference.y[iteration]
            let nextDX = 2.0 * (rx * dx - ry * dy)
                + (dx * dx - dy * dy) + deltaX
            let nextDY = 2.0 * (rx * dy + ry * dx)
                + 2.0 * dx * dy + deltaY
            dx = nextDX
            dy = nextDY

            let fullX = reference.x[iteration + 1] + dx
            let fullY = reference.y[iteration + 1] + dy
            if fullX.squared() + fullY.squared() > QuadDouble(4.0) {
                return iteration + 1
            }
        }
        return reference.escapedAt < maxIterations
            ? reference.escapedAt
            : maxIterations
    }
}
