'-----------------------------------------------------------------------------------------------------------------------
' Generic hash map library for QB64-PE with support for multiple data types and dynamic resizing
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'HMap.bi'

''' @brief Compute a 64-bit FNV-1a hash.
''' @param k The string to hash.
''' @return The computed hash.
FUNCTION __HMap_Hash~%& (k AS STRING)
    DIM hash AS _UNSIGNED _INTEGER64: hash = &HCBF29CE484222325~&&
    DIM keyLength AS _UNSIGNED _OFFSET: keyLength = LEN(k)
    DIM i AS _UNSIGNED _INTEGER64: i = 1

    WHILE i <= keyLength
        hash = (hash XOR ASC(k, i)) * &H100000001B3~&&
        i = i + 1
    WEND

    __HMap_Hash = hash
END FUNCTION

''' @brief Check whether the hash map has been initialized.
''' @param map The dynamic HMap array to check.
''' @return _TRUE if initialized, otherwise _FALSE.
FUNCTION HMap_IsInitialized%% (map() AS HMap)
    HMap_IsInitialized = LBOUND(map) = 0 _ANDALSO UBOUND(map) > 0 _ANDALSO map(0).T = HMAP_TYPE_RESERVED _ANDALSO LEN(map(0).V) = _SIZE_OF_OFFSET
END FUNCTION

''' @brief Initialize a hash map (allocate initial table and reset metadata).
''' After this call the map is ready for use; metadata is stored in element 0 and
''' user entries start at index 1.
''' @param map The dynamic HMap array to initialize.
SUB HMap_Initialize (map() AS HMap)
    REDIM map(0 TO 16) AS HMap ' power of 2 initial size

    map(0).V = _MK$(_UNSIGNED _OFFSET, 0) ' reset count to zero
    map(0).T = HMAP_TYPE_RESERVED ' set to reserved
END SUB

''' @brief Clear the hash map, but do not change the capacity.
''' @param map The hash map to clear.
SUB HMap_Clear (map() AS HMap)
    REDIM map(0 TO UBOUND(map)) AS HMap

    map(0).V = _MK$(_UNSIGNED _OFFSET, 0) ' reset count to zero
    map(0).T = HMAP_TYPE_RESERVED ' set to reserved
END SUB

''' @brief Delete the hash map and free all associated memory.
''' @param map The hash map to clear.
SUB HMap_Free (map() AS HMap)
    REDIM map(0) AS HMap
END SUB

''' @brief Return the current capacity of the hash map.
''' @param map The hash map to query.
''' @return The total number of slots in the map.
FUNCTION HMap_GetCapacity~%& (map() AS HMap)
    HMap_GetCapacity = UBOUND(map)
END FUNCTION

''' @brief Return the number of user entries currently stored in the map.
''' @param map The hash map to query.
''' @return The number of unique items.
FUNCTION HMap_GetCount~%& (map() AS HMap)
    HMap_GetCount = _CV(_UNSIGNED _OFFSET, map(0).V)
END FUNCTION

''' @brief Resize the hash table and rehash all user entries.
''' @param map The dynamic HMap array to resize.
SUB __HMap_ResizeAndRehash (map() AS HMap)
    DIM oldSize AS _UNSIGNED _OFFSET: oldSize = UBOUND(map)
    DIM tempMap(0 TO oldSize) AS HMap

    ' Make a copy of the old map
    DIM i AS _UNSIGNED _OFFSET
    WHILE i <= oldSize
        tempMap(i).K = map(i).K
        tempMap(i).V = map(i).V
        tempMap(i).T = map(i).T
        i = i + 1
    WEND

    DIM newSize AS _UNSIGNED _OFFSET: newSize = _SHL(oldSize, 1) ' grow by power of 2
    DIM newMask AS _UNSIGNED _OFFSET: newMask = newSize - 1
    REDIM map(0 TO newSize) AS HMap

    ' Copy metadata
    map(0).V = tempMap(0).V
    map(0).T = tempMap(0).T

    DIM AS _UNSIGNED _OFFSET hash, probeIndex, j

    i = 1
    WHILE i <= oldSize
        IF tempMap(i).T > HMAP_TYPE_DELETED THEN
            hash = __HMap_Hash(tempMap(i).K) AND newMask

            j = 0
            WHILE j < newSize
                probeIndex = 1 + (hash + j) AND newMask

                IF map(probeIndex).T = HMAP_TYPE_NONE THEN
                    map(probeIndex).T = tempMap(i).T
                    map(probeIndex).K = tempMap(i).K
                    map(probeIndex).V = tempMap(i).V
                    EXIT WHILE
                END IF

                j = j + 1
            WEND

            IF j >= newSize THEN
                ERROR _ERR_INTERNAL_ERROR
                EXIT SUB
            END IF
        END IF

        i = i + 1
    WEND
