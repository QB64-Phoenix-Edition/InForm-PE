'-----------------------------------------------------------------------------------------------------------------------
' File I/O like routines for memory loaded files
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'Memory.bi'

' A StringFile represents a file loaded in memory as a STRING buffer and a cursor to read and write from it.
' Unlike BASIC file I/O, StringFiles are zero-based.
' Since it uses a STRING as a backing buffer, no explicit memory management (i.e. freeing) is required.
TYPE StringFile
    buffer AS STRING
    cursor AS _UNSIGNED _OFFSET
END TYPE
