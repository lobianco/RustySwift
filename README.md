# RustySwift

RustySwift is a unique approach to efficient, _asynchronous_ bidirectional communication between Rust and Swift. 

**The Goal**: To implement a function in Rust that can be cross-compiled into a static library for iOS and macOS (along with many other targets, but those are not our focus) and invoked asynchronously using native Swift closures.

**The Challenge**: Rust is ignorant of the concept of Swift closures. How can it notify Swift when the work is done? What do?

**The Solution**: Take a look at the comments in [`rust/ffi/src/lib.rs`](rust/ffi/src/lib.rs) and [`swift/RustySwift/RustySwift.swift`](swift/RustySwift/RustySwift.swift) to see how it works.  

## Usage

The Swift project contains a working demonstration of the Rust integration. Open the Xcode project found in `swift` and run it on an iOS simulator to see it in action. You'll also find helpful documentation describing each piece of the puzzle in excruciating detail.

## Building the Rust Library

_Requirements: [`cargo`](https://doc.rust-lang.org/cargo/getting-started/installation.html) and a macOS host. Optional: [`cargo-lipo`](https://github.com/TimNN/cargo-lipo)._

The Rust binary is prebuilt and checked into the repo already. But if you want to build it manually, first add the necessary targets via `rustup`:

```bash
rustup target add x86_64-apple-ios aarch64-apple-ios
```

Then `cd` into `rust` and run:

```bash 
# to build for the iOS simulator
cargo build -p ffi --release --target=x86_64-apple-ios

# to build for an iOS device
cargo build -p ffi --release --target=aarch64-apple-ios

# optionally, build a universal ("fat") binary with `cargo-lipo` instead
cargo lipo -p ffi --release
```

This will generate a static library in `target/${TARGET}/release` (or `target/universal/release` for the `cargo-lipo` command) that can be imported into the Swift project. 
