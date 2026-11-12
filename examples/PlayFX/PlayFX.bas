': This program uses
': InForm-PE - GUI library for QB64-PE - v1.6
': https://github.com/QB64-Phoenix-Edition/InForm-PE
'-----------------------------------------------------------

OPTION _EXPLICIT

TYPE VoiceConfig
    enabled AS _BYTE
    waveform AS LONG
    waveParam AS LONG
    volume AS LONG
    pan AS LONG
    attack AS LONG
    decay AS LONG
    sustain AS LONG
    release AS LONG
    quickRamp AS LONG
    tempo AS LONG
    octave AS LONG
    length AS LONG
    articulation AS LONG
END TYPE

TYPE WaveformType
    active AS LONG
    waveform AS LONG
    note AS LONG
    length AS LONG
    lengthType AS LONG
    tempo AS LONG
    volume AS LONG
    volRamp AS LONG
END TYPE

DIM SHARED Voice(1 TO 4) AS VoiceConfig
DIM SHARED isPaused AS _BYTE
DIM SHARED lastPlayingState AS _BYTE
DIM SHARED activeCompVoice AS LONG: activeCompVoice = 1
DIM SHARED updatingText AS _BYTE

DIM SHARED FXWaveform(1 TO 5) AS WaveformType
DIM SHARED currentFXWaveform AS LONG: currentFXWaveform = 1
DIM SHARED currentFXControl AS LONG

': Controls' IDs: ------------------------------------------------------------------
DIM SHARED PlayFXDesigner AS LONG
DIM SHARED MasterFrame AS LONG
DIM SHARED PresetLB AS LONG
DIM SHARED PresetsDL AS LONG
DIM SHARED MasterTempoLB AS LONG
DIM SHARED MasterTempoSlider AS LONG
DIM SHARED MasterTempoValLB AS LONG
DIM SHARED PlayBT AS LONG
DIM SHARED PauseBT AS LONG
DIM SHARED CopyCodeBT AS LONG
DIM SHARED StatusLB AS LONG
DIM SHARED MainTabs AS LONG

DIM SHARED Voice1HeaderLB AS LONG
DIM SHARED Voice1EnableCB AS LONG
DIM SHARED Voice1WaveformDL AS LONG
DIM SHARED V1VolLB AS LONG
DIM SHARED Voice1VolSlider AS LONG
DIM SHARED V1PanLB AS LONG
DIM SHARED Voice1PanSlider AS LONG
DIM SHARED Voice1MeterLB AS LONG
DIM SHARED Voice1SoloBT AS LONG
DIM SHARED Voice1ClearBT AS LONG
DIM SHARED V1MMLLB AS LONG
DIM SHARED Voice1MMLTB AS LONG

DIM SHARED Voice2HeaderLB AS LONG
DIM SHARED Voice2EnableCB AS LONG
DIM SHARED Voice2WaveformDL AS LONG
DIM SHARED V2VolLB AS LONG
DIM SHARED Voice2VolSlider AS LONG
DIM SHARED V2PanLB AS LONG
DIM SHARED Voice2PanSlider AS LONG
DIM SHARED Voice2MeterLB AS LONG
DIM SHARED Voice2SoloBT AS LONG
DIM SHARED Voice2ClearBT AS LONG
DIM SHARED V2MMLLB AS LONG
DIM SHARED Voice2MMLTB AS LONG

DIM SHARED Voice3HeaderLB AS LONG
DIM SHARED Voice3EnableCB AS LONG
DIM SHARED Voice3WaveformDL AS LONG
DIM SHARED V3VolLB AS LONG
DIM SHARED Voice3VolSlider AS LONG
DIM SHARED V3PanLB AS LONG
DIM SHARED Voice3PanSlider AS LONG
DIM SHARED Voice3MeterLB AS LONG
DIM SHARED Voice3SoloBT AS LONG
DIM SHARED Voice3ClearBT AS LONG
DIM SHARED V3MMLLB AS LONG
DIM SHARED Voice3MMLTB AS LONG

DIM SHARED Voice4HeaderLB AS LONG
DIM SHARED Voice4EnableCB AS LONG
DIM SHARED Voice4WaveformDL AS LONG
DIM SHARED V4VolLB AS LONG
DIM SHARED Voice4VolSlider AS LONG
DIM SHARED V4PanLB AS LONG
DIM SHARED Voice4PanSlider AS LONG
DIM SHARED Voice4MeterLB AS LONG
DIM SHARED Voice4SoloBT AS LONG
DIM SHARED Voice4ClearBT AS LONG
DIM SHARED V4MMLLB AS LONG
DIM SHARED Voice4MMLTB AS LONG

DIM SHARED MixerInfoLB AS LONG

DIM SHARED CompTargetLB AS LONG
DIM SHARED CompVoiceDL AS LONG
DIM SHARED CompOctaveLB AS LONG
DIM SHARED CompOctaveDL AS LONG
DIM SHARED CompLengthLB AS LONG
DIM SHARED CompLengthDL AS LONG
DIM SHARED CompArtLB AS LONG
DIM SHARED CompArtDL AS LONG
DIM SHARED PianoHeaderLB AS LONG

DIM SHARED KeyC AS LONG, KeyD AS LONG, KeyE AS LONG, KeyF AS LONG, KeyG AS LONG, KeyA AS LONG, KeyB AS LONG
DIM SHARED KeyC2 AS LONG, KeyD2 AS LONG, KeyE2 AS LONG, KeyF2 AS LONG, KeyG2 AS LONG, KeyA2 AS LONG, KeyB2 AS LONG
DIM SHARED KeyCs AS LONG, KeyDs AS LONG, KeyFs AS LONG, KeyGs AS LONG, KeyAs AS LONG
DIM SHARED KeyCs2 AS LONG, KeyDs2 AS LONG, KeyFs2 AS LONG, KeyGs2 AS LONG, KeyAs2 AS LONG
DIM SHARED KeyRest AS LONG, KeyDot AS LONG, KeyOctDown AS LONG, KeyOctUp AS LONG, KeyTie AS LONG
DIM SHARED KeyInsertHeader AS LONG, KeyBackspace AS LONG, KeyClearMML AS LONG

