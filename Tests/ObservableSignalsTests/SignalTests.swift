import ObservableSignals
import Testing

@Suite
struct SignalTests {
    @Test("Should be a getter which reflects the set value")
    func getterSetter() {
        let (state, setState) = createSignal(false)
        #expect(state() == false)
        setState(true)
        #expect(state() == true)
    }
    
    @Test("Should not propagate change when the new signal value is equal to the previous one")
    func equality() {
        struct StringCount: Equatable {
            let string: String
            
            init(_ string: String) {
                self.string = string
            }

            static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.string.count == rhs.string.count
            }
        }

        let (state, setState) = createSignal(StringCount("aaa"))

        // set to a "different" value that is "equal" to the previous one
        // there should be no change in the signal's value as the new value is determined to be equal
        // to the previous one
        setState(StringCount("bbb"))
        #expect(state().string.uppercased() == "AAA")

        setState(StringCount("ccc"))
        #expect(state().string.uppercased() == "AAA")

        // setting a "non-equal" value
        setState(StringCount("d"))
        #expect(state().string.uppercased() == "D")
    }
}
