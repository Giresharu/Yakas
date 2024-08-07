#Requires AutoHotkey v2.0
#Include ..\Util\Util.ahk
#Include ..\KBL\KeyboardLayout.ahk

class GlobalSetting {
    static StandAlong := true
    static CleanOnProcessExit := true
    static DefualtKBL := "en-US: 0"
    static Delay := 50
    static RememberCaps := true
    static CleanCapsOnSwitched := true
    static CleanCapsOnProcessChanged := true
    static CleanCapsOnRecovered := true

    static Initialize(iniFile) {
        GlobalSetting.FromINI(iniFile)
    }

    static FromINI(iniFile) {
        ; GlobalSetting.StandAlong := Util.INIRead(iniFile, "GlobalSetting", "stand_along", "true") == "true"
        GlobalSetting.InitializeStandAlong(iniFile)
        GlobalSetting.CleanOnProcessExit := Util.INIRead(iniFile, "GlobalSetting", "clean_on_process_exit", "true") == "true"

        GlobalSetting.DefualtKBL := Util.INIRead(iniFile, "GlobalSetting", "default_kbl", "en-US: 0")
        str := StrSplit(GlobalSetting.DefualtKBL, ":", " ")
        kbl := str[1]
        imeState := str[2]

        str := StrSplit(imeState, "|", " ")
        imeState := Integer(str[1])
        delay := str.Length > 1 ? Integer(str[2]) : -1

        GlobalSetting.DefualtKBL := KeyboardLayout(kbl, imeState, delay)


        GlobalSetting.Delay := Util.INIRead(iniFile, "GlobalSetting", "delay", "50")
        GlobalSetting.RememberCaps := Util.INIRead(iniFile, "GlobalSetting", "remember_caps", "true") == "true"
        GlobalSetting.CleanCapsOnSwitched := Util.INIRead(iniFile, "GlobalSetting", "clean_caps_on_switched", "true") == "true"
        ; GlobalSetting.CleanCapsOnProcessChanged := Util.INIRead(iniFile, "GlobalSetting", "CleanCapsOnProcessChanged", "true") == "true"
        GlobalSetting.CleanCapsOnRecovered := Util.INIRead(iniFile, "GlobalSetting", "clean_caps_on_recovered", "true") == "true"
    }

    ; 存储用户本来的设置，在退出时恢复
    static InitializeStandAlong(iniFile) {
        GlobalSetting.StandAlong := Util.INIRead(iniFile, "GlobalSetting", "stand_along", "true") == "true"
        ; temp := GlobalSetting.GetStandAlongInSystem()
        ; GlobalSetting.SetStandAlongInSystem(0)
        ; global onExitCallbacks

        ; onExitCallbacks.Push((a, b) => GlobalSetting.SetStandAlongInSystem(temp))
    }

    static SPI_GETTHREADLOCALINPUTSETTINGS := 0x104E

    static GetStandAlongInSystem() {
        pvParam := Buffer(4)
        DllCall("SystemParametersInfoW",
            "UInt", GlobalSetting.SPI_GETTHREADLOCALINPUTSETTINGS,
            "UInt", 0,
            "Ptr", pvParam,
            "UInt", 0)
        result := NumGet(pvParam, 0, "uint")

        VarSetStrCapacity(&pvParam, 0)
        return result
    }

    ; BUG value 为 0 时也会调整选项为 true
    static SPI_SETTHREADLOCALINPUTSETTINGS := 0x104F
    static SetStandAlongInSystem(value) {
        pvParam := Buffer(4)
        NumPut("uint", value, pvParam)
        DllCall("SystemParametersInfoW",
            "UInt", GlobalSetting.SPI_SETTHREADLOCALINPUTSETTINGS,
            "UInt", 0,
            "Ptr", pvParam,
            "UInt", 0
        )
        VarSetStrCapacity(&pvParam, 0)
    }
}