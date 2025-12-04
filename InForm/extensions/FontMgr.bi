'-----------------------------------------------------------------------------------------------------------------------
' Cross-platform TrueType / OpenType font helper library
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'Memory.bi'
'$INCLUDE:'Pathname.bi'

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
