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
(`q35`, 256 MiB) with its graphical display enabled and serial redirected to
the terminal. Set `QEMU_DISPLAY=none` for a headless run. Limine selects the
video mode; the kernel does not prescribe a single resolution. The
expected initial UART output is:

```text
KratOS: Limine x86_64 kernel entered
KratOS: memory map entries=0000000000000010 first usable frame=0x000000000007e000
kratos>
```

`./kratos/build-qemu.sh --build-only` stops after ISO creation. The kernel
prints through COM1 (0x3f8), validates the Limine memory map, allocates one
usable physical page frame, installs an IDT for CPU exceptions, then enters a
bounded shell. Click the graphical QEMU window and type commands there; release
QEMU keyboard capture using its displayed host-key shortcut. Alternatively type
into the serial terminal for recovery and automation.
Built-ins are `help`, `about`, `echo <text>`, `mem`, `clear`, `kratos`, `halt`,
and `shutdown`;
unknown commands report an error and return to the prompt. Input is limited to
128 bytes. Backspace edits a valid line; exceeding the limit rings the bell and
discards the entire line through its terminator. UART overrun, parity, framing,
or break errors likewise ring the bell, discard the damaged line, and print
`Input error: line discarded` before returning to a clean prompt. CR, LF, and
CRLF line endings are accepted.

`halt` disables guest interrupts and halts the CPU; it does not close the QEMU
process. `shutdown` writes the 32-bit value `0x10` to the QEMU `isa-debug-exit`
device at I/O port `0xf4`; QEMU exits with status 33. The normal launcher adds
this device and does not use `-no-shutdown`. This does not send Ctrl+C to the
host process and is not a portable hardware poweroff mechanism. If running QEMU
without that device, close the host window or press Ctrl+C in the terminal that
launched it.

`echo` removes matching single- or double-quote delimiters and preserves the
other argument bytes, including spaces inside quotes. Empty quoted arguments
produce an empty line; adjacent quoted/unquoted portions concatenate. Backslash
escaping is not supported. An unmatched quote prints `echo: unmatched quote`
without printing a partial argument and the shell remains usable.

## Framebuffer console

The kernel requests Limine's framebuffer and accepts only a validated 32-bit
RGB surface with byte-aligned, non-overlapping 8-bit channels. The reusable
`kratos/kernel/raster.zig` surface checks dimensions, pitch, and backing extent
before drawing; its 12x12 cell bitmap font renders upper/lowercase letters, digits,
spaces, and common punctuation. The bounded console clips pixels, wraps,
scrolls, clears, and handles CR/LF/backspace. `presentation.zig` renders a
centered multiline ASCII-art KratOS logo and welcome screen with a deep-red background,
Spartan-red logo/prompt, and warm-white output. Unsupported or absent framebuffer
data emits a serial diagnostic and leaves the serial shell operational. Shell
prompt, input echo, and command output are mirrored to the framebuffer when
available and to serial. The polled i8042 keyboard path decodes translated
PS/2 set-1 make/break codes with independent left/right Shift, US letters and
punctuation, Enter and Backspace. Extended keys, Caps Lock, other modifiers,
and non-US layouts are not implemented. Each poll consumes at most one keyboard
byte and alternates source priority; absent keyboard input does not block COM1.
`clear` clears the framebuffer directly and uses a plain text serial notice (no
ANSI sequences are sent to the framebuffer).

Host validation, from the repository root:

```sh
zig test kratos/kernel/raster.zig
zig test kratos/kernel/console.zig
```

### Branded screen visual checklist

Run `./kratos/build-qemu.sh` and inspect the framebuffer at the default mode:

- Confirm the welcome heading, legible `KratOS` logo, warm-white tagline, and
  red-on-dark palette appear before the shell prompt.
- Confirm `help`, `about`, `echo hello`, `mem`, unknown-command warning, and
  `clear` update framebuffer output; typed input is visible in both outputs.
- At 320x200, confirm the compact footer, prompt, and ASCII-art logo remain
  legible and do not overlap.
