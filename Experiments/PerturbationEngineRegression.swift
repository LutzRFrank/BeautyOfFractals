import Foundation

private func directIteration(
    x0: Double,
    y0: Double,
    maxIterations: Int
) -> Int {
    var x = 0.0
    var y = 0.0

    for iteration in 0..<maxIterations {
        let nextX = x * x - y * y + x0
        let nextY = 2.0 * x * y + y0
        x = nextX
        y = nextY

        if x * x + y * y > 4.0 {
            return iteration + 1
        }
    }

    return maxIterations
}

private struct RegressionLocation {
    let centerX: Double
    let centerY: Double
    let scale: Double
    let maxIterations: Int
}

@main
private enum PerturbationEngineRegression {
    static func main() {
        let locations = [
            RegressionLocation(
                centerX: -0.743643887037151,
                centerY: 0.131825904205330,
                scale: 1e-6,
                maxIterations: 10_000
            ),
            RegressionLocation(
                centerX: -0.743643887037151,
                centerY: 0.131825904205330,
                scale: 1e-12,
                maxIterations: 10_000
            ),
            // Covers targets whose nearest reference has a different escape
            // time, so reference escape must not be copied to the target.
            RegressionLocation(
                centerX: -0.75,
                centerY: 0.0,
                scale: 0.2,
                maxIterations: 2_000
            )
        ]
        let offsets = [-0.48, -0.31, -0.07, 0.0, 0.19, 0.37, 0.49]
        var failures: [String] = []
        var comparisons = 0

        for location in locations {
            let references = PerturbationEngine.makeReferenceGrid(
                centerX: location.centerX,
                centerY: location.centerY,
                scale: location.scale,
                aspectRatio: 1.0,
                maxIterations: location.maxIterations
            )

            for oy in offsets {
                for ox in offsets {
                    let x = location.centerX + ox * location.scale
                    let y = location.centerY + oy * location.scale
                    let expected = directIteration(
                        x0: x,
                        y0: y,
                        maxIterations: location.maxIterations
                    )
                    var cache = PerturbationReferenceCache(references: references)
                    let result = PerturbationEngine
                        .perturbationIterationWithCachedRebase(
                            x0: x,
                            y0: y,
                            cache: &cache,
                            maxIterations: location.maxIterations,
                            maximumCachedReferences: references.count + 8
                        )
                    comparisons += 1

                    if !result.reliable || result.iteration != expected {
                        failures.append(
                            "scale=\(location.scale) offset=(\(ox),\(oy)) "
                                + "expected=\(expected) actual=\(result.iteration) "
                                + "reliable=\(result.reliable)"
                        )
                    }
                }
            }
        }

        guard failures.isEmpty else {
            for failure in failures.prefix(20) {
                print("FAIL \(failure)")
            }
            fatalError("\(failures.count) of \(comparisons) comparisons failed")
        }

        print("PASS: \(comparisons) direct/perturbation comparisons")
    }
}
