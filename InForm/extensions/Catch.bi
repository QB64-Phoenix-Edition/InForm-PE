'-----------------------------------------------------------------------------------------------------------------------
' Minimalistic test framework library for QB64-PE
' Copyright (c) 2026 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

$IF TEST_STRICT = DEFINED AND TEST_STRICT = TRUE THEN
    _DEFINE A-Z AS LONG
    OPTION _EXPLICITARRAY
    OPTION _EXPLICIT
$END IF

$IF TEST_CONSOLE_ONLY = DEFINED AND TEST_CONSOLE_ONLY = TRUE THEN
    $CONSOLE:ONLY
$ELSE
    $CONSOLE
$END IF

'$INCLUDE:'Time.bi'

CONST __TEST_COLOR_HEADER = 36 ' light cyan
CONST __TEST_COLOR_PASS = 32 ' light green
CONST __TEST_COLOR_FAIL = 31 ' light red
CONST __TEST_COLOR_SKIP = 33 ' yellow
CONST __TEST_COLOR_NOTE = 90 ' dark gray
CONST __TEST_COLOR_NAME = 97 ' white
CONST __TEST_COLOR_ARROW = 94 ' light blue
CONST __TEST_COLOR_KIND = 35 ' magenta
CONST __TEST_SEPARATOR_WIDTH = 79

TYPE __TestState
    testsRun AS LONG
    assertions AS LONG
    failures AS LONG
    currentTestName AS STRING
    currentTestChecks AS LONG
    currentTestFails AS LONG
    abortCurrentTest AS _BYTE
    skipCurrentTest AS _BYTE
    testStart AS _UNSIGNED _INTEGER64
    filter AS STRING
    errorHandlerEnabled AS _BYTE
    colorDisabled AS _BYTE
    exitOnEndDisabled AS _BYTE
    rngSeed AS _UNSIGNED _INTEGER64
END TYPE

DIM __TestState AS __TestState

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

''' @brief Initializes the test framework, resets counters, and prints test environment information.
SUB TEST_BEGIN_ALL
    SHARED __TestState AS __TestState

    __TestState.testsRun = 0
    __TestState.assertions = 0
    __TestState.failures = 0
    __TestState.filter = _TRIM$(COMMAND$)

    IF __TestState.rngSeed = 0 THEN
        DO
            __TestState.rngSeed = TIMER(0.001) * 1000
        LOOP UNTIL __TestState.rngSeed

        RANDOMIZE __TestState.rngSeed
    END IF

    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "OS: " + _OS$
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Date: " + DATE$
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Time: " + TIME$
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Executable: " + COMMAND$(0)
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Working directory: " + _CWD$
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Random number seed:" + STR$(__TestState.rngSeed)
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Runtime error handler: " + _IIF(__TestState.errorHandlerEnabled, "enabled", "disabled")
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Color output: " + _IIF(__TestState.colorDisabled, "disabled", "enabled")
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Auto exit: " + _IIF(__TestState.exitOnEndDisabled, "disabled", "enabled")
    __TestSetColor __TEST_COLOR_HEADER: __TestPrintLn "Catch test framework library for QB64-PE initialized"
    __TestSetColor __TEST_COLOR_NOTE: __TestPrintLn STRING$(__TEST_SEPARATOR_WIDTH, "-")

    IF LEN(__TestState.filter) THEN
        __TestSetColor __TEST_COLOR_NOTE: __TestPrintLn "Filter: " + _CHR_QUOTE + __TestState.filter + _CHR_QUOTE
    END IF

    __TestResetColor
END SUB

''' @brief Finalizes the test run, prints summary statistics, and exits with a status code.
SUB TEST_END_ALL
    SHARED __TestState AS __TestState

    __TestSetColor __TEST_COLOR_NOTE: __TestPrintLn STRING$(__TEST_SEPARATOR_WIDTH, "-")
    __TestSetColor __TEST_COLOR_NOTE: __TestPrint "Tests run :": __TestSetColor __TEST_COLOR_NAME: __TestPrintLn STR$(__TestState.testsRun)
    __TestSetColor __TEST_COLOR_NOTE: __TestPrint "Asserts   :": __TestSetColor __TEST_COLOR_NAME: __TestPrintLn STR$(__TestState.assertions)
    __TestSetColor __TEST_COLOR_NOTE: __TestPrint "Failures  :": __TestSetColor __TEST_COLOR_NAME: __TestPrintLn STR$(__TestState.failures)

    IF __TestState.failures THEN
        __TestSetColor __TEST_COLOR_FAIL: __TestPrintLn "RESULT    : FAILURE"
    ELSE
        __TestSetColor __TEST_COLOR_PASS: __TestPrintLn "RESULT    : SUCCESS"
    END IF

    __TestResetColor

    IF NOT __TestState.exitOnEndDisabled THEN
        SYSTEM __TestState.failures
    END IF
END SUB

