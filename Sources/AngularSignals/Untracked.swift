/// Execute an arbitrary function in a non-reactive (non-tracking) context. The executed function
/// can, optionally, return a value.
public func untracked<T>(nonReactiveReadsFn: () -> T) -> T {
    let prevConsumer = setActiveConsumer(nil)
    // We are not trying to catch any particular errors here, just making sure that the consumers
    // stack is restored in case of errors.
    defer { setActiveConsumer(prevConsumer) }
    do { return nonReactiveReadsFn() }
}
