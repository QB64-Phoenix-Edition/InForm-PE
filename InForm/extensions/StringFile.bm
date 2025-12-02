'-----------------------------------------------------------------------------------------------------------------------
' File I/O like routines for memory loaded files
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'StringFile.bi'

' Creates a new StringFile object
' StringFile APIs are a simple way of dealing with file that are completely loaded in memory
' Since it uses a QB string as a backing buffer, no explicit memory management (i.e. freeing) is required
SUB StringFile_Create (stringFile AS StringFileType, buffer AS STRING)
    stringFile.buffer = buffer
    stringFile.cursor = 0
END SUB


' Loads a whole file from disk into a StringFile object
' This will reset the StringFile object if it was previously being used
FUNCTION StringFile_Load%% (stringFile AS StringFileType, fileName AS STRING)
    IF _FILEEXISTS(fileName) THEN
        stringFile.buffer = _READFILE$(fileName)
        stringFile.cursor = 0

        StringFile_Load = _TRUE
    END IF
END FUNCTION


' Saves a StringFile object to a file
' This does not disturb the read / write cursor
FUNCTION StringFile_Save%% (stringFile AS StringFileType, fileName AS STRING, overwrite AS _BYTE)
    IF _FILEEXISTS(fileName) AND NOT overwrite THEN EXIT FUNCTION

    _WRITEFILE fileName, stringFile.buffer

    StringFile_Save = _TRUE
END FUNCTION


' Returns true if EOF is reached
FUNCTION StringFile_IsEOF%% (stringFile AS StringFileType)
    StringFile_IsEOF = (stringFile.cursor >= LEN(stringFile.buffer))
END FUNCTION


' Get the size of the file
FUNCTION StringFile_GetSize~& (stringFile AS StringFileType)
    StringFile_GetSize = LEN(stringFile.buffer)
END FUNCTION


' Gets the current r/w cursor position
FUNCTION StringFile_GetPosition~& (stringFile AS StringFileType)
    StringFile_GetPosition = stringFile.cursor
END FUNCTION


' Seeks to a position in the file
SUB StringFile_Seek (stringFile AS StringFileType, position AS _UNSIGNED LONG)
    IF position <= LEN(stringFile.buffer) THEN ' allow seeking to EOF position
        stringFile.cursor = position
    ELSE
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
    END IF
END SUB


' Resizes the file
SUB StringFile_Resize (stringFile AS StringFileType, newSize AS _UNSIGNED LONG)
    DIM AS _UNSIGNED LONG curSize: curSize = LEN(stringFile.buffer)

    IF newSize > curSize THEN
        stringFile.buffer = stringFile.buffer + STRING$(newSize - curSize, _ASC_NUL)
    ELSEIF newSize < curSize THEN
        stringFile.buffer = LEFT$(stringFile.buffer, newSize)
        IF stringFile.cursor > newSize THEN stringFile.cursor = newSize ' reposition cursor to EOF position
    END IF
END SUB


' Reads size bytes from the file
FUNCTION StringFile_ReadString$ (stringFile AS StringFileType, size AS _UNSIGNED LONG)
    IF size > 0 THEN ' reading 0 bytes will simply do nothing
        IF stringFile.cursor < LEN(stringFile.buffer) THEN ' we'll allow partial string reads but check if we have anything to read at all
            DIM dst AS STRING: dst = MID$(stringFile.buffer, stringFile.cursor + 1, size)

            stringFile.cursor = stringFile.cursor + LEN(dst) ' increment cursor by size bytes

            StringFile_ReadString = dst
        ELSE ' not enough bytes to read
            ERROR _ERR_ILLEGAL_FUNCTION_CALL
        END IF
    END IF
END FUNCTION