END SUB

''' @brief Insert or update a key's value.
''' If the slot is empty the key/value are inserted and the function returns _TRUE.
''' If the key already exists the value is updated and the function returns _TRUE.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The raw value string to store (packed using MK$ helpers for numeric types).
''' @param dataType The data type constant for the value being stored.
SUB __HMap_Set (map() AS HMap, k AS STRING, v AS STRING, dataType AS _UNSIGNED _BYTE)
    DIM tableSize AS _UNSIGNED _OFFSET: tableSize = UBOUND(map)
    DIM mask AS _UNSIGNED _OFFSET: mask = tableSize - 1
    DIM hash AS _UNSIGNED _OFFSET: hash = __HMap_Hash(k) AND mask
    DIM AS _UNSIGNED _OFFSET i, probeIndex, entryCount, insertSlot

    WHILE i < tableSize
        probeIndex = 1 + (hash + i) AND mask ' + 1 for metadata
        DIM currentType AS _UNSIGNED _BYTE: currentType = map(probeIndex).T

        IF currentType = HMAP_TYPE_NONE THEN
            IF insertSlot = 0 THEN insertSlot = probeIndex
            EXIT WHILE ' End of probe chain
        ELSEIF currentType = HMAP_TYPE_DELETED THEN
            IF insertSlot = 0 THEN insertSlot = probeIndex
        ELSE ' Slot is active
            IF map(probeIndex).K = k THEN
                ' Key found, update value and exit
                map(probeIndex).V = v
                map(probeIndex).T = dataType
                EXIT SUB
            END IF
        END IF

        i = i + 1 ' try the next one
    WEND

    ' If we are here, the key does not exist, so insert it
    IF insertSlot = 0 THEN
        ' This should not happen if resize logic is correct
        ERROR _ERR_INTERNAL_ERROR
        EXIT SUB
    END IF

    map(insertSlot).T = dataType
    map(insertSlot).K = k
    map(insertSlot).V = v

    ' Increase count
    entryCount = _CV(_UNSIGNED _OFFSET, map(0).V) + 1
    map(0).V = _MK$(_UNSIGNED _OFFSET, entryCount)

    ' Check if we need to resize the table before we exit
    IF entryCount >= (tableSize - _SHR(tableSize, 2)) THEN
        ' Triggers when the entry count is 75% or more of the table size
        __HMap_ResizeAndRehash map()
    END IF
END SUB

''' @brief Returns the index for the given key.
''' @param map The hash map to search.
''' @param k The key to search for.
''' @return The index of the key if found, 0 otherwise.
FUNCTION __HMap_Find~%& (map() AS HMap, k AS STRING)
    DIM tableSize AS _UNSIGNED _OFFSET: tableSize = UBOUND(map)
    DIM mask AS _UNSIGNED _OFFSET: mask = tableSize - 1
    DIM hash AS _UNSIGNED _OFFSET: hash = __HMap_Hash(k) AND mask
    DIM AS _UNSIGNED _OFFSET i, probeIndex

    WHILE i < tableSize
        probeIndex = 1 + (hash + i) AND mask ' + 1 for metadata

        DIM currentType AS _UNSIGNED _BYTE: currentType = map(probeIndex).T

        IF currentType = HMAP_TYPE_NONE THEN
            EXIT WHILE ' end of probe chain, key not found
        ELSEIF currentType <> HMAP_TYPE_DELETED _ANDALSO map(probeIndex).K = k THEN
            __HMap_Find = probeIndex
            EXIT WHILE ' key found
        END IF

        i = i + 1
    WEND
END FUNCTION

''' @brief Delete a key-value pair by key and return whether it existed.
''' @param map The hash map to modify.
''' @param k The key string to remove.
''' @return _TRUE if the key was removed, otherwise _FALSE.
FUNCTION HMap_Delete%% (map() AS HMap, k AS STRING)
    DIM probeIndex AS _UNSIGNED _OFFSET: probeIndex = __HMap_Find(map(), k)
    IF probeIndex THEN
        ' Mark the slot as deleted (tombstone)
        map(probeIndex).T = HMAP_TYPE_DELETED
        map(probeIndex).K = _STR_EMPTY
        map(probeIndex).V = _STR_EMPTY

        ' Decrease entry count
        map(0).V = _MK$(_UNSIGNED _OFFSET, _CV(_UNSIGNED _OFFSET, map(0).V) - 1)

        HMap_Delete = _TRUE
    END IF
END FUNCTION

