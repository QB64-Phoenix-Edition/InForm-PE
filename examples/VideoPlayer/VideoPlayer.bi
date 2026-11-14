'-----------------------------------------------------------------------------------------------------------------------
' Video player for InForm-PE PictureBox controls
' Copyright (c) 2026 Fellippe Heitor
'
' Built on Tony3068's video libraries (MIT License): VIDHandles.bi, which plays SPV videos itself
' (SPVHandles.bi) and everything else through libvlc (VLCHandles.bi + qbvlc.h).
'
' Plays standard video files and streams (MP4, MKV, WebM, AVI, MOV, http://...) and SPV videos
' inside a PictureBox. Standard videos need the VLC 3.x runtime on the user's machine; SPV
' videos don't. Nothing extra is needed to compile. See README.md in this folder.
'
' Usage:
'   '$INCLUDE:'VideoPlayer.bi'   (before InForm.bi)
'   IF Video_Open(MyPictureBox, "movie.mp4") THEN Video_Play MyPictureBox
'   SUB __UI_BeforeUpdateDisplay: Video_Draw MyPictureBox
'   SUB __UI_BeforeUnload: Video_CloseAll
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'VIDHandles.bi'
'$INCLUDE:'../../InForm/InFormCommon.bi'

TYPE __VideoPlayType
    id AS LONG ' PictureBox control ID (0 = free slot)
    handle AS LONG ' VIDHandles handle
END TYPE

DIM __VideoPlay(1 TO VID_MAX_VIDEOS) AS __VideoPlayType
DIM __VideoPlayError AS STRING

' SPV videos are decoded on a timer; it only runs while an SPV video is open
DIM __VideoPlayTimer AS LONG: __VideoPlayTimer = _FREETIMER
ON TIMER(__VideoPlayTimer, VID_TICK_SECONDS) VIDTICK


' True if the VLC 3.x runtime can be loaded on this machine (needed for everything but SPV videos)
FUNCTION Video_IsAvailable%% ()
    SHARED __VideoPlayError AS STRING

    IF qbvlc_probe THEN
        Video_IsAvailable = _TRUE
    ELSE
        __VideoPlayError = VLC_ERRTEXT
    END IF
END FUNCTION


' Opens a video file or URL into a PictureBox. The video is left stopped on its first frame.
' Returns false on failure; Video_GetError$ says why. Opening a standard video waits until the
' first frame is decoded (normally well under a second, up to 10 seconds for a slow stream).
FUNCTION Video_Open%% (Id AS LONG, fileName AS STRING)
    SHARED __VideoPlay() AS __VideoPlayType
    SHARED __VideoPlayError AS STRING

    IF Control(Id).Type <> __UI_Type_PictureBox THEN
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
        EXIT FUNCTION
    END IF

    Video_Close Id

    DIM slot AS LONG: slot = __Video_FindSlot(0)
    IF slot = 0 THEN
        __VideoPlayError = "No free video slots (max" + STR$(VID_MAX_VIDEOS) + ")"
        EXIT FUNCTION
    END IF

    ' Let VLC decode straight to the size of the PictureBox, so frames rarely need scaling
    DIM bs AS LONG: bs = Control(Id).BorderSize * ABS(Control(Id).HasBorder)
    DIM h AS LONG: h = VIDOPENFIT(fileName, Control(Id).Width - bs * 2, Control(Id).Height - bs * 2)

    IF h = 0 THEN
        __VideoPlayError = VIDERROR
        EXIT FUNCTION
    END IF

    __VideoPlay(slot).id = Id
    __VideoPlay(slot).handle = h
    __VideoPlayError = _STR_EMPTY

    __Video_UpdateTimer

    Video_Open = _TRUE
END FUNCTION


' Closes the video in a PictureBox and clears the PictureBox
SUB Video_Close (Id AS LONG)
    SHARED __VideoPlay() AS __VideoPlayType

    DIM slot AS LONG: slot = __Video_FindSlot(Id)
    IF slot = 0 THEN EXIT SUB

    VIDCLOSE __VideoPlay(slot).handle
    __VideoPlay(slot).id = 0
    __VideoPlay(slot).handle = 0

    __Video_UpdateTimer

    IF Control(Id).HelperCanvas < -1 THEN
        BeginDraw Id
        CLS , Control(Id).BackColor
        EndDraw Id
    END IF
END SUB


' Closes every video and shuts libvlc down. Call it from __UI_BeforeUnload.
SUB Video_CloseAll
    SHARED __VideoPlay() AS __VideoPlayType

    DIM i AS LONG
    FOR i = 1 TO VID_MAX_VIDEOS
        IF __VideoPlay(i).id THEN Video_Close __VideoPlay(i).id
    NEXT

    VIDCLOSEALL
END SUB


' True if a video is open in this PictureBox
FUNCTION Video_IsLoaded%% (Id AS LONG)
    Video_IsLoaded = (__Video_FindSlot(Id) <> 0)
END FUNCTION


' True if the video in this PictureBox is an SPV video
FUNCTION Video_IsSPV%% (Id AS LONG)
    Video_IsSPV = (VIDTYPE(__Video_Handle(Id)) = VID_TYPE_SPV)
END FUNCTION


' Text of the last failure (Video_Open, Video_IsAvailable)
FUNCTION Video_GetError$
    SHARED __VideoPlayError AS STRING

    Video_GetError = __VideoPlayError
END FUNCTION


' Starts playing, or resumes if paused. Turns looping off.
SUB Video_Play (Id AS LONG)
    VIDPLAY __Video_Handle(Id)
END SUB


' Starts playing and restarts the video each time it ends
SUB Video_Loop (Id AS LONG)
    VIDLOOP __Video_Handle(Id)
