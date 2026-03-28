# raven-ui-cli

CLI for building and developing [Raven](https://github.com/raven-ui/raven) UI framework applications.

## Install

```bash
npm install -g raven-ui-cli
```

## Prerequisites

- **Swift** 5.9+ (swift.org or Xcode)
- **Rust** (rustup.rs)
- **Vulkan SDK** (lunarg.com/vulkan-sdk)
- **SDL3** (vendored or system-installed)

Run `raven doctor` to verify your toolchain.

## Usage

```bash
# Create a new project
raven init my-app

# Build
cd my-app
raven build

# Build and run
raven run

# Dev mode (watch for changes, auto-rebuild)
raven dev

# Clean build artifacts
raven clean

# Release build
raven build --release
raven run --release
```

## Commands

| Command | Description |
|---------|-------------|
| `raven init <name>` | Create a new Raven project |
| `raven build` | Build Rust + Swift |
| `raven run` | Build and run the app |
| `raven dev` | Watch mode with auto-rebuild |
| `raven clean` | Clean all build artifacts |
| `raven doctor` | Check prerequisites |
| `raven version` | Print version info |

## Options

- `--release` — Build in release mode
- `--target=<name>` — Specify executable target (default: RavenDemo)
