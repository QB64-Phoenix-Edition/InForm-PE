# VideoPlayer Example

This example demonstrates video playback inside an InForm-PE PictureBox control using a custom video player implementation:

- **Standard video files and streams** (MP4, MKV, WebM, AVI, MOV, `http://` and other URLs). Decoding and sound are handled by [VLC](https://www.videolan.org), which is loaded while the program runs.
- **SPV videos**, the format made for the Commander X16, decoded by the library itself, so they play without VLC.

`Video_Open` looks at the file and picks the right player: a file that starts with `SPRV` or ends in `.spv` is an SPV video; anything else goes to VLC.

This example is built on [ahenry3068](https://github.com/ahenry3068)'s .spv video libraries (MIT License): `VIDHandles.bi` routes each video to `SPVHandles.bi` (with `SPVAspect.bi` and `SPVExtra.bi`) or to `VLCHandles.bi` and `qbvlc.h`.

## Requirements

- **To compile:** nothing extra. All required files are included in this example directory: `VideoPlayer.bi`, `VIDHandles.bi`, `VLCHandles.bi`, `qbvlc.h`, `SPVHandles.bi`, `SPVAspect.bi`, `SPVExtra.bi`.
- **To play SPV videos:** nothing extra.
- **To play anything else:** VLC 3.x installed on the computer running the program. VLC 4 is not supported. The VLC build has to match the program:
  - **Windows:** same bitness as QB64-PE (64-bit VLC for a 64-bit program). VLC is found in `Program Files`, or put `libvlc.dll`, `libvlccore.dll` and the `plugins` folder next to the `.exe`.
  - **macOS:** `VLC.app` in `/Applications` or `~/Applications`. On Apple Silicon, use the Universal or Apple Silicon download (the Intel-only build won't load).
  - **Linux:** the VLC runtime, e.g. `sudo apt install libvlc5 vlc-plugin-base`.

Use `Video_IsAvailable` to check for VLC and show a friendly message if it's missing. SPV videos still play without it.

## Usage

This example includes a complete video player with the following features:

- Open video files or URLs
- Play/Pause/Stop controls
- Seek bar for navigation
- Loop toggle
- Volume control
- Time display

To run the example:

1. Ensure QB64-PE is installed
2. Navigate to the `examples/VideoPlayer` directory
3. Compile with QB64-PE: `qb64pe -x -w -e VideoPlayer.bas`
4. Run the compiled executable
5. Open a video file using the Open button, or pass a file/URL as a command-line argument

### Integration into Your Own Project

To use the video player in your own project:

1. Copy the following files from this example to your project's directory:
   - `VideoPlayer.bi`
   - `VIDHandles.bi`
   - `VLCHandles.bi`
   - `qbvlc.h`
   - `SPVHandles.bi`
   - `SPVAspect.bi`
   - `SPVExtra.bi`

2. Include `VideoPlayer.bi` before `InForm.bi` in your `.bas` file:

```vb
': External modules: ---------------------------------------------------------------
'$INCLUDE:'VideoPlayer.bi'
'$INCLUDE:'InForm/InForm.bi'
'$INCLUDE:'MyForm.frm'
'$INCLUDE:'InForm/InForm.ui'
```

1. Use the video player API in your event handlers:

```vb
SUB __UI_OnLoad
    IF Video_Open(VideoPictureBox, "movie.mp4") THEN
        Video_Play VideoPictureBox
    ELSE
        MessageBox Video_GetError, "", MsgBox_OkOnly
    END IF
END SUB

SUB __UI_BeforeUpdateDisplay
    Video_Draw VideoPictureBox
END SUB

SUB __UI_BeforeUnload
    Video_CloseAll
END SUB
```

`Video_Draw` must be called every loop. Besides drawing, it is what makes looping and `Video_SetLimit` work.

## API Reference

`Id` is the control ID of the PictureBox that shows the video. Up to 8 standard videos and 16 SPV videos can be open at once. Seconds and volume are `SINGLE`.

| Name | Description |
| --- | --- |
| `Video_IsAvailable%%` | True if VLC 3.x can be loaded (needed for everything but SPV). On false, `Video_GetError` says why. |
| `Video_Open%% (Id, fileName$)` | Opens a file or URL into the PictureBox and stops on its first frame. Returns false on failure. |
| `Video_Close Id` | Closes the video and clears the PictureBox. |
| `Video_CloseAll` | Closes every video and shuts VLC down. Call it from `__UI_BeforeUnload`. |
| `Video_IsLoaded%% (Id)` | True if a video is open in the PictureBox. |
| `Video_IsSPV%% (Id)` | True if the video is an SPV video. |
| `Video_GetError$` | Text of the last failure. |
| `Video_Play Id` | Plays, or resumes if paused. Turns looping off. |
| `Video_Loop Id` | Plays and restarts the video each time it ends. |
| `Video_Pause Id` | Pauses. `Video_Play` or `Video_Loop` resumes. |
| `Video_Stop Id` | Stops and rewinds to the first frame. |
| `Video_IsPlaying%% (Id)`, `Video_IsPaused%% (Id)` | Play state. |
| `Video_GetLength# (Id)` | Length in seconds (0 for a live stream). |
| `Video_GetPosition# (Id)` | Position in seconds. |
| `Video_SetPosition Id, seconds!` | Jumps to a time, keeping the play state. |
| `Video_SetVolume Id, volume!` | 0 (silent) to 1 (full); standard videos accept up to 2 to boost it. |
| `Video_GetVolume! (Id)` | Current volume. |
| `Video_SetLimit Id, seconds!` | Stops (or, when looping, restarts) at this time. 0 removes the limit. |
| `Video_GetWidth& (Id)`, `Video_GetHeight& (Id)` | Native size of the video in pixels. |
| `Video_GetAspect# (Id)` | Display aspect ratio (width / height). For SPV videos it follows the file's hint byte, so it can differ from the pixel size. |
| `Video_Draw Id` | Draws the newest frame, fitted to the PictureBox at the right aspect ratio and letterboxed with its `BackColor`. SPV bitmap videos are scaled with crisp pixels, everything else smoothly. Only redraws when there is a new frame or the PictureBox changed size. |

## Notes

- **Opening waits for the first frame.** For a local file that is usually well under a second, but a slow stream can take up to 10 seconds, and the form doesn't respond during that time.
- **Decoding size.** VLC decodes the video shrunk to fit the PictureBox's size when it was opened, which keeps playback cheap. If the PictureBox grows afterwards, the picture is scaled up. Reopen the video to get full detail at the new size.
- **SPV timer.** SPV videos are decoded on a QB64 `ON TIMER` that `VideoPlay.bi` starts and stops by itself (it only runs while an SPV video is open), so your program doesn't have to set one up. Don't call `Video_` commands from your own `ON TIMER` handlers.
- **Dialogs.** For standard videos, sound keeps playing while a message box or file dialog is open, but the picture pauses until it closes. SPV videos pause completely and their sound can break up, because the timer can't run while a dialog is open.
- File paths are passed to VLC as UTF-8. Plain ASCII paths are the safest.
