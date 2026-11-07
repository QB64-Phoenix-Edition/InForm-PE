'-----------------------------------------------------------------------------------------------------------------------
' Handle based video library (libvlc 3.x)
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$IncludeOnce
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

Const VLC_MAX_VIDEOS = 8

Const VLC_STOPPED = 0
Const VLC_PLAYING = 1
Const VLC_PAUSED = 2

Declare Library "qbvlc"
    Function qbvlc_probe& ()
    Function qbvlc_last_error& ()
    Function qbvlc_open& (path As String, Byval w As Long, Byval h As Long)
    Sub qbvlc_close (Byval h As Long)
    Sub qbvlc_shutdown ()
    Function qbvlc_acquire%& (Byval h As Long)
    Function qbvlc_stage_w& (Byval h As Long)
    Function qbvlc_stage_h& (Byval h As Long)
    Function qbvlc_native_w& (Byval h As Long)
    Function qbvlc_native_h& (Byval h As Long)
    Function qbvlc_frames& (Byval h As Long)
    Function qbvlc_state& (Byval h As Long)
    Sub qbvlc_pause (Byval h As Long, Byval p As Long)
    Sub qbvlc_seek (Byval h As Long, Byval ms As Long)
    Function qbvlc_time& (Byval h As Long)
    Function qbvlc_length& (Byval h As Long)
    Sub qbvlc_set_volume (Byval h As Long, Byval v As Long)
    Function qbvlc_get_volume& (Byval h As Long)
    Sub qbvlc_mute (Byval h As Long, Byval m As Long)
    Sub qbvlc_restart (Byval h As Long)
    Function qbvlc_fps& (Byval h As Long)
End Declare

Type VLCH_SLOT
    InUse As Integer
    Img As Long
    W As Long
    H As Long
    State As Integer
    Finished As Integer
    Looping As Integer
    LimitSec As Single
    Volume As Single
    NewFrame As Integer
    LoopT As Double
End Type

Dim Shared VLCX(1 To VLC_MAX_VIDEOS) As VLCH_SLOT
Dim Shared VLC_BLANK As VLCH_SLOT
Dim Shared VLC_ERRMSG As String

'=============================================================================
'  PUBLIC API
'=============================================================================

Function VLCOPEN& (FileName$)
    VLCOPEN = VLC_OPEN_INT(FileName$, 0, 0)
End Function

' Like VLCOPEN, but VLC scales the picture down (aspect kept) to fit inside
' BoxW x BoxH while decoding, which is much cheaper than scaling every frame in
' BASIC.  Videos smaller than the box keep their native size.
Function VLCOPENFIT& (FileName$, BoxW As Long, BoxH As Long)
    If BoxW < 1 Or BoxH < 1 Then
        VLCOPENFIT = VLC_OPEN_INT(FileName$, 0, 0)
    Else
        VLCOPENFIT = VLC_OPEN_INT(FileName$, -BoxW, -BoxH)
    End If
End Function

' Native size of the video (VLCWIDTH / VLCHEIGHT give the decoded size)
Function VLCNATIVEW& (h As Long)
    VLCNATIVEW = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCNATIVEW = qbvlc_native_w(h)
End Function

Function VLCNATIVEH& (h As Long)
    VLCNATIVEH = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCNATIVEH = qbvlc_native_h(h)
End Function

Function VLC_OPEN_INT& (FileName$, ReqW As Long, ReqH As Long)
    Dim h As Long
    VLC_OPEN_INT = 0
    VLC_ERRMSG = ""
    If InStr(FileName$, "://") = 0 Then
        If Not _FileExists(FileName$) Then
            VLC_ERRMSG = "File not found: " + FileName$
            Exit Function
        End If
    End If
    h = qbvlc_open(FileName$ + Chr$(0), ReqW, ReqH)
    If h = 0 Then
        VLC_ERRMSG = VLC_ERRTEXT$
        Exit Function
    End If
    VLCX(h) = VLC_BLANK
    VLCX(h).InUse = _TRUE
    VLCX(h).Volume = 1
    If Not VLC_PRIME(h) Then
        VLC_CLOSE_INT h
        Exit Function
    End If
    VLC_OPEN_INT = h
End Function

Sub VLCPLAY (h As Long)
    If Not VLC_VALID(h) Then Exit Sub
    VLC_PLAY_INT h, _FALSE
