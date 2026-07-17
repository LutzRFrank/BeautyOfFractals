import Foundation

@main
private enum SeriesApproximationBenchmark {
    static func main() {
        let viewport = TripleDoubleViewport(
            centerX: TripleDouble(
                hi: -1.98553972092420827,
                mid: 1.02560425037289523e-16,
                lo: 3.46729274823902897e-33
            ),
            centerY: TripleDouble(
                hi: -5.31904698440635147e-16,
                mid: -4.35254071565166860e-32,
                lo: -9.03781809275728321e-49
            ),
            scale: TripleDouble(
                hi: 1.83491755349385380e-14,
                mid: -1.45605666494383612e-30,
                lo: 8.15387306164897185e-47
            )
        )
        let maxIterations = 160_000
        let aspectRatio = 1180.0 / 740.0
        let scale = viewport.scale.doubleValue
        let references = TripleDoublePerturbation.makeReferenceGrid(
            viewport: viewport,
            aspectRatio: aspectRatio,
            maxIterations: maxIterations
        )
        guard let center = references.first(where: {
            $0.horizontalOffset == 0.0 && $0.verticalOffset == 0.0
        }) else {
            fatalError("No central reference generated")
        }
        let approximations = TripleDoublePerturbation.makeSeriesApproximations(
            scale: scale,
            aspectRatio: aspectRatio,
            reference: center.orbit,
            maxIterations: maxIterations
        )
        guard let approximation = approximations.last else {
            fatalError("No series approximation generated")
        }

        let offsets = stride(from: -0.48, through: 0.48, by: 0.16)
        var comparisons = 0
        var mismatches = 0
        let start = Date()

        for vertical in offsets {
            for horizontalFraction in offsets {
                let horizontal = horizontalFraction * aspectRatio
                let baseline = TripleDoublePerturbation.iterationWithLocalRebase(
                    horizontalOffset: horizontal,
                    verticalOffset: vertical,
                    scale: scale,
                    references: references,
                    maxIterations: maxIterations
                )
                let accelerated = TripleDoublePerturbation
                    .acceleratedIterationWithLocalRebase(
                        horizontalOffset: horizontal,
                        verticalOffset: vertical,
                        scale: scale,
                        references: references,
                        approximations: approximations,
                        maxIterations: maxIterations
                    )
                comparisons += 1
                if baseline != accelerated.iteration {
                    mismatches += 1
                    print(
                        "Mismatch offset=(\(horizontal),\(vertical)) "
                            + "baseline=\(baseline) accelerated=\(accelerated.iteration)"
                    )
                }
            }
        }

        print("Series checkpoints: \(approximations.count)")
        print("Series skip: \(approximation.iteration) iterations")
        print("Comparisons: \(comparisons), mismatches: \(mismatches)")
        print(String(format: "Elapsed: %.3fs", Date().timeIntervalSince(start)))
        guard mismatches == 0 else { exit(1) }
    }
}
