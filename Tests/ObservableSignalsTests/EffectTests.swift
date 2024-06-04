import ObservableSignals
import Testing

@Suite
struct EffectTests {
    @Test("Should create and run once, even without dependencies")
    func createAndRunOnce() {
        var runs = 0

        createEffect {
            runs += 1
        }

        #expect(runs == 1)
    }
    
    @Test("Should schedule on dependencies (signal) change")
    func scheduleOnDependenciesChange() {
        let (count, setCount) = createSignal(0)
        var runLog: [Int] = []
        
        createEffect {
            runLog.append(count())
        }
        
        #expect(runLog == [0])
        
        setCount(1)
        #expect(runLog == [0, 1])
    }
}
