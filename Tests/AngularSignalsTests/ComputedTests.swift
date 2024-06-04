import Foundation
import Testing
@testable import AngularSignals

@Suite
struct ComputedTests {
    @Test("Should create computed")
    func createComputed() {
        let counter = signal(0)
        var computedRunCount = 0
        let double = computed {
            computedRunCount += 1
            return "\(counter() * 2):\(computedRunCount)"
        }
        
        #expect(double() == "0:1")

        counter.set(1)
        #expect(double() == "2:2")
        #expect(double() == "2:2")

        counter.set(2)
        #expect(double() == "4:3")
        #expect(double() == "4:3")
    }

    @Test("Should not re-compute if there are no dependencies")
    func noDependencies() {
        var tick = 0
        let c = computed {
            tick += 1
            return tick
        }

        #expect(c() == 1)
        #expect(c() == 1)
    }

    @Test("Should not re-compute if the dependency is a primitive value and the value did not change")
    func valueDidNotChange() {
        let counter = signal(0)

        var computedRunCount = 0
        let double = computed {
            computedRunCount += 1
            return "\(counter() * 2):\(computedRunCount)"
        }

        #expect(double() == "0:1")

        counter.set(0)
        #expect(double() == "0:1")
    }

    @Test("Should chain computed")
    func chainComputed() {
        let name = signal("abc")
        let reverse = computed { String(name().reversed()) }
        let upper = computed { reverse().uppercased() }

        #expect(upper() == "CBA")

        name.set("foo")
        #expect(upper() == "OOF")
    }

    @Test("Should evaluate computed only when subscribing")
    func evaluateWhenSubscribing() {
        let name = signal("John")
        let show = signal(true)

        var computeCount = 0
        let displayName = computed {
            computeCount += 1
            return "\(show() ? name() : "anonymous"):\(computeCount)"
        }

        #expect(displayName() == "John:1")

        show.set(false)
        #expect(displayName() == "anonymous:2")

        name.set("Bob")
        #expect(displayName() == "anonymous:2")
    }

    @Test("Should detect simple dependency cycles")
    func detectCycles() {
        let a: some Signal<Int> = computed { a() }
        #expect(throws: Error.self, "Detected cycle in computations.") {
            a()
        }
    }

    // TODO: This doesn't seem possible given the Swift type system; Need to verify
//    @Test("Should detect deep dependency cycles")
//    func detectDeepCycles() {
//        var a: (some Signal<Int>)? = computed { b!() }
//        var b: (some Signal<Int>)? = computed { c!() }
//        var c: (some Signal<Int>)? = computed { d!() }
//        var d: (some Signal<Int>)? = computed { a!() }
//        #expect(throws: Error.self, "Detected cycle in computations.") {
//            a!()
//        }
//    }

    @Test("Should cache exceptions thrown until computed gets dirty again")
    func cacheErrorsUntilDirty() {
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
        
        #expect(throws: Error.self) {
            try c()
        }
        
        #expect(throws: Error.self) {
            try c()
        }

        toggle.set("OK")
        #expect(try! c() == "OK")
    }

    @Test("Should not update dependencies of computations when dependencies don't change")
    func depencenciesDontChange() {
        let source = signal(0)
        let isEven = computed { source() % 2 == 0 }
        var updateCounter = 0
        let updateTracker = computed {
            isEven()
            updateCounter += 1
            return updateCounter
        }

        updateTracker()
        #expect(updateCounter == 1)

        source.set(1)
        updateTracker()
        #expect(updateCounter == 2)

        // Setting the counter to another odd value should not trigger `updateTracker` to update.
        source.set(3)
        updateTracker()
        #expect(updateCounter == 2)

        source.set(4)
        updateTracker()
        #expect(updateCounter == 3)
    }

    @Test("Should not mark dirty computed signals that are dirty already")
    func alreadyDirty() {
        let source = signal("a")
        let derived = computed { source().uppercased() }

        var watchCount = 0
        let watch = Watch(
            watch: { derived() },
            schedule: { _ in watchCount += 1 },
            allowSignalWrites: false
        )

        watch.run()
        #expect(watchCount == 0)

        // change signal, mark downstream dependencies dirty
        source.set("b")
        #expect(watchCount == 1)

        // change signal again, downstream dependencies should be dirty already and not marked again
        source.set("c")
        #expect(watchCount == 1)

        // resetting dependencies back to clean
        watch.run()
        #expect(watchCount == 1)

        // expecting another notification at this point
        source.set("d")
        #expect(watchCount == 2)
    }
}
