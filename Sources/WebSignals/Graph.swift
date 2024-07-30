import Foundation

// TODO: Replace `@ThreadLocal` with `@TaskLocal` if possible

enum ReactiveScope {
    /**
     * The currently active consumer `ReactiveNode`, if running code in a reactive context.
     *
     * Change this via `setActiveConsumer`.
     */
    @ThreadLocal fileprivate static var activeConsumer: (any ReactiveNode)? = nil
    @ThreadLocal fileprivate static var inNotificationPhase = false
    
    /**
     * Global epoch counter. Incremented whenever a source signal is set.
     */
    @ThreadLocal fileprivate static var epoch: UInt? = 1
    
    @discardableResult
    static func setActiveConsumer(consumer: (any ReactiveNode)?) -> (any ReactiveNode)? {
        let prev = ReactiveScope.activeConsumer
        ReactiveScope.activeConsumer = consumer
        return prev
    }
    
    static func getActiveConsumer() -> (any ReactiveNode)? {
        ReactiveScope.activeConsumer
    }
    
    static var isInNotificationPhase: Bool {
        get { ReactiveScope.inNotificationPhase ?? false }
        set { ReactiveScope.inNotificationPhase = newValue }
    }
        
    /**
     * Increment the global epoch counter.
     *
     * Called by source producers (that is, not computeds) whenever their values change.
     */
    static func producerIncrementEpoch() {
        if var epoch { epoch += 1 }
    }
            
    /**
     * Whether this `ReactiveNode` in its producer capacity is currently allowed to initiate updates,
     * based on the current consumer context.
     */
    static func producerUpdatesAllowed() -> Bool {
        return activeConsumer?.consumerAllowSignalWrites != false
    }
    
    /**
     * Prepare this consumer to run a computation in its reactive context.
     *
     * Must be called by subclasses which represent reactive computations, before those computations
     * begin.
     */
    static func consumerBeforeComputation(node: inout (any ReactiveNode)?) -> (any ReactiveNode)? {
        if var node {
            node.nextProducerIndex = 0
        }
        
        return setActiveConsumer(consumer: node)
    }
}

/**
 * A producer and/or consumer which participates in the reactive graph.
 *
 * Producer `ReactiveNode`s which are accessed when a consumer `ReactiveNode` is the
 * `activeConsumer` are tracked as dependencies of that consumer.
 *
 * Certain consumers are also tracked as "live" consumers and create edges in the other direction,
 * from producer to consumer. These edges are used to propagate change notifications when a
 * producer's value is updated.
 *
 * A `ReactiveNode` may be both a producer and consumer.
 */
protocol ReactiveNode: Identifiable<UUID> {
    /**
     * Version of the value that this node produces.
     *
     * This is incremented whenever a new value is produced by this node which is not equal to the
     * previous value (by whatever definition of equality is in use).
     */
    var version: UInt? { get set }
    
    /**
     * Epoch at which this node is verified to be clean.
     *
     * This allows skipping of some polling operations in the case where no signals have been set
     * since this node was last read.
     */
    var lastCleanEpoch: UInt? { get set }
    
    /**
     * Whether this node (in its consumer capacity) is dirty.
     *
     * Only live consumers become dirty, when receiving a change notification from a dependency
     * producer.
     */
    var dirty: Bool { get set }
    
    /**
     * Producers which are dependencies of this consumer.
     *
     * Uses the same indices as the `producerLastReadVersion` and `producerIndexOfThis` arrays.
     */
    var producerNode: [any ReactiveNode]? { get set }
    
    /**
     * `Version` of the value last read by a given producer.
     *
     * Uses the same indices as the `producerNode` and `producerIndexOfThis` arrays.
     */
    var producerLastReadVersion: [UInt?]? { get set }
    
