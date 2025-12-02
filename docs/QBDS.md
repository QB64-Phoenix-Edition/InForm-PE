# **QBDS**

`QBDS` is a collection of **generic data structure libraries**. It provides containers such as queues, lists, stacks, maps, and more.

## Libraries

* [**Array**](./Array.md): A generic dynamic array supporting multiple data types and resizing.
* [**HMap**](./HMap.md): A generic hash map library supporting multiple data types and resizing.
* [**HMap64**](./HMap64.md): A hash map library optimized for 64-bit integer keys, supporting multiple data types and resizing.
* [**HSet**](./HSet.md): A generic hash set library supporting multiple data types and resizing.
* [**LList**](./LList.md): A generic doubly linked list library supporting multiple data types and resizing.
* [**Queue**](./Queue.md): A generic queue library supporting multiple data types and resizing.
* [**Stack**](./Stack.md): A generic stack library supporting multiple data types and resizing.

## QBDS.bi + QBDS.bm

The `QBDS.bi` and `QBDS.bm` file defines some **common constants and routines** shared across all `QBDS` libraries.

### Constants

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

## API Reference

Computes a 64-bit FNV-1a hash for the STRING `k`.

```vb
FUNCTION QBDS_Hash~&& (k AS STRING)
```