End Sub

Sub VLCLOOP (h As Long)
    If Not VLC_VALID(h) Then Exit Sub
    VLC_PLAY_INT h, _TRUE
End Sub

Sub VLCPAUSE (h As Long)
    If Not VLC_VALID(h) Then Exit Sub
    If VLCX(h).State = VLC_PLAYING Then
        qbvlc_pause h, 1
        VLCX(h).State = VLC_PAUSED
    End If
End Sub

Sub VLCSTOP (h As Long)
    If Not VLC_VALID(h) Then Exit Sub
    If VLCX(h).State = VLC_PLAYING Then qbvlc_pause h, 1
    VLC_REWIND h
    VLCX(h).State = VLC_STOPPED
    VLCX(h).Finished = _FALSE
End Sub

Sub VLCSETPOS (h As Long, Secs As Single)
    Dim T As Single
    Dim Restarted As Integer
    If Not VLC_VALID(h) Then Exit Sub
    T = Secs
    If T < 0 Then T = 0
    Restarted = (qbvlc_state(h) >= 5)
    If Restarted Then VLC_REWIND h
    qbvlc_seek h, Int(T * 1000)
    VLCX(h).Finished = _FALSE
    If Restarted And VLCX(h).State = VLC_PLAYING Then qbvlc_pause h, 0
End Sub

Sub VLCVOL (h As Long, Vol As Single)
    If Not VLC_VALID(h) Then Exit Sub
    If Vol < 0 Then Vol = 0
    If Vol > 2 Then Vol = 2
    VLCX(h).Volume = Vol
    VLC_APPLY_VOL h
End Sub

Sub VLCLIMIT (h As Long, Secs As Single)
    If Not VLC_VALID(h) Then Exit Sub
    VLCX(h).LimitSec = Secs
End Sub

Sub VLCCLOSE (h As Long)
    If Not VLC_VALID(h) Then Exit Sub
    VLC_CLOSE_INT h
End Sub

Sub VLCCLOSEALL
    Dim h As Long
    For h = 1 To VLC_MAX_VIDEOS
        If VLCX(h).InUse Then VLC_CLOSE_INT h
    Next
    qbvlc_shutdown
End Sub

Function VLCPLAYING% (h As Long)
    VLCPLAYING = _FALSE
    If Not VLC_VALID(h) Then Exit Function
    VLC_SERVICE h
    VLCPLAYING = (VLCX(h).State = VLC_PLAYING)
End Function

Function VLCPAUSED% (h As Long)
    VLCPAUSED = _FALSE
    If Not VLC_VALID(h) Then Exit Function
    VLC_SERVICE h
    VLCPAUSED = (VLCX(h).State = VLC_PAUSED)
End Function

Function VLCLEN# (h As Long)
    Dim L As Long
    VLCLEN = 0
    If Not VLC_VALID(h) Then Exit Function
    L = qbvlc_length(h)
    If L < 0 Then L = 0
    VLCLEN = L / 1000
End Function

Function VLCGETPOS# (h As Long)
    Dim T As Long
    VLCGETPOS = 0
    If Not VLC_VALID(h) Then Exit Function
    VLC_SERVICE h
    T = qbvlc_time(h)
    If qbvlc_state(h) >= 5 Then T = qbvlc_length(h)
    If T < 0 Then T = 0
    VLCGETPOS = T / 1000
End Function

Function VLCIMAGE& (h As Long)
    VLCIMAGE = 0
    If Not VLC_VALID(h) Then Exit Function
    VLC_SERVICE h
    VLCIMAGE = VLCX(h).Img
End Function

Function VLCWIDTH& (h As Long)
    VLCWIDTH = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCWIDTH = VLCX(h).W
End Function

Function VLCHEIGHT& (h As Long)
    VLCHEIGHT = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCHEIGHT = VLCX(h).H
End Function

Function VLCFPS# (h As Long)
    VLCFPS = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCFPS = qbvlc_fps(h) / 1000
End Function

Function VLCFRAMES& (h As Long)
    VLCFRAMES = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCFRAMES = Int(VLCLEN(h) * VLCFPS(h) + .5)
End Function

Function VLCFRAME& (h As Long)
    VLCFRAME = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCFRAME = Int(VLCGETPOS(h) * VLCFPS(h))
