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
        GlobalSetting.StandAlong := Util.INIRead(iniFile, "GlobalSetting", "StandAlong", "true") == "true"
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
}