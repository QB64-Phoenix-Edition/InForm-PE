'-----------------------------------------------------------------------------------------------------------------------
' Generic circular queue library for QB64-PE
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'QBDS.bi'

''' @brief Primary data structure used by the Queue library.
''' The user declares a dynamic array of this type and passes it to the Queue_* functions.
''' The library stores internal metadata at array index 0; user entries begin at index 1.
''' The queue is implemented as a ring buffer with a head and a tail pointer.
''' When the queue is full, the capacity is automatically doubled and the queue is unwrapped.
''' Metadata (stored in element 0):
'''     - V: packed count, head, and tail (_MK$(_UNSIGNED _OFFSET, count) + _MK$(_UNSIGNED _OFFSET, head) + _MK$(_UNSIGNED _OFFSET, tail))
'''     - T: QBDS_TYPE_RESERVED
TYPE Queue
    V AS STRING
    T AS _UNSIGNED _BYTE
END TYPE
