@testable import SwiftSignal
import XCTest

final class GlitchFreeTests: XCTestCase {
    // should recompute only once for diamond dependency graph
    func testShouldRecomputeOnluOnceForDiamondDependencies() {
        var fullRecompute = 0

        let name = signal("John Doe")
        let first = computed { name().split(separator: " ")[0] }
        let last = computed { name().split(separator: " ")[1] }
        let full = computed {
            fullRecompute += 1
            return "\(first())/\(last())"
        }

        XCTAssertEqual(full(), "John/Doe")
        XCTAssertEqual(fullRecompute, 1)

        name.set("Bob Fisher")
        XCTAssertEqual(full(), "Bob/Fisher")
        XCTAssertEqual(fullRecompute, 2)
    }

    // should recompute only once
    func testShouldRecomputeOnlyOnce() {
        let a = signal("a")
        let b = computed { a() + "b" }
        var cRecompute = 0
        let c = computed {
            cRecompute += 1
            return "\(a())|\(b())|\(cRecompute)"
        }

        XCTAssertEqual(c(), "a|ab|1")

        a.set("A")
        XCTAssertEqual(c(), "A|Ab|2")
    }
}
