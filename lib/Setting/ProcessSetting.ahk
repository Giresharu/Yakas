#Requires AutoHotkey v2.0
#Include GlobalSetting.ahk

class ProcessSetting {
    static ProcessSettings := Map()
    RegExSettings := 0
    SortedRegExSetting := 0

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

        str := StrSplit(value[-2], ":", " ")
        defaultKBLName := str[1]
        defaultKBLImeState := str.Length > 1 ? str[2] : 0

        ; 分析 | 分割表示的修改 state 延迟
        str := StrSplit(defaultKBLImeState, "|", " ")
        defaultKBLImeState := Integer(str[1])
        defaultKBLDelay := str.Length > 1 ? Integer(str[2]) : -1

        defaultKBL := KeyboardLayout(defaultKBLName, defaultKBLImeState, defaultKBLDelay)
        alwaysRecorveToDefault := value[-1] == "true"

        ; 写窗口正则的情况
        if (value.Length > 3) {
            ;要考虑还没有创建的情况，需要自动创建
            key := name
            name := Trim(value[2], " ")
            _processSeting := ProcessSetting.GetProcessSetting(dic, key)
            dic := ProcessSetting.FindSettingDic(_processSeting, name)
        }

        if (dic.Has(name)) {
            dic[name].DefaultKBL := defaultKBL
            dic[name].AlwaysRecorveToDefault := alwaysRecorveToDefault
        } else {
            dic[name] := ProcessSetting(name, defaultKBL, alwaysRecorveToDefault)
        }

        if (value.Length > 3) {
            if (!_processSeting.SortedRegExSetting)
                _processSeting.SortedRegExSetting := Array()
            _processSeting.SortedRegExSetting.Push(dic[name])
        }
    }

    ; 从进程设置的字典中找到正则的子字典
    static FindSettingDic(_processSetting, name) {
        dic := _processSetting.RegExSettings := (_processSetting.RegExSettings == 0 ? Map() : _processSetting.RegExSettings)

        return dic
    }

    static GetProcessSetting(dic, key) {
        if (!dic.Has(key))
            dic[key] := ProcessSetting(key, 0, false) ; 以 0 表示进程本身没有默认配置，防止打开时自动恢复
        return dic[key]
    }

}