' Writes a string to the file and grows the file if needed
SUB StringFile_WriteString (stringFile AS StringFileType, src AS STRING)
    DIM srcSize AS _UNSIGNED LONG: srcSize = LEN(src)

    IF srcSize > 0 THEN ' writing 0 bytes will simply do nothing
        DIM curSize AS _UNSIGNED LONG: curSize = LEN(stringFile.buffer)

        ' Grow the buffer if needed
        IF stringFile.cursor + srcSize >= curSize THEN stringFile.buffer = stringFile.buffer + STRING$(stringFile.cursor + srcSize - curSize, _ASC_NUL)

        MID$(stringFile.buffer, stringFile.cursor + 1, srcSize) = src
        stringFile.cursor = stringFile.cursor + srcSize ' this puts the cursor right after the last position written
    END IF
END SUB


' Reads a byte from the file
FUNCTION StringFile_ReadByte~%% (stringFile AS StringFileType)
    IF stringFile.cursor + _SIZE_OF_BYTE <= LEN(stringFile.buffer) THEN ' check if we really have the amount of bytes to read
        StringFile_ReadByte = ASC(stringFile.buffer, stringFile.cursor + 1) ' read the data
        stringFile.cursor = stringFile.cursor + _SIZE_OF_BYTE ' this puts the cursor right after the last position read
    ELSE ' not enough bytes to read
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
    END IF
END FUNCTION


' Write a byte to the file
SUB StringFile_WriteByte (stringFile AS StringFileType, src AS _UNSIGNED _BYTE)
    DIM curSize AS _UNSIGNED LONG: curSize = LEN(stringFile.buffer)

    ' Grow the buffer if needed
    IF stringFile.cursor + _SIZE_OF_BYTE >= curSize THEN stringFile.buffer = stringFile.buffer + STRING$(stringFile.cursor + _SIZE_OF_BYTE - curSize, _ASC_NUL)

    ASC(stringFile.buffer, stringFile.cursor + 1) = src ' write the data
    stringFile.cursor = stringFile.cursor + _SIZE_OF_BYTE ' this puts the cursor right after the last position written
END SUB


' Reads an integer from the file
FUNCTION StringFile_ReadInteger~% (stringFile AS StringFileType)
    IF stringFile.cursor + _SIZE_OF_INTEGER <= LEN(stringFile.buffer) THEN ' check if we really have the amount of bytes to read
        StringFile_ReadInteger = CVI(MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_INTEGER)) ' read the data
        stringFile.cursor = stringFile.cursor + _SIZE_OF_INTEGER ' this puts the cursor right after the last position read
    ELSE ' not enough bytes to read
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
    END IF
END FUNCTION


' Writes an integer to the file
SUB StringFile_WriteInteger (stringFile AS StringFileType, src AS _UNSIGNED INTEGER)
    DIM curSize AS _UNSIGNED LONG: curSize = LEN(stringFile.buffer)

    ' Grow the buffer if needed
    IF stringFile.cursor + _SIZE_OF_INTEGER >= curSize THEN stringFile.buffer = stringFile.buffer + STRING$(stringFile.cursor + _SIZE_OF_INTEGER - curSize, _ASC_NUL)

    MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_INTEGER) = MKI$(src) ' write the data
    stringFile.cursor = stringFile.cursor + _SIZE_OF_INTEGER ' this puts the cursor right after the last position written
END SUB


' Reads a long from the file
FUNCTION StringFile_ReadLong~& (stringFile AS StringFileType)
    IF stringFile.cursor + _SIZE_OF_LONG <= LEN(stringFile.buffer) THEN ' check if we really have the amount of bytes to read
        StringFile_ReadLong = CVL(MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_LONG)) ' read the data
        stringFile.cursor = stringFile.cursor + _SIZE_OF_LONG ' this puts the cursor right after the last position read
    ELSE ' not enough bytes to read
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
    END IF
END FUNCTION


' Writes a long to the file
SUB StringFile_WriteLong (stringFile AS StringFileType, src AS _UNSIGNED LONG)
    DIM curSize AS _UNSIGNED LONG: curSize = LEN(stringFile.buffer)

    ' Grow the buffer if needed
    IF stringFile.cursor + _SIZE_OF_LONG >= curSize THEN stringFile.buffer = stringFile.buffer + STRING$(stringFile.cursor + _SIZE_OF_LONG - curSize, _ASC_NUL)

    MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_LONG) = MKL$(src) ' write the data
    stringFile.cursor = stringFile.cursor + _SIZE_OF_LONG ' this puts the cursor right after the last position written
