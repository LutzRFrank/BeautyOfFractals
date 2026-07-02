import Foundation

nonisolated struct PerturbationOrbit {
    let x: [Double]
    let y: [Double]
    let escapedAt: Int
}

nonisolated
struct PerturbationState {
    var zx: Double = 0.0
    var zy: Double = 0.0
    var iteration: Int = 0
    var reference: PerturbationReference
}

struct PerturbationIterationResult {
    let iteration: Int
    let reliable: Bool
    let rebaseCount: Int
    let firstRebaseIteration: Int?
}

struct PerturbationStepResult {
    let escaped: Bool
    let shouldRebase: Bool
    let iteration: Int
}

struct PerturbationReference {
    let centerX: Double
    let centerY: Double
    let orbit: PerturbationOrbit
}


nonisolated struct PerturbationReferenceCache {
    private(set) var references: [PerturbationReference]

    var count: Int {
        references.count
    }

    init(references: [PerturbationReference]) {
        self.references = references
    }

    mutating func nearestReference(
        forX x: Double,
        y: Double
    ) -> PerturbationReference? {
        PerturbationEngine.nearestReference(
            forX: x,
            y: y,
            references: references
        )
    }

    func nearestReferenceDistanceSquared(
        forX x: Double,
        y: Double
    ) -> Double {
        references
            .map { PerturbationEngine.squaredDistance(x, y, $0.centerX, $0.centerY) }
            .min() ?? .greatestFiniteMagnitude
    }

    mutating func cacheLocalReference(
        centerX: Double,
        centerY: Double,
        maxIterations: Int
    ) -> PerturbationReference {
        let reference = PerturbationReference(
            centerX: centerX,
            centerY: centerY,
            orbit: PerturbationEngine.makeReferenceOrbit(
                centerX: centerX,
                centerY: centerY,
                maxIterations: maxIterations
            )
        )

        // references.append(reference)
        references.append(reference)
        return reference
    }
}


nonisolated enum PerturbationEngine {
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
        let zoom = 3.0 / max(scale, 1e-30)
        let offsets = zoom >= 1e12
            ? [-0.5, -0.25, 0.0, 0.25, 0.5]
            : [-0.5, 0.0, 0.5]

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


    static func step(
        state: inout PerturbationState,
        targetX: Double,
        targetY: Double,
        maxIterations: Int
    ) -> PerturbationStepResult {
        let orbit = state.reference.orbit
        guard state.iteration < maxIterations,
              state.iteration < orbit.x.count,
              state.iteration < orbit.y.count else {
            return PerturbationStepResult(
                escaped: false,
                shouldRebase: false,
                iteration: maxIterations
            )
        }

        let deltaX = targetX - state.reference.centerX
        let deltaY = targetY - state.reference.centerY

        let rx = orbit.x[state.iteration]
        let ry = orbit.y[state.iteration]

        let nextZX = 2.0 * (rx * state.zx - ry * state.zy)
            + (state.zx * state.zx - state.zy * state.zy)
            + deltaX
        let nextZY = 2.0 * (rx * state.zy + ry * state.zx)
            + 2.0 * state.zx * state.zy
            + deltaY

        state.zx = nextZX
        state.zy = nextZY
        state.iteration += 1

        let fullX = rx + state.zx
        let fullY = ry + state.zy
        let magnitude2 = fullX * fullX + fullY * fullY

        if magnitude2 > 4.0 {
            return PerturbationStepResult(
                escaped: true,
                shouldRebase: false,
                iteration: state.iteration
            )
        }

        let deltaMagnitude2 = state.zx * state.zx + state.zy * state.zy
        let shouldRebase = deltaMagnitude2 > 0.00001

        if state.iteration >= orbit.escapedAt {
            return PerturbationStepResult(
                escaped: true,
                shouldRebase: false,
                iteration: orbit.escapedAt
            )
        }

        return PerturbationStepResult(
            escaped: false,
            shouldRebase: shouldRebase,
            iteration: state.iteration
        )
    }


    static func perturbationIterationWithCachedRebase(
        x0: Double,
        y0: Double,
        cache: inout PerturbationReferenceCache,
        maxIterations: Int,
        maximumCachedReferences: Int
    ) -> PerturbationIterationResult {
        guard let initialReference = cache.nearestReference(forX: x0, y: y0) else {
            return PerturbationIterationResult(
                iteration: maxIterations,
                reliable: false,
                rebaseCount: 0,
                firstRebaseIteration: nil
            )
        }

        var state = PerturbationState(reference: initialReference)
        var rebaseCount = 0
        var firstRebaseIteration: Int?

        while state.iteration < maxIterations {
            let result = step(
                state: &state,
                targetX: x0,
                targetY: y0,
                maxIterations: maxIterations
            )

            if result.escaped {
                return PerturbationIterationResult(
                    iteration: result.iteration,
                    reliable: true,
                    rebaseCount: rebaseCount,
                    firstRebaseIteration: firstRebaseIteration
                )
            }

            if result.shouldRebase {
                // A reference orbit for the exact target point has all global
                // orbit positions available. Reset only the delta; preserve the
                // absolute iteration so the next step continues at z_n, not z_0.
                guard cache.count < maximumCachedReferences,
                      rebaseCount < 4 else {
                    return PerturbationIterationResult(
                        iteration: result.iteration,
                        reliable: false,
                        rebaseCount: rebaseCount,
                        firstRebaseIteration: firstRebaseIteration
                    )
                }

                rebaseCount += 1
                if firstRebaseIteration == nil {
                    firstRebaseIteration = state.iteration
                }

                let preservedIteration = state.iteration
                let localReference = cache.cacheLocalReference(
                    centerX: x0,
                    centerY: y0,
                    maxIterations: maxIterations
                )

                state = PerturbationState(
                    zx: 0.0,
                    zy: 0.0,
                    iteration: preservedIteration,
                    reference: localReference
                )
            }
        }

        return PerturbationIterationResult(
            iteration: maxIterations,
            reliable: true,
            rebaseCount: rebaseCount,
            firstRebaseIteration: firstRebaseIteration
        )
    }

    static func perturbationIteration(
        x0: Double,
        y0: Double,
        reference: PerturbationReference,
        maxIterations: Int
    ) -> Int {
        var state = PerturbationState(reference: reference)

        while state.iteration < maxIterations {
            let result = step(
                state: &state,
                targetX: x0,
                targetY: y0,
                maxIterations: maxIterations
            )

            if result.escaped {
                return result.iteration
            }

            if result.iteration >= maxIterations {
                return maxIterations
            }
        }

        return maxIterations
    }

    static func squaredDistance(
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
