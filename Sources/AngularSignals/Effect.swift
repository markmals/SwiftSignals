@discardableResult
public func effect(_ effectFunc: @escaping () -> Void) -> EffectRef {
    // TODO: Allow signal writes in effects
    // Using effects to synchronize data by writing to signals can lead to confusing and
    // potentially incorrect behavior, and should be enabled only when necessary.
    EffectManager().create(effectFunc: effectFunc, allowSignalWrites: false)
}

// @discardableResult
// public func effect(_ effectFunc: () -> EffectCleanUpFunc) -> EffectRef {
//     EffectManager().create(effectFunc: effectFunc, allowSignalWrites: false)
// }

public typealias EffectCleanUpFunc = () -> Void

public struct EffectRef {
    let destroy: () -> Void
}

// TODO: Convert Zone.js references to Swift Concurrency
// Maybe this should be an actor?
final class EffectManager {
    private var all = Set<Watch>()
    // private var queue = [Watch: Zone]()

    func create(effectFunc: @escaping () -> Void, allowSignalWrites: Bool) -> EffectRef {
        // let zone = Zone.current

        let watch = Watch(
            watch: effectFunc,
            schedule: { [unowned self] watch in
                if !all.contains(watch) {
                    return
                }

                // queue.set(watch, zone)
            },
            allowSignalWrites: allowSignalWrites
        )

        all.insert(watch)

        // Effects start dirty.
        watch.notify()

        // let unregisterOnDestroy: (() -> Void)?

        let destroy: () -> Void = { [unowned self] in
            watch.cleanup()
            // unregisterOnDestroy?()
            all.remove(watch)
            // queue.delete(watch)
        }

        // unregisterOnDestroy = destroyRef?.onDestroy(destroy)

        return EffectRef(destroy: destroy)
    }

    // func flush() {
    //     if queue.count == 0 {
    //         return
    //     }

    //     for (watch, zone) in queue {
    //         queue.remove(watch)
    //         zone.run { watch.run() }
    //     }
    // }

    // var isQueueEmpty: Bool {
    //     queue.count == 0
    // }
}

// TODO: Support async effects
