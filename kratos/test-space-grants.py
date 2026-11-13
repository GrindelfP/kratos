#!/usr/bin/env python3
"""Verify persisted shared-space grants and revocation through the recovery shell."""
import os
import socket
import subprocess
import tempfile
import time

iso = os.environ.get("ISO", "build/kratos.iso")
image = os.environ.get("KRATOS_DATA_IMAGE", "/tmp/kratos-grants-test.img")
qemu = os.environ.get("QEMU", "qemu-system-x86_64")


def boot_and_run(boot_index, commands):
    with tempfile.TemporaryDirectory(prefix="kratos-grants-test-") as directory:
        serial_path = os.path.join(directory, "serial.sock")
        process = subprocess.Popen([
            qemu, "-M", "q35", "-m", "256M", "-cdrom", iso, "-boot", "order=d",
            "-display", "none", "-no-reboot", "-device", "piix3-ide,id=kratos-ide",
            "-drive", f"if=none,id=kratos-data,file={image},format=raw",
            "-device", "ide-hd,drive=kratos-data,bus=kratos-ide.0",
            "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04",
            "-serial", f"unix:{serial_path},server=on,wait=off", "-monitor", "none",
        ])
        try:
            deadline = time.monotonic() + 10
            serial = socket.socket(socket.AF_UNIX)
            while True:
                try:
                    serial.connect(serial_path)
                    break
                except (FileNotFoundError, ConnectionRefusedError):
                    if time.monotonic() > deadline or process.poll() is not None:
                        raise RuntimeError("QEMU serial socket unavailable")
                    time.sleep(0.02)
            serial.settimeout(0.2)
            pending = b""
            transcript = b""

            def wait_for(marker):
                nonlocal pending, transcript
                end = time.monotonic() + 20
                while marker not in pending and time.monotonic() < end:
                    try:
                        chunk = serial.recv(4096)
                        if not chunk:
                            break
                        pending += chunk
                        transcript += chunk
                    except socket.timeout:
                        if process.poll() is not None:
                            break
                if marker not in pending:
                    raise AssertionError(f"boot {boot_index}: missing {marker!r}; output={pending!r}; transcript={transcript!r}")
                pending = pending.split(marker, 1)[1]

            def command(line, expected):
                serial.sendall(line.encode("ascii") + b"\r")
                wait_for(expected.encode("ascii"))
                wait_for(b"kratos> ")
                if boot_index == 2 and line == "space-list" and b"team" in transcript:
                    raise AssertionError("revoked reader still discovers the shared space")

            wait_for(b"kratos> ")
            for line, expected in commands:
                command(line, expected)
            serial.sendall(b"shutdown\r")
            wait_for(b"KratOS shutting down")
            if process.wait(timeout=10) != 33:
                raise AssertionError("unexpected QEMU shutdown status")
            serial.close()
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


boot_and_run(1, [
    ("space-format", "Blank data volume formatted"),
    ("account-create alice", "Created account id=2"),
    ("account-create bob", "Created account id=3"),
    ("account-create carol", "Created account id=4"),
    ("account-use alice", "Active recovery principal: alice"),
    ("space-create team", "Space created"),
    ("touch team:/work/report", "Created"),
    ("write team:/work/report shared-content", "Written"),
    ("account-list", "2 alice (active)"),
    ("space-list", "team"),
    ("grant team: 3 reader", "Grant saved"),
    ("grant team: 4 editor", "Grant saved"),
    ("account-use bob", "Active recovery principal: bob"),
    ("space-list", "team"),
    ("read team:/work/report", "shared-content"),
    ("write team:/work/report denied-content", "Access denied for active principal"),
    ("account-use carol", "Active recovery principal: carol"),
    ("write team:/work/report editor-content", "Written"),
    ("account-use alice", "Active recovery principal: alice"),
    ("revoke team: 3", "Grant revoked"),
])

boot_and_run(2, [
    ("account-use bob", "Active recovery principal: bob"),
    ("space-list", "bob"),
    ("read team:/work/report", "Access denied for active principal"),
    ("account-use carol", "Active recovery principal: carol"),
    ("read team:/work/report", "editor-content"),
    ("write team:/work/report persisted-editor-content", "Written"),
    ("account-use alice", "Active recovery principal: alice"),
    ("read team:/work/report", "persisted-editor-content"),
])

print("QEMU persisted owner/editor/reader grants, denied writes, revocation, and recovery passed")
