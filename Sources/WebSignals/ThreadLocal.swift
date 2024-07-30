import Foundation

@propertyWrapper
struct ThreadLocal<Value> {
    private var threadDictionary: NSMutableDictionary {
        Thread.current.threadDictionary
    }
    
    private var key: NSString
    
    init(wrappedValue: Value?) {
        let box = Box(wrappedValue)
        self.key = NSString(string: "\(Unmanaged.passUnretained(box).toOpaque())")
        
        guard let wrappedValue else {
            // Is this necessary in the init too?
            threadDictionary.removeObject(forKey: self.key)
            return
        }

        guard let threadBox = threadDictionary.object(forKey: self.key) as? Box<Value> else {
            threadDictionary.setObject(box, forKey: self.key)
            return
        }
        
        threadBox.wrappedValue = wrappedValue
    }
    
    var wrappedValue: Value? {
        get {
            (threadDictionary.object(forKey: key) as? Box<Value>)?.wrappedValue
        }
        set {
            guard let newValue else {
                threadDictionary.removeObject(forKey: key)
                return
            }
            
            guard let box = threadDictionary.object(forKey: key) as? Box<Value> else {
                threadDictionary.setObject(Box(newValue), forKey: key)
                return
            }
            
            box.wrappedValue = newValue
        }
    }
}

extension ThreadLocal {
    private class Box<Wrapped> {
        var wrappedValue: Wrapped
        
        init(_ wrappedValue: Wrapped) {
            self.wrappedValue = wrappedValue
        }
    }
}
