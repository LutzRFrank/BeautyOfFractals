import Foundation

/// Direct Mandelbrot escape iteration using TripleDouble arithmetic.
///
/// This deliberately remains separate from the production renderer. It is the
/// correctness-first reference kernel for the later 3.0 deep-zoom path.
nonisolated func calculateMandelbrotIterationTripleDouble(
    cX: TripleDouble,
    cY: TripleDouble,
    maxIterations: Int
) -> Int {
    var x = TripleDouble.zero
    var y = TripleDouble.zero
    var iteration = 0

    let bailoutRadiusSquared = TripleDouble(4.0)

    while iteration < maxIterations {
        let magnitudeSquared = x.squared() + y.squared()

        if magnitudeSquared > bailoutRadiusSquared {
            break
        }

        let nextX = x.squared() - y.squared() + cX
        let nextY = 2.0 * x * y + cY

        x = nextX
        y = nextY
        iteration += 1
    }

    return iteration
}
