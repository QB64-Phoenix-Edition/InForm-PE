'-----------------------------------------------------------------------------------------------------------------------
' Animated GIF Player library
' Copyright (c) 2026 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'HMap64.bi'
'$INCLUDE:'Resource.bi'
'$INCLUDE:'StringFile.bi'
'$INCLUDE:'Time.bi'
'$INCLUDE:'../InFormCommon.bi'

' This is the master animation type that holds info about a complete animation
TYPE __GIFPlayType
    isUsed AS _BYTE ' is this slot being used (this is only here to assist slot allocation)
    isReady AS _BYTE ' this is set if the GIF is fully loaded (helps fix issues with InForm-PE TIMERs)
    image AS LONG ' the rendered 32bpp frame image
    bgColor AS _UNSIGNED LONG ' background color (32-bit RGBA!)
    firstFrame AS LONG ' index of the first frame in the frame data array
    lastFrame AS LONG ' index of the last frame in the frame data array
    frame AS LONG ' index of the current frame being played
    frameCount AS _UNSIGNED LONG ' total number of frames counted while loading
    frameNumber AS _UNSIGNED LONG ' this is simply the number of current frame since playback (re)started
    isPlaying AS _BYTE ' set to true if the animation is currently playing
    loops AS LONG ' -1 = no, 0 = forever, n = that many times
    loopCounter AS _UNSIGNED LONG ' this counts the number of loops
    duration AS _UNSIGNED _INTEGER64 ' total duration in ticks (ms)
    lastTick AS _UNSIGNED _INTEGER64 ' the tick recorded when the last frame was played
    elapsedTime AS _UNSIGNED _INTEGER64 ' the time (ms) that has passed since the animation was started
    lastFrameRendered AS LONG ' index of the last frame that was rendered
    savedImage AS LONG ' copy of the current frame when disposal method 3 (restore to previous) is encountered
    hasSavedImage AS _BYTE ' set to true if we have a valid saved frame
    overlayEnabled AS _BYTE ' should the "GIF" overlay be shown / hidden when it is not playing
END TYPE

' This type holds information for a single animation frame
TYPE __GIFPlayFrameType
    isUsed AS _BYTE ' is this frame slot being used?
    prevFrame AS LONG ' previous frame (this will link back to the last frame if this is the first one)
    nextFrame AS LONG ' next frame (this will link back to the first frame if this is the last one)
    image AS LONG ' QB64 image handle
    L AS _UNSIGNED INTEGER ' frame left (x offset)
    T AS _UNSIGNED INTEGER ' frame top (y offset)
    disposalMethod AS _UNSIGNED _BYTE ' 0 = don't care, 1 = keep, 2 = background, 3 = previous
    duration AS _UNSIGNED _INTEGER64 ' frame duration in ticks (ms)
END TYPE

' This is an internal type that defines whatever is needed (except the pixel info) from a raw GIF frame data to construct a QB64 image
TYPE __GIFFrameType
    globalColors AS _UNSIGNED INTEGER ' total colors in the global palette
    globalPalette AS STRING * 768 ' global palette - 256 colors * 3 components
    localColors AS _UNSIGNED INTEGER ' total colors in the local frame palette
    localPalette AS STRING * 768 ' local frame palette - 256 colors * 3 components
    disposalMethod AS _UNSIGNED _BYTE ' 0 = don't care, 1 = keep, 2 = background, 3 = previous
    transparentColor AS INTEGER ' transparent color for this frame (< 0 means none)
    duration AS _UNSIGNED INTEGER ' raw duration data in 1/100th seconds
END TYPE

REDIM __GIFPlayHashTable(0 TO 0) AS HMap64 ' shared hash table to keep user supplied IDs (the values here points to indexes in __GIFPlay)
REDIM __GIFPlay(0 TO 0) AS __GIFPlayType ' main GIFPlay array - each array element is for a single GIF
REDIM __GIFPlayFrame(0 TO 0) AS __GIFPlayFrameType ' shared GIF frame array - this holds GIF frame and frame information for all loaded GIFs
DIM __GIF_FirstFreeFrame AS LONG ' index of the lowest free frame in __GIFPlayFrame

''' @brief Opens an animated GIF file from a buffer in memory.
''' @param Id The InForm PictureBox control ID.
''' @param buffer The string containing raw GIF file data.
''' @return _TRUE if the GIF was loaded successfully, _FALSE otherwise.
FUNCTION GIF_LoadFromMemory%% (Id AS LONG, buffer AS STRING)
    IF Id < LBOUND(Control) _ORELSE Id > UBOUND(Control) THEN
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
        EXIT FUNCTION
    END IF

    IF Control(Id).Type <> __UI_Type_PictureBox THEN
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
        EXIT FUNCTION
    END IF

    DIM sf AS StringFile

    StringFile_Create sf, buffer

    GIF_LoadFromMemory = __GIF_Load(Id, sf)
END FUNCTION

''' @brief Opens an animated GIF file from a file on disk.
''' @param Id The InForm PictureBox control ID.
''' @param fileName The path to the GIF file on disk.
''' @return _TRUE if the GIF was loaded successfully, _FALSE otherwise.
FUNCTION GIF_LoadFromFile%% (Id AS LONG, fileName AS STRING)
    IF Id < LBOUND(Control) _ORELSE Id > UBOUND(Control) THEN
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
        EXIT FUNCTION
    END IF

    IF Control(Id).Type <> __UI_Type_PictureBox THEN
        ERROR _ERR_ILLEGAL_FUNCTION_CALL
        EXIT FUNCTION
    END IF

    DIM sf AS StringFile

    IF StringFile_Load(sf, fileName) THEN
        GIF_LoadFromFile = __GIF_Load(Id, sf)
    END IF
END FUNCTION

