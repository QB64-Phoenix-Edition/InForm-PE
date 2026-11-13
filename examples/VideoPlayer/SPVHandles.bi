'-----------------------------------------------------------------------------------------------------------------------
' SPV video library
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

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

CONST SPV_MAX_VIDEOS = 16
CONST SPV_TICK_SECONDS = 0.01

CONST SPV_STOPPED = 0
CONST SPV_PLAYING = 1
CONST SPV_PAUSED = 2

CONST SPV_PCM8_TOFLOAT = 1! / 128!
CONST SPV_PCM16_TOFLOAT = 1! / 32768!

TYPE SPVH_HEADER
    ID AS STRING * 4
    VTYPE AS _UNSIGNED _BYTE
    BPP AS _UNSIGNED _BYTE
    FPS AS _UNSIGNED _BYTE
    SpriteWidth AS _UNSIGNED _BYTE
    SpriteHeight AS _UNSIGNED _BYTE
    FrameWidth AS _UNSIGNED INTEGER
    FrameHeight AS _UNSIGNED INTEGER
    NumFrames AS _UNSIGNED LONG
    HINT AS STRING * 1
    VeraRATE AS _UNSIGNED _BYTE
    AudFrmSize AS _UNSIGNED INTEGER
    XAUD_FLAG AS STRING * 1
    XAUD_BYTE AS _UNSIGNED _BYTE
    F_FPS AS _UNSIGNED INTEGER
    EXTRA AS STRING * 6
    PALTAG AS STRING * 1
END TYPE

TYPE SPVH_JHDR
    ID AS STRING * 2
    SIZE AS LONG
END TYPE

TYPE SPVH_VPAL
    GB AS _UNSIGNED _BYTE
    R AS _UNSIGNED _BYTE
END TYPE

TYPE SPVH_ST8
    L AS _BYTE
    R AS _BYTE
END TYPE

TYPE SPVH_ST16
    L AS INTEGER
    R AS INTEGER
END TYPE

TYPE SPVH_SLOT
    InUse AS INTEGER
    Path AS STRING
    VFN AS INTEGER
    AFN AS INTEGER
    Hdr AS SPVH_HEADER
    VType AS INTEGER
    IsMJPG AS INTEGER
    IsVGA AS INTEGER
    IsModeX AS INTEGER
    Full24 AS INTEGER
    WidePal AS INTEGER
    ExactRate AS INTEGER
    IsSprite AS INTEGER
    AudioSep AS INTEGER
    Padded AS INTEGER
    HasPal AS INTEGER
    Is16 AS INTEGER
    IsStereo AS INTEGER
    Channels AS INTEGER
    BPP AS INTEGER
    FrameW AS LONG
    FrameH AS LONG
    SprW AS LONG
    SprH AS LONG
    PixUpper AS LONG
    SprPixSize AS LONG
    VidFrameSize AS LONG
    VidBufSize AS LONG
    QSize AS LONG
    PalSize AS LONG
    PalUpper AS LONG
    AudFrameSize AS LONG
    TotalFrameBytes AS _INTEGER64
    FPS AS DOUBLE
    InRate AS _UNSIGNED LONG
    InSamples AS LONG
    Out32 AS LONG
    ConvFactor AS DOUBLE
    TickSec AS DOUBLE
    TrueFPS AS DOUBLE
    NumFrames AS LONG
    NoLead0 AS INTEGER
    NoLead AS INTEGER
    V1Idx AS LONG
    VReadIdx AS LONG
    FrameIdx AS LONG
    JIdxCount AS LONG
    JIdxBuilt AS INTEGER
    JImg1 AS LONG
    JImg2 AS LONG
    Img AS LONG
    SprImg AS LONG
    SndH AS LONG
    State AS INTEGER
    Finished AS INTEGER
    Looping AS INTEGER
    LimitSec AS DOUBLE
    Volume AS SINGLE
    NewFrame AS INTEGER
END TYPE

DIM SHARED SPVX(1 TO SPV_MAX_VIDEOS) AS SPVH_SLOT
DIM SHARED SPV_BLANK AS SPVH_SLOT
DIM SHARED SPV_HDRTMP AS SPVH_HEADER
DIM SHARED SPV_JHDR AS SPVH_JHDR
DIM SHARED SPV_LOCK AS INTEGER
DIM SHARED SPV_OUT_RATE AS LONG
DIM SHARED SPV_LEAD_FRAMES AS SINGLE ' audio look-ahead, in frames (default 1.25)
DIM SHARED SPV_ERRMSG AS STRING