DIM SHARED SynthHeaderLB AS LONG
DIM SHARED SynthWaveLB AS LONG, SynthWaveDL AS LONG
DIM SHARED SynthDutyLB AS LONG, SynthDutySlider AS LONG, SynthDutyValLB AS LONG
DIM SHARED SynthVolLB AS LONG, SynthVolSlider AS LONG, SynthVolValLB AS LONG
DIM SHARED SynthPanLB AS LONG, SynthPanSlider AS LONG
DIM SHARED AttackLB AS LONG, AttackSlider AS LONG, AttackValLB AS LONG
DIM SHARED DecayLB AS LONG, DecaySlider AS LONG, DecayValLB AS LONG
DIM SHARED SustainLB AS LONG, SustainSlider AS LONG, SustainValLB AS LONG
DIM SHARED ReleaseLB AS LONG, ReleaseSlider AS LONG, ReleaseValLB AS LONG
DIM SHARED QuickRampLB AS LONG, QuickRampSlider AS LONG, QuickRampValLB AS LONG
DIM SHARED ApplySynthBT AS LONG, AuditionVoiceBT AS LONG

DIM SHARED ActiveVoiceHeaderLB AS LONG
DIM SHARED ActiveVoiceMMLTB AS LONG
DIM SHARED PlayActiveVoiceBT AS LONG
DIM SHARED ActiveVoiceStatusLB AS LONG

DIM SHARED FXSlotsHeaderLB AS LONG
DIM SHARED Waveform1TB AS LONG, Waveform2TB AS LONG, Waveform3TB AS LONG, Waveform4TB AS LONG, Waveform5TB AS LONG
DIM SHARED FXConfigHeaderLB AS LONG
DIM SHARED WaveformLB AS LONG, WaveformSlider AS LONG, WaveformNameLB AS LONG
DIM SHARED NoteLB AS LONG, NoteSlider AS LONG
DIM SHARED LengthLB AS LONG, LengthSlider AS LONG, LengthEffectsDL AS LONG
DIM SHARED TempoLB AS LONG, TempoSlider AS LONG
DIM SHARED VolumeLB AS LONG, VolumeSlider AS LONG
DIM SHARED VolRampLB AS LONG, VolRampSlider AS LONG
DIM SHARED PlayFXTB AS LONG, PlayFXPlayBT AS LONG

DIM SHARED RefHeaderLB AS LONG
DIM SHARED RefNotesTitleLB AS LONG, RefNotesLB AS LONG
DIM SHARED RefSynthTitleLB AS LONG, RefSynthLB AS LONG
DIM SHARED RefEnvelopeTitleLB AS LONG, RefEnvelopeLB AS LONG

': External modules: ---------------------------------------------------------------
'$INCLUDE:'../../InForm/InForm.bi'
'$INCLUDE:'PlayFX.frm'
'$INCLUDE:'../../InForm/InForm.ui'

': Custom procedures: --------------------------------------------------------------

SUB InitDefaultVoiceSettings
    DIM i AS LONG
    FOR i = 1 TO 4
        Voice(i).enabled = _TRUE
        Voice(i).waveform = _IIF(i = 1, 9, _IIF(i = 2, 1, _IIF(i = 3, 3, 5)))
        Voice(i).waveParam = 50
        Voice(i).volume = _IIF(i = 4, 60, 80)
        Voice(i).pan = _IIF(i = 1, 35, _IIF(i = 2, 65, 50))
        Voice(i).attack = 5
        Voice(i).decay = 15
        Voice(i).sustain = 70
        Voice(i).release = 10
        Voice(i).quickRamp = 10
        Voice(i).tempo = 140
        Voice(i).octave = _IIF(i = 1, 4, _IIF(i = 2, 4, _IIF(i = 3, 2, 1)))
        Voice(i).length = 4
        Voice(i).articulation = 1 ' Normal MN
    NEXT i
END SUB

FUNCTION GetVoiceMMLTB& (v AS LONG)
    SELECT CASE v
        CASE 1: GetVoiceMMLTB = Voice1MMLTB
        CASE 2: GetVoiceMMLTB = Voice2MMLTB
        CASE 3: GetVoiceMMLTB = Voice3MMLTB
        CASE 4: GetVoiceMMLTB = Voice4MMLTB
    END SELECT
END FUNCTION

SUB SyncMixerControlsFromVoice (v AS LONG)
    SELECT CASE v
        CASE 1
            Control(Voice1EnableCB).Value = Voice(1).enabled
            Control(Voice1WaveformDL).Value = Voice(1).waveform
            Control(Voice1VolSlider).Value = Voice(1).volume
            Control(Voice1PanSlider).Value = Voice(1).pan
        CASE 2
            Control(Voice2EnableCB).Value = Voice(2).enabled
            Control(Voice2WaveformDL).Value = Voice(2).waveform
            Control(Voice2VolSlider).Value = Voice(2).volume
            Control(Voice2PanSlider).Value = Voice(2).pan
        CASE 3
            Control(Voice3EnableCB).Value = Voice(3).enabled
            Control(Voice3WaveformDL).Value = Voice(3).waveform
            Control(Voice3VolSlider).Value = Voice(3).volume
            Control(Voice3PanSlider).Value = Voice(3).pan
        CASE 4
            Control(Voice4EnableCB).Value = Voice(4).enabled
            Control(Voice4WaveformDL).Value = Voice(4).waveform
            Control(Voice4VolSlider).Value = Voice(4).volume
            Control(Voice4PanSlider).Value = Voice(4).pan
    END SELECT
END SUB

SUB SyncComposerFromActiveVoice
    DIM v AS LONG: v = activeCompVoice
    IF v < 1 _ORELSE v > 4 THEN v = 1

    Control(CompVoiceDL).Value = v
    Control(CompOctaveDL).Value = Voice(v).octave + 1 ' 0..6 maps to 1..7
    Control(SynthWaveDL).Value = Voice(v).waveform
    Control(SynthDutySlider).Value = Voice(v).waveParam
    SetCaption SynthDutyValLB, LTRIM$(STR$(Voice(v).waveParam)) + "%"

    Control(SynthVolSlider).Value = Voice(v).volume
    SetCaption SynthVolValLB, LTRIM$(STR$(Voice(v).volume))

    Control(SynthPanSlider).Value = Voice(v).pan

    Control(AttackSlider).Value = Voice(v).attack
    SetCaption AttackValLB, LTRIM$(STR$(Voice(v).attack)) + "%"

    Control(DecaySlider).Value = Voice(v).decay
    SetCaption DecayValLB, LTRIM$(STR$(Voice(v).decay)) + "%"

    Control(SustainSlider).Value = Voice(v).sustain
    SetCaption SustainValLB, LTRIM$(STR$(Voice(v).sustain)) + "%"

    Control(ReleaseSlider).Value = Voice(v).release
    SetCaption ReleaseValLB, LTRIM$(STR$(Voice(v).release)) + "%"

    Control(QuickRampSlider).Value = Voice(v).quickRamp
    SetCaption QuickRampValLB, LTRIM$(STR$(Voice(v).quickRamp)) + "%"

    updatingText = _TRUE
    Text(ActiveVoiceMMLTB) = Text(GetVoiceMMLTB(v))
    updatingText = _FALSE
    SetCaption ActiveVoiceStatusLB, "Voice " + LTRIM$(STR$(v)) + " loaded for editing."
