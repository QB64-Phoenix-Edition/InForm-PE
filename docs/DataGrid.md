# DataGrid

A **DataGrid** turns a frame into a table: a row of column headers, rows of cells under it, and a current cell you can move around and edit in place. The designer's **Property grid rows** dialog is one.

The grid takes care of the parts that are tedious to write by hand:

- One cell is current. Click a cell, or move with the arrow keys, **Home**/**End** (with **Ctrl** for the first/last row), **Page Up**/**Page Down** and **Tab**/**Shift+Tab**. Past the last cell, **Tab** leaves the grid.
- To edit a cell, click it again, press **Enter** or **F2**, or just start typing. **Enter** (or leaving the cell) keeps the new value, **Esc** puts back the old one, and **Up**/**Down** keep it and move to the next row.
- Choice cells open a list (**Space**, **Enter** or a second click), and typing a letter picks the next item that starts with it. Toggle cells flip with a click or **Space**. **Delete** clears a cell.
- Whole rows can be selected as a range: **Shift** with Up/Down/Page Up/Page Down (or **Ctrl+Shift+Home/End**), **Shift+click**, or dragging over rows (past the top or bottom of the table, the grid scrolls). Cells aren't selected one by one: a range is for removing or moving rows.
- When the rows don't fit, a scrollbar appears on the right, the same as a list box's, and the mouse wheel scrolls the grid. The row below the last whole one shows cut off, and scrolls into full view when it's clicked or edited.
- Every change arrives in one place: `__UI_ValueChanged`, with the frame's ID.

## Quick start

Put a frame on your form in the designer, then add columns and rows to it in `__UI_OnLoad`:

```vb
SUB __UI_OnLoad
    DataGrid_AddTextColumn ListFrame, "Item", 0 ' 0: takes the room the other columns leave
    DataGrid_AddChoiceColumn ListFrame, "Aisle", 100, "Produce|Bakery|Dairy"
    DataGrid_AddIntegerColumn ListFrame, "Qty", 50
    DataGrid_AddToggleColumn ListFrame, "Got it", 60

    r = DataGrid_AddRow(ListFrame, "Apples|Produce|6|-1")
    r = DataGrid_AddRow(ListFrame, "Milk|Dairy|2")
END SUB

SUB __UI_ValueChanged (id AS LONG)
    SELECT CASE id
        CASE ListFrame
            r = DataGrid_ChangedRow(ListFrame)
            IF DataGrid_ChangedColumn(ListFrame) = 0 THEN
                'Another cell became current
            ELSE
                'A cell was changed
                PRINT DataGrid_Cell$(ListFrame, r, DataGrid_ChangedColumn(ListFrame))
            END IF
    END SELECT
END SUB
```

Rows and columns are numbered from 1, in the order they show. Every cell holds text: use `VAL()` to read numbers.

The `DataGridDemo` example shows a complete form, with buttons to add, delete and move rows (one or a selected range).

## Columns

| Add with | Cells hold | Edited with |
|---|---|---|
| `DataGrid_AddTextColumn` | any text | a text box |
| `DataGrid_AddIntegerColumn` | a whole number, rounded when kept | a text box for numbers |
| `DataGrid_AddFloatColumn` | a number | a text box for numbers |
| `DataGrid_AddChoiceColumn` | the chosen item's text (items separated by `\|`) | a dropdown list |
| `DataGrid_AddToggleColumn` | `"-1"` when checked, `"0"` when not | a click or Space |

Numbers are shown on the right of their cells.

A column's width is in pixels. Columns with a width of `0` share the room the others leave, and the last column always reaches the right edge. Columns that don't fit are cut off: there's no sideways scrolling.

## Events

The grid fires `__UI_ValueChanged` with the frame's ID when:

- the user changes a cell: `DataGrid_ChangedRow` and `DataGrid_ChangedColumn` say which one.
- the user makes another cell current: `DataGrid_ChangedRow` is its row and `DataGrid_ChangedColumn` is `0`.

Changes made by your code (`DataGrid_SetCell`, `DataGrid_Select`...) don't fire it.

Arrow keys and the other keys the grid doesn't use still reach `__UI_KeyPress` with the frame's ID, so you can add your own (for example, **Insert** to add a row).

While a cell is edited, the grid puts a text box or a dropdown list of its own on top of the cell. They're in the frame, and they fire their own events, which you can ignore. `DataGrid_GridOf` tells them apart:

```vb
IF DataGrid_GridOf(id) = ListFrame THEN EXIT SUB
```

## API reference

