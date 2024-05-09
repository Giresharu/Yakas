#Requires AutoHotkey v2.0

class Util {
    ; 从 ini 文件中读取指定 section 和 key 对应的值
    static INIRead(iniFile, section, key, defaultValue?) {
        str := IniRead(iniFile, section, key, defaultValue?)
        str := RegExReplace(str, ";.*$", "")  ; 移除行尾的注释
        str := Trim(str)  ; 移除字符串两侧的空格
        return str
    }

    ; 从 ini 文件中读取指定 section 下的所有键值对，并以回调函数处理值
    static INIReadForeach(iniFile, section, callBack?) {
        dic := Map()
        loop parse IniRead(iniFile, section), "`n", "`r" {
            str := RegExReplace(A_LoopField, ";.*$", "")  ; 移除行尾的注释

            keyValue := StrSplit(str, "=", " ")  ; 以等号拆分键值对
            key := keyValue[1]
            value := keyValue.Length > 1 ? keyValue[2] : ""  ; 如果有值则为键值中的第二个元素，否则为空字符串

            if (callBack)
                dic[key] := callBack(0, iniFile, value)  ; 若有回调函数则处理值并存储
            ; 我是不知道为什么明明两个形参的回调来要写成3个参数，写2个就报错。总是就这样写吧
            else
                dic[key] := value  ; 没有回调函数则直接存储值
        }
        return dic
    }

    ; 将字符串转换为 Map 对象
    static StrToMap(str, elementDelimiters := ",", keyValueDelimiters := ":", defaultValue?) {
        dic := Map()
        loop parse str, elementDelimiters, " " {
            keyValue := StrSplit(A_LoopField, keyValueDelimiters, " ")

            key := keyValue[1]
            value := keyValue.Length > 1 ? keyValue[2] : defaultValue  ; 如果有值则为键值中的第二个元素，否则使用默认值

            dic[key] := value
        }
        return dic
    }

    ; 将字符串转换为数组
    static StrToArray(str, elementDelimiters := ",") {
        arr := Array()
        loop parse str, elementDelimiters, " " {
            arr.Push(A_LoopField)
        }
        return arr
    }

    ; 正则表达式匹配，返回所有匹配以及每个匹配下的捕获组
    static RegExMatch(str, pattern, &matches?, &groups?, startPos := 1) {
        matches := []
        groups := []

        Loop {
            hasResult := RegExMatch(str, pattern, &localMatches, startPos)
            if (hasResult == 0)
                break

            matches.Push(localMatches[0])
            startPos += StrLen(localMatches[0])

            arr := []
            for i, match in localMatches {
                if (i == 0)
                    continue  ; 跳过第一个元素，因为它是整个匹配结果

                arr.Push(match)
            }
            groups.Push(arr)

        }
        return matches.Length > 0
    }

    static GetActiveWindowId(title := "A") {
        temp := A_DetectHiddenWindows
        DetectHiddenWindows True

        hwnd := ControlGetFocus(title)
        if (!hwnd) {
            hwnd := WinExist(title)
        }

        ; 如果是 UWP 则用另外的方法获取 ID
        ; if WinGetProcessName(hwnd) == "ApplicationFrameHost.exe" {
        ;     childPID := ''

        ;     pid := WinGetPID(hwnd)

        ;     for c in WinGetControls(hwnd)
        ;         DllCall(KBLTool.GetWindowThreadProcessId, "Ptr", c, "UintP", childPID)
        ;     until childPID != pid

        ;     DetectHiddenWindows true
        ;     hwnd := WinExist("ahk_pid" childPID)
        ; }

        DetectHiddenWindows temp
        return hwnd
    }
}