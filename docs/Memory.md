# Memory Library

The `Memory` library provides routines for low-level memory operations, such as copying blocks of memory, setting byte values, and swapping byte orders (endianness conversion).

## Usage

To use the `Memory` library, include `Memory.bi` in your project.

```vb
'$INCLUDE:'InForm/extensions/Memory.bi'

DIM src AS STRING: src = "Hello, World!"
DIM dst AS STRING: dst = SPACE$(LEN(src))

' Copy memory from src to dst
Memory_Copy _OFFSET(dst), _OFFSET(src), LEN(src)
PRINT dst

' Fill a block of memory with zeros or character values
Memory_Set _OFFSET(dst), ASC("!"), LEN(dst)
PRINT dst

' Byte swap 16-bit, 32-bit, and 64-bit integers
DIM val16 AS _UNSIGNED INTEGER: val16 = &H1234
PRINT HEX$(Memory_SwapByte16(val16)) ' Prints 3412
```

## API Reference

### Memory Operations

***

Copies `count` bytes of memory from `src` to `dst`. The memory areas must not overlap. If memory areas may overlap, use `Memory_CopySafe`.

**Parameters:**

* `dst`: The destination memory address.
* `src`: The source memory address.
* `count`: The number of bytes to copy.

```vb
SUB Memory_Copy (dst AS _UNSIGNED _OFFSET, src AS _UNSIGNED _OFFSET, count AS _UNSIGNED _OFFSET)
```

***

Safely copies `count` bytes of memory from `src` to `dst`. Can be used when the destination and source memory blocks overlap.

**Parameters:**

* `dst`: The destination memory address.
* `src`: The source memory address.
* `count`: The number of bytes to copy.

```vb
SUB Memory_CopySafe (dst AS _UNSIGNED _OFFSET, src AS _UNSIGNED _OFFSET, count AS _UNSIGNED _OFFSET)
```

***

Fills a block of memory with a specified byte value.

**Parameters:**

* `dst`: The starting destination memory address.
* `value`: The byte value to set (passed as a `LONG`, converted to an unsigned char).
* `count`: The number of bytes to set.

```vb
SUB Memory_Set (dst AS _UNSIGNED _OFFSET, value AS LONG, count AS _UNSIGNED _OFFSET)
```

***

### Byte Swapping

***

Reverses the byte order of a 16-bit unsigned integer.

**Parameters:**

* `x`: The 16-bit unsigned integer to byte-swap.

**Returns:**
The byte-swapped 16-bit unsigned integer.

```vb
FUNCTION Memory_SwapByte16~% (x AS _UNSIGNED INTEGER)
```

***

Reverses the byte order of a 32-bit unsigned integer.

**Parameters:**

* `x`: The 32-bit unsigned integer to byte-swap.

**Returns:**
The byte-swapped 32-bit unsigned integer.

```vb
FUNCTION Memory_SwapByte32~& (x AS _UNSIGNED LONG)
```

***

Reverses the byte order of a 64-bit unsigned integer.

**Parameters:**

* `x`: The 64-bit unsigned integer to byte-swap.

**Returns:**
The byte-swapped 64-bit unsigned integer.

```vb
FUNCTION Memory_SwapByte64~&& (x AS _UNSIGNED _INTEGER64)
```