END SUB

SUB ApplyComposerToActiveVoice
    DIM v AS LONG: v = activeCompVoice
    IF v < 1 _ORELSE v > 4 THEN v = 1

    Voice(v).waveform = Control(SynthWaveDL).Value
    Voice(v).waveParam = Control(SynthDutySlider).Value
    Voice(v).volume = Control(SynthVolSlider).Value
    Voice(v).pan = Control(SynthPanSlider).Value
    Voice(v).attack = Control(AttackSlider).Value
    Voice(v).decay = Control(DecaySlider).Value
    Voice(v).sustain = Control(SustainSlider).Value
    Voice(v).release = Control(ReleaseSlider).Value
    Voice(v).quickRamp = Control(QuickRampSlider).Value
    Voice(v).octave = Control(CompOctaveDL).Value - 1

    SyncMixerControlsFromVoice v
    updatingText = _TRUE
    Text(GetVoiceMMLTB(v)) = Text(ActiveVoiceMMLTB)
    updatingText = _FALSE
    SetCaption ActiveVoiceStatusLB, "Voice " + LTRIM$(STR$(v)) + " settings applied."
END SUB

FUNCTION BuildVoiceSetupHeader$ (v AS LONG)
    DIM h AS STRING
    h = "@" + LTRIM$(STR$(Voice(v).waveform))
    IF Voice(v).waveform = 8 _ORELSE Voice(v).waveform = 9 THEN
        h = h + "Y" + LTRIM$(STR$(Voice(v).waveParam))
    END IF
    h = h + "V" + LTRIM$(STR$(Voice(v).volume))
    h = h + "S" + LTRIM$(STR$(Voice(v).pan))
    IF Voice(v).quickRamp > 0 THEN
        h = h + "Q" + LTRIM$(STR$(Voice(v).quickRamp))
    ELSE
        h = h + "/" + LTRIM$(STR$(Voice(v).attack)) + "\" + LTRIM$(STR$(Voice(v).decay)) + "^" + LTRIM$(STR$(Voice(v).sustain)) + "_" + LTRIM$(STR$(Voice(v).release))
    END IF
    BuildVoiceSetupHeader = h + " "
END FUNCTION

FUNCTION BuildFinalVoiceString$ (v AS LONG)
    IF NOT Voice(v).enabled THEN
        BuildFinalVoiceString = ""
        EXIT FUNCTION
    END IF

    DIM rawMML AS STRING: rawMML = _TRIM$(Text(GetVoiceMMLTB(v)))
    IF LEN(rawMML) = 0 THEN
        BuildFinalVoiceString = ""
        EXIT FUNCTION
    END IF

    DIM res AS STRING
    res = "MB "

    ' If the raw MML doesn't already specify tempo, add master tempo
    IF INSTR(UCASE$(rawMML), "T") = 0 THEN
        res = res + "T" + LTRIM$(STR$(Control(MasterTempoSlider).Value)) + " "
    END IF

    ' If raw MML doesn't already specify waveform @, prepend voice setup header
    IF INSTR(rawMML, "@") = 0 _ANDALSO INSTR(UCASE$(rawMML), "W") = 0 THEN
        res = res + BuildVoiceSetupHeader(v)
    END IF

    res = res + rawMML
    BuildFinalVoiceString = res
END FUNCTION

SUB PlayAllVoices
    IF isPaused THEN
        SOUND RESUME
        isPaused = _FALSE
        SetCaption PauseBT, "P&ause"
        SetCaption StatusLB, "Resumed playback."
        EXIT SUB
    END IF

    DIM AS STRING v1, v2, v3, v4
    v1 = BuildFinalVoiceString(1)
    v2 = BuildFinalVoiceString(2)
    v3 = BuildFinalVoiceString(3)
    v4 = BuildFinalVoiceString(4)

    IF LEN(v1) = 0 _ANDALSO LEN(v2) = 0 _ANDALSO LEN(v3) = 0 _ANDALSO LEN(v4) = 0 THEN
        SetCaption StatusLB, "No active voice MML to play."
        EXIT SUB
    END IF

    PLAY v1, v2, v3, v4

    isPaused = _FALSE
    SetCaption PauseBT, "P&ause"
    SetCaption StatusLB, "Playing 4-voice MML tune..."
END SUB

SUB PauseResumePlayback
    IF isPaused THEN
        SOUND RESUME
        isPaused = _FALSE
        SetCaption PauseBT, "P&ause"
        SetCaption StatusLB, "Resumed playback."
    ELSE
        SOUND WAIT
        isPaused = _TRUE
        SetCaption PauseBT, "Res&ume"
        SetCaption StatusLB, "Playback paused."
    END IF
END SUB

SUB SoloVoice (v AS LONG)
    DIM i AS LONG
    FOR i = 1 TO 4
        Voice(i).enabled = _IIF(i = v, _TRUE, _FALSE)
        SyncMixerControlsFromVoice i
    NEXT i
    SetCaption StatusLB, "Soloing Voice " + LTRIM$(STR$(v)) + "."
END SUB

SUB ClearVoiceMML (v AS LONG)
    updatingText = _TRUE
    Text(GetVoiceMMLTB(v)) = ""
    IF v = activeCompVoice THEN Text(ActiveVoiceMMLTB) = ""
    updatingText = _FALSE
    SetCaption StatusLB, "Cleared MML for Voice " + LTRIM$(STR$(v)) + "."
END SUB

SUB AppendNoteToActiveVoice (noteToken AS STRING)
    DIM v AS LONG: v = activeCompVoice
    DIM cur AS STRING: cur = _TRIM$(Text(GetVoiceMMLTB(v)))

    IF LEN(cur) > 0 THEN
        cur = cur + " " + noteToken
    ELSE
        cur = noteToken
    END IF

    updatingText = _TRUE
    Text(GetVoiceMMLTB(v)) = cur
    Text(ActiveVoiceMMLTB) = cur
    updatingText = _FALSE
    SetCaption ActiveVoiceStatusLB, "Appended: " + noteToken
END SUB

