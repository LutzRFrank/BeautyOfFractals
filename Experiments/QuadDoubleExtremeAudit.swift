import Foundation

@main
private enum QuadDoubleExtremeAudit {
    static func main() {
        let centerX = QuadDouble(TripleDouble(
            hi: Double(bitPattern: 0xbffc1f84423c3598),
            mid: Double(bitPattern: 0xbc6d578b7c80e791),
            lo: Double(bitPattern: 0xb9020a2fcaab242a)
        ))
        let centerY = QuadDouble(TripleDouble(
            hi: Double(bitPattern: 0xbf921acbc0c781a5),
            mid: Double(bitPattern: 0x3c1861014c758a2d),
            lo: Double(bitPattern: 0x38ac2e707b5dff74)
        ))
        let scale = QuadDouble(TripleDouble(
            hi: Double(bitPattern: 0x35f0253cb2d2c37d),
            mid: Double(bitPattern: 0x3290b2e1d05ce617),
            lo: Double(bitPattern: 0xaf11109a35d10cf5)
        ))
        let maxIterations = 141_600
        let reference = QuadDoublePerturbation.makeReferenceOrbit(
            centerX: centerX,
            centerY: centerY,
            maxIterations: maxIterations
        )
        let offsets = [(-0.64, -0.4), (0.64, -0.4), (-0.64, 0.4), (0.64, 0.4)]
        var mismatches = 0
        let started = Date()

        for offset in offsets {
            let dcX = scale * offset.0
            let dcY = scale * offset.1
            let direct = calculateMandelbrotIterationQuadDouble(
                cX: centerX + dcX,
                cY: centerY + dcY,
                maxIterations: maxIterations
            )
            let perturbed = QuadDoublePerturbation.iteration(
                deltaX: dcX,
                deltaY: dcY,
                reference: reference,
                maxIterations: maxIterations
            )
            if direct != perturbed { mismatches += 1 }
            print("offset=\(offset) direct=\(direct) perturbation=\(perturbed)")
        }

        print("Reference escape: \(reference.escapedAt)")
        print("Mismatches: \(mismatches)/\(offsets.count)")
        print(String(format: "Elapsed: %.3fs", Date().timeIntervalSince(started)))
        guard mismatches == 0 else { exit(1) }
    }
}
