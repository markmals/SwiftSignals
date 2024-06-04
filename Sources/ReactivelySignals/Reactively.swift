//import Foundation

public func equals(_ lhs: Any?, _ rhs: Any?) -> Bool {
    func open<A: Equatable>(_ lhs: A, _ rhs: Any?) -> Bool {
        lhs == (rhs as? A)
    }

    guard let lhs = lhs as? any Equatable
    else { return false }

    return open(lhs, rhs)
}

// Current capture context for identifying reactive sources (other reactive elements) and cleanups
// active while evaluating a reactive function body.
struct ReactiveGraph {
    var currentReaction: (any ReactiveNode)? = nil
    var currentGets: [any ReactiveNode]? = nil
    var currentGetsIndex = 0
    
    /// A list of non-clean 'effect' nodes that will be updated when stabilize() is called
    var effectQueue: [any ReactiveNode] = []
    /// fn to call if there are dirty effect nodes
    var stabilizeFn: (() -> Void)? = nil
    /// stabilizeFn() is queued to run after this event loop
    var stabilizationQueued = false
}

enum CacheState: UInt {
    case clean = 0
    case check = 1
    case dirty = 2
    
    var isClean: Bool {
        return self == .clean
    }
}

@MainActor
internal protocol ReactiveNode: AnyObject {
    var state: CacheState { get set }
    var sources: [any ReactiveNode]? { get set }
    var observers: [any ReactiveNode]? { get set }
    var cleanups: [() -> Void] { get set }
    
    func trigger()
    
    func updateIfNecessary()
    func mark(as state: CacheState)
}

@MainActor
var graph = ReactiveGraph()

@MainActor
public protocol Signal<Wrapped> {
    associatedtype Wrapped
    func get() -> Wrapped
    func set(_ newValue: Wrapped)
}

@MainActor
final class Reactive<Wrapped>: ReactiveNode, Signal {
    private var _value: Wrapped! = nil
    private var function: (() -> Wrapped)? = nil
    var observers: [any ReactiveNode]? = nil
    var sources: [any ReactiveNode]? = nil
    
    var state: CacheState
    private var effect: Bool = false
    private var label: String?
    
    var cleanups: [() -> Void] = []
    
    init(_ initialValue: Wrapped, label: String? = nil) {
        self._value = initialValue
        self.state = .clean
        self.label = label
    }
    
    @discardableResult
    init(_ initialize: @escaping () -> Wrapped, effect: Bool = false, label: String? = nil) {
        self.function = initialize
        self.state = .dirty
        print("initial dirty (fn)", label ?? "")
        if effect {
            graph.effectQueue.append(self)
            graph.stabilizeFn?()
        }
        self.label = label
    }
    
    @discardableResult
    func get() -> Wrapped {
        if let currentReaction = graph.currentReaction {
            if let sources = currentReaction.sources, sources[graph.currentGetsIndex] === self, graph.currentGets == nil {
                graph.currentGetsIndex += 1
            } else {
                if var currentGets = graph.currentGets {
                    currentGets.append(self)
                } else {
                    graph.currentGets = [self]
                }
            }
        }
        
        if function != nil {
            updateIfNecessary()
        }
        
        return self._value
    }
    
    func trigger() {
        get()
    }
        
    func set(_ newValue: Wrapped) {
        if function != nil {
            removeParentObservers(at: 0)
            self.sources = nil
            function = nil
        }
        
        if equals(_value, newValue) {
            if let observers {
                for (index, _) in observers.enumerated() {
                    observers[index].mark(as: .dirty)
                }
            }
            
            _value = newValue
        }
    }
    
//    func set(_ newValue: @escaping () -> Wrapped) {
//        let fn = newValue
//        if fn !== self.function {
//            mark(as: .dirty)
//        }
//
//        self.function = fn
//    }
    
    func mark(as state: CacheState) {
        assert(!state.isClean)
        if self.state.rawValue < state.rawValue {
            // If we were previously clean, then we know that we may need to update to get the new value
            if self.state.isClean && effect {
                // EffectQueue.push(this);
                // stabilizeFn?.(this);
            }
            
            self.state = state
            
            if let observers {
                for (index, _) in observers.enumerated() {
                    observers[index].mark(as: .check)
                }
            }
        }
    }
    
