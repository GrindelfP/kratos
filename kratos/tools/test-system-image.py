#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

HERE = Path(__file__).parent

def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

builder = load('builder', 'build-system-image.py')
validator = load('validator', 'validate-system-image.py')

class ImageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('boot', 'packages/hello', 'policy'):
            (self.root / directory).mkdir(parents=True)
        (self.root / 'packages/hello/program').write_bytes(b'KRU1 payload')
        (self.root / 'packages/hello/message').write_bytes(b'hello\n')
        self.types = {'packages/hello/program': 'executable', 'packages/hello/message': 'text'}
        self.image = builder.build(self.root, self.types)

    def invalid(self, image):
        with self.assertRaises(ValueError):
            validator.validate(image)

    def record(self, index, offset, fmt, value):
        image = bytearray(self.image)
        struct.pack_into(fmt, image, 32 + index * 80 + offset, value)
        return image

    def test_valid_and_deterministic(self):
        self.assertEqual(self.image, builder.build(self.root, self.types))
        self.assertEqual(validator.validate(self.image), 7)
        self.assertIn(b'KRU1 payload', self.image)
        self.assertIn(b'hello\n', self.image)

    def test_bounds(self):
        self.invalid(self.image[:-1])
        self.invalid(self.image + b'x' * (validator.MAX_SIZE + 1))
        self.invalid(self.record(4, 52, '<Q', (1 << 64) - 1))
        self.invalid(self.record(4, 60, '<Q', (1 << 64) - 1))
        self.invalid(self.record(4, 52, '<Q', len(self.image) + 1))

    def test_structure(self):
        self.invalid(self.record(2, 0, '<Q', 2)) # duplicate id
        self.invalid(self.record(2, 8, '<Q', 999)) # missing parent
        self.invalid(self.record(2, 8, '<Q', 3)) # self cycle
        image = bytearray(self.image)
        # Duplicate package child name by copying name and length.
        image[32 + 5 * 80 + 18:32 + 5 * 80 + 52] = image[32 + 4 * 80 + 18:32 + 4 * 80 + 52]
        self.invalid(image)
        self.invalid(self.record(1, 20, 'B', ord('A')))

    def test_builder_rejects_invalid_input(self):
        (self.root / 'boot/Bad').write_bytes(b'x')
        with self.assertRaises(ValueError):
            builder.build(self.root, self.types)

    def test_reserved_root_and_manifest(self):
        with self.assertRaises(ValueError):
            builder.build(self.root, {})
        (self.root / 'extra').mkdir()
        with self.assertRaises(ValueError):
            builder.build(self.root, self.types)
        with self.assertRaises(ValueError):
            builder.build(self.root, {})

if __name__ == '__main__':
    unittest.main()