    /**
     * Index of `this` (consumer) in each producer's `liveConsumers` array.
     *
     * This value is only meaningful if this node is live (`liveConsumers.length > 0`). Otherwise
     * these indices are stale.
     *
     * Uses the same indices as the `producerNode` and `producerLastReadVersion` arrays.
     */
    var producerIndexOfThis: [Int]? { get set }
    
    /**
     * Index into the producer arrays that the next dependency of this node as a consumer will use.
     *
     * This index is zeroed before this node as a consumer begins executing. When a producer is read,
     * it gets inserted into the producers arrays at this index. There may be an existing dependency
     * in this location which may or may not match the incoming producer, depending on whether the
     * same producers were read in the same order as the last computation.
     */
    var nextProducerIndex: Int { get set }
    
    /**
     * Array of consumers of this producer that are "live" (they require push notifications).
     *
     * `liveConsumerNode.length` is effectively our reference count for this node.
     */
    var liveConsumerNode: [any ReactiveNode]? { get set }
    
    /**
     * Index of `this` (producer) in each consumer's `producerNode` array.
     *
     * Uses the same indices as the `liveConsumerNode` array.
     */
    var liveConsumerIndexOfThis: [Int?]? { get set }
    
    /**
     * Whether writes to signals are allowed when this consumer is the `activeConsumer`.
     *
     * This is used to enforce guardrails such as preventing writes to writable signals in the
     * computation function of computed signals, which is supposed to be pure.
     */
    var consumerAllowSignalWrites: Bool { get set }
    
    var consumerIsAlwaysLive: Bool { get }
    
    /**
     * Tracks whether producers need to recompute their value independently of the reactive graph (for
     * example, if no initial value has been computed).
     */
    func producerMustRecompute(node: Any) -> Bool
    func producerRecomputeValue(node: Any)
    func consumerMarkedDirty(this: Any)
    
    /**
     * Called when a signal is read within this consumer.
     */
    func consumerOnSignalRead(node: Any)
    
    /**
     * Called when the signal becomes "live"
     */
    var watched: (() -> Void)? { get set }
    
    /**
     * Called when the signal stops being "live"
     */
    var unwatched: (() -> Void)? { get set }
    
    /**
     * Optional extra data for embedder of this signal library.
     * Sent to various callbacks as the this value.
     */
    var wrapper: Any? { get set }
}

extension ReactiveNode {
    /**
     * Called by implementations when a producer's signal is read.
     */
    mutating func producerAccessed() {
        guard !ReactiveScope.isInNotificationPhase else {
            fatalError("signal read during notification phase")
        }
        
        guard var activeConsumer = ReactiveScope.activeConsumer else {
            // Accessed outside of a reactive context, so nothing to record.
            return
        }
        
        activeConsumer.consumerOnSignalRead(node: self)
        
        // This producer is the `idx`th dependency of `activeConsumer`.
        activeConsumer.nextProducerIndex += 1
        var idx = activeConsumer.nextProducerIndex
        
        activeConsumer.hydrateConsumerNode()
        
        if var producer = activeConsumer.producerNode, idx < producer.count && producer[idx].id != id {
            // There's been a change in producers since the last execution of `activeConsumer`.
            // `activeConsumer.producerNode[idx]` holds a stale dependency which will be be removed and
            // replaced with `self`.
            //
            // If `activeConsumer` isn't live, then this is a no-op, since we can replace the producer in
            // `activeConsumer.producerNode` directly. However, if `activeConsumer` is live, then we need
            // to remove it from the stale producer's `liveConsumer`s.
            if activeConsumer.consumerIsLive, let producerIndex = activeConsumer.producerIndexOfThis?[idx] {
                var staleProducer = producer[idx]
                staleProducer.removeLiveConsumer(atIndex: producerIndex)
                
                // At this point, the only record of `staleProducer` is the reference at
                // `activeConsumer.producerNode[idx]` which will be overwritten below.
            }
        }
        
        if activeConsumer.producerNode?[idx].id != id {
            // We're a new dependency of the consumer (at `idx`).
            activeConsumer.producerNode?[idx] = self
            
            // If the active consumer is live, then add it as a live consumer. If not, then use 0 as a
            // placeholder value.
            activeConsumer.producerIndexOfThis?[idx] = activeConsumer.consumerIsLive
                ? add(liveConsumer: &activeConsumer, atIndex: idx)
                : 0
        }
        
        activeConsumer.producerLastReadVersion?[idx] = version
    }

