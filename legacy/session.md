# Session handoff

## Goal and result

Tickets 0007–0009 delivered the first interactive KratOS experience: a bounded
COM1 console and kernel shell booting in x86_64 QEMU. The shell supports `help`,
`about`, `echo`, `mem`, `clear`, and `halt`; line input supports backspace and
CR/LF/CRLF. This is still a kernel monitor, not a userland/POSIX OS.

## Decisions and verification

- Zig 0.17.0 remains the kernel language; Limine 12.9.6 boots the BIOS QEMU
  profile. QEMU input/output uses the serial console; there is no keyboard driver.
- `zig test kratos/kernel/memory_map.zig` — 3 passed.
- `zig test kratos/kernel/console.zig` — 3 passed.
- `zig test kratos/kernel/shell_commands.zig` — 4 passed.
- Zig formatting, `sh -n kratos/build-qemu.sh`, and `git diff --check` passed.
- Built the ISO and exercised all shell commands, unknown-command recovery,
  multiple commands, empty input, backspace, CRLF, and halt in QEMU. A QEMU NMI
  also produced the expected fatal exception diagnostic.

## Run

From the repository root, with Zig, Clang, xorriso, QEMU and Limine 12.9.6
available:

```sh
LIMINE_DIR=/path/to/limine-binary ./kratos/build-qemu.sh
```

See [`qemu-boot.md`](qemu-boot.md) for dependency setup and an example session.
The previously used Limine directory was under the temporary OpenCode workspace
and may no longer exist.

## Remaining work and next step

No user-mode programs, process/syscall layer, filesystem, keyboard, UEFI boot, or
physical hardware support is implemented. Next, define the smallest user-mode
program and syscall milestone, then add a filesystem/userland path; keep the
serial kernel shell as the recovery/debug console.