''' @brief Starts a new test case with the specified name.
''' @param testName The descriptive name of the test case.
SUB TEST_CASE_BEGIN (testName AS STRING)
    SHARED __TestState AS __TestState

    __TestState.currentTestName = testName
    __TestState.currentTestChecks = 0
    __TestState.currentTestFails = 0
    __TestState.abortCurrentTest = _FALSE
    __TestState.skipCurrentTest = _FALSE
    __TestState.testsRun = __TestState.testsRun + 1
    __TestState.testStart = Time_GetTicks

    IF LEN(__TestState.filter) THEN
        IF INSTR(UCASE$(testName), UCASE$(__TestState.filter)) = 0 THEN
            __TestState.skipCurrentTest = _TRUE
            __TestState.abortCurrentTest = _TRUE
        END IF
    END IF

    __TestSetColor __TEST_COLOR_ARROW: __TestPrint "->": __TestResetColor: __TestPrint " "
    __TestSetColor __TEST_COLOR_NAME: __TestPrint testName
    IF __TestState.skipCurrentTest THEN
        __TestPrint " "
        __TestPrintTag "SKIP", __TEST_COLOR_SKIP
    END IF
    __TestPrintLn _STR_EMPTY

    __TestResetColor
END SUB

''' @brief Ends the current test case and prints its results and execution duration.
SUB TEST_CASE_END
    SHARED __TestState AS __TestState

    DIM durMs AS _UNSIGNED _INTEGER64: durMs = Time_GetTicks - __TestState.testStart

    __TestPrint "  "
    IF __TestState.skipCurrentTest THEN
        __TestPrintTag "SKIP", __TEST_COLOR_SKIP
        __TestSetColor __TEST_COLOR_NOTE: __TestPrintLn "(0 asserts, 0 fails," + STR$(durMs) + " ms)"
    ELSEIF __TestState.currentTestFails = 0 THEN
        __TestPrintTag "OK", __TEST_COLOR_PASS
        __TestSetColor __TEST_COLOR_NOTE: __TestPrintLn "(" + _TOSTR$(__TestState.currentTestChecks) + " asserts, 0 fails," + STR$(durMs) + " ms)"
    ELSE
        __TestPrintTag "FAIL", __TEST_COLOR_FAIL
        __TestSetColor __TEST_COLOR_NOTE: __TestPrintLn "(" + _TOSTR$(__TestState.currentTestChecks) + " asserts," + STR$(__TestState.currentTestFails) + " fails," + STR$(durMs) + " ms)"
    END IF

    __TestResetColor
END SUB

''' @brief Asserts that a condition is true; records a failure if false without aborting the test.
''' @param cond The condition expression to test.
''' @param expr The string representation of the expression being tested.
SUB TEST_CHECK (cond AS _INTEGER64, expr AS STRING)
    SHARED __TestState AS __TestState

    IF __TestState.abortCurrentTest THEN EXIT SUB

    __TestState.assertions = __TestState.assertions + 1
    __TestState.currentTestChecks = __TestState.currentTestChecks + 1

    IF cond THEN EXIT SUB

    __TestState.failures = __TestState.failures + 1
    __TestState.currentTestFails = __TestState.currentTestFails + 1
    __TestPrintFailure "TEST_CHECK", expr
END SUB

''' @brief Asserts that a condition is true without an expression label.
''' @param cond The condition expression to test.
SUB TEST_CHECK2 (cond AS _INTEGER64)
    TEST_CHECK cond, _STR_EMPTY
END SUB

''' @brief Asserts that a condition is false; records a failure if true without aborting the test.
''' @param cond The condition expression to test.
''' @param expr The string representation of the expression being tested.
SUB TEST_CHECK_FALSE (cond AS _INTEGER64, expr AS STRING)
    SHARED __TestState AS __TestState

    IF __TestState.abortCurrentTest THEN EXIT SUB

    __TestState.assertions = __TestState.assertions + 1
    __TestState.currentTestChecks = __TestState.currentTestChecks + 1

    IF _NEGATE cond THEN EXIT SUB

    __TestState.failures = __TestState.failures + 1
    __TestState.currentTestFails = __TestState.currentTestFails + 1
    __TestPrintFailure "TEST_CHECK_FALSE", expr
END SUB

''' @brief Asserts that a condition is false without an expression label.
''' @param cond The condition expression to test.
SUB TEST_CHECK_FALSE2 (cond AS _INTEGER64)
    TEST_CHECK_FALSE cond, _STR_EMPTY
END SUB

''' @brief Asserts that a condition is true; aborts the current test case immediately if false.
''' @param cond The condition expression to test.
''' @param expr The string representation of the expression being tested.
SUB TEST_REQUIRE (cond AS _INTEGER64, expr AS STRING)
    SHARED __TestState AS __TestState

    IF __TestState.abortCurrentTest THEN EXIT SUB

    __TestState.assertions = __TestState.assertions + 1
    __TestState.currentTestChecks = __TestState.currentTestChecks + 1

    IF cond THEN EXIT SUB

    __TestState.failures = __TestState.failures + 1
    __TestState.currentTestFails = __TestState.currentTestFails + 1
    __TestPrintFailure "TEST_REQUIRE", expr
    __TestState.abortCurrentTest = _TRUE
END SUB

