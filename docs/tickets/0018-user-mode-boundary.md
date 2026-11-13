# Establish the x86_64 user-mode boundary

**Status:** done — bounded QEMU x86_64 test context

## Description

Create the minimum QEMU x86_64 privilege and memory boundary for one user-mode
execution context. Preserve a controlled path back to the kernel shell rather
than introducing a scheduler or a general process model.

## Acceptance criteria

- Document the privilege-transition mechanism, descriptor and kernel-stack
  setup, address-space layout, and the ownership and lifetime of mappings.
- Map only the required user code, data, and stack with appropriate user and
  write permissions; kernel memory must not be accessible from user mode.
  Validate ranges and arithmetic before creating mappings, and define cleanup
  and failure behavior within the existing allocator's limitations.
- Demonstrate in QEMU that a bounded test context actually runs at ring 3. A
  user attempt to access kernel memory or execute an invalid instruction must
  produce an identifiable fault and return control to the recovery shell.
  Kernel-origin faults must not be misclassified as user faults.
- Add host tests for hardware-independent mapping and range validation where
  practical, and document QEMU commands, expected output, and limitations.
- Existing kernel shell and serial recovery behavior remain usable. No general
  scheduler, multiprocess support, or security guarantee is implied.

## Rationale and dependencies

This is the foundation for a separately built user program. It builds on the
memory-map allocator and exception handling from tickets 0005 and 0006. A small
embedded test context may exercise the boundary; a general loader is not needed.

## Implementation and verification

The fixed embedded context, mapping ownership, failure policy, transition, and
limitations are documented in [qemu-boot.md](../qemu-boot.md#bounded-ring-3-self-test).
Run `zig test kratos/kernel/user_ranges.zig` and, after building the ISO,
`python3 kratos/test-user-boundary.py /path/to/kratos.iso`. The QEMU test checks
actual user faults, shell recovery, and a kernel-origin NMI. This is not a
general loader, scheduler, or security guarantee.
