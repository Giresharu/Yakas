#Requires AutoHotkey v2.0
#Include ..\Util\Util.ahk

; 用于存储键盘布局切换设置
class KBLSwitchSetting {

    static ModifierToMark := Map("Win", "#", "Alt", "!", "Shift", "+", "Ctrl", "^", "L", "<", "R", ">")
    static MarkToModifier := Map("#", "Win", "!", "Alt", "+", "Shift", "^", "Ctrl", "<", "L", ">", "R")
    static KBLSwitchSettings := Map()

    __New(name, key, condition, layouts) {
        this.Name := name
        this.Key := key
        this.Condition := condition
        this.Layouts := layouts
    }

    static __Item[i] => KBLSwitchSetting.KBLSwitchSettings[i]
    ; __Item[i] => this.Layouts[i]

    static Initialize(iniFile) {
        KBLSwitchSetting.KBLSwitchSettings := KBLSwitchSetting.FromINI(iniFile)
        Util.INIReadForeach(iniFile, "AutoSendString", KBLSwitchSetting.AddToGroupAutoSendString)
        Util.INIReadForeach(iniFile, "TrayWnd", KBLSwitchSetting.AddToGroupTrayWnd)
    }

    ; 从 ini 文件中读取设置并返回 KBLSwitchSetting 对象
    static FromINISection(iniFile, value, dic, _) {
        key := Util.INIRead(iniFile, "KBLSwitch." value, "key", "LShift")
        condition := KBLSwitchSetting.ParseCondition(value, key, Util.INIRead(iniFile, "KBLSwitch." value, "condition", "long_release(500)"))
        layouts := KBLSwitchSetting.ParseKBLayout(Util.INIRead(iniFile, "KBLSwitch." value, "layouts", "en-US: 0, zh-CN: 1025"))

        dic[key] := KBLSwitchSetting(value, key, condition, layouts)
    }

    static AddToGroupAutoSendString(iniFile, value, dic, _) {
        GroupAdd "AutoSendString", value
    }

    static AddToGroupTrayWnd(iniFile, value, dic, _) {
        GroupAdd "TrayWnd", value
    }

    static SplitKeys(key) {
        arr := []

        ; key的格式为 N个修饰符与一个主键结合，其中修饰符可能有<或者>标注
        Util.RegExMatchAll(key, "(<|>)?(\+|\^|\#|\!)", &matches, &groups)
        for e in groups {
            prefix := e[1] != "" ? KBLSwitchSetting.MarkToModifier[e[1]] : ""
            modifier := prefix KBLSwitchSetting.MarkToModifier[e[2]]
            arr.Push(modifier)
        }

        RegExMatch(key, "\w+$", &matches, -1)
        arr.Push(matches[0])

        return arr
    }

    static ParseCondition(value, key, condition) {
        ; releaseKeys := Util.INIRead(iniFile, "KBLSwitch." value, "release_key", "")

        holdTime := 0
        reverse := false
        release := false

        if (InStr(condition, "release")) {
            release := true
            if (InStr(condition, "short")) {
                reverse := true
            }
        }

        holdTime := RegExMatch(condition, "\d+", &holdTime) ? holdTime[0] : 0

        return KBLSwitchSetting.Condition(release, reverse, holdTime)
    }

    static ParseKBLayout(str) {
        arr := Array()
        loop parse str, ",", " " {
            str := StrSplit(A_LoopField, ":", " ")

            name := str[1]
            imeState := str.Length > 1 ? Integer(str[2]) : 0x0

            arr.Push(KBLSwitchSetting.Layout(name, imeState))
        }
        return arr
    }

    ; 从 ini 文件中读取所有键值对并返回 Map 对象
    static FromINI(iniFile) {
        ; 从 Ini 文件中读取所有键值对并根据 FromIni 转换为 KBLSwitchSetting 对象
        return Util.INIReadForeach(iniFile, "KBLSwitch", KBLSwitchSetting.FromINISection)
    }


    ; TODO 保存设置到 ini 文件

    ; 用于存储单个键盘布局设置
    class Layout {
        __New(name, imeState) {
            this.Name := name
            this.ImeState := imeState
        }
    }

    class Condition {

        __New(needRelease, reverseHold, holdTime) {
            this.NeedRelease := needRelease
            this.ReverseHold := reverseHold
            this.HoldTime := holdTime
            ; this.ReleaseKeys := releaseKeys
        }
    }
}