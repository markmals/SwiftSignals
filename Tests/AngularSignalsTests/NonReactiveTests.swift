@testable import SwiftSignal
import XCTest

final class NonReactiveTests: XCTestCase {
    override class func tearDown() {
        // This is the tearDown() class method.
        // XCTest calls it after the last test method completes.
        // Perform any overall cleanup here.
        resetEffects()
    }

    // should read the latest value from signal
    func testShouldReadLatestValueFromSignal() {
        let counter = signal(0)

        XCTAssertEqual(untracked { counter() }, 0)

        counter.set(1)
        XCTAssertEqual(untracked { counter() }, 1)
    }

    // should not add dependencies to computed when reading a value from a signal
    func testShouldNotAddDependenciesToComputedWhenReadingValueFromSignal() {
        let counter = signal(0)
        let double = computed { untracked { counter() } * 2 }

        XCTAssertEqual(double(), 0)

        counter.set(2)
        XCTAssertEqual(double(), 0)
    }

    // should refresh computed value if stale and read non-reactively
    func testShouldRefreshComputedValueIfStaleAndReadNonReactively() {
        let counter = signal(0)
        let double = computed { counter() * 2 }

        XCTAssertEqual(untracked { double() }, 0)

        counter.set(2)
        XCTAssertEqual(untracked { double() }, 4)
    }

    // should not make surrounding effect depend on the signal
    func testShouldNotMakeSurroundingEffectDependOnSignal() {
        let s = signal(1)

        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(untracked { s() })
        }

        // an effect will run at least once
        flushEffects()
        XCTAssertEqual(runLog, [1])

        // subsequent signal changes should not trigger effects as signal is untracked
        s.set(2)
        flushEffects()
        XCTAssertEqual(runLog, [1])
    }

    // should schedule on dependencies (computed) change
    func testShouldScheduleOnDependenciesChange() {
        let count = signal(0)
        let double = computed { count() * 2 }

        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(double())
        }

        flushEffects()
        XCTAssertEqual(runLog, [0])

        count.set(1)
        flushEffects()
        XCTAssertEqual(runLog, [0, 2])
    }

    // should non-reactively read all signals accessed inside untrack
    func testShouldNonReactivelyReadAllSignalsAccessedInsideUntrack() {
        let first = signal("John")
        let last = signal("Doe")

        var runLog: [String] = []
        testingEffect { _ in
            untracked { runLog.append("\(first()) \(last())") }
        }

        // effects run at least once
        flushEffects()
        XCTAssertEqual(runLog, ["John Doe"])

        // change one of the signals - should not update as not read reactively
        first.set("Patricia")
        flushEffects()
        XCTAssertEqual(runLog, ["John Doe"])

        // change one of the signals - should not update as not read reactively
        last.set("Garcia")
        flushEffects()
        XCTAssertEqual(runLog, ["John Doe"])
    }
}
