#!/usr/bin/env python3
"""Verify two launches of a selected KRU1 image and recovery after each."""
import argparse
import os
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("iso", nargs="?", default="build/kratos.iso")
parser.add_argument("--no-nx", action="store_true")
parser.add_argument("--scenario", choices=("hello", "syscalls", "ud", "kernel-read", "code-write", "data-execute"), default="hello")
args = parser.parse_args()
iso, no_nx = args.iso, args.no_nx
if no_nx and args.scenario != "hello":
    parser.error("--no-nx requires the hello image")
faults = {
    "ud": (6, 0), "kernel-read": (14, 5),
    "code-write": (14, 7), "data-execute": (14, 0x15),
}
with tempfile.TemporaryDirectory(prefix="kratos-program-") as directory:
    path = os.path.join(directory, "serial.sock")
    process = subprocess.Popen([
        os.environ.get("QEMU", "qemu-system-x86_64"), "-M", "q35", "-m", "256M",
        "-cdrom", iso, "-boot", "order=d", "-display", "none", "-no-reboot",
        *(["-cpu", "qemu64,-nx"] if no_nx else []),
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

        wait_for(b"kratos> ")
        for launch in range(2):
            serial.sendall(b"hello\r")
            if no_nx:
                wait_for(b"hello: image unavailable, invalid, or program faulted\r\n")
            elif args.scenario in faults:
                vector, error = faults[args.scenario]
                wait_for(f"KratOS: user fault vector=0x{vector:016x} error=0x{error:016x}".encode())
                wait_for(b"hello: image unavailable, invalid, or program faulted\r\n")
            elif args.scenario == "syscalls":
                wait_for(b"hello: exited with status 0x0000000000000015\r\n")
            else:
                wait_for(b"Hello from a separate user program!\r\n")
                wait_for(b"hello: exited with status 0x0000000000000007\r\n")
            wait_for(b"kratos> ")
            marker = f"shell-recovered-{launch}".encode()
            serial.sendall(b"echo " + marker + b"\r")
            wait_for(b"\r\n" + marker + b"\r\nkratos> ")
        serial.sendall(b"shutdown\r")
        if process.wait(timeout=10) != 33:
            raise AssertionError("unexpected shutdown status")
        print(f"QEMU {args.scenario} launch/relaunch, recovery after each, and shutdown passed" + (" (NX unavailable)" if no_nx else ""))
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