''' @brief Internal helper to safely get the __GIFPlay slot index for an ID.
''' @param Id The InForm PictureBox control ID.
''' @return The index in __GIFPlay(), or -1 if not found.
FUNCTION __GIF_GetSlot& (Id AS LONG)
    $CHECKING:OFF
    SHARED __GIFPlayHashTable() AS HMap64

    IF HMap64_IsInitialized(__GIFPlayHashTable()) _ANDALSO HMap64_Contains(__GIFPlayHashTable(), Id) THEN
        __GIF_GetSlot = HMap64_GetLong(__GIFPlayHashTable(), Id)
    ELSE
        __GIF_GetSlot = -1
    END IF
    $CHECKING:ON
END FUNCTION

''' @brief Frees a loaded GIF and all associated frame images and resources.
''' @param Id The InForm PictureBox control ID.
SUB GIF_Free (Id AS LONG)
    SHARED __GIFPlayHashTable() AS HMap64
    SHARED __GIFPlay() AS __GIFPlayType
    SHARED __GIFPlayFrame() AS __GIFPlayFrameType
    SHARED __GIF_FirstFreeFrame AS LONG

    ' Get the slot we need to free
    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx < 0 THEN EXIT SUB

    ' Walk the whole animation chain to free all the frames and associated data
    IF __GIFPlay(idx).firstFrame >= 0 THEN
        DIM currFrame AS LONG: currFrame = __GIFPlay(idx).firstFrame
        DO
            DIM nextFrame AS LONG: nextFrame = __GIFPlayFrame(currFrame).nextFrame

            ' Free the image being held by the frame
            IF __GIFPlayFrame(currFrame).image < -1 THEN
                _FREEIMAGE __GIFPlayFrame(currFrame).image
                __GIFPlayFrame(currFrame).image = 0
            END IF

            ' Mark the frame slot as unused so that it can be reused
            __GIFPlayFrame(currFrame).isUsed = _FALSE
            __GIFPlayFrame(currFrame).nextFrame = -1
            __GIFPlayFrame(currFrame).prevFrame = -1

            ' Note the lowest free frame
            IF __GIF_FirstFreeFrame > currFrame THEN __GIF_FirstFreeFrame = currFrame

            ' Move to the next frame
            currFrame = nextFrame
        LOOP WHILE currFrame >= 0 _ANDALSO currFrame <> __GIFPlay(idx).firstFrame
    END IF

    ' Free the rendered image
    IF __GIFPlay(idx).image < -1 THEN
        _FREEIMAGE __GIFPlay(idx).image
        __GIFPlay(idx).image = 0
    END IF

    ' Free the saved rendered image
    IF __GIFPlay(idx).savedImage < -1 THEN
        _FREEIMAGE __GIFPlay(idx).savedImage
        __GIFPlay(idx).savedImage = 0
    END IF

    ' Reset frame pointers
    __GIFPlay(idx).firstFrame = -1
    __GIFPlay(idx).lastFrame = -1
    __GIFPlay(idx).frame = -1
    __GIFPlay(idx).isReady = _FALSE

    ' Finally mark the GIF slot as unused so that it can be reused
    __GIFPlay(idx).isUsed = _FALSE

    ' Remove Id from the hash table
    HMap64_Remove __GIFPlayHashTable(), Id
END SUB

''' @brief Returns the width of the animation in pixels.
''' @param Id The InForm PictureBox control ID.
''' @return The width in pixels, or 0 if not loaded.
FUNCTION GIF_GetWidth~& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN
        IF __GIFPlay(idx).image < -1 THEN GIF_GetWidth = _WIDTH(__GIFPlay(idx).image)
    END IF
END FUNCTION

''' @brief Returns the height of the animation in pixels.
''' @param Id The InForm PictureBox control ID.
''' @return The height in pixels, or 0 if not loaded.
FUNCTION GIF_GetHeight~& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN
        IF __GIFPlay(idx).image < -1 THEN GIF_GetHeight = _HEIGHT(__GIFPlay(idx).image)
    END IF
END FUNCTION

''' @brief Returns the index of the currently playing frame.
''' @param Id The InForm PictureBox control ID.
''' @return The 0-based frame number since playback started.
FUNCTION GIF_GetFrameNumber~& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN GIF_GetFrameNumber = __GIFPlay(idx).frameNumber
END FUNCTION

''' @brief Returns the total number of frames in the GIF animation.
''' If this returns 1, the image is a static (non-animated) GIF.
''' @param Id The InForm PictureBox control ID.
''' @return The total frame count.
FUNCTION GIF_GetTotalFrames~& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN GIF_GetTotalFrames = __GIFPlay(idx).frameCount
END FUNCTION

