# Select and document the x86 boot path

**Status:** done

## Description

Compare reasonable bootloader/protocol options for the initial x86 QEMU prototype and select a practical path. Document the handoff information the kernel needs, image format, and how the selected option works with the toolchain validation.

## Rationale and dependencies

A boot path is required to make the first prototype runnable, but no bootloader has been agreed. Ticket [0001](0001-validate-x86-zig-toolchain.md) provides toolchain constraints; the choice should be compatible with its findings.

## Acceptance criteria

- Candidate options and decision factors are briefly documented.
- A bootloader/protocol is selected for the prototype, with rationale and known tradeoffs.
- The expected kernel handoff and image/run workflow are documented.
- The choice is scoped to the first prototype and does not imply a permanent or multi-architecture commitment.
