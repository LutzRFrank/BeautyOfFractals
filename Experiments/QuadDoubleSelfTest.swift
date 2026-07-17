import Foundation

@main
private enum QuadDoubleSelfTest {
    static func main() {
        let e1 = Double.ulpOfOne / 2
        let e2 = e1 * e1
        let e3 = e2 * e1
        let value = QuadDouble(1) + QuadDouble(e1) + QuadDouble(e2) + QuadDouble(e3)

        precondition(value.hi == 1)
        precondition(value.upperMid == e1)
        precondition(value.lowerMid == e2)
        precondition(value.lo == e3)
        precondition(value - QuadDouble(1) - QuadDouble(e1) - QuadDouble(e2) == QuadDouble(e3))

        let product = value * (QuadDouble(1) - QuadDouble(e1) + QuadDouble(e2))
        precondition(product.isFinite)
        precondition(product > QuadDouble.zero)
        print("QuadDouble self-test passed")
    }
}
