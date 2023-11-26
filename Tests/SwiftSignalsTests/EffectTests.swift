import SwiftSignals
import Testing

@Suite
struct EffectTests {
    // should create and run once, even without dependencies
    @Test func shouldCreateAndRunOnce() {
        var runs = 0

        createEffect {
            runs += 1
        }

        #expect(runs == 1)
    }
    
    // should schedule on dependencies (signal) change
    @Test func shouldScheduleOnDependenciesChange() {
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
