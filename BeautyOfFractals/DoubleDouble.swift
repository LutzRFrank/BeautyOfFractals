import Foundation

// BeautyOfFractals
//
// DoubleDouble.swift
//
// Extended floating-point arithmetic built from a compensated pair of Doubles.
//
// DoubleDouble provides substantially more precision than a single Double
// while remaining lightweight enough for interactive deep-zoom navigation.
nonisolated struct DoubleDouble: Sendable, Equatable, Comparable {
    let hi: Double
    let lo: Double

    init(_ value: Double) {
        self.hi = value
        self.lo = 0.0
    }

    init(hi: Double, lo: Double) {
        let (sum, error) = Self.twoSum(hi, lo)
        self.hi = sum
        self.lo = error
    }

    var doubleValue: Double {
        hi + lo
    }

    var isFinite: Bool {
        hi.isFinite && lo.isFinite
    }

    var magnitude: Double {
        abs(hi) + abs(lo)
    }

    static let zero = DoubleDouble(0.0)
    static let one = DoubleDouble(1.0)

    static func < (lhs: DoubleDouble, rhs: DoubleDouble) -> Bool {
        lhs.hi == rhs.hi ? lhs.lo < rhs.lo : lhs.hi < rhs.hi
    }

    static prefix func - (value: DoubleDouble) -> DoubleDouble {
        DoubleDouble(hi: -value.hi, lo: -value.lo)
    }

    static func + (lhs: DoubleDouble, rhs: DoubleDouble) -> DoubleDouble {
        let (sum, error) = twoSum(lhs.hi, rhs.hi)
        let (renormalized, residual) = twoSum(sum, lhs.lo + rhs.lo)

        return DoubleDouble(
            hi: renormalized,
            lo: error + residual
        )
    }

    static func - (lhs: DoubleDouble, rhs: DoubleDouble) -> DoubleDouble {
        lhs + (-rhs)
    }

    static func * (lhs: DoubleDouble, rhs: DoubleDouble) -> DoubleDouble {
        let (product, productError) = twoProduct(lhs.hi, rhs.hi)

        let correction =
            productError
            + lhs.hi * rhs.lo
            + lhs.lo * rhs.hi
            + lhs.lo * rhs.lo

        return DoubleDouble(
            hi: product,
            lo: correction
        )
    }

    static func / (lhs: DoubleDouble, rhs: Double) -> DoubleDouble {
        precondition(rhs != 0.0, "Division by zero")

        let firstQuotient = lhs.hi / rhs
        let remainder = lhs - DoubleDouble(firstQuotient) * rhs
        let correction = (remainder.hi + remainder.lo) / rhs

        return DoubleDouble(firstQuotient) + DoubleDouble(correction)
    }

    static func + (lhs: DoubleDouble, rhs: Double) -> DoubleDouble {
        lhs + DoubleDouble(rhs)
    }

    static func + (lhs: Double, rhs: DoubleDouble) -> DoubleDouble {
        DoubleDouble(lhs) + rhs
    }

    static func - (lhs: DoubleDouble, rhs: Double) -> DoubleDouble {
        lhs - DoubleDouble(rhs)
    }

    static func - (lhs: Double, rhs: DoubleDouble) -> DoubleDouble {
        DoubleDouble(lhs) - rhs
    }

    static func * (lhs: DoubleDouble, rhs: Double) -> DoubleDouble {
        lhs * DoubleDouble(rhs)
    }

    static func * (lhs: Double, rhs: DoubleDouble) -> DoubleDouble {
        DoubleDouble(lhs) * rhs
    }

    func squared() -> DoubleDouble {
        self * self
    }

    private static func twoSum(
        _ a: Double,
        _ b: Double
    ) -> (sum: Double, error: Double) {
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

        let split = 134_217_729.0

        let aSplit = split * a
        let aHigh = aSplit - (aSplit - a)
        let aLow = a - aHigh

        let bSplit = split * b
        let bHigh = bSplit - (bSplit - b)
        let bLow = b - bHigh

        let error =
            ((aHigh * bHigh - product)
             + aHigh * bLow
             + aLow * bHigh)
            + aLow * bLow

        return (product, error)
    }
}
