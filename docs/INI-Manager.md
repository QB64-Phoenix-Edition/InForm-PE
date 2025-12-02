# INI Manager Library

The `INI Manager` library provides functionality for reading and writing [INI files](https://en.wikipedia.org/wiki/INI_file) in QB64-PE. [INI files](https://en.wikipedia.org/wiki/INI_file) are a simple, human-readable format for storing configuration data.

## Usage

To use the `INI Manager` library in your project, you need to include `Ini.bi` at the top of your code and `Ini.bm` at the bottom.

```vb
'$INCLUDE:'Ini.bi'

' Your code here...

'$INCLUDE:'Ini.bm'
```

## API Reference

### Reading Data

Reads a value from a specified section and key. To get all keys sequentially from the file, pass an empty string for `section$` and `key$`. To get all keys sequentially from a specific section, pass an empty string for `key$`.

```vb
FUNCTION Ini_ReadSetting$ (file$, section$, key$)
```

### Writing and Modifying Data

Writes a value to a specified section and key. If the key exists, it's updated. If it doesn't, it's created. New sections are created automatically.

```vb
SUB Ini_WriteSetting (file$, section$, key$, value$)
```

Deletes an entire section and all its keys from the INI file.

```vb
SUB Ini_DeleteSection (file$, section$)
```

Deletes a specific key from a given section.

```vb
SUB Ini_DeleteKey (file$, section$, key$)
```

Moves a key from one section to another.

```vb
SUB Ini_MoveKey (file$, section$, key$, newSection$)
```

Sorts all keys within a specified section alphabetically.

```vb
SUB Ini_SortSection (file$, section$)
```

### Information

Returns a string describing the result or error code of the last operation. Useful for debugging.

```vb
FUNCTION Ini_GetInfo$
```