SUB AuditionTone (noteName AS STRING, octaveShift AS LONG)
    DIM v AS LONG: v = activeCompVoice
    DIM oct AS LONG: oct = Control(CompOctaveDL).Value - 1 + octaveShift
    IF oct < 0 THEN oct = 0
    IF oct > 6 THEN oct = 6

    DIM lenCode AS LONG
    SELECT CASE Control(CompLengthDL).Value
        CASE 1: lenCode = 1
        CASE 2: lenCode = 2
        CASE 3: lenCode = 4
        CASE 4: lenCode = 8
        CASE 5: lenCode = 16
        CASE 6: lenCode = 32
        CASE 7: lenCode = 64
        CASE ELSE: lenCode = 4
    END SELECT

    DIM artCode AS STRING
    SELECT CASE Control(CompArtDL).Value
        CASE 1: artCode = "MN"
        CASE 2: artCode = "ML"
        CASE 3: artCode = "MS"
        CASE ELSE: artCode = "MN"
    END SELECT

    ' Single note preview play
    DIM previewMML AS STRING
    previewMML = "MB T140 @" + LTRIM$(STR$(Control(SynthWaveDL).Value))
    IF Control(SynthWaveDL).Value = 8 _ORELSE Control(SynthWaveDL).Value = 9 THEN
        previewMML = previewMML + "Y" + LTRIM$(STR$(Control(SynthDutySlider).Value))
    END IF
    previewMML = previewMML + "V" + LTRIM$(STR$(Control(SynthVolSlider).Value))
    previewMML = previewMML + "S" + LTRIM$(STR$(Control(SynthPanSlider).Value))
    previewMML = previewMML + " " + artCode + " O" + LTRIM$(STR$(oct)) + " L" + LTRIM$(STR$(lenCode)) + " " + noteName

    PLAY previewMML

    ' Append to voice stream
    DIM appendToken AS STRING: appendToken = "O" + LTRIM$(STR$(oct)) + " " + noteName + LTRIM$(STR$(lenCode))
    AppendNoteToActiveVoice appendToken
END SUB

SUB CopyQB64CodeToClipboard
    DIM AS STRING v1, v2, v3, v4
    v1 = BuildFinalVoiceString(1)
    v2 = BuildFinalVoiceString(2)
    v3 = BuildFinalVoiceString(3)
    v4 = BuildFinalVoiceString(4)

    DIM code AS STRING
    code = "'--------------------------------------------------------------------------------" + _CHR_LF
    code = code + "' 4-Voice MML Tune generated by PlayFX - 4-Voice MML Studio" + _CHR_LF
    code = code + "' Requires QB64-PE v4.0.0 or later" + _CHR_LF
    code = code + "'--------------------------------------------------------------------------------" + _CHR_LF
    code = code + "DIM SHARED AS STRING v1, v2, v3, v4" + _CHR_LF + _CHR_LF
    code = code + "v1 = " + _CHR_QUOTE + v1 + _CHR_QUOTE + _CHR_LF
    code = code + "v2 = " + _CHR_QUOTE + v2 + _CHR_QUOTE + _CHR_LF
    code = code + "v3 = " + _CHR_QUOTE + v3 + _CHR_QUOTE + _CHR_LF
    code = code + "v4 = " + _CHR_QUOTE + v4 + _CHR_QUOTE + _CHR_LF + _CHR_LF
    code = code + "PLAY v1, v2, v3, v4" + _CHR_LF + _CHR_LF
    code = code + "' Wait until tune finishes" + _CHR_LF
    code = code + "WHILE PLAY(0) > 0 _ORELSE PLAY(1) > 0 _ORELSE PLAY(2) > 0 _ORELSE PLAY(3) > 0" + _CHR_LF
    code = code + "    _LIMIT 30" + _CHR_LF
    code = code + "WEND" + _CHR_LF

    _CLIPBOARD$ = code
    SetCaption StatusLB, "QB64-PE code copied to clipboard!"
END SUB

