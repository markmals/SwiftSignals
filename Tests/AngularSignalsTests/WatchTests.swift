import Testing
@testable import AngularSignals

@Suite
final class WatchTests {
    deinit {
        resetEffects()
    }

    @Test("Should create and run once, even without dependencies")
    func createAndRunOnce() {
        var runs = 0

        testingEffect { _ in
            runs += 1
        }

        flushEffects()
        #expect(runs == 1)
    }

    @Test("Should schedule on dependencies (signal) change")
    func scheduleOnChange() {
        let count = signal(0)
        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(count())
        }

        flushEffects()
        #expect(runLog == [0])

        count.set(1)
        flushEffects()
        #expect(runLog == [0, 1])
    }

    @Test("Should not schedule when a previous dependency changes")
    func previousDependencyChanged() {
        let increment = { (value: Int) in value + 1 }
        let countA = signal(0)
        let countB = signal(100)
        let useCountA = signal(true)

        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(useCountA() ? countA() : countB())
        }

        flushEffects()
        #expect(runLog == [0])

        countB.update(increment)
        flushEffects()
        // No update expected: updated the wrong signal.
        #expect(runLog == [0])

        countA.update(increment)
        flushEffects()
        #expect(runLog == [0, 1])

        useCountA.set(false)
        flushEffects()
        #expect(runLog == [0, 1, 101])

        countA.update(increment)
        flushEffects()
        // No update expected: updated the wrong signal.
        #expect(runLog == [0, 1, 101])
    }

    @Test("Should not update dependencies when dependencies don't change")
    func dependenciesDontChange() {
        let source = signal(0)
        let isEven = computed { source() % 2 == 0 }
        var updateCounter = 0
        testingEffect { _ in
            isEven()
            updateCounter += 1
        }

        flushEffects()
        #expect(updateCounter == 1)

        source.set(1)
        flushEffects()
        #expect(updateCounter == 2)

        source.set(3)
        flushEffects()
        #expect(updateCounter == 2)

        source.set(4)
        flushEffects()
        #expect(updateCounter == 3)
    }

    @Test("Should allow registering cleanup function from the watch logic")
    func registerCleanupFunction() {
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
        #expect(seenCounterValues == [0])

        source.update { $0 + 1 }
        flushEffects()
        #expect(seenCounterValues == [0, 1])

        source.update { $0 + 1 }
        flushEffects()
        // cleanup (array removeAll) should have run before executing effect
        #expect(seenCounterValues == [2])
    }

    @Test("Should forget previously registered cleanup function when effect re-runs")
    func forgetPreviouslyRegisteredCleanupFunc() {
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
        #expect(seenCounterValues == [0])

        source.set(2)
        flushEffects()
        // cleanup (array removeAll) should have run before executing effect
        #expect(seenCounterValues == [2])

        source.set(3)
        flushEffects()
        // cleanup (array removeAll) should *not* be registered again
        #expect(seenCounterValues == [2, 3])
    }

    @Test("Should throw an error when reading a signal during the notification phase")
    func throwWhenReadingDuringNotificationPhase() {
        let source = signal(0)
        var ranScheduler = false
        
        let watch = Watch(
            watch: {
                source()
            },
            schedule: { _ in
                ranScheduler = true
                #expect(throws: Error.self) {
                    source()
                }
            },
            allowSignalWrites: false
        )

        // Run the effect manually to initiate dependency tracking.
        watch.run()

        // Changing the signal will attempt to schedule the effect.
        source.set(1)
        #expect(ranScheduler == true)
    }
}
