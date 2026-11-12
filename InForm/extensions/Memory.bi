'-----------------------------------------------------------------------------------------------------------------------
' Low-level memory manipulation functions
' Copyright (c) 2026 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

DECLARE CUSTOMTYPE LIBRARY
    ''' @brief Copies bytes from a source memory location to a destination memory location.
    ''' The memory areas must not overlap. Use Memory_CopySafe if the memory areas might overlap.
    ''' @param dst The destination memory address.
    ''' @param src The source memory address.
    ''' @param count The number of bytes to copy.
    SUB Memory_Copy ALIAS "std::memcpy" (BYVAL dst AS _UNSIGNED _OFFSET, BYVAL src AS _UNSIGNED _OFFSET, BYVAL count AS _UNSIGNED _OFFSET)
    ''' @brief Safely copies bytes between potentially overlapping memory locations.
    ''' @param dst The destination memory address.
    ''' @param src The source memory address.
    ''' @param count The number of bytes to copy.
    SUB Memory_CopySafe ALIAS "std::memmove" (BYVAL dst AS _UNSIGNED _OFFSET, BYVAL src AS _UNSIGNED _OFFSET, BYVAL count AS _UNSIGNED _OFFSET)
    ''' @brief Fills a block of memory with a specified byte value.
    ''' @param dst The starting memory address to fill.
    ''' @param value The byte value to set.
    ''' @param count The number of bytes to set.
    SUB Memory_Set ALIAS "std::memset" (BYVAL dst AS _UNSIGNED _OFFSET, BYVAL value AS LONG, BYVAL count AS _UNSIGNED _OFFSET)
END DECLARE

DECLARE LIBRARY
    ''' @brief Reverses the byte order of a 16-bit unsigned integer.
    ''' @param x The 16-bit value to byte-swap.
    ''' @return The byte-swapped 16-bit value.
    FUNCTION Memory_SwapByte16~% ALIAS "__builtin_bswap16" (BYVAL x AS _UNSIGNED INTEGER)
    ''' @brief Reverses the byte order of a 32-bit unsigned integer.
    ''' @param x The 32-bit value to byte-swap.
    ''' @return The byte-swapped 32-bit value.
    FUNCTION Memory_SwapByte32~& ALIAS "__builtin_bswap32" (BYVAL x AS _UNSIGNED LONG)
    ''' @brief Reverses the byte order of a 64-bit unsigned integer.
    ''' @param x The 64-bit value to byte-swap.
    ''' @return The byte-swapped 64-bit value.
    FUNCTION Memory_SwapByte64~&& ALIAS "__builtin_bswap64" (BYVAL x AS _UNSIGNED _INTEGER64)
END DECLARE