SUB LoadPreset (idx AS LONG)
    updatingText = _TRUE
    SELECT CASE idx
        CASE 1 ' Korobeiniki (Tetris) - 4-voice chiptune
            Control(MasterTempoSlider).Value = 144
            SetCaption MasterTempoValLB, "144"

            Voice(1).waveform = 9 ' Pulse lead
            Voice(1).waveParam = 50
            Voice(1).volume = 90
            Voice(1).pan = 35

            Voice(2).waveform = 1 ' Square harmony
            Voice(2).volume = 75
            Voice(2).pan = 65

            Voice(3).waveform = 3 ' Triangle bass
            Voice(3).volume = 95
            Voice(3).pan = 50

            Voice(4).waveform = 5 ' Noise drums
            Voice(4).volume = 60
            Voice(4).pan = 50

            Text(Voice1MMLTB) = "@9 Y50 V90 S35 O4 L8 E B4 C8 D4 C8 B4 A4 A8 C8 E4 D8 C4 B4. C8 D4 E4 C4 A4 A2 P8 D4. F8 O5 A4 G8 F4 E4. C8 E4 D8 C4 B4 B8 C8 D4 E4 C4 A4 A2 P8"
            Text(Voice2MMLTB) = "@1 V75 S65 O3 L8 G#4 A4. B8 G#4 E4. A8 O4 C4 O3 B8 A4 G#4. A8 B4 O4 C4 O3 A4 E4 E2 P8 F4. A8 O4 D4 C8 O3 B4 G4. E8 G4 F8 E4 D4 D8 E8 F4 G4 E4 C4 C2 P8"
            Text(Voice3MMLTB) = "@3 V95 S50 O2 L4 E E A A G# G# A A F F C C E E A A D D F F C C E E E E E E A A A2 P8"
            Text(Voice4MMLTB) = "@5 Q6 V60 S50 O1 L8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8 N20 N8"

        CASE 2 ' Pachelbel - Canon in D
            Control(MasterTempoSlider).Value = 96
            SetCaption MasterTempoValLB, "96"

            Voice(1).waveform = 4: Voice(1).volume = 85: Voice(1).pan = 30 ' Flute/Sine
            Voice(2).waveform = 1: Voice(2).volume = 75: Voice(2).pan = 70 ' Warm Square
            Voice(3).waveform = 2: Voice(3).volume = 70: Voice(3).pan = 40 ' Soft Saw
            Voice(4).waveform = 3: Voice(4).volume = 95: Voice(4).pan = 60 ' Triangle Cello

            Text(Voice1MMLTB) = "@4 V85 S30 O5 L4 F# E D C# O4 B A B C# O5 D C# O4 B A G F# G E O5 F# E D C# O4 B A B C# D2"
            Text(Voice2MMLTB) = "@1 V75 S70 P1 O4 L4 D C# O3 B A G F# G A O4 D C# O3 B A G F# G E O4 F# E D C# O3 B A B C# D2"
            Text(Voice3MMLTB) = "@2 V70 S40 P1 P1 O4 L4 F# E D C# O3 B A B C# O4 D C# O3 B A G F# G E O4 D C# O3 B A G F# G A B2"
            Text(Voice4MMLTB) = "@3 V95 S60 O3 L4 D O2 A B F# G D G A O3 D O2 A B F# G D G A O3 D O2 A B F# G D G A D2"

        CASE 3 ' J.S. Bach - Minuet in G
            Control(MasterTempoSlider).Value = 120
            SetCaption MasterTempoValLB, "120"

            Voice(1).waveform = 1: Voice(1).volume = 85: Voice(1).pan = 40
            Voice(2).waveform = 4: Voice(2).volume = 70: Voice(2).pan = 60
            Voice(3).waveform = 2: Voice(3).volume = 65: Voice(3).pan = 30
            Voice(4).waveform = 3: Voice(4).volume = 90: Voice(4).pan = 50

            Text(Voice1MMLTB) = "@1 V85 S40 O4 L4 D8 G8 A8 B8 O5 C8 D4 G4 G4 E8 C8 D8 E8 F#8 G4 G4 G4 C8 D8 C8 O4 B8 A8 B8 O5 C8 O4 B8 A8 G8 F#8 G8 A8 B8 G8 B4 A2"
            Text(Voice2MMLTB) = "@4 V70 S60 O3 L4 G2. F#2. E2. D2. E2. D2. C2. D4 D2"
            Text(Voice3MMLTB) = "@2 V65 S30 O3 L4 B4 O4 D4 G4 A4 O4 D4 F#4 G4 O4 C4 E4 F#4 O3 A4 O4 D4 E4 G4 O4 C4 D4 G4 O4 B4 C4 E4 A4 D4 F#2"
            Text(Voice4MMLTB) = "@3 V90 S50 O2 L4 G2. D2. E2. B2. C2. G2. A2. D4 D2"

        CASE 4 ' Greensleeves
            Control(MasterTempoSlider).Value = 110
            SetCaption MasterTempoValLB, "110"

            Voice(1).waveform = 4: Voice(1).volume = 90: Voice(1).pan = 45
            Voice(2).waveform = 1: Voice(2).volume = 75: Voice(2).pan = 65
            Voice(3).waveform = 2: Voice(3).volume = 70: Voice(3).pan = 30
            Voice(4).waveform = 3: Voice(4).volume = 95: Voice(4).pan = 50

            Text(Voice1MMLTB) = "@4 V90 S45 O4 L4 A8 O5 C4 D8 E4. F8 E8 D4 O4 B8 G4. A8 B8 O5 C4 O4 A8 A4. G#8 A8 B4 G#8 E4. A8 O5 C4 D8 E4. F8 E8 D4 O4 B8 G4. A8 B8 O5 C4. O4 B4 A8 G#4. F#8 G#8 A2."
            Text(Voice2MMLTB) = "@1 V75 S65 O4 L4 E8 A4 B8 O5 C4. D8 C8 O4 B4 G8 E4. F8 G8 A4 F8 F4. E8 F8 G4 E8 O3 B4. O4 E8 A4 B8 O5 C4. D8 C8 O4 B4 G8 E4. F8 G8 A4. G4 F8 E4. D8 E8 E2."
            Text(Voice3MMLTB) = "@2 V70 S30 O3 L8 A O4 C E C A C G O4 D G D O3 G B F O4 C F C O3 F A E O4 C E C O3 E G# A O4 C E C A C G O4 D G D O3 G B F O4 C F C O3 F A E O3 B O4 E O3 B A2."
            Text(Voice4MMLTB) = "@3 V95 S50 O2 L2. A G F E A G F E A."

        CASE 5 ' Retro Arcade SFX
            Control(MasterTempoSlider).Value = 180
            SetCaption MasterTempoValLB, "180"

            Voice(1).waveform = 2: Voice(1).volume = 85: Voice(1).pan = 25
            Voice(2).waveform = 9: Voice(2).waveParam = 25: Voice(2).volume = 80: Voice(2).pan = 75
            Voice(3).waveform = 1: Voice(3).volume = 75: Voice(3).pan = 50
            Voice(4).waveform = 7: Voice(4).volume = 85: Voice(4).pan = 50

            Text(Voice1MMLTB) = "T255 @2 Q1 L64 O6 B A G F E D C O5 B A G F E D C O4 B A G F E D C"
            Text(Voice2MMLTB) = "T200 @9 Y25 L32 O3 C E G O4 C E G O3 G E C P16 O3 C E G O4 C E G"
            Text(Voice3MMLTB) = "T180 @1 L16 O5 C G C G C G C G"
            Text(Voice4MMLTB) = "T160 @7 Q15 L16 O1 N10 N8 N6 N4 N3 N2 N1"

        CASE 6 ' Original PlayFX Chords
            Control(MasterTempoSlider).Value = 120
            SetCaption MasterTempoValLB, "120"
            Voice(1).waveform = 3: Voice(1).volume = 100: Voice(1).pan = 50
            Voice(2).waveform = 3: Voice(2).volume = 80: Voice(2).pan = 35
            Voice(3).waveform = 3: Voice(3).volume = 80: Voice(3).pan = 65
            Voice(4).waveform = 5: Voice(4).volume = 50: Voice(4).pan = 50

            Text(Voice1MMLTB) = "T120 L4 MN V100 Q10 @3 N42"
            Text(Voice2MMLTB) = "T120 L4 MN V80 Q10 @3 N46"
            Text(Voice3MMLTB) = "T120 L4 MN V80 Q10 @3 N49"
            Text(Voice4MMLTB) = "T120 L4 MN V50 Q10 @5 N15"

        CASE ELSE ' Custom / Empty
            DIM i AS LONG
            FOR i = 1 TO 4
                Text(GetVoiceMMLTB(i)) = ""
            NEXT i
    END SELECT
    updatingText = _FALSE

    DIM j AS LONG
    FOR j = 1 TO 4
        Voice(j).enabled = _TRUE
        SyncMixerControlsFromVoice j
    NEXT j

    SyncComposerFromActiveVoice
    SetCaption StatusLB, "Loaded preset: " + GetItem$(PresetsDL, idx)
END SUB

': FX Synthesizer (Tab 3) Procedures: ----------------------------------------------
SUB SetFXConfigControls (id AS LONG, curCtrl AS LONG)
    Control(WaveformSlider).Value = FXWaveform(id).waveform
    Control(NoteSlider).Value = FXWaveform(id).note
    Control(LengthSlider).Value = FXWaveform(id).length
    Control(LengthEffectsDL).Value = FXWaveform(id).lengthType
    Control(TempoSlider).Value = FXWaveform(id).tempo
    Control(VolumeSlider).Value = FXWaveform(id).volume
    Control(VolRampSlider).Value = FXWaveform(id).volRamp

    currentFXWaveform = id
    currentFXControl = curCtrl
