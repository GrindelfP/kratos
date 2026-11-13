# Limine/QEMU kernel prototype

This is a reproducibility scaffold for **Zig 0.17.0** and the selected
**Limine x86-64** boot protocol, including a bounded ring-3 test context.

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
KratOS: user fault vector=0x0000000000000006 error=0x0000000000000000
KratOS: user fault vector=0x000000000000000e error=0x0000000000000005
KratOS: user fault vector=0x000000000000000e error=0x0000000000000007
KratOS: user fault vector=0x000000000000000e error=0x0000000000000015
KratOS: ring3 boundary self-test passed
kratos>
```

`./kratos/build-qemu.sh --build-only` stops after ISO creation. The kernel
prints through COM1 (0x3f8), validates the Limine memory map, allocates one
usable physical page frame, installs an IDT for CPU exceptions, then enters a
bounded shell. Click the graphical QEMU window and type commands there; release
QEMU keyboard capture using its displayed host-key shortcut. Alternatively type
into the serial terminal for recovery and automation.

## Bounded ring-3 self-test

At boot the kernel executes four short embedded snippets, one at a time, before
starting the shell. Each writes its actual CS selector (0x23) to user data.
They then cause respectively invalid opcode (#UD), a read of kernel memory,
a write to read-only user code, and instruction fetch from NX user data (#PF).
The page-fault error codes above identify user protection violations: 5 for a
read, 7 for a write, and 0x15 for instruction fetch. A failed or unavailable
test is reported on serial and the shell still starts if recovery was possible.

The kernel installs its own GDT with ring-0 and ring-3 code/data descriptors and
a TSS. Its RSP0 points to a dedicated 16 KiB kernel exception stack; the TSS
I/O bitmap is absent and user IOPL is zero. With interrupts disabled, `iretq`
enters ring 3. An exception gate switches to RSP0; the dispatcher checks both
the active-test flag and the saved CS privilege bits before recovering #UD or
#PF. Recovery restores the original CR3, CR4, and saved kernel ABI stack, then
returns to the caller. All kernel-origin exceptions and other user exceptions
remain fatal. The bounded syscall and separately built program paths are described
below; there is no general arbitrary-program fault handler.

Each run uses a fresh four-level root copied from the Limine root, with the
user bit cleared on every inherited root entry and entry zero replaced by a
private user page-table tree. Only 0x400000 (code: user/read/execute), 0x401000
(data: user/read/write/NX), and 0x402000 (stack: user/read/write/NX) are user
mapped; the stack initially points just above its page. Null and all other
low-half pages are absent. Higher-half kernel/HHDM mappings are supervisor-only.
NX support is required and enabled; LA57 and PCID are rejected. Global TLB
entries are flushed by temporarily disabling CR4.PGE across the switch.

Page tables and backing pages are page-aligned static kernel storage, reserved
for the kernel lifetime and reused only after returning to the original CR3;
they are zeroed before each run. No monotonic allocator frames are consumed,
so neither partial allocation nor freeing is needed. The code validates the
fixed virtual ranges, physical-address arithmetic and alignment before use;
missing Limine responses, unsupported paging/NX, or invalid setup skip the
test and leave the shell available. This design assumes the Limine QEMU boot
environment and one CPU, and only supports the trusted, bounded snippets; it
does not provide timeouts, preemption, SMP, a process model, or a security claim.

Reproduce with Zig 0.17.0 and the prerequisites above:

```sh
ZIG=/path/to/zig LIMINE_DIR=/path/to/limine ./kratos/build-qemu.sh --build-only
zig test kratos/kernel/user_ranges.zig
python3 kratos/test-user-boundary.py build/kratos.iso
./kratos/test-serial-shell.sh build/kratos.iso
```

The boundary test also sends `echo recovered-shell` and injects a kernel-mode
NMI via the QEMU monitor, expecting fatal vector 2 rather than user recovery.

## Shell commands

Built-ins are `help`, `about`, `echo <text>`, `mem`, `clear`, `kratos`, `halt`,
`shutdown`, and `hello`. Read-only system-space browsing is available through
`spaces`, `pwd`, `ls [path]`, `cd <path>`, and `cat <text-file>`. The browser
starts at `system:` (the image root); paths can be relative to the current
directory or absolute, and `.`/`..` are normalized according to the namespace
grammar. `ls` lists at most 16 entries, while `cat` prints at most the first 96
bytes of a text file. `spaces` lists only the mounted `system` space until
principal discovery and grants arrive in ticket 0029. Other spaces are not yet
available. These commands use the same lowercase ASCII path names as the
filesystem contract. Errors return to the shell without changing its current
directory.
unknown commands report an error and return to the prompt. Input is limited to
128 bytes. Backspace edits a valid line; exceeding the limit rings the bell and
discards the entire line through its terminator. UART overrun, parity, framing,
or break errors likewise ring the bell, discard the damaged line, and print
`Input error: line discarded` before returning to a clean prompt. CR, LF, and
CRLF line endings are accepted. Keyboard Tab completes a unique built-in first-token
prefix; ambiguous prefixes list matches. Up/Down browse the 16 most recent
non-blank submitted lines and Down past the newest restores the draft. Duplicate
submissions are retained; the oldest entry is overwritten when history fills.
Editing a recalled line does not change its stored entry. These keys are for the
PS/2 keyboard path; serial input remains the existing byte-oriented interface.
Framebuffer input uses a single-row horizontal viewport: the prompt stays visible
and the rightmost input characters are shown as a long line is edited or recalled.
The complete line remains available for submission, up to the 128-byte limit.

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
before drawing; its normal 24x28 cell font (5x5 source glyphs rendered at 4x4
pixels per source bit) renders upper/lowercase letters, digits, spaces, and
common punctuation. Compact layouts use 18x20 cells at 3x3 pixels per source
bit. The bounded console clips pixels, wraps, scrolls, clears, and handles
CR/LF/backspace. At 1280x800, the welcome, prompt, input echo, output, and
animation use a 50-pixel inset on all four edges. At 320x200, compact text uses
16-pixel horizontal and 12-pixel vertical insets so the interface remains
usable. Clear resets to the padded console origin rather than (0,0), and
scrolling is constrained to the padded viewport. `presentation.zig` renders a
centered multiline ASCII-art KratOS logo and welcome screen with a deep-red
background, Spartan-red logo/prompt, and warm-white output. Unsupported or
absent framebuffer data emits a serial diagnostic and leaves the serial shell
operational. Shell prompt, input echo, and command output are mirrored to the
framebuffer when available and to serial. The polled i8042 keyboard path decodes translated
PS/2 set-1 make/break codes with independent left/right Shift, US letters and
punctuation, Enter, Backspace, Tab and extended Up/Down. Other extended keys, Caps Lock, other modifiers,
and non-US layouts are not implemented. Each poll consumes at most one keyboard
byte and alternates source priority; absent keyboard input does not block COM1.
`clear` clears the framebuffer directly and uses a plain text serial notice (no
ANSI sequences are sent to the framebuffer).

Host validation, from the repository root:

```sh
zig test kratos/kernel/raster.zig
zig test kratos/kernel/presentation.zig
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
- At 1280x800, confirm all UI content stays within 50 pixels of each edge; at
  320x200 confirm the compact 16x12-pixel insets, prompt baseline, and bottom
  margin.