''' @brief Asserts that a condition is true and aborts on failure without an expression label.
''' @param cond The condition expression to test.
SUB TEST_REQUIRE2 (cond AS _INTEGER64)
    TEST_REQUIRE cond, _STR_EMPTY
END SUB

''' @brief Asserts that a condition is false; aborts the current test case immediately if true.
''' @param cond The condition expression to test.
''' @param expr The string representation of the expression being tested.
SUB TEST_REQUIRE_FALSE (cond AS _INTEGER64, expr AS STRING)
    SHARED __TestState AS __TestState

    IF __TestState.abortCurrentTest THEN EXIT SUB

    __TestState.assertions = __TestState.assertions + 1
    __TestState.currentTestChecks = __TestState.currentTestChecks + 1

    IF _NEGATE cond THEN EXIT SUB

    __TestState.failures = __TestState.failures + 1
    __TestState.currentTestFails = __TestState.currentTestFails + 1
    __TestPrintFailure "TEST_REQUIRE_FALSE", expr
    __TestState.abortCurrentTest = _TRUE
END SUB

''' @brief Asserts that a condition is false and aborts on failure without an expression label.
''' @param cond The condition expression to test.
SUB TEST_REQUIRE_FALSE2 (cond AS _INTEGER64)
    TEST_REQUIRE_FALSE cond, _STR_EMPTY
END SUB

''' @brief Checks whether the current test case was aborted by a failed requirement.
''' @return _TRUE if the current test case was aborted, _FALSE otherwise.
FUNCTION TEST_ABORTED%%
    SHARED __TestState AS __TestState
    TEST_ABORTED = __TestState.abortCurrentTest
END FUNCTION

''' @brief Enables or disables ANSI color output in test reports.
''' @param enable _TRUE to enable colored output, _FALSE to disable.
SUB TEST_ENABLE_COLOR (enable AS _INTEGER64)
    SHARED __TestState AS __TestState
    __TestState.colorDisabled = (enable = _FALSE)
END SUB

''' @brief Enables or disables automatic termination of the process when TEST_END_ALL completes.
''' @param enable _TRUE to call SYSTEM/END on completion, _FALSE to return normally.
SUB TEST_ENABLE_EXIT_ON_END (enable AS _INTEGER64)
    SHARED __TestState AS __TestState
    __TestState.exitOnEndDisabled = (enable = _FALSE)
END SUB

''' @brief Sets the pseudo-random number generator seed used for the test run.
''' @param rngSeed The 64-bit seed value.
SUB TEST_SET_RNG_SEED (rngSeed AS _UNSIGNED _INTEGER64)
    SHARED __TestState AS __TestState
    __TestState.rngSeed = rngSeed
    RANDOMIZE rngSeed
END SUB

''' @brief Internal helper to set terminal foreground color via ANSI escape codes.
''' @param fg The ANSI color code number.
SUB __TestSetColor (fg AS _UNSIGNED _BYTE)
    SHARED __TestState AS __TestState
    IF NOT __TestState.colorDisabled THEN __TestPrint _CHR_ESC + "[" + _TOSTR$(fg) + "m"
END SUB

''' @brief Internal helper to reset terminal color to defaults.
SUB __TestResetColor
    SHARED __TestState AS __TestState
    IF NOT __TestState.colorDisabled THEN __TestPrint _CHR_ESC + "[0m"
END SUB

''' @brief Internal helper to print a formatted status tag enclosed in brackets.
''' @param tag The tag text to display (e.g., "OK", "FAIL", "SKIP").
''' @param fg The ANSI color code for the tag.
SUB __TestPrintTag (tag AS STRING, fg AS _UNSIGNED _BYTE)
    __TestSetColor fg: __TestPrint "[" + tag + "] "
    __TestResetColor
END SUB

''' @brief Internal helper to print a formatted assertion failure message.
''' @param kind The assertion kind (e.g., "TEST_CHECK", "TEST_REQUIRE").
''' @param expr The expression string that failed.
SUB __TestPrintFailure (kind AS STRING, expr AS STRING)
    __TestSetColor __TEST_COLOR_FAIL: __TestPrint "    "
    __TestPrintTag "FAIL", __TEST_COLOR_FAIL
    IF LEN(expr) THEN
        __TestSetColor __TEST_COLOR_KIND: __TestPrint kind + ": "
        __TestSetColor __TEST_COLOR_NAME: __TestPrintLn expr
    ELSE
        __TestSetColor __TEST_COLOR_KIND: __TestPrintLn kind
    END IF

    __TestResetColor
END SUB

''' @brief Internal helper to print a message to standard output without a newline.
''' @param message The text string to print.
SUB __TestPrint (message AS STRING)
    DECLARE LIBRARY
        SUB __TestPrintF ALIAS "::printf" (message AS STRING)
    END DECLARE

    __TestPrintF message + _CHR_NUL
END SUB

''' @brief Internal helper to print a message to standard output followed by a newline.
''' @param message The text string to print.
SUB __TestPrintLn (message AS STRING)
    DECLARE LIBRARY
        SUB __TestPutS ALIAS "::puts" (message AS STRING)
    END DECLARE

    __TestPutS message + _CHR_NUL
END SUB
