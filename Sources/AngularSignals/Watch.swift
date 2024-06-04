public typealias WatchCleanUpFunc = () -> Void

let NOOP_CLEANUP_FUNC: WatchCleanUpFunc = {}

internal final class Watch: ReactiveNode, Hashable, Equatable {
    static func == (lhs: Watch, rhs: Watch) -> Bool {
        lhs.id == rhs.id
    }

    lazy var hashValue = id

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    private var dirty = false
    private var cleanupFunc = NOOP_CLEANUP_FUNC

    private var watch: () -> Void
    private var schedule: (Watch) -> Void

    internal init(
        watch: @escaping () -> Void,
        schedule: @escaping (Watch) -> Void,
        allowSignalWrites: Bool
    ) {
        self.watch = watch
        self.schedule = schedule
        super.init()
        self.consumerAllowSignalWrites = allowSignalWrites
    }

    internal func notify() {
        if !dirty {
            schedule(self)
        }

        dirty = true
    }

    override internal func onConsumerDependencyMayHaveChanged() {
        notify()
    }

    override internal func onProducerUpdateValueVersion() {
        // Watches are not producers.
    }

    /**
     * Execute the reactive expression in the context of this `Watch` consumer.
     *
     * Should be called by the user scheduling algorithm when the provided
     * `schedule` hook is called by `Watch`.
     */
    internal func run() {
        dirty = false

        if trackingVersion != 0 && !consumerPollProducersForChange() {
            return
        }

        let prevConsumer = setActiveConsumer(self)
        trackingVersion += 1

        defer { setActiveConsumer(prevConsumer) }

        do {
            cleanupFunc()
            cleanupFunc = watch // ?? NOOP_CLEANUP_FUNC
        }
    }

    internal func cleanup() {
        cleanupFunc()
    }
}
