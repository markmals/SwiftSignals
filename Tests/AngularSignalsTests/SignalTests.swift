import SwiftSignal
import XCTest

final class SignalTests: XCTestCase {
    // should be a getter which reflects the set value
    func testGetterSetter() {
        let state = signal(false)
        XCTAssertFalse(state())
        state.set(true)
        XCTAssertTrue(state())
    }

    // should accept update method to set a new value based on the previous one
    func testUpdate() {
        let counter = signal(1)
        XCTAssertEqual(counter(), 1)

        counter.update { $0 + 1 }
        XCTAssertEqual(counter(), 2)
    }

    // should have mutate method for mutable, out of bound updates
    func testMutate() {
        let state = signal(["a"])
        XCTAssertEqual(state(), ["a"])

        state.mutate { $0.append("b") }
        XCTAssertEqual(state(), ["a", "b"])
    }

    // should not propagate change when the new signal value is equal to the previous one
    func testEquality() {
        struct StringCount: Equatable {
            let string: String
            init(_ string: String) {
                self.string = string
            }

            static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.string.count == rhs.string.count
            }
        }

        let state = signal(StringCount("aaa"))

        // set to a "different" value that is "equal" to the previous one
        // there should be no change in the signal's value as the new value is determined to be equal
        // to the previous one
        state.set(StringCount("bbb"))
        XCTAssertEqual(state().string.uppercased(), "AAA")

        state.update { _ in StringCount("ccc") }
        XCTAssertEqual(state().string.uppercased(), "AAA")

        // setting a "non-equal" value
        state.set(StringCount("d"))
        XCTAssertEqual(state().string.uppercased(), "D")
    }
}
