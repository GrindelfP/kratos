# Add a QEMU shutdown command

**Status:** planned

## Description

Add a `shutdown` shell command that terminates the QEMU process cleanly from
inside KratOS. This is distinct from sending Ctrl+C: Ctrl+C is a host-side
terminal signal, and a guest kernel cannot send that signal to its host QEMU
process. Use an explicit QEMU integration, such as the `isa-debug-exit` device
on a dedicated I/O port, enabled by the documented QEMU launch and test scripts.

Keep `halt` as the architecture-level operation that disables interrupts and
halts the guest CPU. Document that `halt` leaves the QEMU process/window running
and explain how to close it until `shutdown` is available. Do not describe a
QEMU-specific exit device as a portable hardware poweroff mechanism.

## Acceptance criteria

- `help` lists `shutdown`; parsing it returns a distinct action and has host-side
  command tests.
- The normal QEMU launch configures the shutdown device and the kernel writes the
  documented exit value to its port; QEMU exits after the command without a
  host-terminal Ctrl+C.
- The QEMU shutdown path emits a final serial diagnostic before exiting, and the
  QEMU regression test verifies process termination and the expected status.
- The serial shell and `halt` behavior remain distinct and tested. Missing QEMU
  device support is documented as a limitation; this is not claimed as generic
  ACPI or physical-machine poweroff.
- README and QEMU instructions explain the difference between guest `halt`, the
  planned/implemented `shutdown`, and host-side Ctrl+C.

## Rationale and dependencies

Users expect a simple way to close the demo from the shell. Directly sending
Ctrl+C to QEMU is not possible from guest code; the emulator must expose a
deliberate guest-to-host exit interface. Builds on the QEMU shell and command
loop from tickets 0007–0014.

## Implementation notes

To be completed. Preferred QEMU implementation: configure `isa-debug-exit` at
I/O base `0xf4` and have the guest issue a 32-bit write on `shutdown`. Keep the
port and exit code in one documented boundary so the behavior is easy to test.
