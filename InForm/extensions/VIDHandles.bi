'-----------------------------------------------------------------------------------------------------------------------
' SPV + VLC video wrapper
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$IncludeOnce
'=============================================================================
'  VIDHandles.bi  (VID-HANDLES.BM in the original distribution)    -    WRAPPER over SPV-HANDLES.BM and VLC-HANDLES.BM
'
'  One set of commands for every video.  VIDOPEN looks at the file and picks
'  the library:
'
'       first 4 bytes = "SPRV"  (or a .SPV name that failed that test)  -> SPV
'       anything else, or a URL ("://")                                 -> VLC
'
'  Every other VID command remembers which library owns the handle and calls
'  the matching SPV... or VLC... command.  Wrapper handles are their own
'  numbers (1 to VID_MAX_VIDEOS), so an SPV handle and a VLC handle can never
'  be confused.
'
'  Same calling convention as both libraries (and _SNDOPEN / _SNDPLAY):
'
'  h& = VIDOPEN(file$)      h& = VIDOPENFIT(file$, w&, h&)   VIDNATIVEW&  VIDNATIVEH&  VIDGETVOL!
'  VIDPLAY h&        VIDLOOP h&       VIDPAUSE h&
'  VIDSTOP h&               VIDPLAYING(h&)    VIDPAUSED(h&)    VIDLEN#(h&)
'  VIDGETPOS#(h&)           VIDSETPOS h&, s!  VIDVOL h&, v!    VIDLIMIT h&, s!
'  VIDCLOSE h&              VIDCLOSEALL
'  VIDIMAGE&(h&)  VIDNEWFRAME%(h&)  VIDWIDTH&  VIDHEIGHT&  VIDFPS#
'  VIDFRAMES&  VIDFRAME&    VIDERROR$         VIDTYPE%(h&)   VIDTICK
'
'  ASPECT / CROP (SPV "hint" byte N,W,T,K; standard videos use the whole image):
'  VIDHINT$(h&)    VIDASPECT#(h&)  display aspect ratio, width / height
'  VIDCROPX&(h&)   VIDCROPW&(h&)   the picture's left edge and width inside
'                                  VIDIMAGE (top is 0, height is VIDHEIGHT)
'  VIDPUT h&, x1, y1, x2, y2       draws the current frame into that box with the
'                                  right shape (crop + aspect, letterboxed and
'                                  centered) onto the current _DEST.  Use this
'                                  instead of _PUTIMAGE , VIDIMAGE(h&)
'
'  VIDGETINFO h&, Info AS VIDINFO   fills a record describing the video
'  VIDSETFPS h&, fps#  VIDNOMFPS#(h&)   SPV only: change / read the frame rate
'
'  VIDTYPE%(h&) returns VID_TYPE_SPV (1) or VID_TYPE_VLC (2).
'
'  TIMER:  only SPV videos need ON TIMER.  Start it once in your main program
'  exactly as before (it does no harm if you only play VLC videos):
'
'       T1 = _FREETIMER
'       ON TIMER(T1, VID_TICK_SECONDS) VIDTICK
'       TIMER(T1) ON
'
'  Include this file ONCE, at the top of your program.  It includes the two
'  libraries itself (VLC first, because it contains a DECLARE LIBRARY block).
'  Do not also include SPV-HANDLES.BM or VLC-HANDLES.BM by hand.
'=============================================================================

'$INCLUDE:'VLCHandles.bi'
'$INCLUDE:'SPVHandles.bi'
'$INCLUDE:'SPVAspect.bi'
'$INCLUDE:'SPVExtra.bi'

Const VID_TYPE_SPV = 1
Const VID_TYPE_VLC = 2
Const VID_MAX_VIDEOS = SPV_MAX_VIDEOS + VLC_MAX_VIDEOS
Const VID_TICK_SECONDS = SPV_TICK_SECONDS

Type VIDH_SLOT
    InUse As Integer
    Lib As Integer
    H As Long
End Type

