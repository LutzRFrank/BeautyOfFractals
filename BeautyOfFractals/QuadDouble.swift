import Foundation

/// Fixed four-component floating-point expansion (~212 significand bits).
/// It is the next accuracy tier above TripleDouble for ultra-deep reference
/// calculations; pixel iterations can continue to use cheaper arithmetic.
nonisolated struct QuadDouble: Sendable, Equatable, Comparable {
    let hi: Double
    let upperMid: Double
    let lowerMid: Double
    let lo: Double

    init(_ value: Double) {
        hi = value
        upperMid = 0
        lowerMid = 0
        lo = 0
    }

    init(_ value: TripleDouble) {
        self.init(hi: value.hi, upperMid: value.mid, lowerMid: value.lo, lo: 0)
    }

    init(hi: Double, upperMid: Double, lowerMid: Double, lo: Double) {
        let value = Self.normalized([lo, lowerMid, upperMid, hi])
        self.hi = value.0
        self.upperMid = value.1
        self.lowerMid = value.2
        self.lo = value.3
    }

    private init(unchecked: (Double, Double, Double, Double)) {
        hi = unchecked.0
        upperMid = unchecked.1
        lowerMid = unchecked.2
        lo = unchecked.3
    }

    static let zero = QuadDouble(0)
    static let one = QuadDouble(1)

    var isFinite: Bool {
        hi.isFinite && upperMid.isFinite && lowerMid.isFinite && lo.isFinite
    }

    static func < (lhs: QuadDouble, rhs: QuadDouble) -> Bool {
        if lhs.hi != rhs.hi { return lhs.hi < rhs.hi }
        if lhs.upperMid != rhs.upperMid { return lhs.upperMid < rhs.upperMid }
        if lhs.lowerMid != rhs.lowerMid { return lhs.lowerMid < rhs.lowerMid }
        return lhs.lo < rhs.lo
    }

    static prefix func - (value: QuadDouble) -> QuadDouble {
        QuadDouble(
            hi: -value.hi,
            upperMid: -value.upperMid,
            lowerMid: -value.lowerMid,
            lo: -value.lo
        )
    }

    static func + (lhs: QuadDouble, rhs: QuadDouble) -> QuadDouble {
        fromExpansion(lhs.expansion + rhs.expansion)
    }

    static func - (lhs: QuadDouble, rhs: QuadDouble) -> QuadDouble {
        lhs + (-rhs)
    }

    static func * (lhs: QuadDouble, rhs: QuadDouble) -> QuadDouble {
        var terms: [Double] = []
        terms.reserveCapacity(32)
        for left in lhs.expansion {
            for right in rhs.expansion {
                let product = twoProduct(left, right)
                if product.error != 0 { terms.append(product.error) }
                if product.product != 0 { terms.append(product.product) }
            }
        }
        return fromExpansion(terms)
    }

    static func + (lhs: QuadDouble, rhs: Double) -> QuadDouble {
        lhs + QuadDouble(rhs)
    }

    static func + (lhs: Double, rhs: QuadDouble) -> QuadDouble { rhs + lhs }

    static func - (lhs: QuadDouble, rhs: Double) -> QuadDouble {
        lhs - QuadDouble(rhs)
    }

    static func * (lhs: QuadDouble, rhs: Double) -> QuadDouble {
        lhs * QuadDouble(rhs)
    }

    static func * (lhs: Double, rhs: QuadDouble) -> QuadDouble { rhs * lhs }

    func squared() -> QuadDouble { self * self }

    private var expansion: [Double] {
        [lo, lowerMid, upperMid, hi].filter { $0 != 0 }
    }

    private static func fromExpansion(_ components: [Double]) -> QuadDouble {
        QuadDouble(unchecked: normalized(components))
    }

    private static func normalized(
        _ components: [Double]
    ) -> (Double, Double, Double, Double) {
        let exact = exactExpansion(components)
        guard !exact.isEmpty else { return (0, 0, 0, 0) }

        let hi = exact.last ?? 0
        let upperMid = exact.count >= 2 ? exact[exact.count - 2] : 0
        let lowerMid = exact.count >= 3 ? exact[exact.count - 3] : 0
        var remainder: [Double] = []
        if exact.count > 3 {
            for component in exact.dropLast(3) {
                remainder = growExpansion(remainder, component)
            }
        }
        let lo = remainder.reversed().reduce(0, +)
        return (hi, upperMid, lowerMid, lo)
    }

    private static func exactExpansion(_ components: [Double]) -> [Double] {
        var result: [Double] = []
        for component in components
            .filter({ $0 != 0 })
            .sorted(by: { abs($0) < abs($1) }) {
            result = growExpansion(result, component)
        }
        return result
    }

    private static func growExpansion(_ expansion: [Double], _ value: Double) -> [Double] {
        var result: [Double] = []
        var accumulator = value
        for component in expansion {
            let sum = twoSum(accumulator, component)
            if sum.error != 0 { result.append(sum.error) }
            accumulator = sum.sum
        }
        if accumulator != 0 || result.isEmpty { result.append(accumulator) }
        return result
    }

    private static func twoSum(_ a: Double, _ b: Double) -> (sum: Double, error: Double) {
        let sum = a + b
        let bVirtual = sum - a
        let aVirtual = sum - bVirtual
        return (sum, (a - aVirtual) + (b - bVirtual))
    }

    private static func twoProduct(
        _ a: Double,
        _ b: Double
    ) -> (product: Double, error: Double) {
        let product = a * b
        return (product, (-product).addingProduct(a, b))
    }
}
