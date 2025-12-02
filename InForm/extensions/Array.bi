'-----------------------------------------------------------------------------------------------------------------------
' Generic dynamic array library for QB64-PE
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'QBDS.bi'

''' @brief Primary data structure used by the Array library.
''' The user declares a dynamic array of this type and passes it to the Array_* functions.
''' The library stores internal metadata at array index 0; user entries begin at index 1.
''' Metadata (stored in element 0):
'''     - V: count of items (_MK$(_UNSIGNED _OFFSET, count))
'''     - T: QBDS_TYPE_RESERVED
TYPE Array
    V AS STRING
    T AS _UNSIGNED _BYTE
END TYPE
