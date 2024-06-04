import Testing
import AngularSignals

@Suite
struct SignalTests {
    @Test("Should be a getter which reflects the set value")
    func getterSetter() {
        let state = signal(false)
        #expect(state() == false)
        state.set(true)
        #expect(state() == true)
    }

    @Test("Should accept update method to set a new value based on the previous one")
    func update() {
        let counter = signal(1)
        #expect(counter() == 1)

        counter.update { $0 + 1 }
        #expect(counter() == 2)
    }

    @Test("Should have mutate method for mutable, out of bound updates")
    func mutate() {
        let state = signal(["a"])
        #expect(state() == ["a"])

        state.mutate { $0.append("b") }
        #expect(state() == ["a", "b"])
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

        let state = signal(StringCount("aaa"))

        // set to a "different" value that is "equal" to the previous one
        // there should be no change in the signal's value as the new value is determined to be equal
        // to the previous one
        state.set(StringCount("bbb"))
        #expect(state().string.uppercased() == "AAA")

        state.update { _ in StringCount("ccc") }
        #expect(state().string.uppercased() == "AAA")

        // setting a "non-equal" value
        state.set(StringCount("d"))
        #expect(state().string.uppercased() == "D")
    }
}
