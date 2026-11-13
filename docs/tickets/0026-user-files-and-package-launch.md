# Read files from user mode and launch a packaged program

**Status:** planned

## Description

Extend the bounded native syscall ABI with file reads and launch the existing
program from `system:packages/hello/program` after kernel image validation.

## Acceptance criteria

- Specify small open/read/close or equivalent handle operations. Validate all
  user pointers, sizes, offsets, handle ownership, and copy limits before
  touching kernel memory. Define EOF, closed/stale handle, wrong-kind, and
  resource-exhaustion results.
- Make the first separately built program read
  `system:packages/hello/message` through the new interface and report its
  contents over the existing output syscall. Keep the test independent of a
  writable filesystem or process scheduler.
- Make `hello` resolve its KRU1 payload from `system:packages/hello/program` instead of
  relying on the compiled-in payload. Reuse existing KRU1 validation and keep
  failure and exit diagnostics observable. Repeated launch and shell recovery
  must still work.
- Test invalid pointers, oversized reads, nonexistent paths, malformed program
  payloads, and repeated handle use in host tests and QEMU fixtures. Document
  the temporary single-program limits and make no POSIX compatibility claim.

## Rationale and dependencies

Depends on [0024](0024-kernel-readonly-files.md); shell browsing [0025](0025-shell-space-browsing.md)
may proceed independently after the mount exists. This is the read-only
filesystem slice of the [milestone](../roadmap.md#next-milestone-native-space-based-filesystem).
