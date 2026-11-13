#!/usr/bin/env python3
"""Exercise ATA PIO write/read, flush, and persistence across QEMU reboot."""
import os
import socket
import subprocess
import tempfile
import time

iso = os.environ.get("ISO", "build/kratos.iso")
image = os.environ.get("KRATOS_DATA_IMAGE", "/tmp/kratos-block-test.img")
expected_boots = [
    b"KratOS: block device write/read passed; reboot to verify persistence\r\n",
    b"KratOS: block device write/read/reboot persistence passed\r\n",
]

with tempfile.TemporaryDirectory(prefix="kratos-block-test-") as directory:
    for boot, expected in enumerate(expected_boots):
        serial_path = os.path.join(directory, f"serial-{boot}.sock")
        process = subprocess.Popen([
            os.environ.get("QEMU", "qemu-system-x86_64"), "-M", "q35", "-m", "256M",
            "-cdrom", iso, "-boot", "order=d", "-display", "none", "-no-reboot",
            "-device", "piix3-ide,id=kratos-ide",
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

            def wait_for(marker):
                global pending
                deadline = time.monotonic() + 20
                while marker not in pending and time.monotonic() < deadline:
                    try:
                        chunk = serial.recv(4096)
                        if not chunk:
                            break
                        pending += chunk
                    except socket.timeout:
                        if process.poll() is not None:
                            break
                if marker not in pending:
                    raise AssertionError(f"missing {marker!r}: {pending!r}")
                pending = pending.split(marker, 1)[1]

            wait_for(expected)
            wait_for(b"kratos> ")
            serial.sendall(b"echo block-recovery\r")
            wait_for(b"block-recovery\r\n")
            wait_for(b"kratos> ")
            serial.sendall(b"shutdown\r")
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

print("QEMU ATA PIO write/read, flush, reboot persistence, and recovery passed")
