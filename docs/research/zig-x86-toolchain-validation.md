# Zig x86 toolchain validation

## Host and version

Validated on Apple Silicon macOS (`aarch64-macos`) with Homebrew Zig **0.17.0**. `zig version` returned `0.17.0`; `zig env` identified `/opt/homebrew/Cellar/zig/0.17.0/lib/zig`. Zig 0.17.0 was installed via Homebrew with the user's approval for general use; no project-specific system modifications were made by the probe.

## Freestanding probe

The source, binaries, and all intermediate files were placed in a `mktemp -d` directory and removed on exit. Source:

```zig
pub export fn _start() noreturn { while (true) {} }
```

`zig build-exe --help` documents `-fentry=[name]` and `-fno-PIE`; `-Wl,...` is not accepted by Zig 0.17.0 (`error: unrecognized parameter: -Wl,-e,_start`). The successful command was:

```sh
zig build-exe "$work/probe.zig" -target x86_64-freestanding -O ReleaseSmall -fno-PIE -fentry=_start -femit-bin="$work/a.elf"
```

Repeated from the same source into clean output names/directories, the stripped ReleaseSmall artifact hashes were both `ea5ea0d48fbd2f11ca3ad5804ea2ce96856e09da364a3d043123aa65b37ac080`; `cmp` reported byte-identical. `llvm-readobj --file-headers --program-headers --dynamic-table` identified an `ET_EXEC` x86-64 ELF with entry `0x10011AC`, loadable segments, and no interpreter/dynamic segment. `llvm-nm -u` on the stripped file reports `no symbols`, so that output alone is not evidence about unresolved symbols. A companion `-fno-strip` ReleaseSmall artifact exposed global `_start` at `0x10011AC` and no undefined entries in `llvm-readobj --symbols`; its bytes differed across temporary source paths, so only the default stripped build is currently demonstrated byte-reproducible.

An additional `-O Debug` build emitted debug info but was not reproducible: hashes `f67e183178334df08be3332731414841a29b45c68263734d8053379eaaa7f1e3` and `710334f76fe2923db751aa34a8ed8ef176e479c3ddbb89eacaa84ceffed93199` differed. Its ELF header entry was `0x1040e80`. `nm -u` listed linker-generated undefined names including `_DYNAMIC`, `_GLOBAL_OFFSET_TABLE_`, `__dso_handle`, and init/fini array boundary symbols; use the ReleaseSmall freestanding link path for the prototype. LLVM inspection tools are available from the installed LLVM 22 package.

## Debugger route and assessment

LLDB successfully loaded the stripped ReleaseSmall ELF as an x86_64 target and listed its image; symbol names require the companion unstripped artifact. The Limine/QEMU boot workflow is now verified separately in [`qemu-boot.md`](../qemu-boot.md). A QEMU GDB-remote session or entry breakpoint has not been exercised; `qemu-system-x86_64 -S -gdb tcp::1234` plus LLDB's GDB-remote target support remains a documented next debugging check, not a tested claim.

This establishes Zig 0.17.0 as viable for the project's x86_64 freestanding prototype: a repeatable static ELF with an inspected entry and no dynamic loader/dependency was built, and the project kernel has since booted under Limine/QEMU. The exact debug-mode linker output remains less clean and debugger remote operation remains untested; those are recorded limitations, not blockers for this minimal toolchain validation. Recommendation: proceed with Zig 0.17.0 for the prototype, keep the compiler version pinned, and continue testing as kernel features are added.
