#Requires AutoHotkey v2.0
#Include ..\Util\Util.ahk
#Include ..\KBL\KeyboardLayout.ahk

class SystemSetting {
    static StandAlong := true
    static CleanOnProcessExit := true
    static DefualtKBL := "en-US: 0"
    static Lag := 50
    static RemenberCaps := true
    static CleanCapsOnSwitched := true
    static CleanCapsOnProcessChanged := true
    static CleanCapsOnRecovered := true

    static Initialize(iniFile) {
        SystemSetting.FromINI(iniFile)
    }

    static FromINI(iniFile) {
        SystemSetting.StandAlong := Util.INIRead(iniFile, "SystemSetting", "StandAlong", "true") == "true"
        SystemSetting.CleanOnProcessExit := Util.INIRead(iniFile, "SystemSetting", "CleanOnProcessExit", "true") == "true"

        SystemSetting.DefualtKBL := Util.INIRead(iniFile, "SystemSetting", "DefualtKBL", "en-US: 0")
        SystemSetting.DefualtKBL := StrSplit(SystemSetting.DefualtKBL, ":", " ")

        SystemSetting.DefualtKBL := KeyboardLayout(SystemSetting.DefualtKBL[1], SystemSetting.DefualtKBL[2])

        SystemSetting.Lag := Util.INIRead(iniFile, "SystemSetting", "Lag", "50")
        SystemSetting.RemenberCaps := Util.INIRead(iniFile, "SystemSetting", "RemenberCaps", "true") == "true"
        SystemSetting.CleanCapsOnSwitched := Util.INIRead(iniFile, "SystemSetting", "CleanCapsOnSwitched", "true") == "true"
        SystemSetting.CleanCapsOnProcessChanged := Util.INIRead(iniFile, "SystemSetting", "CleanCapsOnProcessChanged", "true") == "true"
        SystemSetting.CleanCapsOnRecovered := Util.INIRead(iniFile, "SystemSetting", "CleanCapsOnRecovered", "true") == "true"
    }
}