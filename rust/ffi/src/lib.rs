#![deny(warnings)]
#![forbid(unused_must_use)]

/// This crate (`ffi`) is the "bridge" that facilitates communication between Swift and Rust. It
/// handles the conversion between C and Rust types, along with JSON serialization and
/// deserialization.
///
use std::ffi::{CStr, CString};
use tokio::runtime::Runtime;
use weather::{WeatherRequest, WeatherResponse};

/// This is the Rust-ified representation of the C function that fetch_weather() accepts as one of
/// its input parameters. It is a C function signature expressed in Rust notation. fetch_weather()
/// will invoke it at the end of its operations.
///
/// # Parameters
///
/// * `result` - The JSON-encoded result
/// * `context` - The context pointer passed in to fetch_weather(), returned untouched
///
pub type ResponseCallbackWithContext =
    unsafe extern "C" fn(result: *const std::os::raw::c_char, context: *mut libc::c_void);

/// Fetches the weather for a given city by zip code. #[no_mangle] is necessary, otherwise
/// Rust will scramble the function signature during compilation. The result will be
/// returned to the caller as the first argument of `callback`, and `context` will be
/// returned (unaltered) as the second argument of `callback`.
///
/// # Parameters
///
/// * `request_json` - The JSON-encoded request
/// * `callback` - A C function that will be invoked after the weather is returned
/// * `context` - A pointer that the caller can use to shuttle data across the FFI boundary
///
#[no_mangle]
pub extern "C" fn fetch_weather(
    request_json: *const std::os::raw::c_char,
    callback: ResponseCallbackWithContext,
    context: *mut libc::c_void,
) {
    // create a Rust string from the input C string
    let request_json: &CStr = unsafe { CStr::from_ptr(request_json) };
    let request_json: &str = match request_json.to_str() {
        Ok(value) => value,
        Err(_) => "", // oops
    };

    // deserialize the JSON into a request object
    let request: Result<WeatherRequest, _> = serde_json::from_str(request_json);
    let request: WeatherRequest = match request {
        Ok(value) => value,
        Err(_) => WeatherRequest::default(),
    };

    // fetch the weather
    let rt: Runtime = Runtime::new().expect("could not create runtime");
    let response: Result<WeatherResponse, _> = rt.block_on(weather::fetch_weather(request));
    let response: WeatherResponse = match response {
        Ok(value) => value,
        Err(_) => WeatherResponse::default(),
    };

    // serialize the JSON into a response object
    let response_json: String = match serde_json::to_string(&response) {
        Ok(value) => value,
        Err(_) => String::from(""),
    };

    // then turn it into a C string. this will require manual deallocation later
    let response_json: *mut i8 = CString::new(response_json).unwrap().into_raw();

    unsafe {
        // invoke the C function "callback" with the response JSON and the context pointer that was
        // passed in originally
        //
        callback(response_json, context);

        if response_json.is_null() == false {
            // now that we have passed ownership of the C string to the Swift caller, Rust will
            // retake ownership to free the memory.
            //
            CString::from_raw(response_json);
        }
    }
}