''' @brief Delete a key-value pair and ignore the return value.
''' @param map The hash map to modify.
''' @param k The key string to remove.
SUB HMap_Delete (map() AS HMap, k AS STRING)
    DIM ignored AS _BYTE: ignored = HMap_Delete(map(), k)
END SUB

''' @brief Check whether a key exists in the map.
''' @param map The hash map to search.
''' @param k The key string to check.
''' @return _TRUE if the key is present, _FALSE otherwise.
FUNCTION HMap_Exists%% (map() AS HMap, k AS STRING)
    HMap_Exists = __HMap_Find(map(), k) <> 0
END FUNCTION

''' @brief Return the stored data type for a key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated data type constant (HMAP_TYPE_*), or 0 if not found.
FUNCTION HMap_GetDataType~%% (map() AS HMap, k AS STRING)
    DIM probeIndex AS _UNSIGNED _OFFSET: probeIndex = __HMap_Find(map(), k)
    IF probeIndex THEN HMap_GetDataType = map(probeIndex).T
END FUNCTION

''' @brief Retrieves the value for a given key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated value string, or an empty string if not found.
FUNCTION HMap_GetString$ (map() AS HMap, k AS STRING)
    DIM probeIndex AS _UNSIGNED _OFFSET: probeIndex = __HMap_Find(map(), k)
    IF probeIndex THEN HMap_GetString = map(probeIndex).V
END FUNCTION

''' @brief Updates an existing key or inserts if not present.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The value string.
SUB HMap_SetString (map() AS HMap, k AS STRING, v AS STRING)
    __HMap_Set map(), k, v, HMAP_TYPE_STRING
END SUB

''' @brief Retrieves the value for a given key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated _BYTE value.
FUNCTION HMap_GetByte%% (map() AS HMap, k AS STRING)
    HMap_GetByte%% = _CV(_BYTE, HMap_GetString(map(), k))
END FUNCTION

''' @brief Updates an existing key or inserts if not present.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The value _BYTE.
SUB HMap_SetByte (map() AS HMap, k AS STRING, v AS _BYTE)
    __HMap_Set map(), k, _MK$(_BYTE, v), HMAP_TYPE_BYTE
END SUB

''' @brief Retrieves the value for a given key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated INTEGER value.
FUNCTION HMap_GetInteger% (map() AS HMap, k AS STRING)
    HMap_GetInteger = CVI(HMap_GetString(map(), k))
END FUNCTION

''' @brief Updates an existing key or inserts it if not present.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The value INTEGER.
SUB HMap_SetInteger (map() AS HMap, k AS STRING, v AS INTEGER)
    __HMap_Set map(), k, MKI$(v), HMAP_TYPE_INTEGER
END SUB

''' @brief Retrieves the value for a given key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated LONG value.
FUNCTION HMap_GetLong& (map() AS HMap, k AS STRING)
    HMap_GetLong = CVL(HMap_GetString(map(), k))
END FUNCTION

''' @brief Updates an existing key or inserts it if not present.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The value LONG.
SUB HMap_SetLong (map() AS HMap, k AS STRING, v AS LONG)
    __HMap_Set map(), k, MKL$(v), HMAP_TYPE_LONG
END SUB

''' @brief Retrieves the value for a given key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated _INTEGER64 value.
FUNCTION HMap_GetInteger64&& (map() AS HMap, k AS STRING)
    HMap_GetInteger64 = _CV(_INTEGER64, HMap_GetString(map(), k))
END FUNCTION

''' @brief Updates an existing key or inserts it if not present.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The value _INTEGER64.
SUB HMap_SetInteger64 (map() AS HMap, k AS STRING, v AS _INTEGER64)
    __HMap_Set map(), k, _MK$(_INTEGER64, v), HMAP_TYPE_INTEGER64
END SUB

''' @brief Retrieves the value for a given key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated SINGLE value.
FUNCTION HMap_GetSingle! (map() AS HMap, k AS STRING)
    HMap_GetSingle = CVS(HMap_GetString(map(), k))
END FUNCTION

''' @brief Updates an existing key or inserts it if not present.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The value SINGLE.
SUB HMap_SetSingle (map() AS HMap, k AS STRING, v AS SINGLE)
    __HMap_Set map(), k, MKS$(v), HMAP_TYPE_SINGLE
END SUB

''' @brief Retrieves the value for a given key.
''' @param map The hash map to search.
''' @param k The key string to look up.
''' @return The associated DOUBLE value.
FUNCTION HMap_GetDouble# (map() AS HMap, k AS STRING)
    HMap_GetDouble = CVD(HMap_GetString(map(), k))
END FUNCTION

''' @brief Updates an existing key or inserts it if not present.
''' @param map The hash map to update.
''' @param k The key string.
''' @param v The value DOUBLE.
SUB HMap_SetDouble (map() AS HMap, k AS STRING, v AS DOUBLE)
    __HMap_Set map(), k, MKD$(v), HMAP_TYPE_DOUBLE
END SUB
