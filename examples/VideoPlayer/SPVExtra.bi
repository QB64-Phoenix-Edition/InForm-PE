'-----------------------------------------------------------------------------------------------------------------------
' SPV frame rate add-on
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'=============================================================================
'  SPVExtra.bi  (SPV-EXTRA.BM in the original distribution)  -  FPS control for SPV-HANDLES.BM  (add-on, no edits needed)
'
'  Include it AFTER SPV-HANDLES.BM (VID-HANDLES.BM does this for you).
'
'     SPVSETFPS h&, fps#     change the playback frame rate (0 = back to the
'                            encoded rate).  Limits: 0.5 to 60.
'     SPVNOMFPS#(h&)         the nominal ("encoded") frame rate right now
'
'  This is the Change_VideoFPS feature of the old SPV-VIDS player (U / D / R
'  keys).  Audio is resampled to match, exactly like the old engine.
'=============================================================================

'$INCLUDE:'SPVHandles.bi'

DIM SHARED SPVEX_PATH(1 TO SPV_MAX_VIDEOS) AS STRING
DIM SHARED SPVEX_ORIG(1 TO SPV_MAX_VIDEOS) AS DOUBLE

FUNCTION SPVNOMFPS# (h AS LONG)
    SPVNOMFPS = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVNOMFPS = SPVX(h).FPS
END FUNCTION

SUB SPVSETFPS (h AS LONG, NewFPS AS DOUBLE)
    DIM Fps AS DOUBLE
    IF NOT SPV_VALID(h) THEN EXIT SUB
    ' remember the encoded rate the first time this video is touched
    IF SPVEX_PATH(h) <> SPVX(h).Path OR SPVEX_ORIG(h) = 0 THEN
        SPVEX_PATH(h) = SPVX(h).Path
        SPVEX_ORIG(h) = SPVX(h).FPS
    END IF
    IF NewFPS = 0 THEN Fps = SPVEX_ORIG(h) ELSE Fps = NewFPS
    IF Fps < .5 THEN Fps = .5
    IF Fps > 60 THEN Fps = 60
    IF Fps = SPVX(h).FPS THEN EXIT SUB

    SPV_LOCK = SPV_LOCK + 1
    SPVX(h).FPS = Fps
    SPVX(h).InRate = _ROUND(SPVX(h).InSamples * Fps)
    IF SPVX(h).InRate < 1 THEN SPVX(h).InRate = 1
    SPVX(h).Out32 = _ROUND(SPVX(h).InSamples * (SPV_OUT_RATE / SPVX(h).InRate))
    IF SPVX(h).Out32 < 1 THEN SPVX(h).Out32 = 1
    SPVX(h).TickSec = SPVX(h).Out32 / SPV_OUT_RATE
    SPVX(h).TrueFPS = SPV_OUT_RATE / SPVX(h).Out32
    SPVX(h).ConvFactor = SPVX(h).InRate / SPV_OUT_RATE
    SPV_LOCK = SPV_LOCK - 1
END SUB