Type VIDINFO
    Lib As Integer
    VType As Integer
    NumFrames As Long
    FrameW As Long
    FrameH As Long
    BPP As Integer
    FPSByte As Integer
    FPSEncoded As Double
    FPSTrue As Double
    Length As Double
    Hint As String * 1
    IsMJPG As Integer
    IsSprite As Integer
    IsVGA As Integer
    IsPadded As Integer
    Full24 As Integer
    PalBits As Integer
    FrameBufSize As Long
    PalBufSize As Long
    SprW As Long
    SprH As Long
    NumSprites As Long
    AudioSeparate As Integer
    AudioFileSize As _Integer64
    AudioFrameSize As Long
    Is16 As Integer
    Channels As Integer
    SampleRate As Long
    RateFromFPS As Integer
    VeraRate As Integer
End Type

Dim Shared VIDX(1 To VID_MAX_VIDEOS) As VIDH_SLOT
Dim Shared VID_ERRMSG As String

'=============================================================================
'  PUBLIC API
'=============================================================================

Function VIDOPEN& (FileName$)
    VIDOPEN = VID_OPEN_INT(FileName$, 0, 0)
End Function

' Like VIDOPEN, but a VLC video is decoded shrunk to fit inside BoxW x BoxH
' (see VLCOPENFIT).  SPV videos are always decoded at their own size.
Function VIDOPENFIT& (FileName$, BoxW As Long, BoxH As Long)
    VIDOPENFIT = VID_OPEN_INT(FileName$, BoxW, BoxH)
End Function

' Native size of the video (for VLC, VIDWIDTH / VIDHEIGHT give the decoded size)
Function VIDNATIVEW& (v As Long)
    VIDNATIVEW = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDNATIVEW = SPVWIDTH(VIDX(v).H) Else VIDNATIVEW = VLCNATIVEW(VIDX(v).H)
End Function

Function VIDNATIVEH& (v As Long)
    VIDNATIVEH = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDNATIVEH = SPVHEIGHT(VIDX(v).H) Else VIDNATIVEH = VLCNATIVEH(VIDX(v).H)
End Function

' Volume as last set with VIDVOL (1 = full)
Function VIDGETVOL! (v As Long)
    VIDGETVOL = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDGETVOL = SPVX(VIDX(v).H).Volume Else VIDGETVOL = VLCX(VIDX(v).H).Volume
End Function

Function VID_OPEN_INT& (FileName$, BoxW As Long, BoxH As Long)
    Dim W As Long, I As Long, Sh As Long
    Dim Lb As Integer
    VID_OPEN_INT = 0
    VID_ERRMSG = ""
    W = 0
    For I = 1 To VID_MAX_VIDEOS
        If Not VIDX(I).InUse Then
            W = I
            Exit For
        End If
    Next
    If W = 0 Then
        VID_ERRMSG = "No free video handles (max" + Str$(VID_MAX_VIDEOS) + ")"
        Exit Function
    End If

    Lb = VID_DETECT%(FileName$)
    If Lb = VID_TYPE_SPV Then
        Sh = SPVOPEN(FileName$)
        If Sh = 0 Then VID_ERRMSG = SPVERROR$
    Else
        Sh = VLCOPENFIT(FileName$, BoxW, BoxH)
        If Sh = 0 Then VID_ERRMSG = VLCERROR$
    End If
    If Sh = 0 Then Exit Function

    VIDX(W).InUse = _TRUE
    VIDX(W).Lib = Lb
    VIDX(W).H = Sh
    VID_OPEN_INT = W
End Function

Sub VIDPLAY (v As Long)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVPLAY VIDX(v).H Else VLCPLAY VIDX(v).H
End Sub

Sub VIDLOOP (v As Long)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVLOOP VIDX(v).H Else VLCLOOP VIDX(v).H
End Sub

Sub VIDPAUSE (v As Long)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVPAUSE VIDX(v).H Else VLCPAUSE VIDX(v).H
End Sub

