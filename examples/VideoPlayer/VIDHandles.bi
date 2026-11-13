'-----------------------------------------------------------------------------------------------------------------------
' SPV + VLC video wrapper
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

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

CONST VID_TYPE_SPV = 1
CONST VID_TYPE_VLC = 2
CONST VID_MAX_VIDEOS = SPV_MAX_VIDEOS + VLC_MAX_VIDEOS
CONST VID_TICK_SECONDS = SPV_TICK_SECONDS

TYPE VIDH_SLOT
    InUse AS INTEGER
    Lib AS INTEGER
    H AS LONG
END TYPE

TYPE VIDINFO
    Lib AS INTEGER
    VType AS INTEGER
    NumFrames AS LONG
    FrameW AS LONG
    FrameH AS LONG
    BPP AS INTEGER
    FPSByte AS INTEGER
    FPSEncoded AS DOUBLE
    FPSTrue AS DOUBLE
    Length AS DOUBLE
    Hint AS STRING * 1
    IsMJPG AS INTEGER
    IsSprite AS INTEGER
    IsVGA AS INTEGER
    IsPadded AS INTEGER
    Full24 AS INTEGER
    PalBits AS INTEGER
    FrameBufSize AS LONG
    PalBufSize AS LONG
    SprW AS LONG
    SprH AS LONG
    NumSprites AS LONG
    AudioSeparate AS INTEGER
    AudioFileSize AS _INTEGER64
    AudioFrameSize AS LONG
    Is16 AS INTEGER
    Channels AS INTEGER
    SampleRate AS LONG
    RateFromFPS AS INTEGER
    VeraRate AS INTEGER
END TYPE

DIM SHARED VIDX(1 TO VID_MAX_VIDEOS) AS VIDH_SLOT
DIM SHARED VID_ERRMSG AS STRING

'=============================================================================
'  PUBLIC API
'=============================================================================

FUNCTION VIDOPEN& (FileName$)
    VIDOPEN = VID_OPEN_INT(FileName$, 0, 0)
END FUNCTION

' Like VIDOPEN, but a VLC video is decoded shrunk to fit inside BoxW x BoxH
' (see VLCOPENFIT).  SPV videos are always decoded at their own size.
FUNCTION VIDOPENFIT& (FileName$, BoxW AS LONG, BoxH AS LONG)
    VIDOPENFIT = VID_OPEN_INT(FileName$, BoxW, BoxH)
END FUNCTION

' Native size of the video (for VLC, VIDWIDTH / VIDHEIGHT give the decoded size)
FUNCTION VIDNATIVEW& (v AS LONG)
    VIDNATIVEW = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDNATIVEW = SPVWIDTH(VIDX(v).H) ELSE VIDNATIVEW = VLCNATIVEW(VIDX(v).H)
END FUNCTION

FUNCTION VIDNATIVEH& (v AS LONG)
    VIDNATIVEH = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDNATIVEH = SPVHEIGHT(VIDX(v).H) ELSE VIDNATIVEH = VLCNATIVEH(VIDX(v).H)
END FUNCTION

' Volume as last set with VIDVOL (1 = full)
FUNCTION VIDGETVOL! (v AS LONG)
    VIDGETVOL = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDGETVOL = SPVX(VIDX(v).H).Volume ELSE VIDGETVOL = VLCX(VIDX(v).H).Volume
END FUNCTION

FUNCTION VID_OPEN_INT& (FileName$, BoxW AS LONG, BoxH AS LONG)
    DIM W AS LONG, I AS LONG, Sh AS LONG
    DIM Lb AS INTEGER
    VID_OPEN_INT = 0
    VID_ERRMSG = ""
    W = 0
    FOR I = 1 TO VID_MAX_VIDEOS
        IF NOT VIDX(I).InUse THEN
            W = I
            EXIT FOR
        END IF
    NEXT
    IF W = 0 THEN
        VID_ERRMSG = "No free video handles (max" + STR$(VID_MAX_VIDEOS) + ")"
        EXIT FUNCTION
    END IF

    Lb = VID_DETECT%(FileName$)
    IF Lb = VID_TYPE_SPV THEN
        Sh = SPVOPEN(FileName$)
        IF Sh = 0 THEN VID_ERRMSG = SPVERROR$
    ELSE
        Sh = VLCOPENFIT(FileName$, BoxW, BoxH)
        IF Sh = 0 THEN VID_ERRMSG = VLCERROR$
    END IF
    IF Sh = 0 THEN EXIT FUNCTION

    VIDX(W).InUse = _TRUE
    VIDX(W).Lib = Lb
    VIDX(W).H = Sh
    VID_OPEN_INT = W
