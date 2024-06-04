//function defaultThrowError(): never {
//  throw new Error();
//}
//
//let throwInvalidWriteToSignalErrorFn = defaultThrowError;
//
//export function throwInvalidWriteToSignalError() {
//  throwInvalidWriteToSignalErrorFn();
//}
//
//export function setThrowInvalidWriteToSignalError(fn: () => never): void {
//  throwInvalidWriteToSignalErrorFn = fn;
//}

import Foundation

struct SignalError: LocalizedError, Equatable {
    var errorDescription: String
    
    init(_ errorDescription: String = "") {
        self.errorDescription = errorDescription
    }
}

private var throwInvalidWriteToSignalErrorFunc = SignalError.init

func throwInvalidWriteToSignalError() throws {
    throw throwInvalidWriteToSignalErrorFunc("Invalid Write to Signal Error")
}

func throwInvalidWriteToSignalErrorFunc(_ fn: @escaping (String) -> SignalError) {
    throwInvalidWriteToSignalErrorFunc = fn
}