Sub VIDSTOP (v As Long)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVSTOP VIDX(v).H Else VLCSTOP VIDX(v).H
End Sub

Sub VIDSETPOS (v As Long, Secs As Single)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVSETPOS VIDX(v).H, Secs Else VLCSETPOS VIDX(v).H, Secs
End Sub

Sub VIDVOL (v As Long, Vol As Single)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVVOL VIDX(v).H, Vol Else VLCVOL VIDX(v).H, Vol
End Sub

Sub VIDLIMIT (v As Long, Secs As Single)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVLIMIT VIDX(v).H, Secs Else VLCLIMIT VIDX(v).H, Secs
End Sub

Sub VIDCLOSE (v As Long)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVCLOSE VIDX(v).H Else VLCCLOSE VIDX(v).H
    VIDX(v).InUse = _FALSE
    VIDX(v).Lib = 0
    VIDX(v).H = 0
End Sub

Sub VIDCLOSEALL
    Dim I As Long
    SPVCLOSEALL
    VLCCLOSEALL
    For I = 1 To VID_MAX_VIDEOS
        VIDX(I).InUse = _FALSE
        VIDX(I).Lib = 0
        VIDX(I).H = 0
    Next
End Sub

Function VIDPLAYING% (v As Long)
    VIDPLAYING = _FALSE
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDPLAYING = SPVPLAYING(VIDX(v).H) Else VIDPLAYING = VLCPLAYING(VIDX(v).H)
End Function

Function VIDPAUSED% (v As Long)
    VIDPAUSED = _FALSE
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDPAUSED = SPVPAUSED(VIDX(v).H) Else VIDPAUSED = VLCPAUSED(VIDX(v).H)
End Function

Function VIDLEN# (v As Long)
    VIDLEN = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDLEN = SPVLEN(VIDX(v).H) Else VIDLEN = VLCLEN(VIDX(v).H)
End Function

Function VIDGETPOS# (v As Long)
    VIDGETPOS = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDGETPOS = SPVGETPOS(VIDX(v).H) Else VIDGETPOS = VLCGETPOS(VIDX(v).H)
End Function

Function VIDIMAGE& (v As Long)
    VIDIMAGE = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDIMAGE = SPVIMAGE(VIDX(v).H) Else VIDIMAGE = VLCIMAGE(VIDX(v).H)
End Function

Function VIDNEWFRAME% (v As Long)
    VIDNEWFRAME = _FALSE
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDNEWFRAME = SPVNEWFRAME(VIDX(v).H) Else VIDNEWFRAME = VLCNEWFRAME(VIDX(v).H)
End Function

Function VIDWIDTH& (v As Long)
    VIDWIDTH = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDWIDTH = SPVWIDTH(VIDX(v).H) Else VIDWIDTH = VLCWIDTH(VIDX(v).H)
End Function

Function VIDHEIGHT& (v As Long)
    VIDHEIGHT = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDHEIGHT = SPVHEIGHT(VIDX(v).H) Else VIDHEIGHT = VLCHEIGHT(VIDX(v).H)
End Function

Function VIDFPS# (v As Long)
    VIDFPS = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDFPS = SPVFPS(VIDX(v).H) Else VIDFPS = VLCFPS(VIDX(v).H)
End Function

Function VIDFRAMES& (v As Long)
    VIDFRAMES = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDFRAMES = SPVFRAMES(VIDX(v).H) Else VIDFRAMES = VLCFRAMES(VIDX(v).H)
End Function

Function VIDFRAME& (v As Long)
    VIDFRAME = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDFRAME = SPVFRAME(VIDX(v).H) Else VIDFRAME = VLCFRAME(VIDX(v).H)
End Function

Function VIDTYPE% (v As Long)
    VIDTYPE = 0
    If Not VID_VALID(v) Then Exit Function
    VIDTYPE = VIDX(v).Lib
End Function

Function VIDERROR$
    VIDERROR = VID_ERRMSG
End Function

