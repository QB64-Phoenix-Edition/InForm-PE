'-----------------------------------------------------------------------------------------------------------------------
' Minimalistic test framework library for QB64-PE
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

ON ERROR GOTO __catch_error_handler

__catch_error_handler:
IF __TestState.errorHandlerEnabled THEN
    DIM __errorLine AS _UNSIGNED _INTEGER64: __errorLine = _INCLERRORLINE
    DIM __errorFile AS STRING

    IF __errorLine THEN
        __errorFile = _INCLERRORFILE$
    ELSE
        __errorLine = _ERRORLINE
        IF __errorLine = 0 THEN __errorLine = ERL

        __errorFile = _INCLERRORFILE$
        IF LEN(__errorFile) = 0 THEN __errorFile = "main module"
    END IF

    __TestSetColor __TEST_COLOR_FAIL: __TestPrintLn "Runtime error" + STR$(ERR) + " (" + LCASE$(_ERRORMESSAGE$) + ") on line" + STR$(__errorLine) + " in " + __errorFile

    __TestResetColor

    IF __TestState.exitOnEndDisabled THEN
        END _MAX(__TestState.failures + 1, 1)
    ELSE
        SYSTEM _MAX(__TestState.failures + 1, 1)
    END IF
ELSE
    __TestState.errorHandlerEnabled = _TRUE
END IF
