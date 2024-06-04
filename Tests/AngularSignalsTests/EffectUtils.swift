@testable import AngularSignals

var queue = Set<Watch>()

/**
 * A wrapper around `Watch` that emulates the `effect` API and allows for more streamlined testing.
 */
@discardableResult
func testingEffect(effectFunc: @escaping ((WatchCleanUpFunc) -> Void) -> Void) -> EffectRef {
    // FIXME: How does effectFunc get watch's cleanup
    // Also, doesn't watch need a real clean up instead of just no-op?
    func cleanup(fn: WatchCleanUpFunc) {}

    let watch = Watch(
        watch: { effectFunc(cleanup) },
        schedule: { queue.insert($0) },
        allowSignalWrites: true
    )

    // Effects start dirty.
    watch.notify()
    return EffectRef(destroy: watch.cleanup)
}

func flushEffects() {
    for watch in queue {
        queue.remove(watch)
        watch.run()
    }
}

func resetEffects() {
    queue.removeAll()
}