END SUB

SUB ClearFXWaveform (id AS LONG)
    FXWaveform(id).active = _FALSE
    FXWaveform(id).waveform = 3
    FXWaveform(id).note = 42
    FXWaveform(id).length = 4
    FXWaveform(id).lengthType = 1
    FXWaveform(id).tempo = 120
    FXWaveform(id).volume = 100
    FXWaveform(id).volRamp = 10
END SUB

SUB MakePlayFXSlotString
    DIM s AS STRING
    IF FXWaveform(currentFXWaveform).active THEN
        s = "T" + LTRIM$(STR$(FXWaveform(currentFXWaveform).tempo)) + "L" + LTRIM$(STR$(FXWaveform(currentFXWaveform).length))
        SELECT CASE FXWaveform(currentFXWaveform).lengthType
            CASE 1: s = s + "MN"
            CASE 2: s = s + "ML"
            CASE 3: s = s + "MS"
        END SELECT
        s = s + "V" + LTRIM$(STR$(FXWaveform(currentFXWaveform).volume)) + "Q" + LTRIM$(STR$(FXWaveform(currentFXWaveform).volRamp))
        s = s + "@" + LTRIM$(STR$(FXWaveform(currentFXWaveform).waveform)) + "N" + LTRIM$(STR$(FXWaveform(currentFXWaveform).note))
    END IF
    IF currentFXControl > 0 THEN Text(currentFXControl) = s
END SUB

SUB MakeCombinedPlayFXString
    DIM s AS STRING: s = "MB"
    IF LEN(Text(Waveform1TB)) > 0 THEN s = s + Text(Waveform1TB)
    IF LEN(Text(Waveform2TB)) > 0 THEN s = s + "," + Text(Waveform2TB)
    IF LEN(Text(Waveform3TB)) > 0 THEN s = s + "," + Text(Waveform3TB)
    IF LEN(Text(Waveform4TB)) > 0 THEN s = s + "," + Text(Waveform4TB)
    IF LEN(Text(Waveform5TB)) > 0 THEN s = s + "," + Text(Waveform5TB)
    Text(PlayFXTB) = s
END SUB

': Event procedures: ---------------------------------------------------------------

SUB __UI_BeforeInit

END SUB

SUB __UI_OnLoad
    InitDefaultVoiceSettings

    DIM i AS LONG
    FOR i = 1 TO 5
        ClearFXWaveform i
    NEXT i

    SetFXConfigControls 1, Waveform1TB
    LoadPreset 1
    SyncComposerFromActiveVoice
END SUB

SUB __UI_BeforeUpdateDisplay
    ' Real-time audio polling at 60 FPS
    DIM p0 AS DOUBLE: p0 = PLAY(0)
    DIM p1 AS DOUBLE: p1 = PLAY(1)
    DIM p2 AS DOUBLE: p2 = PLAY(2)
    DIM p3 AS DOUBLE: p3 = PLAY(3)

    DIM isPlaying AS _BYTE
    isPlaying = (p0 > 0 _ORELSE p1 > 0 _ORELSE p2 > 0 _ORELSE p3 > 0)

    IF isPlaying THEN
        SetCaption Voice1MeterLB, _IIF(p0 > 0, "PLAYING (" + LTRIM$(STR$(INT(p0 * 10) / 10)) + "s)", "Idle (0.00s)")
        SetCaption Voice2MeterLB, _IIF(p1 > 0, "PLAYING (" + LTRIM$(STR$(INT(p1 * 10) / 10)) + "s)", "Idle (0.00s)")
        SetCaption Voice3MeterLB, _IIF(p2 > 0, "PLAYING (" + LTRIM$(STR$(INT(p2 * 10) / 10)) + "s)", "Idle (0.00s)")
        SetCaption Voice4MeterLB, _IIF(p3 > 0, "PLAYING (" + LTRIM$(STR$(INT(p3 * 10) / 10)) + "s)", "Idle (0.00s)")

        DIM maxT AS DOUBLE: maxT = p0
        IF p1 > maxT THEN maxT = p1
        IF p2 > maxT THEN maxT = p2
        IF p3 > maxT THEN maxT = p3

        IF NOT isPaused THEN
            SetCaption StatusLB, "Playing 4-voice MML tune (" + LTRIM$(STR$(INT(maxT * 10) / 10)) + "s remaining)..."
        END IF
        lastPlayingState = _TRUE
    ELSEIF lastPlayingState THEN
        lastPlayingState = _FALSE
        SetCaption Voice1MeterLB, "Idle (0.00s)"
        SetCaption Voice2MeterLB, "Idle (0.00s)"
        SetCaption Voice3MeterLB, "Idle (0.00s)"
        SetCaption Voice4MeterLB, "Idle (0.00s)"
        SetCaption StatusLB, "Playback complete. Ready."
    END IF
END SUB

SUB __UI_BeforeUnload

END SUB