- Try a very long `echo` response and multiple lines; confirm wrapping/scrolling
  stays within the framebuffer and no ANSI escape glyphs appear.
- For fallback, boot without a framebuffer response (or with unsupported format)
  and verify the serial diagnostic, prompt, commands, and `clear` notice remain
  available.

Fresh BIOS QEMU captures verified at 1280x800 and 320x200. Normal 24x28 cells
and 50-pixel edge insets are used at 1280x800; the 320x200 compact mode uses
18x20 cells, 16-pixel horizontal insets, and 12-pixel vertical insets (literal
50-pixel padding would leave too few columns and rows for a usable shell). The
initial prompt remains inset at the bottom of the welcome, and `clear` returns
the prompt to the inset top-left origin. Fresh welcome and post-clear screenshots for both sizes are committed
in [`docs/screenshots`](screenshots/) and were inspected.

### Foreground KratOS animation

Run `kratos` to start the bounded kernel-mode framebuffer demonstration. Its
multi-line figure moves within the drawable grid and changes direction at an
edge. Press `q` or `Q` at any point to return to the branded shell; verify the
prompt and theme return, then run `help` and `about` before `halt`. No key other
than the exit key is treated as a shell command while the application is active.
The app uses PIT channel 2's ~1.193182 MHz base clock with a 23,864-count
one-shot (~20 ms) for frame pacing, polling keyboard and COM1 during that
interval. Runtime direction state is seeded from `RDTSC`; this is a varied
local seed, not secure
entropy. The channel-2/speaker gate state is restored when the app exits.

