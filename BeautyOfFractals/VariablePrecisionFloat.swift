import Foundation

/// A configurable non-overlapping Double expansion. This correctness-first
/// implementation is used to determine the precision required by ultra-deep
/// reference orbits before a specialized fast tier is selected.
nonisolated struct VariablePrecisionFloat: Sendable, Comparable {
    private(set) var components: [Double] // increasing magnitude
    let componentLimit: Int

    init(_ value: Double, componentLimit: Int) {
        precondition(componentLimit >= 2)
        components = value == 0 ? [] : [value]
        self.componentLimit = componentLimit
    }

    init(_ value: TripleDouble, componentLimit: Int) {
        self.init(
            components: [value.lo, value.mid, value.hi],
            componentLimit: componentLimit
        )
    }

    private init(components: [Double], componentLimit: Int) {
        self.componentLimit = componentLimit
        self.components = Self.truncated(
            Self.exactExpansion(components),
            to: componentLimit
        )
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.componentLimit == rhs.componentLimit && lhs.components == rhs.components
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        precondition(lhs.componentLimit == rhs.componentLimit)
        let difference = lhs - rhs
        return (difference.components.last ?? 0) < 0
    }

    static prefix func - (value: Self) -> Self {
        Self(
            components: value.components.map(-),
            componentLimit: value.componentLimit
        )
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        precondition(lhs.componentLimit == rhs.componentLimit)
        return Self(
            components: lhs.components + rhs.components,
            componentLimit: lhs.componentLimit
        )
    }

    static func - (lhs: Self, rhs: Self) -> Self { lhs + (-rhs) }

    static func * (lhs: Self, rhs: Self) -> Self {
        precondition(lhs.componentLimit == rhs.componentLimit)
        var terms: [Double] = []
        terms.reserveCapacity(lhs.components.count * rhs.components.count * 2)
        for left in lhs.components {
            for right in rhs.components {
                let product = left * right
                let error = (-product).addingProduct(left, right)
                if error != 0 { terms.append(error) }
                if product != 0 { terms.append(product) }
            }
        }
        return Self(components: terms, componentLimit: lhs.componentLimit)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        lhs * Self(rhs, componentLimit: lhs.componentLimit)
    }

    static func * (lhs: Double, rhs: Self) -> Self { rhs * lhs }

    func squared() -> Self { self * self }

    var doubleValue: Double {
        components.reversed().reduce(0, +)
    }

    private static func truncated(_ expansion: [Double], to limit: Int) -> [Double] {
        guard expansion.count > limit else { return expansion }
        let retained = Array(expansion.suffix(limit - 1))
        let remainder = expansion.dropLast(limit - 1).reversed().reduce(0, +)
        return exactExpansion([remainder] + retained)
    }

    private static func exactExpansion(_ values: [Double]) -> [Double] {
        var result: [Double] = []
        for value in values.filter({ $0 != 0 }).sorted(by: { abs($0) < abs($1) }) {
            var grown: [Double] = []
            var accumulator = value
            for component in result {
                let sum = accumulator + component
                let virtual = sum - accumulator
                let error = (accumulator - (sum - virtual)) + (component - virtual)
                if error != 0 { grown.append(error) }
                accumulator = sum
            }
            if accumulator != 0 || grown.isEmpty { grown.append(accumulator) }
            result = grown
        }
        return result
    }
}
