'-----------------------------------------------------------------------------------------------------------------------
' SPV frame rate add-on
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$IncludeOnce
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

Dim Shared SPVEX_PATH(1 To SPV_MAX_VIDEOS) As String
Dim Shared SPVEX_ORIG(1 To SPV_MAX_VIDEOS) As Double

Function SPVNOMFPS# (h As Long)
    SPVNOMFPS = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVNOMFPS = SPVX(h).FPS
End Function

Sub SPVSETFPS (h As Long, NewFPS As Double)
    Dim Fps As Double
    If Not SPV_VALID(h) Then Exit Sub
    ' remember the encoded rate the first time this video is touched
    If SPVEX_PATH(h) <> SPVX(h).Path Or SPVEX_ORIG(h) = 0 Then
        SPVEX_PATH(h) = SPVX(h).Path
        SPVEX_ORIG(h) = SPVX(h).FPS
    End If
    If NewFPS = 0 Then Fps = SPVEX_ORIG(h) Else Fps = NewFPS
    If Fps < .5 Then Fps = .5
    If Fps > 60 Then Fps = 60
    If Fps = SPVX(h).FPS Then Exit Sub

    SPV_LOCK = SPV_LOCK + 1
    SPVX(h).FPS = Fps
    SPVX(h).InRate = _Round(SPVX(h).InSamples * Fps)
    If SPVX(h).InRate < 1 Then SPVX(h).InRate = 1
    SPVX(h).Out32 = _Round(SPVX(h).InSamples * (SPV_OUT_RATE / SPVX(h).InRate))
    If SPVX(h).Out32 < 1 Then SPVX(h).Out32 = 1
    SPVX(h).TickSec = SPVX(h).Out32 / SPV_OUT_RATE
    SPVX(h).TrueFPS = SPV_OUT_RATE / SPVX(h).Out32
    SPVX(h).ConvFactor = SPVX(h).InRate / SPV_OUT_RATE
    SPV_LOCK = SPV_LOCK - 1
End Sub