Function VIDHINT$ (v As Long)
    VIDHINT = ""
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDHINT = SPVHINT(VIDX(v).H) Else VIDHINT = VLCHINT(VIDX(v).H)
End Function

Function VIDASPECT# (v As Long)
    VIDASPECT = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDASPECT = SPVASPECT(VIDX(v).H) Else VIDASPECT = VLCASPECT(VIDX(v).H)
End Function

Function VIDCROPX& (v As Long)
    VIDCROPX = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDCROPX = SPVCROPX(VIDX(v).H) Else VIDCROPX = VLCCROPX(VIDX(v).H)
End Function

Function VIDCROPW& (v As Long)
    VIDCROPW = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDCROPW = SPVCROPW(VIDX(v).H) Else VIDCROPW = VLCCROPW(VIDX(v).H)
End Function

' Draw the current frame into the box (x1,y1)-(x2,y2) of the current _DEST,
' cropped and scaled to the correct aspect ratio, centered with letterbox /
' pillarbox bars left untouched (clear the box first if you want black bars).
Sub VIDPUT (v As Long, X1 As Long, Y1 As Long, X2 As Long, Y2 As Long)
    Dim Img As Long
    Dim BW As Long, BH As Long, DW As Long, DH As Long, DX As Long, DY As Long
    Dim CX As Long, CW As Long, FH As Long
    Dim Ar As Double
    Dim Smooth As Integer
    If Not VID_VALID(v) Then Exit Sub
    Img = VIDIMAGE(v) ' also brings a VLC image up to date
    If Img >= -1 Then Exit Sub
    Ar = VIDASPECT(v)
    CW = VIDCROPW(v): FH = VIDHEIGHT(v)
    If Ar <= 0 Or CW < 1 Or FH < 1 Then Exit Sub
    CX = VIDCROPX(v)

    BW = X2 - X1 + 1: BH = Y2 - Y1 + 1
    If BW < 1 Or BH < 1 Then Exit Sub
    DW = BW: DH = Int(DW / Ar + .5)
    If DH > BH Then
        DH = BH
        DW = Int(DH * Ar + .5)
    End If
    DX = X1 + (BW - DW) \ 2
    DY = Y1 + (BH - DH) \ 2

    ' crisp pixels for SPV bitmap videos, smooth scaling for photographic video
    Smooth = (VIDX(v).Lib = VID_TYPE_VLC)
    If VIDX(v).Lib = VID_TYPE_SPV Then Smooth = SPVX(VIDX(v).H).IsMJPG

    If Smooth Then
        _PutImage (DX, DY)-(DX + DW - 1, DY + DH - 1), Img, , (CX, 0)-(CX + CW - 1, FH - 1), _Smooth
    Else
        _PutImage (DX, DY)-(DX + DW - 1, DY + DH - 1), Img, , (CX, 0)-(CX + CW - 1, FH - 1)
    End If
End Sub