END FUNCTION

SUB VIDPLAY (v AS LONG)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVPLAY VIDX(v).H ELSE VLCPLAY VIDX(v).H
END SUB

SUB VIDLOOP (v AS LONG)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVLOOP VIDX(v).H ELSE VLCLOOP VIDX(v).H
END SUB

SUB VIDPAUSE (v AS LONG)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVPAUSE VIDX(v).H ELSE VLCPAUSE VIDX(v).H
END SUB

SUB VIDSTOP (v AS LONG)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVSTOP VIDX(v).H ELSE VLCSTOP VIDX(v).H
END SUB

SUB VIDSETPOS (v AS LONG, Secs AS SINGLE)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVSETPOS VIDX(v).H, Secs ELSE VLCSETPOS VIDX(v).H, Secs
END SUB

SUB VIDVOL (v AS LONG, Vol AS SINGLE)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVVOL VIDX(v).H, Vol ELSE VLCVOL VIDX(v).H, Vol
END SUB

SUB VIDLIMIT (v AS LONG, Secs AS SINGLE)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVLIMIT VIDX(v).H, Secs ELSE VLCLIMIT VIDX(v).H, Secs
END SUB

SUB VIDCLOSE (v AS LONG)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVCLOSE VIDX(v).H ELSE VLCCLOSE VIDX(v).H
    VIDX(v).InUse = _FALSE
    VIDX(v).Lib = 0
    VIDX(v).H = 0
END SUB

SUB VIDCLOSEALL
    DIM I AS LONG
    SPVCLOSEALL
    VLCCLOSEALL
    FOR I = 1 TO VID_MAX_VIDEOS
        VIDX(I).InUse = _FALSE
        VIDX(I).Lib = 0
        VIDX(I).H = 0
    NEXT
END SUB

FUNCTION VIDPLAYING% (v AS LONG)
    VIDPLAYING = _FALSE
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDPLAYING = SPVPLAYING(VIDX(v).H) ELSE VIDPLAYING = VLCPLAYING(VIDX(v).H)
END FUNCTION

FUNCTION VIDPAUSED% (v AS LONG)
    VIDPAUSED = _FALSE
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDPAUSED = SPVPAUSED(VIDX(v).H) ELSE VIDPAUSED = VLCPAUSED(VIDX(v).H)
END FUNCTION

FUNCTION VIDLEN# (v AS LONG)
    VIDLEN = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDLEN = SPVLEN(VIDX(v).H) ELSE VIDLEN = VLCLEN(VIDX(v).H)
END FUNCTION

FUNCTION VIDGETPOS# (v AS LONG)
    VIDGETPOS = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDGETPOS = SPVGETPOS(VIDX(v).H) ELSE VIDGETPOS = VLCGETPOS(VIDX(v).H)
END FUNCTION

FUNCTION VIDIMAGE& (v AS LONG)
    VIDIMAGE = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDIMAGE = SPVIMAGE(VIDX(v).H) ELSE VIDIMAGE = VLCIMAGE(VIDX(v).H)
END FUNCTION

FUNCTION VIDNEWFRAME% (v AS LONG)
    VIDNEWFRAME = _FALSE
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDNEWFRAME = SPVNEWFRAME(VIDX(v).H) ELSE VIDNEWFRAME = VLCNEWFRAME(VIDX(v).H)
END FUNCTION

FUNCTION VIDWIDTH& (v AS LONG)
    VIDWIDTH = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDWIDTH = SPVWIDTH(VIDX(v).H) ELSE VIDWIDTH = VLCWIDTH(VIDX(v).H)
END FUNCTION

FUNCTION VIDHEIGHT& (v AS LONG)
    VIDHEIGHT = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDHEIGHT = SPVHEIGHT(VIDX(v).H) ELSE VIDHEIGHT = VLCHEIGHT(VIDX(v).H)
END FUNCTION

FUNCTION VIDFPS# (v AS LONG)
    VIDFPS = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDFPS = SPVFPS(VIDX(v).H) ELSE VIDFPS = VLCFPS(VIDX(v).H)
END FUNCTION

