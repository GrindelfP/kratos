#!/usr/bin/env python3
"""QEMU PS/2 shell regression; serial is output-only.

Usage: python3 kratos/test-keyboard-shell.py [path/to/kratos.iso]
Screenshots and serial output are retained in a temporary directory.
"""

import os
import socket
import subprocess
import sys
import tempfile
import time

base = os.path.join(tempfile.mkdtemp(prefix="kratos-keyboard-"), "qemu")
iso = sys.argv[1] if len(sys.argv) > 1 else "build/kratos.iso"
monitor_path = base + "-monitor.sock"
serial_log = base + "-serial.log"
process = subprocess.Popen(
    [
        "qemu-system-x86_64",
        "-M",
        "q35",
        "-m",
        "256M",
        "-cdrom",
        iso,
        "-boot",
        "order=d",
        "-device",
        "isa-debug-exit,iobase=0xf4,iosize=0x04",
        "-serial",
        "file:" + serial_log,
        "-monitor",
        "unix:" + monitor_path + ",server=on,wait=off",
        "-display",
        "none",
        "-no-reboot",
    ]
)
monitor = None


def read_log():
    try:
        with open(serial_log, encoding="utf-8", errors="replace") as stream:
            return stream.read()
    except FileNotFoundError:
        return ""


try:
    for _ in range(100):
        if os.path.exists(monitor_path):
            break
        if process.poll() is not None:
            raise RuntimeError(f"QEMU exited during startup: {process.returncode}")
        time.sleep(0.1)
    else:
        raise TimeoutError("QEMU monitor socket did not appear")

    monitor = socket.socket(socket.AF_UNIX)
    monitor.connect(monitor_path)
    time.sleep(0.2)
    monitor.recv(4096)

    def monitor_command(command):
        monitor.sendall((command + "\n").encode())
        time.sleep(0.08)
        monitor.recv(4096)

    def wait_for(text):
        for _ in range(200):
            data = read_log()
            if text in data:
                return
            if process.poll() is not None:
                break
            time.sleep(0.1)
        raise AssertionError(f"missing {text!r} in QEMU output:\n{read_log()}")

    def key(name):
        monitor_command(f"sendkey {name} 40")
        time.sleep(0.04)

    def type_keys(names):
        for name in names:
            key(name)

    wait_for("kratos> ")
    monitor_command("screendump " + base + "-welcome.ppm")
    type_keys(["h", "e", "l", "x", "backspace", "p", "ret"])
    wait_for("help about echo mem clear kratos halt shutdown")
    type_keys(
        [
            "e", "c", "h", "o", "spc", "shift-apostrophe", "shift-h", "e",
            "l", "l", "o", "spc", "shift-1", "shift-apostrophe", "ret",
        ]
    )
    wait_for("\nHello !\n")
    # Complete a unique prefix, then preserve an unsubmitted draft across recall.
    type_keys(["e", "c", "tab", "spc", "d", "r", "a", "f", "t"])
    type_keys(["up", "down", "ret"])
    wait_for("\ndraft\n")
    type_keys(["up", "ret"])
    for _ in range(100):
        if read_log().count("\ndraft\n") == 2:
            break
        time.sleep(0.1)
    else:
        raise AssertionError("recalled command did not execute twice: " + read_log())
    type_keys(["h", "tab"])
    wait_for("help halt ")
    type_keys(["e", "l", "p", "ret"])
    type_keys(["c", "l", "e", "a", "r", "ret"])
    wait_for("[screen cleared]")
    time.sleep(0.2)
    monitor_command("screendump " + base + "-shell.ppm")
    type_keys(["k", "r", "a", "t", "o", "s", "ret"])
    wait_for("KratOS app: press q")
    time.sleep(0.5)
    monitor_command("screendump " + base + "-app.ppm")
    key("q")
    time.sleep(0.5)
    monitor_command("screendump " + base + "-return.ppm")
    type_keys(["h", "e", "l", "p", "ret"])
    wait_for("help about echo mem clear kratos halt shutdown")
    type_keys(["s", "h", "u", "t", "d", "o", "w", "n", "ret"])
    wait_for("KratOS shutting down")
    status = process.wait(timeout=5)
    assert status == 33, f"unexpected QEMU shutdown status: {status}"
    data = read_log()
    assert data.count("help about echo mem clear kratos halt shutdown") == 3, data
    print(data)
    print("QEMU exited via guest shutdown with status 33.")
    print("Screenshots and serial output:", os.path.dirname(base))
finally:
    if monitor is not None:
        monitor.close()
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=5)
