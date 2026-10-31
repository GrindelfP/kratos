# Validate the x86 freestanding Zig toolchain

**Status:** done

## Description

Evaluate and document a specific Zig release/toolchain for building a minimal freestanding x86 kernel artifact. Determine the target, linker and debugger workflow, runtime/library constraints, and whether Zig is viable as the proposed primary kernel language. Record an alternative or unresolved blocker if validation fails.

## Rationale and dependencies

Zig is the proposed direction, not yet a validated commitment. Early validation reduces risk before kernel code depends on a toolchain. Coordinate with the boot-path investigation in ticket [0002](0002-select-x86-boot-path.md); the artifact need not boot to complete this investigation.

## Acceptance criteria

- A specific Zig version and host setup are recorded.
- A minimal freestanding x86 artifact builds reproducibly with documented commands.
- Linker output, runtime assumptions, and available debugging path are described.
- A recommendation to proceed, adjust, or revisit the language choice is recorded with evidence and limitations.

## Implementation status

Zig 0.17.0 on Apple Silicon macOS reproducibly built a freestanding x86_64
ReleaseSmall ELF. ELF type, entry point, load segments, and absence of dynamic
loader/dependency were inspected; an unstripped companion exposed `_start` and
no unresolved symbols. The project's Limine/QEMU kernel boot has also been
verified. Debug-mode output and remote-debugger operation have documented
limitations in [`zig-x86-toolchain-validation.md`](../research/zig-x86-toolchain-validation.md).
