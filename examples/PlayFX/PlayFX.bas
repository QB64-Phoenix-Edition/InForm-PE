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

DIM SHARED Voice(1 TO 4) AS VoiceConfig
DIM SHARED lastPlayingState AS _BYTE
DIM SHARED activeCompVoice AS LONG: activeCompVoice = 1
DIM SHARED updatingText AS _BYTE

': Controls' IDs: ------------------------------------------------------------------
DIM SHARED PlayFXDesigner AS LONG
DIM SHARED MasterFrame AS LONG
DIM SHARED PresetLB AS LONG
DIM SHARED PresetsDL AS LONG
DIM SHARED MasterTempoLB AS LONG
DIM SHARED MasterTempoSlider AS LONG
DIM SHARED MasterTempoValLB AS LONG
DIM SHARED PlayBT AS LONG
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
DIM SHARED Voice1SoloBT AS LONG
DIM SHARED Voice1ClearBT AS LONG
DIM SHARED Voice1MeterLB AS LONG
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
        Voice(i).volume = _IIF(i = 1, 38, _IIF(i = 2, 32, _IIF(i = 3, 40, 28)))
        Voice(i).pan = _IIF(i = 1, 35, _IIF(i = 2, 65, 50))
        Voice(i).attack = 5
        Voice(i).decay = 15
        Voice(i).sustain = 70
        Voice(i).release = 10
        Voice(i).quickRamp = 10
        Voice(i).tempo = 140
        Voice(i).octave = _IIF(i = 1, 2, _IIF(i = 2, 2, _IIF(i = 3, 0, 0)))
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

    SetCaption StatusLB, "Playing 4-voice MML tune..."
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
    DIM j AS LONG
    FOR j = 1 TO 4
        Voice(j).enabled = _TRUE
    NEXT j

    updatingText = _TRUE
    SELECT CASE idx
        CASE 1 ' Korobeiniki (Tetris Chiptune - 4 Voices)
            Control(MasterTempoSlider).Value = 144
            SetCaption MasterTempoValLB, "144"

            Voice(1).waveform = 9 ' Pulse lead
            Voice(1).waveParam = 50
            Voice(1).volume = 38
            Voice(1).pan = 35
            Voice(1).octave = 3

            Voice(2).waveform = 1 ' Square harmony
            Voice(2).volume = 30
            Voice(2).pan = 65
            Voice(2).octave = 2

            Voice(3).waveform = 3 ' Triangle bass
            Voice(3).volume = 42
            Voice(3).pan = 50
            Voice(3).octave = 1

            Voice(4).waveform = 5 ' White noise drums
            Voice(4).quickRamp = 6
            Voice(4).volume = 24
            Voice(4).pan = 50
            Voice(4).octave = 0

            Text(Voice1MMLTB) = "T144 @9 Y50 V38 S35 O3 E4 < B8 > C8 D4 C8 < B8 A4 A8 > C8 E4 D8 C8 < B4. > C8 D4 E4 C4 < A4 A4 > P4 D4. F8 A4 G8 F8 E4. C8 E4 D8 C8 < B4 B8 > C8 D4 E4 C4 < A4 A4 > P4"
            Text(Voice2MMLTB) = "T144 @1 V30 S65 O2 G#4 B4 G#4 B4 A4 > C4 < A4 > C4 G#4 B4 > E4 < B4 A4 > C4 < A4 P4 F4 A4 F4 A4 E4 A4 E4 A4 E4 G#4 B4 G#4 A4 > C4 < A4 P4"
            Text(Voice3MMLTB) = "T144 @3 V42 S50 O1 E4 < B4 > E4 < B4 > A4 E4 A4 E4 E4 < B4 > E4 < B4 > A4 E4 A4 P4 D4 < A4 > D4 < A4 > A4 E4 A4 E4 E4 < B4 > E4 < B4 > A4 E4 A4 P4"
            Text(Voice4MMLTB) = "T144 @5 Q6 V24 S50 O0 L8 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 N15 N6 P4"

        CASE 2 ' Wilbert Brants - Chamber Allegro (3 Voices) [from play_demo.bas Demo 2]
            Control(MasterTempoSlider).Value = 103
            SetCaption MasterTempoValLB, "103"

            Voice(1).waveform = 1: Voice(1).volume = 35: Voice(1).pan = 40: Voice(1).octave = 3
            Voice(2).waveform = 1: Voice(2).volume = 33: Voice(2).pan = 60: Voice(2).octave = 1
            Voice(3).waveform = 2: Voice(3).volume = 38: Voice(3).pan = 50: Voice(3).octave = 0
            Voice(4).enabled = _FALSE

            Text(Voice1MMLTB) = "t103 w1 o3 q1 v35 L4 GG2G8F8 E-E-2E-8D8 CCCD E-2D2 B-B-2B-8A8 GG2G8F8 CCCD E-2D2 GG2G8F8 E-E-2E-8D8 CCCD E-2D2 B-B-2B-8A8 GG2G8F8 ACFA G2D2"
            Text(Voice2MMLTB) = "t103 w1 o1 q2 v33 L8 GB->D4<GB->D4< GB->E-<B-GB->E-<B- A>CF4<A>CF4< FA>C<AGB->D4< GB->D4<GB->D4< GB->E-<B-GB->E-<B- A>CF4<A>CF4< FA>C<AGB->D4< GB->D4<GB->D4< GB->E-<B-GB->E-<B- A>CF4<A>CF4< FA>C<AGB->D4< GB->D4<GB->D4< GB->E-<B-GB->E-<B- A>CF4<A>CF4< FA>C<AGB->D4<"
            Text(Voice3MMLTB) = "t103 w2 o0 q8 v38 L8 G4B-B-G4B-B- G4>E-E-<G4>E-E-< A>CF4<A>CF4< F4AAGB->D4< G4B-B-G4B-B- G4>E-E-<G4>E-E-< A>CF4<A>CF4< F4AAGB->D4< G4B-B-G4B-B- G4>E-E-<G4>E-E-< A>CF4<A>CF4< F4AAGB->D4< G4B-B-G4B-B- G4>E-E-<G4>E-E-< A>CF4<A>CF4< F4AAGB->D4<"
            Text(Voice4MMLTB) = ""

        CASE 3 ' Wilbert Brants - Polyphony in C (3 Voices) [from play_demo.bas Demo 3]
            Control(MasterTempoSlider).Value = 144
            SetCaption MasterTempoValLB, "144"

            Voice(1).waveform = 3: Voice(1).volume = 22: Voice(1).pan = 40: Voice(1).octave = 3
            Voice(2).waveform = 1: Voice(2).volume = 20: Voice(2).pan = 60: Voice(2).octave = 1
            Voice(3).waveform = 2: Voice(3).volume = 22: Voice(3).pan = 50: Voice(3).octave = 0
            Voice(4).enabled = _FALSE

            Text(Voice1MMLTB) = "t144 w3 o3 q2 v22 l8 cegceg l4 caf l8 cegceg l4 caf l8 gbdgbd l4 cgg l8 cegceg l4 caf l8 cegceg l4 caf l8 gbdgbd l4 cgg l8 cegceg l4 caf l8 cegceg l4 caf l8 gbdgbd l4 cgg"
            Text(Voice2MMLTB) = "t144 w1 o1 q2 v20 l4 gec f2a8c8 gec f2a8c8 gbd ec2 l4 gec f2a8c8 gec f2a8c8 gbd ec2 l4 gec f2a8c8 gec f2a8c8 gbd ec2"
            Text(Voice3MMLTB) = "t144 w2 o0 q16 v22 l8 v+cv-ceeg4 v+ f v- faa>cc< v+ c v- ceeg4 v+ f v- faa>cc< ggbb>d4< q8 g4c2 q16 l8 v+cv-ceeg4 v+ f v- faa>cc< v+ c v- ceeg4 v+ f v- faa>cc< ggbb>d4< q8 g4c2 q16 l8 v+cv-ceeg4 v+ f v- faa>cc< v+ c v- ceeg4 v+ f v- faa>cc< ggbb>d4< q8 g4c2"
            Text(Voice4MMLTB) = ""

        CASE 4 ' J. Baker - Multi-Wave Groove (4 Voices) [from play_demo.bas Demo 1]
            Control(MasterTempoSlider).Value = 144
            SetCaption MasterTempoValLB, "144"

            Voice(1).waveform = 2: Voice(1).volume = 33: Voice(1).pan = 35: Voice(1).octave = 3
            Voice(2).waveform = 1: Voice(2).volume = 31: Voice(2).pan = 65: Voice(2).octave = 2
            Voice(3).waveform = 1: Voice(3).volume = 32: Voice(3).pan = 50: Voice(3).octave = 0
            Voice(4).waveform = 9: Voice(4).waveParam = 15: Voice(4).volume = 29: Voice(4).pan = 50: Voice(4).octave = 3

            Text(Voice1MMLTB) = "t144 l4 w2 o3 q20 v33 r1r1 r1r1 r1r1 r1r1 cd>d<e cd>d<e cd>d<e cd>d2<"
            Text(Voice2MMLTB) = "t144 q0 w1 o2 /1^100_99 v31 l1 gba /1\20^25_79 l4 gab2 /1^100_99 l1 gba /1\20^25_79 l4 gab2 v40 /9^100\1 l1 gba \2 l4 gab2"
            Text(Voice3MMLTB) = "t144 l4 q0 w1 o0 ^75_100 v32 w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w1 ^75_100 o0 dd2 w8 ^100_80 o4 c w4 ^75_100 o0 d2 w8 ^100_80 o4 cd w4 ^75_100 o0 d2 w8 ^100_80 o4 cd w4 ^75_100 o0 d2 w8 ^100_80 o4 cd w4 ^75_100 o0 d2 w8 ^100_80 o4 cd"
            Text(Voice4MMLTB) = "t144 q0 w9 y15 o3 _100 v29 l8 d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d d"

        CASE 5 ' Wilbert Brants - Baroque Canon (3 Voices) [from play_demo.bas Demo 5]
            Control(MasterTempoSlider).Value = 103
            SetCaption MasterTempoValLB, "103"

            Voice(1).waveform = 4: Voice(1).volume = 38: Voice(1).pan = 40: Voice(1).octave = 3
            Voice(2).waveform = 1: Voice(2).volume = 25: Voice(2).pan = 60: Voice(2).octave = 2
            Voice(3).waveform = 2: Voice(3).volume = 28: Voice(3).pan = 50: Voice(3).octave = 0
            Voice(4).enabled = _FALSE

            Text(Voice1MMLTB) = "T103 q1 O3 v38 W4 L4 CEC<G> CEC2 CEC<G> CE16R16E16R16C2 CEC<G> CEC2 CEC<G> C<G16>R16E16R16C2"
            Text(Voice2MMLTB) = "T103 q8 O2 V25 W1 L8 CEG>C< <FA>CF <GB>DG CEG>C< CEG>C< <FA>CF <GB>DG CEG>C< CEG>C< <FA>CF <GB>DG CEG>C< CEG>C< <FA>CF <GB>DG CEG>C<"
            Text(Voice3MMLTB) = "T103 q16 O0 V28 W2 L4 V+CV-E8E8 <FA> <V+GV-B8B8> CE V+CV-E8E8 <FA> <V+GV-B8B8> CE V+CV-E8E8 <FA> <V+GV-B8B8> CE V+CV-E8E8 <FA> <V+GV-B8B8> CE"
            Text(Voice4MMLTB) = ""

        CASE 6 ' Pachelbel - Canon in D (4 Voices)
            Control(MasterTempoSlider).Value = 96
            SetCaption MasterTempoValLB, "96"

            Voice(1).waveform = 4: Voice(1).volume = 38: Voice(1).pan = 30: Voice(1).octave = 3
            Voice(2).waveform = 1: Voice(2).volume = 30: Voice(2).pan = 70: Voice(2).octave = 2
            Voice(3).waveform = 2: Voice(3).volume = 28: Voice(3).pan = 40: Voice(3).octave = 2
            Voice(4).waveform = 3: Voice(4).volume = 42: Voice(4).pan = 50: Voice(4).octave = 1

            Text(Voice1MMLTB) = "T96 @4 V38 S30 O3 L4 F# E D C# < B A B > C# D C# < B A G F# G E > F# E D C# < B A B > C# D C# < B A G F# G E >"
            Text(Voice2MMLTB) = "T96 @1 V30 S70 O2 L4 A G F# E D C# D E F# A G F# E D C# D A G F# E D C# D E F# A G F# E D C# D"
            Text(Voice3MMLTB) = "T96 @2 V28 S40 O2 L4 F# E D C# < B A B > C# D F# E D C# < B A B > F# E D C# < B A B > C# D F# E D C# < B A B >"
            Text(Voice4MMLTB) = "T96 @3 V42 S50 O1 L2 D < A B F# G D G A > D < A B F# G D G A >"

        CASE 7 ' J.S. Bach - Minuet in G (4 Voices)
            Control(MasterTempoSlider).Value = 120
            SetCaption MasterTempoValLB, "120"

            Voice(1).waveform = 1: Voice(1).volume = 38: Voice(1).pan = 35: Voice(1).octave = 3
            Voice(2).waveform = 4: Voice(2).volume = 30: Voice(2).pan = 65: Voice(2).octave = 2
            Voice(3).waveform = 2: Voice(3).volume = 28: Voice(3).pan = 40: Voice(3).octave = 2
            Voice(4).waveform = 3: Voice(4).volume = 40: Voice(4).pan = 50: Voice(4).octave = 1

            Text(Voice1MMLTB) = "T120 @1 V38 S35 O3 D4 G8 A8 B8 > C8 < D4 G4 G4 E4 > C8 D8 E8 F#8 G4 < G4 G4 > C4 D8 C8 < B8 A8 B4 > C8 < B8 A8 G8 F#4 G8 A8 B8 > C8 < B4 A4 G4"
            Text(Voice2MMLTB) = "T120 @4 V30 S65 O2 B2 > C4 < B2 > C4 < A2 > C4 < B2 > C4 < E2 F#4 G2 F#4 D2 > C4 < B2."
            Text(Voice3MMLTB) = "T120 @2 V28 S40 O2 D2 E4 D2 E4 C2 E4 D2 E4 C2 D4 D2 B4 A2 F#4 G2."
            Text(Voice4MMLTB) = "T120 @3 V40 S50 O1 G2 > C4 < G2 > C4 E2 C4 G2 > C4 < C2 D4 G2 D4 D2 D4 G2."

        CASE 8 ' J. Baker - Dual-Voice Counterpoint (2 Voices) [from play_demo.bas Demo 4]
            Control(MasterTempoSlider).Value = 120
            SetCaption MasterTempoValLB, "120"

            Voice(1).waveform = 1: Voice(1).volume = 21: Voice(1).pan = 40: Voice(1).octave = 1
            Voice(2).waveform = 1: Voice(2).volume = 20: Voice(2).pan = 60: Voice(2).octave = 0
            Voice(3).enabled = _FALSE
            Voice(4).enabled = _FALSE

            Text(Voice1MMLTB) = "t120 w1 o1 q1 v21 l8 >dcde< dcde#4 l4 >d1< l8 de l4 >f1 l8 ddfe1< dedfe dd r4"
            Text(Voice2MMLTB) = "t120 w1 o0 q2 v20 l8 <dced> dcge4 l4 q1 <d1> r8 l8 q2 dg l4 q1 <d1> l8 q2 dge q1 <d1> q2 dcdrr v+ <<dd>> v- r"
            Text(Voice3MMLTB) = ""
            Text(Voice4MMLTB) = ""

        CASE 9 ' Retro Arcade SFX (4 Voices)
            Control(MasterTempoSlider).Value = 180
            SetCaption MasterTempoValLB, "180"

            Voice(1).waveform = 2: Voice(1).volume = 38: Voice(1).pan = 25: Voice(1).octave = 4
            Voice(2).waveform = 9: Voice(2).waveParam = 25: Voice(2).volume = 34: Voice(2).pan = 75: Voice(2).octave = 2
            Voice(3).waveform = 1: Voice(3).volume = 32: Voice(3).pan = 50: Voice(3).octave = 3
            Voice(4).waveform = 7: Voice(4).volume = 36: Voice(4).pan = 50: Voice(4).octave = 0

            Text(Voice1MMLTB) = "T180 @2 Q1 L16 O4 B A G F E D C < B A G F E D C < B P16"
            Text(Voice2MMLTB) = "T180 @9 Y25 L16 O2 C E G > C E G < G E C P16 C E G > C E < P16"
            Text(Voice3MMLTB) = "T180 @1 L16 O3 C G C G C G C G C G C G C G C P16"
            Text(Voice4MMLTB) = "T180 @7 Q15 L16 O0 N15 N13 N11 N9 N7 N5 N3 N1 N15 N13 N11 N9 N7 N5 N3 P16"

        CASE ELSE ' Custom / Empty
            DIM i AS LONG
            FOR i = 1 TO 4
                Text(GetVoiceMMLTB(i)) = ""
            NEXT i
    END SELECT
    updatingText = _FALSE

    FOR j = 1 TO 4
        SyncMixerControlsFromVoice j
    NEXT j

    SyncComposerFromActiveVoice
    SetCaption StatusLB, "Loaded preset: " + GetItem$(PresetsDL, idx)
