CreateGUID()
{
    pguid := Buffer(16)
    if !(DllCall("ole32.dll\CoCreateGuid", "ptr", pguid)) {
        size := (38 << !!StrLen(Chr(0xFFFF))) + 1
        sguid := Buffer(size)
        if (DllCall("ole32.dll\StringFromGUID2", "ptr", pguid, "ptr", sguid, "int", size))
            return StrGet(sguid)
    }
    return ""
}