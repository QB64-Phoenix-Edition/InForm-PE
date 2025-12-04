'-----------------------------------------------------------------------------------------------------------------------
' INI Manager
' Copyright (c) 2025 Samuel Gomes
' Copyright (c) 2022 Fellippe Heitor
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

' INI operation result codes
CONST INI_INFO_SUCCESS& = 0
CONST INI_INFO_FILE_NOT_FOUND& = 1
CONST INI_INFO_EMPTY_VALUE& = 2
CONST INI_INFO_KEY_NOT_FOUND& = 3
CONST INI_INFO_KEY_UPDATED& = 4
CONST INI_INFO_GLOBAL_KEY_CREATED& = 5
CONST INI_INFO_KEY_CREATED_EXISTING_SECTION& = 7
CONST INI_INFO_NO_CHANGE_SAME_VALUE& = 8
CONST INI_INFO_NEW_SECTION_KEY_CREATED& = 9
CONST INI_INFO_NO_MORE_KEYS& = 10
CONST INI_INFO_FILE_CREATED_KEY_ADDED& = 11
CONST INI_INFO_INVALID_KEY& = 12
CONST INI_INFO_SECTION_DELETED& = 13
CONST INI_INFO_SECTION_NOT_FOUND& = 14
CONST INI_INFO_INVALID_SECTION& = 15
CONST INI_INFO_NEW_SECTION_KEY_MOVED& = 16
CONST INI_INFO_EMPTY_FILE& = 17
CONST INI_INFO_NO_FILE_OPEN& = 18
CONST INI_INFO_KEY_DELETED& = 19
CONST INI_INFO_KEY_MOVED& = 20
CONST INI_INFO_INVALID_FILENAME& = 21
CONST INI_INFO_SECTION_SORTED& = 22
CONST INI_INFO_SECTION_ALREADY_SORTED& = 23
CONST INI_INFO_NO_MORE_SECTIONS& = 24

TYPE __IniType
    loadedFiles AS STRING
    currentFileName AS STRING
    currentFileLOF AS _UNSIGNED LONG
    wholeFile AS STRING
    sectionData AS STRING
    position AS _UNSIGNED LONG
    newFile AS STRING
    lastSection AS STRING
    lastKey AS STRING
    LF AS STRING ' new-line sequence
    disableAutoCommit AS _BYTE
    code AS LONG
    forceReload AS _BYTE
END TYPE

' Global variables declaration
DIM __ini AS __IniType
