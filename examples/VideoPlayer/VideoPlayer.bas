': Video Player example - plays standard video files and streams in a PictureBox
': Fellippe Heitor, 2026
': Uses Tony3068's video libraries. SPV videos play as is; other formats need VLC 3.x installed.
': https://github.com/QB64-Phoenix-Edition/InForm-PE
'-----------------------------------------------------------

DEFLNG A-Z
OPTION _EXPLICIT

': Controls' IDs: ------------------------------------------------------------------
DIM SHARED VideoPlayerForm AS LONG
DIM SHARED VideoPictureBox AS LONG
DIM SHARED SeekTrackBar AS LONG
DIM SHARED OpenButton AS LONG
DIM SHARED PlayButton AS LONG
DIM SHARED StopButton AS LONG
DIM SHARED LoopCheckBox AS LONG
DIM SHARED TimeLabel AS LONG
DIM SHARED VolumeLabel AS LONG
DIM SHARED VolumeTrackBar AS LONG

' The seek bar value last set by this program, so moving it from code isn't taken as a seek
DIM SHARED SeekValueByCode AS LONG

': External modules: ---------------------------------------------------------------
'$INCLUDE:'VideoPlayer.bi'
'$INCLUDE:'../../InForm/InForm.bi'
'$INCLUDE:'VideoPlayer.frm'
'$INCLUDE:'../../InForm/InForm.ui'

': Program procedures: -------------------------------------------------------------
SUB OpenVideo (fileName AS STRING)
    IF Video_Open(VideoPictureBox, fileName) THEN
        Video_SetVolume VideoPictureBox, Control(VolumeTrackBar).Value / 100
        Caption(VideoPlayerForm) = "Video Player - " + fileName
        Control(PlayButton).Disabled = False
        Control(StopButton).Disabled = False
        Control(SeekTrackBar).Disabled = (Video_GetLength(VideoPictureBox) <= 0)
        SeekValueByCode = 0
        Control(SeekTrackBar).Value = 0
    ELSE
        MessageBox "Could not open the video:\n\n" + Video_GetError, Caption(VideoPlayerForm), MsgBox_OkOnly + MsgBox_Exclamation
    END IF
END SUB

FUNCTION FormatTime$ (seconds AS DOUBLE)
    DIM s AS LONG: s = INT(seconds)
    DIM m$: m$ = _TOSTR$(s \ 60)
    FormatTime = m$ + ":" + RIGHT$("0" + _TOSTR$(s MOD 60), 2)
END FUNCTION

': Event procedures: ---------------------------------------------------------------
SUB __UI_BeforeInit
END SUB

SUB __UI_OnLoad
    IF NOT Video_IsAvailable THEN
        MessageBox "Only SPV videos can be played: other formats need VLC 3.x (https://www.videolan.org).\n\n" + Video_GetError, Caption(VideoPlayerForm), MsgBox_OkOnly + MsgBox_Exclamation
    END IF

    ' A file or URL can be passed on the command line
    IF LEN(COMMAND$) > 0 THEN OpenVideo COMMAND$
END SUB

SUB __UI_BeforeUpdateDisplay
    IF NOT Video_IsLoaded(VideoPictureBox) THEN EXIT SUB

    Video_Draw VideoPictureBox

    DIM length AS DOUBLE: length = Video_GetLength(VideoPictureBox)
    DIM position AS DOUBLE: position = Video_GetPosition(VideoPictureBox)

    ' Follow the video, unless the user is dragging the seek bar
    IF length > 0 AND NOT (__UI_MouseIsDown AND __UI_MouseDownOnID = SeekTrackBar) THEN
        SeekValueByCode = _ROUND(position / length * 1000)
        Control(SeekTrackBar).Value = SeekValueByCode
    END IF

    Caption(TimeLabel) = FormatTime(position) + " / " + FormatTime(length)

    ' Caption() holds the text without the & hotkey marker
    DIM playCaption AS STRING
    IF Video_IsPlaying(VideoPictureBox) THEN playCaption = "Pause" ELSE playCaption = "Play"
    IF Caption(PlayButton) <> playCaption THEN SetCaption PlayButton, "&" + playCaption
END SUB

SUB __UI_BeforeUnload
    Video_CloseAll
END SUB

SUB __UI_Click (id AS LONG)
    SELECT CASE id
        CASE OpenButton
            DIM fileName AS STRING
            fileName = _OPENFILEDIALOG$(Caption(VideoPlayerForm), , "*.mp4|*.MP4|*.mkv|*.MKV|*.spv|*.SPV|*.webm|*.WEBM|*.avi|*.AVI|*.mov|*.MOV|*.mpg|*.MPG|*.mpeg|*.MPEG", "Video files")
            IF LEN(fileName) > 0 THEN OpenVideo fileName

        CASE PlayButton
            IF Video_IsPlaying(VideoPictureBox) THEN
                Video_Pause VideoPictureBox
            ELSEIF Control(LoopCheckBox).Value THEN
                Video_Loop VideoPictureBox
            ELSE
                Video_Play VideoPictureBox
            END IF

        CASE StopButton
            Video_Stop VideoPictureBox

        CASE ELSE
    END SELECT
END SUB

SUB __UI_MouseEnter (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_MouseLeave (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_FocusIn (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_FocusOut (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_MouseDown (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_MouseUp (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_KeyPress (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_TextChanged (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_ValueChanged (id AS LONG)
    SELECT CASE id
        CASE SeekTrackBar
            IF Control(SeekTrackBar).Value <> SeekValueByCode THEN
                Video_SetPosition VideoPictureBox, Video_GetLength(VideoPictureBox) * Control(SeekTrackBar).Value / 1000
                SeekValueByCode = Control(SeekTrackBar).Value
            END IF

        CASE VolumeTrackBar
            Video_SetVolume VideoPictureBox, Control(VolumeTrackBar).Value / 100

        CASE LoopCheckBox
            ' Switching looping on or off while playing keeps it playing
            IF Video_IsPlaying(VideoPictureBox) THEN
                IF Control(LoopCheckBox).Value THEN Video_Loop VideoPictureBox ELSE Video_Play VideoPictureBox
            END IF

        CASE ELSE
    END SELECT
END SUB

SUB __UI_FormResized
END SUB
