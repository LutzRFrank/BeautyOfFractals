import Foundation

// BeautyOfFractals
//
// TripleDouble.swift
//
// Extended floating-point arithmetic represented by a three-component
// expansion. The components are kept in descending order of significance.

nonisolated struct TripleDouble: Sendable, Equatable, Comparable {
    let hi: Double
    let mid: Double
    let lo: Double

    init(_ value: Double) {
        hi = value
        mid = 0.0
        lo = 0.0
    }

    init(_ value: DoubleDouble) {
        self.init(hi: value.hi, mid: value.lo, lo: 0.0)
    }

    init(hi: Double, mid: Double, lo: Double) {
        let normalized = Self.normalized([lo, mid, hi])
        self.hi = normalized.hi
        self.mid = normalized.mid
        self.lo = normalized.lo
    }

    var doubleValue: Double {
        hi + mid + lo
    }

    var doubleDoubleValue: DoubleDouble {
        DoubleDouble(hi: hi, lo: mid + lo)
    }

    var isFinite: Bool {
        hi.isFinite && mid.isFinite && lo.isFinite
    }

    var magnitude: Double {
        abs(hi) + abs(mid) + abs(lo)
    }

    static let zero = TripleDouble(0.0)
    static let one = TripleDouble(1.0)

    static func < (lhs: TripleDouble, rhs: TripleDouble) -> Bool {
        if lhs.hi != rhs.hi {
            return lhs.hi < rhs.hi
        }
        if lhs.mid != rhs.mid {
            return lhs.mid < rhs.mid
        }
        return lhs.lo < rhs.lo
    }

    static prefix func - (value: TripleDouble) -> TripleDouble {
        TripleDouble(hi: -value.hi, mid: -value.mid, lo: -value.lo)
    }

    static func + (lhs: TripleDouble, rhs: TripleDouble) -> TripleDouble {
        fromExpansion(
            expansionSum(lhs.expansion, rhs.expansion)
        )
    }

    static func - (lhs: TripleDouble, rhs: TripleDouble) -> TripleDouble {
        lhs + (-rhs)
    }

    static func * (lhs: TripleDouble, rhs: TripleDouble) -> TripleDouble {
        var terms: [Double] = []
        terms.reserveCapacity(18)

        for left in lhs.expansion {
            for right in rhs.expansion {
                let product = twoProduct(left, right)
                if product.error != 0.0 {
                    terms.append(product.error)
                }
                if product.product != 0.0 {
                    terms.append(product.product)
                }
            }
        }

        return fromExpansion(exactExpansion(terms))
    }

    static func / (lhs: TripleDouble, rhs: Double) -> TripleDouble {
        precondition(rhs != 0.0, "Division by zero")

        let first = lhs.hi / rhs
        var remainder = lhs - TripleDouble(first) * rhs
        let second = remainder.hi / rhs
        remainder = remainder - TripleDouble(second) * rhs
        let third = remainder.hi / rhs

        return TripleDouble(first) + TripleDouble(second) + TripleDouble(third)
    }

    static func + (lhs: TripleDouble, rhs: Double) -> TripleDouble {
        lhs + TripleDouble(rhs)
    }

    static func + (lhs: Double, rhs: TripleDouble) -> TripleDouble {
        TripleDouble(lhs) + rhs
    }

    static func - (lhs: TripleDouble, rhs: Double) -> TripleDouble {
        lhs - TripleDouble(rhs)
    }

    static func - (lhs: Double, rhs: TripleDouble) -> TripleDouble {
        TripleDouble(lhs) - rhs
    }

    static func * (lhs: TripleDouble, rhs: Double) -> TripleDouble {
        lhs * TripleDouble(rhs)
    }

    static func * (lhs: Double, rhs: TripleDouble) -> TripleDouble {
        TripleDouble(lhs) * rhs
    }

    func squared() -> TripleDouble {
        self * self
    }

    private var expansion: [Double] {
        [lo, mid, hi].filter { $0 != 0.0 }
    }

    private static func fromExpansion(_ expansion: [Double]) -> TripleDouble {
        let value = normalized(expansion)
        return TripleDouble(uncheckedHi: value.hi, mid: value.mid, lo: value.lo)
    }

    private init(uncheckedHi hi: Double, mid: Double, lo: Double) {
        self.hi = hi
        self.mid = mid
        self.lo = lo
    }

    /// Reduces an exact expansion to its three most significant components.
    private static func normalized(
        _ components: [Double]
    ) -> (hi: Double, mid: Double, lo: Double) {
        let expansion = exactExpansion(components)
        guard !expansion.isEmpty else {
            return (0.0, 0.0, 0.0)
        }

        if expansion.count == 1 {
            return (expansion[0], 0.0, 0.0)
        }
        if expansion.count == 2 {
            return (expansion[1], expansion[0], 0.0)
        }

        let hi = expansion[expansion.count - 1]
        let mid = expansion[expansion.count - 2]
        var lowExpansion: [Double] = []
        for component in expansion.dropLast(2) {
            lowExpansion = growExpansion(lowExpansion, component)
        }
        let lo = lowExpansion.reversed().reduce(0.0, +)

        return (hi, mid, lo)
    }

    /// Builds a non-overlapping expansion in increasing magnitude order.
    private static func exactExpansion(_ components: [Double]) -> [Double] {
        var result: [Double] = []
        for component in components
            .filter({ $0 != 0.0 })
            .sorted(by: { abs($0) < abs($1) }) {
            result = growExpansion(result, component)
        }
        return result
    }

    private static func expansionSum(_ lhs: [Double], _ rhs: [Double]) -> [Double] {
        exactExpansion(lhs + rhs)
    }

    private static func growExpansion(_ expansion: [Double], _ value: Double) -> [Double] {
        var result: [Double] = []
        result.reserveCapacity(expansion.count + 1)
        var accumulator = value

        for component in expansion {
            let sum = twoSum(accumulator, component)
            if sum.error != 0.0 {
                result.append(sum.error)
            }
            accumulator = sum.sum
        }

        if accumulator != 0.0 || result.isEmpty {
            result.append(accumulator)
        }
        return result
    }

    private static func twoSum(_ a: Double, _ b: Double) -> (sum: Double, error: Double) {
        let sum = a + b
        let bVirtual = sum - a
        let aVirtual = sum - bVirtual
        let bError = b - bVirtual
        let aError = a - aVirtual
        return (sum, aError + bError)
    }

    private static func twoProduct(
        _ a: Double,
        _ b: Double
    ) -> (product: Double, error: Double) {
        let product = a * b
        let error = (-product).addingProduct(a, b)
        return (product, error)
    }
}