FUNCTION VIDFRAMES& (v AS LONG)
    VIDFRAMES = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDFRAMES = SPVFRAMES(VIDX(v).H) ELSE VIDFRAMES = VLCFRAMES(VIDX(v).H)
END FUNCTION

FUNCTION VIDFRAME& (v AS LONG)
    VIDFRAME = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDFRAME = SPVFRAME(VIDX(v).H) ELSE VIDFRAME = VLCFRAME(VIDX(v).H)
END FUNCTION

FUNCTION VIDTYPE% (v AS LONG)
    VIDTYPE = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    VIDTYPE = VIDX(v).Lib
END FUNCTION

FUNCTION VIDERROR$
    VIDERROR = VID_ERRMSG
END FUNCTION

FUNCTION VIDHINT$ (v AS LONG)
    VIDHINT = ""
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDHINT = SPVHINT(VIDX(v).H) ELSE VIDHINT = VLCHINT(VIDX(v).H)
END FUNCTION

FUNCTION VIDASPECT# (v AS LONG)
    VIDASPECT = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDASPECT = SPVASPECT(VIDX(v).H) ELSE VIDASPECT = VLCASPECT(VIDX(v).H)
END FUNCTION

FUNCTION VIDCROPX& (v AS LONG)
    VIDCROPX = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDCROPX = SPVCROPX(VIDX(v).H) ELSE VIDCROPX = VLCCROPX(VIDX(v).H)
END FUNCTION

FUNCTION VIDCROPW& (v AS LONG)
    VIDCROPW = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDCROPW = SPVCROPW(VIDX(v).H) ELSE VIDCROPW = VLCCROPW(VIDX(v).H)
END FUNCTION

' Draw the current frame into the box (x1,y1)-(x2,y2) of the current _DEST,
' cropped and scaled to the correct aspect ratio, centered with letterbox /
' pillarbox bars left untouched (clear the box first if you want black bars).
SUB VIDPUT (v AS LONG, X1 AS LONG, Y1 AS LONG, X2 AS LONG, Y2 AS LONG)
    DIM Img AS LONG
    DIM BW AS LONG, BH AS LONG, DW AS LONG, DH AS LONG, DX AS LONG, DY AS LONG
    DIM CX AS LONG, CW AS LONG, FH AS LONG
    DIM Ar AS DOUBLE
    DIM Smooth AS INTEGER
    IF NOT VID_VALID(v) THEN EXIT SUB
    Img = VIDIMAGE(v) ' also brings a VLC image up to date
    IF Img >= -1 THEN EXIT SUB
    Ar = VIDASPECT(v)
    CW = VIDCROPW(v): FH = VIDHEIGHT(v)
    IF Ar <= 0 OR CW < 1 OR FH < 1 THEN EXIT SUB
    CX = VIDCROPX(v)

    BW = X2 - X1 + 1: BH = Y2 - Y1 + 1
    IF BW < 1 OR BH < 1 THEN EXIT SUB
    DW = BW: DH = INT(DW / Ar + .5)
    IF DH > BH THEN
        DH = BH
        DW = INT(DH * Ar + .5)
    END IF
    DX = X1 + (BW - DW) \ 2
    DY = Y1 + (BH - DH) \ 2

    ' crisp pixels for SPV bitmap videos, smooth scaling for photographic video
    Smooth = (VIDX(v).Lib = VID_TYPE_VLC)
    IF VIDX(v).Lib = VID_TYPE_SPV THEN Smooth = SPVX(VIDX(v).H).IsMJPG

    IF Smooth THEN
        _PUTIMAGE (DX, DY)-(DX + DW - 1, DY + DH - 1), Img, , (CX, 0)-(CX + CW - 1, FH - 1), _SMOOTH
    ELSE
        _PUTIMAGE (DX, DY)-(DX + DW - 1, DY + DH - 1), Img, , (CX, 0)-(CX + CW - 1, FH - 1)
    END IF
END SUB

