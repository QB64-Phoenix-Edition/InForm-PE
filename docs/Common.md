# Common

The `QBDS.bi` and `QBDS.bm` file defines some **common constants and routines** shared across all QBDS libraries.

## Constants

These constants identify the type of data stored in a container:

| Constant              | Description                             |
| --------------------- | --------------------------------------- |
| `QBDS_TYPE_NONE`      | Unused entry                            |
| `QBDS_TYPE_RESERVED`  | Metadata entry                          |
| `QBDS_TYPE_DELETED`   | Deleted entry (tombstone)               |
| `QBDS_TYPE_STRING`    | Variable-length string                  |
| `QBDS_TYPE_BYTE`      | 8-bit integer                           |
| `QBDS_TYPE_INTEGER`   | 16-bit integer                          |
| `QBDS_TYPE_LONG`      | 32-bit integer                          |
| `QBDS_TYPE_INTEGER64` | 64-bit integer                          |
| `QBDS_TYPE_SINGLE`    | 32-bit floating-point number            |
| `QBDS_TYPE_DOUBLE`    | 64-bit floating-point number            |
| `QBDS_TYPE_UDT`       | User-defined data types (10–255)        |

## Routines

Computes a 64-bit FNV-1a hash for the STRING `k`.

```vb
FUNCTION QBDS_Hash~&& (k AS STRING)
```

Copies `bytes` worth of memory from `src` to `dst`.

```vb
SUB QBDS_CopyMemory (dst AS _UNSIGNED _OFFSET, src AS _UNSIGNED _OFFSET, bytes AS _UNSIGNED _OFFSET)
```