BIOS QEMU verification at both 1280x800 and 320x200 confirmed the figure is
visible and bounded within the padded drawable region, `q` returns to the
restored inset shell, and `help` then `halt` still work. A separate `-vga none`
run confirmed the no-framebuffer diagnostic, `kratos` fallback, shell recovery,
and halt.

Example interaction (memory values depend on the Limine map):

```text
kratos> help
help about echo mem clear kratos halt shutdown hello spaces ls pwd cd cat
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
Backspace, Shift and quoted echo, Tab completion, history and draft restoration,
recalled command execution, system-space navigation, failed lookup and shell
recovery, a full-capacity draft and short/long history redraw with framebuffer
screenshot comparisons, app exit, and `shutdown`'s
QEMU process exit/status.

On 2026-11-01, the monitor-key test passed on QEMU at 1280x800 and 320x200 (a
separate ISO with Limine `resolution: 320x200x32`). It covers Backspace, quoted
echo, clear, `kratos`, keyboard `q`, shell recovery, and `shutdown` (QEMU status
33). Screenshots at both sizes were inspected; this tests emulated keyboard
delivery, not physical keyboard layouts.

### Serial shell regression test

After building a BIOS ISO with `./kratos/build-qemu.sh --build-only`, run
`./kratos/test-serial-shell.sh [path/to/kratos.iso]`. This repeatably boots the
documented `q35`/256 MiB QEMU configuration and rapidly pastes a 115-byte echo
command followed by `help` and `about`, tests system-space listing/navigation,
text preview and a failed lookup, CRLF, exactly-full and overflowing lines,
quoted echo, backspace, unknown-command recovery, and `halt`. It starts a
second VM to send `shutdown` over serial and verifies QEMU exits with status 33.
The script requires `expect` in addition to the QEMU prerequisites and fails on
missing output, corruption, or a damaged prompt. Unit tests can be run without
booting QEMU with:

```sh
zig test kratos/kernel/console.zig
zig test kratos/kernel/input.zig
zig test kratos/kernel/shell_commands.zig
zig test kratos/kernel/shell_edit.zig
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

## Minimal ring-3 syscall ABI

This is a KratOS-specific experimental ABI for the fixed 0018 context, not
POSIX. A user invokes `int $0x80` (64-bit mode, DPL-3 interrupt gate); the CPU
switches to the existing TSS RSP0 kernel stack. Maskable interrupts remain off.
`RAX` holds the unsigned 64-bit call number, `RDI` and `RSI` hold unsigned
64-bit arguments, and `RAX` returns a 64-bit result. All other general-purpose
registers and the user flags are preserved on returning calls; floating-point,
SIMD and other extended state are not part of this ABI and may be clobbered.
The kernel clears DF while executing. The context is single-CPU and cannot run
concurrently with mapping changes.

| Number | Operation | Arguments | Return |
| --- | --- | --- | --- |
| 1 | output | `RDI` = user virtual address, `RSI` = byte count | byte count, or error |
| 2 | exit | `RDI` = 64-bit status, `RSI` ignored | does not return |

Errors are signed 64-bit values in `RAX`: -1 invalid or inaccessible range,
-2 count exceeds 1024, -3 unknown call number. Oversize is checked first.
A zero-length output succeeds with zero for any address and reads nothing.
For nonzero output the entire half-open range must lie in the fixed contiguous
readable user mappings `[0x400000, 0x403000)`; this rejects wrapping, kernel,
noncanonical and unmapped addresses before any byte is read. The limit is
1024 bytes inclusive; output is raw bytes through the kernel console. This
policy is coupled to the current immutable page tables and must be replaced by
actual mapping/permission validation before a general loader or mutable address
space is introduced. No protection against malicious output content is claimed.

