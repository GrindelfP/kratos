#!/usr/bin/env python3
"""Exercise user faults, shell recovery, and a kernel-origin NMI in QEMU."""
import os
import socket
import subprocess
import sys
import tempfile
import time

iso = sys.argv[1] if len(sys.argv) > 1 else "build/kratos.iso"
directory = tempfile.mkdtemp(prefix="kratos-user-boundary-")
serial_path = os.path.join(directory, "serial.sock")
monitor_path = os.path.join(directory, "monitor.sock")
process = subprocess.Popen([
    os.environ.get("QEMU", "qemu-system-x86_64"), "-M", "q35", "-m", "256M",
    "-cdrom", iso, "-boot", "order=d", "-display", "none", "-no-reboot",
    "-serial", f"unix:{serial_path},server=on,wait=off",
    "-monitor", f"unix:{monitor_path},server=on,wait=off",
])


def connect(path):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            connection = socket.socket(socket.AF_UNIX)
            connection.connect(path)
            connection.settimeout(0.2)
            return connection
        except (FileNotFoundError, ConnectionRefusedError):
            connection.close()
            if process.poll() is not None:
                raise RuntimeError("QEMU exited before connecting")
            time.sleep(0.02)
    raise TimeoutError(f"socket unavailable: {path}")


try:
    serial = connect(serial_path)
    monitor = connect(monitor_path)
    output = b""

    def wait_for(text):
        global output
        deadline = time.monotonic() + 20
        while text not in output and time.monotonic() < deadline:
            try:
                chunk = serial.recv(4096)
                if not chunk:
                    break
                output += chunk
            except socket.timeout:
                if process.poll() is not None:
                    break
        if text not in output:
            raise AssertionError(f"missing {text!r}:\n{output.decode(errors='replace')}")

    wait_for(b"kratos> ")
    for expected in (
        b"user fault vector=0x0000000000000006 error=0x0000000000000000",
        b"user fault vector=0x000000000000000e error=0x0000000000000005",
        b"user fault vector=0x000000000000000e error=0x0000000000000007",
        b"user fault vector=0x000000000000000e error=0x0000000000000015",
        b"ring3 boundary self-test passed",
    ):
        if expected not in output:
            raise AssertionError(f"missing {expected!r}:\n{output.decode(errors='replace')}")
    serial.sendall(b"echo recovered-shell\r")
    wait_for(b"\r\nrecovered-shell\r\nkratos> ")
    monitor.sendall(b"nmi\n")
    wait_for(b"fatal x86 exception vector=0x0000000000000002")
    print("QEMU user faults, recovery shell, and kernel NMI classification passed")
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