END SUB

': Event procedures: ---------------------------------------------------------------

SUB __UI_BeforeInit

END SUB

SUB __UI_OnLoad
    InitDefaultVoiceSettings
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

        SetCaption StatusLB, "Playing 4-voice MML tune (" + LTRIM$(STR$(INT(maxT * 10) / 10)) + "s remaining)..."
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
        CASE PlayFXDesigner

        CASE MasterFrame

        CASE PresetLB

        CASE PresetsDL

        CASE MasterTempoLB

        CASE MasterTempoSlider

        CASE MasterTempoValLB

        CASE StatusLB

        CASE MainTabs

        CASE Voice1HeaderLB

        CASE Voice1EnableCB

        CASE Voice1WaveformDL

        CASE V1VolLB

        CASE Voice1VolSlider

        CASE V1PanLB

        CASE Voice1PanSlider

        CASE Voice1SoloBT

        CASE Voice1ClearBT

        CASE Voice1MeterLB

        CASE V1MMLLB

        CASE Voice1MMLTB

        CASE Voice2HeaderLB

        CASE Voice2EnableCB

        CASE Voice2WaveformDL

        CASE V2VolLB

        CASE Voice2VolSlider

        CASE V2PanLB

        CASE Voice2PanSlider

        CASE Voice2SoloBT

        CASE Voice2ClearBT

        CASE Voice2MeterLB

        CASE V2MMLLB

        CASE Voice2MMLTB

        CASE Voice3HeaderLB

        CASE Voice3EnableCB

        CASE Voice3WaveformDL

        CASE V3VolLB

        CASE Voice3VolSlider

        CASE V3PanLB

        CASE Voice3PanSlider

        CASE Voice3SoloBT

        CASE Voice3ClearBT

        CASE Voice3MeterLB

        CASE V3MMLLB

        CASE Voice3MMLTB

        CASE Voice4HeaderLB

        CASE Voice4EnableCB

        CASE Voice4WaveformDL

        CASE V4VolLB

        CASE Voice4VolSlider

        CASE V4PanLB

        CASE Voice4PanSlider

        CASE Voice4SoloBT

        CASE Voice4ClearBT

        CASE Voice4MeterLB

        CASE V4MMLLB

        CASE Voice4MMLTB

        CASE MixerInfoLB

        CASE CompTargetLB

        CASE CompVoiceDL

        CASE CompOctaveLB

        CASE CompOctaveDL

        CASE CompLengthLB

        CASE CompLengthDL

        CASE CompArtLB

        CASE CompArtDL

        CASE PianoHeaderLB

        CASE KeyC

        CASE KeyD

        CASE KeyE

        CASE KeyF

        CASE KeyG

        CASE KeyA

        CASE KeyB

        CASE KeyC2

        CASE KeyD2

        CASE KeyE2

        CASE KeyF2

        CASE KeyG2

        CASE KeyA2

        CASE KeyB2

        CASE KeyCs

        CASE KeyDs

        CASE KeyFs

        CASE KeyGs

        CASE KeyAs

        CASE KeyCs2

        CASE KeyDs2

        CASE KeyFs2

        CASE KeyGs2

        CASE KeyAs2

        CASE SynthHeaderLB

        CASE SynthWaveLB

        CASE SynthWaveDL

        CASE SynthDutyLB

        CASE SynthDutySlider

        CASE SynthDutyValLB

        CASE SynthVolLB

        CASE SynthVolSlider

        CASE SynthVolValLB

        CASE SynthPanLB

        CASE SynthPanSlider

        CASE AttackLB

        CASE AttackSlider

        CASE AttackValLB

        CASE DecayLB

        CASE DecaySlider

        CASE DecayValLB

        CASE SustainLB

        CASE SustainSlider

        CASE SustainValLB

        CASE ReleaseLB

        CASE ReleaseSlider

        CASE ReleaseValLB

        CASE QuickRampLB

        CASE QuickRampSlider

        CASE QuickRampValLB

        CASE ActiveVoiceHeaderLB

        CASE ActiveVoiceMMLTB

        CASE ActiveVoiceStatusLB

        CASE RefHeaderLB

        CASE RefNotesTitleLB

        CASE RefNotesLB

        CASE RefSynthTitleLB

        CASE RefSynthLB

        CASE RefEnvelopeTitleLB

        CASE RefEnvelopeLB

        CASE PlayBT
            PlayAllVoices

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
        CASE PresetsDL

        CASE MasterTempoSlider

        CASE PlayBT

        CASE CopyCodeBT

        CASE MainTabs

        CASE Voice1EnableCB

        CASE Voice1WaveformDL

        CASE Voice1VolSlider

        CASE Voice1PanSlider

        CASE Voice1SoloBT

        CASE Voice1ClearBT

        CASE Voice1MMLTB

        CASE Voice2EnableCB

        CASE Voice2WaveformDL

        CASE Voice2VolSlider

        CASE Voice2PanSlider

        CASE Voice2SoloBT

        CASE Voice2ClearBT

        CASE Voice2MMLTB

        CASE Voice3EnableCB

        CASE Voice3WaveformDL

        CASE Voice3VolSlider

        CASE Voice3PanSlider

        CASE Voice3SoloBT

        CASE Voice3ClearBT

        CASE Voice3MMLTB

        CASE Voice4EnableCB

        CASE Voice4WaveformDL

        CASE Voice4VolSlider

        CASE Voice4PanSlider

        CASE Voice4SoloBT

        CASE Voice4ClearBT

        CASE Voice4MMLTB

        CASE CompVoiceDL

        CASE CompOctaveDL

        CASE CompLengthDL

        CASE CompArtDL

        CASE KeyC

        CASE KeyD

        CASE KeyE

        CASE KeyF

        CASE KeyG

        CASE KeyA

        CASE KeyB

        CASE KeyC2

        CASE KeyD2

        CASE KeyE2

        CASE KeyF2

        CASE KeyG2

        CASE KeyA2

        CASE KeyB2

        CASE KeyCs

        CASE KeyDs

        CASE KeyFs

        CASE KeyGs

        CASE KeyAs

        CASE KeyCs2

        CASE KeyDs2

        CASE KeyFs2

        CASE KeyGs2

        CASE KeyAs2

        CASE KeyRest

        CASE KeyDot

        CASE KeyOctDown

        CASE KeyOctUp

        CASE KeyTie

        CASE KeyInsertHeader

        CASE KeyBackspace

        CASE KeyClearMML

        CASE SynthWaveDL

        CASE SynthDutySlider

        CASE SynthVolSlider

        CASE SynthPanSlider

        CASE AttackSlider

        CASE DecaySlider

        CASE SustainSlider

        CASE ReleaseSlider

        CASE QuickRampSlider

        CASE ApplySynthBT

        CASE AuditionVoiceBT

        CASE ActiveVoiceMMLTB

        CASE PlayActiveVoiceBT
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
    END SELECT

    updatingText = _FALSE
END SUB

SUB __UI_ValueChanged (id AS LONG)
    SELECT CASE id
        CASE MainTabs

        CASE Voice1EnableCB

        CASE Voice1WaveformDL

        CASE Voice1VolSlider

        CASE Voice1PanSlider

        CASE Voice2EnableCB

        CASE Voice2WaveformDL

        CASE Voice2VolSlider

        CASE Voice2PanSlider

        CASE Voice3EnableCB

        CASE Voice3WaveformDL

        CASE Voice3VolSlider

        CASE Voice3PanSlider

        CASE Voice4EnableCB

        CASE Voice4WaveformDL

        CASE Voice4VolSlider

        CASE Voice4PanSlider

        CASE CompOctaveDL

        CASE CompLengthDL

        CASE CompArtDL

        CASE SynthWaveDL

        CASE SynthPanSlider

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
    END SELECT
END SUB

SUB __UI_FormResized

END SUB