SUB __UI_Click (id AS LONG)
    SELECT CASE id
        ' Master controls
        CASE PlayBT
            PlayAllVoices

        CASE PauseBT
            PauseResumePlayback

        CASE CopyCodeBT
            CopyQB64CodeToClipboard

        ' Voice 1-4 Mixer Buttons
        CASE Voice1SoloBT: SoloVoice 1
        CASE Voice1ClearBT: ClearVoiceMML 1
        CASE Voice2SoloBT: SoloVoice 2
        CASE Voice2ClearBT: ClearVoiceMML 2
        CASE Voice3SoloBT: SoloVoice 3
        CASE Voice3ClearBT: ClearVoiceMML 3
        CASE Voice4SoloBT: SoloVoice 4
        CASE Voice4ClearBT: ClearVoiceMML 4

        ' Interactive Piano Keyboard Keys (Octave 1)
        CASE KeyC: AuditionTone "C", 0
        CASE KeyCs: AuditionTone "C#", 0
        CASE KeyD: AuditionTone "D", 0
        CASE KeyDs: AuditionTone "D#", 0
        CASE KeyE: AuditionTone "E", 0
        CASE KeyF: AuditionTone "F", 0
        CASE KeyFs: AuditionTone "F#", 0
        CASE KeyG: AuditionTone "G", 0
        CASE KeyGs: AuditionTone "G#", 0
        CASE KeyA: AuditionTone "A", 0
        CASE KeyAs: AuditionTone "A#", 0
        CASE KeyB: AuditionTone "B", 0

        ' Interactive Piano Keyboard Keys (Octave 2)
        CASE KeyC2: AuditionTone "C", 1
        CASE KeyCs2: AuditionTone "C#", 1
        CASE KeyD2: AuditionTone "D", 1
        CASE KeyDs2: AuditionTone "D#", 1
        CASE KeyE2: AuditionTone "E", 1
        CASE KeyF2: AuditionTone "F", 1
        CASE KeyFs2: AuditionTone "F#", 1
        CASE KeyG2: AuditionTone "G", 1
        CASE KeyGs2: AuditionTone "G#", 1
        CASE KeyA2: AuditionTone "A", 1
        CASE KeyAs2: AuditionTone "A#", 1
        CASE KeyB2: AuditionTone "B", 1

        ' Note Helper Buttons
        CASE KeyRest
            DIM rLen AS LONG
            SELECT CASE Control(CompLengthDL).Value
                CASE 1: rLen = 1
                CASE 2: rLen = 2
                CASE 3: rLen = 4
                CASE 4: rLen = 8
                CASE 5: rLen = 16
                CASE 6: rLen = 32
                CASE 7: rLen = 64
                CASE ELSE: rLen = 4
            END SELECT
            AppendNoteToActiveVoice "P" + LTRIM$(STR$(rLen))

        CASE KeyDot
            AppendNoteToActiveVoice "."

        CASE KeyOctDown
            AppendNoteToActiveVoice "<"

        CASE KeyOctUp
            AppendNoteToActiveVoice ">"

        CASE KeyTie
            AppendNoteToActiveVoice ","

        CASE KeyInsertHeader
            AppendNoteToActiveVoice BuildVoiceSetupHeader(activeCompVoice)

        CASE KeyBackspace
            DIM bText AS STRING: bText = _TRIM$(Text(GetVoiceMMLTB(activeCompVoice)))
            DIM lastSpace AS LONG: lastSpace = _INSTRREV(bText, " ")
            IF lastSpace > 0 THEN
                bText = LEFT$(bText, lastSpace - 1)
            ELSE
                bText = ""
            END IF
            updatingText = _TRUE
            Text(GetVoiceMMLTB(activeCompVoice)) = bText
            Text(ActiveVoiceMMLTB) = bText
            updatingText = _FALSE
            SetCaption ActiveVoiceStatusLB, "Removed last token."

        CASE KeyClearMML
            ClearVoiceMML activeCompVoice

        ' Composer Synth Buttons
        CASE ApplySynthBT
            ApplyComposerToActiveVoice

        CASE AuditionVoiceBT
            AuditionTone "C", 0

        CASE PlayActiveVoiceBT
            DIM oneVoiceMML AS STRING
            oneVoiceMML = BuildFinalVoiceString(activeCompVoice)
            IF LEN(oneVoiceMML) > 0 THEN
                PLAY oneVoiceMML
                SetCaption ActiveVoiceStatusLB, "Playing Voice " + LTRIM$(STR$(activeCompVoice)) + "..."
            ELSE
                SetCaption ActiveVoiceStatusLB, "Voice " + LTRIM$(STR$(activeCompVoice)) + " is empty or muted."
            END IF

        ' Tab 3: Sound FX Designer
        CASE PlayFXPlayBT
            PLAY Text(PlayFXTB)
    END SELECT
END SUB

SUB __UI_MouseEnter (id AS LONG)
    IF id = 0 THEN EXIT SUB
END SUB

SUB __UI_MouseLeave (id AS LONG)
    IF id = 0 THEN EXIT SUB
END SUB

SUB __UI_FocusIn (id AS LONG)
    SELECT CASE id
        CASE Waveform1TB: SetFXConfigControls 1, Waveform1TB
        CASE Waveform2TB: SetFXConfigControls 2, Waveform2TB
        CASE Waveform3TB: SetFXConfigControls 3, Waveform3TB
        CASE Waveform4TB: SetFXConfigControls 4, Waveform4TB
        CASE Waveform5TB: SetFXConfigControls 5, Waveform5TB
    END SELECT
END SUB

SUB __UI_FocusOut (id AS LONG)
    IF id = 0 THEN EXIT SUB
END SUB

SUB __UI_MouseDown (id AS LONG)
    IF id = 0 THEN EXIT SUB
END SUB

SUB __UI_MouseUp (id AS LONG)
    IF id = 0 THEN EXIT SUB
END SUB

SUB __UI_KeyPress (id AS LONG)
    IF id = 0 THEN EXIT SUB
END SUB

SUB __UI_TextChanged (id AS LONG)
    IF updatingText THEN EXIT SUB
    updatingText = _TRUE

    SELECT CASE id
        CASE Voice1MMLTB
            IF activeCompVoice = 1 THEN Text(ActiveVoiceMMLTB) = Text(Voice1MMLTB)
        CASE Voice2MMLTB
            IF activeCompVoice = 2 THEN Text(ActiveVoiceMMLTB) = Text(Voice2MMLTB)
        CASE Voice3MMLTB
            IF activeCompVoice = 3 THEN Text(ActiveVoiceMMLTB) = Text(Voice3MMLTB)
        CASE Voice4MMLTB
            IF activeCompVoice = 4 THEN Text(ActiveVoiceMMLTB) = Text(Voice4MMLTB)
        CASE ActiveVoiceMMLTB
            Text(GetVoiceMMLTB(activeCompVoice)) = Text(ActiveVoiceMMLTB)

        ' Tab 3 slots
        CASE Waveform1TB
            IF Text(id) = "" THEN ClearFXWaveform 1: SetFXConfigControls 1, Waveform1TB
        CASE Waveform2TB
            IF Text(id) = "" THEN ClearFXWaveform 2: SetFXConfigControls 2, Waveform2TB
        CASE Waveform3TB
            IF Text(id) = "" THEN ClearFXWaveform 3: SetFXConfigControls 3, Waveform3TB
        CASE Waveform4TB
            IF Text(id) = "" THEN ClearFXWaveform 4: SetFXConfigControls 4, Waveform4TB
        CASE Waveform5TB
            IF Text(id) = "" THEN ClearFXWaveform 5: SetFXConfigControls 5, Waveform5TB
    END SELECT

    updatingText = _FALSE
END SUB

