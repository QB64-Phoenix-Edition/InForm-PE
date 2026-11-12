'-----------------------------------------------------------------------------------------------------------------------
' Cross-platform TrueType / OpenType font helper library
' Copyright (c) 2026 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'Memory.bi'
'$INCLUDE:'Pathname.bi'
'$INCLUDE:'Sort.bi'

CONST __FONTMGR_PROBE_SIZE_MIN~%% = 8~% ' minimum font height that can be reported
CONST __FONTMGR_PROBE_SIZE_MAX~%% = 120~%% ' maximum font height that can be reported
CONST __FONTMGR_PLATFORM_ID_UNI~% = 0~%
CONST __FONTMGR_PLATFORM_ID_MAC~% = 1~%
CONST __FONTMGR_PLATFORM_ID_WIN~% = 3~%
CONST __FONTMGR_LANGUAGE_ID_UNI~% = 0~% ' unicode
CONST __FONTMGR_LANGUAGE_ID_MAC~% = 0~% ' mac english
CONST __FONTMGR_LANGUAGE_ID_WIN~% = 1033~% ' Windows en-us

' Bunch of nameIDs that can be passed to FontMgr_GetName()
' Note that the font may not contain all of these
CONST FONTMGR_NAME_COPYRIGHT~%% = 0~%%
CONST FONTMGR_NAME_FAMILY~%% = 1~%%
CONST FONTMGR_NAME_STYLE~%% = 2~%%
CONST FONTMGR_NAME_UNIQUE~%% = 3~%%
CONST FONTMGR_NAME_FULL~%% = 4~%%
CONST FONTMGR_NAME_VERSION~%% = 5~%%
CONST FONTMGR_NAME_POSTSCRIPT~%% = 6~%%
CONST FONTMGR_NAME_TRADEMARK~%% = 7~%%
CONST FONTMGR_NAME_MANUFACTURER~%% = 8~%%
CONST FONTMGR_NAME_DESIGNER~%% = 9~%%
CONST FONTMGR_NAME_DESCRIPTION~%% = 10~%%
CONST FONTMGR_NAME_VENDOR_URL~%% = 11~%%
CONST FONTMGR_NAME_DESIGNER_URL~%% = 12~%%
CONST FONTMGR_NAME_LICENSE_DESCRIPTION~%% = 13~%%
CONST FONTMGR_NAME_LICENSE_INFO_URL~%% = 14~%%
CONST FONTMGR_NAME_PREFERRED_FAMILY~%% = 16~%%
CONST FONTMGR_NAME_PREFERRED_SUBFAMILY~%% = 17~%%
CONST FONTMGR_NAME_COMPATIBLE_FULL~%% = 18~%%
CONST FONTMGR_NAME_SAMPLE_TEXT~%% = 19~%%
CONST FONTMGR_NAME_POSTSCRIPT_CID~%% = 20~%%

TYPE __FontMgr_TTCHeaderType
    szTag AS STRING * 4
    uMajorVersion AS _UNSIGNED INTEGER
    uMinorVersion AS _UNSIGNED INTEGER
    uNumFonts AS _UNSIGNED LONG
END TYPE

TYPE __FontMgr_TTOffsetTableType
    uMajorVersion AS _UNSIGNED INTEGER
    uMinorVersion AS _UNSIGNED INTEGER
    uNumOfTables AS _UNSIGNED INTEGER
    uSearchRange AS _UNSIGNED INTEGER
    uEntrySelector AS _UNSIGNED INTEGER
    uRangeShift AS _UNSIGNED INTEGER
END TYPE

TYPE __FontMgr_TTTableDirectoryType
    szTag AS STRING * 4
    uCheckSum AS _UNSIGNED LONG
    uOffset AS _UNSIGNED LONG
    uLength AS _UNSIGNED LONG
END TYPE

TYPE __FontMgr_TTNameTableHeaderType
    uFSelector AS _UNSIGNED INTEGER
    uNRCount AS _UNSIGNED INTEGER
    uStorageOffset AS _UNSIGNED INTEGER
END TYPE

TYPE __FontMgr_TTNameRecordType
    uPlatformID AS _UNSIGNED INTEGER
    uEncodingID AS _UNSIGNED INTEGER
    uLanguageID AS _UNSIGNED INTEGER
    uNameID AS _UNSIGNED INTEGER
    uStringLength AS _UNSIGNED INTEGER
    uStringOffset AS _UNSIGNED INTEGER
END TYPE

