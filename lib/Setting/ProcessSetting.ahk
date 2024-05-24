#Requires AutoHotkey v2.0
#Include GlobalSetting.ahk

class ProcessSetting {
    static ProcessSettings := Map()
    WindowSettings := 0

    __New(title, defaultKBL, alwaysRecorveToDefault) {
        this.Title := title
        this.DefaultKBL := defaultKBL
        this.AlwaysRecorveToDefault := alwaysRecorveToDefault
    }

    static __Item[key] => ProcessSetting.ProcessSettings[key]

    static Initialize(iniFile) {
        ProcessSetting.ProcessSettings := ProcessSetting.FromINI(iniFile)
    }

    static FromINI(iniFile) {
        return Util.INIReadForeach(iniFile, "ProcessSetting", ProcessSetting.FromINISection)
    }

    static FromINISection(iniFile, value, dic, _) {
        value := Util.StrToArray(value, ",")

        name := Trim(value[1], " ")

        defaultKBL := StrSplit(value[-2], ":", " ")
        defaultKBL := KeyboardLayout(defaultKBL[1], defaultKBL[2])
        alwaysRecorveToDefault := value[-1] == "true"

        if (value.Length > 3) {
            ;要考虑还没有创建的情况，需要自动创建
            key := name
            name := Trim(value[2], " ")
            dic := ProcessSetting.FindSettingDic(dic, key, name)
        }

        if (dic.Has(name)) {
            dic[name].DefaultKBL := defaultKBL
            dic[name].AlwaysRecorveToDefault := alwaysRecorveToDefault
        } else
            dic[name] := ProcessSetting(name, defaultKBL, alwaysRecorveToDefault)
    }

    static FindSettingDic(dic, key, name) {
        if (key != "") {
            if (!dic.Has(key))
                dic[key] := ProcessSetting(key, GlobalSetting.DefualtKBL, false)
            dic := dic[key]
        }

        name := Trim(name, " ")

        if (name != "") {
            dic := dic.WindowSettings := (dic.WindowSettings == 0 ? Map() : dic.WindowSettings)
        }

        return dic
    }

}