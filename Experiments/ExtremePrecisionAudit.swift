import Foundation

@main
private enum ExtremePrecisionAudit {
    static func main() {
        let viewport = TripleDoubleViewport(
            centerX: TripleDouble(
                hi: Double(bitPattern: 0xbffc1f84423c3598),
                mid: Double(bitPattern: 0xbc6d578b7c80e791),
                lo: Double(bitPattern: 0xb9020a2fcaab242a)
            ),
            centerY: TripleDouble(
                hi: Double(bitPattern: 0xbf921acbc0c781a5),
                mid: Double(bitPattern: 0x3c1861014c758a2d),
                lo: Double(bitPattern: 0x38ac2e707b5dff74)
            ),
            scale: TripleDouble(
                hi: Double(bitPattern: 0x35f0253cb2d2c37d),
                mid: Double(bitPattern: 0x3290b2e1d05ce617),
                lo: Double(bitPattern: 0xaf11109a35d10cf5)
            )
        )
        let maxIterations = 141_600
        let aspectRatio = 1440.0 / 900.0
        let projectedScale = viewport.scale.doubleValue
        let references = TripleDoublePerturbation.makeReferenceGrid(
            viewport: viewport,
            aspectRatio: aspectRatio,
            maxIterations: maxIterations
        )
        guard let center = references.first(where: {
            $0.horizontalOffset == 0.0 && $0.verticalOffset == 0.0
        }) else { fatalError("Missing central reference") }
        let approximations = TripleDoublePerturbation.makeSeriesApproximations(
            scale: projectedScale,
            aspectRatio: aspectRatio,
            reference: center.orbit,
            maxIterations: maxIterations
        )
        let centerDirect = calculateMandelbrotIterationTripleDouble(
            cX: viewport.centerX,
            cY: viewport.centerY,
            maxIterations: maxIterations
        )

        let horizontalFractions = [-0.4, 0.4]
        let verticalFractions = [-0.4, 0.4]
        var directVsBaseline = 0
        var directVsCentral = 0
        var baselineVsSeries = 0
        var directVsSeries = 0
        var largestDelta = 0
        var samples = 0
        let started = Date()

        for vertical in verticalFractions {
            for horizontalFraction in horizontalFractions {
                let horizontal = horizontalFraction * aspectRatio
                let direct = calculateMandelbrotIterationTripleDouble(
                    cX: viewport.centerX + viewport.scale * horizontal,
                    cY: viewport.centerY + viewport.scale * vertical,
                    maxIterations: maxIterations
                )
                let baseline = TripleDoublePerturbation.iterationWithLocalRebase(
                    horizontalOffset: horizontal,
                    verticalOffset: vertical,
                    scale: projectedScale,
                    references: references,
                    maxIterations: maxIterations
                )
                let central = TripleDoublePerturbation.iteration(
                    deltaX: projectedScale * horizontal,
                    deltaY: projectedScale * vertical,
                    reference: center.orbit,
                    maxIterations: maxIterations
                )
                let accelerated = TripleDoublePerturbation
                    .acceleratedIterationWithLocalRebase(
                        horizontalOffset: horizontal,
                        verticalOffset: vertical,
                        scale: projectedScale,
                        references: references,
                        approximations: approximations,
                        maxIterations: maxIterations
                    ).iteration

                samples += 1
                directVsBaseline += direct == baseline ? 0 : 1
                directVsCentral += direct == central ? 0 : 1
                baselineVsSeries += baseline == accelerated ? 0 : 1
                directVsSeries += direct == accelerated ? 0 : 1
                largestDelta = max(largestDelta, abs(direct - accelerated))
                if direct != baseline || direct != central
                    || baseline != accelerated {
                    print(
                        "offset=(\(horizontal), \(vertical)) "
                            + "direct=\(direct) central=\(central) "
                            + "baseline=\(baseline) "
                            + "series=\(accelerated)"
                    )
                }
            }
        }

        print("Samples: \(samples)")
        print("Center direct: \(centerDirect)")
        print("Series checkpoints: \(approximations.count)")
        print("Series skip: \(approximations.last?.iteration ?? 0)")
        print("Direct != baseline: \(directVsBaseline)")
        print("Direct != central: \(directVsCentral)")
        print("Baseline != series: \(baselineVsSeries)")
        print("Direct != series: \(directVsSeries)")
        print("Largest direct/series delta: \(largestDelta)")
        print(String(format: "Elapsed: %.3fs", Date().timeIntervalSince(started)))
    }
}
