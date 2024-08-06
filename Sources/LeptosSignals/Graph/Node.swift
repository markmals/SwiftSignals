/// A node in the reactive graph.
public protocol ReactiveNode {
    /// Notifies the source's dependencies that it has changed.
    mutating func markDirty()

    /// Notifies the source's dependencies that it may have changed.
    mutating func markCheck()

    /// Marks that all subscribers need to be checked.
    mutating func markSubscribersCheck()

    /// Regenerates the value for this node, if needed, and returns whether
    /// it has actually changed or not.
    mutating func updateIfNecessary() -> Bool
}

/// The current state of a reactive node.
public enum ReactiveNodeState: Comparable {
    /// The node is known to be clean: i.e., either none of its sources have changed, or its
    /// sources have changed but its value is unchanged and its dependencies do not need to change.
    case clean
    /// The node may have changed, but it is not yet known whether it has actually changed.
    case check
    /// The node's value has definitely changed, and subscribers will need to update.
    case dirty
}
