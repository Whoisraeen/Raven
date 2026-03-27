.PHONY: build build-rust build-swift run clean

build: build-rust build-swift

build-rust:
	cd rust/raven-core && cargo build --release

build-swift:
	swift build

run: build
	swift run RavenDemo

clean:
	cd rust/raven-core && cargo clean
	swift package clean
