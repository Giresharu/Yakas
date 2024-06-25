#Requires AutoHotkey v2.0
#Include ..\Util\Util.ahk
#Include ..\KBL\KeyboardLayout.ahk

class GlobalSetting {
    static StandAlong := true
    static CleanOnProcessExit := true
    static DefualtKBL := "en-US: 0"
    static Lag := 50
    static RemenberCaps := true
    static CleanCapsOnSwitched := true
    static CleanCapsOnProcessChanged := true
    static CleanCapsOnRecovered := true

    static Initialize(iniFile) {
        GlobalSetting.FromINI(iniFile)
    }

    static FromINI(iniFile) {
        ; GlobalSetting.StandAlong := Util.INIRead(iniFile, "GlobalSetting", "StandAlong", "true") == "true"
        GlobalSetting.InitializeStandAlong(iniFile)
        GlobalSetting.CleanOnProcessExit := Util.INIRead(iniFile, "GlobalSetting", "CleanOnProcessExit", "true") == "true"

        GlobalSetting.DefualtKBL := Util.INIRead(iniFile, "GlobalSetting", "DefualtKBL", "en-US: 0")
        GlobalSetting.DefualtKBL := StrSplit(GlobalSetting.DefualtKBL, ":", " ")

        GlobalSetting.DefualtKBL := KeyboardLayout(GlobalSetting.DefualtKBL[1], GlobalSetting.DefualtKBL[2])

        GlobalSetting.Lag := Util.INIRead(iniFile, "GlobalSetting", "Lag", "50")
        GlobalSetting.RemenberCaps := Util.INIRead(iniFile, "GlobalSetting", "RemenberCaps", "true") == "true"
        GlobalSetting.CleanCapsOnSwitched := Util.INIRead(iniFile, "GlobalSetting", "CleanCapsOnSwitched", "true") == "true"
        GlobalSetting.CleanCapsOnProcessChanged := Util.INIRead(iniFile, "GlobalSetting", "CleanCapsOnProcessChanged", "true") == "true"
        GlobalSetting.CleanCapsOnRecovered := Util.INIRead(iniFile, "GlobalSetting", "CleanCapsOnRecovered", "true") == "true"
    }

    ; 存储用户本来的设置，在退出时恢复
    static InitializeStandAlong(iniFile) {
        GlobalSetting.StandAlong := Util.INIRead(iniFile, "GlobalSetting", "StandAlong", "true") == "true"
        temp := GlobalSetting.GetStandAlongInSystem()
        GlobalSetting.SetStandAlongInSystem(true)
        global onExitCallbacks

        onExitCallbacks.Push((a, b) => GlobalSetting.SetStandAlongInSystem(temp))
    }

    static SPI_GETTHREADLOCALINPUTSETTINGS := 0x104E
    ; TODO 也许不需要了
    static GetStandAlongInSystem() {
/*         pvParam := Buffer(4)
        DllCall("SystemParametersInfoW",
            "UInt", GlobalSetting.SPI_GETTHREADLOCALINPUTSETTINGS,
            "UInt", 0,
            "Ptr", pvParam,
            "UInt", 0)
        result := NumGet(pvParam, 0, "uint")

        VarSetStrCapacity(&pvParam, 0)
        return result */
    }

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