End Function

Function VLCNEWFRAME% (h As Long)
    VLCNEWFRAME = _FALSE
    If Not VLC_VALID(h) Then Exit Function
    VLC_SERVICE h
    If VLCX(h).NewFrame Then
        VLCX(h).NewFrame = _FALSE
        VLCNEWFRAME = _TRUE
    End If
End Function

Function VLCERROR$
    VLCERROR = VLC_ERRMSG
End Function

' Aspect / crop, same meaning as SPVASPECT / SPVCROPX / SPVCROPW.  Standard
' videos have no hint and no bars to crop: the picture is the whole image.
Function VLCHINT$ (h As Long)
    VLCHINT = ""
End Function

Function VLCASPECT# (h As Long)
    VLCASPECT = 0
    If Not VLC_VALID(h) Then Exit Function
    If VLCX(h).H > 0 Then VLCASPECT = VLCX(h).W / VLCX(h).H
End Function

Function VLCCROPX& (h As Long)
    VLCCROPX = 0
End Function

Function VLCCROPW& (h As Long)
    VLCCROPW = 0
    If Not VLC_VALID(h) Then Exit Function
    VLCCROPW = VLCX(h).W
End Function

' Optional: call from your main loop if you never call a status function
' (VLCIMAGE, VLCNEWFRAME, VLCPLAYING ...) but still want loops/limits honored.
' Do NOT call it from an ON TIMER handler.
Sub VLCTICK
    Dim h As Long
    For h = 1 To VLC_MAX_VIDEOS
        If VLCX(h).InUse Then VLC_SERVICE h
    Next
End Sub

'=============================================================================
'  INTERNALS
'=============================================================================

Function VLC_VALID% (h As Long)
    VLC_VALID = _FALSE
    If h < 1 Or h > VLC_MAX_VIDEOS Then Exit Function
    VLC_VALID = VLCX(h).InUse
End Function

Function VLC_ELAPSED# (T0 As Double)
    Dim D As Double
    D = Timer - T0
    If D < 0 Then D = D + 86400
    VLC_ELAPSED = D
End Function

Function VLC_ERRTEXT$
    Select Case qbvlc_last_error
        Case 0: VLC_ERRTEXT = "No error"
        Case 1: VLC_ERRTEXT = "libvlc could not be loaded (VLC 3.x is not installed, or its 32/64-bit or Intel/ARM build does not match this program)"
        Case 2: VLC_ERRTEXT = "libvlc is missing a required function (VLC 3.x is needed, not 4.x)"
        Case 3: VLC_ERRTEXT = "libvlc_new failed (VLC plugins not found?)"
        Case 4: VLC_ERRTEXT = "Could not create media (bad path or URL?)"
        Case 5: VLC_ERRTEXT = "No free video handles (max" + Str$(VLC_MAX_VIDEOS) + ")"
        Case 6: VLC_ERRTEXT = "Could not create media player"
        Case 7: VLC_ERRTEXT = "Playback could not be started"
        Case Else: VLC_ERRTEXT = "Unknown libvlc error"
    End Select
End Function

Sub VLC_APPLY_VOL (h As Long)
    qbvlc_set_volume h, Int(VLCX(h).Volume * 100 + .5)
End Sub

' Wait for the first frame, park on it (paused, muted while priming), create the
' image.  The video is left STOPPED on frame 0, like SPVOPEN.
Function VLC_PRIME% (h As Long)
    Dim T0 As Double
    Dim F0 As Long
    VLC_PRIME = _FALSE
    qbvlc_mute h, 1
    T0 = Timer
    Do While qbvlc_frames(h) < 1
        If qbvlc_state(h) = 7 Then
            VLC_ERRMSG = "VLC could not play this file"
            Exit Function
        End If
        If VLC_ELAPSED(T0) > 10 Then
            VLC_ERRMSG = "Timed out waiting for the first video frame (audio-only file?)"
            Exit Function
        End If
        _Delay 0.005
    Loop
    qbvlc_pause h, 1
    F0 = qbvlc_frames(h)
    qbvlc_seek h, 0
    T0 = Timer
    Do While qbvlc_frames(h) <= F0 And VLC_ELAPSED(T0) < .5
        _Delay 0.005
    Loop
    VLC_PULL h
    If VLCX(h).Img = 0 Then
        VLC_ERRMSG = "No video frame could be decoded"
        Exit Function
    End If
    VLCX(h).State = VLC_STOPPED
    VLCX(h).NewFrame = _TRUE
    qbvlc_mute h, 0
    VLC_APPLY_VOL h
    VLC_PRIME = _TRUE
