import Observation

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

public func createEffect(_ apply: @escaping () -> Void) {
    @Sendable func effect() {
        withObservationTracking {
            apply()
        } onChange: {
            Task { @MainActor in
                effect()
            }
        }
    }
    
    effect()
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

public func createMemo<T: Equatable>(_ computation: @autoclosure @escaping Accessor<T>) -> Accessor<T> {
    let signal = Signal<Initializable<T>>(wrappedValue: .uninitialized)
    
    @Sendable func effect() {
        let result = withObservationTracking {
            return computation()
        } onChange: {
            Task { @MainActor in
                effect()
            }
        }

        guard case .initialized(_) = signal.wrappedValue else {
            signal.wrappedValue = .initialized(result)
            return
        }
        
        if result != signal.wrappedValue.value {
            signal.wrappedValue = .initialized(result)
        }
    }
    
    effect()
    
    return { signal.wrappedValue.value }
}