Exit records the full status, deactivates the context and restores the saved
kernel address space and stack; static backing pages remain reserved and are
cleared before the next run. Boot's embedded position-independent ring-3 fixture
writes `KratOS: syscall output`, checks kernel-address, end-crossing and
wrapping pointer failures, zero length, oversize and unknown-call errors, and
exits with status 42. The kernel prints `ring3 syscall self-test passed exit=42`
only if those checks and the ring-3 CS check succeed. Run
`zig test kratos/kernel/user_syscalls.zig` and
`python3 kratos/test-user-boundary.py /path/to/kratos.iso`; the latter also
checks the 0018 fault cases, shell recovery and kernel-origin NMI handling.
This fixture is not a separately loaded program, scheduler or security guarantee.
## Separate user program

`hello` launches the KRU1 program from `system:/packages/hello/program` after
the complete system image and program have been validated. The program opens
`system:/packages/hello/message`, reads it through the file syscalls, prints
`Hello from the system space.`, closes the handle, and exits with status 7.
Syscall output goes to COM1; the shell prints its 64-bit exit status in
hexadecimal on both displays. Type `hello` again to exercise a fresh handle
table and reused user context.

The fixed-context ABI uses syscall 3 for `open(path, path_length)`, syscall 4
for `read(handle, writable_buffer, length)` with a per-handle sequential cursor,
and syscall 5 for `close(handle)`. Paths are limited to 255 bytes; reads are
limited to 512 bytes. There are four handles per run. EOF returns zero, invalid
user ranges return -1, oversized requests -2, missing paths -4, wrong-kind
paths -5, stale/closed handles -6, absent mounts -7, and exhausted handle slots
-8, and invalid namespace paths -9. Handles are generation-tagged and reset between launches. This is a
single-program read-only file API, not POSIX or a process-wide filesystem ABI.

With the prerequisites and pinned versions above, build and run:

```sh
ZIG=/path/to/zig LIMINE_DIR=/path/to/limine-binary OUT_DIR=/tmp/kratos-build ./kratos/build-qemu.sh --build-only
python3 kratos/test-user-program.py /tmp/kratos-build/kratos.iso
python3 kratos/test-user-program.py /tmp/kratos-build/kratos.iso --no-nx
/path/to/zig test kratos/kernel/user_image.zig
```

The build also requires `objcopy` (override with `OBJCOPY`). It independently
assembles `kratos/user/hello.S` for `x86_64-none-elf`, extracts its `.text` into
`hello.kru`, then packages that opaque KRU1 file in the read-only system image;
the kernel ELF is placed in the ISO alongside the image. This is not an ELF loader. KRU1 consists
of `KRU1`, a little-endian u32 payload length, a little-endian u32 entry offset,
then exactly that many payload bytes. Length must be 1–4096 and entry must be
inside the payload. There are no relocations, imports, or separate initialized
data segment: code and constants must be position-independent. The entry is
`0x400000 + offset` (the supplied program uses offset zero), with a read-only
executable page at `0x400000`, writable NX data at `0x401000`, and writable NX
stack at `0x402000` (initial RSP `0x403000`). Syscalls use the ABI above.

The loader checks the mounted package, complete KRU1 image, and fixed
mapping/physical prerequisites before entry. Missing, malformed, oversized or
unsupported images, and user faults, report failure and return to the shell.
The static pages are zeroed and reused on each run; only one context can run
and no scheduling, preemption, general process isolation, authentication, or
termination of a looping program is provided. The executable bytes are trusted
boot content, not authenticated. A malformed packaged program fixture can be
built with `KRATOS_TEST_SYSTEM_IMAGE=malformed-program`; run the usual user
program test with `--scenario malformed-program` to verify shell recovery.
For example, build that fixture in its own output directory and run it with:

```sh
KRATOS_TEST_SYSTEM_IMAGE=malformed-program OUT_DIR=/tmp/kratos-malformed-program ./kratos/build-qemu.sh --build-only
python3 kratos/test-user-program.py /tmp/kratos-malformed-program/kratos.iso --scenario malformed-program
```

## User-mode milestone regression

In addition to the prerequisites above, these commands require Python 3,
`objcopy`, and `expect`. From the repository root, set the actual tool paths;
the following are the paths used on the Linux verification host:

