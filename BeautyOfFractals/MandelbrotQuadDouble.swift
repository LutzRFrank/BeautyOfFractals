import Foundation

/// Accuracy reference for ultra-deep Mandelbrot calculations.
nonisolated func calculateMandelbrotIterationQuadDouble(
    cX: QuadDouble,
    cY: QuadDouble,
    maxIterations: Int
) -> Int {
    var x = QuadDouble.zero
    var y = QuadDouble.zero

    for iteration in 0..<maxIterations {
        let nextX = x.squared() - y.squared() + cX
        let nextY = 2.0 * x * y + cY
        x = nextX
        y = nextY

        if x.squared() + y.squared() > QuadDouble(4.0) {
            return iteration + 1
        }
    }
    return maxIterations
}
