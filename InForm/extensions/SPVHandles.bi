'-----------------------------------------------------------------------------------------------------------------------
' SPV video library
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$IncludeOnce
'=============================================================================
'  SPVHandles.bi  (SPV-HANDLES.BM in the original distribution)
'
'  Handle based SPV video library, modeled on _SNDOPEN / _SNDPLAY.
'  Ported from SPV-VIDS.QLB.  Supports MJPG (VTYPE 99) and the legacy
'  sprite / bitmap / VGA / ModeX types.
'
'  This library never touches the screen, the keyboard or _DEST.  Your program
'  owns the screen; the library keeps one image per video up to date and you
'  draw it yourself with _PUTIMAGE.
'
'  ---------------------------------------------------------------------------
'  QB64 sound command          SPV equivalent
'  ---------------------------------------------------------------------------
'  h& = _SNDOPEN(file$)        h& = SPVOPEN(file$)          (0 = failure)
'  _SNDPLAY h&                 SPVPLAY h&
'  _SNDLOOP h&                 SPVLOOP h&
'  _SNDPAUSE h&                SPVPAUSE h&
'  _SNDSTOP h&                 SPVSTOP h&                   (rewinds to start)
'  _SNDPLAYING(h&)             SPVPLAYING(h&)
'  _SNDPAUSED(h&)              SPVPAUSED(h&)
'  _SNDLEN(h&)                 SPVLEN(h&)                   (seconds)
'  _SNDGETPOS(h&)              SPVGETPOS(h&)                (seconds)
'  _SNDSETPOS h&, secs!        SPVSETPOS h&, secs!
'  _SNDVOL h&, v!              SPVVOL h&, v!                (0 to 1)
'  _SNDLIMIT h&, secs!         SPVLIMIT h&, secs!           (0 = no limit)
'  _SNDCLOSE h&                SPVCLOSE h&
'
'  Video only additions:
'    SPVIMAGE&(h&)      image handle holding the current frame
'    SPVNEWFRAME%(h&)   true once each time a new frame has been drawn
'    SPVWIDTH&(h&)  SPVHEIGHT&(h&)  SPVFPS#(h&)  SPVFRAMES&(h&)  SPVFRAME&(h&)
'    SPVERROR$          text of the last SPVOPEN failure
'    SPVCLOSEALL        close every open video
'    SPVTICK            the ON TIMER handler (see below)
'
'  Handles are LONG.  Use h& or DIM h AS LONG.  Seconds / volume are SINGLE.
'
'  ---------------------------------------------------------------------------
'  REQUIRED: the timer
'  ---------------------------------------------------------------------------
'  Playback is driven by SPVTICK.  Put these two lines in your MAIN program
'  once, before opening a video:
'
'       ON TIMER(1, SPV_TICK_SECONDS) SPVTICK
'       TIMER(1) ON
'
'  (If your QB64 version only accepts a label there, use:
'       ON TIMER(1, SPV_TICK_SECONDS) GOSUB SPVTICKLABEL
'   and in the main program:  SPVTICKLABEL: SPVTICK: RETURN  )
'
'  Frames are paced by the audio queue, exactly like SPV-VIDS: each tick the
'  library checks how much audio is queued per video and, when it runs low,
'  decodes and queues the next frame.  Do not block the main program for long
'  periods (INPUT, long _DELAY) or the audio will underrun.
'
'  ---------------------------------------------------------------------------
'  Minimal example
'  ---------------------------------------------------------------------------
'       '$INCLUDE:'SPV-HANDLES.BM'
'       DIM v AS LONG
'       SCREEN _NEWIMAGE(800, 600, 32)
'       ON TIMER(1, SPV_TICK_SECONDS) SPVTICK
'       TIMER(1) ON
'       v = SPVOPEN("movie.spv")
'       IF v = 0 THEN PRINT SPVERROR$: END
'       SPVLOOP v
'       DO
'           _PUTIMAGE , SPVIMAGE(v)
'           _DISPLAY
'           _LIMIT 120
'       LOOP UNTIL INKEY$ = CHR$(27)
'       SPVCLOSE v
'=============================================================================

Const SPV_MAX_VIDEOS = 16
Const SPV_TICK_SECONDS = 0.01

Const SPV_STOPPED = 0
Const SPV_PLAYING = 1
Const SPV_PAUSED = 2

Const SPV_PCM8_TOFLOAT = 1! / 128!
Const SPV_PCM16_TOFLOAT = 1! / 32768!

Type SPVH_HEADER
    ID As String * 4
    VTYPE As _Unsigned _Byte
    BPP As _Unsigned _Byte
    FPS As _Unsigned _Byte
    SpriteWidth As _Unsigned _Byte
    SpriteHeight As _Unsigned _Byte
    FrameWidth As _Unsigned Integer
    FrameHeight As _Unsigned Integer
    NumFrames As _Unsigned Long
    HINT As String * 1
    VeraRATE As _Unsigned _Byte
    AudFrmSize As _Unsigned Integer
    XAUD_FLAG As String * 1
    XAUD_BYTE As _Unsigned _Byte
    F_FPS As _Unsigned Integer
    EXTRA As String * 6
    PALTAG As String * 1
End Type

Type SPVH_JHDR
    ID As String * 2
    SIZE As Long
End Type

Type SPVH_VPAL
    GB As _Unsigned _Byte
    R As _Unsigned _Byte
End Type

Type SPVH_ST8
    L As _Byte
    R As _Byte
End Type

Type SPVH_ST16
    L As Integer
    R As Integer
End Type

Type SPVH_SLOT
    InUse As Integer
    Path As String
    VFN As Integer
    AFN As Integer
    Hdr As SPVH_HEADER
    VType As Integer
    IsMJPG As Integer
    IsVGA As Integer
    IsModeX As Integer
    Full24 As Integer
    WidePal As Integer
    ExactRate As Integer
    IsSprite As Integer
    AudioSep As Integer
    Padded As Integer
    HasPal As Integer
    Is16 As Integer
    IsStereo As Integer
    Channels As Integer
    BPP As Integer
    FrameW As Long
    FrameH As Long
    SprW As Long
    SprH As Long
    PixUpper As Long
    SprPixSize As Long
    VidFrameSize As Long
    VidBufSize As Long
    QSize As Long
    PalSize As Long
    PalUpper As Long
    AudFrameSize As Long
    TotalFrameBytes As _Integer64
    FPS As Double
    InRate As _Unsigned Long
    InSamples As Long
    Out32 As Long
    ConvFactor As Double
    TickSec As Double
    TrueFPS As Double
    NumFrames As Long
    NoLead0 As Integer
    NoLead As Integer
    V1Idx As Long
    VReadIdx As Long
    FrameIdx As Long
    JIdxCount As Long
    JIdxBuilt As Integer
    JImg1 As Long
    JImg2 As Long
    Img As Long
    SprImg As Long
    SndH As Long
    State As Integer
    Finished As Integer
    Looping As Integer
    LimitSec As Double
    Volume As Single
    NewFrame As Integer
End Type

Dim Shared SPVX(1 To SPV_MAX_VIDEOS) As SPVH_SLOT
Dim Shared SPV_BLANK As SPVH_SLOT
Dim Shared SPV_HDRTMP As SPVH_HEADER
Dim Shared SPV_JHDR As SPVH_JHDR
Dim Shared SPV_LOCK As Integer
Dim Shared SPV_OUT_RATE As Long
Dim Shared SPV_LEAD_FRAMES As Single ' audio look-ahead, in frames (default 1.25)
Dim Shared SPV_ERRMSG As String

