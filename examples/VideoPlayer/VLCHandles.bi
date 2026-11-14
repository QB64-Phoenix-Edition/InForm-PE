'-----------------------------------------------------------------------------------------------------------------------
' Handle based video library (libvlc 3.x)
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'=============================================================================
'  VLCHandles.bi  (VLC-HANDLES.BM in the original distribution)
'
'  Handle based video library for ANY standard video (MP4, MKV, AVI, WebM,
'  MOV, streams ...) using libvlc 3.x.  Same calling convention as
'  SPV-HANDLES.BM, which is modeled on _SNDOPEN / _SNDPLAY.
'
'  Needs qbvlc.h (the C code) in the same folder as your program, and the
'  VLC 3.x runtime installed (same bitness as QB64-PE).  See VLC-VID-GUIDE.MD.
'
'  This library never touches the screen, the keyboard or _DEST.  Your program
'  owns the screen; the library keeps one image per video up to date and you
'  draw it yourself with _PUTIMAGE.
'
'  *** NO ON TIMER IS NEEDED. ***  VLC decodes and plays sound on its own
'  threads.  Looping, SPVLIMIT-style limits and end-of-video detection are
'  checked whenever you call VLCIMAGE, VLCNEWFRAME, VLCPLAYING, VLCPAUSED,
'  VLCGETPOS (or VLCTICK), so any normal draw loop is enough.
'
'  ---------------------------------------------------------------------------
'  QB64 sound command          VLC equivalent
'  ---------------------------------------------------------------------------
'  h& = _SNDOPEN(file$)        h& = VLCOPEN(file$)          (0 = failure)
'                              h& = VLCOPENFIT(file$, w&, h&) (decode shrunk to fit w x h)
'  _SNDPLAY h&                 VLCPLAY h&
'  _SNDLOOP h&                 VLCLOOP h&
'  _SNDPAUSE h&                VLCPAUSE h&
'  _SNDSTOP h&                 VLCSTOP h&                   (rewinds to start)
'  _SNDPLAYING(h&)             VLCPLAYING(h&)
'  _SNDPAUSED(h&)              VLCPAUSED(h&)
'  _SNDLEN(h&)                 VLCLEN(h&)                   (seconds)
'  _SNDGETPOS(h&)              VLCGETPOS(h&)                (seconds)
'  _SNDSETPOS h&, secs!        VLCSETPOS h&, secs!
'  _SNDVOL h&, v!              VLCVOL h&, v!                (0 to 1, up to 2)
'  _SNDLIMIT h&, secs!         VLCLIMIT h&, secs!           (0 = no limit)
'  _SNDCLOSE h&                VLCCLOSE h&
'
'  Video only additions (same as SPV):
'    VLCIMAGE&(h&)      image handle holding the current frame
'    VLCNEWFRAME%(h&)   true once each time a new frame has arrived
'    VLCWIDTH&(h&)  VLCHEIGHT&(h&)  VLCFPS#(h&)  VLCFRAMES&(h&)  VLCFRAME&(h&)
'    VLCERROR$          text of the last VLCOPEN failure
'    VLCCLOSEALL        close every open video and shut libvlc down
'    VLCTICK            optional: service every video (loop/limit/end checks)
'
'  Handles are LONG (1 to 8).  Seconds / volume are SINGLE.
'  Like SPVOPEN, VLCOPEN leaves the video STOPPED on its first frame; call
'  VLCPLAY or VLCLOOP to start it.  VLCOPEN waits (normally well under a
'  second) until VLC has produced that first frame.
'=============================================================================

CONST VLC_MAX_VIDEOS = 8

CONST VLC_STOPPED = 0
CONST VLC_PLAYING = 1
CONST VLC_PAUSED = 2

