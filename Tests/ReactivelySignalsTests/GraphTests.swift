import Testing
import ReactivelySignals

@MainActor
@Suite
struct GraphTests {
    /*
              a  b
              | /
              c
    */
    @Test func twoSignals() {
        let a = signal(7)
        let b = signal(1)
        var callCount = 0
        
        let computation = {
            callCount += 1
            return a.get() * b.get()
        }
        
        let c = memo(computation())
        
        a.set(2)
        #expect(c() == 2)
        
        a.set(3)
        #expect(c() == 6)
        
        #expect(callCount == 2)
        let _ = c()
        #expect(callCount == 2)
    }
    
    /*
               a  b
               | /
               c
               |
               d
     */
    @Test func dependentComputed() {
        let a = signal(7)
        let b = signal(1)
        
        var callCount1 = 0
        let computationC = {
            callCount1 += 1
            return a.get() * b.get()
        }
        let c = memo(computationC())
        
        var callCount2 = 0
        let computationD = {
            callCount2 += 1
            return c() + 1
        }
        let d = memo(computationD())
        
        #expect(d() == 8)
        #expect(callCount1 == 1)
        #expect(callCount2 == 1)
        
        a.set(3)
        
        #expect(d() == 4)
        #expect(callCount1 == 2)
        #expect(callCount2 == 2)
    }
    
    /*
                a
                |
                c
    */
    @Test func equalityCheck() {
        var callCount = 0
        let a = signal(7)
        let computation = {
            callCount += 1
            return a.get() + 10
        }
        let c = memo(computation())
        
        let _ = c()
        let _ = c()
        
        #expect(callCount == 1)
        
        a.set(7)
        
        #expect(callCount == 1) // unchanged, equality check
    }
    
    /*
                a     b
                |     |
                cA   cB
                |   / (dynamically depends on cB)
                cAB
    */
    @Test func dynamicComputed() {
        let a = signal(1)
        let b = signal(2)
        
        var callCountA = 0
        var callCountB = 0
        var callCountAB = 0
        
        let computationCA = {
            callCountA += 1
            return a.get()
        }
        let cA = memo(computationCA())
        
        let computationCB = {
            callCountB += 1
            return b.get()
        }
        let cB = memo(computationCB())
        
        let computationCAB = {
            callCountAB += 1
            
            if cA() != 0 {
                return cA()
            }
            
            return cB()
        }
        let cAB = memo(computationCAB())
        
        #expect(cAB() == 1)
        a.set(2)
        b.set(3)
        #expect(cAB() == 2)
        
        #expect(callCountA == 2)
        #expect(callCountAB == 2)
        #expect(callCountB == 0)
        a.set(0)
        #expect(cAB() == 3)
        #expect(callCountA == 3)
        #expect(callCountAB == 3)
        #expect(callCountB == 1)
        b.set(4)
        #expect(cAB() == 4)
        #expect(callCountA == 3)
        #expect(callCountAB == 4)
        #expect(callCountB == 2)
    }
    
    /*
                  a
                  |
                  b (=)
                  |
                  c
    */
    @Test func booleanEqualityCheck() {
        let a = signal(0)
        let b = memo(a.get() > 0)
        var callCount = 0
        let computationC = {
            callCount += 1
            return b() ? 1 : 0
        }
        let c = memo(computationC())
        
        #expect(c() == 0)
        #expect(callCount == 1)
        
        a.set(1)
        #expect(c() == 1)
        #expect(callCount == 2)
        
        a.set(2)
        #expect(c() == 1)
        #expect(callCount == 2) // unchanged, oughtn't run because bool didn't change

    }
    
    /*
                s
                |
                a
                | \
                b  c
                 \ |
                   d
    */
    @Test func diamondComputeds() {
        let s = signal(1)
        let a = memo(s.get())
        let b = memo(a() * 2)
        let c = memo(a() * 3)
        var callCount = 0
        let computationD = {
            callCount += 1
            return b() + c()
        }
        let d = memo(computationD())
        
        #expect(d() == 5)
        #expect(callCount == 1)
        
        s.set(2)
        #expect(d() == 10)
        #expect(callCount == 2)

        s.set(3)
        #expect(d() == 15)
        #expect(callCount == 3)
    }
    
    /*
                s
                |
                l  a (sets s)
    */
    @Test func setInsideReaction() {
        let s = signal(1)
        let computationA = {
            s.set(2)
            return 0
        }
        let a = memo(computationA())
        let l = memo(s.get() + 100)
        
        let _ = a()
        #expect(l() == 102)
    }
}