```sh
export ZIG="$HOME/.local/share/kratos-tools/zig-x86_64-linux-0.17.0/zig"
export LIMINE_DIR="$HOME/.local/share/kratos-tools/limine-binary"
export OUT_DIR=/tmp/opencode/kratos-0021-build
./kratos/build-qemu.sh --build-only
python3 kratos/test-user-program.py "$OUT_DIR/kratos.iso"
python3 kratos/test-user-program.py "$OUT_DIR/kratos.iso" --no-nx
python3 kratos/test-user-boundary.py "$OUT_DIR/kratos.iso"
./kratos/test-serial-shell.sh "$OUT_DIR/kratos.iso"
python3 kratos/test-keyboard-shell.py "$OUT_DIR/kratos.iso"
for test in kratos/kernel/*.zig; do
  if grep -q '^test ' "$test"; then "$ZIG" test "$test" || exit 1; fi
done
```

Build and test each separately assembled fault/syscall fixture in its own output
directory (do not substitute a fixture ISO for the normal hello ISO):

```sh
for scenario in syscalls ud kernel-read code-write data-execute; do
  KRATOS_TEST_USER="$scenario" OUT_DIR="$OUT_DIR/$scenario" \
    ./kratos/build-qemu.sh --build-only || exit 1
  python3 kratos/test-user-program.py "$OUT_DIR/$scenario/kratos.iso" \
    --scenario "$scenario" || exit 1
done
```

To run one case, use the matching `KRATOS_TEST_USER` value and `--scenario`
value from the loop. The selector is for test builds only; unset it for the
normal image. Each Python invocation boots QEMU with q35/256 MiB, BIOS,
headless display, a serial socket, `-no-reboot`, and `isa-debug-exit`. Each
case runs `hello` twice, checks its result, executes `echo shell-recovered-0`
and `echo shell-recovered-1` after the respective returns, and verifies shutdown
status 33. Success prints `QEMU <scenario> launch/relaunch, recovery after each,
and shutdown passed`; a missing result, timeout, unexpected QEMU exit, or wrong
shutdown status fails the command. `--no-nx` instead expects visible failure
on each launch and the same recovery and shutdown checks.

The normal image must print `Hello from the system space.` and exit 7.
The syscall fixture exits 21 only if a kernel-address output request returns -1
and unknown call 999 returns -3; mismatch exits 99 and fails the test. The
fault fixtures respectively assert user #UD vector 6/error 0, kernel-memory
read #PF vector 14/error 5, code-write #PF vector 14/error 7, and NX execution
#PF vector 14/error 0x15, followed by the shell's failure message. The separate
boundary test also injects a kernel NMI and requires `fatal x86 exception
vector=0x0000000000000002`, not user-fault recovery.

On 2026-11-13 all commands above passed on Linux with Zig 0.17.0, Limine
12.9.6, QEMU 11.1.3 and xorriso 1.5.8; the serial and keyboard regressions
both verified guest shutdown status 33. The keyboard test used the default ISO
resolution; no additional resolution or physical hardware was tested in this
run. xorriso emitted the documented EFI-directory warning; only BIOS was tested.
These checks verify a bounded single-program milestone, not full process
isolation, POSIX conformance, or a general security guarantee. A looping user
program still has no timeout or preemption.

## Read-only system image

The normal build requires Python 3 and generates `build/system.img` (or
`$OUT_DIR/system.img`). It packages the normal KRU1 hello program and a text
message, validates the result, and places it at `/boot/system.img` in the ISO.
Limine loads it as a boot module; the kernel validates and mounts it read-only
as `system:` before exposing it to shell or user mode. The builder accepts a
system tree containing exactly the `boot`, `packages`, and `policy` root
directories and a JSON mapping of each relative file path to `opaque`, `text`,
or `executable`. For example, after the normal build:

```sh
python3 kratos/tools/build-system-image.py build/system-tree kratos/user/system-types.json build/system.img
python3 kratos/tools/validate-system-image.py build/system.img
python3 kratos/tools/test-system-image.py
```

See [system-image-format.md](system-image-format.md) for the binary format and
limits. The build's `system-tree` is generated output; use a clean output
directory if its contents have been modified.