DECLARE LIBRARY "qbvlc"
    FUNCTION qbvlc_probe& ()
    FUNCTION qbvlc_last_error& ()
    FUNCTION qbvlc_open& (path AS STRING, BYVAL w AS LONG, BYVAL h AS LONG)
    SUB qbvlc_close (BYVAL h AS LONG)
    SUB qbvlc_shutdown ()
    FUNCTION qbvlc_acquire%& (BYVAL h AS LONG)
    FUNCTION qbvlc_stage_w& (BYVAL h AS LONG)
    FUNCTION qbvlc_stage_h& (BYVAL h AS LONG)
    FUNCTION qbvlc_native_w& (BYVAL h AS LONG)
    FUNCTION qbvlc_native_h& (BYVAL h AS LONG)
    FUNCTION qbvlc_frames& (BYVAL h AS LONG)
    FUNCTION qbvlc_state& (BYVAL h AS LONG)
    SUB qbvlc_pause (BYVAL h AS LONG, BYVAL p AS LONG)
    SUB qbvlc_seek (BYVAL h AS LONG, BYVAL ms AS LONG)
    FUNCTION qbvlc_time& (BYVAL h AS LONG)
    FUNCTION qbvlc_length& (BYVAL h AS LONG)
    SUB qbvlc_set_volume (BYVAL h AS LONG, BYVAL v AS LONG)
    FUNCTION qbvlc_get_volume& (BYVAL h AS LONG)
    SUB qbvlc_mute (BYVAL h AS LONG, BYVAL m AS LONG)
    SUB qbvlc_restart (BYVAL h AS LONG)
    FUNCTION qbvlc_fps& (BYVAL h AS LONG)
END DECLARE

TYPE VLCH_SLOT
    InUse AS INTEGER
    Img AS LONG
    W AS LONG
    H AS LONG
    State AS INTEGER
    Finished AS INTEGER
    Looping AS INTEGER
    LimitSec AS SINGLE
    Volume AS SINGLE
    NewFrame AS INTEGER
    LoopT AS DOUBLE
END TYPE

DIM SHARED VLCX(1 TO VLC_MAX_VIDEOS) AS VLCH_SLOT
DIM SHARED VLC_BLANK AS VLCH_SLOT
DIM SHARED VLC_ERRMSG AS STRING

'=============================================================================
'  PUBLIC API
'=============================================================================

FUNCTION VLCOPEN& (FileName$)
    VLCOPEN = VLC_OPEN_INT(FileName$, 0, 0)
END FUNCTION

' Like VLCOPEN, but VLC scales the picture down (aspect kept) to fit inside
' BoxW x BoxH while decoding, which is much cheaper than scaling every frame in
' BASIC.  Videos smaller than the box keep their native size.
FUNCTION VLCOPENFIT& (FileName$, BoxW AS LONG, BoxH AS LONG)
    IF BoxW < 1 OR BoxH < 1 THEN
        VLCOPENFIT = VLC_OPEN_INT(FileName$, 0, 0)
    ELSE
        VLCOPENFIT = VLC_OPEN_INT(FileName$, -BoxW, -BoxH)
    END IF
END FUNCTION

' Native size of the video (VLCWIDTH / VLCHEIGHT give the decoded size)
FUNCTION VLCNATIVEW& (h AS LONG)
    VLCNATIVEW = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCNATIVEW = qbvlc_native_w(h)
END FUNCTION

FUNCTION VLCNATIVEH& (h AS LONG)
    VLCNATIVEH = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCNATIVEH = qbvlc_native_h(h)
END FUNCTION

FUNCTION VLC_OPEN_INT& (FileName$, ReqW AS LONG, ReqH AS LONG)
    DIM h AS LONG
    VLC_OPEN_INT = 0
    VLC_ERRMSG = ""
    IF INSTR(FileName$, "://") = 0 THEN
        IF NOT _FILEEXISTS(FileName$) THEN
            VLC_ERRMSG = "File not found: " + FileName$
            EXIT FUNCTION
        END IF
    END IF
    h = qbvlc_open(FileName$ + CHR$(0), ReqW, ReqH)
    IF h = 0 THEN
        VLC_ERRMSG = VLC_ERRTEXT$
        EXIT FUNCTION
    END IF
    VLCX(h) = VLC_BLANK
    VLCX(h).InUse = _TRUE
    VLCX(h).Volume = 1
    IF NOT VLC_PRIME(h) THEN
        VLC_CLOSE_INT h
        EXIT FUNCTION
    END IF
    VLC_OPEN_INT = h
END FUNCTION

SUB VLCPLAY (h AS LONG)
    IF NOT VLC_VALID(h) THEN EXIT SUB
    VLC_PLAY_INT h, _FALSE
END SUB

SUB VLCLOOP (h AS LONG)
    IF NOT VLC_VALID(h) THEN EXIT SUB
    VLC_PLAY_INT h, _TRUE
END SUB

SUB VLCPAUSE (h AS LONG)
    IF NOT VLC_VALID(h) THEN EXIT SUB
    IF VLCX(h).State = VLC_PLAYING THEN
        qbvlc_pause h, 1
        VLCX(h).State = VLC_PAUSED
    END IF
