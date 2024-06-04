public protocol ThrowingSignal<T> {
    associatedtype T
    @discardableResult func callAsFunction() throws -> T
}

public protocol Signal<T> {
    associatedtype T
    @discardableResult func callAsFunction() -> T
}

// func isSignal<T>(_ value: () -> T) -> Bool {
//   return value as? Signal<T> != nil
// }
