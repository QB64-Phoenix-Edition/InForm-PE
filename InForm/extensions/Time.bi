'-----------------------------------------------------------------------------------------------------------------------
' Time related routines
' Copyright (c) 2025 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

DECLARE LIBRARY
    ''' @brief Retrieves the number of ticks since the application started.
    ''' @return Number of ticks (1000 ticks = 1 second) as a 64-bit integer.
    FUNCTION Time_GetTicks~&& ALIAS "GetTicks"
END DECLARE