' Fill an info record (used by the movie player's information screen).
' SPV fields that do not exist for standard videos are left at 0.
Sub VIDGETINFO (v As Long, Inf As VIDINFO)
    Dim s As Long
    Dim Blank As VIDINFO
    Inf = Blank
    If Not VID_VALID(v) Then Exit Sub
    s = VIDX(v).H
    Inf.Lib = VIDX(v).Lib
    Inf.Hint = " "
    If VIDX(v).Lib = VID_TYPE_SPV Then
        Inf.VType = SPVX(s).VType
        Inf.NumFrames = SPVX(s).NumFrames
        Inf.FrameW = SPVX(s).FrameW
        Inf.FrameH = SPVX(s).FrameH
        Inf.BPP = SPVX(s).BPP
        Inf.FPSByte = SPVX(s).Hdr.FPS
        Inf.FPSEncoded = SPVX(s).FPS
        Inf.FPSTrue = SPVX(s).TrueFPS
        Inf.Length = SPVLEN(s)
        Inf.Hint = SPVHINT(s)
        If Inf.Hint = "" Then Inf.Hint = " "
        Inf.IsMJPG = SPVX(s).IsMJPG
        Inf.IsSprite = SPVX(s).IsSprite
        Inf.IsVGA = SPVX(s).IsVGA
        Inf.IsPadded = SPVX(s).Padded
        Inf.Full24 = SPVX(s).Full24
        Inf.PalBits = 12
        If SPVX(s).IsVGA Then Inf.PalBits = 18
        If SPVX(s).Full24 Then Inf.PalBits = 24
        Inf.FrameBufSize = SPVX(s).VidFrameSize
        Inf.PalBufSize = SPVX(s).PalSize
        Inf.SprW = SPVX(s).SprW
        Inf.SprH = SPVX(s).SprH
        If SPVX(s).IsSprite And SPVX(s).SprW > 0 And SPVX(s).SprH > 0 Then
            Inf.NumSprites = (SPVX(s).FrameW \ SPVX(s).SprW) * (SPVX(s).FrameH \ SPVX(s).SprH)
        End If
        Inf.AudioSeparate = SPVX(s).AudioSep
        If SPVX(s).AudioSep Then Inf.AudioFileSize = LOF(SPVX(s).AFN)
        Inf.AudioFrameSize = SPVX(s).AudFrameSize
        Inf.Is16 = SPVX(s).Is16
        Inf.Channels = SPVX(s).Channels
        Inf.SampleRate = SPVX(s).InRate
        Inf.RateFromFPS = (SPVX(s).ExactRate Or SPVX(s).AudioSep)
        Inf.VeraRate = SPVX(s).Hdr.VeraRATE
    Else
        Inf.FrameW = VLCWIDTH(s)
        Inf.FrameH = VLCHEIGHT(s)
        Inf.FPSTrue = VLCFPS(s)
        Inf.FPSEncoded = Inf.FPSTrue
        Inf.Length = VLCLEN(s)
        Inf.NumFrames = VLCFRAMES(s)
    End If
End Sub

' SPV only: change the playback frame rate (0 = restore).  No-op for VLC videos.
Sub VIDSETFPS (v As Long, NewFPS As Double)
    If Not VID_VALID(v) Then Exit Sub
    If VIDX(v).Lib = VID_TYPE_SPV Then SPVSETFPS VIDX(v).H, NewFPS
End Sub

' SPV: the nominal ("encoded") FPS as currently set.  VLC: 0.
Function VIDNOMFPS# (v As Long)
    VIDNOMFPS = 0
    If Not VID_VALID(v) Then Exit Function
    If VIDX(v).Lib = VID_TYPE_SPV Then VIDNOMFPS = SPVNOMFPS(VIDX(v).H)
End Function

' ON TIMER handler.  Drives SPV playback; VLC videos do not need it.
Sub VIDTICK
    SPVTICK
End Sub

'=============================================================================
'  INTERNALS
'=============================================================================

Function VID_VALID% (v As Long)
    VID_VALID = _FALSE
    If v < 1 Or v > VID_MAX_VIDEOS Then Exit Function
    VID_VALID = VIDX(v).InUse
End Function

' Decide which library plays a file.
Function VID_DETECT% (FileName$)
    Dim Fn As Integer
    Dim Id As String * 4
    Dim IsSpvName As Integer
    VID_DETECT = VID_TYPE_VLC
    If InStr(FileName$, "://") > 0 Then Exit Function
    IsSpvName = (UCase$(Right$(FileName$, 4)) = ".SPV")
    If Not _FileExists(FileName$) Then
        ' let the chosen library report "File not found"
        If IsSpvName Then VID_DETECT = VID_TYPE_SPV
        Exit Function
    End If
    Fn = FreeFile
    Open FileName$ For Binary Access Read As Fn
    If LOF(Fn) >= 4 Then
        Get Fn, 1, Id
        If Id = "SPRV" Then VID_DETECT = VID_TYPE_SPV
    End If
    Close Fn
    ' a .SPV file with a bad header goes to SPV so you get its error message
    If IsSpvName Then VID_DETECT = VID_TYPE_SPV
End Function