END SUB


' Reads a single from the file
FUNCTION StringFile_ReadSingle! (stringFile AS StringFileType)
    IF stringFile.cursor + _SIZE_OF_SINGLE <= LEN(stringFile.buffer) THEN ' check if we really have the amount of bytes to read
        StringFile_ReadSingle = CVS(MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_SINGLE)) ' read the data
        stringFile.cursor = stringFile.cursor + _SIZE_OF_SINGLE ' this puts the cursor right after the last position read
    ELSE ' not enough bytes to read
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
    END IF
END FUNCTION


' Writes a single to the file
SUB StringFile_WriteSingle (stringFile AS StringFileType, src AS SINGLE)
    DIM curSize AS _UNSIGNED LONG: curSize = LEN(stringFile.buffer)

    ' Grow the buffer if needed
    IF stringFile.cursor + _SIZE_OF_SINGLE >= curSize THEN stringFile.buffer = stringFile.buffer + STRING$(stringFile.cursor + _SIZE_OF_SINGLE - curSize, _ASC_NUL)

    MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_SINGLE) = MKS$(src) ' write the data
    stringFile.cursor = stringFile.cursor + _SIZE_OF_SINGLE ' this puts the cursor right after the last position written
END SUB


' Reads an integer64 from the file
FUNCTION StringFile_ReadInteger64~&& (stringFile AS StringFileType)
    IF stringFile.cursor + _SIZE_OF_INTEGER64 <= LEN(stringFile.buffer) THEN ' check if we really have the amount of bytes to read
        StringFile_ReadInteger64 = _CV(_UNSIGNED _INTEGER64, MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_INTEGER64)) ' read the data
        stringFile.cursor = stringFile.cursor + _SIZE_OF_INTEGER64 ' this puts the cursor right after the last position read
    ELSE ' not enough bytes to read
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
    END IF
END FUNCTION


' Writes an integer64 to the file
SUB StringFile_WriteInteger64 (stringFile AS StringFileType, src AS _UNSIGNED _INTEGER64)
    DIM curSize AS _UNSIGNED LONG: curSize = LEN(stringFile.buffer)

    ' Grow the buffer if needed
    IF stringFile.cursor + _SIZE_OF_INTEGER64 >= curSize THEN stringFile.buffer = stringFile.buffer + STRING$(stringFile.cursor + _SIZE_OF_INTEGER64 - curSize, _ASC_NUL)

    MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_INTEGER64) = _MK$(_UNSIGNED _INTEGER64, src) ' write the data
    stringFile.cursor = stringFile.cursor + _SIZE_OF_INTEGER64 ' this puts the cursor right after the last position written
END SUB


' Reads a double from the file
FUNCTION StringFile_ReadDouble# (stringFile AS StringFileType)
    IF stringFile.cursor + _SIZE_OF_DOUBLE <= LEN(stringFile.buffer) THEN ' check if we really have the amount of bytes to read
        StringFile_ReadDouble = CVD(MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_DOUBLE)) ' read the data
        stringFile.cursor = stringFile.cursor + _SIZE_OF_DOUBLE ' this puts the cursor right after the last position read
    ELSE ' not enough bytes to read
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
    END IF
END FUNCTION


' Writes a double to the file
SUB StringFile_WriteDouble (stringFile AS StringFileType, src AS DOUBLE)
    DIM curSize AS _UNSIGNED LONG: curSize = LEN(stringFile.buffer)

    ' Grow the buffer if needed
    IF stringFile.cursor + _SIZE_OF_DOUBLE >= curSize THEN stringFile.buffer = stringFile.buffer + STRING$(stringFile.cursor + _SIZE_OF_DOUBLE - curSize, _ASC_NUL)

    MID$(stringFile.buffer, stringFile.cursor + 1, _SIZE_OF_DOUBLE) = MKD$(src) ' write the data
    stringFile.cursor = stringFile.cursor + _SIZE_OF_DOUBLE ' this puts the cursor right after the last position written
END SUB
