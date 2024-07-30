//import Foundation
//import ReactivelySignals
//
//@MainActor
//func reactiveMain() {
//    autoStabilize()
//    
//    let count = signal(1)
//    let doubleCount = memo(count.get() * 2)
//        
//    effect {
//        print("Double \(count.get()) is \(doubleCount())")
//    }
//    
//    count.set(2)
//}
//
//@MainActor
//func main() async throws {
//    @State var count = 1
//    @Derived var doubleCount = count * 2
//        
//    effect {
//        print("Double \(count) is \(doubleCount)")
//    }
//    
//    while true {
//        try await Task.sleep(for: .seconds(1))
//        count += 1
//    }
//}
//
//
//Task {
//    await reactiveMain()
//}