' Fill an info record (used by the movie player's information screen).
' SPV fields that do not exist for standard videos are left at 0.
SUB VIDGETINFO (v AS LONG, Inf AS VIDINFO)
    DIM s AS LONG
    DIM Blank AS VIDINFO
    Inf = Blank
    IF NOT VID_VALID(v) THEN EXIT SUB
    s = VIDX(v).H
    Inf.Lib = VIDX(v).Lib
    Inf.Hint = " "
    IF VIDX(v).Lib = VID_TYPE_SPV THEN
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
        IF Inf.Hint = "" THEN Inf.Hint = " "
        Inf.IsMJPG = SPVX(s).IsMJPG
        Inf.IsSprite = SPVX(s).IsSprite
        Inf.IsVGA = SPVX(s).IsVGA
        Inf.IsPadded = SPVX(s).Padded
        Inf.Full24 = SPVX(s).Full24
        Inf.PalBits = 12
        IF SPVX(s).IsVGA THEN Inf.PalBits = 18
        IF SPVX(s).Full24 THEN Inf.PalBits = 24
        Inf.FrameBufSize = SPVX(s).VidFrameSize
        Inf.PalBufSize = SPVX(s).PalSize
        Inf.SprW = SPVX(s).SprW
        Inf.SprH = SPVX(s).SprH
        IF SPVX(s).IsSprite AND SPVX(s).SprW > 0 AND SPVX(s).SprH > 0 THEN
            Inf.NumSprites = (SPVX(s).FrameW \ SPVX(s).SprW) * (SPVX(s).FrameH \ SPVX(s).SprH)
        END IF
        Inf.AudioSeparate = SPVX(s).AudioSep
        IF SPVX(s).AudioSep THEN Inf.AudioFileSize = LOF(SPVX(s).AFN)
        Inf.AudioFrameSize = SPVX(s).AudFrameSize
        Inf.Is16 = SPVX(s).Is16
        Inf.Channels = SPVX(s).Channels
        Inf.SampleRate = SPVX(s).InRate
        Inf.RateFromFPS = (SPVX(s).ExactRate OR SPVX(s).AudioSep)
        Inf.VeraRate = SPVX(s).Hdr.VeraRATE
    ELSE
        Inf.FrameW = VLCWIDTH(s)
        Inf.FrameH = VLCHEIGHT(s)
        Inf.FPSTrue = VLCFPS(s)
        Inf.FPSEncoded = Inf.FPSTrue
        Inf.Length = VLCLEN(s)
        Inf.NumFrames = VLCFRAMES(s)
    END IF
END SUB

' SPV only: change the playback frame rate (0 = restore).  No-op for VLC videos.
SUB VIDSETFPS (v AS LONG, NewFPS AS DOUBLE)
    IF NOT VID_VALID(v) THEN EXIT SUB
    IF VIDX(v).Lib = VID_TYPE_SPV THEN SPVSETFPS VIDX(v).H, NewFPS
END SUB

' SPV: the nominal ("encoded") FPS as currently set.  VLC: 0.
FUNCTION VIDNOMFPS# (v AS LONG)
    VIDNOMFPS = 0
    IF NOT VID_VALID(v) THEN EXIT FUNCTION
    IF VIDX(v).Lib = VID_TYPE_SPV THEN VIDNOMFPS = SPVNOMFPS(VIDX(v).H)
END FUNCTION

' ON TIMER handler.  Drives SPV playback; VLC videos do not need it.
SUB VIDTICK
    SPVTICK
END SUB

'=============================================================================
'  INTERNALS
'=============================================================================

FUNCTION VID_VALID% (v AS LONG)
    VID_VALID = _FALSE
    IF v < 1 OR v > VID_MAX_VIDEOS THEN EXIT FUNCTION
    VID_VALID = VIDX(v).InUse
END FUNCTION

' Decide which library plays a file.
FUNCTION VID_DETECT% (FileName$)
    DIM Fn AS INTEGER
    DIM Id AS STRING * 4
    DIM IsSpvName AS INTEGER
    VID_DETECT = VID_TYPE_VLC
    IF INSTR(FileName$, "://") > 0 THEN EXIT FUNCTION
    IsSpvName = (UCASE$(RIGHT$(FileName$, 4)) = ".SPV")
    IF NOT _FILEEXISTS(FileName$) THEN
        ' let the chosen library report "File not found"
        IF IsSpvName THEN VID_DETECT = VID_TYPE_SPV
        EXIT FUNCTION
    END IF
    Fn = FREEFILE
    OPEN FileName$ FOR BINARY ACCESS READ AS Fn
    IF LOF(Fn) >= 4 THEN
        GET Fn, 1, Id
        IF Id = "SPRV" THEN VID_DETECT = VID_TYPE_SPV
    END IF
    CLOSE Fn
    ' a .SPV file with a bad header goes to SPV so you get its error message
    IF IsSpvName THEN VID_DETECT = VID_TYPE_SPV
END FUNCTION
