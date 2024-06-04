//@propertyWrapper
//struct Derived<Wrapped: Equatable> {
//    var value: () -> Wrapped
//
//    var wrappedValue: Wrapped {
//        get { value() }
//    }
//
//    init(wrappedValue: @escaping @autoclosure () -> Wrapped) {
//        self.value = wrappedValue
//    }
//}
//
//@propertyWrapper
//struct State<Wrapped: Equatable> {
//    var wrappedValue: Wrapped
//
//    init(wrappedValue: Wrapped) {
//        self.wrappedValue = wrappedValue
//    }
//}
