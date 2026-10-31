# Initial x86_64 QEMU boot path

**Decision (prototype only):** use Limine's x86-64 boot protocol, with the Limine
bootloader to load an ELF kernel from a bootable ISO9660 image. This is a
practical starting point, not a commitment to Limine for later releases or to
any architecture beyond this prototype.

## Candidates and decision

- **Limine protocol + Limine bootloader (selected).** Its official protocol
  specifies x86-64 ELF support (ELF is recommended), the 64-bit entry state,
  and request/response features for data such as a memory map, framebuffer,
  and HHDM. Limine supports x86-64 and ISO9660. This keeps the first kernel
  focused on kernel initialization rather than implementing firmware and
  mode-transition code. Tradeoffs: external bootloader and image tooling are
  dependencies; the kernel must consume Limine's ABI and should pin/document
  compatible bootloader/protocol versions.
- **GRUB + Multiboot2.** Multiboot2 has a published boot contract and widely
  supported loaders, and provides tagged boot information including a memory
  map. Its standard x86 handoff is i386 protected mode, not a ready x86-64
  long-mode handoff; transitioning to 64-bit mode would add early assembly and
  setup work. The specification's original target is 32-bit systems.
- **A native UEFI application/kernel.** This avoids a separate protocol
  bootloader, but makes the kernel responsible for a UEFI entry point and
  firmware boot-services/memory-map lifecycle (including `ExitBootServices`).
  That is extra coupling and work for the first QEMU proof.

Limine is preferred because it gives the proposed x86_64 kernel a documented
64-bit entry ABI and requestable handoff data, while supporting both BIOS and
UEFI boot media. This is a project choice, not a claim that it is the only
valid loader or the eventual permanent interface.

## Kernel handoff contract

Build an ELF executable with an entry point and the System V x86-64 ABI expected
by Limine (without FP/SIMD at the protocol boundary). At entry, execution is in
64-bit mode with paging enabled and interrupts disabled; Limine supplies a
stack, but the kernel must install its own IDT and must not return. General
purpose registers are zeroed, so pass required boot information through
explicit Limine requests, not undocumented register values. Request only what
the first kernel needs; in particular, request and validate the Limine memory
map before using memory. Responses live in bootloader-reclaimable memory and
must not be treated as permanent after reclaiming it. The full register,
mapping, and feature contract is defined in the protocol specification.

## Image and run workflow

The intended artifact is a bootable ISO9660 image containing the kernel ELF,
`limine.conf`, and the Limine boot files. The Limine project documents the
hybrid BIOS/UEFI ISO layout and `xorriso` command; for the first QEMU run use
the BIOS boot path to avoid adding an OVMF firmware dependency. The conceptual
loop is: build kernel ELF → stage kernel/config/bootloader files → create ISO
and install the Limine BIOS stage → run `qemu-system-x86_64` with that ISO as
CD-ROM and boot from CD (QEMU documents `-cdrom` and `-boot order=d`). Add the
serial/display options appropriate to the observable-kernel ticket. The
prototype pins Limine release binaries/tool to **v12.9.6**. Exact build,
staging, run commands, and the release verification procedure are documented in
[`qemu-boot.md`](qemu-boot.md). This pin is for the prototype only and should be
re-evaluated before a later release.

## Integration boundary with ticket 0001

Ticket 0001 validates the proposed Zig toolchain. The QEMU prototype confirms
that the chosen Zig release emits an ELF that the pinned Limine boot path can
load; it does not make Limine a permanent project-wide or multi-architecture
commitment.

## Primary sources

- Limine protocol specification (ELF recommendation, x86-64 ABI, entry state,
  features and memory map):
  <https://github.com/Limine-Bootloader/limine-protocol/blob/trunk/PROTOCOL.md>
- Limine official project README (architectures, protocols, filesystems and
  binary releases): <https://github.com/Limine-Bootloader/limine/blob/trunk/README.md>
- Limine official usage guide (hybrid ISO layout and image creation):
  <https://github.com/Limine-Bootloader/limine/blob/trunk/USAGE.md>
- GNU GRUB Multiboot2 specification (image, i386 handoff, boot information and
  scope): <https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html>
- UEFI Specification 2.10, Boot Services (memory map and `ExitBootServices`):
  <https://uefi.org/specifications/UEFI/2.10/07_Services_Boot_Services.html>
- QEMU system invocation reference (`-cdrom`, boot order):
  <https://www.qemu.org/docs/master/system/invocation.html>
