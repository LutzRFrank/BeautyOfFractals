import Foundation

/// Direct Mandelbrot escape iteration using DoubleDouble arithmetic.
///
/// This is intentionally separate from the existing fast Double renderer.
/// It is the kernel for a later extreme-zoom CPU path.
nonisolated func calculateMandelbrotIterationDoubleDouble(
    cX: DoubleDouble,
    cY: DoubleDouble,
    maxIterations: Int
) -> Int {
    var x = DoubleDouble.zero
    var y = DoubleDouble.zero
    var iteration = 0

    let bailoutRadiusSquared = DoubleDouble(4.0)

    while iteration < maxIterations {
        let magnitudeSquared = x * x + y * y

        if magnitudeSquared > bailoutRadiusSquared {
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
