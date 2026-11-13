#!/usr/bin/env python3
"""Independently validate the complete KRSYSIMG v1 namespace and byte ranges."""
import argparse
from pathlib import Path
import struct

MAX_SIZE = 16 * 1024 * 1024
U64_MAX = (1 << 64) - 1


def validate(image):
    def require(condition, message):
        if not condition:
            raise ValueError(message)
    require(32 <= len(image) <= MAX_SIZE, 'image size')
    magic, version, total, count, table, data, reserved = struct.unpack_from('<8sIIIIII', image)
    require(magic == b'KRSYSIMG' and version == 1 and reserved == 0, 'header')
    require(total == len(image) and 1 <= count <= 4096 and table == 32, 'header bounds')
    require(data == 32 + count * 80 and data <= total, 'table bounds')
    objects, siblings, ranges = {}, set(), []
    for i in range(count):
        ident, parent, kind, typ, nlen, raw, start, length, tail = struct.unpack_from('<QQBBH32sQQ12s', image, 32 + i * 80)
        require(ident != 0 and ident not in objects, 'duplicate or zero ID')
        require(tail == bytes(12) and nlen <= 32 and raw[nlen:] == bytes(32 - nlen), 'record padding')
        name = raw[:nlen]
        require(kind in (1, 2), 'kind')
        if ident == 1:
            require(parent == 0 and kind == 1 and not name, 'root')
        else:
            require(parent != 0 and 1 <= nlen <= 32 and all(97 <= c <= 122 for c in name), 'name or parent')
            require((parent, name) not in siblings, 'duplicate sibling')
            siblings.add((parent, name))
        if kind == 1:
            require(typ == 0 and start == 0 and length == 0, 'directory content')
        else:
            require(typ != 0 and start <= U64_MAX - length, 'file type or overflow')
            require(data <= start <= total and start + length <= total, 'file bounds')
            if length:
                ranges.append((start, start + length))
        objects[ident] = (parent, kind, name)
    require(1 in objects, 'missing root')
    for ident in objects:
        current, visited, parts = ident, set(), []
        while current != 1:
            require(current not in visited, 'cycle')
            visited.add(current)
            require(current in objects, 'missing parent')
            parent, _, name = objects[current]
            parts.append(name)
            require(parent in objects and objects[parent][1] == 1, 'parent is not directory')
            current = parent
        require(len(b'system:') + sum(len(p) + 1 for p in parts) <= 255, 'path too long')
    root_children = {name for parent, kind, name in objects.values() if parent == 1 and kind == 1}
    require(root_children == {b'boot', b'packages', b'policy'} and sum(parent == 1 for parent, _, _ in objects.values()) == 3, 'system layout')
    cursor = data
    for start, end in sorted(ranges):
        require(start == cursor, 'content overlap or gap')
        cursor = end
    require(cursor == total, 'unreferenced content')
    return len(objects)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image')
    args = parser.parse_args()
    try:
        path = Path(args.image)
        if path.stat().st_size > MAX_SIZE:
            raise ValueError('image size')
        count = validate(path.read_bytes())
        print(f'valid system image: {count} objects')
    except (OSError, ValueError, struct.error) as e:
        parser.exit(1, f'validate-system-image: {e}\n')


if __name__ == '__main__':
    main()
