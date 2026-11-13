# Read-only system image, version 1

The image is a deterministic snapshot of `system:`. All integers are unsigned
little-endian. The maximum image size is 16 MiB and the maximum object count is
4096. There is no padding or alignment requirement; offsets are byte offsets.
The 32-byte header is `<8sIIIIII`: magic `KRSYSIMG`, version 1, total size,
object count, table offset (32), data offset (32 + 80 * count), and reserved
zero. The total size must equal the file length.

Each 80-byte record is `<QQBBH32sQQ12s`: nonzero object ID, parent ID, kind
(1 directory, 2 file), file type (0 directory, 1 opaque, 2 text, 3 executable),
name length, a 32-byte name padded with zeros, content offset and length, and
12 reserved zero bytes. The root has ID 1, parent 0, an empty name and is a
directory. Other names follow the namespace contract. Directories have zero
content fields. File content lies in the data region; zero-length files use a
valid data-region offset. File ranges must not overlap and collectively cover
the data region without gaps. Unknown file types are retained as opaque.

IDs are assigned from 2 in bytewise sorted depth-first order. Each parent must
be a directory, every object must lead to the root without cycles, and sibling
names must be unique. Root children are exactly the directories `boot`,
`packages`, and `policy`. No path may exceed 255 bytes including `system:` and
separators. The validator rejects invalid ranges, arithmetic overflow beyond
64 bits, unsupported versions, nonzero reserved or padding bytes, malformed
references and invalid namespace structure. The builder rejects symlinks and
non-regular inputs. The image is read-only; IDs are stable within an image,
with cross-build identity management deferred.