DIM SHARED SPV_A1(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_A2(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_V1(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_V2(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_P1(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_P2(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_FMEM(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_SPRMEM(1 TO SPV_MAX_VIDEOS) AS _MEM
DIM SHARED SPV_JIDX(1 TO SPV_MAX_VIDEOS) AS _MEM

' Shared scratch arrays.  They are only used inside one library call at a time
' (SPV_LOCK guarantees the timer can not interleave with them).
REDIM SHARED SPV_PCM8_1(0 TO 2) AS _BYTE
REDIM SHARED SPV_PCM8_2(0 TO 2) AS _BYTE
REDIM SHARED SPV_PCM16_1(0 TO 2) AS INTEGER
REDIM SHARED SPV_PCM16_2(0 TO 2) AS INTEGER
REDIM SHARED SPV_ST8_1(0 TO 2) AS SPVH_ST8
REDIM SHARED SPV_ST8_2(0 TO 2) AS SPVH_ST8
REDIM SHARED SPV_ST16_1(0 TO 2) AS SPVH_ST16
REDIM SHARED SPV_ST16_2(0 TO 2) AS SPVH_ST16
REDIM SHARED SPV_PCM32(0 TO 2) AS SINGLE
REDIM SHARED SPV_AIO(0 TO 2) AS _UNSIGNED _BYTE
REDIM SHARED SPV_VIO(0 TO 2) AS _UNSIGNED _BYTE
REDIM SHARED SPV_PIO(0 TO 2) AS _UNSIGNED _BYTE
REDIM SHARED SPV_VWORK(0 TO 2) AS _UNSIGNED _BYTE
REDIM SHARED SPV_QB1(0 TO 2) AS _UNSIGNED _BYTE
REDIM SHARED SPV_QB2(0 TO 2) AS _UNSIGNED _BYTE
REDIM SHARED SPV_QB3(0 TO 2) AS _UNSIGNED _BYTE
REDIM SHARED SPV_QB4(0 TO 2) AS _UNSIGNED _BYTE

DIM SHARED SPV_VPAL_DEF(0 TO 255) AS SPVH_VPAL
DIM SHARED SPV_VPAL_GRAY(0 TO 15) AS SPVH_VPAL

DIM SPVH_K AS LONG

SPV_OUT_RATE = _SNDRATE
SPV_LEAD_FRAMES = 1.25
SPV_ERRMSG = ""

SPVH_DATA_DEFAULT:
DATA 0,0,255,15,0,8,254,10,76,12,197,0,10,0,231,14,133,13,64,6,119,15,51,3,119,7,246,10,143,0,187,11,0,0,17,1,34,2,51,3,68,4,85,5,102,6,119,7,136,8,153,9,170,10,187,11,204,12,221,13,238
DATA 14,255,15,17,2,51,4,68,6,102,8,136,10,153,12,187,15,17,2,34,4,51,6,68,8,85,10,102,12,119,15,0,2,17,4,17,6,34,8,34,10,51,12,51,15,0,2,0,4,0,6,0,8,0,10,0,12,0,15,33,2,67,4,100,6,134,8
DATA 168,10,201,12,235,15,17,2,50,4,83,6,116,8,149,10,182,12,215,15,16,2,49,4,81,6,98,8,130,10,163,12,195,15,16,2,48,4,64,6,96,8,128,10,144,12,176,15,33,1,67,3,100,5,134,7,168,9,201,11,251
DATA 13,33,1,66,3,99,4,132,6,165,8,198,9,247,11,32,1,65,2,97,4,130,5,162,6,195,8,243,9,32,1,64,2,96,3,128,4,160,5,192,6,240,7,33,1,67,3,101,4,134,6,168,8,202,9,252,11,33,1,66,2,100,3,133
DATA 4,166,5,200,6,249,7,32,0,65,1,98,1,131,2,164,2,197,3,246,3,32,0,65,0,97,0,130,0,162,0,195,0,243,0,34,1,68,3,102,4,136,6,170,8,204,9,255,11,34,1,68,2,102,3,136,4,170,5,204,6,255,7,34
DATA 0,68,1,102,1,136,2,170,2,204,3,255,3,34,0,68,0,102,0,136,0,170,0,204,0,255,0,18,1,52,3,86,4,104,6,138,8,172,9,207,11,18,1,36,2,70,3,88,4,106,5,140,6,159,7,2,0,20,1,38,1,56,2,74,2,92
DATA 3,111,3,2,0,20,0,22,0,40,0,42,0,60,0,63,0,18,1,52,3,70,5,104,7,138,9,156,11,191,13,18,1,36,3,54,4,72,6,90,8,108,9,127,11,2,1,20,2,22,4,40,5,42,6,60,8,63,9,2,1,4,2,6,3,8,4,10,5,12,6
DATA 15,7,18,2,52,4,70,6,104,8,138,10,156,12,190,15,17,2,35,4,53,6,71,8,89,10,107,12,125,15,1,2,19,4,21,6,38,8,40,10,58,12,60,15,1,2,3,4,4,6,6,8,8,10,9,12,11,15

SPVH_DATA_GRAY:
DATA 0,0,17,1,34,2,51,3,68,4,85,5,102,6,119,7,136,8,153,9,170,10,187,11,204,12,221,13,238,14,255,15

RESTORE SPVH_DATA_DEFAULT
FOR SPVH_K = 0 TO 255
    READ SPV_VPAL_DEF(SPVH_K).GB
    READ SPV_VPAL_DEF(SPVH_K).R
NEXT
RESTORE SPVH_DATA_GRAY
FOR SPVH_K = 0 TO 15
    READ SPV_VPAL_GRAY(SPVH_K).GB
    READ SPV_VPAL_GRAY(SPVH_K).R
NEXT

'=============================================================================
'  PUBLIC API
'=============================================================================

FUNCTION SPVOPEN& (FileName$)
    SPV_LOCK = SPV_LOCK + 1
    SPVOPEN = SPV_OPEN_INT(FileName$)
    SPV_LOCK = SPV_LOCK - 1
END FUNCTION

SUB SPVPLAY (h AS LONG)
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    SPV_PLAY_INT h, _FALSE
    SPV_LOCK = SPV_LOCK - 1
END SUB

SUB SPVLOOP (h AS LONG)
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    SPV_PLAY_INT h, _TRUE
    SPV_LOCK = SPV_LOCK - 1
END SUB

SUB SPVPAUSE (h AS LONG)
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    IF SPVX(h).State = SPV_PLAYING THEN
        _SNDPAUSE SPVX(h).SndH
        SPVX(h).State = SPV_PAUSED
    END IF
    SPV_LOCK = SPV_LOCK - 1
END SUB

SUB SPVSTOP (h AS LONG)
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    SPV_FLUSH_AUDIO h
    SPV_REPOSITION h, 0
    SPVX(h).State = SPV_STOPPED
    SPV_LOCK = SPV_LOCK - 1
END SUB

SUB SPVSETPOS (h AS LONG, Secs AS SINGLE)
    DIM T AS SINGLE
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    T = Secs
    IF T < 0 THEN T = 0
    SPV_FLUSH_AUDIO h
    SPV_REPOSITION h, INT(T * SPVX(h).TrueFPS)
    SPV_LOCK = SPV_LOCK - 1
END SUB

SUB SPVVOL (h AS LONG, Vol AS SINGLE)
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    IF Vol < 0 THEN Vol = 0
    SPVX(h).Volume = Vol
    _SNDVOL SPVX(h).SndH, Vol
    SPV_LOCK = SPV_LOCK - 1
END SUB

SUB SPVLIMIT (h AS LONG, Secs AS SINGLE)
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPVX(h).LimitSec = Secs
END SUB

SUB SPVCLOSE (h AS LONG)
    IF NOT SPV_VALID(h) THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    SPV_CLOSE_INT h
    SPV_LOCK = SPV_LOCK - 1
END SUB

SUB SPVCLOSEALL
    DIM h AS LONG
    SPV_LOCK = SPV_LOCK + 1
    FOR h = 1 TO SPV_MAX_VIDEOS
        IF SPVX(h).InUse THEN SPV_CLOSE_INT h
    NEXT
    SPV_LOCK = SPV_LOCK - 1
END SUB

FUNCTION SPVPLAYING% (h AS LONG)
    SPVPLAYING = _FALSE
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVPLAYING = (SPVX(h).State = SPV_PLAYING)
END FUNCTION

FUNCTION SPVPAUSED% (h AS LONG)
    SPVPAUSED = _FALSE
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVPAUSED = (SPVX(h).State = SPV_PAUSED)
END FUNCTION

FUNCTION SPVLEN# (h AS LONG)
    SPVLEN = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVLEN = SPVX(h).NumFrames / SPVX(h).TrueFPS
END FUNCTION

FUNCTION SPVGETPOS# (h AS LONG)
    SPVGETPOS = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVGETPOS = SPVX(h).FrameIdx / SPVX(h).TrueFPS
END FUNCTION

FUNCTION SPVIMAGE& (h AS LONG)
    SPVIMAGE = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVIMAGE = SPVX(h).Img
END FUNCTION

FUNCTION SPVWIDTH& (h AS LONG)
    SPVWIDTH = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVWIDTH = SPVX(h).FrameW
END FUNCTION

FUNCTION SPVHEIGHT& (h AS LONG)
    SPVHEIGHT = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVHEIGHT = SPVX(h).FrameH
END FUNCTION

FUNCTION SPVFPS# (h AS LONG)
    SPVFPS = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVFPS = SPVX(h).TrueFPS
END FUNCTION

FUNCTION SPVFRAMES& (h AS LONG)
    SPVFRAMES = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVFRAMES = SPVX(h).NumFrames
END FUNCTION

FUNCTION SPVFRAME& (h AS LONG)
    SPVFRAME = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVFRAME = SPVX(h).FrameIdx
END FUNCTION

FUNCTION SPVNEWFRAME% (h AS LONG)
    SPVNEWFRAME = _FALSE
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPV_LOCK = SPV_LOCK + 1
    IF SPVX(h).NewFrame THEN
        SPVX(h).NewFrame = _FALSE
        SPVNEWFRAME = _TRUE
    END IF
    SPV_LOCK = SPV_LOCK - 1
END FUNCTION

FUNCTION SPVERROR$
    SPVERROR = SPV_ERRMSG
END FUNCTION

'=============================================================================
'  TIMER HANDLER
'=============================================================================

SUB SPVTICK
    DIM h AS LONG
    DIM Guard AS INTEGER
    IF SPV_LOCK > 0 THEN EXIT SUB
    SPV_LOCK = SPV_LOCK + 1
    FOR h = 1 TO SPV_MAX_VIDEOS
        IF SPVX(h).InUse THEN
            IF SPVX(h).State = SPV_PLAYING AND SPVX(h).SndH <> 0 THEN
                IF SPVX(h).Finished THEN
                    ' last frame already queued: wait for the audio to drain
                    IF _SNDRAWLEN(SPVX(h).SndH) <= 0 THEN SPVX(h).State = SPV_STOPPED
                ELSE
                    Guard = 0
                    DO WHILE (_SNDRAWLEN(SPVX(h).SndH) <= SPVX(h).TickSec * SPV_LEAD_FRAMES) _ANDALSO (Guard < 3)
                        SPV_STEP h
                        Guard = Guard + 1
                        IF SPVX(h).Finished THEN EXIT DO
                    LOOP
                END IF
            END IF
        END IF
    NEXT
    SPV_LOCK = SPV_LOCK - 1
END SUB

'=============================================================================
'  INTERNALS - transport
'=============================================================================

FUNCTION SPV_VALID% (h AS LONG)
    SPV_VALID = _FALSE
    IF h < 1 OR h > SPV_MAX_VIDEOS THEN EXIT FUNCTION
    SPV_VALID = SPVX(h).InUse
END FUNCTION

SUB SPV_PLAY_INT (h AS LONG, LoopIt AS INTEGER)
    SPVX(h).Looping = LoopIt
    SELECT CASE SPVX(h).State
        CASE SPV_PAUSED
            _SNDPLAY SPVX(h).SndH
            SPVX(h).State = SPV_PLAYING
        CASE SPV_STOPPED
            IF SPVX(h).Finished THEN SPV_REPOSITION h, 0
            SPVX(h).State = SPV_PLAYING
    END SELECT
END SUB

SUB SPV_FLUSH_AUDIO (h AS LONG)
    IF SPVX(h).SndH <> 0 THEN _SNDCLOSE SPVX(h).SndH
    SPVX(h).SndH = _SNDOPENRAW
    IF SPVX(h).SndH <> 0 THEN _SNDVOL SPVX(h).SndH, SPVX(h).Volume
END SUB

SUB SPV_REPOSITION (h AS LONG, Fr AS LONG)
    SPV_PREPLAY h, Fr
END SUB

SUB SPV_AFTER_STEP (h AS LONG)
    IF NOT SPVX(h).Finished THEN
        IF SPVX(h).LimitSec > 0 THEN
            IF SPVX(h).FrameIdx / SPVX(h).TrueFPS >= SPVX(h).LimitSec THEN SPVX(h).Finished = _TRUE
        END IF
    END IF
    IF SPVX(h).Finished AND SPVX(h).Looping THEN
        ' restart without flushing so the audio stays seamless
        SPV_PREPLAY h, 0
    END IF
END SUB

'=============================================================================
'  INTERNALS - open / close
'=============================================================================

FUNCTION SPV_OPEN_INT& (FName$)
    DIM h AS LONG, I AS LONG
    DIM FileNum AS INTEGER
    SPV_OPEN_INT = 0
    SPV_ERRMSG = ""
    IF NOT _FILEEXISTS(FName$) THEN
        SPV_ERRMSG = "File not found: " + FName$
        EXIT FUNCTION
    END IF
    FOR I = 1 TO SPV_MAX_VIDEOS
        IF NOT SPVX(I).InUse THEN h = I: EXIT FOR
    NEXT
    IF h = 0 THEN
        SPV_ERRMSG = "No free video handles (max" + STR$(SPV_MAX_VIDEOS) + ")"
        EXIT FUNCTION
    END IF
    IF LEN(SPV_HDRTMP) <> 32 OR LEN(SPV_JHDR) <> 6 THEN
        SPV_ERRMSG = "Internal header size mismatch"
        EXIT FUNCTION
    END IF

    FileNum = FREEFILE
    OPEN FName$ FOR BINARY ACCESS READ AS FileNum
    IF LOF(FileNum) < 33 THEN
        CLOSE FileNum
        SPV_ERRMSG = "File too small to be an SPV video"
        EXIT FUNCTION
    END IF
    GET FileNum, 1, SPV_HDRTMP
    IF SPV_HDRTMP.ID <> "SPRV" THEN
        CLOSE FileNum
        SPV_ERRMSG = "Not an SPV video file"
        EXIT FUNCTION
    END IF

    SPVX(h) = SPV_BLANK
    SPVX(h).InUse = _TRUE
    SPVX(h).Path = FName$
    SPVX(h).VFN = FileNum
    SPVX(h).AFN = FileNum
    SPVX(h).Hdr = SPV_HDRTMP
    SPVX(h).Img = 0
    SPVX(h).SprImg = 0

    IF NOT SPV_CLASSIFY(h) THEN
        SPV_ERRMSG = "Unsupported SPV video type" + STR$(SPV_HDRTMP.VTYPE)
        SPV_CLOSE_INT h
        EXIT FUNCTION
    END IF
    IF NOT SPV_SETUP(h) THEN
        SPV_CLOSE_INT h
        EXIT FUNCTION
    END IF

    SPVX(h).Volume = 1
    SPVX(h).SndH = _SNDOPENRAW
    IF SPVX(h).SndH = 0 THEN
        SPV_ERRMSG = "Could not open an audio stream"
        SPV_CLOSE_INT h
        EXIT FUNCTION
    END IF
    SPVX(h).State = SPV_STOPPED
    SPV_PREPLAY h, 0
    SPV_OPEN_INT = h
END FUNCTION

FUNCTION SPV_CLASSIFY% (h AS LONG)
    DIM vt AS LONG
    SPV_CLASSIFY = _TRUE
    vt = SPVX(h).Hdr.VTYPE
    SPVX(h).VType = vt
    SELECT CASE vt
        CASE 99
            SPVX(h).IsMJPG = _TRUE
        CASE 1
            SPVX(h).IsSprite = _TRUE: SPVX(h).AudioSep = _TRUE: SPVX(h).HasPal = _TRUE
        CASE 2
            SPVX(h).IsSprite = _TRUE: SPVX(h).AudioSep = _TRUE
        CASE 3
            SPVX(h).AudioSep = _TRUE: SPVX(h).HasPal = _TRUE
        CASE 6
            SPVX(h).IsSprite = _TRUE: SPVX(h).HasPal = _TRUE
        CASE 7
            SPVX(h).IsSprite = _TRUE
        CASE 8
            SPVX(h).HasPal = _TRUE
        CASE 23
            SPVX(h).AudioSep = _TRUE: SPVX(h).Padded = _TRUE: SPVX(h).HasPal = _TRUE
        CASE 28, 86, 88
            SPVX(h).Padded = _TRUE: SPVX(h).HasPal = _TRUE
            IF vt = 86 OR vt = 88 THEN SPVX(h).IsVGA = _TRUE
            IF vt = 88 THEN SPVX(h).IsModeX = _TRUE
        CASE ELSE
            SPV_CLASSIFY = _FALSE
            EXIT FUNCTION
    END SELECT
    SPVX(h).Full24 = (NOT SPVX(h).IsMJPG) AND (NOT SPVX(h).IsSprite) AND (SPVX(h).Hdr.PALTAG = CHR$(24))
    SPVX(h).WidePal = (SPVX(h).Hdr.PALTAG = CHR$(24)) OR (SPVX(h).Hdr.PALTAG = CHR$(18))
END FUNCTION

FUNCTION SPV_SETUP% (h AS LONG)
    DIM Divisor AS LONG
    DIM HasExt AS INTEGER
    DIM Pw AS LONG, Ph AS LONG
    SPV_SETUP = _FALSE

    SPVX(h).NumFrames = SPVX(h).Hdr.NumFrames
    SPVX(h).BPP = SPVX(h).Hdr.BPP
    SPVX(h).FrameW = SPVX(h).Hdr.FrameWidth
    SPVX(h).FrameH = SPVX(h).Hdr.FrameHeight
    Pw = SPVX(h).FrameW
    Ph = SPVX(h).FrameH
    IF SPVX(h).NumFrames < 1 OR Pw < 1 OR Ph < 1 THEN
        SPV_ERRMSG = "Bad frame count or frame size in header"
        EXIT FUNCTION
    END IF
    HasExt = (SPVX(h).Hdr.XAUD_FLAG = "X")
    SPVX(h).PixUpper = (Pw * Ph) - 1

    ' ---- video parameters --------------------------------------------------
    IF SPVX(h).IsMJPG THEN
        SPVX(h).VidBufSize = 0
        SPVX(h).Img = _NEWIMAGE(Pw, Ph, 32)
    ELSE
        SELECT CASE SPVX(h).BPP
            CASE 8
                Divisor = 1: SPVX(h).PalSize = 512: SPVX(h).PalUpper = 255
            CASE 4
                Divisor = 2: SPVX(h).PalSize = 32: SPVX(h).PalUpper = 15
            CASE 2
                Divisor = 4: SPVX(h).PalSize = 8: SPVX(h).PalUpper = 3
            CASE 1
                Divisor = 8: SPVX(h).PalSize = 4: SPVX(h).PalUpper = 1
            CASE ELSE
                SPV_ERRMSG = "Unsupported bits per pixel" + STR$(SPVX(h).BPP)
                EXIT FUNCTION
        END SELECT
        IF SPVX(h).Padded THEN SPVX(h).PalSize = 512
        IF SPVX(h).IsVGA OR SPVX(h).Full24 THEN SPVX(h).PalSize = 768

        SPVX(h).VidFrameSize = (Pw * Ph) \ Divisor
        SPVX(h).VidBufSize = SPVX(h).VidFrameSize

        SPVX(h).Img = _NEWIMAGE(Pw, Ph, 256)
        SPV_FMEM(h) = _MEMIMAGE(SPVX(h).Img)

        IF SPVX(h).IsSprite THEN
            SPVX(h).SprW = SPVX(h).Hdr.SpriteWidth
            SPVX(h).SprH = SPVX(h).Hdr.SpriteHeight
            IF SPVX(h).SprW < 1 OR SPVX(h).SprH < 1 THEN
                SPV_ERRMSG = "Bad sprite size in header"
                EXIT FUNCTION
            END IF
            SPVX(h).SprImg = _NEWIMAGE(SPVX(h).SprW, SPVX(h).SprH, 256)
            SPV_SPRMEM(h) = _MEMIMAGE(SPVX(h).SprImg)
            SPVX(h).SprPixSize = SPVX(h).SprW * SPVX(h).SprH
        END IF

        IF SPVX(h).Padded AND (SPVX(h).VType < 80) THEN
            SPVX(h).VidBufSize = ((SPVX(h).VidBufSize + 511) \ 512) * 512
        END IF
        SPVX(h).QSize = SPVX(h).VidBufSize \ 4

        SPV_V1(h) = _MEMNEW(SPVX(h).VidBufSize)
        SPV_V2(h) = _MEMNEW(SPVX(h).VidBufSize)
        SPV_P1(h) = _MEMNEW(SPVX(h).PalSize)
        SPV_P2(h) = _MEMNEW(SPVX(h).PalSize)
        SPV_ZERO SPV_V1(h)
        SPV_ZERO SPV_V2(h)
        SPV_ZERO SPV_P1(h)
        SPV_ZERO SPV_P2(h)

        IF NOT SPVX(h).HasPal THEN SPV_LOAD_STATIC_PALETTE h
    END IF

    ' ---- audio parameters ----------------------------------------------------
    SPVX(h).FPS = SPVX(h).Hdr.FPS
    SPVX(h).Is16 = _FALSE
    SPVX(h).IsStereo = _FALSE
    SPVX(h).Channels = 1
    IF HasExt AND (SPVX(h).Hdr.F_FPS <> 0) THEN SPVX(h).FPS = SPVX(h).Hdr.F_FPS / 100
    IF HasExt AND (SPVX(h).Hdr.XAUD_BYTE <> 0) THEN
        IF (SPVX(h).Hdr.XAUD_BYTE AND &B00100000) = &B00100000 THEN SPVX(h).Is16 = _TRUE
        IF (SPVX(h).Hdr.XAUD_BYTE AND &B00010000) = &B00010000 THEN
            SPVX(h).IsStereo = _TRUE
            SPVX(h).Channels = 2
        END IF
    END IF

    SPVX(h).TotalFrameBytes = 0
    IF SPVX(h).AudioSep THEN
        IF NOT SPV_OPEN_SOUNDTRACK(h) THEN EXIT FUNCTION
    ELSE
        SPVX(h).AudFrameSize = SPVX(h).Hdr.AudFrmSize
        SPVX(h).TotalFrameBytes = SPVX(h).AudFrameSize
        IF SPV_USE_EXACT_RATE(h) THEN
            ' Not meant for the X16 (VGA, MJPG, 18/24-bit palette, or a standard
            ' bitmap video above the X16 bandwidth limit): the VERA rate byte is
            ' not trustworthy, so derive the PCM rate from the audio frame size
            ' and the frame rate (header FPS, or X-FPS when present).
            SPVX(h).ExactRate = _TRUE
            SPVX(h).InRate = SPVX(h).AudFrameSize * SPVX(h).FPS
            IF SPVX(h).IsStereo THEN SPVX(h).InRate = SPVX(h).InRate * .5
            IF SPVX(h).Is16 THEN SPVX(h).InRate = SPVX(h).InRate * .5
        ELSE
            SPVX(h).InRate = _ROUND((SPVX(h).Hdr.VeraRATE / 128) * 48828.15)
        END IF
    END IF
    SPVX(h).TotalFrameBytes = SPVX(h).TotalFrameBytes + SPVX(h).VidBufSize
    IF SPVX(h).HasPal THEN SPVX(h).TotalFrameBytes = SPVX(h).TotalFrameBytes + SPVX(h).PalSize

    IF SPVX(h).AudFrameSize < 1 OR SPVX(h).InRate < 1 THEN
        SPV_ERRMSG = "Bad audio parameters in header"
        EXIT FUNCTION
    END IF

    SPVX(h).InSamples = SPVX(h).AudFrameSize
    SPVX(h).NoLead0 = (SPVX(h).AudFrameSize > 2048)
    IF SPVX(h).IsStereo THEN
        IF SPVX(h).Is16 THEN
            SPVX(h).InSamples = SPVX(h).InSamples \ 4
        ELSE
            SPVX(h).InSamples = SPVX(h).InSamples \ 2
        END IF
    ELSE
        IF SPVX(h).Is16 THEN SPVX(h).InSamples = SPVX(h).InSamples \ 2
    END IF
    IF SPVX(h).InSamples < 2 THEN
        SPV_ERRMSG = "Audio frame too small"
        EXIT FUNCTION
    END IF

    SPV_A1(h) = _MEMNEW(SPVX(h).AudFrameSize)
    SPV_A2(h) = _MEMNEW(SPVX(h).AudFrameSize)
    SPV_ZERO SPV_A1(h)
    SPV_ZERO SPV_A2(h)

    SPVX(h).Out32 = _ROUND(SPVX(h).InSamples * (SPV_OUT_RATE / SPVX(h).InRate))
    IF SPVX(h).Out32 < 1 THEN
        SPV_ERRMSG = "Bad audio sample rate"
        EXIT FUNCTION
    END IF
    SPVX(h).TickSec = SPVX(h).Out32 / SPV_OUT_RATE
    SPVX(h).TrueFPS = SPV_OUT_RATE / SPVX(h).Out32
    SPVX(h).ConvFactor = SPVX(h).InRate / SPV_OUT_RATE

    SPV_SETUP = _TRUE
END FUNCTION

FUNCTION SPV_USE_EXACT_RATE% (h AS LONG)
    ' True for videos whose embedded-audio rate should come from FPS rather than
    ' the VERA rate byte.  Threshold for standard bitmap videos is bytes/second
    ' of frame data (audio + video + palette) at the video's frame rate.
    CONST SPV_X16_MAX_BPS = 250000
    DIM FrameBytes AS _INTEGER64
    SPV_USE_EXACT_RATE = _FALSE
    IF SPVX(h).IsVGA OR SPVX(h).IsMJPG OR SPVX(h).WidePal THEN
        SPV_USE_EXACT_RATE = _TRUE
        EXIT FUNCTION
    END IF
    IF (NOT SPVX(h).IsSprite) AND (NOT SPVX(h).Padded) THEN
        FrameBytes = SPVX(h).AudFrameSize + SPVX(h).VidBufSize
        IF SPVX(h).HasPal THEN FrameBytes = FrameBytes + SPVX(h).PalSize
        IF FrameBytes * SPVX(h).FPS > SPV_X16_MAX_BPS THEN SPV_USE_EXACT_RATE = _TRUE
    END IF
END FUNCTION

FUNCTION SPV_OPEN_SOUNDTRACK% (h AS LONG)
    DIM Stem$, AudName$
    DIM FileNum AS INTEGER
    DIM SzBytes AS _INTEGER64
    DIM Afs AS LONG
    SPV_OPEN_SOUNDTRACK = _FALSE
    Stem$ = SPV_BASEPATH$(SPVX(h).Path)
    AudName$ = Stem$ + ".SVA"
    IF NOT _FILEEXISTS(AudName$) THEN AudName$ = Stem$ + ".sva"
    IF NOT _FILEEXISTS(AudName$) THEN
        SPV_ERRMSG = "Missing audio file: " + Stem$ + ".SVA"
        EXIT FUNCTION
    END IF
    FileNum = FREEFILE
    OPEN AudName$ FOR BINARY ACCESS READ AS FileNum
    SPVX(h).AFN = FileNum
    SzBytes = LOF(FileNum)
    Afs = _ROUND(SzBytes / SPVX(h).NumFrames)
    IF SPVX(h).IsStereo OR SPVX(h).Is16 THEN
        IF (Afs MOD 2) = 1 THEN
            IF Afs > INT(SzBytes / SPVX(h).NumFrames) THEN
                Afs = Afs - 1
            ELSE
                Afs = Afs + 1
            END IF
        END IF
        IF SPVX(h).IsStereo AND SPVX(h).Is16 THEN
            DO WHILE (Afs MOD 4)
                Afs = Afs + 1
            LOOP
        END IF
    END IF
    SPVX(h).AudFrameSize = Afs
    SPVX(h).InRate = Afs * SPVX(h).FPS
    IF SPVX(h).IsStereo THEN SPVX(h).InRate = SPVX(h).InRate * .5
    IF SPVX(h).Is16 THEN SPVX(h).InRate = SPVX(h).InRate * .5
    SPV_OPEN_SOUNDTRACK = _TRUE
END FUNCTION

SUB SPV_LOAD_STATIC_PALETTE (h AS LONG)
    ' Videos without an embedded palette: use <name>.PAL if it is the right
    ' size, otherwise the default VERA palette (gray for < 8 bpp).
    DIM Stem$, PalName$
    DIM FileNum AS INTEGER
    DIM Ok AS INTEGER
    DIM I AS LONG
    DIM Gb AS _UNSIGNED _BYTE, Rd AS _UNSIGNED _BYTE
    DIM N AS LONG
    N = SPVX(h).PalSize
    Stem$ = SPV_BASEPATH$(SPVX(h).Path)
    PalName$ = Stem$ + ".PAL"
    IF NOT _FILEEXISTS(PalName$) THEN PalName$ = Stem$ + ".pal"
    Ok = _FALSE
    IF _FILEEXISTS(PalName$) THEN
        FileNum = FREEFILE
        OPEN PalName$ FOR BINARY ACCESS READ AS FileNum
        IF LOF(FileNum) = N THEN
            IF UBOUND(SPV_PIO) <> N - 1 THEN REDIM SPV_PIO(0 TO N - 1) AS _UNSIGNED _BYTE
            GET FileNum, 1, SPV_PIO()
            _MEMPUT SPV_P1(h), SPV_P1(h).OFFSET, SPV_PIO()
            Ok = _TRUE
        END IF
        CLOSE FileNum
    END IF
    IF NOT Ok THEN
        FOR I = 0 TO SPVX(h).PalUpper
            IF SPVX(h).BPP < 8 THEN
                Gb = SPV_VPAL_GRAY(I).GB
                Rd = SPV_VPAL_GRAY(I).R
            ELSE
                Gb = SPV_VPAL_DEF(I).GB
                Rd = SPV_VPAL_DEF(I).R
            END IF
            _MEMPUT SPV_P1(h), SPV_P1(h).OFFSET + (I * 2), Gb
            _MEMPUT SPV_P1(h), SPV_P1(h).OFFSET + (I * 2) + 1, Rd
        NEXT
    END IF
END SUB

SUB SPV_CLOSE_INT (h AS LONG)
    IF SPVX(h).SndH <> 0 THEN _SNDCLOSE SPVX(h).SndH
    SPV_FREE_JPEGS h
    IF _MEMEXISTS(SPV_A1(h)) THEN _MEMFREE SPV_A1(h)
    IF _MEMEXISTS(SPV_A2(h)) THEN _MEMFREE SPV_A2(h)
    IF _MEMEXISTS(SPV_V1(h)) THEN _MEMFREE SPV_V1(h)
    IF _MEMEXISTS(SPV_V2(h)) THEN _MEMFREE SPV_V2(h)
    IF _MEMEXISTS(SPV_P1(h)) THEN _MEMFREE SPV_P1(h)
    IF _MEMEXISTS(SPV_P2(h)) THEN _MEMFREE SPV_P2(h)
    IF _MEMEXISTS(SPV_JIDX(h)) THEN _MEMFREE SPV_JIDX(h)
    IF _MEMEXISTS(SPV_FMEM(h)) THEN _MEMFREE SPV_FMEM(h)
    IF _MEMEXISTS(SPV_SPRMEM(h)) THEN _MEMFREE SPV_SPRMEM(h)
    IF SPVX(h).SprImg < -1 THEN _FREEIMAGE SPVX(h).SprImg
    IF SPVX(h).Img < -1 THEN _FREEIMAGE SPVX(h).Img
    IF SPVX(h).AFN <> 0 AND SPVX(h).AFN <> SPVX(h).VFN THEN CLOSE SPVX(h).AFN
    IF SPVX(h).VFN <> 0 THEN CLOSE SPVX(h).VFN
    SPVX(h) = SPV_BLANK
END SUB

SUB SPV_FREE_JPEGS (h AS LONG)
    IF SPVX(h).JImg1 < -1 THEN _FREEIMAGE SPVX(h).JImg1
    IF SPVX(h).JImg2 < -1 THEN _FREEIMAGE SPVX(h).JImg2
    SPVX(h).JImg1 = 0
    SPVX(h).JImg2 = 0
END SUB

SUB SPV_ZERO (M AS _MEM)
    _MEMFILL M, M.OFFSET, M.SIZE, 0 AS _BYTE
END SUB

'=============================================================================
'  INTERNALS - file positioning / reading
'=============================================================================

FUNCTION SPV_SEEK_TO& (h AS LONG, Target AS LONG)
    ' Positions the video (and separate audio) file so that SPV_PREPLAY can
    ' read starting at frame Target.  Returns the (clamped) frame number.
    DIM Fr AS LONG
    DIM HeaderLead AS LONG
    DIM FilePos AS _INTEGER64
    DIM Vf AS INTEGER, Af AS INTEGER

    Vf = SPVX(h).VFN
    Af = SPVX(h).AFN
    Fr = Target
    IF Fr > SPVX(h).NumFrames - 1 THEN Fr = SPVX(h).NumFrames - 1
    IF Fr < 0 THEN Fr = 0

    HeaderLead = 33
    IF SPVX(h).Padded THEN HeaderLead = 513

    IF SPVX(h).IsMJPG AND Fr > 0 THEN
        IF NOT SPVX(h).JIdxBuilt THEN SPV_BUILD_JINDEX h
        IF Fr > SPVX(h).JIdxCount - 1 THEN Fr = SPVX(h).JIdxCount - 1
        IF Fr < 0 THEN Fr = 0
    END IF

    IF Fr = 0 THEN
        SEEK Vf, HeaderLead
        IF SPVX(h).AudioSep THEN SEEK Af, 1
        SPVX(h).NoLead = SPVX(h).NoLead0
    ELSEIF SPVX(h).IsMJPG THEN
        _MEMGET SPV_JIDX(h), SPV_JIDX(h).OFFSET + (8 * Fr), FilePos
        SEEK Vf, FilePos
        SPVX(h).NoLead = _TRUE
    ELSE
        ' If the audio frame is 2k or less the 1st one is doubled on videos
        ' with embedded audio
        IF (NOT SPVX(h).AudioSep) AND SPVX(h).AudFrameSize < 2049 THEN
            HeaderLead = HeaderLead + SPVX(h).AudFrameSize
        END IF
        FilePos = (Fr * SPVX(h).TotalFrameBytes) + HeaderLead
        SEEK Vf, FilePos
        IF SPVX(h).AudioSep THEN
            SPVX(h).NoLead = _FALSE
            SEEK Af, (Fr * SPVX(h).AudFrameSize) + 1
        ELSE
            SPVX(h).NoLead = _TRUE
        END IF
    END IF
    SPV_SEEK_TO = Fr
END FUNCTION

SUB SPV_BUILD_JINDEX (h AS LONG)
    ' MJPG frames are variable sized, so walk the file once and remember where
    ' each frame's audio starts.
    DIM K AS LONG, Cnt AS LONG
    DIM FilePos AS _INTEGER64, SavedPos AS _INTEGER64
    DIM Vf AS INTEGER
    DIM Afs AS LONG
    Vf = SPVX(h).VFN
    Afs = SPVX(h).AudFrameSize
    IF _MEMEXISTS(SPV_JIDX(h)) THEN _MEMFREE SPV_JIDX(h)
    SPV_JIDX(h) = _MEMNEW(8 * SPVX(h).NumFrames)
    SavedPos = SEEK(Vf)
    FilePos = 33
    IF Afs < 2049 THEN FilePos = FilePos + Afs
    Cnt = 0
    FOR K = 0 TO SPVX(h).NumFrames - 1
        IF FilePos + Afs + 5 > LOF(Vf) THEN EXIT FOR
        _MEMPUT SPV_JIDX(h), SPV_JIDX(h).OFFSET + (8 * K), FilePos
        SEEK Vf, FilePos + Afs
        GET Vf, , SPV_JHDR
        IF SPV_JHDR.ID <> "jp" OR SPV_JHDR.SIZE <= 0 THEN EXIT FOR
        FilePos = FilePos + Afs + 6 + SPV_JHDR.SIZE
        Cnt = Cnt + 1
    NEXT
    SEEK Vf, SavedPos
    SPVX(h).JIdxCount = Cnt
    SPVX(h).JIdxBuilt = _TRUE
END SUB

SUB SPV_READ_AUDIO (h AS LONG, Which AS INTEGER)
    DIM Af AS INTEGER
    DIM N AS LONG, I AS LONG
    Af = SPVX(h).AFN
    N = SPVX(h).AudFrameSize
    IF UBOUND(SPV_AIO) <> N - 1 THEN REDIM SPV_AIO(0 TO N - 1) AS _UNSIGNED _BYTE
    IF SEEK(Af) + N - 1 > LOF(Af) THEN
        ' past the end of the file: silence
        FOR I = 0 TO N - 1
            SPV_AIO(I) = 0
        NEXT
    ELSE
        GET Af, , SPV_AIO()
        ' VGA 8 bit mono audio is unsigned; the resampler wants signed
        IF SPVX(h).IsVGA _ANDALSO (NOT SPVX(h).IsStereo) _ANDALSO (NOT SPVX(h).Is16) THEN
            FOR I = 0 TO N - 1
                SPV_AIO(I) = SPV_AIO(I) XOR &H80
            NEXT
        END IF
    END IF
    IF Which = 1 THEN
        _MEMPUT SPV_A1(h), SPV_A1(h).OFFSET, SPV_AIO()
    ELSE
        _MEMPUT SPV_A2(h), SPV_A2(h).OFFSET, SPV_AIO()
    END IF
END SUB

FUNCTION SPV_READ_JPEG& (h AS LONG)
    DIM Vf AS INTEGER
    DIM NewImg AS LONG
    DIM Buf AS STRING
    SPV_READ_JPEG = 0
    Vf = SPVX(h).VFN
    IF SEEK(Vf) + 5 > LOF(Vf) THEN EXIT FUNCTION
    GET Vf, , SPV_JHDR
    IF SPV_JHDR.ID <> "jp" THEN EXIT FUNCTION
    IF SPV_JHDR.SIZE <= 0 THEN EXIT FUNCTION
    IF SPV_JHDR.SIZE > LOF(Vf) - SEEK(Vf) + 1 THEN EXIT FUNCTION
    Buf = STRING$(SPV_JHDR.SIZE, 0)
    GET Vf, , Buf
    NewImg = _LOADIMAGE(Buf, 32, "MEMORY")
    IF NewImg < -1 THEN SPV_READ_JPEG = NewImg
END FUNCTION

SUB SPV_READ_VIDEO (h AS LONG, Which AS INTEGER)
    DIM Vf AS INTEGER
    DIM N AS LONG
    DIM NewImg AS LONG

    IF SPVX(h).VReadIdx >= SPVX(h).NumFrames THEN
        ' nothing left in the file
        IF SPVX(h).IsMJPG THEN
            IF Which = 1 THEN SPVX(h).JImg1 = 0 ELSE SPVX(h).JImg2 = 0
        END IF
        EXIT SUB
    END IF
    Vf = SPVX(h).VFN

    IF SPVX(h).IsMJPG THEN
        NewImg = SPV_READ_JPEG(h)
        IF Which = 1 THEN SPVX(h).JImg1 = NewImg ELSE SPVX(h).JImg2 = NewImg
        SPVX(h).VReadIdx = SPVX(h).VReadIdx + 1
        EXIT SUB
    END IF

    N = SPVX(h).VidBufSize
    IF UBOUND(SPV_VIO) <> N - 1 THEN REDIM SPV_VIO(0 TO N - 1) AS _UNSIGNED _BYTE
    IF SEEK(Vf) + N - 1 <= LOF(Vf) THEN
        GET Vf, , SPV_VIO()
        IF Which = 1 THEN
            _MEMPUT SPV_V1(h), SPV_V1(h).OFFSET, SPV_VIO()
        ELSE
            _MEMPUT SPV_V2(h), SPV_V2(h).OFFSET, SPV_VIO()
        END IF
        IF SPVX(h).HasPal THEN
            N = SPVX(h).PalSize
            IF UBOUND(SPV_PIO) <> N - 1 THEN REDIM SPV_PIO(0 TO N - 1) AS _UNSIGNED _BYTE
            IF SEEK(Vf) + N - 1 <= LOF(Vf) THEN
                GET Vf, , SPV_PIO()
                IF Which = 1 THEN
                    _MEMPUT SPV_P1(h), SPV_P1(h).OFFSET, SPV_PIO()
                ELSE
                    _MEMPUT SPV_P2(h), SPV_P2(h).OFFSET, SPV_PIO()
                END IF
            END IF
        END IF
    END IF
    SPVX(h).VReadIdx = SPVX(h).VReadIdx + 1
END SUB

'=============================================================================
'  INTERNALS - the pre-play cache and the per-tick step
'=============================================================================

SUB SPV_PREPLAY (h AS LONG, Target AS LONG)
    ' Equivalent of PREPLAY_CACHE_DATA.  Primes the two-deep audio / video
    ' buffers at frame Target and draws a poster frame into SPVIMAGE.
    DIM Fr AS LONG
    SPV_FREE_JPEGS h
    Fr = SPV_SEEK_TO(h, Target)
    SPVX(h).VReadIdx = Fr
    SPVX(h).Finished = _FALSE

    SPV_READ_AUDIO h, 1
    IF SPVX(h).NoLead THEN
        SPVX(h).V1Idx = Fr
        SPV_READ_VIDEO h, 1
    ELSE
        SPVX(h).V1Idx = Fr - 1
    END IF
    SPV_READ_AUDIO h, 2
    SPV_READ_VIDEO h, 2

    ' With small audio frames buffer 1 stays empty for the first step.  For
    ' MJPG show the frame that is waiting in buffer 2 as the poster so
    ' SPVIMAGE is never blank.
    IF SPVX(h).IsMJPG AND (NOT SPVX(h).NoLead) THEN
        IF SPVX(h).JImg2 < -1 THEN SPVX(h).JImg1 = _COPYIMAGE(SPVX(h).JImg2, 32)
    END IF

    SPV_SHOW_FRAME h
    SPVX(h).FrameIdx = Fr
END SUB

SUB SPV_STEP (h AS LONG)
    ' One iteration of the old  NextAudioFrame / NextVideoFrame  loop.
    DIM Shown AS LONG

    ' ---- audio: resample the current frame and queue it ------------------
    SPV_RESAMPLE h
    _SNDRAWBATCH SPV_PCM32(), SPVX(h).Channels, SPVX(h).SndH, SPVX(h).Out32
    _MEMCOPY SPV_A2(h), SPV_A2(h).OFFSET, SPVX(h).AudFrameSize TO SPV_A1(h), SPV_A1(h).OFFSET
    SPV_READ_AUDIO h, 2

    ' ---- video: show buffer 1, shift, read ahead -------------------------
    Shown = SPVX(h).V1Idx
    SPV_SHOW_FRAME h
    IF Shown >= 0 THEN SPVX(h).FrameIdx = Shown
    SPVX(h).V1Idx = Shown + 1
    IF SPVX(h).IsMJPG THEN
        SPVX(h).JImg1 = SPVX(h).JImg2
        SPVX(h).JImg2 = 0
    ELSE
        _MEMCOPY SPV_V2(h), SPV_V2(h).OFFSET, SPVX(h).VidBufSize TO SPV_V1(h), SPV_V1(h).OFFSET
        IF SPVX(h).HasPal THEN
            _MEMCOPY SPV_P2(h), SPV_P2(h).OFFSET, SPVX(h).PalSize TO SPV_P1(h), SPV_P1(h).OFFSET
        END IF
    END IF
    SPV_READ_VIDEO h, 2

    IF Shown >= SPVX(h).NumFrames - 1 THEN SPVX(h).Finished = _TRUE
    SPV_AFTER_STEP h
END SUB

SUB SPV_SHOW_FRAME (h AS LONG)
    IF SPVX(h).IsMJPG THEN
        IF SPVX(h).JImg1 < -1 THEN
            _PUTIMAGE , SPVX(h).JImg1, SPVX(h).Img
            _FREEIMAGE SPVX(h).JImg1
            SPVX(h).JImg1 = 0
        END IF
    ELSEIF SPVX(h).IsSprite THEN
        SPV_DECODE_SPRITE h
    ELSE
        SPV_DECODE_BITMAP h
    END IF
    SPVX(h).NewFrame = _TRUE
END SUB

'=============================================================================
'  INTERNALS - audio resampler (same linear averaging as SPV-VIDS)
'=============================================================================

SUB SPV_RESAMPLE (h AS LONG)
    DIM I AS LONG, J AS LONG
    DIM N AS LONG, Ins AS LONG, Ch AS LONG
    DIM Conv AS DOUBLE, InPos AS DOUBLE
    DIM L1 AS SINGLE, L2 AS SINGLE, R1 AS SINGLE, R2 AS SINGLE

    N = SPVX(h).Out32
    Ins = SPVX(h).InSamples
    Ch = SPVX(h).Channels
    Conv = SPVX(h).ConvFactor
    IF UBOUND(SPV_PCM32) < (N * Ch) - 1 THEN REDIM SPV_PCM32(0 TO (N * Ch) - 1) AS SINGLE

    IF SPVX(h).IsStereo THEN
        IF SPVX(h).Is16 THEN
            IF UBOUND(SPV_ST16_1) <> Ins - 1 THEN
                REDIM SPV_ST16_1(0 TO Ins - 1) AS SPVH_ST16
                REDIM SPV_ST16_2(0 TO Ins - 1) AS SPVH_ST16
            END IF
            _MEMGET SPV_A1(h), SPV_A1(h).OFFSET, SPV_ST16_1()
            _MEMGET SPV_A2(h), SPV_A2(h).OFFSET, SPV_ST16_2()
            FOR I = 0 TO N - 1
                InPos = I * Conv
                J = INT(InPos)
                IF J < Ins - 1 THEN
                    L1 = SPV_ST16_1(J).L: L2 = SPV_ST16_1(J + 1).L
                    R1 = SPV_ST16_1(J).R: R2 = SPV_ST16_1(J + 1).R
                ELSE
                    L1 = SPV_ST16_1(Ins - 1).L: L2 = SPV_ST16_2(0).L
                    R1 = SPV_ST16_1(Ins - 1).R: R2 = SPV_ST16_2(0).R
                END IF
                SPV_PCM32(I * 2) = ((L1 + L2) * .5) * SPV_PCM16_TOFLOAT
                SPV_PCM32(I * 2 + 1) = ((R1 + R2) * .5) * SPV_PCM16_TOFLOAT
            NEXT
        ELSE
            IF UBOUND(SPV_ST8_1) <> Ins - 1 THEN
                REDIM SPV_ST8_1(0 TO Ins - 1) AS SPVH_ST8
                REDIM SPV_ST8_2(0 TO Ins - 1) AS SPVH_ST8
            END IF
            _MEMGET SPV_A1(h), SPV_A1(h).OFFSET, SPV_ST8_1()
            _MEMGET SPV_A2(h), SPV_A2(h).OFFSET, SPV_ST8_2()
            FOR I = 0 TO N - 1
                InPos = I * Conv
                J = INT(InPos)
                IF J < Ins - 1 THEN
                    L1 = SPV_ST8_1(J).L: L2 = SPV_ST8_1(J + 1).L
                    R1 = SPV_ST8_1(J).R: R2 = SPV_ST8_1(J + 1).R
                ELSE
                    L1 = SPV_ST8_1(Ins - 1).L: L2 = SPV_ST8_2(0).L
                    R1 = SPV_ST8_1(Ins - 1).R: R2 = SPV_ST8_2(0).R
                END IF
                SPV_PCM32(I * 2) = ((L1 + L2) * .5) * SPV_PCM8_TOFLOAT
                SPV_PCM32(I * 2 + 1) = ((R1 + R2) * .5) * SPV_PCM8_TOFLOAT
            NEXT
        END IF
    ELSE
        IF SPVX(h).Is16 THEN
            IF UBOUND(SPV_PCM16_1) <> Ins - 1 THEN
                REDIM SPV_PCM16_1(0 TO Ins - 1) AS INTEGER
                REDIM SPV_PCM16_2(0 TO Ins - 1) AS INTEGER
            END IF
            _MEMGET SPV_A1(h), SPV_A1(h).OFFSET, SPV_PCM16_1()
            _MEMGET SPV_A2(h), SPV_A2(h).OFFSET, SPV_PCM16_2()
            FOR I = 0 TO N - 1
                InPos = I * Conv
                J = INT(InPos)
                IF J < Ins - 1 THEN
                    L1 = SPV_PCM16_1(J): L2 = SPV_PCM16_1(J + 1)
                ELSE
                    L1 = SPV_PCM16_1(Ins - 1): L2 = SPV_PCM16_2(0)
                END IF
                SPV_PCM32(I) = ((L1 + L2) * .5) * SPV_PCM16_TOFLOAT
            NEXT
        ELSE
            IF UBOUND(SPV_PCM8_1) <> Ins - 1 THEN
                REDIM SPV_PCM8_1(0 TO Ins - 1) AS _BYTE
                REDIM SPV_PCM8_2(0 TO Ins - 1) AS _BYTE
            END IF
            _MEMGET SPV_A1(h), SPV_A1(h).OFFSET, SPV_PCM8_1()
            _MEMGET SPV_A2(h), SPV_A2(h).OFFSET, SPV_PCM8_2()
            FOR I = 0 TO N - 1
                InPos = I * Conv
                J = INT(InPos)
                IF J < Ins - 1 THEN
                    L1 = SPV_PCM8_1(J): L2 = SPV_PCM8_1(J + 1)
                ELSE
                    L1 = SPV_PCM8_1(Ins - 1): L2 = SPV_PCM8_2(0)
                END IF
                SPV_PCM32(I) = ((L1 + L2) * .5) * SPV_PCM8_TOFLOAT
            NEXT
        END IF
    END IF
END SUB

'=============================================================================
'  INTERNALS - legacy (non MJPG) frame decoding
'=============================================================================

SUB SPV_LOAD_PALETTE (h AS LONG)
    DIM I AS LONG, PIdx AS LONG, Par AS LONG
    DIM B1 AS _UNSIGNED _BYTE, B2 AS _UNSIGNED _BYTE, B3 AS _UNSIGNED _BYTE
    DIM C1 AS LONG, C2 AS LONG, C3 AS LONG
    DIM PM AS _MEM
    PM = SPV_P1(h)
    PIdx = 0
    IF SPVX(h).HasPal THEN
        IF SPVX(h).BPP < 8 _ANDALSO (SPVX(h).VType = 23 OR SPVX(h).VType = 28) THEN
            ' 4 bpp padded videos alternate between two palettes
            Par = SPVX(h).V1Idx
            IF Par < 0 THEN Par = 0
            IF (Par AND 1) = 0 THEN PIdx = &HE0 ELSE PIdx = &HF0
        END IF
    END IF
    FOR I = 0 TO SPVX(h).PalUpper
        IF SPVX(h).Full24 THEN
            _MEMGET PM, PM.OFFSET + (PIdx * 3), B1
            _MEMGET PM, PM.OFFSET + (PIdx * 3) + 1, B2
            _MEMGET PM, PM.OFFSET + (PIdx * 3) + 2, B3
            _PALETTECOLOR I, _RGB32(B1, B2, B3, 255), SPVX(h).Img
        ELSEIF SPVX(h).IsVGA THEN
            _MEMGET PM, PM.OFFSET + (PIdx * 3), B1
            _MEMGET PM, PM.OFFSET + (PIdx * 3) + 1, B2
            _MEMGET PM, PM.OFFSET + (PIdx * 3) + 2, B3
            ' same scaling as SPV-VIDS (v*4+v), clamped to 255
            C1 = B1: C1 = C1 * 5: IF C1 > 255 THEN C1 = 255
            C2 = B2: C2 = C2 * 5: IF C2 > 255 THEN C2 = 255
            C3 = B3: C3 = C3 * 5: IF C3 > 255 THEN C3 = 255
            _PALETTECOLOR I, _RGB32(C1, C2, C3, 255), SPVX(h).Img
        ELSE
            _MEMGET PM, PM.OFFSET + (PIdx * 2), B1
            _MEMGET PM, PM.OFFSET + (PIdx * 2) + 1, B2
            C1 = B1
            C2 = B2
            _PALETTECOLOR I, SPV_VERA2RGB(C1, C2), SPVX(h).Img
        END IF
        PIdx = PIdx + 1
    NEXT
END SUB

FUNCTION SPV_VERA2RGB& (GB AS LONG, RR AS LONG)
    DIM G AS LONG, B AS LONG, R AS LONG
    G = GB AND &HF0
    G = G + (G \ 16)
    B = (GB AND &H0F) * 16
    B = B + (B \ 16)
    R = (RR AND &H0F) * 17
    SPV_VERA2RGB = _RGB32(R, G, B, 255)
END FUNCTION

SUB SPV_FIX_MODEX (h AS LONG)
    ' Mode X buffers are stored as 4 separate planes; rebuild a linear buffer
    ' in SPV_VWORK.
    DIM Q AS LONG, Il AS LONG, Jl AS LONG
    DIM Add2 AS LONG, Add3 AS LONG
    Q = SPVX(h).QSize
    Add2 = Q * 2
    Add3 = Q * 3
    IF UBOUND(SPV_QB1) <> Q - 1 THEN
        REDIM SPV_QB1(0 TO Q - 1) AS _UNSIGNED _BYTE
        REDIM SPV_QB2(0 TO Q - 1) AS _UNSIGNED _BYTE
        REDIM SPV_QB3(0 TO Q - 1) AS _UNSIGNED _BYTE
        REDIM SPV_QB4(0 TO Q - 1) AS _UNSIGNED _BYTE
    END IF
    IF UBOUND(SPV_VWORK) <> SPVX(h).VidBufSize - 1 THEN
        REDIM SPV_VWORK(0 TO SPVX(h).VidBufSize - 1) AS _UNSIGNED _BYTE
    END IF
    _MEMGET SPV_V1(h), SPV_V1(h).OFFSET, SPV_VWORK()
    FOR Il = 0 TO Q - 1
        SPV_QB1(Il) = SPV_VWORK(Il)
        SPV_QB2(Il) = SPV_VWORK(Il + Q)
        SPV_QB3(Il) = SPV_VWORK(Il + Add2)
        SPV_QB4(Il) = SPV_VWORK(Il + Add3)
    NEXT
    Jl = 0
    FOR Il = 0 TO Q - 1
        SPV_VWORK(Jl) = SPV_QB1(Il)
        SPV_VWORK(Jl + 1) = SPV_QB2(Il)
        SPV_VWORK(Jl + 2) = SPV_QB3(Il)
        SPV_VWORK(Jl + 3) = SPV_QB4(Il)
        Jl = Jl + 4
    NEXT
END SUB

SUB SPV_DECODE_BITMAP (h AS LONG)
    STATIC Px2(0 TO 3) AS _UNSIGNED _BYTE
    STATIC Px1(0 TO 7) AS _UNSIGNED _BYTE
    DIM Pix1 AS _UNSIGNED _BYTE, Pix2 AS _UNSIGNED _BYTE
    DIM Mask AS _UNSIGNED _BYTE
    DIM PB AS _UNSIGNED _BYTE
    DIM ShiftVal AS LONG, PixN AS LONG
    DIM PixIdx AS LONG, ImgIdx AS LONG, PixUpper AS LONG
    DIM VM AS _MEM, FM AS _MEM

    SPV_LOAD_PALETTE h
    VM = SPV_V1(h)
    FM = SPV_FMEM(h)
    PixUpper = SPVX(h).PixUpper
    PixIdx = 0
    ImgIdx = 0

    SELECT CASE SPVX(h).BPP
        CASE 8
            IF SPVX(h).IsModeX THEN
                SPV_FIX_MODEX h
                _MEMPUT FM, FM.OFFSET, SPV_VWORK()
            ELSE
                _MEMCOPY VM, VM.OFFSET, SPVX(h).VidFrameSize TO FM, FM.OFFSET
            END IF
        CASE 4
            DO
                _MEMGET VM, VM.OFFSET + ImgIdx, PB
                Pix1 = _SHR((PB AND &HF0), 4)
                Pix2 = PB AND &H0F
                _MEMPUT FM, FM.OFFSET + PixIdx, Pix1
                PixIdx = PixIdx + 1
                _MEMPUT FM, FM.OFFSET + PixIdx, Pix2
                ImgIdx = ImgIdx + 1
                PixIdx = PixIdx + 1
            LOOP UNTIL PixIdx > PixUpper
        CASE 2
            DO
                Mask = &B11000000
                ShiftVal = 8
                PixN = 0
                _MEMGET VM, VM.OFFSET + ImgIdx, PB
                DO
                    ShiftVal = ShiftVal - 2
                    Px2(PixN) = _SHR(PB AND Mask, ShiftVal)
                    PixN = PixN + 1
                    Mask = _SHR(Mask, 2)
                LOOP WHILE ShiftVal
                _MEMPUT FM, FM.OFFSET + PixIdx, Px2()
                ImgIdx = ImgIdx + 1
                PixIdx = PixIdx + 4
            LOOP UNTIL PixIdx > PixUpper
        CASE 1
            DO
                Mask = &B10000000
                ShiftVal = 8
                PixN = 0
                _MEMGET VM, VM.OFFSET + ImgIdx, PB
                DO
                    ShiftVal = ShiftVal - 1
                    Px1(PixN) = _SHR(PB AND Mask, ShiftVal)
                    PixN = PixN + 1
                    Mask = _SHR(Mask, 1)
                LOOP WHILE ShiftVal
                _MEMPUT FM, FM.OFFSET + PixIdx, Px1()
                ImgIdx = ImgIdx + 1
                PixIdx = PixIdx + 8
            LOOP UNTIL PixIdx > PixUpper
    END SELECT
END SUB

SUB SPV_DECODE_SPRITE (h AS LONG)
    DIM Pix1 AS _UNSIGNED _BYTE, Pix2 AS _UNSIGNED _BYTE, PB AS _UNSIGNED _BYTE
    DIM SX AS LONG, SY AS LONG
    DIM ImgIdx AS LONG, PixIdx AS LONG, PixUpper AS LONG, SprPix AS LONG
    DIM VM AS _MEM, SM AS _MEM

    SPV_LOAD_PALETTE h
    _COPYPALETTE SPVX(h).Img, SPVX(h).SprImg
    VM = SPV_V1(h)
    SM = SPV_SPRMEM(h)
    PixUpper = SPVX(h).PixUpper
    SprPix = SPVX(h).SprPixSize
    PixIdx = 0
    SX = 0
    SY = 0

    SELECT CASE SPVX(h).BPP
        CASE 8
            DO
                _MEMCOPY VM, VM.OFFSET + PixIdx, SprPix TO SM, SM.OFFSET
                PixIdx = PixIdx + SprPix
                _PUTIMAGE (SX, SY), SPVX(h).SprImg, SPVX(h).Img
                SX = SX + SPVX(h).SprW
                IF SX >= SPVX(h).FrameW THEN
                    SX = 0
                    SY = SY + SPVX(h).SprH
                END IF
            LOOP UNTIL PixIdx > PixUpper
        CASE 4
            ' PixIdx counts source BYTES here (2 pixels each), so the end
            ' of the frame is half the pixel count.
            PixUpper = ((PixUpper + 1) \ 2) - 1
            DO
                ImgIdx = 0
                DO
                    _MEMGET VM, VM.OFFSET + PixIdx, PB
                    Pix1 = _SHR(PB AND &HF0, 4)
                    Pix2 = PB AND &H0F
                    _MEMPUT SM, SM.OFFSET + ImgIdx, Pix1
                    ImgIdx = ImgIdx + 1
                    _MEMPUT SM, SM.OFFSET + ImgIdx, Pix2
                    ImgIdx = ImgIdx + 1
                    PixIdx = PixIdx + 1
                    IF PixIdx > PixUpper THEN EXIT DO
                LOOP UNTIL ImgIdx >= SprPix
                _PUTIMAGE (SX, SY), SPVX(h).SprImg, SPVX(h).Img
                SX = SX + SPVX(h).SprW
                IF SX >= SPVX(h).FrameW THEN
                    SX = 0
                    SY = SY + SPVX(h).SprH
                END IF
            LOOP UNTIL PixIdx > PixUpper
    END SELECT
END SUB

'=============================================================================
'  INTERNALS - path helpers (no dependency on FILEPATHS.BM)
'=============================================================================

FUNCTION SPV_DIRPART$ (Fl$)
    DIM I AS LONG, C$
    SPV_DIRPART = ""
    FOR I = LEN(Fl$) TO 1 STEP -1
        C$ = MID$(Fl$, I, 1)
        IF C$ = "/" OR C$ = "\" THEN
            SPV_DIRPART = LEFT$(Fl$, I)
            EXIT FUNCTION
        END IF
    NEXT
END FUNCTION

FUNCTION SPV_BASEPATH$ (Fl$)
    ' path + file name, without the extension
    DIM I AS LONG, DirLen AS LONG
    DirLen = LEN(SPV_DIRPART$(Fl$))
    SPV_BASEPATH = Fl$
    FOR I = LEN(Fl$) TO DirLen + 1 STEP -1
        IF MID$(Fl$, I, 1) = "." THEN
            SPV_BASEPATH = LEFT$(Fl$, I - 1)
            EXIT FUNCTION
        END IF
    NEXT
END FUNCTION
