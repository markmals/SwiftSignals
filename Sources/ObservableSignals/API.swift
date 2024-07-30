import Observation
import SwiftNavigation

@Observable
final class Signal<T> {
    var wrappedValue: T
    init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

public typealias Accessor<T> = () -> T
public typealias Setter<T> = (T) -> Void

public func createSignal<T: Equatable>(_ initialValue: T) -> (Accessor<T>, Setter<T>) {
    let signal = Signal(wrappedValue: initialValue)
    return (
        { signal.wrappedValue },
        { newValue in
            if signal.wrappedValue != newValue {
                signal.wrappedValue = newValue
            }
        }
    )
}

public func createEffect(_ apply: @escaping @Sendable () -> Void) {
    let _ = observe { _ in
        apply()
    }
}

enum Initializable<T> {
    case initialized(T)
    case uninitialized
    
    var value: T {
        switch self {
        case .initialized(let value): return value
        case .uninitialized: fatalError("Memoized function accessed before initialization")
        }
    }
}

extension Initializable: Equatable where T: Equatable {
    static func == (lhs: Initializable<T>, rhs: Initializable<T>) -> Bool {
        switch lhs {
        case .uninitialized:
            return rhs == .uninitialized
        case .initialized(let lhsValue):
            switch rhs {
            case .initialized(let rhsValue):
                return lhsValue == rhsValue
            case .uninitialized:
                return false
            }
        }
    }
}

public func createMemo<T: Equatable>(_ computation: @autoclosure @escaping Accessor<T>) -> Accessor<T> {
    let (signal, setSignal) = createSignal(Initializable<T>.uninitialized)
    
    createEffect {
        let result = computation()
        
        guard case .initialized(_) = signal() else {
            setSignal(.initialized(result))
            return
        }
        
        if result != signal().value {
            setSignal(.initialized(result))
        }
    }
    
    return { signal().value }
}
