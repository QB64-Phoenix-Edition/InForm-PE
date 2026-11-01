'-----------------------------------------------------------------------------------------------------------------------
' InForm-PE PropertyGrid
' Copyright (c) 2026 Fellippe Heitor
'
' Turns a frame into a list of "label | value" rows, like the editor's Control properties panel.
' See InFormPropertyGrid.bm and docs/PropertyGrid.md.
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'Row kinds
CONST __UI_PropertyGrid_Text%% = 1%%
CONST __UI_PropertyGrid_Integer%% = 2%%
CONST __UI_PropertyGrid_Float%% = 3%%
CONST __UI_PropertyGrid_Choice%% = 4%%
CONST __UI_PropertyGrid_Toggle%% = 5%%
CONST __UI_PropertyGrid_Button%% = 6%%
CONST __UI_PropertyGrid_Other%% = 7%% ' an adopted control that isn't a textbox: laid out, but not edited by the grid

'Row states (see PropertyGrid_RowState)
CONST __UI_PropertyGrid_Normal%% = 0%%
CONST __UI_PropertyGrid_Confirmed%% = 1%% ' the text in the box is the row's value
CONST __UI_PropertyGrid_Rejected%% = 2%% ' a value was entered, but the row ended up with another one

TYPE __UI_PropertyGridTYPE
    FrameID AS LONG
    RowLeft AS INTEGER
    FirstTop AS INTEGER
    RowSpacing AS INTEGER
    LabelWidth AS INTEGER
    NextTop AS INTEGER ' where a row added below the last visible one would go
    FocusRow AS LONG ' row whose textbox had focus during the last update
    ChangedRow AS LONG ' row that last fired __UI_ValueChanged
    LastFocusID AS LONG ' __UI_Focus at the last update, to notice a row getting focus
    ScrollRow AS LONG ' stacked rows scrolled out above the frame
    MaxScroll AS LONG ' 0 when every row fits
    StackCount AS LONG ' rows being stacked (shown and not floating)
    EnsureRow AS LONG ' a row to bring into view at the next layout
    Dragging AS _BYTE ' the scrollbar's thumb is being dragged
    TrackTop AS INTEGER ' scrollbar, in the frame's coordinates
    TrackHeight AS INTEGER
    ThumbTop AS INTEGER
    ThumbHeight AS INTEGER
END TYPE

TYPE __UI_PropertyGridRowTYPE
    Grid AS LONG
    Kind AS _BYTE
    LabelID AS LONG
    ControlID AS LONG
    Owned AS _BYTE ' the grid created the row's controls (and lays out their left and width)
    Shown AS _BYTE
    Floating AS _BYTE ' kept out of the stacking: the program places it
    Dirty AS _BYTE ' the text was edited since the last commit
    CommitTime AS SINGLE
    LastValue AS _FLOAT ' choice and toggle rows: the control's value at the last update
END TYPE

REDIM SHARED __UI_PropertyGrids(0) AS __UI_PropertyGridTYPE
REDIM SHARED __UI_PropertyGridRows(0) AS __UI_PropertyGridRowTYPE
REDIM SHARED __UI_PropertyGridKeys(0) AS STRING
REDIM SHARED __UI_PropertyGridValues(0) AS STRING
REDIM SHARED __UI_PropertyGridSeen(0) AS STRING ' text of a focused row's textbox at the last update
REDIM SHARED __UI_PropertyGridAttachedID(0) AS LONG
REDIM SHARED __UI_PropertyGridAttachedRow(0) AS LONG
DIM SHARED __UI_TotalPropertyGrids AS LONG, __UI_TotalPropertyGridRows AS LONG
DIM SHARED __UI_TotalPropertyGridAttached AS LONG
