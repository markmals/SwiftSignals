public func computed<T: Equatable>(_ computation: @escaping () -> T) -> some Signal<T> {
    ComputedSignal(computation: computation)
}

public func computed<T: Equatable>(_ computation: @escaping () throws -> T) -> some ThrowingSignal<T> {
    ThrowingComputedSignal(computation: computation)
}

internal enum ComputedValue<Wrapped: Equatable>: Equatable {
    case unset
    case computing
    case errored(SignalError)
    case value(Wrapped)
}

/// A computation, which derives a value from a declarative reactive expression.
///
/// `Computed`s are both producers and consumers of reactivity.
internal class ThrowingComputedSignal<Value: Equatable>: ReactiveNode, ThrowingSignal {
    public typealias T = Value

    public func callAsFunction() throws -> T {
        // Check if the value needs updating before returning it.
        onProducerUpdateValueVersion()

        // Record that someone looked at this signal.
        producerAccessed()

        // FIXME: This can't throw, but it might need to...
        if case let .errored(error) = value {
            throw error
        }

        if case let .value(v) = value { return v }

        // FIXME:
        fatalError()
    }

    internal let computation: () throws -> T

    internal init(computation: @escaping () throws -> T) {
        self.computation = computation
    }

    /**
     * Current value of the computation.
     *
     * This can also be one of the special values `.unset`, `.computing`, or `.errored`.
     */
    internal var value: ComputedValue<Value> = .unset

    /**
     * If `value` is `.errored`, the error caught from the last computation attempt which will
     * be re-thrown.
     */
    internal var error: Error? = nil

    /**
     * Flag indicating that the computation is currently stale, meaning that one of the
     * dependencies has notified of a potential change.
     *
     * It's possible that no dependency has _actually_ changed, in which case the `stale`
     * state can be resolved without recomputing the value.
     */
    internal var stale = true

    // FIXME: How to override this?
//    override public var consumerAllowSignalWrites: Bool { false }

    override internal func onConsumerDependencyMayHaveChanged() {
        if stale {
            // We've already notified consumers that this value has potentially changed.
            return
        }

        // Record that the currently cached value may be stale.
        stale = true

        // Notify any consumers about the potential change.
        producerMayHaveChanged()
    }

    override internal func onProducerUpdateValueVersion() {
        if !stale {
            // The current value and its version are already up to date.
            return
        }

        // The current value is stale. Check whether we need to produce a new one.
        if value != .unset && value != .computing && !consumerPollProducersForChange() {
            // Even though we were previously notified of a potential dependency update, all of
            // our dependencies report that they have not actually changed in value, so we can
            // resolve the stale state without needing to recompute the current value.
            stale = false
            return
        }

        // The current value is stale, and needs to be recomputed. It still may not change -
        // that depends on whether the newly computed value is equal to the old.
        recomputeValue()
    }

    internal func recomputeValue() {
        if value == .computing {
            // Our computation somehow led to a cyclic read of itself.
            // FIXME: Make this a recoverable error
            fatalError("Detected cycle in computations.")
        }

        let oldValue = value
        value = .computing

        // As we're re-running the computation, update our dependent tracking version number.
        trackingVersion += 1
        let prevConsumer = setActiveConsumer(self)
        let newValue: ComputedValue<Value>

        defer { setActiveConsumer(prevConsumer) }

        do {
            newValue = try .value(computation())
        }
        // TODO: Catch non-SignalErrors, e.g. user-thrown errors
        // Do I need to transform them into SignalErrors?
        // FIXME: No errors thrown in do block. `computation` should throw?
        catch {
            newValue = .errored(error as! SignalError)
        }

        stale = false

        guard
            case .unset = oldValue,
            case .errored = oldValue,
            case .errored = newValue,
            oldValue != newValue
        else {
            // No change to `valueVersion` - old and new values are
            // semantically equivalent.
            value = oldValue
            return
        }

        value = newValue
        valueVersion += 1
    }
}

internal class ComputedSignal<Value: Equatable>: ThrowingComputedSignal<Value>, Signal {
    public typealias T = Value

    override public func callAsFunction() -> T {
        // Check if the value needs updating before returning it.
        onProducerUpdateValueVersion()

        // Record that someone looked at this signal.
        producerAccessed()

        // FIXME: This can't throw, but it might need to...
//        if case let .errored(error) = value {
//            throw error
//        }

        if case let .value(v) = value { return v }

        // FIXME:
        fatalError()
    }

    override init(computation: @escaping () throws -> Value) {
        super.init(computation: computation)
    }
}

// TODO: Support async computed
