#!/usr/bin/env python3
"""Build a KRSYSIMG image from a system tree and explicit file type manifest."""
import argparse
import json
import os
from pathlib import Path
import struct

HEADER = struct.Struct('<8sIIIIII')
RECORD = struct.Struct('<QQBBH32sQQ12s')
MAX_SIZE = 16 * 1024 * 1024
MAX_OBJECTS = 4096
TYPES = {'opaque': 1, 'text': 2, 'executable': 3}


def build(root, types):
    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        raise ValueError('root must be a real directory')
    if set(os.listdir(root)) != {'boot', 'packages', 'policy'}:
        raise ValueError('system root must contain boot, packages, policy')
    records = [(1, 0, 1, 0, b'', b'')]
    seen_files = set()
    total_content = 0

    def walk(folder, parent, relative):
        nonlocal total_content
        for path in sorted(folder.iterdir(), key=lambda p: os.fsencode(p.name)):
            name = os.fsencode(path.name)
            if not 1 <= len(name) <= 32 or any(c < 97 or c > 122 for c in name):
                raise ValueError('invalid name: ' + str(path))
            rel = relative + ('/' if relative else '') + path.name
            if len(('system:/' + rel).encode('ascii')) > 255:
                raise ValueError('path too long')
            if path.is_symlink():
                raise ValueError('symlink is forbidden: ' + str(path))
            ident = len(records) + 1
            if ident > MAX_OBJECTS:
                raise ValueError('too many objects')
            if path.is_dir():
                records.append((ident, parent, 1, 0, name, b''))
                walk(path, ident, rel)
            elif path.is_file():
                if rel not in types or types[rel] not in TYPES:
                    raise ValueError('missing or invalid type: ' + rel)
                seen_files.add(rel)
                with path.open('rb') as source:
                    content = source.read(MAX_SIZE - total_content + 1)
                total_content += len(content)
                if total_content > MAX_SIZE:
                    raise ValueError('file data too large')
                records.append((ident, parent, 2, TYPES[types[rel]], name, content))
            else:
                raise ValueError('unsupported input: ' + str(path))
    walk(root, 1, '')
    if seen_files != set(types):
        raise ValueError('manifest has missing or extra paths')
    if any(r[2] != 1 for r in records if r[1] == 1):
        raise ValueError('system root entries must be directories')
    offset = HEADER.size + RECORD.size * len(records)
    size = offset + sum(len(r[5]) for r in records)
    if size > MAX_SIZE:
        raise ValueError('image too large')
    table, data = bytearray(), bytearray()
    for ident, parent, kind, typ, name, content in records:
        file_offset = offset + len(data) if kind == 2 else 0
        table += RECORD.pack(ident, parent, kind, typ, len(name), name.ljust(32, b'\0'), file_offset, len(content), bytes(12))
        data += content
    return HEADER.pack(b'KRSYSIMG', 1, size, len(records), HEADER.size, offset, 0) + table + data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tree')
    parser.add_argument('manifest', help='JSON object mapping relative paths to opaque, text or executable')
    parser.add_argument('output')
    args = parser.parse_args()
    try:
        with open(args.manifest, encoding='utf-8') as f:
            types = json.load(f)
        if not isinstance(types, dict):
            raise ValueError('manifest must be an object')
        image = build(args.tree, types)
        Path(args.output).write_bytes(image)
    except (OSError, ValueError, RecursionError) as e:
        parser.exit(1, f'build-system-image: {e}\n')


if __name__ == '__main__':
    main()
