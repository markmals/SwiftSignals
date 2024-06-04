@testable import SwiftSignal
import XCTest

final class WatchTests: XCTestCase {
    override class func tearDown() {
        // This is the tearDown() class method.
        // XCTest calls it after the last test method completes.
        // Perform any overall cleanup here.
        resetEffects()
    }

    // should create and run once, even without dependencies
    func testShouldCreateAndRunOnceEvenWithoutDependencies() {
        var runs = 0

        testingEffect { _ in
            runs += 1
        }

        flushEffects()
        XCTAssertEqual(runs, 1)
    }

    // should schedule on dependencies (signal) change
    func testShouldScheduleOnDependenciesSignalChange() {
        let count = signal(0)
        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(count())
        }

        flushEffects()
        XCTAssertEqual(runLog, [0])

        count.set(1)
        flushEffects()
        XCTAssertEqual(runLog, [0, 1])
    }

    // should not schedule when a previous dependency changes
    func testShouldNotScheduleWhenPreviousDependencyChanges() {
        let increment = { (value: Int) in value + 1 }
        let countA = signal(0)
        let countB = signal(100)
        let useCountA = signal(true)

        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(useCountA() ? countA() : countB())
        }

        flushEffects()
        XCTAssertEqual(runLog, [0])

        countB.update(increment)
        flushEffects()
        // No update expected: updated the wrong signal.
        XCTAssertEqual(runLog, [0])

        countA.update(increment)
        flushEffects()
        XCTAssertEqual(runLog, [0, 1])

        useCountA.set(false)
        flushEffects()
        XCTAssertEqual(runLog, [0, 1, 101])

        countA.update(increment)
        flushEffects()
        // No update expected: updated the wrong signal.
        XCTAssertEqual(runLog, [0, 1, 101])
    }

    // should not update dependencies when dependencies don't change
    func testShouldNotUpdateDependenciesWhenDependenciesDontChange() {
        let source = signal(0)
        let isEven = computed { source() % 2 == 0 }
        var updateCounter = 0
        testingEffect { _ in
            isEven()
            updateCounter += 1
        }

        flushEffects()
        XCTAssertEqual(updateCounter, 1)

        source.set(1)
        flushEffects()
        XCTAssertEqual(updateCounter, 2)

        source.set(3)
        flushEffects()
        XCTAssertEqual(updateCounter, 2)

        source.set(4)
        flushEffects()
        XCTAssertEqual(updateCounter, 3)
    }

    // should allow registering cleanup function from the watch logic
    func testShouldAllowRegisteringCleanupFunctionFromWatchLogic() {
        let source = signal(0)

        var seenCounterValues: [Int] = []
        testingEffect { onCleanup in
            seenCounterValues.append(source())

            // register a cleanup function that is executed every time an effect re-runs
            onCleanup {
                if seenCounterValues.count == 2 {
                    seenCounterValues.removeAll()
                }
            }
        }

        flushEffects()
        XCTAssertEqual(seenCounterValues, [0])

        source.update { $0 + 1 }
        flushEffects()
        XCTAssertEqual(seenCounterValues, [0, 1])

        source.update { $0 + 1 }
        flushEffects()
        // cleanup (array removeAll) should have run before executing effect
        XCTAssertEqual(seenCounterValues, [2])
    }

    // should forget previously registered cleanup function when effect re-runs
    func testShouldForgetPreviouslyRegisteredCleanupFunctionWhenEffectReRuns() {
        let source = signal(0)

        var seenCounterValues: [Int] = []
        testingEffect { onCleanup in
            let value = source()

            seenCounterValues.append(value)

            // register a cleanup function that is executed next time an effect re-runs
            if value == 0 {
                onCleanup {
                    seenCounterValues.removeAll()
                }
            }
        }

        flushEffects()
        XCTAssertEqual(seenCounterValues, [0])

        source.set(2)
        flushEffects()
        // cleanup (array removeAll) should have run before executing effect
        XCTAssertEqual(seenCounterValues, [2])

        source.set(3)
        flushEffects()
        // cleanup (array removeAll) should *not* be registered again
        XCTAssertEqual(seenCounterValues, [2, 3])
    }

    // should throw an error when reading a signal during the notification phase
    func testShouldThrowErrorWhenReadingSignalDuringNotificationPhase() {
        let source = signal(0)
        var ranScheduler = false
        
        let watch = Watch(
            watch: {
                source()
            },
            schedule: { _ in
                ranScheduler = true
                XCTAssertThrowsError(source())
            },
            allowSignalWrites: false
        )

        // Run the effect manually to initiate dependency tracking.
        watch.run()

        // Changing the signal will attempt to schedule the effect.
        source.set(1)
        XCTAssertTrue(ranScheduler)
    }
}
