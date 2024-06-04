@testable import SwiftSignal
import XCTest

final class ComputedTests: XCTestCase {
    // should create computed
    func testCreateComputed() {
        let counter = signal(0)
        var computedRunCount = 0
        let double = computed {
            computedRunCount += 1
            return "\(counter() * 2):\(computedRunCount)"
        }
        XCTAssertEqual(double(), "0:1")

        counter.set(1)
        XCTAssertEqual(double(), "2:2")
        XCTAssertEqual(double(), "2:2")

        counter.set(2)
        XCTAssertEqual(double(), "4:3")
        XCTAssertEqual(double(), "4:3")
    }

    // should not re-compute if there are no dependencies
    func testShouldNotRecompute() {
        var tick = 0
        let c = computed {
            tick += 1
            return tick
        }

        XCTAssertEqual(c(), 1)
        XCTAssertEqual(c(), 1)
    }

    // should not re-compute if the dependency is a primitive value and the value did not change
    func testShouldNotRecomputeIfValueDidNotChange() {
        let counter = signal(0)

        var computedRunCount = 0
        let double = computed {
            computedRunCount += 1
            return "\(counter() * 2):\(computedRunCount)"
        }

        XCTAssertEqual(double(), "0:1")

        counter.set(0)
        XCTAssertEqual(double(), "0:1")
    }

    // should chain computed
    func testShouldChainComputed() {
        let name = signal("abc")
        let reverse = computed { String(name().reversed()) }
        let upper = computed { reverse().uppercased() }

        XCTAssertEqual(upper(), "CBA")

        name.set("foo")
        XCTAssertEqual(upper(), "OOF")
    }

    // should evaluate computed only when subscribing
    func testShouldEvaluateOnlyWhenSubscribing() {
        let name = signal("John")
        let show = signal(true)

        var computeCount = 0
        let displayName = computed {
            computeCount += 1
            return "\(show() ? name() : "anonymous"):\(computeCount)"
        }

        XCTAssertEqual(displayName(), "John:1")

        show.set(false)
        XCTAssertEqual(displayName(), "anonymous:2")

        name.set("Bob")
        XCTAssertEqual(displayName(), "anonymous:2")
    }

    // should detect simple dependency cycles
    func testShouldDetectSimpleDependencyCycles() {
        let a: some Signal<Int> = computed { a() }
        XCTAssertThrowsError(a(), "Detected cycle in computations.")
    }

    // TODO: This doesn't seem possible given the Swift type system; Need to verify
    // should detect deep dependency cycles
//    func testShouldDetectDeepDependencyCycles() {
//        var a: (some Signal<Int>)? = computed { b!() }
//        var b: (some Signal<Int>)? = computed { c!() }
//        var c: (some Signal<Int>)? = computed { d!() }
//        var d: (some Signal<Int>)? = computed { a!() }
//        XCTAssertThrowsError(a!(), "Detected cycle in computations.")
//    }

    // should cache exceptions thrown until computed gets dirty again
    func testShouldCacheErrorsThrownUntilDirtyAgain() {
        struct Error: LocalizedError, Equatable {
            let errorDescription: String
            init(_ errorDescription: String) {
                self.errorDescription = errorDescription
            }
        }

        let toggle = signal("KO")
        let c = computed {
            let val = toggle()
            if val == "KO" {
                throw Error("KO")
            } else {
                return val
            }
        }

        XCTAssertThrowsError(try c())
        XCTAssertThrowsError(try c())

        toggle.set("OK")
        XCTAssertEqual(try c(), "OK")
    }

    // should not update dependencies of computations when dependencies don't change
    func testShouldNotUpdateDependenciesWhenDepencenciesDontChange() {
        let source = signal(0)
        let isEven = computed { source() % 2 == 0 }
        var updateCounter = 0
        let updateTracker = computed {
            isEven()
            updateCounter += 1
            return updateCounter
        }

        updateTracker()
        XCTAssertEqual(updateCounter, 1)

        source.set(1)
        updateTracker()
        XCTAssertEqual(updateCounter, 2)

        // Setting the counter to another odd value should not trigger `updateTracker` to update.
        source.set(3)
        updateTracker()
        XCTAssertEqual(updateCounter, 2)

        source.set(4)
        updateTracker()
        XCTAssertEqual(updateCounter, 3)
    }

    // should not mark dirty computed signals that are dirty already
    func testShouldNotMarkDirtyIfAlreadyDirty() {
        let source = signal("a")
        let derived = computed { source().uppercased() }

        var watchCount = 0
        let watch = Watch(
            watch: { derived() },
            schedule: { _ in watchCount += 1 },
            allowSignalWrites: false
        )

        watch.run()
        XCTAssertEqual(watchCount, 0)

        // change signal, mark downstream dependencies dirty
        source.set("b")
        XCTAssertEqual(watchCount, 1)

        // change signal again, downstream dependencies should be dirty already and not marked again
        source.set("c")
        XCTAssertEqual(watchCount, 1)

        // resetting dependencies back to clean
        watch.run()
        XCTAssertEqual(watchCount, 1)

        // expecting another notification at this point
        source.set("d")
        XCTAssertEqual(watchCount, 2)
    }
}
