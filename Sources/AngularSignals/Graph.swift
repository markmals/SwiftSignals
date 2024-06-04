/// Counter tracking the next `ProducerID` or `ConsumerID`.
private var nextReactiveID: Int = 0

/// Tracks the currently active reactive consumer (or `null` if there is no active consumer).
private var activeConsumer: ReactiveNode?

/// Whether the graph is currently propagating change notifications.
private var inNotificationPhase = false

@discardableResult
func setActiveConsumer(_ consumer: ReactiveNode?) -> ReactiveNode? {
    let prev = activeConsumer
    activeConsumer = consumer
    return prev
}

/// A bidirectional edge in the dependency graph of `ReactiveNode`s.
struct ReactiveEdge {
    /// Weakly held reference to the consumer side of this edge.
    weak var producerNode: ReactiveNode?

    /// Weakly held reference to the producer side of this edge.
    weak var consumerNode: ReactiveNode?

    /// `trackingVersion` of the consumer at which this dependency edge was last observed.
    ///
    /// If this doesn't match the consumer's current `trackingVersion`, then this dependency record
    /// is stale, and needs to be cleaned up.
    var atTrackingVersion: Int?

    /// `valueVersion` of the producer at the time this dependency was last accessed.
    var seenValueVersion: Int
}

open class ReactiveNode {
    internal let id = nextReactiveID + 1

    /// A cached weak reference to this node, which will be used in `ReactiveEdge`s.
    private weak var ref: ReactiveNode?

    init() {
        ref = self
    }

    /// Edges to producers on which this node depends (in its consumer capacity).
    private var producers = [Int: ReactiveEdge]()

    /// Edges to consumers on which this node depends (in its producer capacity).
    private var consumers = [Int: ReactiveEdge]()

    /// Monotonically increasing counter representing a version of this `Consumer`'s dependencies.
    open var trackingVersion = 0

    /// Monotonically increasing counter which increases when the value of this `Producer` semantically changes.
    open var valueVersion = 0

    /// Whether signal writes should be allowed while this `ReactiveNode` is the current consumer.
    open var consumerAllowSignalWrites: Bool = false

    /// Called for consumers whenever one of their dependencies notifies that it might have a new value.
    open func onConsumerDependencyMayHaveChanged() {
        fatalError("abstract method")
    }

    /// Called for producers when a dependent consumer is checking if the producer's value has actually changed.
    open func onProducerUpdateValueVersion() {
        fatalError("abstract method")
    }

    /**
     * Polls dependencies of a consumer to determine if they have actually changed.
     *
     * If this returns `false`, then even though the consumer may have previously been notified of a
     * change, the values of its dependencies have not actually changed and the consumer should not
     * rerun any reactions.
     */
    open func consumerPollProducersForChange() -> Bool {
        for (producerID, edge) in producers {
            let producer = edge.producerNode

            if producer == nil || edge.atTrackingVersion != trackingVersion {
                // This dependency edge is stale, so remove it.
                producers.removeValue(forKey: producerID)
                producer?.consumers.removeValue(forKey: id)
                continue
            }

            if let producer = producer,
               producer.producerPollStatus(lastSeenValueVersion: edge.seenValueVersion)
            {
                // One of the dependencies reports a real value change.
                return true
            }
        }

        // No dependency reported a real value change, so the `Consumer` has also not been
        // impacted.
        return false
    }

    /**
     * Notify all consumers of this producer that its value may have changed.
     */
    open func producerMayHaveChanged() {
        // Prevent signal reads when we're updating the graph
        let prev = inNotificationPhase
        inNotificationPhase = true

        defer { inNotificationPhase = prev }
        do {
            for (consumerID, edge) in consumers {
                let consumer = edge.consumerNode

                if consumer == nil || consumer?.trackingVersion != edge.atTrackingVersion {
                    consumers.removeValue(forKey: consumerID)
                    consumer?.producers.removeValue(forKey: id)
                    continue
                }

                consumer?.onConsumerDependencyMayHaveChanged()
            }
        }
    }

    /**
     * Mark that this producer node has been accessed in the current reactive context.
     */
    open func producerAccessed() {
        if inNotificationPhase {
            // FIXME: Make this a recoverable error
            fatalError("Assertion error: signal read during notification phase")
        }

        if let activeConsumer = activeConsumer {
            // Either create or update the dependency `Edge` in both directions.
            if var edge = activeConsumer.producers[id] {
                edge.seenValueVersion = valueVersion
                edge.atTrackingVersion = activeConsumer.trackingVersion
                activeConsumer.producers[id] = edge
            }
            else {
                let edge = ReactiveEdge(
                    producerNode: ref,
                    consumerNode: activeConsumer,
                    atTrackingVersion: activeConsumer.trackingVersion,
                    seenValueVersion: valueVersion
                )

                activeConsumer.producers[id] = edge
                consumers[activeConsumer.id] = edge
            }
        }
    }

    /**
     * Whether this consumer currently has any producers registered.
     */
    open var hasProducers: Bool {
        producers.count > 0
    }

    /**
     * Whether this `ReactiveNode` in its producer capacity is currently allowed to initiate updates,
     * based on the current consumer context.
     */
    open var producerUpdatesAllowed: Bool {
        !(activeConsumer?.consumerAllowSignalWrites ?? false)
    }

    /**
     * Checks if a `Producer` has a current value which is different than the value
     * last seen at a specific version by a `Consumer` which recorded a dependency on
     * this `Producer`.
     */
    private func producerPollStatus(lastSeenValueVersion: Int) -> Bool {
        // `producer.valueVersion` may be stale, but a mismatch still means that the value
        // last seen by the `Consumer` is also stale.
        if valueVersion != lastSeenValueVersion {
            return true
        }

        // Trigger the `Producer` to update its `valueVersion` if necessary.
        onProducerUpdateValueVersion()

        // At this point, we can trust `producer.valueVersion`.
        return valueVersion != lastSeenValueVersion
    }
}
