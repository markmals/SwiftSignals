/// The current reactive observer.
///
/// The observer is whatever reactive node is currently listening for signals that need to be
/// tracked. For example, if an effect is running, that effect is the observer, which means it will
/// subscribe to changes in any signals that are read.
public enum Observer {
    @ThreadLocal package static var observer: AnySubscriber? = nil
    
    /// Returns the current observer, if any.
    public static func get() -> AnySubscriber? {
        observer
    }
    
    package static func `is`(observer: inout AnySubscriber) -> Bool {
        self.observer == observer
    }
    
    func set(observer: AnySubscriber?) {
        Self.observer = observer
    }
}

/// Suspends reactive tracking while running the given function.
///
/// This can be used to isolate parts of the reactive graph from one another.
///
/// ```rust
/// # use reactive_graph::computed::*;
/// # use reactive_graph::signal::*;
/// # use reactive_graph::prelude::*;
/// # use reactive_graph::untrack;
/// # tokio_test::block_on(async move {
/// # any_spawner::Executor::init_tokio();
/// let (a, set_a) = signal(0);
/// let (b, set_b) = signal(0);
/// let c = Memo::new(move |_| {
///     // this memo will *only* update when `a` changes
///     a.get() + untrack(move || b.get())
/// });
///
/// assert_eq!(c.get(), 0);
/// set_a.set(1);
/// assert_eq!(c.get(), 1);
/// set_b.set(1);
/// // hasn't updated, because we untracked before reading b
/// assert_eq!(c.get(), 1);
/// set_a.set(2);
/// assert_eq!(c.get(), 3);
/// # });
/// ```
@TrackCaller
public func untrack<T>(nonReactiveReadsFunc: @autoclosure @escaping () -> T) -> T {
    SpecialNonReactiveZone.enter()
    let prev = Observer.get()
    return nonReactiveReadsFunc()
}

/// Converts a [`Subscriber`] to a type-erased [`AnySubscriber`].
public protocol AnySubscriberConvertible {
    var anySubscriber: AnySubscriber { get }
}

/// Any type that can track reactive values (like an effect or a memo).
public protocol Subscriber: ReactiveNode {
    /// Adds a subscriber to this subscriber's list of dependencies.
    mutating func add(source: AnySource)

    /// Clears the set of sources for this subscriber.
    mutating func clearSources(subscriber: inout AnySubscriber)
}



/// A type-erased subscriber.
public struct AnySubscriber: Identifiable {
    public var id: Int
    public weak var subscriber: (any Subscriber & Sendable & AnyObject)?
}

extension AnySubscriber: AnySubscriberConvertible {
    public var anySubscriber: AnySubscriber {
        self
    }
}

extension AnySubscriber: Subscriber {
    public mutating func add(source: AnySource) {
        if var inner = subscriber {
            inner.add(source: source)
        }
    }
    
    public mutating func clearSources(subscriber: inout AnySubscriber) {
        if var inner = self.subscriber {
            inner.clearSources(subscriber: &subscriber)
        }
    }
}

extension AnySubscriber: ReactiveNode {
    public mutating func markDirty() {
        if var inner = subscriber {
            inner.markDirty()
        }
    }
    
    public mutating func markCheck() {
        if var inner = subscriber {
            inner.markCheck()
        }
    }
    
    public mutating func markSubscribersCheck() {
        if var inner = subscriber {
            inner.markSubscribersCheck()
        }
    }
    
    public mutating func updateIfNecessary() -> Bool {
        guard var inner = subscriber else {
            return false
        }
        
        return inner.updateIfNecessary()
    }
}

///// Runs code with some subscriber as the thread-local [`Observer`].
//public protocol WithObserver {
//    /// Runs the given function with this subscriber as the thread-local [`Observer`].
//    mutating func withObserver<T>(fn: () -> T) -> T
//}
//
//extension AnySubscriber: WithObserver {
//    /// Runs the given function with this subscriber as the thread-local [`Observer`].
//    public mutating func withObserver<T>(fn: () -> T) -> T {
//        let prev = Observer.set(self)
//        fn()
//    }
//}

extension AnySubscriber: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        struct AnySubscriber {
            var id = \(id)
        }
        """
    }
}

extension AnySubscriber: Equatable {
    public static func == (lhs: AnySubscriber, rhs: AnySubscriber) -> Bool {
        lhs.id == rhs.id
    }
}

extension AnySubscriber: Hashable {
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}
