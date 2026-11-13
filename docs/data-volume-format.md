# Writable data volume, versions 1 and 2

The writable data disk uses 512-byte sectors and a fixed LBA layout. Sector 0
is unused. Metadata slot A occupies sectors 1–9 and slot B sectors 10–18. File
data starts at LBA 19. Each metadata slot is a 4608-byte snapshot containing a
512-byte header followed by at most 64 fixed 64-byte object records. All
integers are unsigned little-endian.

Version 1 headers contain `KRSPACE1`, record count, monotonically increasing
generation, CRC-32, next object ID, data-start LBA (19), and zero reserved
bytes. Version 2 retains the same object records and adds an identity-table
schema marker, account and grant counts, and the next stable account ID in the
header. It stores up to six 50-byte account records and eight 17-byte grant
records in the previously reserved header area. The CRC covers the entire
metadata slot with the CRC field zeroed. A
record stores object ID, parent ID, kind (`space`, `directory`, or `file`),
name length and 32-byte lowercase-ASCII name, file byte size, first data LBA,
and allocated sector count. A file extent must fit the device, must not
overlap another live extent, and contains no more than 64 KiB. Directories and
spaces have no extent. IDs increase monotonically and are not reused after a
successful mutation. A removed object makes its old handle stale (`not found`);
rename and move preserve its ID.

The first record is the root of the namespace and has parent ID zero. Further
root records are spaces. Version 2 creates a stable `admin` account and its
private space when a blank disk is explicitly formatted. Account IDs are
independent of lowercase account names; renaming changes no object IDs or
ownership. Disabling an account retains its private data and ownership records
but prevents selection. Version 1 volumes still mount without identities;
create an account before creating owned spaces on such a volume. Every space
is created with exactly the reserved
directories `inbox`, `work`, `library`, and `archive`; callers may create
objects below those directories. A directory may
contain at most 64 objects because the whole volume has a 64-object metadata
limit. Names are 1–32 bytes of `a` through `z`; paths are at most 255 bytes.

Each mutation creates new metadata in the inactive slot. File replacement
allocates a fresh extent while the prior generation still references its old
extent. The operation writes new data, flushes the device, writes the full
metadata snapshot, then flushes again. The highest-generation snapshot with a
valid CRC and valid references wins at mount. A torn inactive slot is ignored,
so an interrupted operation exposes the complete old snapshot; a complete new
slot exposes the new snapshot. Data sectors not referenced by either selected
snapshot are free and may be reused. An I/O or flush error poisons the live
mount; it reports the error and requires a reboot/remount before more
mutations. Corrupt or unsupported metadata is rejected without repair.

`space-format` is explicit and succeeds only when both metadata slots are all
zero. It never reformats an existing or malformed volume. No disk is formatted
automatically at boot. The QEMU image creator makes a blank image without
overwriting existing files; attach it with the documented primary-master IDE
configuration in `docs/qemu-boot.md`.

This bounded snapshot format is a milestone format, not a general-purpose
filesystem. The metadata limit is 64 objects, maximum file size is 64 KiB,
and recovery keeps the prior complete generation when an update is
interrupted.

Version 2 binds each private space to one account and stores owner, editor, or
reader grants for shared spaces in the same checksummed snapshot. Owners can
read and mutate files and manage grants; editors can read and mutate files;
readers can discover, look up, and read. Lookup reports inaccessible shared
objects as missing. File handles recheck the current grant on every read, so a
revoked grant or disabled account cannot keep using an already-open handle.
`account-use` selects a principal in the privileged recovery shell for testing;
it is not password login or a security boundary against someone with shell
access. The current single user-program context uses the selected principal;
authentication and general process isolation are not provided.
