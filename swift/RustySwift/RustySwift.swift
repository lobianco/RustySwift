//
//  RustySwift.swift
//  RustySwift
//
//  Created by Anthony on 10/25/19.
//  Copyright © 2019 Planet 4. All rights reserved.
//

import Foundation

// MARK: Public

public typealias StringCallback = (String?) -> Void

// This is a wrapper class that compartmentalizes all the Rust integration logic.
// Outside classes can call the functions exposed in the public interface with a
// JSON-encoded request as input, and optionally provide a callback that will be
// invoked after the work is done. The callback has one parameter, an optional
// string, that will be the JSON-encoded response.
//
public class RustySwift {

    // the background queue to run the Rust function on
    private static let workQueue = DispatchQueue(
        label: "com.lobianco.RustySwift.workQueue",
        qos: .background,
        attributes: .concurrent
    )

    // Calls the fetchWeather() function in Rust.
    //
    // - Parameters:
    //   - json: A JSON-encoded request string
    //   - completion: An optional closure that will fire upon completion
    //
    public static func rustyFetchWeather(with json: String, completion: StringCallback?) {
        invoke(
            rustFunction: fetch_weather,
            with: json,
            on: workQueue,
            completion: completion
        )
    }
    
}

// MARK: Internal

private extension RustySwift {

    // The Swift-ified representation of the fetchWeather() Rust function signature
    //
    // - Parameters:
    //   - unsafe pointer to the encoded JSON request
    //   - the C representation of the Swift callback that Rust will invoke when it completes the task
    //   - unsafe pointer to the Context object, going in
    //
    private typealias CRustySwiftRequestFunction = @convention(c) (
        UnsafePointer<Int8>?,
        CRustySwiftResponseCallback?,
        UnsafeMutableRawPointer?
    ) -> Void

    // The Swift-ified representation of the C function that the fetchWeather() Rust
    // function accepts as one of its parameters. This must match the definition of
    // ResponseCallbackWithContext in librustyswift.h
    //
    // - Parameters:
    //   - unsafe pointer to the encoded JSON response
    //   - unsafe pointer to the Context object, coming back out
    //
    private typealias CRustySwiftResponseCallback = @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

    // Invokes a given Rust function.
    //
    // - Parameters:
    //   - fn: The Rust function signature, as defined in `librustyswift.h`
    //   - json: A JSON-encoded request string
    //   - queue: An optional dispatch queue to operate on
    //   - completion: An optional closure that will fire upon completion
    //
    private static func invoke(
        rustFunction: CRustySwiftRequestFunction,
        with json: String,
        on queue: DispatchQueue = .global(qos: .background),
        completion: StringCallback?
    ) {

        // The variable below is the callback function that Rust will invoke after it
        // returns the weather. It is technically a native Swift closure that Swift will
        // convert to a C function behind the scenes. Your first instinct might be to just
        // call `completion` inside here, to alert the Swift caller that everything is
        // finished and to hand off the response for processing. But doing so would
        // throw an error:
        //
        // > "A C function pointer cannot be formed from a closure that captures context"
        //
        // It says local context is unusable in a C function that was created from a
        // closure. So this is where things get cool! To sidestep the issue, we can
        // instantiate a Context object (defined below) and give it `completion` to
        // hold on to. Then we'll grab a pointer to the Context object's address on the
        // stack and pass that to the Rust function (as the `context` argument). The
        // Rust function will perform its work as normal, and when it's done it will invoke
        // this callback function with two arguments:
        //
        // 1. the JSON-encoded response string
        // 2. The same `context` pointer that we passed in
        //
        // The response string can be decoded to see the results of the operation, and
        // the `context` pointer can be unboxed to gain access to the `completion`
        // closure that we stored inside. Then it can be called normally. How cool is
        // that?
        //
        let callback: CRustySwiftResponseCallback = { (unsafeResponse: UnsafePointer<Int8>?, unsafeContextPtr: UnsafeMutableRawPointer?) in
            // make sure we're still on the same work queue...
            let queueLabel = String(cString: __dispatch_queue_get_label(nil))
            assert(queueLabel == "com.lobianco.RustySwift.workQueue")

            // `unsafeContextPtr` is the same Context pointer that we passed in initially.
            // it needs to be unboxed here before we can use it. it is important not to
            // dispatch to another thread until we consume the unsafe pointers, otherwise
            // they will go out of scope and we will end up with mangled data.
            //
            guard let context = Context.retainedObject(from: unsafeContextPtr), let callback = context.callback else {
                // no context and/or no callback to invoke
                return
            }

            var result: String? = nil

            if let unsafeResponse = unsafeResponse {
                result = String(cString: unsafeResponse)
            }

            // now dispatch back to the main thread for downstream classes
            DispatchQueue.main.async {
                callback(result)
            }
        }

        // The context object that will be shuttled across the FFI boundary and back
        // again. It is used to access `completion` within the callback function above.
        //
        let context = Context(with: completion)

        // Do the work in the background
        queue.async {
            rustFunction(
                json.unsafePointer(),
                callback,
                context.retainedPointer()
            )
        }

        print("Waiting on Rust function to complete...")
    }

}

// MARK: Context

// The Context class serves as a "box" to package up arbitrary data that we want
// to be able to access within the callback function that Rust invokes after doing
// its work. In this case, it's being used to package up a completion closure that
// we can fire to alert the Swift caller that the work has been completed.
//
private class Context {

    let identifier: UUID = UUID()
    let callback: StringCallback?

    init(with callback: StringCallback?) {
        self.callback = callback
    }

}

private extension Context {

    // Convenience functions to "box" and "unbox" a Context object. It is important
    // to note that we are deliberately dealing with unbalanced retains. In order to
    // ensure that the Context object stays alive long enough to be unboxed at some
    // arbitrary point in the future, we need to use `passRetained()` which will
    // increment its reference count by +1. Later on when we unbox it, we will call
    // `takeRetainedValue()` which will consume the unbalanced retain and allow it
    // to be properly deallocated.
    //

    func retainedPointer() -> UnsafeMutableRawPointer {
        print("  > Retaining context with id \(identifier.uuidString)")
        return Unmanaged.passRetained(self).toOpaque()
    }

    static func retainedObject(from pointer: UnsafeMutableRawPointer?) -> Context? {
        guard let pointer = pointer else {
            return nil
        }

        let context = Unmanaged<Context>.fromOpaque(pointer).takeRetainedValue()
        print("  > Releasing context with id \(context.identifier.uuidString)")

        return context
    }

}

// MARK: String Helpers

private extension String {

    // We need to convert Swift strings to C strings for Rust to make use of them
    func unsafePointer() -> UnsafePointer<Int8>? {
        return (self as NSString).utf8String
    }

}
