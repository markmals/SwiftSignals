public func signal<T: Equatable>(_ initialValue: T) -> WritableSignal<T> {
    WritableSignal(initialValue)
}

public final class WritableSignal<Value: Equatable>: ReactiveNode, Signal {
    public typealias T = Value
    // FIXME: How to override this?
//    override public var consumerAllowSignalWrites: Bool { false }

    private var value: T

    internal init(_ initialValue: T) {
        self.value = initialValue
    }

    override public func onConsumerDependencyMayHaveChanged() {
        // This never happens for writable signals as they're not consumers.
    }

    override public func onProducerUpdateValueVersion() {
        // Writable signal value versions are always up to date.
    }

    @discardableResult
    public func callAsFunction() -> Value {
        producerAccessed()
        return value
    }

    /**
     * Directly set the signal to a new value, and notify any dependents.
     */
    public func set(_ newValue: Value) {
        if !producerUpdatesAllowed {
            try! throwInvalidWriteToSignalError()
        }

        if value != newValue {
            value = newValue
            valueVersion += 1
            producerMayHaveChanged()
        }
    }

    /**
     * Update the value of the signal based on its current value, and
     * notify any dependents.
     */
    public func update(_ updateFunc: (Value) -> Value) {
        if !producerUpdatesAllowed {
            try! throwInvalidWriteToSignalError()
        }

        set(updateFunc(value))
    }

    /**
     * Update the current value by mutating it in-place, and
     * notify any dependents.
     */
    public func mutate(_ mutatorFunc: (inout Value) -> Void) {
        if !producerUpdatesAllowed {
            try! throwInvalidWriteToSignalError()
        }

        // Mutate bypasses equality checks as it's by definition changing the value.
        mutatorFunc(&value)
        valueVersion += 1
        producerMayHaveChanged()
    }
}
