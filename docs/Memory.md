# Memory Library

The `Memory` library provides routines for low-level memory operations.

## API Reference

Copies `bytes` worth of memory from `src` to `dst`. The `Safe` variant can be used safely when `dst` and `src` overlaps.

```vb
SUB Memory_Copy (dst AS _UNSIGNED _OFFSET, src AS _UNSIGNED _OFFSET, bytes AS _UNSIGNED _OFFSET)
SUB Memory_CopySafe (dst AS _UNSIGNED _OFFSET, src AS _UNSIGNED _OFFSET, bytes AS _UNSIGNED _OFFSET)
```

Returns `x` with the order of the bytes reversed.

```vb
FUNCTION Memory_SwapByte16~% (x AS _UNSIGNED INTEGER)
FUNCTION Memory_SwapByte32~& (x AS _UNSIGNED LONG)
FUNCTION Memory_SwapByte64~&& (x AS _UNSIGNED _INTEGER64)
```