```vb
SUB DataGrid_AddTextColumn (frameID AS LONG, columnCaption AS STRING, columnWidth AS INTEGER)
SUB DataGrid_AddIntegerColumn (frameID AS LONG, columnCaption AS STRING, columnWidth AS INTEGER)
SUB DataGrid_AddFloatColumn (frameID AS LONG, columnCaption AS STRING, columnWidth AS INTEGER)
SUB DataGrid_AddChoiceColumn (frameID AS LONG, columnCaption AS STRING, columnWidth AS INTEGER, itemList AS STRING)
SUB DataGrid_AddToggleColumn (frameID AS LONG, columnCaption AS STRING, columnWidth AS INTEGER)
FUNCTION DataGrid_ColumnCount& (frameID AS LONG)
```

Add a column to the right of the others. The first column makes the frame a grid (`DataGrid_Attach` does only that).

```vb
SUB DataGrid_SetColumnWidth (frameID AS LONG, columnNumber AS LONG, columnWidth AS INTEGER)
SUB DataGrid_SetColumnCaption (frameID AS LONG, columnNumber AS LONG, columnCaption AS STRING)
SUB DataGrid_SetColumnItems (frameID AS LONG, columnNumber AS LONG, itemList AS STRING)
```

Change a column. New items for a choice column don't change the cells.

```vb
FUNCTION DataGrid_AddRow& (frameID AS LONG, cellList AS STRING)
FUNCTION DataGrid_InsertRow& (frameID AS LONG, beforeRow AS LONG, cellList AS STRING)
SUB DataGrid_RemoveRow (frameID AS LONG, rowNumber AS LONG)
SUB DataGrid_MoveRow (frameID AS LONG, rowNumber AS LONG, toRow AS LONG)
SUB DataGrid_Clear (frameID AS LONG)
FUNCTION DataGrid_RowCount& (frameID AS LONG)
```

Add a row at the end or before another, and get its number back. `cellList` has the cells separated by `|`. Cells left out get their column's default: empty text, `0`, unchecked, or a choice's first item. A cell that has to hold `|` can be set with `DataGrid_SetCell`.

`DataGrid_MoveRow` moves a row so it becomes row `toRow`, and the current cell goes along with it. After `DataGrid_RemoveRow`, the current cell stays on the same row number. `DataGrid_Clear` removes every row and keeps the columns.

```vb
FUNCTION DataGrid_Cell$ (frameID AS LONG, rowNumber AS LONG, columnNumber AS LONG)
SUB DataGrid_SetCell (frameID AS LONG, rowNumber AS LONG, columnNumber AS LONG, cellValue AS STRING)
```

Read or set a cell.

```vb
FUNCTION DataGrid_Row& (frameID AS LONG)
FUNCTION DataGrid_Column& (frameID AS LONG)
SUB DataGrid_Select (frameID AS LONG, rowNumber AS LONG, columnNumber AS LONG)
```

The current cell (`0` when there is none), and making a cell current. The grid scrolls to show it.

```vb
FUNCTION DataGrid_ChangedRow& (frameID AS LONG)
FUNCTION DataGrid_ChangedColumn& (frameID AS LONG)
```

What fired `__UI_ValueChanged` (see [Events](#events)).

```vb
FUNCTION DataGrid_SelectionFirst& (frameID AS LONG)
FUNCTION DataGrid_SelectionLast& (frameID AS LONG)
FUNCTION DataGrid_RowSelected%% (frameID AS LONG, rowNumber AS LONG)
SUB DataGrid_SelectRows (frameID AS LONG, fromRow AS LONG, toRow AS LONG)
SUB DataGrid_MoveSelection (frameID AS LONG, byRows AS LONG)
SUB DataGrid_RemoveSelection (frameID AS LONG)
```

The selected rows: the current row alone, or a range selected with Shift or by dragging. `DataGrid_SelectRows` selects a range from code (the current cell goes to `toRow`). `DataGrid_MoveSelection` moves the selected rows up (`-1`) or down (`1`) one place and keeps them selected, and `DataGrid_RemoveSelection` removes them. Moving the current cell without Shift leaves only its row selected.

With several rows selected, **Delete** doesn't clear a cell: it goes on to `__UI_KeyPress`, so your program can remove the rows:

```vb
SUB __UI_KeyPress (id AS LONG)
    IF id = ListFrame _ANDALSO __UI_KeyHit = _KEY_DELETE THEN
        IF DataGrid_SelectionLast(ListFrame) > DataGrid_SelectionFirst(ListFrame) THEN DataGrid_RemoveSelection ListFrame
    END IF
END SUB
```

```vb
SUB DataGrid_Edit (frameID AS LONG)
SUB DataGrid_StopEditing (frameID AS LONG)
FUNCTION DataGrid_IsEditing%% (frameID AS LONG)
```

Start editing the current cell as if Enter had been pressed, for example right after adding a row. `DataGrid_StopEditing` keeps what was typed, which is useful before reading the cells (for example, when an OK button is clicked while a cell is being edited).

```vb
FUNCTION DataGrid_GridOf& (controlID AS LONG)
```

The frame a control belongs to: the frame itself, or the box or list that edits its cells. `0` for any other control.
