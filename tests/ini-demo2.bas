OPTION _EXPLICIT

'$INCLUDE:'../InForm/extensions/Ini.bi'

'INI Manager - demo 2
'
'syntax: var$ = ReadSetting(file$, "", "")
'
'You can read all keys/values from an .ini file by calling
'ReadSetting with empty section$ and key$ values.
'----------------------------------------------------------------

COLOR 9
PRINT "Fetch every key/value pair in the file:"
DO
    DIM a$: a$ = Ini_ReadSetting("test.ini", "", "")

    IF Ini_GetCode = 1 THEN PRINT Ini_GetInfo: END 'IniCODE = 1 -> File not found
    IF Ini_GetCode = 10 THEN EXIT DO 'IniCODE = 10 -> No more keys found

    COLOR 7
    PRINT Ini_GetLastSection;
    COLOR 15: PRINT Ini_GetLastKey;
    COLOR 4: PRINT "=";
    COLOR 2: PRINT a$
LOOP
COLOR 9
PRINT "End of file."

'----------------------------------------------------------------
'syntax: var$ = ReadSetting(file$, "[section]", "")
'
'You can read all keys/values from a specific section by calling
'ReadSetting with an empty key$ value.
'----------------------------------------------------------------
PRINT
COLOR 9
PRINT "Fetch only section [contact]:"
DO
    a$ = Ini_ReadSetting("test.ini", "contact", "")

    IF Ini_GetCode = 1 THEN PRINT Ini_GetInfo: END 'IniCODE = 1 -> File not found
    IF Ini_GetCode = 10 THEN EXIT DO 'IniCODE = 10 -> No more keys found
    IF Ini_GetCode = 14 THEN PRINT Ini_GetInfo: END 'IniCODE = 14 -> Section not found

    COLOR 7
    PRINT Ini_GetLastSection;
    COLOR 15: PRINT Ini_GetLastKey;
    COLOR 4: PRINT "=";
    COLOR 2: PRINT a$
LOOP
COLOR 9
PRINT "End of section."


'$INCLUDE:'../InForm/extensions/Ini.bm'
