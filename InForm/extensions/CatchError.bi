' ==============================================================================
' Minimalistic test framework library for QB64-PE
' Copyright (c) 2025, Samuel Gomes
' ==============================================================================

$INCLUDEONCE

ON ERROR GOTO __catch_error_handler

__catch_error_handler:
IF __TestState.errorHandlerEnabled THEN
    DIM __errorLine AS LONG: __errorLine = _INCLERRORLINE

    DIM __errorFile AS STRING

    IF __errorLine THEN
        __errorFile = _INCLERRORFILE$
    ELSE
        __errorLine = _ERRORLINE
        IF NOT __errorLine THEN __errorLine = ERL

        __errorFile = _INCLERRORFILE$
        IF NOT LEN(__errorFile) THEN __errorFile = "main module"
    END IF

    __TestSetColor __TEST_COLOR_FAIL: __TestPrintLn "Runtime error" + STR$(ERR) + " on line" + STR$(__errorLine) + " in " + __errorFile
    SYSTEM 1
ELSE
    __TestState.errorHandlerEnabled = _TRUE
END IF