''' @brief Starts or resumes animation playback.
''' @param Id The InForm PictureBox control ID.
SUB GIF_Play (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN
        __GIFPlay(idx).isPlaying = _TRUE
        __GIFPlay(idx).lastTick = Time_GetTicks
    END IF
END SUB

''' @brief Pauses animation playback at the current frame.
''' @param Id The InForm PictureBox control ID.
SUB GIF_Pause (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN __GIFPlay(idx).isPlaying = _FALSE
END SUB

''' @brief Stops animation playback and resets the cursor to the first frame.
''' @param Id The InForm PictureBox control ID.
SUB GIF_Stop (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType
    SHARED __GIFPlayFrame() AS __GIFPlayFrameType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN
        __GIFPlay(idx).isPlaying = _FALSE
        __GIFPlay(idx).frame = __GIFPlay(idx).firstFrame
        __GIFPlay(idx).frameNumber = 0
        __GIFPlay(idx).loopCounter = 0
        __GIFPlay(idx).elapsedTime = 0
        __GIFPlay(idx).lastFrameRendered = -1
        __GIFPlay(idx).hasSavedImage = _FALSE

        ' Re-render the first frame onto the image surface so subsequent draws show frame 0
        IF __GIFPlay(idx).firstFrame >= 0 _ANDALSO __GIFPlay(idx).image < -1 THEN
            CLS , __GIFPlay(idx).bgColor, __GIFPlay(idx).image
            DIM f AS LONG: f = __GIFPlay(idx).firstFrame
            IF __GIFPlayFrame(f).image < -1 THEN
                _PUTIMAGE (__GIFPlayFrame(f).L, __GIFPlayFrame(f).T), __GIFPlayFrame(f).image, __GIFPlay(idx).image
            END IF
            __GIFPlay(idx).lastFrameRendered = f
        END IF
    END IF
END SUB

''' @brief Checks whether the animation is currently playing.
''' @param Id The InForm PictureBox control ID.
''' @return _TRUE if the GIF is playing, _FALSE otherwise.
FUNCTION GIF_IsPlaying%% (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN GIF_IsPlaying = __GIFPlay(idx).isPlaying
END FUNCTION

''' @brief Draws the current frame on the destination surface at (0, 0), stretching if needed.
''' If playback is paused or stopped and overlay is enabled, draws the GIF overlay icon.
''' @param Id The InForm PictureBox control ID.
SUB GIF_Draw (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN
        BeginDraw ID

        ' Get the rendered image handle
        DIM renderedFrame AS LONG: renderedFrame = GIF_GetFrame(Id)

        ' Clear the surface using the background color (this will be black if the GIF has no global color table)
        CLS , __GIFPlay(idx).bgColor

        ' Blit the rendered frame
        IF renderedFrame < -1 THEN
            _PUTIMAGE , renderedFrame, , , _SMOOTH
        END IF

        ' Render the overlay if needed
        IF NOT __GIFPlay(idx).isPlaying _ANDALSO __GIFPlay(idx).overlayEnabled _ANDALSO __GIFPlay(idx).frameCount > 1 THEN
            DIM overlayImage AS LONG: overlayImage = __GIF_GetOverlayImage

            _PUTIMAGE (_SHR(_WIDTH, 1) - _SHR(_WIDTH(overlayImage), 1), _SHR(_HEIGHT, 1) - _SHR(_HEIGHT(overlayImage), 1)), overlayImage
        END IF

        EndDraw ID
    END IF
END SUB

''' @brief Returns the current rendered frame image handle (QB64 image).
''' Playback is time-sensitive so frames may be advanced or skipped based on elapsed time.
''' The caller must not free this image handle.
''' @param Id The InForm PictureBox control ID.
''' @return The QB64 image handle of the rendered frame.
FUNCTION GIF_GetFrame& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType
    SHARED __GIFPlayFrame() AS __GIFPlayFrameType

    ' Get the GIF slot
    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx < 0 THEN EXIT FUNCTION

    ' Always return the rendered image handle (since this does not change during the GIFs lifetime)
    GIF_GetFrame = __GIFPlay(idx).image

    ' Exit if we are paused or not ready
    IF NOT __GIFPlay(idx).isPlaying _ORELSE NOT __GIFPlay(idx).isReady THEN EXIT FUNCTION

    ' Exit if we finished a single or the specified number of loops
    IF __GIFPlay(idx).loops <> 0 _ANDALSO (__GIFPlay(idx).loopCounter < 0 _ORELSE __GIFPlay(idx).loopCounter >= __GIFPlay(idx).loops) THEN EXIT FUNCTION

    ' Fetch and store the current tick
    DIM currentTick AS _UNSIGNED _INTEGER64: currentTick = Time_GetTicks

    ' Remember the last frame index
    DIM lastFrameRendered AS LONG: lastFrameRendered = __GIFPlay(idx).frame

    ' Walk through the animation chain and find the frame we have to render based on the tick we recorded the last time
    DO UNTIL currentTick < __GIFPlay(idx).lastTick + __GIFPlayFrame(__GIFPlay(idx).frame).duration
        ' Add the current frame duration to lastTick so that we can do frame skips if needed
        __GIFPlay(idx).lastTick = __GIFPlay(idx).lastTick + __GIFPlayFrame(__GIFPlay(idx).frame).duration
        ' Increment elapsed time
        __GIFPlay(idx).elapsedTime = __GIFPlay(idx).elapsedTime + __GIFPlayFrame(__GIFPlay(idx).frame).duration
        ' We crossed the duration of the current frame, so move to the next one
        __GIFPlay(idx).frame = __GIFPlayFrame(__GIFPlay(idx).frame).nextFrame ' this should correctly loop back to the first frame
        ' Increment the frame counter and loop back to 0 if needed
        __GIFPlay(idx).frameNumber = __GIFPlay(idx).frameNumber + 1
        IF __GIFPlay(idx).frameNumber >= __GIFPlay(idx).frameCount THEN
            __GIFPlay(idx).frameNumber = 0
            __GIFPlay(idx).loopCounter = __GIFPlay(idx).loopCounter + 1

            IF __GIFPlay(idx).loops < 0 THEN
                __GIFPlay(idx).loopCounter = -1 ' single-shot animation
            ELSE
                __GIFPlay(idx).elapsedTime = 0 ' only reset the elapsed time for looping playback
            END IF
        END IF
    LOOP

    ' If the last frame rendered is the same as the current frame then just return the previously rendered frame image
    IF __GIFPlay(idx).frame = __GIFPlay(idx).lastFrameRendered THEN EXIT FUNCTION

    ' We now have the frame to display, so save the currentTick and update lastFrameRendered
    __GIFPlay(idx).lastTick = currentTick
    __GIFPlay(idx).lastFrameRendered = lastFrameRendered

    ' Take appropriate action based on the disposal method of the previous frame
    IF __GIFPlay(idx).frame = __GIFPlay(idx).firstFrame THEN
        ' If this is the first frame, then we do not have any previous disposal method
        CLS , __GIFPlay(idx).bgColor, __GIFPlay(idx).image ' clear the render image using the BG color
    ELSE
        SELECT CASE __GIFPlayFrame(__GIFPlayFrame(__GIFPlay(idx).frame).prevFrame).disposalMethod
            CASE 2 ' Restore to background color
                CLS , __GIFPlay(idx).bgColor, __GIFPlay(idx).image
                _CLEARCOLOR __GIFPlay(idx).bgColor, __GIFPlay(idx).image

            CASE 3 ' Restore to previous
                IF __GIFPlay(idx).hasSavedImage THEN
                    ' Copy back the saved image and unset the flag
                    _PUTIMAGE , __GIFPlay(idx).savedImage, __GIFPlay(idx).image
                    __GIFPlay(idx).hasSavedImage = _FALSE
                END IF

                ' All other disposal methods do not require any action
        END SELECT
    END IF

    ' If the current frame's disposal method is 3 (restore to previous) then save the current rendered frame and set the flag
    IF __GIFPlayFrame(__GIFPlay(idx).frame).disposalMethod = 3 THEN
        _PUTIMAGE , __GIFPlay(idx).image, __GIFPlay(idx).savedImage
        __GIFPlay(idx).hasSavedImage = _TRUE
    END IF

    ' Render the frame at the correct (x, y) offset on the final image
    _PUTIMAGE (__GIFPlayFrame(__GIFPlay(idx).frame).L, __GIFPlayFrame(__GIFPlay(idx).frame).T), __GIFPlayFrame(__GIFPlay(idx).frame).image, __GIFPlay(idx).image
END FUNCTION

''' @brief Returns the background color that should be used to clear the surface before drawing the final rendered frame.
''' @param Id The InForm PictureBox control ID.
''' @return The background color as a 32-bit RGBA value.
FUNCTION GIF_GetBackgroundColor~& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN GIF_GetBackgroundColor = __GIFPlay(idx).bgColor
END FUNCTION

''' @brief Returns the total duration of the animation in milliseconds.
''' @param Id The InForm PictureBox control ID.
''' @return The total duration in milliseconds.
FUNCTION GIF_GetTotalDuration~&& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN GIF_GetTotalDuration = __GIFPlay(idx).duration
END FUNCTION

''' @brief Returns the display duration of the current frame in milliseconds.
''' @param Id The InForm PictureBox control ID.
''' @return The current frame duration in milliseconds.
FUNCTION GIF_GetFrameDuration~&& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType
    SHARED __GIFPlayFrame() AS __GIFPlayFrameType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN
        IF __GIFPlay(idx).frame >= 0 THEN
            GIF_GetFrameDuration = __GIFPlayFrame(__GIFPlay(idx).frame).duration
        END IF
    END IF
END FUNCTION

''' @brief Returns the elapsed playback time since the animation started in milliseconds.
''' @param Id The InForm PictureBox control ID.
''' @return The elapsed time in milliseconds.
FUNCTION GIF_GetElapsedTime~&& (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN GIF_GetElapsedTime = __GIFPlay(idx).elapsedTime
END FUNCTION

''' @brief Configures looping behavior for the animation.
''' @param Id The InForm PictureBox control ID.
''' @param loops Number of times to loop (-1 = no loop, 0 = infinite, n = loop n times).
SUB GIF_SetLoop (Id AS LONG, loops AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN __GIFPlay(idx).loops = loops
END SUB

''' @brief Enables or disables the GIF overlay icon when playback is paused or stopped.
''' @param Id The InForm PictureBox control ID.
''' @param isEnabled _TRUE to show the overlay icon, _FALSE to hide it.
SUB GIF_EnableOverlay (Id AS LONG, isEnabled AS _BYTE)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN __GIFPlay(idx).overlayEnabled = isEnabled
END SUB

''' @brief Checks if a GIF is fully loaded and ready for playback.
''' @param Id The InForm PictureBox control ID.
''' @return _TRUE if the GIF is loaded and ready, _FALSE otherwise.
FUNCTION GIF_IsLoaded%% (Id AS LONG)
    SHARED __GIFPlay() AS __GIFPlayType

    DIM idx AS LONG: idx = __GIF_GetSlot(Id)
    IF idx >= 0 THEN GIF_IsLoaded = __GIFPlay(idx).isReady
END FUNCTION

''' @brief Internal helper to deinterlace an interlaced GIF frame image.
''' @param bmp The raw frame image handle to deinterlace.
SUB __GIF_DeinterlaceFrameImage (bmp AS LONG)
    DIM W AS LONG: W = _WIDTH(bmp)
    DIM H AS LONG: H = _HEIGHT(bmp)
    DIM MX AS LONG: MX = W - 1
    DIM n AS LONG: n = _NEWIMAGE(W, H, 256)

    DIM AS LONG y, i

    WHILE y < H
        _PUTIMAGE (0, y), bmp, n, (0, i)-(MX, i)
        i = i + 1
        y = y + 8
    WEND

    y = 4
    WHILE y < H
        _PUTIMAGE (0, y), bmp, n, (0, i)-(MX, i)
        i = i + 1
        y = y + 8
    WEND

    y = 2
    WHILE y < H
        _PUTIMAGE (0, y), bmp, n, (0, i)-(MX, i)
        i = i + 1
        y = y + 4
    WEND

    y = 1
    WHILE y < H
        _PUTIMAGE (0, y), bmp, n, (0, i)-(MX, i)
        i = i + 1
        y = y + 2
    WEND

    _PUTIMAGE , n, bmp
    _FREEIMAGE n
END SUB

''' @brief Internal helper to read an LZW code of variable bit size from a bit stream.
''' @param sf The StringFile stream.
''' @param buffer The input byte buffer.
''' @param bitPos The current bit position in the buffer.
''' @param bitSize The number of bits to read.
''' @return The decoded LZW code, or -1 on end of stream.
FUNCTION __GIF_ReadLZWCode& (sf AS StringFile, buffer AS STRING, bitPos AS LONG, bitSize AS LONG)
    DIM AS LONG code, p: p = 1

    DIM i AS LONG: FOR i = 1 TO bitSize
        DIM bytePos AS LONG: bytePos = _SHR(bitPos, 3) AND 255

        IF bytePos = 0 THEN
            IF StringFile_IsEOF(sf) THEN
                __GIF_ReadLZWCode = -1
                EXIT FUNCTION
            END IF

            DIM dataLen AS LONG: dataLen = StringFile_ReadByte(sf)

            IF dataLen = 0 THEN
                __GIF_ReadLZWCode = -1
                EXIT FUNCTION
            END IF

            IF StringFile_GetPosition(sf) + dataLen > StringFile_GetSize(sf) THEN
                __GIF_ReadLZWCode = -1
                EXIT FUNCTION
            END IF

            MID$(buffer, 257 - dataLen, dataLen) = StringFile_ReadString(sf, dataLen)

            bytePos = 256 - dataLen
            bitPos = _SHL(bytePos, 3)
        END IF

        IF ASC(buffer, 1 + bytePos) AND _SHL(1, bitPos AND 7) THEN code = code + p

        p = p + p
        bitPos = bitPos + 1
    NEXT i

    __GIF_ReadLZWCode = code
END FUNCTION

''' @brief Internal helper to decode LZW compressed image data into pixel memory.
''' @param sf The StringFile stream containing LZW compressed data.
''' @param bmpMem The destination bitmap memory block.
''' @return _TRUE on successful decompression, _FALSE otherwise.
FUNCTION __GIF_DecodeLZW%% (sf AS StringFile, bmpMem AS _MEM)
    IF StringFile_IsEOF(sf) THEN EXIT FUNCTION

    DIM origBitSize AS LONG: origBitSize = StringFile_ReadByte(sf)
    IF origBitSize < 2 _ORELSE origBitSize > 8 THEN EXIT FUNCTION

    TYPE __LZWCodeType
        c AS LONG
        prefix AS LONG
        length AS LONG
    END TYPE

    DIM codes(0 TO 4095) AS __LZWCodeType ' maximum bit size is 12

    DIM n AS LONG: n = 2 + _SHL(1, origBitSize)

    DIM i AS LONG: WHILE i < n
        codes(i).c = i
        codes(i).length = 0
        i = i + 1
    WEND

    DIM clearMarker AS LONG: clearMarker = n - 2
    DIM endMarker AS LONG: endMarker = n - 1

    DIM buffer AS STRING: buffer = SPACE$(256)
    DIM bitSize AS LONG: bitSize = origBitSize + 1
    DIM bitPos AS LONG

    ' Expect to read clear code as first code here
    DIM prev AS LONG: prev = __GIF_ReadLZWCode(sf, buffer, bitPos, bitSize)
    IF prev = -1 THEN EXIT FUNCTION

    DO
        DIM code AS LONG: code = __GIF_ReadLZWCode(sf, buffer, bitPos, bitSize)
        IF code = -1 THEN EXIT FUNCTION

        IF code = clearMarker THEN
            bitSize = origBitSize
            n = _SHL(1, bitSize) + 2
            bitSize = bitSize + 1
            prev = code
            _CONTINUE
        END IF

        IF code = endMarker THEN EXIT DO

        ' Known code: ok. Else: must be doubled char
        DIM c AS LONG: IF code < n THEN c = code ELSE c = prev

        ' Output the code
        DIM outPos AS LONG: outPos = outPos + codes(c).length

        i = 0
        DO
            IF outPos - i >= 0 _ANDALSO outPos - i < bmpMem.SIZE THEN
                _MEMPUT bmpMem, bmpMem.OFFSET + outPos - i, codes(c).c AS _UNSIGNED _BYTE
            END IF

            IF codes(c).length <> 0 THEN
                c = codes(c).prefix
            ELSE
                EXIT DO
            END IF

            i = i + 1
        LOOP

        outPos = outPos + 1

        ' Unknown code -> must be double char
        IF code >= n THEN
            IF outPos >= 0 _ANDALSO outPos < bmpMem.SIZE THEN
                _MEMPUT bmpMem, bmpMem.OFFSET + outPos, codes(c).c AS _UNSIGNED _BYTE
            END IF
            outPos = outPos + 1
        END IF

        ' If outPos has reached or exceeded the buffer capacity, stop decoding
        IF outPos > bmpMem.SIZE THEN EXIT DO

        ' Except after clear marker, build new code
        IF prev <> clearMarker _ANDALSO n < 4096 THEN
            codes(n).prefix = prev
            codes(n).length = codes(prev).length + 1
            codes(n).c = codes(c).c
            n = n + 1
        END IF

        ' Out of bits? Increase
        IF _SHL(1, bitSize) = n THEN
            IF bitSize < 12 THEN bitSize = bitSize + 1
        END IF

        prev = code
    LOOP

    __GIF_DecodeLZW = _TRUE
END FUNCTION

''' @brief Internal helper to apply the color palette and transparency to a raw GIF frame image.
''' @param info The frame metadata containing palette and transparency settings.
''' @param bmp The raw 8-bit frame image handle.
SUB __GIF_PrepareFrameImage (info AS __GIFFrameType, bmp AS LONG)
    ' Set the 8-bit image palette
    DIM AS LONG x, y
    IF info.localColors = 0 THEN
        ' No local palette, so use the global one
        WHILE y < info.globalColors
            x = y * 3
            _PALETTECOLOR y, _RGB32(ASC(info.globalPalette, x + 1), ASC(info.globalPalette, x + 2), ASC(info.globalPalette, x + 3)), bmp
            y = y + 1
        WEND
    ELSE
        ' Use the local palette
        WHILE y < info.localColors
            x = y * 3
            _PALETTECOLOR y, _RGB32(ASC(info.localPalette, x + 1), ASC(info.localPalette, x + 2), ASC(info.localPalette, x + 3)), bmp
            y = y + 1
        WEND
    END IF

    ' Set the transparent color
    IF info.transparentColor >= 0 THEN _CLEARCOLOR info.transparentColor, bmp
END SUB

''' @brief Internal helper that parses and loads a GIF from a StringFile stream.
''' @param Id The InForm PictureBox control ID.
''' @param sf The StringFile stream containing GIF data.
''' @return _TRUE on successful load, _FALSE otherwise.
FUNCTION __GIF_Load%% (Id AS LONG, sf AS StringFile)
    SHARED __GIFPlayHashTable() AS HMap64
    SHARED __GIFPlay() AS __GIFPlayType
    SHARED __GIFPlayFrame() AS __GIFPlayFrameType
    SHARED __GIF_FirstFreeFrame AS LONG

    IF NOT HMap64_IsInitialized(__GIFPlayHashTable()) THEN
        HMap64_Initialize __GIFPlayHashTable()
    END IF

    ' Check if Id already exists and if so free it
    IF GIF_IsLoaded(Id) THEN GIF_Free Id

    ' Minimal GIF header (6) + Logical Screen Descriptor (7) = 13 bytes
    IF StringFile_GetSize(sf) < 13 THEN EXIT FUNCTION

    ' Check the file signature before proceeding further
    DIM buffer AS STRING: buffer = StringFile_ReadString(sf, 6)
    IF buffer <> "GIF87a" _ANDALSO buffer <> "GIF89a" THEN EXIT FUNCTION

    ' Ok, so it is a GIF. Allocate resources to load the rest of the file
    DIM idx AS LONG: FOR idx = 0 TO UBOUND(__GIFPlay)
        IF NOT __GIFPlay(idx).isUsed THEN EXIT FOR
    NEXT idx

    ' No free GIF slots?
    IF idx > UBOUND(__GIFPlay) THEN REDIM _PRESERVE __GIFPlay(0 TO idx) AS __GIFPlayType

    __GIFPlay(idx).isUsed = _TRUE ' occupy the slot
    HMap64_SetLong __GIFPlayHashTable(), Id, idx ' add it to the hash table

    ' Reset some stuff
    __GIFPlay(idx).isReady = _FALSE
    __GIFPlay(idx).firstFrame = -1
    __GIFPlay(idx).lastFrame = -1
    __GIFPlay(idx).frame = -1
    __GIFPlay(idx).frameCount = 0
    __GIFPlay(idx).frameNumber = 0
    __GIFPlay(idx).isPlaying = _FALSE
    __GIFPlay(idx).loops = 0
    __GIFPlay(idx).loopCounter = 0
    __GIFPlay(idx).duration = 0
    __GIFPlay(idx).lastTick = 0
    __GIFPlay(idx).elapsedTime = 0
    __GIFPlay(idx).lastFrameRendered = -1
    __GIFPlay(idx).hasSavedImage = _FALSE
    __GIFPlay(idx).overlayEnabled = _TRUE

    ' Get width and height
    DIM W AS _UNSIGNED INTEGER: W = StringFile_ReadInteger(sf)
    DIM H AS _UNSIGNED INTEGER: H = StringFile_ReadInteger(sf)

    IF W = 0 _ORELSE H = 0 THEN GOTO gif_load_error

    ' Create the 32bpp rendered image using the width and height we got above
    __GIFPlay(idx).image = _NEWIMAGE(W, H, 32)
    __GIFPlay(idx).savedImage = _NEWIMAGE(W, H, 32)
    IF __GIFPlay(idx).image >= -1 _ORELSE __GIFPlay(idx).savedImage >= -1 THEN GOTO gif_load_error

    DIM i AS _UNSIGNED _BYTE: i = StringFile_ReadByte(sf)

    DIM rawFrame AS __GIFFrameType
    rawFrame.globalPalette = STRING$(768, 0)
    rawFrame.localPalette = STRING$(768, 0)
    rawFrame.transparentColor = -1 ' no transparent color

    ' Global color table?
    IF _READBIT(i, 7) THEN rawFrame.globalColors = _SHL(1, ((i AND 7) + 1))

    ' Background color is only valid with a global palette
    DIM bgColorIndex AS _UNSIGNED _BYTE: bgColorIndex = StringFile_ReadByte(sf)

    ' Skip aspect ratio
    StringFile_Seek sf, StringFile_GetPosition(sf) + 1

    ' Read the global palette data
    IF rawFrame.globalColors > 0 THEN MID$(rawFrame.globalPalette, 1, 3 * rawFrame.globalColors) = StringFile_ReadString(sf, 3 * rawFrame.globalColors)

    ' Get RGBA value from the global palette for the background color
    IF rawFrame.globalColors > 0 _ANDALSO bgColorIndex < rawFrame.globalColors THEN
        DIM bgOffset AS LONG: bgOffset = 3 * bgColorIndex
        __GIFPlay(idx).bgColor = _RGB32(ASC(rawFrame.globalPalette, bgOffset + 1), ASC(rawFrame.globalPalette, bgOffset + 2), ASC(rawFrame.globalPalette, bgOffset + 3))
    ELSE
        __GIFPlay(idx).bgColor = _RGBA32(0, 0, 0, 0)
    END IF

    DIM frameIdx AS LONG: frameIdx = -1

    DO WHILE NOT StringFile_IsEOF(sf)
        i = StringFile_ReadByte(sf)

        SELECT CASE i
            CASE &H2C ' image descriptor
                ' Look for a free slot from the last lowest freed index
                FOR frameIdx = __GIF_FirstFreeFrame TO UBOUND(__GIFPlayFrame)
                    IF NOT __GIFPlayFrame(frameIdx).isUsed THEN
                        __GIF_FirstFreeFrame = frameIdx + 1
                        EXIT FOR
                    END IF
                NEXT

                IF frameIdx > UBOUND(__GIFPlayFrame) THEN
                    ' Search from the beginning
                    FOR frameIdx = 0 TO UBOUND(__GIFPlayFrame)
                        IF NOT __GIFPlayFrame(frameIdx).isUsed THEN EXIT FOR
                    NEXT
                END IF

                ' If still no free frame slot then allocate one
                IF frameIdx > UBOUND(__GIFPlayFrame) THEN REDIM _PRESERVE __GIFPlayFrame(0 TO frameIdx) AS __GIFPlayFrameType

                ' Occupy the slot
                __GIFPlayFrame(frameIdx).isUsed = _TRUE

                ' Read frame size and offset
                __GIFPlayFrame(frameIdx).L = StringFile_ReadInteger(sf)
                __GIFPlayFrame(frameIdx).T = StringFile_ReadInteger(sf)
                W = StringFile_ReadInteger(sf)
                H = StringFile_ReadInteger(sf)

                IF W = 0 _ORELSE H = 0 THEN GOTO gif_load_error

                ' Create a raw frame image from the width and height we got above
                __GIFPlayFrame(frameIdx).image = _NEWIMAGE(W, H, 256)
                IF __GIFPlayFrame(frameIdx).image >= -1 THEN GOTO gif_load_error

                i = StringFile_ReadByte(sf)

                ' Local palette?
                IF _READBIT(i, 7) THEN
                    rawFrame.localColors = _SHL(1, ((i AND 7) + 1))
                    MID$(rawFrame.localPalette, 1, 3 * rawFrame.localColors) = StringFile_ReadString(sf, 3 * rawFrame.localColors)
                END IF

                ' Decode the frame bitmap data
                DIM mI AS _MEM: mI = _MEMIMAGE(__GIFPlayFrame(frameIdx).image)
                IF mI.SIZE = 0 THEN GOTO gif_load_error

                IF NOT __GIF_DecodeLZW(sf, mI) THEN
                    _MEMFREE mI
                    GOTO gif_load_error
                END IF

                _MEMFREE mI

                ' De-interlace the bitmap if it is interlaced
                IF _READBIT(i, 6) THEN __GIF_DeinterlaceFrameImage __GIFPlayFrame(frameIdx).image

                ' Apply palette and transparency
                __GIF_PrepareFrameImage rawFrame, __GIFPlayFrame(frameIdx).image

                ' Update GIF properties
                IF __GIFPlay(idx).firstFrame = -1 THEN
                    ' This is the first frame of the animation
                    __GIFPlay(idx).firstFrame = frameIdx
                    __GIFPlay(idx).frame = frameIdx ' the starting frame
                    __GIFPlayFrame(frameIdx).prevFrame = frameIdx ' make previous frame to point to this
                    __GIFPlayFrame(frameIdx).nextFrame = frameIdx ' make next frame to point to this
                ELSE
                    ' This is not the first frame
                    __GIFPlayFrame(__GIFPlay(idx).firstFrame).prevFrame = frameIdx ' update first frame's previous frame
                    __GIFPlayFrame(__GIFPlay(idx).lastFrame).nextFrame = frameIdx ' udpate last frames's next frame
                    __GIFPlayFrame(frameIdx).prevFrame = __GIFPlay(idx).lastFrame ' previous frame is the last frame
                    __GIFPlayFrame(frameIdx).nextFrame = __GIFPlay(idx).firstFrame ' next frame is the the first frame

                END IF
                __GIFPlay(idx).lastFrame = frameIdx ' make the last frame to point to this
                __GIFPlayFrame(frameIdx).disposalMethod = rawFrame.disposalMethod
                IF rawFrame.duration = 0 THEN rawFrame.duration = 10~% ' 0.1 seconds if no duration is specified (this behavior is from the erstwhile GIFPlay library)
                __GIFPlayFrame(frameIdx).duration = 10~&& * rawFrame.duration ' convert to ticks (ms)
                __GIFPlay(idx).duration = __GIFPlay(idx).duration + __GIFPlayFrame(frameIdx).duration ' add the frame duration to the global duration
                __GIFPlay(idx).frameCount = __GIFPlay(idx).frameCount + 1

                ' Prepare for next frame
                rawFrame.localColors = 0
                rawFrame.localPalette = STRING$(768, 0)
                rawFrame.disposalMethod = 0
                rawFrame.transparentColor = -1 ' no transparent color
                rawFrame.duration = 0

            CASE &H21 ' extension introducer
                DIM j AS _UNSIGNED _BYTE: j = StringFile_ReadByte(sf) ' extension type
                i = StringFile_ReadByte(sf) ' size

                IF j = &HF9 THEN ' graphic control extension
                    ' Size must be 4
                    IF i <> 4 THEN GOTO gif_load_error

                    i = StringFile_ReadByte(sf)

                    rawFrame.disposalMethod = _SHR(i, 2) AND 7
                    rawFrame.duration = StringFile_ReadInteger(sf)

                    IF _READBIT(i, 0) THEN ' transparency?
                        rawFrame.transparentColor = StringFile_ReadByte(sf)
                    ELSE
                        StringFile_Seek sf, StringFile_GetPosition(sf) + 1
                    END IF

                    i = StringFile_ReadByte(sf) ' size
                ELSEIF j = &HFF THEN ' application extension
                    IF i = 11 THEN
                        buffer = StringFile_ReadString(sf, 11)
                        i = StringFile_ReadByte(sf) ' size
                        IF _STRCMP(buffer, "NETSCAPE2.0") = 0 THEN
                            IF i = 3 THEN
                                j = StringFile_ReadByte(sf)
                                __GIFPlay(idx).loops = StringFile_ReadInteger(sf)
                                IF j <> 1 THEN __GIFPlay(idx).loops = 0
                                i = StringFile_ReadByte(sf) ' size
                            END IF
                        END IF
                    END IF
                END IF

                ' Possibly more blocks until terminator block (0)
                WHILE i > 0 _ANDALSO NOT StringFile_IsEOF(sf)
                    DIM seekPos AS _UNSIGNED _OFFSET: seekPos = StringFile_GetPosition(sf) + i
                    IF seekPos > StringFile_GetSize(sf) THEN seekPos = StringFile_GetSize(sf)
                    StringFile_Seek sf, seekPos
                    IF NOT StringFile_IsEOF(sf) THEN
                        i = StringFile_ReadByte(sf)
                    ELSE
                        i = 0
                    END IF
                WEND

            CASE &H3B ' GIF trailer
                EXIT DO
        END SELECT
    LOOP

    ' Bad / corrupt GIF?
    IF __GIFPlay(idx).frameCount = 0 THEN GOTO gif_load_error

    __GIFPlay(idx).isReady = _TRUE ' set the ready flag

    ' Render the first frame and then stop
    GIF_Play Id
    DIM dummy AS LONG: dummy = GIF_GetFrame(Id)
    GIF_Stop Id

    __GIF_Load = _TRUE
    EXIT FUNCTION

    gif_load_error:
    GIF_Free Id ' use GIF_Free() to cleanup if we encountered any error
END FUNCTION

''' @brief Internal helper to retrieve the cached GIF overlay icon image handle.
''' Loads the image from embedded resources on first call.
''' @return The QB64 image handle of the overlay icon.
FUNCTION __GIF_GetOverlayImage&
    CONST SIZE_GIFOVERLAYIMAGE_BMP_16506~& = 16506~&
    CONST COMP_GIFOVERLAYIMAGE_BMP_16506%% = _TRUE
    CONST DATA_GIFOVERLAYIMAGE_BMP_16506 = _
        "eNpy8q1yYACDKiDOAWIHKGZkUGBgZsAF/kMQjDM4gRSgfbsGjt+I4jgexj+2YU57nd27H0Nl6htD6wkzJ31hqFyFWkMVZmZm5rzjMyjfzcwLvEKj" + _
        "tXTnFbyZjxn0O60WBBjDdVjDU/gAP0LwK77CW3gKa7gOY+B3c1k13Ic3ICm9gftQQ8h1BIt4GdInL2MRRxBKHcd1+BIyIF/iehzHYdWpmMXnkEPy" + _
        "OWZxKgZZV2AbEohtXI5B1Di+hQTmW4z3ub3fBQncXX04Hs7CKiQnVnFWhtkfh+TM4zgrgza/AsmplZTHwh2QnLszRT8vheA/LlyObyAF8Q0u9zjm" + _
        "tyEFs52wL5iFFNRsgrXMZ5CC+gwnY/JfBym462LW719BCu4rHIGtRUhJLNo+H29ASuINMxYMQ1JooIUOekYHLTQgFpromJ8V1NFGV7+HOiQjw9C6" + _
        "L0VumzlOB02TvWehhTZ6VoavwX3QehXixWz7ysrK7rPPPrsXmXJfc98zGdqoa8bNzc2/f++tt97a19dJ9/tPP/20H1EPPfSQ/o0mJAOvwdVFabK7" + _
        "bFHCeuSRR/ZMWxh4fuMiTBygzff+u9267XY/X3vttT33Nc3gyn08NTW1474fQP4J3ATx0LH7/eabbzbt24D7mUajEWmWQPLfhHXffT8yMrJjs6Nr" + _
        "+3k00LZZAsq/jqcgCbX+u+8/++yzfc2OOgR1bSNWgPmfwoe+bd/ljig93tGCOLrd/ctvwM4dPLyL7yAJ9Rxt+/Pz8ztmnzTRc1+PYirT/Ibna/AF" + _
        "5KD56Qc0f72v+ROU+V1J6JeM89v2Hy+A/Inav8mm45ht/7b/i9FBPZD2n0X/107ye0YnhP4vzfjnti3BuqShc0FdC7iPQxn/fOc/msX2ZTr/Qd2u" + _
        "be2cIaD5/3oW81/tByzl5vsRZecM2R//3ucJbsLYQdc/bnv/u8616wCX2635Isrse6eRYX6r67H+uRDiqYWeo/mSjE8cN6aPzm78i5mTxbkIrl5J" + _
        "8xroOlfHBbvmN+2iAwkg/6vQuhfixfRvCWj/KN7nv/x1Pc9/DfX5/GcD9ZTnP5Fp/zdkzn+/Xsrz39X1D63z8SWk4L7Eker6Z2mvfx9HXM2U+P4H" + _
        "HQu2IAVDJrIlq8uKd/8TmfxqrMT3v2ndBsm526v7X6v7n6v736vnH6rnX6rnnzI+HmYCeP5tBqeW8PnH63A8wOdfX4L0yUvm+ddQq4a78QokpVdw" + _
        "N2rIY+nz70tYxZN431x3/g7v40msYmlQz7//BcxY2A4="

    STATIC overlayImage AS LONG

    ' Only do this once
    IF overlayImage = 0 THEN
        overlayImage = _LOADIMAGE(Resource_LoadBase64String(DATA_GIFOVERLAYIMAGE_BMP_16506, SIZE_GIFOVERLAYIMAGE_BMP_16506, COMP_GIFOVERLAYIMAGE_BMP_16506), 32, "memory")
    END IF

    __GIF_GetOverlayImage = overlayImage
END FUNCTION
