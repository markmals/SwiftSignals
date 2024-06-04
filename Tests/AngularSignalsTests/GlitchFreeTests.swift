import Testing
import AngularSignals

@Suite
struct GlitchFreeTests {
    @Test("Should recompute only once for diamond dependency graph")
    func recomputeOnlyOnceForDiamondDependencies() {
        var fullRecompute = 0

        let name = signal("John Doe")
        let first = computed { name().split(separator: " ")[0] }
        let last = computed { name().split(separator: " ")[1] }
        let full = computed {
            fullRecompute += 1
            return "\(first())/\(last())"
        }

        #expect(full() == "John/Doe")
        #expect(fullRecompute == 1)

        name.set("Bob Fisher")
        #expect(full() == "Bob/Fisher")
        #expect(fullRecompute == 2)
    }

    @Test("Should recompute only once")
    func recomputeOnlyOnce() {
        let a = signal("a")
        let b = computed { a() + "b" }
        var cRecompute = 0
        let c = computed {
            cRecompute += 1
            return "\(a())|\(b())|\(cRecompute)"
        }

        #expect(c() == "a|ab|1")

        a.set("A")
        #expect(c() == "A|Ab|2")
    }
}
