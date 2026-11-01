'-----------------------------------------------------------------------------------------------------------------------
' InForm-PE DataGrid
' Copyright (c) 2026 Fellippe Heitor
'
' Turns a frame into a table: column headers, rows of cells, a current cell, editing in place and a scrollbar.
' See InFormDataGrid.bm and docs/DataGrid.md.
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'Column kinds
CONST __UI_DataGrid_Text%% = 1%%
CONST __UI_DataGrid_Integer%% = 2%%
CONST __UI_DataGrid_Float%% = 3%%
CONST __UI_DataGrid_Choice%% = 4%% ' a dropdown list of items; the cell holds the chosen item's text
CONST __UI_DataGrid_Toggle%% = 5%% ' a check box; the cell holds "-1" or "0"

TYPE __UI_DataGridTYPE
    FrameID AS LONG
    Columns AS STRING ' MKL$ of the grid's columns (indexes into __UI_DataGridCols), in order
    Rows AS STRING ' MKL$ of the grid's rows (indexes into __UI_DataGridCells), in order
    CurRow AS LONG ' current cell (0 = none)
    CurCol AS LONG
    SelAnchor AS LONG ' the other end of a range of selected rows (0 = only the current row is selected)
    DragSelecting AS _BYTE ' the mouse button went down on a cell and is still held: dragging selects rows
    DragTime AS SINGLE ' when a drag past the top or bottom scrolls again
    TopRow AS LONG ' rows scrolled out of view at the top
    ChangedRow AS LONG ' what last fired __UI_ValueChanged: a cell (row and column),
    ChangedColumn AS LONG ' or the current cell moving (column 0)
    EditorID AS LONG ' text box used to edit text and number cells (created when first needed)
    ChooserID AS LONG ' dropdown list used to edit choice cells (created when first needed)
    Editing AS _BYTE ' 0 = no, 1 = in the text box, 2 = in the dropdown list
    ListOpened AS _BYTE ' the dropdown list's list was opened
    EditRow AS LONG ' the cell being edited
    EditCol AS LONG
    PendingEdit AS _BYTE ' start editing the current cell once the mouse button is released
    LastClick AS DOUBLE ' when the current cell was last clicked
    HadFocus AS _BYTE ' the grid had focus at the last update
    'Measures, in the frame's coordinates (see __UI_DGMeasure)
    AreaLeft AS INTEGER
    AreaTop AS INTEGER
    AreaRight AS INTEGER ' last column of pixels
    AreaBottom AS INTEGER
    RowHeight AS INTEGER
    HeaderHeight AS INTEGER
    VisibleRows AS LONG
    MaxTopRow AS LONG ' 0 when every row fits
    'Scrollbar (drawn by __UI_DrawVScrollBar)
    SbLeft AS INTEGER
    SbTop AS INTEGER
    SbHeight AS INTEGER
    TrackTop AS INTEGER
    TrackHeight AS INTEGER
    ThumbTop AS INTEGER
    ThumbHeight AS INTEGER
    HoverPart AS _BYTE ' 1 = up button, 2 = down button, 3 = thumb, 4 = track above it, 5 = track below it
    PressPart AS _BYTE
    Dragging AS _BYTE
    GrabOffset AS INTEGER
    RepeatTime AS SINGLE
END TYPE

TYPE __UI_DataGridColumnTYPE
    Kind AS _BYTE
    Width AS INTEGER ' 0 = share the room the other columns leave
    Left AS INTEGER ' where the column starts, worked out by __UI_DGMeasure
    Right AS INTEGER
END TYPE

REDIM SHARED __UI_DataGrids(0) AS __UI_DataGridTYPE
REDIM SHARED __UI_DataGridCols(0) AS __UI_DataGridColumnTYPE
REDIM SHARED __UI_DataGridColCaption(0) AS STRING
REDIM SHARED __UI_DataGridColItems(0) AS STRING ' a choice column's items, separated by "|"
REDIM SHARED __UI_DataGridCells(0) AS STRING ' a row's cells, separated by CHR$(0)
REDIM SHARED __UI_DataGridRowUsed(0) AS _BYTE
REDIM SHARED __UI_DataGridLook(0) AS STRING ' what a grid looked like at the last update (scroll, current cell, focus...)
DIM SHARED __UI_TotalDataGrids AS LONG, __UI_TotalDataGridCols AS LONG, __UI_TotalDataGridRows AS LONG