- Try a very long `echo` response and multiple lines; confirm wrapping/scrolling
  stays within the framebuffer and no ANSI escape glyphs appear.
- For fallback, boot without a framebuffer response (or with unsupported format)
  and verify the serial diagnostic, prompt, commands, and `clear` notice remain
  available.

BIOS QEMU verification passed at 1280x800 using Limine 12.9.6 built from the
provided source archive. A monitor screenshot confirmed the welcome message,
Spartan-red logo, readable text, and shell prompt. The serial shell regression
passed for pasted echo, quoted echo, full/overflow lines, recovery, and halt.
The same visual acceptance passed at 320x200; the welcome footer uses a compact
layout at narrow widths. A 320x200 QEMU screenshot confirmed the prompt and
wordmark remain visible.

### Foreground KratOS animation

Run `kratos` to start the bounded kernel-mode framebuffer demonstration. Its
multi-line figure moves within the drawable grid and changes direction at an
edge. Press `q` or `Q` at any point to return to the branded shell; verify the
prompt and theme return, then run `help` and `about` before `halt`. No key other
than the exit key is treated as a shell command while the application is active.
The app uses PIT channel 2's ~1.193182 MHz base clock with a 23,864-count
one-shot (~20 ms) for frame pacing, polling keyboard and COM1 during that interval. Runtime
direction state is seeded from `RDTSC`; this is a varied local seed, not secure
entropy. The channel-2/speaker gate state is restored when the app exits.

BIOS QEMU verification at both 1280x800 and 320x200 confirmed the figure is
visible and bounded, `q` returns to the restored branded shell, and `help` then
`halt` still work. A separate `-vga none` run confirmed the no-framebuffer
diagnostic, `kratos` fallback, shell recovery, and halt.

Example interaction (memory values depend on the Limine map):

```text
kratos> help
help about echo mem clear kratos halt shutdown
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

`halt` disables interrupts and halts the CPU, leaving QEMU itself running. Use
`shutdown` in the documented QEMU configuration to exit QEMU.

### Keyboard shell regression test

After building the ISO, run `python3 kratos/test-keyboard-shell.py [path/to/kratos.iso]`.
The script uses monitor `sendkey` to generate keyboard events, never injects
serial input, checks serial output as an independent observation, and retains
welcome, shell, and app screenshots in a printed temporary directory. It tests
Backspace, Shift and quoted echo, app exit, shell recovery, and `shutdown`'s
QEMU process exit/status.

On 2026-11-01, the monitor-key test passed on QEMU 11.1.2 at 1280x800
and at 320x200 (a separate ISO with Limine `resolution: 320x200x32`).
Screenshots at both sizes were inspected for the logo and shell input; serial
output confirmed `help`, `echo "Hello !"`, `kratos`, keyboard `q`, `help`, and
`shutdown` (QEMU status 33). This tests emulated keyboard delivery, not physical
keyboard layouts.

### Serial shell regression test

After building a BIOS ISO with `./kratos/build-qemu.sh --build-only`, run
`./kratos/test-serial-shell.sh [path/to/kratos.iso]`. This repeatably boots the
documented `q35`/256 MiB QEMU configuration and rapidly pastes a 115-byte echo
command followed by `help` and `about`, tests CRLF, exactly-full and overflowing
lines, quoted echo, backspace, unknown-command recovery, and `halt`. It starts a
second VM to send `shutdown` over serial and verifies QEMU exits with status 33.
The script requires `expect` in addition to the QEMU prerequisites and fails on
missing output, corruption, or a damaged prompt. Unit tests can be run without
booting QEMU with:

```sh
zig test kratos/kernel/console.zig
zig test kratos/kernel/input.zig
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
recovery, multiple commands, empty input, backspace, CRLF, `halt`, and `shutdown`
from both keyboard and serial; shutdown terminated QEMU with status 33. A separate
QEMU monitor `nmi` command reached the exception handler, which printed vector 2,
error code 0, and RIP before halting. The ISO tool reports an
EFI-directory warning; only the BIOS QEMU path is tested, and no physical
hardware or UEFI boot is claimed. This proves the prototype path, not general
hardware support.