''' @brief Builds an array of fonts that are available in the host OS (user installed + system installed).
''' @param fontList This is a dynamic string array. The function will re-dimension fontList starting from 1.
''' @return The count of fonts found.
FUNCTION FontMgr_BuildList~& (fontList() AS STRING)
    ' dirStack is a stack of directories that we'll need to traverse
    REDIM dirStack(1 TO 8) AS STRING
    DIM stackCount AS _UNSIGNED LONG

    ' Add the system font directory
    DIM sysFontDir AS STRING: sysFontDir = _DIR$("FONT")
    IF _DIREXISTS(sysFontDir) THEN
        stackCount = stackCount + 1
        IF stackCount > UBOUND(dirStack) THEN REDIM _PRESERVE dirStack(1 TO stackCount * 2) AS STRING
        dirStack(stackCount) = Pathname_AddDirectorySeparator(sysFontDir)
    END IF

    ' Add the user font directory if it exists and is distinct from HOME and system font directory
    DIM userFontDir AS STRING: userFontDir = _DIR$("USERFONT")
    IF _DIREXISTS(userFontDir) _ANDALSO userFontDir <> _DIR$("HOME") _ANDALSO userFontDir <> sysFontDir THEN
        stackCount = stackCount + 1
        IF stackCount > UBOUND(dirStack) THEN REDIM _PRESERVE dirStack(1 TO stackCount * 2) AS STRING
        dirStack(stackCount) = Pathname_AddDirectorySeparator(userFontDir)
    END IF

    ' This keeps the total count of fonts that we found and is returned to the caller
    DIM fontCount AS _UNSIGNED LONG

    ' Add a placeholder for the internal VGA font at index 1
    fontCount = 1
    REDIM fontList(1 TO 64) AS STRING
    fontList(1) = _STR_EMPTY

    ' Keep reading directories until the stack is exhausted
    WHILE stackCount > 0
        DIM directory AS STRING: directory = dirStack(stackCount)
        stackCount = stackCount - 1

        DIM entry AS STRING: entry = _FILES$(directory)

        DO WHILE LEN(entry) > 0
            IF entry <> PATHNAME_DIR_CURRENT _ANDALSO entry <> PATHNAME_DIR_PARENT _ANDALSO RIGHT$(entry, 1) = PATHNAME_DIR_SEPARATOR THEN
                ' If the entry is a directory, push it onto the stack
                stackCount = stackCount + 1
                IF stackCount > UBOUND(dirStack) THEN REDIM _PRESERVE dirStack(1 TO stackCount * 2) AS STRING
                dirStack(stackCount) = directory + entry
            ELSE
                SELECT CASE LCASE$(Pathname_GetFileExtension(entry))
                    ' Add the entry to the fontList() array if it is a legit font file name
                    ' TODO: .fon support is not implemented. See comments in other functions
                    CASE ".ttf", ".ttc", ".otf", ".otc", ".fnt", ".pcf", ".bdf" ' , ".fon"
                        fontCount = fontCount + 1
                        IF fontCount > UBOUND(fontList) THEN
                            REDIM _PRESERVE fontList(1 TO UBOUND(fontList) * 2) AS STRING
                        END IF
                        fontList(fontCount) = directory + entry
                END SELECT
            END IF

            entry = _FILES$
        LOOP
    WEND

    ' Shrink fontList to exact size found
    REDIM _PRESERVE fontList(1 TO fontCount) AS STRING

    ' Sort the array (index 1 empty VGA font remains at index 1)
    IF fontCount > 1 THEN Sort_StringArray fontList()

    FontMgr_BuildList = fontCount
END FUNCTION

''' @brief Returns the font name by directly probing a TrueType / OpenType font file.
''' Adapted from https://www.codeproject.com/articles/2293/retrieving-font-name-from-ttf-file.
''' QB64-PE port, TTC/OTC support, and OpenType OTTO support by a740g.
''' Note that this has just enough code to fetch font names and is by no means a complete TTF / OTF parser.
''' @param filePath The font file path name.
''' @param fontIndex The font index inside a TTC/OTC collection (zero-based). Must be 0 for TTF & OTF.
''' @param nameId The component needed from the font's name table.
''' @return The name of the font. An invalid filePath or fontIndex will return an empty string.
FUNCTION FontMgr_GetName$ (filePath AS STRING, fontIndex AS _UNSIGNED LONG, nameId AS _UNSIGNED _BYTE)
    IF LEN(filePath) = 0 _ANDALSO fontIndex = 0 THEN
        ' VGA font special-case
        FontMgr_GetName = "Built-in VGA font"
        EXIT FUNCTION
    END IF

    IF NOT _FILEEXISTS(filePath) THEN EXIT FUNCTION

    ' Check for non-ttf/otf fonts and return file name without extension
    SELECT CASE LCASE$(Pathname_GetFileExtension(filePath))
        ' TODO: .fon support is not implemented. See comments in other functions
        CASE ".fnt", ".pcf", ".bdf" ', ".fon"
            IF fontIndex = 0 THEN
                SELECT CASE nameId
                    CASE FONTMGR_NAME_FAMILY, FONTMGR_NAME_FULL, FONTMGR_NAME_PREFERRED_FAMILY, FONTMGR_NAME_COMPATIBLE_FULL
                        FontMgr_GetName = Pathname_RemoveFileExtension(Pathname_GetFileName(filePath))
                END SELECT
            END IF
            EXIT FUNCTION
    END SELECT

    DIM f AS LONG: f = FREEFILE
    OPEN filePath FOR BINARY ACCESS READ AS f

    IF LOF(f) < 12 THEN
        CLOSE f
        EXIT FUNCTION
    END IF

    ' Attempt to read TTC/OTC header
    DIM ttcHeader AS __FontMgr_TTCHeaderType
    GET f, 1, ttcHeader

    DIM fontBaseOffset AS _UNSIGNED LONG
    IF ttcHeader.szTag = "ttcf" THEN ' TTC / OTC format
        ttcHeader.uNumFonts = Memory_SwapByte32(ttcHeader.uNumFonts)

        IF fontIndex >= ttcHeader.uNumFonts THEN
            CLOSE f
            EXIT FUNCTION ' out of range
        END IF

        GET f, 1 + LEN(ttcHeader) + (fontIndex * _SIZE_OF_LONG), fontBaseOffset
        fontBaseOffset = Memory_SwapByte32(fontBaseOffset)
    ELSEIF fontIndex > 0 THEN
        CLOSE f
        EXIT FUNCTION ' not a collection, non-zero fontIndex is invalid
    END IF

    SEEK f, 1 + fontBaseOffset

    ' Read the table directory header
    DIM ttOffsetTable AS __FontMgr_TTOffsetTableType
    GET f, , ttOffsetTable
    ttOffsetTable.uMajorVersion = Memory_SwapByte16(ttOffsetTable.uMajorVersion)
    ttOffsetTable.uMinorVersion = Memory_SwapByte16(ttOffsetTable.uMinorVersion)

    ' Check if this is a supported TrueType / OpenType font:
    ' 0x00010000 = TrueType 1.0
    ' 0x4F54544F = OpenType with CFF outlines ("OTTO")
    ' 0x74727565 = Apple TrueType ("true")
    ' 0x74797031 = Type 1 in sfnt wrapper ("typ1")
    DIM isSupportedFont AS _BYTE
    IF ttOffsetTable.uMajorVersion = 1 _ANDALSO ttOffsetTable.uMinorVersion = 0 THEN
        isSupportedFont = _TRUE
    ELSEIF ttOffsetTable.uMajorVersion = &H4F54 _ANDALSO ttOffsetTable.uMinorVersion = &H544F THEN
        isSupportedFont = _TRUE
    ELSEIF ttOffsetTable.uMajorVersion = &H7472 _ANDALSO ttOffsetTable.uMinorVersion = &H7565 THEN
        isSupportedFont = _TRUE
    ELSEIF ttOffsetTable.uMajorVersion = &H7479 _ANDALSO ttOffsetTable.uMinorVersion = &H7031 THEN
        isSupportedFont = _TRUE
    END IF

    IF NOT isSupportedFont THEN
        CLOSE f
        EXIT FUNCTION
    END IF

    ttOffsetTable.uNumOfTables = Memory_SwapByte16(ttOffsetTable.uNumOfTables)

    ' Locate the "name" table in the table directory
    DIM tblDir AS __FontMgr_TTTableDirectoryType
    DIM hasNameTable AS _BYTE
    DIM i AS _UNSIGNED LONG
    FOR i = 1 TO ttOffsetTable.uNumOfTables
        GET f, , tblDir
        IF tblDir.szTag = "name" THEN
            tblDir.uLength = Memory_SwapByte32(tblDir.uLength)
            tblDir.uOffset = Memory_SwapByte32(tblDir.uOffset)
            hasNameTable = _TRUE
            EXIT FOR
        END IF
    NEXT i

    IF NOT hasNameTable THEN
        CLOSE f
        EXIT FUNCTION
    END IF

    ' Read the name table header
    DIM ttNTHeader AS __FontMgr_TTNameTableHeaderType
    GET f, 1 + tblDir.uOffset, ttNTHeader
    ttNTHeader.uNRCount = Memory_SwapByte16(ttNTHeader.uNRCount)
    ttNTHeader.uStorageOffset = Memory_SwapByte16(ttNTHeader.uStorageOffset)

    DIM nameBuffer AS STRING
    DIM fallbackOffset AS _UNSIGNED LONG
    DIM fallbackLength AS _UNSIGNED INTEGER

    DIM j AS _UNSIGNED LONG
    FOR j = 1 TO ttNTHeader.uNRCount
        DIM ttRecord AS __FontMgr_TTNameRecordType
        GET f, , ttRecord
        ttRecord.uNameID = Memory_SwapByte16(ttRecord.uNameID)
        ttRecord.uLanguageID = Memory_SwapByte16(ttRecord.uLanguageID)
        ttRecord.uPlatformID = Memory_SwapByte16(ttRecord.uPlatformID)

        IF ttRecord.uNameID = nameId THEN
            ttRecord.uStringLength = Memory_SwapByte16(ttRecord.uStringLength)
            ttRecord.uStringOffset = Memory_SwapByte16(ttRecord.uStringOffset)

            IF ttRecord.uStringLength > 0 THEN
                ' Check for exact preferred language match (Unicode/Mac English/Windows US English)
                IF (ttRecord.uPlatformID = __FONTMGR_PLATFORM_ID_UNI _ANDALSO ttRecord.uLanguageID = __FONTMGR_LANGUAGE_ID_UNI) _
                    _ORELSE (ttRecord.uPlatformID = __FONTMGR_PLATFORM_ID_MAC _ANDALSO ttRecord.uLanguageID = __FONTMGR_LANGUAGE_ID_MAC) _
                    _ORELSE (ttRecord.uPlatformID = __FONTMGR_PLATFORM_ID_WIN _ANDALSO ttRecord.uLanguageID = __FONTMGR_LANGUAGE_ID_WIN) THEN
                    nameBuffer = SPACE$(ttRecord.uStringLength)
                    GET f, 1 + tblDir.uOffset + ttRecord.uStringOffset + ttNTHeader.uStorageOffset, nameBuffer
                    EXIT FOR
                ELSEIF fallbackLength = 0 THEN
                    ' Keep the first candidate matching nameId as fallback if no preferred language match is found
                    fallbackOffset = ttRecord.uStringOffset
                    fallbackLength = ttRecord.uStringLength
                END IF
            END IF
        END IF
    NEXT j

    ' If no preferred language record was matched, use fallback candidate
    IF LEN(nameBuffer) = 0 _ANDALSO fallbackLength > 0 THEN
        nameBuffer = SPACE$(fallbackLength)
        GET f, 1 + tblDir.uOffset + fallbackOffset + ttNTHeader.uStorageOffset, nameBuffer
    END IF

    CLOSE f

    ' Get rid of null characters if the name is in UTF-16BE / unicode format
    DIM sanitizedName AS STRING
    FOR i = 1 TO LEN(nameBuffer)
        DIM char AS _UNSIGNED _BYTE: char = ASC(nameBuffer, i)
        IF char > 0 THEN sanitizedName = sanitizedName + CHR$(char)
    NEXT

    FontMgr_GetName = _TRIM$(sanitizedName)
END FUNCTION

''' @brief Returns the number of fonts in a font file or collection (TTC/OTC).
''' @param filePath The font file path name.
''' @return 1 or more for valid font files. 0 for invalid font files.
FUNCTION FontMgr_GetCount~& (filePath AS STRING)
    IF LEN(filePath) = 0 THEN
        ' VGA font special-case
        FontMgr_GetCount = 1
        EXIT FUNCTION
    END IF

    IF NOT _FILEEXISTS(filePath) THEN EXIT FUNCTION

    ' Bitmap fonts contain a single font face
    DIM extension AS STRING: extension = LCASE$(Pathname_GetFileExtension(filePath))
    SELECT CASE extension
        ' TODO: .fon files are multi-font resource files and should be handled correctly
        CASE ".fnt", ".pcf", ".bdf" ', ".fon"
            FontMgr_GetCount = 1
            EXIT FUNCTION
    END SELECT

    DIM f AS LONG: f = FREEFILE
    OPEN filePath FOR BINARY ACCESS READ AS f

    IF LOF(f) < 12 THEN
        CLOSE f
        EXIT FUNCTION
    END IF

    DIM ttcHeader AS __FontMgr_TTCHeaderType
    GET f, 1, ttcHeader

    IF ttcHeader.szTag = "ttcf" THEN ' TTC / OTC format
        FontMgr_GetCount = Memory_SwapByte32(ttcHeader.uNumFonts)
        CLOSE f
        EXIT FUNCTION
    END IF

    SEEK f, 1

    DIM ttOffsetTable AS __FontMgr_TTOffsetTableType
    GET f, , ttOffsetTable
    ttOffsetTable.uMajorVersion = Memory_SwapByte16(ttOffsetTable.uMajorVersion)
    ttOffsetTable.uMinorVersion = Memory_SwapByte16(ttOffsetTable.uMinorVersion)

    ' Verify valid TrueType / OpenType header:
    ' 0x00010000 = TrueType 1.0
    ' 0x4F54544F = OpenType with CFF outlines ("OTTO")
    ' 0x74727565 = Apple TrueType ("true")
    ' 0x74797031 = Type 1 in sfnt wrapper ("typ1")
    IF (ttOffsetTable.uMajorVersion = 1 _ANDALSO ttOffsetTable.uMinorVersion = 0) _
        _ORELSE (ttOffsetTable.uMajorVersion = &H4F54 _ANDALSO ttOffsetTable.uMinorVersion = &H544F) _
        _ORELSE (ttOffsetTable.uMajorVersion = &H7472 _ANDALSO ttOffsetTable.uMinorVersion = &H7565) _
        _ORELSE (ttOffsetTable.uMajorVersion = &H7479 _ANDALSO ttOffsetTable.uMinorVersion = &H7031) THEN
        FontMgr_GetCount = 1
    END IF

    CLOSE f
