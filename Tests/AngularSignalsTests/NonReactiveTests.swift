import Testing
import AngularSignals

@Suite
final class NonReactiveTests {
    deinit {
        resetEffects()
    }

    @Test("Should read the latest value from signal")
    func readLatestValue() {
        let counter = signal(0)

        #expect(untracked { counter() } == 0)

        counter.set(1)
        #expect(untracked { counter() } == 1)
    }

    @Test("Should not add dependencies to computed when reading a value from a signal")
    func dontAddDependencies() {
        let counter = signal(0)
        let double = computed { untracked { counter() } * 2 }

        #expect(double() == 0)

        counter.set(2)
        #expect(double() == 0)
    }

    @Test("Should refresh computed value if stale and read non-reactively")
    func refreshIfStale() {
        let counter = signal(0)
        let double = computed { counter() * 2 }

        #expect(untracked { double() } == 0)

        counter.set(2)
        #expect(untracked { double() } == 4)
    }

    @Test("Should not make surrounding effect depend on the signal")
    func dontDependOnSignal() {
        let s = signal(1)

        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(untracked { s() })
        }

        // an effect will run at least once
        flushEffects()
        #expect(runLog == [1])

        // subsequent signal changes should not trigger effects as signal is untracked
        s.set(2)
        flushEffects()
        #expect(runLog == [1])
    }

    @Test("Should schedule on dependencies (computed) change")
    func dcheduleOnDependenciesChange() {
        let count = signal(0)
        let double = computed { count() * 2 }

        var runLog: [Int] = []
        testingEffect { _ in
            runLog.append(double())
        }

        flushEffects()
        #expect(runLog == [0])

        count.set(1)
        flushEffects()
        #expect(runLog == [0, 2])
    }

    @Test("Should non-reactively read all signals accessed inside untrack")
    func nonReactiveRead() {
        let first = signal("John")
        let last = signal("Doe")

        var runLog: [String] = []
        testingEffect { _ in
            untracked { runLog.append("\(first()) \(last())") }
        }

        // effects run at least once
        flushEffects()
        #expect(runLog == ["John Doe"])

        // change one of the signals - should not update as not read reactively
        first.set("Patricia")
        flushEffects()
        #expect(runLog == ["John Doe"])

        // change one of the signals - should not update as not read reactively
        last.set("Garcia")
        flushEffects()
        #expect(runLog == ["John Doe"])
    }
}
