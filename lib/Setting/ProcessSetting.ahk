#Requires AutoHotkey v2.0
#Include ..\Util\Util.ahk
#Include ..\KBL\KeyboardLayout.ahk

class ProcessSetting {
    static StandAlong := true
    static CleanOnProcessExit := true
    static DefualtKBL := "en-US: 0"
    static ProcessSettings := Map()

    __New(name, defaultKBL, alwaysRecorveToDefault) {
        this.Name := name
        this.DefaultKBL := defaultKBL
        this.AlwaysRecorveToDefault := alwaysRecorveToDefault
    }

    __Item[i] => ProcessSetting.ProcessSettings[i]

    static Initialize(iniFile) {
        ProcessSetting.ProcessSettings := ProcessSetting.FromINI(iniFile)
    }

    static FromINI(iniFile) {
        ProcessSetting.StandAlong := Util.INIRead(iniFile, "GlobalProcessSetting", "StandAlong", "true") == "true"
        ProcessSetting.CleanOnProcessExit := Util.INIRead(iniFile, "GlobalProcessSetting", "CleanOnProcessExit", "true") == "true"

        ProcessSetting.DefualtKBL := Util.INIRead(iniFile, "GlobalProcessSetting", "DefualtKBL", "en-US: 0")
        ProcessSetting.DefualtKBL := StrSplit(ProcessSetting.DefualtKBL, ":")
        ProcessSetting.DefualtKBL := KeyboardLayout(ProcessSetting.DefualtKBL[1], ProcessSetting.DefualtKBL[2])

        arr := Util.INIReadForeach(iniFile, "ProcessSetting", ProcessSetting.FromINISection)
        dic := Map()
        for i, e in arr {
            dic[e.Name] := e
        }
        return dic
    }

    static FromINISection(iniFile, value) {
        value := Util.StrToArray(value, ",")

        processName := value[1]
        defaultKBL := StrSplit(value[2], ":")
        defaultKBL := KeyboardLayout(defaultKBL[1], defaultKBL[2])
        alwaysRecorveToDefault := value[3] == "true"
        return ProcessSetting(processName, defaultKBL, alwaysRecorveToDefault)
    }

}