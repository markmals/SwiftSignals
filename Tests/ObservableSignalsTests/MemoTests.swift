import SwiftSignals
import Testing

@Suite
struct MemoTests {
    @Test func createMemoizedSignal() {
        let (counter, setCounter) = createSignal(0)
        var computedRunCount = 0
        
        let computation = {
            computedRunCount += 1
            return "\(counter() * 2):\(computedRunCount)"
        }
        
        let double = createMemo(computation())
                
        #expect(double() == "0:1")

        setCounter(1)
        #expect(double() == "2:2")
        #expect(double() == "2:2")

        setCounter(2)
        #expect(double() == "4:3")
        #expect(double() == "4:3")
    }
    
    // should not re-compute if there are no dependencies
    @Test func shouldNotRecompute() {
        var tick = 0
        
        let computation = {
            tick += 1
            return tick
        }
        
        let memo = createMemo(computation())

        #expect(memo() == 1)
        #expect(memo() == 1)
    }

    // should not re-compute if the dependency is a primitive value and the value did not change
    @Test func shouldNotRecomputeIfValueDidNotChange() {
        let (counter, setCounter) = createSignal(0)

        var computedRunCount = 0
        let computation = {
            computedRunCount += 1
            return "\(counter() * 2):\(computedRunCount)"
        }
        
        let double = createMemo(computation())

        #expect(double() == "0:1")

        setCounter(0)
        #expect(double() == "0:1")
    }
    
    // FIXME: This test fails without the Task.sleep in between the set and #expect
    @Test func shouldChainComputed() {
        let (name, setName) = createSignal("abc")
        let reverse = createMemo(String(name().reversed()))
        let upper = createMemo(reverse().uppercased())

        #expect(upper() == "CBA")

        setName("foo")
        #expect(upper() == "OOF")
    }
    
    // should evaluate computed only when subscribing
    @Test func shouldEvaluateOnlyWhenSubscribing() {
        let (name, setName) = createSignal("John")
        let (show, setShow) = createSignal(true)

        var computeCount = 0
        let computation = {
            computeCount += 1
            return "\(show() ? name() : "anonymous"):\(computeCount)"
        }
        
        let displayName = createMemo(computation())

        #expect(displayName() == "John:1")

        setShow(false)
        #expect(displayName() == "anonymous:2")

        setName("Bob")
        #expect(displayName() == "anonymous:2")
    }
}