SUB __UI_ValueChanged (id AS LONG)
    SELECT CASE id
        CASE PresetsDL
            LoadPreset Control(PresetsDL).Value

        CASE MasterTempoSlider
            SetCaption MasterTempoValLB, LTRIM$(STR$(Control(MasterTempoSlider).Value))

        ' Voice 1 Mixer controls
        CASE Voice1EnableCB: Voice(1).enabled = Control(Voice1EnableCB).Value
        CASE Voice1WaveformDL: Voice(1).waveform = Control(Voice1WaveformDL).Value: IF activeCompVoice = 1 THEN Control(SynthWaveDL).Value = Voice(1).waveform
        CASE Voice1VolSlider: Voice(1).volume = Control(Voice1VolSlider).Value: IF activeCompVoice = 1 THEN Control(SynthVolSlider).Value = Voice(1).volume: SetCaption SynthVolValLB, LTRIM$(STR$(Voice(1).volume))
        CASE Voice1PanSlider: Voice(1).pan = Control(Voice1PanSlider).Value: IF activeCompVoice = 1 THEN Control(SynthPanSlider).Value = Voice(1).pan

        ' Voice 2 Mixer controls
        CASE Voice2EnableCB: Voice(2).enabled = Control(Voice2EnableCB).Value
        CASE Voice2WaveformDL: Voice(2).waveform = Control(Voice2WaveformDL).Value: IF activeCompVoice = 2 THEN Control(SynthWaveDL).Value = Voice(2).waveform
        CASE Voice2VolSlider: Voice(2).volume = Control(Voice2VolSlider).Value: IF activeCompVoice = 2 THEN Control(SynthVolSlider).Value = Voice(2).volume: SetCaption SynthVolValLB, LTRIM$(STR$(Voice(2).volume))
        CASE Voice2PanSlider: Voice(2).pan = Control(Voice2PanSlider).Value: IF activeCompVoice = 2 THEN Control(SynthPanSlider).Value = Voice(2).pan

        ' Voice 3 Mixer controls
        CASE Voice3EnableCB: Voice(3).enabled = Control(Voice3EnableCB).Value
        CASE Voice3WaveformDL: Voice(3).waveform = Control(Voice3WaveformDL).Value: IF activeCompVoice = 3 THEN Control(SynthWaveDL).Value = Voice(3).waveform
        CASE Voice3VolSlider: Voice(3).volume = Control(Voice3VolSlider).Value: IF activeCompVoice = 3 THEN Control(SynthVolSlider).Value = Voice(3).volume: SetCaption SynthVolValLB, LTRIM$(STR$(Voice(3).volume))
        CASE Voice3PanSlider: Voice(3).pan = Control(Voice3PanSlider).Value: IF activeCompVoice = 3 THEN Control(SynthPanSlider).Value = Voice(3).pan

        ' Voice 4 Mixer controls
        CASE Voice4EnableCB: Voice(4).enabled = Control(Voice4EnableCB).Value
        CASE Voice4WaveformDL: Voice(4).waveform = Control(Voice4WaveformDL).Value: IF activeCompVoice = 4 THEN Control(SynthWaveDL).Value = Voice(4).waveform
        CASE Voice4VolSlider: Voice(4).volume = Control(Voice4VolSlider).Value: IF activeCompVoice = 4 THEN Control(SynthVolSlider).Value = Voice(4).volume: SetCaption SynthVolValLB, LTRIM$(STR$(Voice(4).volume))
        CASE Voice4PanSlider: Voice(4).pan = Control(Voice4PanSlider).Value: IF activeCompVoice = 4 THEN Control(SynthPanSlider).Value = Voice(4).pan

        ' Composer Tab 2 controls
        CASE CompVoiceDL
            activeCompVoice = Control(CompVoiceDL).Value
            SyncComposerFromActiveVoice

        CASE SynthDutySlider
            SetCaption SynthDutyValLB, LTRIM$(STR$(Control(SynthDutySlider).Value)) + "%"

        CASE SynthVolSlider
            SetCaption SynthVolValLB, LTRIM$(STR$(Control(SynthVolSlider).Value))

        CASE AttackSlider
            SetCaption AttackValLB, LTRIM$(STR$(Control(AttackSlider).Value)) + "%"

        CASE DecaySlider
            SetCaption DecayValLB, LTRIM$(STR$(Control(DecaySlider).Value)) + "%"

        CASE SustainSlider
            SetCaption SustainValLB, LTRIM$(STR$(Control(SustainSlider).Value)) + "%"

        CASE ReleaseSlider
            SetCaption ReleaseValLB, LTRIM$(STR$(Control(ReleaseSlider).Value)) + "%"

        CASE QuickRampSlider
            SetCaption QuickRampValLB, LTRIM$(STR$(Control(QuickRampSlider).Value)) + "%"

        ' Tab 3: Sound FX Designer controls
        CASE WaveformSlider
            SELECT CASE Control(id).Value
                CASE 1: SetCaption WaveformNameLB, "Square"
                CASE 2: SetCaption WaveformNameLB, "Sawtooth"
                CASE 3: SetCaption WaveformNameLB, "Triangle"
                CASE 4: SetCaption WaveformNameLB, "Sine"
                CASE 5: SetCaption WaveformNameLB, "White Noise"
                CASE 6: SetCaption WaveformNameLB, "Pink Noise"
                CASE 7: SetCaption WaveformNameLB, "Brownian Noise"
                CASE 8: SetCaption WaveformNameLB, "LFSR Noise"
                CASE 9: SetCaption WaveformNameLB, "Pulse"
            END SELECT

        CASE NoteSlider, LengthSlider, LengthEffectsDL, TempoSlider, VolumeSlider, VolRampSlider
            ' Handled below
    END SELECT

    ' Update Tab 3 FX Slot if a Tab 3 control changed
    IF id = WaveformSlider _ORELSE id = NoteSlider _ORELSE id = LengthSlider _ORELSE id = LengthEffectsDL _ORELSE id = TempoSlider _ORELSE id = VolumeSlider _ORELSE id = VolRampSlider THEN
        FXWaveform(currentFXWaveform).waveform = Control(WaveformSlider).Value
        FXWaveform(currentFXWaveform).note = Control(NoteSlider).Value
        FXWaveform(currentFXWaveform).length = Control(LengthSlider).Value
        FXWaveform(currentFXWaveform).lengthType = Control(LengthEffectsDL).Value
        FXWaveform(currentFXWaveform).tempo = Control(TempoSlider).Value
        FXWaveform(currentFXWaveform).volume = Control(VolumeSlider).Value
        FXWaveform(currentFXWaveform).volRamp = Control(VolRampSlider).Value
        FXWaveform(currentFXWaveform).active = _TRUE

        MakePlayFXSlotString
        MakeCombinedPlayFXString
    END IF
END SUB

SUB __UI_FormResized

END SUB