    /**
     * Ensure this producer's `version` is up-to-date.
     */
    mutating func producerUpdateValueVersion() {
        if consumerIsLive && !dirty {
            // A live consumer will be marked dirty by producers, so a clean state means that its version
            // is guaranteed to be up-to-date.
            return
        }
        
        if !dirty && lastCleanEpoch == ReactiveScope.epoch {
            // Even non-live consumers can skip polling if they previously found themselves to be clean at
            // the current epoch, since their dependencies could not possibly have changed (such a change
            // would've increased the epoch).
            return
        }
        
        if !producerMustRecompute(node: self) && !consumerPollProducersForChange() {
            // None of our producers report a change since the last time they were read, so no
            // recomputation of our value is necessary, and we can consider ourselves clean.
            dirty = false
            lastCleanEpoch = ReactiveScope.epoch
            return
        }
        
        producerRecomputeValue(node: self)
        
        // After recomputing the value, we're no longer dirty.
        dirty = false
        lastCleanEpoch = ReactiveScope.epoch
    }

    /**
     * Propagate a dirty notification to live consumers of this producer.
     */
    mutating func producerNotifyConsumers() {
        if liveConsumerNode == nil {
            return
        }
        
        // Prevent signal reads when we're updating the graph
        let prev = ReactiveScope.isInNotificationPhase
        ReactiveScope.isInNotificationPhase = true
        defer { ReactiveScope.isInNotificationPhase = prev }
        
        if var consumers = liveConsumerNode {
            for index in consumers.indices where !consumers[index].dirty {
                consumers[index].consumerMarkDirty()
            }
        }
    }
    
    mutating func consumerMarkDirty() {
        dirty = true
        producerNotifyConsumers()
        consumerMarkedDirty(this: wrapper ?? self)
    }

    /**
     * Finalize this consumer's state after a reactive computation has run.
     *
     * Must be called by subclasses which represent reactive computations, after those computations
     * have finished.
     */
    mutating func consumerAfterComputation(prevConsumer: (any ReactiveNode)?) {
        ReactiveScope.setActiveConsumer(consumer: prevConsumer)
        
        guard
            var producerNode,
            var producerIndexOfThis,
            var producerLastReadVersion
        else {
            return
        }
        
        if consumerIsLive {
            // For live consumers, we need to remove the producer -> consumer edge for any stale producers
            // which weren't dependencies after the recomputation.
            for index in nextProducerIndex..<producerNode.count {
                producerNode[index].removeLiveConsumer(atIndex: producerIndexOfThis[index])
            }
        }
        
        // Truncate the producer tracking arrays.
        // Perf note: this is essentially truncating the length to `node.nextProducerIndex`, but
        // benchmarking has shown that individual pop operations are faster.
        while producerNode.count > nextProducerIndex {
            producerNode.removeLast()
            producerLastReadVersion.removeLast()
            producerIndexOfThis.removeLast()
        }
    }
    
    /**
     * Determine whether this consumer has any dependencies which have changed since the last time
     * they were read.
     */
    mutating func consumerPollProducersForChange() -> Bool {
        hydrateConsumerNode()
        
        if let producerNode {
            // Poll producers for change.
            for index in producerNode.indices {
                var producer = producerNode[index]
                let seenVersion = producerLastReadVersion?[index]
                
                // First check the versions. A mismatch means that the producer's value is known to have
                // changed since the last time we read it.
                if seenVersion != producer.version {
                    return true
                }
                
                // The producer's version is the same as the last time we read it, but it might itself be
                // stale. Force the producer to recompute its version (calculating a new value if necessary).
                producer.producerUpdateValueVersion()
                
                // Now when we do this check, `producer.version` is guaranteed to be up to date, so if the
                // versions still match then it has not changed since the last time we read it.
                if seenVersion != producer.version {
                    return true
                }
            }
        }
        
        return false
    }
    
