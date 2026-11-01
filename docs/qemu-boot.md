# Limine/QEMU kernel prototype

This is a reproducibility scaffold for **Zig 0.17.0** and the selected
**Limine x86-64** boot protocol. The Zig kernel uses inline assembly only for
the x86 port I/O instructions and `hlt`.

## Prerequisites

Provide Zig **0.17.0**, Clang, `xorriso`, `qemu-system-x86_64`, and the official
Limine **v12.9.6** release files `limine`, `limine-bios.sys`,
`limine-bios-cd.bin`, and `limine-uefi-cd.bin`. The Limine release asset and
signature are available from the [v12.9.6 release page](https://github.com/Limine-Bootloader/Limine/releases/tag/v12.9.6);
verify the signature with the release key fingerprint
`05D29860D0A0668AAEFB9D691F3C021BECA23821` before extracting. Build its host
tool with `make -C /path/to/limine-binary`. Set `LIMINE_DIR` to that directory.
The build script rejects a Limine tool whose reported version is not 12.9.6.
Use `ZIG`, `CLANG`, `XORRISO`, or `QEMU` to select non-default executable paths;
`OUT_DIR` selects build output (default `build/` at the repository root).

From the repository root:

```sh
ZIG=/path/to/zig-0.17.0/bin/zig LIMINE_DIR=/path/to/limine \
  ./kratos/build-qemu.sh
```

The script compiles a freestanding x86-64 ELF, stages the Limine files, creates
an ISO with xorriso, installs Limine's BIOS stage, then runs QEMU's BIOS path
(`q35`, 256 MiB) with serial redirected to the terminal. The
expected initial UART output is:

```text
KratOS: Limine x86_64 kernel entered
KratOS: memory map entries=0000000000000010 first usable frame=0x000000000007e000
kratos>
```

`./kratos/build-qemu.sh --build-only` stops after ISO creation. The kernel
prints through COM1 (0x3f8), validates the Limine memory map, allocates one
usable physical page frame, installs an IDT for CPU exceptions, then enters a
bounded serial shell. Type commands in the QEMU terminal and press Enter.
Built-ins are `help`, `about`, `echo <text>`, `mem`, `clear`, and `halt`;
unknown commands report an error and return to the prompt. Input is limited to
128 bytes. Backspace edits a valid line; exceeding the limit rings the bell and
discards the entire line through its terminator. UART overrun, parity, framing,
or break errors likewise ring the bell, discard the damaged line, and print
`Input error: line discarded` before returning to a clean prompt. CR, LF, and
CRLF line endings are accepted.

`echo` removes matching single- or double-quote delimiters and preserves the
other argument bytes, including spaces inside quotes. Empty quoted arguments
produce an empty line; adjacent quoted/unquoted portions concatenate. Backslash
escaping is not supported. An unmatched quote prints `echo: unmatched quote`
without printing a partial argument and the shell remains usable.

Example interaction (memory values depend on the Limine map):

```text
kratos> help
help about echo mem clear halt
kratos> about
KratOS: a small hobby operating system
kratos> echo hello KratOS
hello KratOS
kratos> echo 'hello from KratOS'
hello from KratOS
kratos> mem
Memory map entries: <entry count>, usable bytes: <usable byte total>, first usable frame: <frame address>
kratos> halt
KratOS halted
```

`halt` disables interrupts and halts the CPU.

### Serial shell regression test

After building a BIOS ISO with `./kratos/build-qemu.sh --build-only`, run
`./kratos/test-serial-shell.sh [path/to/kratos.iso]`. This repeatably boots the
documented `q35`/256 MiB QEMU configuration and rapidly pastes a 115-byte echo
command followed by `help` and `about`, tests CRLF, exactly-full and overflowing
lines, quoted echo, backspace, unknown-command recovery, and halt. The script
requires `expect` in addition to the QEMU prerequisites and fails on missing
output, corruption, or a damaged prompt. Unit tests can be run without booting
QEMU with:

```sh
zig test kratos/kernel/console.zig
zig test kratos/kernel/shell_commands.zig
```

The same QEMU image can test fatal exception reporting: connect to the QEMU
monitor and issue `nmi`; the diagnostic includes vector 2, error code 0, and the
interrupted instruction address.
The kernel does not yet provide a general allocator, virtual-memory manager,
device drivers, or hardware support beyond this QEMU profile.

## Validation status

Verified on Apple Silicon macOS with Zig 0.17.0, Clang, xorriso 1.5.8.pl02,
Limine 12.9.6, and QEMU 11.1.2. The build-only command produced the ISO; QEMU
BIOS interaction verified the prompt, all documented built-ins, unknown-command
recovery, multiple commands, empty input, backspace, CRLF, and halt. A separate
QEMU monitor `nmi` command reached the exception handler, which printed vector 2,
error code 0, and RIP before halting. The ISO tool reports an
EFI-directory warning; only the BIOS QEMU path is tested, and no physical
hardware or UEFI boot is claimed. This proves the prototype path, not general
hardware support.