END FUNCTION

''' @brief Probes and returns the supported font size range (useful for bitmap fonts).
''' @param filePath The font file path name.
''' @param fontIndex The font index inside a TTC/OTC collection (zero-based). Must be 0 for TTF & OTF.
''' @param outMinSize [OUT] The minimum size supported by the font.
''' @param outMaxSize [OUT] The maximum size supported by the font.
''' @return True if a valid size range was probed.
FUNCTION FontMgr_GetSizeRange%% (filePath AS STRING, fontIndex AS _UNSIGNED LONG, outMinSize AS _UNSIGNED _BYTE, outMaxSize AS _UNSIGNED _BYTE)
    IF LEN(filePath) = 0 _ANDALSO fontIndex = 0 THEN
        ' VGA font special-case
        ' This is not really a range and the caller is expected to do special handling for the internal VGA font
        outMinSize = __FONTMGR_PROBE_SIZE_MIN
        outMaxSize = 16

        FontMgr_GetSizeRange = _TRUE
    ELSEIF _FILEEXISTS(filePath) THEN
        ' Scalable fonts support arbitrary sizes; return the full probe range directly
        SELECT CASE LCASE$(Pathname_GetFileExtension(filePath))
            CASE ".ttf", ".ttc", ".otf", ".otc"
                outMinSize = __FONTMGR_PROBE_SIZE_MIN
                outMaxSize = __FONTMGR_PROBE_SIZE_MAX

                FontMgr_GetSizeRange = _TRUE
                EXIT FUNCTION
        END SELECT

        DIM AS _UNSIGNED _BYTE minSize, maxSize
        minSize = __FONTMGR_PROBE_SIZE_MAX + 1 ' set this to an impossible positive value

        DIM i AS LONG
        ' I've seen some crazy short bitmap fonts. So, we'll go with 3 here
        FOR i = 3 TO __FONTMGR_PROBE_SIZE_MAX
            ' Attempt to load the font
            DIM fontHandle AS LONG: fontHandle = _LOADFONT(filePath, i, , fontIndex)

            IF fontHandle > 0 THEN
                ' Record the min and max sizes if the font loaded successfully
                IF minSize > i THEN minSize = i
                IF maxSize < i THEN maxSize = i

                _FREEFONT fontHandle ' free the font
            END IF
        NEXT i

        IF minSize <= maxSize THEN
            ' Only signal success if at least one font size was successfully probed
            outMinSize = minSize
            outMaxSize = maxSize

            FontMgr_GetSizeRange = _TRUE
        END IF
    END IF
END FUNCTION
