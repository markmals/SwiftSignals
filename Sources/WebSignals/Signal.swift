import Foundation

enum SignalState {
    /**
     * If set, called after `WritableSignal`s are updated.
     *
     * This hook can be used to achieve various effects, such as running effects synchronously as part
     * of setting a signal.
     */
    @ThreadLocal static var postSignalSetFunc: (() -> Void)? = nil
}

protocol SignalNode<T>: ReactiveNode {
    associatedtype T
    
    var value: T { get set }
//    var equal: (T, T) -> Bool { get set }
}

/**
 * Create a `Signal` that can be set or updated directly.
 */
//export function createSignal<T>(initialValue: T): SignalGetter<T> {
//  const node: SignalNode<T> = Object.create(SIGNAL_NODE);
//  node.value = initialValue;
//  const getter = (() => {
//    producerAccessed(node);
//    return node.value;
//  }) as SignalGetter<T>;
//  (getter as any)[SIGNAL] = node;
//  return getter;
//}

final class SignalImpl<T>: SignalNode<T> {
    
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
    
    func producerMustRecompute(node: Any) -> Bool {
        <#code#>
    }
    
    func producerRecomputeValue(node: Any) {
        <#code#>
    }
    
    func consumerMarkedDirty(this: Any) {
        <#code#>
    }
    
    func consumerOnSignalRead(node: Any) {
        <#code#>
    }
    
    var watched: (() -> Void)?
    
    var unwatched: (() -> Void)?
    
    var wrapper: Any?
    
    var id: UUID
        
    private var wrappedValue: T
    private var equal: (T, T) -> Bool

    init(_ initialValue: T) {
        self.wrappedValue = initialValue
    }
    
    var value: T {
        producerAccessed()
        return wrappedValue
    }
}
