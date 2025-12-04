# Algorithm Library

The `Algo` library provides general-purpose algorithms.

## Usage

To use the `Algo` library, you need to include `Algo.bm` in your project.

```vb
DIM names(1 TO 5) AS STRING
names(1) = "John"
names(2) = "jane"
names(3) = "Peter"
names(4) = "sue"
names(5) = "pete"

Algo_SortStringArray names()

DIM i AS LONG
FOR i = LBOUND(names) TO UBOUND(names)
    PRINT names(i)
NEXT

IF Algo_SortStringArrayRange(names(), 2, 4, _FALSE, _FALSE) THEN
    PRINT "Array was changed"
END IF

FOR i = LBOUND(names) TO UBOUND(names)
    PRINT names(i)
NEXT

'$INCLUDE:'Algo.bm'
```

## API Reference

### Sorting

***

Sorts a string array using a non-recursive QuickSort algorithm.

**Parameters:**

* `strArr()`: The array of strings to sort.
* `l`: The lower index of the range to sort (inclusive).
* `u`: The upper index of the range to sort (inclusive).
* `wantsAscending`: `_TRUE` for ascending order, `_FALSE` for descending order.
* `caseSensitive`: `_TRUE` for case-sensitive comparison, `_FALSE` for case-insensitive comparison.

**Returns:**
`_TRUE` if the array was modified, `_FALSE` otherwise.

```vb
FUNCTION Algo_SortStringArrayRange%% (strArr() AS STRING, l AS _INTEGER64, u AS _INTEGER64, wantsAscending AS _BYTE, caseSensitive AS _BYTE)
```

***

A convenience function that sorts the entire string array in ascending, case-sensitive order.

**Parameters:**

* `strArr()`: The array of strings to sort.

**Returns:**
`_TRUE` if the array was modified, `_FALSE` otherwise.

```vb
FUNCTION Algo_SortStringArray%% (strArr() AS STRING)
```

***

A convenience SUB that sorts the entire string array in ascending, case-sensitive order.

**Parameters:**

* `strArr()`: The array of strings to sort.

```vb
SUB Algo_SortStringArray (strArr() AS STRING)
```
