# Build and validate a read-only space image

**Status:** planned

## Description

Create a deterministic host-side builder for the first read-only filesystem
image. It contains the protected `system` space and at least one packaged user
program, replacing the idea that every program must be linked into the kernel.

## Acceptance criteria

- Define a versioned, bounded image format with checked offsets, lengths,
  object IDs, parent relationships, kind, and file-type metadata. Document byte
  order, alignment, maximum image size, and rejection of malformed references
  or duplicate names in one directory.
- Build the same bytes from the same input tree and tool version. Include a
  `system:packages/hello` package directory with `program` containing the
  existing KRU1 payload and `message` containing readable test data. Store
  enough type metadata to identify both without extensions.
- Have the image builder enforce [0022](0022-filesystem-namespace-contract.md),
  including the lowercase-only names and reserved system layout. Host build
  filenames such as `hello.kru` are not names inside the filesystem.
- Provide an independent image validator and host tests for valid trees,
  truncated/oversized images, integer overflow, cycles, invalid names, duplicate
  IDs or siblings, and out-of-bounds file contents.
- Integrate the image into the documented QEMU build path without yet assuming
  a writable disk driver. Record the exact build command and image placement.

## Rationale and dependencies

Depends on [0022](0022-filesystem-namespace-contract.md). The image is the
smallest testable source of named program files. Kernel mounting and lookup are
separate in [0024](0024-kernel-readonly-files.md).
