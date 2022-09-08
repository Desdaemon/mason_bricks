# flutter_rust_bridge

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

Quickly scaffold a Rust crate within a Flutter project using [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge).

## Getting Started

After installing the brick, initialize it from the _root of your Flutter project_,
then generate the project with `mason make flutter_rust_bridge`.

The installation process is semi-automatic right now, so be sure to
check out [our documentation](http://cjycode.com/flutter_rust_bridge/integrate.html)
on how to hook the crates' build process to `flutter run`.

## Notes

- If you use [just](https://github.com/casey/just), consider letting this brick manage
  justfile automatically; it will append new crates on repeated invocations.
  If justfile already exists, this brick will not generate one.

## Outputs

```bash
# mason make flutter_rust_bridge --name native --bridge bridge_generated
justfile
lib
└── src
    ├── native.dart
    └── native
        ├── native.dart
        └── native.web.dart
linux # if linux support is present
└── rust.cmake
windows # if Windows support is present
└── rust.cmake
native
├── build.rs
├── native.xcodeproj # post-init hook, requires Cargo
├── Cargo.toml
└── src
    ├── lib.rs
    └── api.rs
```

```makefile
# file: justfile
# @mason: flutter_rust_bridge

default: check lint
lint: lint_native ..
    dart fmt .
clean: clean_native ..
    flutter clean
check: check_native ..
    flutter analyze

# Crates section
lint_native:
    cd native && cargo fmt
clean_native:
    cd native && cargo clean
check_native:
    cd native && cargo check

..
```