END SUB

SUB VLCSTOP (h AS LONG)
    IF NOT VLC_VALID(h) THEN EXIT SUB
    IF VLCX(h).State = VLC_PLAYING THEN qbvlc_pause h, 1
    VLC_REWIND h
    VLCX(h).State = VLC_STOPPED
    VLCX(h).Finished = _FALSE
END SUB

SUB VLCSETPOS (h AS LONG, Secs AS SINGLE)
    DIM T AS SINGLE
    DIM Restarted AS INTEGER
    IF NOT VLC_VALID(h) THEN EXIT SUB
    T = Secs
    IF T < 0 THEN T = 0
    Restarted = (qbvlc_state(h) >= 5)
    IF Restarted THEN VLC_REWIND h
    qbvlc_seek h, INT(T * 1000)
    VLCX(h).Finished = _FALSE
    IF Restarted AND VLCX(h).State = VLC_PLAYING THEN qbvlc_pause h, 0
END SUB

SUB VLCVOL (h AS LONG, Vol AS SINGLE)
    IF NOT VLC_VALID(h) THEN EXIT SUB
    IF Vol < 0 THEN Vol = 0
    IF Vol > 2 THEN Vol = 2
    VLCX(h).Volume = Vol
    VLC_APPLY_VOL h
END SUB

SUB VLCLIMIT (h AS LONG, Secs AS SINGLE)
    IF NOT VLC_VALID(h) THEN EXIT SUB
    VLCX(h).LimitSec = Secs
END SUB

SUB VLCCLOSE (h AS LONG)
    IF NOT VLC_VALID(h) THEN EXIT SUB
    VLC_CLOSE_INT h
END SUB

SUB VLCCLOSEALL
    DIM h AS LONG
    FOR h = 1 TO VLC_MAX_VIDEOS
        IF VLCX(h).InUse THEN VLC_CLOSE_INT h
    NEXT
    qbvlc_shutdown
END SUB

FUNCTION VLCPLAYING% (h AS LONG)
    VLCPLAYING = _FALSE
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLC_SERVICE h
    VLCPLAYING = (VLCX(h).State = VLC_PLAYING)
END FUNCTION

FUNCTION VLCPAUSED% (h AS LONG)
    VLCPAUSED = _FALSE
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLC_SERVICE h
    VLCPAUSED = (VLCX(h).State = VLC_PAUSED)
END FUNCTION

FUNCTION VLCLEN# (h AS LONG)
    DIM L AS LONG
    VLCLEN = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    L = qbvlc_length(h)
    IF L < 0 THEN L = 0
    VLCLEN = L / 1000
END FUNCTION

FUNCTION VLCGETPOS# (h AS LONG)
    DIM T AS LONG
    VLCGETPOS = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLC_SERVICE h
    T = qbvlc_time(h)
    IF qbvlc_state(h) >= 5 THEN T = qbvlc_length(h)
    IF T < 0 THEN T = 0
    VLCGETPOS = T / 1000
END FUNCTION

FUNCTION VLCIMAGE& (h AS LONG)
    VLCIMAGE = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLC_SERVICE h
    VLCIMAGE = VLCX(h).Img
END FUNCTION

FUNCTION VLCWIDTH& (h AS LONG)
    VLCWIDTH = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCWIDTH = VLCX(h).W
END FUNCTION

FUNCTION VLCHEIGHT& (h AS LONG)
    VLCHEIGHT = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCHEIGHT = VLCX(h).H
END FUNCTION

FUNCTION VLCFPS# (h AS LONG)
    VLCFPS = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCFPS = qbvlc_fps(h) / 1000
END FUNCTION

FUNCTION VLCFRAMES& (h AS LONG)
    VLCFRAMES = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCFRAMES = INT(VLCLEN(h) * VLCFPS(h) + .5)
END FUNCTION

FUNCTION VLCFRAME& (h AS LONG)
    VLCFRAME = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCFRAME = INT(VLCGETPOS(h) * VLCFPS(h))
END FUNCTION

FUNCTION VLCNEWFRAME% (h AS LONG)
    VLCNEWFRAME = _FALSE
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLC_SERVICE h
    IF VLCX(h).NewFrame THEN
        VLCX(h).NewFrame = _FALSE
        VLCNEWFRAME = _TRUE
    END IF
END FUNCTION

FUNCTION VLCERROR$
    VLCERROR = VLC_ERRMSG
