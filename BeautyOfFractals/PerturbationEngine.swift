import Foundation

struct PerturbationOrbit {
    let x: [Double]
    let y: [Double]
    let escapedAt: Int
}

struct PerturbationReference {
    let centerX: Double
    let centerY: Double
    let orbit: PerturbationOrbit
}

enum PerturbationEngine {
    static func makeReferenceOrbit(
        centerX: Double,
        centerY: Double,
        maxIterations: Int
    ) -> PerturbationOrbit {
        var xs: [Double] = []
        var ys: [Double] = []
        xs.reserveCapacity(maxIterations)
        ys.reserveCapacity(maxIterations)

        var x = 0.0
        var y = 0.0

        for iteration in 0..<maxIterations {
            xs.append(x)
            ys.append(y)

            let nextX = x * x - y * y + centerX
            let nextY = 2.0 * x * y + centerY

            x = nextX
            y = nextY

            if x * x + y * y > 4.0 {
                return PerturbationOrbit(x: xs, y: ys, escapedAt: iteration + 1)
            }
        }

        return PerturbationOrbit(x: xs, y: ys, escapedAt: maxIterations)
    }

    static func makeReferenceGrid(
        centerX: Double,
        centerY: Double,
        scale: Double,
        aspectRatio: Double,
        maxIterations: Int
    ) -> [PerturbationReference] {
        let offsets = [-0.5, 0.0, 0.5]

        return offsets.flatMap { oy in
            offsets.map { ox in
                let rx = centerX + ox * scale * aspectRatio
                let ry = centerY + oy * scale

                return PerturbationReference(
                    centerX: rx,
                    centerY: ry,
                    orbit: makeReferenceOrbit(
                        centerX: rx,
                        centerY: ry,
                        maxIterations: maxIterations
                    )
                )
            }
        }
    }

    static func nearestReference(
        forX x: Double,
        y: Double,
        references: [PerturbationReference]
    ) -> PerturbationReference? {
        references.min {
            let da = squaredDistance(x, y, $0.centerX, $0.centerY)
            let db = squaredDistance(x, y, $1.centerX, $1.centerY)
            return da < db
        }
    }

    static func perturbationIteration(
        x0: Double,
        y0: Double,
        reference: PerturbationReference,
        maxIterations: Int
    ) -> Int {
        var zx = 0.0
        var zy = 0.0

        let orbit = reference.orbit
        let limit = min(maxIterations, orbit.x.count, orbit.y.count)

        let deltaX = x0 - reference.centerX
        let deltaY = y0 - reference.centerY

        for iteration in 0..<limit {
            let rx = orbit.x[iteration]
            let ry = orbit.y[iteration]

            let nextZX = 2.0 * (rx * zx - ry * zy)
                + (zx * zx - zy * zy)
                + deltaX
            let nextZY = 2.0 * (rx * zy + ry * zx)
                + 2.0 * zx * zy
                + deltaY

            zx = nextZX
            zy = nextZY

            let fullX = rx + zx
            let fullY = ry + zy

            if fullX * fullX + fullY * fullY > 4.0 {
                return iteration + 1
            }

            if iteration + 1 >= orbit.escapedAt {
                return orbit.escapedAt
            }
        }

        return maxIterations
    }

    private static func squaredDistance(
        _ ax: Double,
        _ ay: Double,
        _ bx: Double,
        _ by: Double
    ) -> Double {
        let dx = ax - bx
        let dy = ay - by
        return dx * dx + dy * dy
    }
}
