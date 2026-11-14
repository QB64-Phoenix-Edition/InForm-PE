'-----------------------------------------------------------------------------------------------------------------------
' SPV aspect ratio and crop add-on
' Copyright (c) 2026 Tony3068
' Licensed under the MIT License (see LICENSE.txt). Adapted for InForm-PE by Fellippe Heitor.
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

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

'$INCLUDE:'SPVHandles.bi'

CONST SPV_K_BMP_W = 320 ' K videos: bitmap width the bars are measured against
CONST SPV_K_SIG_W = 270 ' K videos: width of the real picture in that bitmap

FUNCTION SPVHINT$ (h AS LONG)
    SPVHINT = ""
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SPVHINT = UCASE$(SPVX(h).Hdr.HINT)
END FUNCTION

FUNCTION SPVASPECT# (h AS LONG)
    SPVASPECT = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    SELECT CASE SPVHINT$(h)
        CASE "N": SPVASPECT = 4 / 3
        CASE "W": SPVASPECT = 16 / 9
        CASE "T", "K": SPVASPECT = 9 / 16
        CASE ELSE
            IF SPVX(h).FrameH > 0 THEN SPVASPECT = SPVX(h).FrameW / SPVX(h).FrameH
    END SELECT
END FUNCTION

FUNCTION SPVCROPW& (h AS LONG)
    SPVCROPW = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    IF SPVHINT$(h) = "K" THEN
        ' the 270-of-320 picture, scaled if the bitmap is not exactly 320 wide
        SPVCROPW = INT(SPVX(h).FrameW * SPV_K_SIG_W / SPV_K_BMP_W + .5)
    ELSE
        SPVCROPW = SPVX(h).FrameW
    END IF
END FUNCTION

FUNCTION SPVCROPX& (h AS LONG)
    SPVCROPX = 0
    IF NOT SPV_VALID(h) THEN EXIT FUNCTION
    IF SPVHINT$(h) = "K" THEN SPVCROPX = (SPVX(h).FrameW - SPVCROPW(h)) \ 2
END FUNCTION
