#!/usr/bin/env python3
"""Verify system image mount diagnostics and recovery-shell availability."""
import argparse
import os
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("iso", nargs="?", default="build/kratos.iso")
parser.add_argument("--malformed", action="store_true")
args = parser.parse_args()

with tempfile.TemporaryDirectory(prefix="kratos-mount-") as directory:
    path = os.path.join(directory, "serial.sock")
    process = subprocess.Popen([
        os.environ.get("QEMU", "qemu-system-x86_64"), "-M", "q35", "-m", "256M",
        "-cdrom", args.iso, "-boot", "order=d", "-display", "none", "-no-reboot",
        "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04",
        "-serial", f"unix:{path},server=on,wait=off", "-monitor", "none",
    ])
    try:
        deadline = time.monotonic() + 10
        serial = socket.socket(socket.AF_UNIX)
        while True:
            try:
                serial.connect(path)
                break
            except (FileNotFoundError, ConnectionRefusedError):
                if time.monotonic() > deadline or process.poll() is not None:
                    raise RuntimeError("QEMU serial socket unavailable")
                time.sleep(0.02)
        serial.settimeout(0.2)
        pending = b""

        def wait_for(expected):
            global pending
            deadline = time.monotonic() + 20
            while expected not in pending and time.monotonic() < deadline:
                try:
                    chunk = serial.recv(4096)
                    if not chunk:
                        break
                    pending += chunk
                except socket.timeout:
                    if process.poll() is not None:
                        break
            if expected not in pending:
                raise AssertionError(f"missing {expected!r}: {pending!r}")
            pending = pending.split(expected, 1)[1]

        wait_for(b"KratOS: malformed system image; recovery shell active\r\n" if args.malformed else b"KratOS: system image mounted read-only\r\n")
        wait_for(b"kratos> ")
        serial.sendall(b"echo mount-recovery\r")
        wait_for(b"mount-recovery\r\n")
        wait_for(b"kratos> ")
        serial.sendall(b"shutdown\r")
        if process.wait(timeout=10) != 33:
            raise AssertionError("unexpected shutdown status")
        print("QEMU malformed-image recovery passed" if args.malformed else "QEMU system-image mount passed")
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