    /**
     * Disconnect this consumer from the graph.
     */
    mutating func consumerDestroy() {
        hydrateConsumerNode()
        
        // Drop all connections from the graph to this node.
        if consumerIsLive, var producerNode {
            for index in producerNode.indices {
                if let producerIndex = producerIndexOfThis?[index] {
                    producerNode[index].removeLiveConsumer(atIndex: producerIndex)
                }
            }
        }
        
        // Truncate all the arrays to drop all connection from this node to the graph.
        producerNode?.removeAll()
        producerLastReadVersion?.removeAll()
        producerIndexOfThis?.removeAll()

        if var liveConsumerNode {
            liveConsumerNode.removeAll()
            liveConsumerIndexOfThis?.removeAll()
        }
    }


    /**
     * Add `consumer` as a live consumer of this node.
     *
     * Note that this operation is potentially transitive. If this node becomes live, then it becomes
     * a live consumer of all of its current producers.
     */
    private mutating func add(
        liveConsumer consumer: inout some ReactiveNode,
        atIndex index: Int
    ) -> Int {
        hydrateProducerNode()
        hydrateConsumerNode()
        
        if let liveConsumerNode = liveConsumerNode, liveConsumerNode.isEmpty {
//            node.watched?(node.wrapper)
            watched?()
            if var producerNode = producerNode {
                // When going from 0 to 1 live consumers, we become a live consumer to our producers.
                for index in producerNode.indices {
                    producerIndexOfThis?[index] = producerNode[index].add(liveConsumer: &self, atIndex: index)
                }
            }
        }
        
        liveConsumerIndexOfThis?.append(index)
        liveConsumerNode?.append(consumer)
        return liveConsumerNode?.firstIndex(where: { $0.id == consumer.id }) ?? 0 - 1
    }

    /**
     * Remove the live consumer at `idx`.
     */
    mutating func removeLiveConsumer(atIndex index: Int) {
        hydrateProducerNode()
        hydrateConsumerNode()
        
        //      if (typeof ngDevMode !== 'undefined' && ngDevMode && idx >= node.liveConsumerNode.length) {
        //        throw new Error(
        //          `Assertion error: active consumer index ${idx} is out of bounds of ${node.liveConsumerNode.length} consumers)`,
        //        )
        //      }
        
        if var liveConsumerNode = liveConsumerNode {
            if liveConsumerNode.count == 1 {
                // When removing the last live consumer, we will no longer be live. We need to remove
                // ourselves from our producers' tracking (which may cause consumer-producers to lose
                // liveness as well).
                //        unwatched?(node.wrapper)
                unwatched?()
                
                if var producerNode = producerNode {
                    for index in producerNode.indices {
                        if let producerIndex = producerIndexOfThis?[index] {
                            producerNode[index].removeLiveConsumer(atIndex: producerIndex)
                        }
                    }
                }
            }
        
            // Move the last value of `liveConsumers` into `idx`. Note that if there's only a single
            // live consumer, this is a no-op.
            let lastIdx = liveConsumerNode.count - 1
            liveConsumerNode[index] = liveConsumerNode[lastIdx]
            liveConsumerIndexOfThis?[index] = liveConsumerIndexOfThis?[lastIdx]
            
            // Truncate the array.
            liveConsumerNode.removeLast()
            liveConsumerIndexOfThis?.removeLast()
            
            // If the index is still valid, then we need to fix the index pointer from the producer to this
            // consumer, and update it from `lastIdx` to `idx` (accounting for the move above).
            if index < liveConsumerNode.count {
                if let idxProducer = liveConsumerIndexOfThis?[index] {
                    var consumer = liveConsumerNode[index]
                    consumer.hydrateConsumerNode()
                    consumer.producerIndexOfThis?[idxProducer] = index
                }
            }
        }
    }

