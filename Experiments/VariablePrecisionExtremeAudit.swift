import Foundation

@main
private enum VariablePrecisionExtremeAudit {
    static func main() {
        let centerXTD = TripleDouble(
            hi: Double(bitPattern: 0xbffc1f84423c3598),
            mid: Double(bitPattern: 0xbc6d578b7c80e791),
            lo: Double(bitPattern: 0xb9020a2fcaab242a)
        )
        let centerYTD = TripleDouble(
            hi: Double(bitPattern: 0xbf921acbc0c781a5),
            mid: Double(bitPattern: 0x3c1861014c758a2d),
            lo: Double(bitPattern: 0x38ac2e707b5dff74)
        )
        let scaleTD = TripleDouble(
            hi: Double(bitPattern: 0x35f0253cb2d2c37d),
            mid: Double(bitPattern: 0x3290b2e1d05ce617),
            lo: Double(bitPattern: 0xaf11109a35d10cf5)
        )
        let maxIterations = 141_600

        for precision in [6, 8] {
            let started = Date()
            let cx = VariablePrecisionFloat(centerXTD, componentLimit: precision)
            let cy = VariablePrecisionFloat(centerYTD, componentLimit: precision)
            let scale = VariablePrecisionFloat(scaleTD, componentLimit: precision)
            let dcX = scale * 0.64
            let dcY = scale * 0.4
            let direct = iterate(
                cX: cx + dcX,
                cY: cy + dcY,
                maxIterations: maxIterations
            )
            let reference = makeReference(
                cX: cx,
                cY: cy,
                maxIterations: maxIterations
            )
            let perturbed = perturb(
                deltaX: dcX,
                deltaY: dcY,
                reference: reference,
                maxIterations: maxIterations
            )
            print(
                "Components: \(precision), center: \(reference.escapedAt), "
                    + "direct: \(direct), perturbation: \(perturbed), "
                    + String(format: "elapsed: %.3fs", Date().timeIntervalSince(started))
            )
        }
    }

    private static func iterate(
        cX: VariablePrecisionFloat,
        cY: VariablePrecisionFloat,
        maxIterations: Int
    ) -> Int {
        let precision = cX.componentLimit
        var x = VariablePrecisionFloat(0, componentLimit: precision)
        var y = VariablePrecisionFloat(0, componentLimit: precision)
        let four = VariablePrecisionFloat(4, componentLimit: precision)
        for iteration in 0..<maxIterations {
            let nextX = x.squared() - y.squared() + cX
            let nextY = 2.0 * x * y + cY
            x = nextX
            y = nextY
            if x.squared() + y.squared() > four { return iteration + 1 }
        }
        return maxIterations
    }

    private struct Reference {
        let x: [VariablePrecisionFloat]
        let y: [VariablePrecisionFloat]
        let escapedAt: Int
    }

    private static func makeReference(
        cX: VariablePrecisionFloat,
        cY: VariablePrecisionFloat,
        maxIterations: Int
    ) -> Reference {
        let precision = cX.componentLimit
        var xs = [VariablePrecisionFloat(0, componentLimit: precision)]
        var ys = [VariablePrecisionFloat(0, componentLimit: precision)]
        var x = xs[0]
        var y = ys[0]
        let four = VariablePrecisionFloat(4, componentLimit: precision)
        var escapedAt = maxIterations
        for iteration in 0..<maxIterations {
            let nextX = x.squared() - y.squared() + cX
            let nextY = 2.0 * x * y + cY
            x = nextX
            y = nextY
            xs.append(x)
            ys.append(y)
            if x.squared() + y.squared() > four {
                escapedAt = iteration + 1
                break
            }
        }
        return Reference(x: xs, y: ys, escapedAt: escapedAt)
    }

    private static func perturb(
        deltaX: VariablePrecisionFloat,
        deltaY: VariablePrecisionFloat,
        reference: Reference,
        maxIterations: Int
    ) -> Int {
        let precision = deltaX.componentLimit
        var dx = VariablePrecisionFloat(0, componentLimit: precision)
        var dy = VariablePrecisionFloat(0, componentLimit: precision)
        let four = VariablePrecisionFloat(4, componentLimit: precision)
        let limit = min(maxIterations, reference.x.count - 1)
        for iteration in 0..<limit {
            let rx = reference.x[iteration]
            let ry = reference.y[iteration]
            let nextDX = 2.0 * (rx * dx - ry * dy)
                + (dx * dx - dy * dy) + deltaX
            let nextDY = 2.0 * (rx * dy + ry * dx)
                + 2.0 * dx * dy + deltaY
            dx = nextDX
            dy = nextDY
            let fullX = reference.x[iteration + 1] + dx
            let fullY = reference.y[iteration + 1] + dy
            if fullX.squared() + fullY.squared() > four { return iteration + 1 }
        }
        return reference.escapedAt
    }
}
