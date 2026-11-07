'-----------------------------------------------------------------------------------------------------------------------
' SPV aspect ratio and crop add-on
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$IncludeOnce
'=============================================================================
'  SPVAspect.bi  (SPV-ASPECT.BM in the original distribution)   -   playback aspect ratio + crop for SPV-HANDLES.BM
'
'  Add-on: include it AFTER SPV-HANDLES.BM (VID-HANDLES.BM already does).  You
'  can also paste everything below the comment block onto the end of
'  SPV-HANDLES.BM.  It only READS the library's own header copy, so no change
'  to SPV-HANDLES.BM is needed.
'
'  The SPV header HINT byte gives the intended PLAYBACK aspect (width/height of
'  the picture as it should appear), which can differ from the bitmap shape
'  because the X16 scales in hardware:
'
'       "N"  4:3
'       "W"  16:9
'       "T"  9:16
'       "K"  9:16, but the bitmap is 320 wide with only a 270 wide picture in
'            the middle between black bars.  Crop to the 270 wide area, then
'            scale it to 9:16.
'       other / blank  -> the bitmap's own width/height
'
'  New commands (handles are LONG, like everything else):
'       SPVHINT$(h&)      the hint letter, upper case ("" for none)
'       SPVASPECT#(h&)    display aspect ratio, width / height of the PICTURE
'       SPVCROPX&(h&)     left edge of the picture inside SPVIMAGE (pixels)
'       SPVCROPW&(h&)     width of the picture inside SPVIMAGE (pixels)
'                         (top is always 0 and the height is SPVHEIGHT)
'
'  Draw it by scaling the crop rectangle into a box that has SPVASPECT shape:
'       _PUTIMAGE (dx1, dy1)-(dx2, dy2), SPVIMAGE(h), , _
'                 (SPVCROPX(h), 0)-(SPVCROPX(h) + SPVCROPW(h) - 1, SPVHEIGHT(h) - 1)
'  (VID-HANDLES.BM does this for you with VIDPUT.)
'=============================================================================

Const SPV_K_BMP_W = 320 ' K videos: bitmap width the bars are measured against
Const SPV_K_SIG_W = 270 ' K videos: width of the real picture in that bitmap

Function SPVHINT$ (h As Long)
    SPVHINT = ""
    If Not SPV_VALID(h) Then Exit Function
    SPVHINT = UCase$(SPVX(h).Hdr.HINT)
End Function

Function SPVASPECT# (h As Long)
    SPVASPECT = 0
    If Not SPV_VALID(h) Then Exit Function
    Select Case SPVHINT$(h)
        Case "N": SPVASPECT = 4 / 3
        Case "W": SPVASPECT = 16 / 9
        Case "T", "K": SPVASPECT = 9 / 16
        Case Else
            If SPVX(h).FrameH > 0 Then SPVASPECT = SPVX(h).FrameW / SPVX(h).FrameH
    End Select
End Function

Function SPVCROPW& (h As Long)
    SPVCROPW = 0
    If Not SPV_VALID(h) Then Exit Function
    If SPVHINT$(h) = "K" Then
        ' the 270-of-320 picture, scaled if the bitmap is not exactly 320 wide
        SPVCROPW = Int(SPVX(h).FrameW * SPV_K_SIG_W / SPV_K_BMP_W + .5)
    Else
        SPVCROPW = SPVX(h).FrameW
    End If
End Function

Function SPVCROPX& (h As Long)
    SPVCROPX = 0
    If Not SPV_VALID(h) Then Exit Function
    If SPVHINT$(h) = "K" Then SPVCROPX = (SPVX(h).FrameW - SPVCROPW(h)) \ 2
End Function
