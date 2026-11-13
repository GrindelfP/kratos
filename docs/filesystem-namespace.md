# Native filesystem namespace contract

This contract defines logical names and operations, independently of image or disk
format. Implementation and enforcement of storage, access and handles belong to
later tickets.

## Paths and names

An absolute path is `selector:` followed by zero or more `/name` components;
`mine:` selects the current principal's personal space, `system:` selects the
protected system space, and any other selector selects a shared space by its
unique namespace name. Roots are `mine:`, `system:`, and e.g. `team:`. A shared
space cannot use the reserved selectors `mine` or `system`; its namespace name
is unique across shared spaces. Display labels are separate metadata and need
not be unique: a label is never accepted as a selector, so ambiguity cannot
silently select a space.

A relative path has one or more slash-separated components and resolves from an
explicit base directory in one space. `.` leaves the current directory unchanged;
`..` selects its parent and fails at the space root. These navigation tokens are
syntax and are never stored. Absolute paths start at their selected root. Empty
paths, empty components, leading or trailing slashes, repeated separators,
colons outside the selector, and navigation above root are invalid. A
canonical path is absolute, has no navigation tokens and uses a selector and
components joined as above; canonicalization is lexical and does not establish
that an object exists or grant access.

Every persisted space, account, folder and file name is 1–32 bytes of ASCII
lowercase `a` through `z`. A path input and its canonical output are each at
most 255 bytes, including delimiters. Reject invalid or overlong input; never
lowercase, transliterate, or truncate it. Colon and slash are syntax only.
Names are compared byte-for-byte and sibling names are unique regardless of
object kind. The path parser accepts at most 128 components (including navigation
components); exceeding any bound is invalid input.

## Layout and operations

Every personal and shared space has root folders `inbox`, `work`, `library`,
and `archive`. The system space has root folders `boot`, `packages`, and
`policy`. These folders are reserved: they cannot be removed or renamed and
ordinary clients cannot create other root entries. Within them, authorized
clients may create files and folders subject to quotas and policy. `archive` is
organizational and has no implicit read-only behavior. System mutations require
system policy; the initial system image is read-only. Each program is kept in a
package tree under `system:packages`.

Each space and object has a stable opaque ID, unique in its respective identity
domain and never reused while references to it may exist. Lookup resolves a
selector then traverses components under authorization, matching exact names.
Rename and move within a space preserve object ID; duplicate destination names,
cycles, and changing reserved root folders fail. Cross-space moves are not
supported in this milestone; copying and deleting is a separate operation.
An open handle refers to the object identity, not its path, and remains usable
across a successful rename or move, subject to access rechecks and deletion
rules. The mutation ticket must specify deletion and crash lifetime precisely;
permission revocation must be enforced on subsequent handle operations.

Operations return distinct `invalid`, `missing`, `duplicate`, `denied`, and
`resource_exhausted` errors, plus `unsupported` for cross-space moves and
`not_directory` when traversal encounters a file. Implementations may expose
additional specific errors; they must not turn invalid input into a different
valid name. The principal/permission design must avoid exposing inaccessible
names when reporting errors.

Files carry explicit type metadata, independent of names: at minimum an opaque
binary, readable text, and executable program type, with unknown types retained
and treated as opaque. Metadata identifies a format, not authority to execute.
Spaces have owner, editor, and reader roles: owners administer grants and edit;
editors read and modify; readers read. System policy can further restrict
operations. A view or alias never grants access to its target; access is checked
against the underlying object and space on each operation. Saved cross-space
views, general alias semantics, authentication, persistence and full permission
enforcement are deferred to later work.