Dim Shared SPV_A1(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_A2(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_V1(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_V2(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_P1(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_P2(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_FMEM(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_SPRMEM(1 To SPV_MAX_VIDEOS) As _MEM
Dim Shared SPV_JIDX(1 To SPV_MAX_VIDEOS) As _MEM

' Shared scratch arrays.  They are only used inside one library call at a time
' (SPV_LOCK guarantees the timer can not interleave with them).
ReDim Shared SPV_PCM8_1(0 To 2) As _Byte
ReDim Shared SPV_PCM8_2(0 To 2) As _Byte
ReDim Shared SPV_PCM16_1(0 To 2) As Integer
ReDim Shared SPV_PCM16_2(0 To 2) As Integer
ReDim Shared SPV_ST8_1(0 To 2) As SPVH_ST8
ReDim Shared SPV_ST8_2(0 To 2) As SPVH_ST8
ReDim Shared SPV_ST16_1(0 To 2) As SPVH_ST16
ReDim Shared SPV_ST16_2(0 To 2) As SPVH_ST16
ReDim Shared SPV_PCM32(0 To 2) As Single
ReDim Shared SPV_AIO(0 To 2) As _Unsigned _Byte
ReDim Shared SPV_VIO(0 To 2) As _Unsigned _Byte
ReDim Shared SPV_PIO(0 To 2) As _Unsigned _Byte
ReDim Shared SPV_VWORK(0 To 2) As _Unsigned _Byte
ReDim Shared SPV_QB1(0 To 2) As _Unsigned _Byte
ReDim Shared SPV_QB2(0 To 2) As _Unsigned _Byte
ReDim Shared SPV_QB3(0 To 2) As _Unsigned _Byte
ReDim Shared SPV_QB4(0 To 2) As _Unsigned _Byte

Dim Shared SPV_VPAL_DEF(0 To 255) As SPVH_VPAL
Dim Shared SPV_VPAL_GRAY(0 To 15) As SPVH_VPAL

Dim SPVH_K As Long

SPV_OUT_RATE = _SndRate
SPV_LEAD_FRAMES = 1.25
SPV_ERRMSG = ""

SPVH_DATA_DEFAULT:
Data 0,0,255,15,0,8,254,10,76,12,197,0,10,0,231,14,133,13,64,6,119,15,51,3,119,7,246,10,143,0,187,11,0,0,17,1,34,2,51,3,68,4,85,5,102,6,119,7,136,8,153,9,170,10,187,11,204,12,221,13,238
Data 14,255,15,17,2,51,4,68,6,102,8,136,10,153,12,187,15,17,2,34,4,51,6,68,8,85,10,102,12,119,15,0,2,17,4,17,6,34,8,34,10,51,12,51,15,0,2,0,4,0,6,0,8,0,10,0,12,0,15,33,2,67,4,100,6,134,8
Data 168,10,201,12,235,15,17,2,50,4,83,6,116,8,149,10,182,12,215,15,16,2,49,4,81,6,98,8,130,10,163,12,195,15,16,2,48,4,64,6,96,8,128,10,144,12,176,15,33,1,67,3,100,5,134,7,168,9,201,11,251
Data 13,33,1,66,3,99,4,132,6,165,8,198,9,247,11,32,1,65,2,97,4,130,5,162,6,195,8,243,9,32,1,64,2,96,3,128,4,160,5,192,6,240,7,33,1,67,3,101,4,134,6,168,8,202,9,252,11,33,1,66,2,100,3,133
Data 4,166,5,200,6,249,7,32,0,65,1,98,1,131,2,164,2,197,3,246,3,32,0,65,0,97,0,130,0,162,0,195,0,243,0,34,1,68,3,102,4,136,6,170,8,204,9,255,11,34,1,68,2,102,3,136,4,170,5,204,6,255,7,34
Data 0,68,1,102,1,136,2,170,2,204,3,255,3,34,0,68,0,102,0,136,0,170,0,204,0,255,0,18,1,52,3,86,4,104,6,138,8,172,9,207,11,18,1,36,2,70,3,88,4,106,5,140,6,159,7,2,0,20,1,38,1,56,2,74,2,92
Data 3,111,3,2,0,20,0,22,0,40,0,42,0,60,0,63,0,18,1,52,3,70,5,104,7,138,9,156,11,191,13,18,1,36,3,54,4,72,6,90,8,108,9,127,11,2,1,20,2,22,4,40,5,42,6,60,8,63,9,2,1,4,2,6,3,8,4,10,5,12,6
Data 15,7,18,2,52,4,70,6,104,8,138,10,156,12,190,15,17,2,35,4,53,6,71,8,89,10,107,12,125,15,1,2,19,4,21,6,38,8,40,10,58,12,60,15,1,2,3,4,4,6,6,8,8,10,9,12,11,15

SPVH_DATA_GRAY:
Data 0,0,17,1,34,2,51,3,68,4,85,5,102,6,119,7,136,8,153,9,170,10,187,11,204,12,221,13,238,14,255,15

Restore SPVH_DATA_DEFAULT
For SPVH_K = 0 To 255
    Read SPV_VPAL_DEF(SPVH_K).GB
    Read SPV_VPAL_DEF(SPVH_K).R
Next
Restore SPVH_DATA_GRAY
For SPVH_K = 0 To 15
    Read SPV_VPAL_GRAY(SPVH_K).GB
    Read SPV_VPAL_GRAY(SPVH_K).R
Next

'=============================================================================
'  PUBLIC API
'=============================================================================

Function SPVOPEN& (FileName$)
    SPV_LOCK = SPV_LOCK + 1
    SPVOPEN = SPV_OPEN_INT(FileName$)
    SPV_LOCK = SPV_LOCK - 1
End Function

Sub SPVPLAY (h As Long)
    If Not SPV_VALID(h) Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    SPV_PLAY_INT h, _FALSE
    SPV_LOCK = SPV_LOCK - 1
End Sub

Sub SPVLOOP (h As Long)
    If Not SPV_VALID(h) Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    SPV_PLAY_INT h, _TRUE
    SPV_LOCK = SPV_LOCK - 1
End Sub

Sub SPVPAUSE (h As Long)
    If Not SPV_VALID(h) Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    If SPVX(h).State = SPV_PLAYING Then
        _SndPause SPVX(h).SndH
        SPVX(h).State = SPV_PAUSED
    End If
    SPV_LOCK = SPV_LOCK - 1
End Sub

Sub SPVSTOP (h As Long)
    If Not SPV_VALID(h) Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    SPV_FLUSH_AUDIO h
    SPV_REPOSITION h, 0
    SPVX(h).State = SPV_STOPPED
    SPV_LOCK = SPV_LOCK - 1
End Sub

Sub SPVSETPOS (h As Long, Secs As Single)
    Dim T As Single
    If Not SPV_VALID(h) Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    T = Secs
    If T < 0 Then T = 0
    SPV_FLUSH_AUDIO h
    SPV_REPOSITION h, Int(T * SPVX(h).TrueFPS)
    SPV_LOCK = SPV_LOCK - 1
End Sub

Sub SPVVOL (h As Long, Vol As Single)
    If Not SPV_VALID(h) Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    If Vol < 0 Then Vol = 0
    SPVX(h).Volume = Vol
    _SndVol SPVX(h).SndH, Vol
    SPV_LOCK = SPV_LOCK - 1
End Sub

Sub SPVLIMIT (h As Long, Secs As Single)
    If Not SPV_VALID(h) Then Exit Sub
    SPVX(h).LimitSec = Secs
End Sub

Sub SPVCLOSE (h As Long)
    If Not SPV_VALID(h) Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    SPV_CLOSE_INT h
    SPV_LOCK = SPV_LOCK - 1
End Sub

Sub SPVCLOSEALL
    Dim h As Long
    SPV_LOCK = SPV_LOCK + 1
    For h = 1 To SPV_MAX_VIDEOS
        If SPVX(h).InUse Then SPV_CLOSE_INT h
    Next
    SPV_LOCK = SPV_LOCK - 1
End Sub

Function SPVPLAYING% (h As Long)
    SPVPLAYING = _FALSE
    If Not SPV_VALID(h) Then Exit Function
    SPVPLAYING = (SPVX(h).State = SPV_PLAYING)
End Function

Function SPVPAUSED% (h As Long)
    SPVPAUSED = _FALSE
    If Not SPV_VALID(h) Then Exit Function
    SPVPAUSED = (SPVX(h).State = SPV_PAUSED)
End Function

Function SPVLEN# (h As Long)
    SPVLEN = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVLEN = SPVX(h).NumFrames / SPVX(h).TrueFPS
End Function

Function SPVGETPOS# (h As Long)
    SPVGETPOS = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVGETPOS = SPVX(h).FrameIdx / SPVX(h).TrueFPS
End Function

Function SPVIMAGE& (h As Long)
    SPVIMAGE = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVIMAGE = SPVX(h).Img
End Function

Function SPVWIDTH& (h As Long)
    SPVWIDTH = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVWIDTH = SPVX(h).FrameW
End Function

Function SPVHEIGHT& (h As Long)
    SPVHEIGHT = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVHEIGHT = SPVX(h).FrameH
End Function

Function SPVFPS# (h As Long)
    SPVFPS = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVFPS = SPVX(h).TrueFPS
End Function

Function SPVFRAMES& (h As Long)
    SPVFRAMES = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVFRAMES = SPVX(h).NumFrames
End Function

Function SPVFRAME& (h As Long)
    SPVFRAME = 0
    If Not SPV_VALID(h) Then Exit Function
    SPVFRAME = SPVX(h).FrameIdx
End Function

Function SPVNEWFRAME% (h As Long)
    SPVNEWFRAME = _FALSE
    If Not SPV_VALID(h) Then Exit Function
    SPV_LOCK = SPV_LOCK + 1
    If SPVX(h).NewFrame Then
        SPVX(h).NewFrame = _FALSE
        SPVNEWFRAME = _TRUE
    End If
    SPV_LOCK = SPV_LOCK - 1
End Function

Function SPVERROR$
    SPVERROR = SPV_ERRMSG
End Function

'=============================================================================
'  TIMER HANDLER
'=============================================================================

Sub SPVTICK
    Dim h As Long
    Dim Guard As Integer
    If SPV_LOCK > 0 Then Exit Sub
    SPV_LOCK = SPV_LOCK + 1
    For h = 1 To SPV_MAX_VIDEOS
        If SPVX(h).InUse Then
            If SPVX(h).State = SPV_PLAYING And SPVX(h).SndH <> 0 Then
                If SPVX(h).Finished Then
                    ' last frame already queued: wait for the audio to drain
                    If _SndRawLen(SPVX(h).SndH) <= 0 Then SPVX(h).State = SPV_STOPPED
                Else
                    Guard = 0
                    Do While (_SndRawLen(SPVX(h).SndH) <= SPVX(h).TickSec * SPV_LEAD_FRAMES) _AndAlso (Guard < 3)
                        SPV_STEP h
                        Guard = Guard + 1
                        If SPVX(h).Finished Then Exit Do
                    Loop
                End If
            End If
        End If
    Next
    SPV_LOCK = SPV_LOCK - 1
End Sub

'=============================================================================
'  INTERNALS - transport
'=============================================================================

Function SPV_VALID% (h As Long)
    SPV_VALID = _FALSE
    If h < 1 Or h > SPV_MAX_VIDEOS Then Exit Function
    SPV_VALID = SPVX(h).InUse
End Function

Sub SPV_PLAY_INT (h As Long, LoopIt As Integer)
    SPVX(h).Looping = LoopIt
    Select Case SPVX(h).State
        Case SPV_PAUSED
            _SndPlay SPVX(h).SndH
            SPVX(h).State = SPV_PLAYING
        Case SPV_STOPPED
            If SPVX(h).Finished Then SPV_REPOSITION h, 0
            SPVX(h).State = SPV_PLAYING
    End Select
End Sub

Sub SPV_FLUSH_AUDIO (h As Long)
    If SPVX(h).SndH <> 0 Then _SndClose SPVX(h).SndH
    SPVX(h).SndH = _SndOpenRaw
    If SPVX(h).SndH <> 0 Then _SndVol SPVX(h).SndH, SPVX(h).Volume
End Sub

Sub SPV_REPOSITION (h As Long, Fr As Long)
    SPV_PREPLAY h, Fr
End Sub

Sub SPV_AFTER_STEP (h As Long)
    If Not SPVX(h).Finished Then
        If SPVX(h).LimitSec > 0 Then
            If SPVX(h).FrameIdx / SPVX(h).TrueFPS >= SPVX(h).LimitSec Then SPVX(h).Finished = _TRUE
        End If
    End If
    If SPVX(h).Finished And SPVX(h).Looping Then
        ' restart without flushing so the audio stays seamless
        SPV_PREPLAY h, 0
    End If
End Sub

'=============================================================================
'  INTERNALS - open / close
'=============================================================================

Function SPV_OPEN_INT& (FName$)
    Dim h As Long, I As Long
    Dim FileNum As Integer
    SPV_OPEN_INT = 0
    SPV_ERRMSG = ""
    If Not _FileExists(FName$) Then
        SPV_ERRMSG = "File not found: " + FName$
        Exit Function
    End If
    For I = 1 To SPV_MAX_VIDEOS
        If Not SPVX(I).InUse Then h = I: Exit For
    Next
    If h = 0 Then
        SPV_ERRMSG = "No free video handles (max" + Str$(SPV_MAX_VIDEOS) + ")"
        Exit Function
    End If
    If Len(SPV_HDRTMP) <> 32 Or Len(SPV_JHDR) <> 6 Then
        SPV_ERRMSG = "Internal header size mismatch"
        Exit Function
    End If

    FileNum = FreeFile
    Open FName$ For Binary Access Read As FileNum
    If LOF(FileNum) < 33 Then
        Close FileNum
        SPV_ERRMSG = "File too small to be an SPV video"
        Exit Function
    End If
    Get FileNum, 1, SPV_HDRTMP
    If SPV_HDRTMP.ID <> "SPRV" Then
        Close FileNum
        SPV_ERRMSG = "Not an SPV video file"
        Exit Function
    End If

    SPVX(h) = SPV_BLANK
    SPVX(h).InUse = _TRUE
    SPVX(h).Path = FName$
    SPVX(h).VFN = FileNum
    SPVX(h).AFN = FileNum
    SPVX(h).Hdr = SPV_HDRTMP
    SPVX(h).Img = 0
    SPVX(h).SprImg = 0

    If Not SPV_CLASSIFY(h) Then
        SPV_ERRMSG = "Unsupported SPV video type" + Str$(SPV_HDRTMP.VTYPE)
        SPV_CLOSE_INT h
        Exit Function
    End If
    If Not SPV_SETUP(h) Then
        SPV_CLOSE_INT h
        Exit Function
    End If

    SPVX(h).Volume = 1
    SPVX(h).SndH = _SndOpenRaw
    If SPVX(h).SndH = 0 Then
        SPV_ERRMSG = "Could not open an audio stream"
        SPV_CLOSE_INT h
        Exit Function
    End If
    SPVX(h).State = SPV_STOPPED
    SPV_PREPLAY h, 0
    SPV_OPEN_INT = h
End Function

Function SPV_CLASSIFY% (h As Long)
    Dim vt As Long
    SPV_CLASSIFY = _TRUE
    vt = SPVX(h).Hdr.VTYPE
    SPVX(h).VType = vt
    Select Case vt
        Case 99
            SPVX(h).IsMJPG = _TRUE
        Case 1
            SPVX(h).IsSprite = _TRUE: SPVX(h).AudioSep = _TRUE: SPVX(h).HasPal = _TRUE
        Case 2
            SPVX(h).IsSprite = _TRUE: SPVX(h).AudioSep = _TRUE
        Case 3
            SPVX(h).AudioSep = _TRUE: SPVX(h).HasPal = _TRUE
        Case 6
            SPVX(h).IsSprite = _TRUE: SPVX(h).HasPal = _TRUE
        Case 7
            SPVX(h).IsSprite = _TRUE
        Case 8
            SPVX(h).HasPal = _TRUE
        Case 23
            SPVX(h).AudioSep = _TRUE: SPVX(h).Padded = _TRUE: SPVX(h).HasPal = _TRUE
        Case 28, 86, 88
            SPVX(h).Padded = _TRUE: SPVX(h).HasPal = _TRUE
            If vt = 86 Or vt = 88 Then SPVX(h).IsVGA = _TRUE
            If vt = 88 Then SPVX(h).IsModeX = _TRUE
        Case Else
            SPV_CLASSIFY = _FALSE
            Exit Function
    End Select
    SPVX(h).Full24 = (Not SPVX(h).IsMJPG) And (Not SPVX(h).IsSprite) And (SPVX(h).Hdr.PALTAG = Chr$(24))
    SPVX(h).WidePal = (SPVX(h).Hdr.PALTAG = Chr$(24)) Or (SPVX(h).Hdr.PALTAG = Chr$(18))
End Function

Function SPV_SETUP% (h As Long)
    Dim Divisor As Long
    Dim HasExt As Integer
    Dim Pw As Long, Ph As Long
    SPV_SETUP = _FALSE

    SPVX(h).NumFrames = SPVX(h).Hdr.NumFrames
    SPVX(h).BPP = SPVX(h).Hdr.BPP
    SPVX(h).FrameW = SPVX(h).Hdr.FrameWidth
    SPVX(h).FrameH = SPVX(h).Hdr.FrameHeight
    Pw = SPVX(h).FrameW
    Ph = SPVX(h).FrameH
    If SPVX(h).NumFrames < 1 Or Pw < 1 Or Ph < 1 Then
        SPV_ERRMSG = "Bad frame count or frame size in header"
        Exit Function
    End If
    HasExt = (SPVX(h).Hdr.XAUD_FLAG = "X")
    SPVX(h).PixUpper = (Pw * Ph) - 1

    ' ---- video parameters --------------------------------------------------
    If SPVX(h).IsMJPG Then
        SPVX(h).VidBufSize = 0
        SPVX(h).Img = _NewImage(Pw, Ph, 32)
    Else
        Select Case SPVX(h).BPP
            Case 8
                Divisor = 1: SPVX(h).PalSize = 512: SPVX(h).PalUpper = 255
            Case 4
                Divisor = 2: SPVX(h).PalSize = 32: SPVX(h).PalUpper = 15
            Case 2
                Divisor = 4: SPVX(h).PalSize = 8: SPVX(h).PalUpper = 3
            Case 1
                Divisor = 8: SPVX(h).PalSize = 4: SPVX(h).PalUpper = 1
            Case Else
                SPV_ERRMSG = "Unsupported bits per pixel" + Str$(SPVX(h).BPP)
                Exit Function
        End Select
        If SPVX(h).Padded Then SPVX(h).PalSize = 512
        If SPVX(h).IsVGA Or SPVX(h).Full24 Then SPVX(h).PalSize = 768

        SPVX(h).VidFrameSize = (Pw * Ph) \ Divisor
        SPVX(h).VidBufSize = SPVX(h).VidFrameSize

        SPVX(h).Img = _NewImage(Pw, Ph, 256)
        SPV_FMEM(h) = _MemImage(SPVX(h).Img)

        If SPVX(h).IsSprite Then
            SPVX(h).SprW = SPVX(h).Hdr.SpriteWidth
            SPVX(h).SprH = SPVX(h).Hdr.SpriteHeight
            If SPVX(h).SprW < 1 Or SPVX(h).SprH < 1 Then
                SPV_ERRMSG = "Bad sprite size in header"
                Exit Function
            End If
            SPVX(h).SprImg = _NewImage(SPVX(h).SprW, SPVX(h).SprH, 256)
            SPV_SPRMEM(h) = _MemImage(SPVX(h).SprImg)
            SPVX(h).SprPixSize = SPVX(h).SprW * SPVX(h).SprH
        End If

        If SPVX(h).Padded And (SPVX(h).VType < 80) Then
            SPVX(h).VidBufSize = ((SPVX(h).VidBufSize + 511) \ 512) * 512
        End If
        SPVX(h).QSize = SPVX(h).VidBufSize \ 4

        SPV_V1(h) = _MemNew(SPVX(h).VidBufSize)
        SPV_V2(h) = _MemNew(SPVX(h).VidBufSize)
        SPV_P1(h) = _MemNew(SPVX(h).PalSize)
        SPV_P2(h) = _MemNew(SPVX(h).PalSize)
        SPV_ZERO SPV_V1(h)
        SPV_ZERO SPV_V2(h)
        SPV_ZERO SPV_P1(h)
        SPV_ZERO SPV_P2(h)

        If Not SPVX(h).HasPal Then SPV_LOAD_STATIC_PALETTE h
    End If

    ' ---- audio parameters ----------------------------------------------------
    SPVX(h).FPS = SPVX(h).Hdr.FPS
    SPVX(h).Is16 = _FALSE
    SPVX(h).IsStereo = _FALSE
    SPVX(h).Channels = 1
    If HasExt And (SPVX(h).Hdr.F_FPS <> 0) Then SPVX(h).FPS = SPVX(h).Hdr.F_FPS / 100
    If HasExt And (SPVX(h).Hdr.XAUD_BYTE <> 0) Then
        If (SPVX(h).Hdr.XAUD_BYTE And &B00100000) = &B00100000 Then SPVX(h).Is16 = _TRUE
        If (SPVX(h).Hdr.XAUD_BYTE And &B00010000) = &B00010000 Then
            SPVX(h).IsStereo = _TRUE
            SPVX(h).Channels = 2
        End If
    End If

    SPVX(h).TotalFrameBytes = 0
    If SPVX(h).AudioSep Then
        If Not SPV_OPEN_SOUNDTRACK(h) Then Exit Function
    Else
        SPVX(h).AudFrameSize = SPVX(h).Hdr.AudFrmSize
        SPVX(h).TotalFrameBytes = SPVX(h).AudFrameSize
        If SPV_USE_EXACT_RATE(h) Then
            ' Not meant for the X16 (VGA, MJPG, 18/24-bit palette, or a standard
            ' bitmap video above the X16 bandwidth limit): the VERA rate byte is
            ' not trustworthy, so derive the PCM rate from the audio frame size
            ' and the frame rate (header FPS, or X-FPS when present).
            SPVX(h).ExactRate = _TRUE
            SPVX(h).InRate = SPVX(h).AudFrameSize * SPVX(h).FPS
            If SPVX(h).IsStereo Then SPVX(h).InRate = SPVX(h).InRate * .5
            If SPVX(h).Is16 Then SPVX(h).InRate = SPVX(h).InRate * .5
        Else
            SPVX(h).InRate = _Round((SPVX(h).Hdr.VeraRATE / 128) * 48828.15)
        End If
    End If
    SPVX(h).TotalFrameBytes = SPVX(h).TotalFrameBytes + SPVX(h).VidBufSize
    If SPVX(h).HasPal Then SPVX(h).TotalFrameBytes = SPVX(h).TotalFrameBytes + SPVX(h).PalSize

    If SPVX(h).AudFrameSize < 1 Or SPVX(h).InRate < 1 Then
        SPV_ERRMSG = "Bad audio parameters in header"
        Exit Function
    End If

    SPVX(h).InSamples = SPVX(h).AudFrameSize
    SPVX(h).NoLead0 = (SPVX(h).AudFrameSize > 2048)
    If SPVX(h).IsStereo Then
        If SPVX(h).Is16 Then
            SPVX(h).InSamples = SPVX(h).InSamples \ 4
        Else
            SPVX(h).InSamples = SPVX(h).InSamples \ 2
        End If
    Else
        If SPVX(h).Is16 Then SPVX(h).InSamples = SPVX(h).InSamples \ 2
    End If
    If SPVX(h).InSamples < 2 Then
        SPV_ERRMSG = "Audio frame too small"
        Exit Function
    End If

    SPV_A1(h) = _MemNew(SPVX(h).AudFrameSize)
    SPV_A2(h) = _MemNew(SPVX(h).AudFrameSize)
    SPV_ZERO SPV_A1(h)
    SPV_ZERO SPV_A2(h)

    SPVX(h).Out32 = _Round(SPVX(h).InSamples * (SPV_OUT_RATE / SPVX(h).InRate))
    If SPVX(h).Out32 < 1 Then
        SPV_ERRMSG = "Bad audio sample rate"
        Exit Function
    End If
    SPVX(h).TickSec = SPVX(h).Out32 / SPV_OUT_RATE
    SPVX(h).TrueFPS = SPV_OUT_RATE / SPVX(h).Out32
    SPVX(h).ConvFactor = SPVX(h).InRate / SPV_OUT_RATE

    SPV_SETUP = _TRUE
End Function

Function SPV_USE_EXACT_RATE% (h As Long)
    ' True for videos whose embedded-audio rate should come from FPS rather than
    ' the VERA rate byte.  Threshold for standard bitmap videos is bytes/second
    ' of frame data (audio + video + palette) at the video's frame rate.
    Const SPV_X16_MAX_BPS = 250000
    Dim FrameBytes As _Integer64
    SPV_USE_EXACT_RATE = _FALSE
    If SPVX(h).IsVGA Or SPVX(h).IsMJPG Or SPVX(h).WidePal Then
        SPV_USE_EXACT_RATE = _TRUE
        Exit Function
    End If
    If (Not SPVX(h).IsSprite) And (Not SPVX(h).Padded) Then
        FrameBytes = SPVX(h).AudFrameSize + SPVX(h).VidBufSize
        If SPVX(h).HasPal Then FrameBytes = FrameBytes + SPVX(h).PalSize
        If FrameBytes * SPVX(h).FPS > SPV_X16_MAX_BPS Then SPV_USE_EXACT_RATE = _TRUE
    End If
End Function

Function SPV_OPEN_SOUNDTRACK% (h As Long)
    Dim Stem$, AudName$
    Dim FileNum As Integer
    Dim SzBytes As _Integer64
    Dim Afs As Long
    SPV_OPEN_SOUNDTRACK = _FALSE
    Stem$ = SPV_BASEPATH$(SPVX(h).Path)
    AudName$ = Stem$ + ".SVA"
    If Not _FileExists(AudName$) Then AudName$ = Stem$ + ".sva"
    If Not _FileExists(AudName$) Then
        SPV_ERRMSG = "Missing audio file: " + Stem$ + ".SVA"
        Exit Function
    End If
    FileNum = FreeFile
    Open AudName$ For Binary Access Read As FileNum
    SPVX(h).AFN = FileNum
    SzBytes = LOF(FileNum)
    Afs = _Round(SzBytes / SPVX(h).NumFrames)
    If SPVX(h).IsStereo Or SPVX(h).Is16 Then
        If (Afs Mod 2) = 1 Then
            If Afs > Int(SzBytes / SPVX(h).NumFrames) Then
                Afs = Afs - 1
            Else
                Afs = Afs + 1
            End If
        End If
        If SPVX(h).IsStereo And SPVX(h).Is16 Then
            Do While (Afs Mod 4)
                Afs = Afs + 1
            Loop
        End If
    End If
    SPVX(h).AudFrameSize = Afs
    SPVX(h).InRate = Afs * SPVX(h).FPS
    If SPVX(h).IsStereo Then SPVX(h).InRate = SPVX(h).InRate * .5
    If SPVX(h).Is16 Then SPVX(h).InRate = SPVX(h).InRate * .5
    SPV_OPEN_SOUNDTRACK = _TRUE
End Function

Sub SPV_LOAD_STATIC_PALETTE (h As Long)
    ' Videos without an embedded palette: use <name>.PAL if it is the right
    ' size, otherwise the default VERA palette (gray for < 8 bpp).
    Dim Stem$, PalName$
    Dim FileNum As Integer
    Dim Ok As Integer
    Dim I As Long
    Dim Gb As _Unsigned _Byte, Rd As _Unsigned _Byte
    Dim N As Long
    N = SPVX(h).PalSize
    Stem$ = SPV_BASEPATH$(SPVX(h).Path)
    PalName$ = Stem$ + ".PAL"
    If Not _FileExists(PalName$) Then PalName$ = Stem$ + ".pal"
    Ok = _FALSE
    If _FileExists(PalName$) Then
        FileNum = FreeFile
        Open PalName$ For Binary Access Read As FileNum
        If LOF(FileNum) = N Then
            If UBound(SPV_PIO) <> N - 1 Then ReDim SPV_PIO(0 To N - 1) As _Unsigned _Byte
            Get FileNum, 1, SPV_PIO()
            _MemPut SPV_P1(h), SPV_P1(h).OFFSET, SPV_PIO()
            Ok = _TRUE
        End If
        Close FileNum
    End If
    If Not Ok Then
        For I = 0 To SPVX(h).PalUpper
            If SPVX(h).BPP < 8 Then
                Gb = SPV_VPAL_GRAY(I).GB
                Rd = SPV_VPAL_GRAY(I).R
            Else
                Gb = SPV_VPAL_DEF(I).GB
                Rd = SPV_VPAL_DEF(I).R
            End If
            _MemPut SPV_P1(h), SPV_P1(h).OFFSET + (I * 2), Gb
            _MemPut SPV_P1(h), SPV_P1(h).OFFSET + (I * 2) + 1, Rd
        Next
    End If
End Sub

Sub SPV_CLOSE_INT (h As Long)
    If SPVX(h).SndH <> 0 Then _SndClose SPVX(h).SndH
    SPV_FREE_JPEGS h
    If _MemExists(SPV_A1(h)) Then _MemFree SPV_A1(h)
    If _MemExists(SPV_A2(h)) Then _MemFree SPV_A2(h)
    If _MemExists(SPV_V1(h)) Then _MemFree SPV_V1(h)
    If _MemExists(SPV_V2(h)) Then _MemFree SPV_V2(h)
    If _MemExists(SPV_P1(h)) Then _MemFree SPV_P1(h)
    If _MemExists(SPV_P2(h)) Then _MemFree SPV_P2(h)
    If _MemExists(SPV_JIDX(h)) Then _MemFree SPV_JIDX(h)
    If _MemExists(SPV_FMEM(h)) Then _MemFree SPV_FMEM(h)
    If _MemExists(SPV_SPRMEM(h)) Then _MemFree SPV_SPRMEM(h)
    If SPVX(h).SprImg < -1 Then _FreeImage SPVX(h).SprImg
    If SPVX(h).Img < -1 Then _FreeImage SPVX(h).Img
    If SPVX(h).AFN <> 0 And SPVX(h).AFN <> SPVX(h).VFN Then Close SPVX(h).AFN
    If SPVX(h).VFN <> 0 Then Close SPVX(h).VFN
    SPVX(h) = SPV_BLANK
End Sub

Sub SPV_FREE_JPEGS (h As Long)
    If SPVX(h).JImg1 < -1 Then _FreeImage SPVX(h).JImg1
    If SPVX(h).JImg2 < -1 Then _FreeImage SPVX(h).JImg2
    SPVX(h).JImg1 = 0
    SPVX(h).JImg2 = 0
End Sub

Sub SPV_ZERO (M As _MEM)
    _MemFill M, M.OFFSET, M.SIZE, 0 As _BYTE
End Sub

'=============================================================================
'  INTERNALS - file positioning / reading
'=============================================================================

Function SPV_SEEK_TO& (h As Long, Target As Long)
    ' Positions the video (and separate audio) file so that SPV_PREPLAY can
    ' read starting at frame Target.  Returns the (clamped) frame number.
    Dim Fr As Long
    Dim HeaderLead As Long
    Dim FilePos As _Integer64
    Dim Vf As Integer, Af As Integer

    Vf = SPVX(h).VFN
    Af = SPVX(h).AFN
    Fr = Target
    If Fr > SPVX(h).NumFrames - 1 Then Fr = SPVX(h).NumFrames - 1
    If Fr < 0 Then Fr = 0

    HeaderLead = 33
    If SPVX(h).Padded Then HeaderLead = 513

    If SPVX(h).IsMJPG And Fr > 0 Then
        If Not SPVX(h).JIdxBuilt Then SPV_BUILD_JINDEX h
        If Fr > SPVX(h).JIdxCount - 1 Then Fr = SPVX(h).JIdxCount - 1
        If Fr < 0 Then Fr = 0
    End If

    If Fr = 0 Then
        Seek Vf, HeaderLead
        If SPVX(h).AudioSep Then Seek Af, 1
        SPVX(h).NoLead = SPVX(h).NoLead0
    ElseIf SPVX(h).IsMJPG Then
        _MemGet SPV_JIDX(h), SPV_JIDX(h).OFFSET + (8 * Fr), FilePos
        Seek Vf, FilePos
        SPVX(h).NoLead = _TRUE
    Else
        ' If the audio frame is 2k or less the 1st one is doubled on videos
        ' with embedded audio
        If (Not SPVX(h).AudioSep) And SPVX(h).AudFrameSize < 2049 Then
            HeaderLead = HeaderLead + SPVX(h).AudFrameSize
        End If
        FilePos = (Fr * SPVX(h).TotalFrameBytes) + HeaderLead
        Seek Vf, FilePos
        If SPVX(h).AudioSep Then
            SPVX(h).NoLead = _FALSE
            Seek Af, (Fr * SPVX(h).AudFrameSize) + 1
        Else
            SPVX(h).NoLead = _TRUE
        End If
    End If
    SPV_SEEK_TO = Fr
End Function

Sub SPV_BUILD_JINDEX (h As Long)
    ' MJPG frames are variable sized, so walk the file once and remember where
    ' each frame's audio starts.
    Dim K As Long, Cnt As Long
    Dim FilePos As _Integer64, SavedPos As _Integer64
    Dim Vf As Integer
    Dim Afs As Long
    Vf = SPVX(h).VFN
    Afs = SPVX(h).AudFrameSize
    If _MemExists(SPV_JIDX(h)) Then _MemFree SPV_JIDX(h)
    SPV_JIDX(h) = _MemNew(8 * SPVX(h).NumFrames)
    SavedPos = Seek(Vf)
    FilePos = 33
    If Afs < 2049 Then FilePos = FilePos + Afs
    Cnt = 0
    For K = 0 To SPVX(h).NumFrames - 1
        If FilePos + Afs + 5 > LOF(Vf) Then Exit For
        _MemPut SPV_JIDX(h), SPV_JIDX(h).OFFSET + (8 * K), FilePos
        Seek Vf, FilePos + Afs
        Get Vf, , SPV_JHDR
        If SPV_JHDR.ID <> "jp" Or SPV_JHDR.SIZE <= 0 Then Exit For
        FilePos = FilePos + Afs + 6 + SPV_JHDR.SIZE
        Cnt = Cnt + 1
    Next
    Seek Vf, SavedPos
    SPVX(h).JIdxCount = Cnt
    SPVX(h).JIdxBuilt = _TRUE
End Sub

Sub SPV_READ_AUDIO (h As Long, Which As Integer)
    Dim Af As Integer
    Dim N As Long, I As Long
    Af = SPVX(h).AFN
    N = SPVX(h).AudFrameSize
    If UBound(SPV_AIO) <> N - 1 Then ReDim SPV_AIO(0 To N - 1) As _Unsigned _Byte
    If Seek(Af) + N - 1 > LOF(Af) Then
        ' past the end of the file: silence
        For I = 0 To N - 1
            SPV_AIO(I) = 0
        Next
    Else
        Get Af, , SPV_AIO()
        ' VGA 8 bit mono audio is unsigned; the resampler wants signed
        If SPVX(h).IsVGA _AndAlso (Not SPVX(h).IsStereo) _AndAlso (Not SPVX(h).Is16) Then
            For I = 0 To N - 1
                SPV_AIO(I) = SPV_AIO(I) Xor &H80
            Next
        End If
    End If
    If Which = 1 Then
        _MemPut SPV_A1(h), SPV_A1(h).OFFSET, SPV_AIO()
    Else
        _MemPut SPV_A2(h), SPV_A2(h).OFFSET, SPV_AIO()
    End If
End Sub

Function SPV_READ_JPEG& (h As Long)
    Dim Vf As Integer
    Dim NewImg As Long
    Dim Buf As String
    SPV_READ_JPEG = 0
    Vf = SPVX(h).VFN
    If Seek(Vf) + 5 > LOF(Vf) Then Exit Function
    Get Vf, , SPV_JHDR
    If SPV_JHDR.ID <> "jp" Then Exit Function
    If SPV_JHDR.SIZE <= 0 Then Exit Function
    If SPV_JHDR.SIZE > LOF(Vf) - Seek(Vf) + 1 Then Exit Function
    Buf = String$(SPV_JHDR.SIZE, 0)
    Get Vf, , Buf
    NewImg = _LoadImage(Buf, 32, "MEMORY")
    If NewImg < -1 Then SPV_READ_JPEG = NewImg
End Function

Sub SPV_READ_VIDEO (h As Long, Which As Integer)
    Dim Vf As Integer
    Dim N As Long
    Dim NewImg As Long

    If SPVX(h).VReadIdx >= SPVX(h).NumFrames Then
        ' nothing left in the file
        If SPVX(h).IsMJPG Then
            If Which = 1 Then SPVX(h).JImg1 = 0 Else SPVX(h).JImg2 = 0
        End If
        Exit Sub
    End If
    Vf = SPVX(h).VFN

    If SPVX(h).IsMJPG Then
        NewImg = SPV_READ_JPEG(h)
        If Which = 1 Then SPVX(h).JImg1 = NewImg Else SPVX(h).JImg2 = NewImg
        SPVX(h).VReadIdx = SPVX(h).VReadIdx + 1
        Exit Sub
    End If

    N = SPVX(h).VidBufSize
    If UBound(SPV_VIO) <> N - 1 Then ReDim SPV_VIO(0 To N - 1) As _Unsigned _Byte
    If Seek(Vf) + N - 1 <= LOF(Vf) Then
        Get Vf, , SPV_VIO()
        If Which = 1 Then
            _MemPut SPV_V1(h), SPV_V1(h).OFFSET, SPV_VIO()
        Else
            _MemPut SPV_V2(h), SPV_V2(h).OFFSET, SPV_VIO()
        End If
        If SPVX(h).HasPal Then
            N = SPVX(h).PalSize
            If UBound(SPV_PIO) <> N - 1 Then ReDim SPV_PIO(0 To N - 1) As _Unsigned _Byte
            If Seek(Vf) + N - 1 <= LOF(Vf) Then
                Get Vf, , SPV_PIO()
                If Which = 1 Then
                    _MemPut SPV_P1(h), SPV_P1(h).OFFSET, SPV_PIO()
                Else
                    _MemPut SPV_P2(h), SPV_P2(h).OFFSET, SPV_PIO()
                End If
            End If
        End If
    End If
    SPVX(h).VReadIdx = SPVX(h).VReadIdx + 1
End Sub

'=============================================================================
'  INTERNALS - the pre-play cache and the per-tick step
'=============================================================================

Sub SPV_PREPLAY (h As Long, Target As Long)
    ' Equivalent of PREPLAY_CACHE_DATA.  Primes the two-deep audio / video
    ' buffers at frame Target and draws a poster frame into SPVIMAGE.
    Dim Fr As Long
    SPV_FREE_JPEGS h
    Fr = SPV_SEEK_TO(h, Target)
    SPVX(h).VReadIdx = Fr
    SPVX(h).Finished = _FALSE

    SPV_READ_AUDIO h, 1
    If SPVX(h).NoLead Then
        SPVX(h).V1Idx = Fr
        SPV_READ_VIDEO h, 1
    Else
        SPVX(h).V1Idx = Fr - 1
    End If
    SPV_READ_AUDIO h, 2
    SPV_READ_VIDEO h, 2

    ' With small audio frames buffer 1 stays empty for the first step.  For
    ' MJPG show the frame that is waiting in buffer 2 as the poster so
    ' SPVIMAGE is never blank.
    If SPVX(h).IsMJPG And (Not SPVX(h).NoLead) Then
        If SPVX(h).JImg2 < -1 Then SPVX(h).JImg1 = _CopyImage(SPVX(h).JImg2, 32)
    End If

    SPV_SHOW_FRAME h
    SPVX(h).FrameIdx = Fr
End Sub

Sub SPV_STEP (h As Long)
    ' One iteration of the old  NextAudioFrame / NextVideoFrame  loop.
    Dim Shown As Long

    ' ---- audio: resample the current frame and queue it ------------------
    SPV_RESAMPLE h
    _SndRawBatch SPV_PCM32(), SPVX(h).Channels, SPVX(h).SndH, SPVX(h).Out32
    _MemCopy SPV_A2(h), SPV_A2(h).OFFSET, SPVX(h).AudFrameSize To SPV_A1(h), SPV_A1(h).OFFSET
    SPV_READ_AUDIO h, 2

    ' ---- video: show buffer 1, shift, read ahead -------------------------
    Shown = SPVX(h).V1Idx
    SPV_SHOW_FRAME h
    If Shown >= 0 Then SPVX(h).FrameIdx = Shown
    SPVX(h).V1Idx = Shown + 1
    If SPVX(h).IsMJPG Then
        SPVX(h).JImg1 = SPVX(h).JImg2
        SPVX(h).JImg2 = 0
    Else
        _MemCopy SPV_V2(h), SPV_V2(h).OFFSET, SPVX(h).VidBufSize To SPV_V1(h), SPV_V1(h).OFFSET
        If SPVX(h).HasPal Then
            _MemCopy SPV_P2(h), SPV_P2(h).OFFSET, SPVX(h).PalSize To SPV_P1(h), SPV_P1(h).OFFSET
        End If
    End If
    SPV_READ_VIDEO h, 2

    If Shown >= SPVX(h).NumFrames - 1 Then SPVX(h).Finished = _TRUE
    SPV_AFTER_STEP h
End Sub

Sub SPV_SHOW_FRAME (h As Long)
    If SPVX(h).IsMJPG Then
        If SPVX(h).JImg1 < -1 Then
            _PutImage , SPVX(h).JImg1, SPVX(h).Img
            _FreeImage SPVX(h).JImg1
            SPVX(h).JImg1 = 0
        End If
    ElseIf SPVX(h).IsSprite Then
        SPV_DECODE_SPRITE h
    Else
        SPV_DECODE_BITMAP h
    End If
    SPVX(h).NewFrame = _TRUE
End Sub

'=============================================================================
'  INTERNALS - audio resampler (same linear averaging as SPV-VIDS)
'=============================================================================

Sub SPV_RESAMPLE (h As Long)
    Dim I As Long, J As Long
    Dim N As Long, Ins As Long, Ch As Long
    Dim Conv As Double, InPos As Double
    Dim L1 As Single, L2 As Single, R1 As Single, R2 As Single

    N = SPVX(h).Out32
    Ins = SPVX(h).InSamples
    Ch = SPVX(h).Channels
    Conv = SPVX(h).ConvFactor
    If UBound(SPV_PCM32) < (N * Ch) - 1 Then ReDim SPV_PCM32(0 To (N * Ch) - 1) As Single

    If SPVX(h).IsStereo Then
        If SPVX(h).Is16 Then
            If UBound(SPV_ST16_1) <> Ins - 1 Then
                ReDim SPV_ST16_1(0 To Ins - 1) As SPVH_ST16
                ReDim SPV_ST16_2(0 To Ins - 1) As SPVH_ST16
            End If
            _MemGet SPV_A1(h), SPV_A1(h).OFFSET, SPV_ST16_1()
            _MemGet SPV_A2(h), SPV_A2(h).OFFSET, SPV_ST16_2()
            For I = 0 To N - 1
                InPos = I * Conv
                J = Int(InPos)
                If J < Ins - 1 Then
                    L1 = SPV_ST16_1(J).L: L2 = SPV_ST16_1(J + 1).L
                    R1 = SPV_ST16_1(J).R: R2 = SPV_ST16_1(J + 1).R
                Else
                    L1 = SPV_ST16_1(Ins - 1).L: L2 = SPV_ST16_2(0).L
                    R1 = SPV_ST16_1(Ins - 1).R: R2 = SPV_ST16_2(0).R
                End If
                SPV_PCM32(I * 2) = ((L1 + L2) * .5) * SPV_PCM16_TOFLOAT
                SPV_PCM32(I * 2 + 1) = ((R1 + R2) * .5) * SPV_PCM16_TOFLOAT
            Next
        Else
            If UBound(SPV_ST8_1) <> Ins - 1 Then
                ReDim SPV_ST8_1(0 To Ins - 1) As SPVH_ST8
                ReDim SPV_ST8_2(0 To Ins - 1) As SPVH_ST8
            End If
            _MemGet SPV_A1(h), SPV_A1(h).OFFSET, SPV_ST8_1()
            _MemGet SPV_A2(h), SPV_A2(h).OFFSET, SPV_ST8_2()
            For I = 0 To N - 1
                InPos = I * Conv
                J = Int(InPos)
                If J < Ins - 1 Then
                    L1 = SPV_ST8_1(J).L: L2 = SPV_ST8_1(J + 1).L
                    R1 = SPV_ST8_1(J).R: R2 = SPV_ST8_1(J + 1).R
                Else
                    L1 = SPV_ST8_1(Ins - 1).L: L2 = SPV_ST8_2(0).L
                    R1 = SPV_ST8_1(Ins - 1).R: R2 = SPV_ST8_2(0).R
                End If
                SPV_PCM32(I * 2) = ((L1 + L2) * .5) * SPV_PCM8_TOFLOAT
                SPV_PCM32(I * 2 + 1) = ((R1 + R2) * .5) * SPV_PCM8_TOFLOAT
            Next
        End If
    Else
        If SPVX(h).Is16 Then
            If UBound(SPV_PCM16_1) <> Ins - 1 Then
                ReDim SPV_PCM16_1(0 To Ins - 1) As Integer
                ReDim SPV_PCM16_2(0 To Ins - 1) As Integer
            End If
            _MemGet SPV_A1(h), SPV_A1(h).OFFSET, SPV_PCM16_1()
            _MemGet SPV_A2(h), SPV_A2(h).OFFSET, SPV_PCM16_2()
            For I = 0 To N - 1
                InPos = I * Conv
                J = Int(InPos)
                If J < Ins - 1 Then
                    L1 = SPV_PCM16_1(J): L2 = SPV_PCM16_1(J + 1)
                Else
                    L1 = SPV_PCM16_1(Ins - 1): L2 = SPV_PCM16_2(0)
                End If
                SPV_PCM32(I) = ((L1 + L2) * .5) * SPV_PCM16_TOFLOAT
            Next
        Else
            If UBound(SPV_PCM8_1) <> Ins - 1 Then
                ReDim SPV_PCM8_1(0 To Ins - 1) As _Byte
                ReDim SPV_PCM8_2(0 To Ins - 1) As _Byte
            End If
            _MemGet SPV_A1(h), SPV_A1(h).OFFSET, SPV_PCM8_1()
            _MemGet SPV_A2(h), SPV_A2(h).OFFSET, SPV_PCM8_2()
            For I = 0 To N - 1
                InPos = I * Conv
                J = Int(InPos)
                If J < Ins - 1 Then
                    L1 = SPV_PCM8_1(J): L2 = SPV_PCM8_1(J + 1)
                Else
                    L1 = SPV_PCM8_1(Ins - 1): L2 = SPV_PCM8_2(0)
                End If
                SPV_PCM32(I) = ((L1 + L2) * .5) * SPV_PCM8_TOFLOAT
            Next
        End If
    End If
End Sub

'=============================================================================
'  INTERNALS - legacy (non MJPG) frame decoding
'=============================================================================

Sub SPV_LOAD_PALETTE (h As Long)
    Dim I As Long, PIdx As Long, Par As Long
    Dim B1 As _Unsigned _Byte, B2 As _Unsigned _Byte, B3 As _Unsigned _Byte
    Dim C1 As Long, C2 As Long, C3 As Long
    Dim PM As _MEM
    PM = SPV_P1(h)
    PIdx = 0
    If SPVX(h).HasPal Then
        If SPVX(h).BPP < 8 _AndAlso (SPVX(h).VType = 23 Or SPVX(h).VType = 28) Then
            ' 4 bpp padded videos alternate between two palettes
            Par = SPVX(h).V1Idx
            If Par < 0 Then Par = 0
            If (Par And 1) = 0 Then PIdx = &HE0 Else PIdx = &HF0
        End If
    End If
    For I = 0 To SPVX(h).PalUpper
        If SPVX(h).Full24 Then
            _MemGet PM, PM.OFFSET + (PIdx * 3), B1
            _MemGet PM, PM.OFFSET + (PIdx * 3) + 1, B2
            _MemGet PM, PM.OFFSET + (PIdx * 3) + 2, B3
            _PaletteColor I, _RGB32(B1, B2, B3, 255), SPVX(h).Img
        ElseIf SPVX(h).IsVGA Then
            _MemGet PM, PM.OFFSET + (PIdx * 3), B1
            _MemGet PM, PM.OFFSET + (PIdx * 3) + 1, B2
            _MemGet PM, PM.OFFSET + (PIdx * 3) + 2, B3
            ' same scaling as SPV-VIDS (v*4+v), clamped to 255
            C1 = B1: C1 = C1 * 5: If C1 > 255 Then C1 = 255
            C2 = B2: C2 = C2 * 5: If C2 > 255 Then C2 = 255
            C3 = B3: C3 = C3 * 5: If C3 > 255 Then C3 = 255
            _PaletteColor I, _RGB32(C1, C2, C3, 255), SPVX(h).Img
        Else
            _MemGet PM, PM.OFFSET + (PIdx * 2), B1
            _MemGet PM, PM.OFFSET + (PIdx * 2) + 1, B2
            C1 = B1
            C2 = B2
            _PaletteColor I, SPV_VERA2RGB(C1, C2), SPVX(h).Img
        End If
        PIdx = PIdx + 1
    Next
End Sub

Function SPV_VERA2RGB& (GB As Long, RR As Long)
    Dim G As Long, B As Long, R As Long
    G = GB And &HF0
    G = G + (G \ 16)
    B = (GB And &H0F) * 16
    B = B + (B \ 16)
    R = (RR And &H0F) * 17
    SPV_VERA2RGB = _RGB32(R, G, B, 255)
End Function

Sub SPV_FIX_MODEX (h As Long)
    ' Mode X buffers are stored as 4 separate planes; rebuild a linear buffer
    ' in SPV_VWORK.
    Dim Q As Long, Il As Long, Jl As Long
    Dim Add2 As Long, Add3 As Long
    Q = SPVX(h).QSize
    Add2 = Q * 2
    Add3 = Q * 3
    If UBound(SPV_QB1) <> Q - 1 Then
        ReDim SPV_QB1(0 To Q - 1) As _Unsigned _Byte
        ReDim SPV_QB2(0 To Q - 1) As _Unsigned _Byte
        ReDim SPV_QB3(0 To Q - 1) As _Unsigned _Byte
        ReDim SPV_QB4(0 To Q - 1) As _Unsigned _Byte
    End If
    If UBound(SPV_VWORK) <> SPVX(h).VidBufSize - 1 Then
        ReDim SPV_VWORK(0 To SPVX(h).VidBufSize - 1) As _Unsigned _Byte
    End If
    _MemGet SPV_V1(h), SPV_V1(h).OFFSET, SPV_VWORK()
    For Il = 0 To Q - 1
        SPV_QB1(Il) = SPV_VWORK(Il)
        SPV_QB2(Il) = SPV_VWORK(Il + Q)
        SPV_QB3(Il) = SPV_VWORK(Il + Add2)
        SPV_QB4(Il) = SPV_VWORK(Il + Add3)
    Next
    Jl = 0
    For Il = 0 To Q - 1
        SPV_VWORK(Jl) = SPV_QB1(Il)
        SPV_VWORK(Jl + 1) = SPV_QB2(Il)
        SPV_VWORK(Jl + 2) = SPV_QB3(Il)
        SPV_VWORK(Jl + 3) = SPV_QB4(Il)
        Jl = Jl + 4
    Next
End Sub

Sub SPV_DECODE_BITMAP (h As Long)
    Static Px2(0 To 3) As _Unsigned _Byte
    Static Px1(0 To 7) As _Unsigned _Byte
    Dim Pix1 As _Unsigned _Byte, Pix2 As _Unsigned _Byte
    Dim Mask As _Unsigned _Byte
    Dim PB As _Unsigned _Byte
    Dim ShiftVal As Long, PixN As Long
    Dim PixIdx As Long, ImgIdx As Long, PixUpper As Long
    Dim VM As _MEM, FM As _MEM

    SPV_LOAD_PALETTE h
    VM = SPV_V1(h)
    FM = SPV_FMEM(h)
    PixUpper = SPVX(h).PixUpper
    PixIdx = 0
    ImgIdx = 0

    Select Case SPVX(h).BPP
        Case 8
            If SPVX(h).IsModeX Then
                SPV_FIX_MODEX h
                _MemPut FM, FM.OFFSET, SPV_VWORK()
            Else
                _MemCopy VM, VM.OFFSET, SPVX(h).VidFrameSize To FM, FM.OFFSET
            End If
        Case 4
            Do
                _MemGet VM, VM.OFFSET + ImgIdx, PB
                Pix1 = _ShR((PB And &HF0), 4)
                Pix2 = PB And &H0F
                _MemPut FM, FM.OFFSET + PixIdx, Pix1
                PixIdx = PixIdx + 1
                _MemPut FM, FM.OFFSET + PixIdx, Pix2
                ImgIdx = ImgIdx + 1
                PixIdx = PixIdx + 1
            Loop Until PixIdx > PixUpper
        Case 2
            Do
                Mask = &B11000000
                ShiftVal = 8
                PixN = 0
                _MemGet VM, VM.OFFSET + ImgIdx, PB
                Do
                    ShiftVal = ShiftVal - 2
                    Px2(PixN) = _ShR(PB And Mask, ShiftVal)
                    PixN = PixN + 1
                    Mask = _ShR(Mask, 2)
                Loop While ShiftVal
                _MemPut FM, FM.OFFSET + PixIdx, Px2()
                ImgIdx = ImgIdx + 1
                PixIdx = PixIdx + 4
            Loop Until PixIdx > PixUpper
        Case 1
            Do
                Mask = &B10000000
                ShiftVal = 8
                PixN = 0
                _MemGet VM, VM.OFFSET + ImgIdx, PB
                Do
                    ShiftVal = ShiftVal - 1
                    Px1(PixN) = _ShR(PB And Mask, ShiftVal)
                    PixN = PixN + 1
                    Mask = _ShR(Mask, 1)
                Loop While ShiftVal
                _MemPut FM, FM.OFFSET + PixIdx, Px1()
                ImgIdx = ImgIdx + 1
                PixIdx = PixIdx + 8
            Loop Until PixIdx > PixUpper
    End Select
End Sub

Sub SPV_DECODE_SPRITE (h As Long)
    Dim Pix1 As _Unsigned _Byte, Pix2 As _Unsigned _Byte, PB As _Unsigned _Byte
    Dim SX As Long, SY As Long
    Dim ImgIdx As Long, PixIdx As Long, PixUpper As Long, SprPix As Long
    Dim VM As _MEM, SM As _MEM

    SPV_LOAD_PALETTE h
    _CopyPalette SPVX(h).Img, SPVX(h).SprImg
    VM = SPV_V1(h)
    SM = SPV_SPRMEM(h)
    PixUpper = SPVX(h).PixUpper
    SprPix = SPVX(h).SprPixSize
    PixIdx = 0
    SX = 0
    SY = 0

    Select Case SPVX(h).BPP
        Case 8
            Do
                _MemCopy VM, VM.OFFSET + PixIdx, SprPix To SM, SM.OFFSET
                PixIdx = PixIdx + SprPix
                _PutImage (SX, SY), SPVX(h).SprImg, SPVX(h).Img
                SX = SX + SPVX(h).SprW
                If SX >= SPVX(h).FrameW Then
                    SX = 0
                    SY = SY + SPVX(h).SprH
                End If
            Loop Until PixIdx > PixUpper
        Case 4
            ' PixIdx counts source BYTES here (2 pixels each), so the end
            ' of the frame is half the pixel count.
            PixUpper = ((PixUpper + 1) \ 2) - 1
            Do
                ImgIdx = 0
                Do
                    _MemGet VM, VM.OFFSET + PixIdx, PB
                    Pix1 = _ShR(PB And &HF0, 4)
                    Pix2 = PB And &H0F
                    _MemPut SM, SM.OFFSET + ImgIdx, Pix1
                    ImgIdx = ImgIdx + 1
                    _MemPut SM, SM.OFFSET + ImgIdx, Pix2
                    ImgIdx = ImgIdx + 1
                    PixIdx = PixIdx + 1
                    If PixIdx > PixUpper Then Exit Do
                Loop Until ImgIdx >= SprPix
                _PutImage (SX, SY), SPVX(h).SprImg, SPVX(h).Img
                SX = SX + SPVX(h).SprW
                If SX >= SPVX(h).FrameW Then
                    SX = 0
                    SY = SY + SPVX(h).SprH
                End If
            Loop Until PixIdx > PixUpper
    End Select
End Sub

'=============================================================================
'  INTERNALS - path helpers (no dependency on FILEPATHS.BM)
'=============================================================================

Function SPV_DIRPART$ (Fl$)
    Dim I As Long, C$
    SPV_DIRPART = ""
    For I = Len(Fl$) To 1 Step -1
        C$ = Mid$(Fl$, I, 1)
        If C$ = "/" Or C$ = "\" Then
            SPV_DIRPART = Left$(Fl$, I)
            Exit Function
        End If
    Next
End Function

Function SPV_BASEPATH$ (Fl$)
    ' path + file name, without the extension
    Dim I As Long, DirLen As Long
    DirLen = Len(SPV_DIRPART$(Fl$))
    SPV_BASEPATH = Fl$
    For I = Len(Fl$) To DirLen + 1 Step -1
        If Mid$(Fl$, I, 1) = "." Then
            SPV_BASEPATH = Left$(Fl$, I - 1)
            Exit Function
        End If
    Next
End Function
