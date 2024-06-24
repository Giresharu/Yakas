#Requires AutoHotkey v2.0
#Include GlobalSetting.ahk

class ProcessSetting {
    static ProcessSettings := Map()
    RegExSettings := 0

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

        ; 写窗口正则的情况
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

    ; 从进程设置的字典中找到正则的子字典
    static FindSettingDic(dic, key, name) {
        if (key != "") {
            ; 如果进程设置此前不存在，则创建一个
            if (!dic.Has(key))
                dic[key] := ProcessSetting(key, 0, false) ; 以 0 表示进程本身没有默认配置，防止打开时自动恢复
            dic := dic[key]
        }

        ; name := Trim(name, " ")

        ; if (name != "") {
        ; 创建正则的子字典
        dic := dic.RegExSettings := (dic.RegExSettings == 0 ? Map() : dic.RegExSettings)
        ; }

        return dic
    }

}