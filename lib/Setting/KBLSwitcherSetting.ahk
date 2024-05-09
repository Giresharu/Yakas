#Requires AutoHotkey v2.0
#Include ..\Util\Util.ahk
#Include ..\Util\CorrectArray.ahk

; 用于存储键盘布局切换设置
class KBLSwitcherSetting {

    static ModifierToMark := Map("Win", "#", "Alt", "!", "Shift", "+", "Ctrl", "^", "L", "<", "R", ">")
    static MarkToModifier := Map("#", "Win", "!", "Alt", "+", "Shift", "^", "Ctrl", "<", "L", ">", "R")

    __New(name, key, condition, layouts) {
        this.Name := name
        this.Key := key
        this.Condition := condition
        this.Layouts := layouts
    }

    __Item[i] => this.Layouts[i]

    ; 从 ini 文件中读取设置并返回 KBLSwitchSetting 对象
    static FromINISection(iniFile, value) {

        key := Util.INIRead(iniFile, "KBLSwitcher." value, "key", "LShift")

        condition := KBLSwitcherSetting.ParseCondition(value, key, Util.INIRead(iniFile, "KBLSwitcher." value, "condition", "long_release(500)"))

        kbls := KBLSwitcherSetting.ParseKBLayout(Util.INIRead(iniFile, "KBLSwitcher." value, "layouts", "US: 0x0, 中文 (简体) - 美式: 0x1"))

        return KBLSwitcherSetting(value, key, condition, kbls)
    }

    static SplitKeys(key) {
        arr := []

        ; key的格式为 N个修饰符与一个主键结合，其中修饰符可能有<或者>标注
        Util.RegExMatch(key, "(<|>)?(\+|\^|\#|\!)", &matches, &groups)
        for e in groups {
            prefix := e[1] != "" ? KBLSwitcherSetting.MarkToModifier[e[1]] : ""
            modifier := prefix KBLSwitcherSetting.MarkToModifier[e[2]]
            arr.Push(modifier)
        }

        RegExMatch(key, "\w+$", &matches, -1)
        arr.Push(matches[0])

        return arr
    }

    static ParseCondition(value, key, condition) {
        releaseKeys := Util.INIRead(iniFile, "KBLSwitcher." value, "release_key", "")

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

        return KBLSwitcherSetting.Condition(release, reverse, holdTime, releaseKeys)
    }

    static ParseKBLayout(str) {
        arr := CorrectArray()
        loop parse str, ",", " " {
            str := StrSplit(A_LoopField, ":", " ")

            name := str[1]
            defualtState := str.Length > 1 ? Integer(str[2]) : 0x0

            arr.Push(KBLSwitcherSetting.Layout(name, defualtState))
        }
        return arr
    }

    ; 从 ini 文件中读取所有键值对并返回 Map 对象
    static FromINI(iniFile) {
        ; 从 Ini 文件中读取所有键值对并根据 FromIni 转换为 KBLSwitchSetting 对象
        return Util.INIReadForeach(iniFile, "KBLSwitcher", KBLSwitcherSetting.FromINISection)
    }


    ; TODO 保存设置到 ini 文件

    ; 用于存储单个键盘布局设置
    class Layout {
        __New(name, defaultState) {
            this.Name := name
            this.DefaultState := defaultState
        }
    }

    class Condition {

        __New(needRelease, reverseHold, holdTime, releaseKeys) {
            this.NeedRelease := needRelease
            this.ReverseHold := reverseHold
            this.HoldTime := holdTime
            this.ReleaseKeys := releaseKeys
        }
    }
}