    /// Run the computation fn, updating the cached value
    private func update() {
        let oldValue = self._value
        
        // Evalute the reactive function body, dynamically capturing any other reactives used
        let prevReaction = graph.currentReaction
        let prevGets = graph.currentGets
        let prevIndex = graph.currentGetsIndex
        
        graph.currentReaction = self
        graph.currentGets = nil
        graph.currentGetsIndex = 0
        
        if !cleanups.isEmpty {
            cleanups.forEach { cleanup in
                cleanup()
            }
            cleanups = []
        }
        
        _value = function!()
        
        // if the sources have changed, update source & observer links
        if let currentGets = graph.currentGets {
            // remove all old sources' .observers links to us
            removeParentObservers(at: graph.currentGetsIndex)
            // update source up links
            if var sources, graph.currentGetsIndex > 0 {
                sources.removeLast(graph.currentGetsIndex + currentGets.count)
                for i in 0...currentGets.count {
                    sources[graph.currentGetsIndex + i] = currentGets[i]
                }
            } else {
                sources = currentGets
            }
            
            for i in 0...graph.currentGetsIndex {
                // Add ourselves to the end of the parent .observers array
                let source = sources?[i]
                if var observers = source?.observers {
                    observers.append(self)
                } else {
                    source?.observers = [self]
                }
            }
        } else if var sources, graph.currentGetsIndex < sources.count {
            // remove all old sources' .observers links to us
            removeParentObservers(at: graph.currentGetsIndex)
            sources.removeLast(graph.currentGetsIndex)
        }
        
        defer {
            graph.currentGets = prevGets
            graph.currentReaction = prevReaction
            graph.currentGetsIndex = prevIndex
        }
        
        // handles diamond depenendencies if we're the parent of a diamond.
        if let observers, equals(oldValue, _value) {
            // We've changed value, so mark our children as dirty so they'll reevaluate
            for (index, _) in observers.enumerated() {
                observers[index].state = .dirty
            }
        }
        
        // We've rerun with the latest values from all of our sources.
        // This means that we no longer need to update until a signal changes
        state = .clean
    }
    
    /// `update()` if dirty, or a parent turns out to be dirty
    func updateIfNecessary() {
        // If we are potentially dirty, see if we have a parent who has actually changed value
        if state == .check {
            for (index, _) in sources!.enumerated() {
                sources![index].updateIfNecessary() // `updateIfNecessary()` can change this.state
                if state == .dirty {
                    // Stop the loop here so we won't trigger updates on other parents unnecessarily.
                    // If our computation changes to no longer use some sources, we don't
                    // want to `update()` a source we used last time, but now don't use.
                    break
                }
            }
        }
        
        // If we were already dirty or marked dirty by the step above, update.
        if state == .dirty {
            update()
        }
        
        // By now, we're clean
        state = .clean
    }
    
    private func removeParentObservers(at index: Int) {
        guard let sources else { return }
        
        for (index, _) in sources.enumerated() {
            let source = sources[index] // We don't actually delete sources here because we're replacing the entire array soon
            let swap = source.observers!.firstIndex(where: { $0 === self })!
            source.observers![swap] = source.observers![source.observers!.count - 1]
            let _ = source.observers!.popLast()
        }
    }
}

@MainActor
public func onCleanup(_ action: @escaping () -> Void) {
    if let current = graph.currentReaction {
        current.cleanups.append(action)
    } else {
        fatalError("onCleanup must be called from within a reactive function")
    }
}

/// run all non-clean effect nodes
@MainActor
public func stabilize() {
    for effect in graph.effectQueue {
        effect.trigger()
    }
    
    graph.effectQueue.removeAll()
}

/// run a function for each dirty effect node.
@MainActor
func autoStabilize(fn: @escaping @MainActor () -> Void = deferredStabilize) {
    graph.stabilizeFn = fn
}

/** queue stabilize() to run at the next idle time */
@MainActor
func deferredStabilize() {
    if (!graph.stabilizationQueued) {
//         graph.stabilizationQueued = true
        // queueMicrotask?
        graph.stabilizationQueued = false
        stabilize()
  }
}

/** A reactive element contains a mutable value that can be observed by other reactive elements.
 *
 * The property can be modified externally by calling set().
 *
 * Reactive elements may also contain a 0-ary function body that produces a new value using
 * values from other reactive elements.
 *
 * Dependencies on other elements are captured dynamically as the 'reactive' function body executes.
 *
 * The reactive function is re-evaluated when any of its dependencies change, and the result is
 * cached.
 */
@MainActor
public func signal<Wrapped: Equatable>(_ initialValue: Wrapped, label: String? = nil) -> some Signal<Wrapped> {
    return Reactive(initialValue, label: label)
}

@MainActor
public func memo<Wrapped: Equatable>(
    _ computation: @escaping @autoclosure () -> Wrapped, label: String? = nil
) -> (() -> Wrapped) {
    return Reactive(computation, effect: false, label: label).get
}

@MainActor
public func effect(_ action: @escaping () -> Void, label: String? = nil) {
    Reactive(action, effect: true, label: label)
}

@MainActor
public func root(_ closure: () -> Void) {
    autoStabilize()
    closure()
}
