#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ISO=${1:-"$ROOT/build/kratos.iso"}
QEMU=${QEMU:-qemu-system-x86_64}
EXPECT=${EXPECT:-expect}

command -v "$QEMU" >/dev/null 2>&1 || { echo "missing required tool: $QEMU" >&2; exit 1; }
command -v "$EXPECT" >/dev/null 2>&1 || { echo "missing required tool: $EXPECT" >&2; exit 1; }
[ -f "$ISO" ] || { echo "missing ISO: $ISO (build it with kratos/build-qemu.sh --build-only)" >&2; exit 1; }

export ISO QEMU
"$EXPECT" <<'EOF'
set timeout 20
log_user 1
spawn $env(QEMU) -M q35 -m 256M -cdrom $env(ISO) -boot order=d \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    -serial stdio -display none -no-reboot -no-shutdown
expect {
    "kratos> " {}
    timeout { puts stderr "QEMU did not reach the serial shell"; exit 1 }
    eof { puts stderr "QEMU exited before the serial shell"; exit 1 }
}

# Submit a near-capacity echo and two commands in one rapid serial paste.
set payload "serial-input-regression-0123456789-abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0123456789-abcdefghij"
send -- "echo $payload\r\nhelp\rabout\r"
expect {
    "$payload" {}
    timeout { puts stderr "long pasted echo was lost or corrupted"; exit 1 }
    eof { puts stderr "QEMU exited during pasted commands"; exit 1 }
}
expect {
    "$payload" {}
    timeout { puts stderr "echo output did not match its pasted argument"; exit 1 }
}
expect {
    "kratos> " {}
    timeout { puts stderr "prompt was damaged after the long echo"; exit 1 }
}
expect {
    "help about echo mem clear kratos halt shutdown hello spaces ls pwd cd cat" {}
    timeout { puts stderr "command after pasted echo did not execute cleanly"; exit 1 }
}
expect {
    "KratOS: a small hobby operating system" {}
    timeout { puts stderr "later command was lost or prompt was corrupted"; exit 1 }
}
expect "kratos> "

# Browse the packaged system namespace and recover after a failed lookup.
send -- "spaces\r"
expect "Accessible spaces: system"
expect "kratos> "
send -- "pwd\r"
expect "system:"
expect "kratos> "
send -- "ls system:/packages/hello\r"
expect "message"
expect "program"
expect "kratos> "
send -- "cd system:/packages/hello\r"
expect "kratos> "
send -- "pwd\r"
expect "system:/packages/hello"
expect "kratos> "
send -- "cat message\r"
expect "Hello from the system space."
expect "kratos> "
send -- "ls system:/missing\rabout\r"
expect "Path not found"
expect "KratOS: a small hobby operating system"
expect "kratos> "

# A line exactly at capacity remains accepted, and quote parsing works in QEMU.
set full_line [string repeat x 128]
send -- "$full_line\r"
expect "Unknown command: $full_line"
expect "kratos> "
send -- "echo 'quoted serial text'\r"
expect "quoted serial text"
expect "quoted serial text"
expect "kratos> "

# Over-capacity input must be rejected as one line, not dispatched as a prefix.
set overflow [string repeat x 140]
send -- "$overflow\rabout\r"
expect {
    "Input error: line discarded" {}
    timeout { puts stderr "over-capacity input was not visibly rejected"; exit 1 }
}
expect "kratos> "
expect {
    "KratOS: a small hobby operating system" {}
    timeout { puts stderr "shell did not recover after over-capacity input"; exit 1 }
}
expect "kratos> "

send -- "echo abc\bD\rnonesuch\r"
expect {
    "abD" {}
    timeout { puts stderr "backspace editing failed"; exit 1 }
}
expect {
    "Unknown command: nonesuch" {}
    timeout { puts stderr "unknown-command recovery failed"; exit 1 }
}
send -- "halt\r"
expect {
    "KratOS halted" {}
    timeout { puts stderr "halt behavior failed"; exit 1 }
}

send -- "\001x"
expect eof
puts "QEMU serial shell regression passed"

# Start a fresh VM and verify shutdown through the serial shell itself.
spawn $env(QEMU) -M q35 -m 256M -cdrom $env(ISO) -boot order=d \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    -serial stdio -display none -no-reboot
expect {
    "kratos> " {}
    timeout { puts stderr "QEMU did not reach the shell for shutdown test"; exit 1 }
    eof { puts stderr "QEMU exited before the shutdown test"; exit 1 }
}
send -- "shutdown\r"
expect {
    "KratOS shutting down" {}
    timeout { puts stderr "shutdown command did not print its final message"; exit 1 }
}
expect eof
set qemu_result [wait]
if {[lindex $qemu_result 3] != 33} {
    puts stderr "shutdown returned unexpected QEMU status: $qemu_result"
    exit 1
}
puts "QEMU serial shutdown regression passed with exit status 33"
EOF
