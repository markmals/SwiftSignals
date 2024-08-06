/// Abstracts over the type of any reactive source.
public protocol AnySourceConvertible {
    /// Converts this type to its type-erased equivalent.
    var anySource: AnySource { get }
}


/// Describes the behavior of any source of reactivity (like a signal, trigger, or memo.)
public protocol Source: ReactiveNode {
    /// Adds a subscriber to this source's list of dependencies.
    mutating func add(subscriber: AnySubscriber)

    /// Removes a subscriber from this source's list of dependencies.
    mutating func remove(subscriber: inout AnySubscriber)

    /// Remove all subscribers from this source's list of dependencies.
    mutating func clearSubscribers()
}

/// A weak reference to any reactive source node.
public struct AnySource {
    package var id: Int
    package weak var source: (any Source & Sendable & AnyObject)?
    package var location: Location
    
    public init(id: Int, source: (any Source & Sendable & AnyObject)?, location: Location) {
        self.id = id
        self.source = source
        self.location = location
    }
}

extension AnySource: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        struct AnySource {
            var id = \(id)
        }
        """
    }
}

extension AnySource: Equatable {
    public static func == (lhs: AnySource, rhs: AnySource) -> Bool {
        lhs.id == rhs.id
    }
}

extension AnySource: Hashable {
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

extension AnySource: AnySourceConvertible {
    public var anySource: AnySource {
        self
    }
}

extension AnySource: Source {
    public mutating func add(subscriber: AnySubscriber) {
        if var inner = source {
            inner.add(subscriber: subscriber)
        }
    }
    
    mutating public func remove(subscriber: inout AnySubscriber) {
        if var inner = source {
            inner.remove(subscriber: &subscriber)
        }
    }
    
    public mutating func clearSubscribers() {
        if var inner = source {
            inner.clearSubscribers()
        }
    }
}

extension AnySource: ReactiveNode {
    public mutating func markDirty() {
        if var inner = source {
            inner.markDirty()
        }
    }
    
    public mutating func markCheck() {
        if var inner = source {
            inner.markCheck()
        }
    }
    
    public mutating func markSubscribersCheck() {
        if var inner = source {
            inner.markSubscribersCheck()
        }
    }
    
    public mutating func updateIfNecessary() -> Bool {
        guard var inner = source else {
            return false
        }
        
        return inner.updateIfNecessary()
    }
}