    fileprivate var consumerIsLive: Bool {
        consumerIsAlwaysLive == true || (liveConsumerNode?.count ?? 0) > 0
    }

    mutating func hydrateConsumerNode() /* -> any ConsumerNode */ {
        if producerNode == nil { producerNode = [] }
        if producerIndexOfThis == nil { producerIndexOfThis = [] }
        if producerLastReadVersion == nil { producerLastReadVersion = [] }
//        return self as! any ConsumerNode
    }
    
    mutating func hydrateProducerNode() /* -> any ProducerNode */ {
        if liveConsumerNode == nil { liveConsumerNode = [] }
        if liveConsumerIndexOfThis == nil { liveConsumerIndexOfThis = [] }
//        return self as! any ProducerNode
    }
}

struct MainNode: ReactiveNode {
    let id: UUID

    var version: UInt?
    var lastCleanEpoch: UInt?
    var dirty: Bool
    var producerNode: [any ReactiveNode]?
    var producerLastReadVersion: [UInt?]?
    var producerIndexOfThis: [Int]?
    var nextProducerIndex: Int
    var liveConsumerNode: [any ReactiveNode]?
    var liveConsumerIndexOfThis: [Int?]?
    var consumerAllowSignalWrites: Bool
    var consumerIsAlwaysLive: Bool
    
    init(
        version: UInt? = nil,
        lastCleanEpoch: UInt? = nil,
        dirty: Bool,
        producerNode: [any ReactiveNode]? = nil,
        producerLastReadVersion: [UInt]? = nil,
        producerIndexOfThis: [Int]? = nil,
        nextProducerIndex: Int,
        liveConsumerNode: [any ReactiveNode]? = nil,
        liveConsumerIndexOfThis: [Int]? = nil,
        consumerAllowSignalWrites: Bool,
        consumerIsAlwaysLive: Bool, watched: (() -> Void)? = nil,
        unwatched: (() -> Void)? = nil,
        wrapper: Any? = nil
    ) {
        self.id = UUID()

        self.version = version
        self.lastCleanEpoch = lastCleanEpoch
        self.dirty = dirty
        self.producerNode = producerNode
        self.producerLastReadVersion = producerLastReadVersion
        self.producerIndexOfThis = producerIndexOfThis
        self.nextProducerIndex = nextProducerIndex
        self.liveConsumerNode = liveConsumerNode
        self.liveConsumerIndexOfThis = liveConsumerIndexOfThis
        self.consumerAllowSignalWrites = consumerAllowSignalWrites
        self.consumerIsAlwaysLive = consumerIsAlwaysLive
        self.watched = watched
        self.unwatched = unwatched
        self.wrapper = wrapper
    }
        
    func producerMustRecompute(node: Any) -> Bool {
        return false
    }
    
    func producerRecomputeValue(node: Any) {}
    func consumerMarkedDirty(this: Any) {}
    func consumerOnSignalRead(node: Any) {}
    
    var watched: (() -> Void)?
    var unwatched: (() -> Void)?
    var wrapper: Any?
}

extension MainNode {
    @ThreadLocal static var shared: Self? = .init(
        version: 0,
        lastCleanEpoch: 0,
        dirty: false,
        nextProducerIndex: 0,
        consumerAllowSignalWrites: false,
        consumerIsAlwaysLive: false
    )
}

//protocol ConsumerNode: ReactiveNode {
//    var producerNode: [any ReactiveNode] { get set }
//    var producerIndexOfThis: [Int] { get set }
//    var producerLastReadVersion: [UInt]{ get set }
//}
//
//protocol ProducerNode: ReactiveNode {
//    var liveConsumerNode: [any ReactiveNode] { get set }
//    var liveConsumerIndexOfThis: [Int] { get set }
//}

