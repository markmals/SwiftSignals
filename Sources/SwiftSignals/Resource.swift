import Foundation
import Observation

enum ResourceState {
    case unresolved
    case pending
    case ready
    case refreshing
    case errored
}

// FIXME: This doesn't track
@Observable
final class Resource<Value> {
    @ObservationIgnored
    private var resolved = false
    
    @ObservationIgnored
    private var task: Task<Value, any Error>? = nil
    
    @ObservationIgnored
    private var fetcher: () async throws -> Value

    private var _value: Value? = nil
    private var _state: ResourceState
    private var _error: (any Error)? = nil
    
    init(_ fetcher: @escaping () async throws -> Value) {
        self._state = resolved ? .ready : .unresolved
        self.fetcher = fetcher
        
        createEffect {
            Task {
                await self.load()
            }
        }
    }
    
    private func loadEnd(task: Task<Value, Error>?, value: Value?, error: (any Error)?) {
        if self.task == task {
            self.task = nil
            self.resolved = true
            self.completeLoad(value, error)
        }
    }
    
    private func completeLoad(_ value: Value?, _ error: (any Error)?) {
        if error == nil { self._value = value }
        self._state = error != nil ? .errored : .ready
        self._error = error
    }
    
    private func load() async {
        self.task = Task<Value, any Error> {
            try await fetcher()
        }
        
        self._state = self.resolved ? .refreshing : .pending
        
        do {
            let value = try await self.task?.value
            self.loadEnd(task: task, value: value, error: nil)
        } catch {
            self.loadEnd(task: task, value: nil, error: error)
        }
    }
    
    public var value: Value? {
        if let _ = self._error, self.task == nil {
            return nil
        }
        
        return self._value
    }
    
    public var state: ResourceState {
        self._state
    }
    
    public var loading: Bool {
        self._state == .pending || self._state == .refreshing
    }
    
    public var error: (any Error)? {
        self._error
    }
    
    public var latest: Value? {
        if !self.resolved { return self._value }
        if let _ = self.error, self.task == nil { return nil }
        return self.value
    }
}

//struct Character: Decodable {
//    var name: String
//}

//let (id, setID) = createSignal(1)
//let resource = Resource {
//    let (data, _) = try await URLSession.shared.data(from: URL(string: "https://swapi.dev/api/people/\(id())/")!)
//    let character = try JSONDecoder().decode(Character.self, from: data)
//    return character
//}
//
//let _ = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
//    setID(id() + 1)
//}
//
//createEffect {
//    print(resource.value ?? "No character yet")
//}
//
//RunLoop.main.run()
