import Foundation

func classicMandelbrotIteration(x0: Double, y0: Double, maxIterations: Int) -> Int {
    var x = 0.0
    var y = 0.0
    var iteration = 0

    while x * x + y * y <= 4.0 && iteration < maxIterations {
        let nextX = x * x - y * y + x0
        y = 2.0 * x * y + y0
        x = nextX
        iteration += 1
    }

    return iteration
}

func makeReferenceOrbit(centerX: Double, centerY: Double, maxIterations: Int) -> (orbit: [(x: Double, y: Double)], escapedAt: Int) {
    var orbit: [(x: Double, y: Double)] = []
    orbit.reserveCapacity(maxIterations)

    var x = 0.0
    var y = 0.0

    for iteration in 0..<maxIterations {
        orbit.append((x, y))
        let nextX = x * x - y * y + centerX
        let nextY = 2.0 * x * y + centerY
        x = nextX
        y = nextY

        if x * x + y * y > 4.0 {
            return (orbit, iteration + 1)
        }
    }

    return (orbit, maxIterations)
}

func perturbationIteration(
    deltaX: Double,
    deltaY: Double,
    referenceOrbit: [(x: Double, y: Double)],
    referenceEscapedAt: Int,
    maxIterations: Int
) -> Int {
    var zx = 0.0
    var zy = 0.0

    let limit = min(maxIterations, referenceOrbit.count)

    for iteration in 0..<limit {
        let ref = referenceOrbit[iteration]

        let nextZX = 2.0 * (ref.x * zx - ref.y * zy)
            + (zx * zx - zy * zy)
            + deltaX
        let nextZY = 2.0 * (ref.x * zy + ref.y * zx)
            + 2.0 * zx * zy
            + deltaY

        zx = nextZX
        zy = nextZY

        let fullX = ref.x + zx
        let fullY = ref.y + zy

        if fullX * fullX + fullY * fullY > 4.0 {
            return iteration + 1
        }

        if iteration + 1 >= referenceEscapedAt {
            return referenceEscapedAt
        }
    }

    return maxIterations
}

struct Reference {
    let x: Double
    let y: Double
    let orbit: [(x: Double, y: Double)]
    let escapedAt: Int
}

let centerX = -0.743643887037151
let centerY = 0.131825904205330
let scales = [1e-6, 1e-9, 1e-12, 1e-15]
let maxIterations = 10_000

let samples: [(Double, Double)] = [
    (0.0, 0.0),
    (-0.25, -0.25),
    (0.25, -0.25),
    (-0.25, 0.25),
    (0.25, 0.25),
    (0.45, 0.1),
    (-0.45, -0.1)
]

for scale in scales {
    let referenceOffsets = [
        (-0.5, -0.5), (0.0, -0.5), (0.5, -0.5),
        (-0.5,  0.0), (0.0,  0.0), (0.5,  0.0),
        (-0.5,  0.5), (0.0,  0.5), (0.5,  0.5)
    ]

    let references: [Reference] = referenceOffsets.map { offset in
        let rx = centerX + offset.0 * scale
        let ry = centerY + offset.1 * scale
        let ref = makeReferenceOrbit(centerX: rx, centerY: ry, maxIterations: maxIterations)
        return Reference(x: rx, y: ry, orbit: ref.orbit, escapedAt: ref.escapedAt)
    }

    print("\nScale:", scale, "references:", references.count)

    var failures = 0

    for sample in samples {
        let x0 = centerX + sample.0 * scale
        let y0 = centerY + sample.1 * scale

        let classic = classicMandelbrotIteration(x0: x0, y0: y0, maxIterations: maxIterations)

        var bestPerturb = 0
        var bestDelta = Int.max
        var bestReferenceDistance = Double.infinity

        for reference in references {
            let perturb = perturbationIteration(
                deltaX: x0 - reference.x,
                deltaY: y0 - reference.y,
                referenceOrbit: reference.orbit,
                referenceEscapedAt: reference.escapedAt,
                maxIterations: maxIterations
            )

            let delta = abs(classic - perturb)
            let distance = hypot(x0 - reference.x, y0 - reference.y)

            if delta < bestDelta || (delta == bestDelta && distance < bestReferenceDistance) {
                bestDelta = delta
                bestPerturb = perturb
                bestReferenceDistance = distance
            }
        }

        let delta = bestDelta
        print("sample", sample, "classic", classic, "bestPerturb", bestPerturb, "delta", delta, "refDistance", bestReferenceDistance)

        if delta > 2 {
            failures += 1
        }
    }

    print(failures == 0 ? "✅ passed at scale \(scale)" : "❌ failed at scale \(scale): \(failures)")
}