END SUB


SUB Video_Pause (Id AS LONG)
    VIDPAUSE __Video_Handle(Id)
END SUB


' Stops and rewinds to the first frame
SUB Video_Stop (Id AS LONG)
    VIDSTOP __Video_Handle(Id)
END SUB


FUNCTION Video_IsPlaying%% (Id AS LONG)
    Video_IsPlaying = VIDPLAYING(__Video_Handle(Id))
END FUNCTION


FUNCTION Video_IsPaused%% (Id AS LONG)
    Video_IsPaused = VIDPAUSED(__Video_Handle(Id))
END FUNCTION


' Length in seconds (0 if unknown, e.g. a live stream)
FUNCTION Video_GetLength# (Id AS LONG)
    Video_GetLength = VIDLEN(__Video_Handle(Id))
END FUNCTION


' Position in seconds
FUNCTION Video_GetPosition# (Id AS LONG)
    Video_GetPosition = VIDGETPOS(__Video_Handle(Id))
END FUNCTION


' Jumps to a time in seconds, keeping the play state
SUB Video_SetPosition (Id AS LONG, seconds AS SINGLE)
    VIDSETPOS __Video_Handle(Id), seconds
END SUB


' Volume from 0 (silent) to 1 (full); standard videos accept up to 2 to boost it
SUB Video_SetVolume (Id AS LONG, volume AS SINGLE)
    VIDVOL __Video_Handle(Id), volume
END SUB


FUNCTION Video_GetVolume! (Id AS LONG)
    Video_GetVolume = VIDGETVOL(__Video_Handle(Id))
END FUNCTION


' Stops playback when the position reaches this time; 0 removes the limit
SUB Video_SetLimit (Id AS LONG, seconds AS SINGLE)
    VIDLIMIT __Video_Handle(Id), seconds
END SUB


' Native size of the video in pixels
FUNCTION Video_GetWidth& (Id AS LONG)
    Video_GetWidth = VIDNATIVEW(__Video_Handle(Id))
END FUNCTION


FUNCTION Video_GetHeight& (Id AS LONG)
    Video_GetHeight = VIDNATIVEH(__Video_Handle(Id))
END FUNCTION


' Display aspect ratio (width / height). For SPV videos this follows the file's hint, so it
' can differ from Video_GetWidth / Video_GetHeight.
FUNCTION Video_GetAspect# (Id AS LONG)
    Video_GetAspect = VIDASPECT(__Video_Handle(Id))
END FUNCTION


' Copies the newest frame into the PictureBox, letterboxed with the control's BackColor.
' Call it every loop from __UI_BeforeUpdateDisplay. It only redraws when there is a new
' frame or the PictureBox changed size, and it also handles looping and end of video.
SUB Video_Draw (Id AS LONG)
    DIM h AS LONG: h = __Video_Handle(Id)
    IF h = 0 THEN EXIT SUB

    DIM isNewFrame AS _BYTE: isNewFrame = VIDNEWFRAME(h)

    ' Keep the drawing surface the same size as the inside of the PictureBox
    DIM bs AS LONG: bs = Control(Id).BorderSize * ABS(Control(Id).HasBorder)
    DIM w AS LONG: w = Control(Id).Width - bs * 2
    DIM ht AS LONG: ht = Control(Id).Height - bs * 2
    IF w < 1 OR ht < 1 THEN EXIT SUB

    DIM isResized AS _BYTE
    IF Control(Id).HelperCanvas >= -1 THEN
        isResized = _TRUE
    ELSEIF _WIDTH(Control(Id).HelperCanvas) <> w OR _HEIGHT(Control(Id).HelperCanvas) <> ht THEN
        isResized = _TRUE
    END IF

    IF isResized THEN
        IF Control(Id).HelperCanvas < -1 THEN _FREEIMAGE Control(Id).HelperCanvas
        Control(Id).HelperCanvas = _NEWIMAGE(w, ht, 32)
    ELSEIF NOT isNewFrame THEN
        EXIT SUB
    END IF

    ' VIDPUT crops and scales to the right shape (SPV hint) and centers the frame
    BeginDraw Id
    CLS , Control(Id).BackColor
    VIDPUT h, 0, 0, w - 1, ht - 1
    EndDraw Id
END SUB


' Returns the VIDHandles handle for a PictureBox, or 0
FUNCTION __Video_Handle& (Id AS LONG)
    SHARED __VideoPlay() AS __VideoPlayType

    DIM slot AS LONG: slot = __Video_FindSlot(Id)
    IF slot THEN __Video_Handle = __VideoPlay(slot).handle
END FUNCTION


' Returns the slot that holds a PictureBox ID (0 finds a free slot), or 0
FUNCTION __Video_FindSlot& (Id AS LONG)
    SHARED __VideoPlay() AS __VideoPlayType

    DIM i AS LONG
    FOR i = 1 TO VID_MAX_VIDEOS
        IF __VideoPlay(i).id = Id THEN __Video_FindSlot = i: EXIT FUNCTION
    NEXT
END FUNCTION


' Runs the SPV timer only while at least one SPV video is open
SUB __Video_UpdateTimer
    SHARED __VideoPlay() AS __VideoPlayType
    SHARED __VideoPlayTimer AS LONG

    DIM i AS LONG
    FOR i = 1 TO VID_MAX_VIDEOS
        IF __VideoPlay(i).id THEN
            IF VIDTYPE(__VideoPlay(i).handle) = VID_TYPE_SPV THEN
                TIMER(__VideoPlayTimer) ON
                EXIT SUB
            END IF
        END IF
    NEXT

    TIMER(__VideoPlayTimer) OFF
END SUB
