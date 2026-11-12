# System Library

The `System` library provides access to low-level operating system and process management functions.

## Usage

To use the `System` library, include `System.bi` in your project.

```vb
'$INCLUDE:'InForm/extensions/System.bi'

DIM pid AS LONG
pid = System_GetProcessID
PRINT "Current Process ID: "; pid
```

## API Reference

### Process Management

***

Retrieves the unique process identifier (PID) of the current calling process from the operating system.

**Returns:**
The process ID as a 32-bit signed `LONG` integer.

```vb
FUNCTION System_GetProcessID&
```
