#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// This header serves as a blueprint for the Rust binary `librustyswift.a`. It
// re-defines the public functions and types in `librustyswift.a` in C notation
// and makes them callable from Swift. It is important that these definitions
// match their Rust counterparts in the `ffi` crate.
//

// types
typedef void (ResponseCallbackWithContext)(const char *response_json, void *context);

// weather
extern void fetch_weather(const char* request_json, ResponseCallbackWithContext callback, void *context);

#ifdef __cplusplus
}
#endif
