# Boot an observable kernel in QEMU

**Status:** ready

## Description

Build the smallest x86 kernel image using the validated toolchain and selected boot path, then start it in QEMU and emit a recognizable boot result through a documented output channel.

## Rationale and dependencies

This is the first end-to-end proof that the project can boot its own kernel. Depends on decisions/findings in tickets [0001](0001-validate-x86-zig-toolchain.md) and [0002](0002-select-x86-boot-path.md).

## Acceptance criteria

- A documented command builds the image and launches the chosen QEMU configuration.
- The kernel reaches its entry point and emits a recognizable result.
- Build, boot, and expected output are documented so the result is reproducible.
- Toolchain, emulator, and boot-path limitations are recorded; no physical hardware support is implied.