END FUNCTION

' Aspect / crop, same meaning as SPVASPECT / SPVCROPX / SPVCROPW.  Standard
' videos have no hint and no bars to crop: the picture is the whole image.
FUNCTION VLCHINT$ (h AS LONG)
    VLCHINT = ""
END FUNCTION

FUNCTION VLCASPECT# (h AS LONG)
    VLCASPECT = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    IF VLCX(h).H > 0 THEN VLCASPECT = VLCX(h).W / VLCX(h).H
END FUNCTION

FUNCTION VLCCROPX& (h AS LONG)
    VLCCROPX = 0
END FUNCTION

FUNCTION VLCCROPW& (h AS LONG)
    VLCCROPW = 0
    IF NOT VLC_VALID(h) THEN EXIT FUNCTION
    VLCCROPW = VLCX(h).W
END FUNCTION

' Optional: call from your main loop if you never call a status function
' (VLCIMAGE, VLCNEWFRAME, VLCPLAYING ...) but still want loops/limits honored.
' Do NOT call it from an ON TIMER handler.
SUB VLCTICK
    DIM h AS LONG
    FOR h = 1 TO VLC_MAX_VIDEOS
        IF VLCX(h).InUse THEN VLC_SERVICE h
    NEXT
END SUB

'=============================================================================
'  INTERNALS
'=============================================================================

FUNCTION VLC_VALID% (h AS LONG)
    VLC_VALID = _FALSE
    IF h < 1 OR h > VLC_MAX_VIDEOS THEN EXIT FUNCTION
    VLC_VALID = VLCX(h).InUse
END FUNCTION

FUNCTION VLC_ELAPSED# (T0 AS DOUBLE)
    DIM D AS DOUBLE
    D = TIMER - T0
    IF D < 0 THEN D = D + 86400
    VLC_ELAPSED = D
END FUNCTION

FUNCTION VLC_ERRTEXT$
    SELECT CASE qbvlc_last_error
        CASE 0: VLC_ERRTEXT = "No error"
        CASE 1: VLC_ERRTEXT = "libvlc could not be loaded (VLC 3.x is not installed, or its 32/64-bit or Intel/ARM build does not match this program)"
        CASE 2: VLC_ERRTEXT = "libvlc is missing a required function (VLC 3.x is needed, not 4.x)"
        CASE 3: VLC_ERRTEXT = "libvlc_new failed (VLC plugins not found?)"
        CASE 4: VLC_ERRTEXT = "Could not create media (bad path or URL?)"
        CASE 5: VLC_ERRTEXT = "No free video handles (max" + STR$(VLC_MAX_VIDEOS) + ")"
        CASE 6: VLC_ERRTEXT = "Could not create media player"
        CASE 7: VLC_ERRTEXT = "Playback could not be started"
        CASE ELSE: VLC_ERRTEXT = "Unknown libvlc error"
    END SELECT
END FUNCTION

SUB VLC_APPLY_VOL (h AS LONG)
    qbvlc_set_volume h, INT(VLCX(h).Volume * 100 + .5)
END SUB

' Wait for the first frame, park on it (paused, muted while priming), create the
' image.  The video is left STOPPED on frame 0, like SPVOPEN.
FUNCTION VLC_PRIME% (h AS LONG)
    DIM T0 AS DOUBLE
    DIM F0 AS LONG
    VLC_PRIME = _FALSE
    qbvlc_mute h, 1
    T0 = TIMER
    DO WHILE qbvlc_frames(h) < 1
        IF qbvlc_state(h) = 7 THEN
            VLC_ERRMSG = "VLC could not play this file"
            EXIT FUNCTION
        END IF
        IF VLC_ELAPSED(T0) > 10 THEN
            VLC_ERRMSG = "Timed out waiting for the first video frame (audio-only file?)"
            EXIT FUNCTION
        END IF
        _DELAY 0.005
    LOOP
    qbvlc_pause h, 1
    F0 = qbvlc_frames(h)
    qbvlc_seek h, 0
    T0 = TIMER
    DO WHILE qbvlc_frames(h) <= F0 AND VLC_ELAPSED(T0) < .5
        _DELAY 0.005
    LOOP
    VLC_PULL h
    IF VLCX(h).Img = 0 THEN
        VLC_ERRMSG = "No video frame could be decoded"
        EXIT FUNCTION
    END IF
    VLCX(h).State = VLC_STOPPED
    VLCX(h).NewFrame = _TRUE
    qbvlc_mute h, 0
    VLC_APPLY_VOL h
    VLC_PRIME = _TRUE