End Function

' Copy the newest decoded frame (if any) into the video's image.
Sub VLC_PULL (h As Long)
    Dim P As _Offset
    Dim PW As Long, PH As Long, N As Long
    Dim Src As _MEM, Dst As _MEM
    P = qbvlc_acquire(h)
    If P = 0 Then Exit Sub
    PW = qbvlc_stage_w(h): PH = qbvlc_stage_h(h)
    If PW < 1 Or PH < 1 Then Exit Sub
    If PW <> VLCX(h).W Or PH <> VLCX(h).H Then
        If VLCX(h).Img < -1 Then _FreeImage VLCX(h).Img
        VLCX(h).Img = _NewImage(PW, PH, 32)
        VLCX(h).W = PW: VLCX(h).H = PH
    End If
    N = PW * PH * 4
    Src = _Mem(P, N)
    Dst = _MemImage(VLCX(h).Img)
    If Dst.SIZE = N Then
        _MemCopy Src, Src.OFFSET, N To Dst, Dst.OFFSET
        VLCX(h).NewFrame = _TRUE
    End If
    _MemFree Dst
End Sub

Sub VLC_PLAY_INT (h As Long, LoopIt As Integer)
    VLCX(h).Looping = LoopIt
    Select Case VLCX(h).State
        Case VLC_PAUSED
            qbvlc_pause h, 0
            VLCX(h).State = VLC_PLAYING
        Case VLC_STOPPED
            If VLCX(h).Finished Then VLC_REWIND h
            VLC_APPLY_VOL h
            qbvlc_pause h, 0
            VLCX(h).Finished = _FALSE
            VLCX(h).State = VLC_PLAYING
    End Select
End Sub

' Go back to the start and park (paused).  If libvlc has already ended the
' stream it must be restarted first (libvlc 3.x cannot seek after the end).
Sub VLC_REWIND (h As Long)
    Dim T0 As Double
    If qbvlc_state(h) >= 5 Then
        qbvlc_mute h, 1
        qbvlc_restart h
        T0 = Timer
        Do While qbvlc_frames(h) < 1 And VLC_ELAPSED(T0) < 3
            _Delay 0.005
        Loop
        qbvlc_pause h, 1
        qbvlc_mute h, 0
    End If
    qbvlc_seek h, 0
End Sub

' Pull the newest frame and apply loop / limit / end-of-video rules.
Sub VLC_SERVICE (h As Long)
    Dim St As Long, Tm As Long, Ln As Long
    VLC_PULL h
    If VLCX(h).State <> VLC_PLAYING Then Exit Sub
    St = qbvlc_state(h)
    Tm = qbvlc_time(h)
    Ln = qbvlc_length(h)

    If VLCX(h).LimitSec > 0 And Tm >= 0 Then
        If Tm >= VLCX(h).LimitSec * 1000 Then
            If VLCX(h).Looping Then
                qbvlc_seek h, 0
            Else
                qbvlc_pause h, 1
                VLCX(h).State = VLC_STOPPED
                VLCX(h).Finished = _TRUE
            End If
            Exit Sub
        End If
    End If

    If St >= 5 Then
        ' ended, stopped or error
        If VLCX(h).Looping And St <> 7 Then
            VLC_REWIND h
            qbvlc_pause h, 0
        Else
            VLCX(h).State = VLC_STOPPED
            VLCX(h).Finished = _TRUE
        End If
    ElseIf VLCX(h).Looping And Ln > 0 And Tm >= 0 Then
        ' loop a hair before the end so there is no "ended" gap
        If Tm >= Ln - 80 And VLC_ELAPSED(VLCX(h).LoopT) > .5 Then
            qbvlc_seek h, 0
            VLCX(h).LoopT = Timer
        End If
    End If
End Sub

Sub VLC_CLOSE_INT (h As Long)
    qbvlc_close h
    If VLCX(h).Img < -1 Then _FreeImage VLCX(h).Img
    VLCX(h) = VLC_BLANK
End Sub