END FUNCTION

' Copy the newest decoded frame (if any) into the video's image.
SUB VLC_PULL (h AS LONG)
    DIM P AS _OFFSET
    DIM PW AS LONG, PH AS LONG, N AS LONG
    DIM Src AS _MEM, Dst AS _MEM
    P = qbvlc_acquire(h)
    IF P = 0 THEN EXIT SUB
    PW = qbvlc_stage_w(h): PH = qbvlc_stage_h(h)
    IF PW < 1 OR PH < 1 THEN EXIT SUB
    IF PW <> VLCX(h).W OR PH <> VLCX(h).H THEN
        IF VLCX(h).Img < -1 THEN _FREEIMAGE VLCX(h).Img
        VLCX(h).Img = _NEWIMAGE(PW, PH, 32)
        VLCX(h).W = PW: VLCX(h).H = PH
    END IF
    N = PW * PH * 4
    Src = _MEM(P, N)
    Dst = _MEMIMAGE(VLCX(h).Img)
    IF Dst.SIZE = N THEN
        _MEMCOPY Src, Src.OFFSET, N TO Dst, Dst.OFFSET
        VLCX(h).NewFrame = _TRUE
    END IF
    _MEMFREE Dst
END SUB

SUB VLC_PLAY_INT (h AS LONG, LoopIt AS INTEGER)
    VLCX(h).Looping = LoopIt
    SELECT CASE VLCX(h).State
        CASE VLC_PAUSED
            qbvlc_pause h, 0
            VLCX(h).State = VLC_PLAYING
        CASE VLC_STOPPED
            IF VLCX(h).Finished THEN VLC_REWIND h
            VLC_APPLY_VOL h
            qbvlc_pause h, 0
            VLCX(h).Finished = _FALSE
            VLCX(h).State = VLC_PLAYING
    END SELECT
END SUB

' Go back to the start and park (paused).  If libvlc has already ended the
' stream it must be restarted first (libvlc 3.x cannot seek after the end).
SUB VLC_REWIND (h AS LONG)
    DIM T0 AS DOUBLE
    IF qbvlc_state(h) >= 5 THEN
        qbvlc_mute h, 1
        qbvlc_restart h
        T0 = TIMER
        DO WHILE qbvlc_frames(h) < 1 AND VLC_ELAPSED(T0) < 3
            _DELAY 0.005
        LOOP
        qbvlc_pause h, 1
        qbvlc_mute h, 0
    END IF
    qbvlc_seek h, 0
END SUB

' Pull the newest frame and apply loop / limit / end-of-video rules.
SUB VLC_SERVICE (h AS LONG)
    DIM St AS LONG, Tm AS LONG, Ln AS LONG
    VLC_PULL h
    IF VLCX(h).State <> VLC_PLAYING THEN EXIT SUB
    St = qbvlc_state(h)
    Tm = qbvlc_time(h)
    Ln = qbvlc_length(h)

    IF VLCX(h).LimitSec > 0 AND Tm >= 0 THEN
        IF Tm >= VLCX(h).LimitSec * 1000 THEN
            IF VLCX(h).Looping THEN
                qbvlc_seek h, 0
            ELSE
                qbvlc_pause h, 1
                VLCX(h).State = VLC_STOPPED
                VLCX(h).Finished = _TRUE
            END IF
            EXIT SUB
        END IF
    END IF

    IF St >= 5 THEN
        ' ended, stopped or error
        IF VLCX(h).Looping AND St <> 7 THEN
            VLC_REWIND h
            qbvlc_pause h, 0
        ELSE
            VLCX(h).State = VLC_STOPPED
            VLCX(h).Finished = _TRUE
        END IF
    ELSEIF VLCX(h).Looping AND Ln > 0 AND Tm >= 0 THEN
        ' loop a hair before the end so there is no "ended" gap
        IF Tm >= Ln - 80 AND VLC_ELAPSED(VLCX(h).LoopT) > .5 THEN
            qbvlc_seek h, 0
            VLCX(h).LoopT = TIMER
        END IF
    END IF
END SUB

SUB VLC_CLOSE_INT (h AS LONG)
    qbvlc_close h
    IF VLCX(h).Img < -1 THEN _FREEIMAGE VLCX(h).Img
    VLCX(h) = VLC_BLANK
END SUB
