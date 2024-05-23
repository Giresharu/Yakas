#Requires AutoHotkey v2.0

class Util {
    static WinGetID(title := "A") {
        while (!WinExist(title))
            Sleep(1000 / 24)
        hWnd := WinGetID(title)
        return Util.FixUWPWinID(hWnd)
    }

    static FixUWPWinID(hWnd, timeout := 5000) {
        if WinGetProcessName(hWnd) == "ApplicationFrameHost.exe" {
            TrueWindow := 0
            ; 因为加载速度的原因，ApplicationFrameHost 加载出来的时候，它的子窗口还没有完全加载出来，所以这里需要循环等待子窗口加载完成
            startTime := A_TickCount
            loop {
                DllCall("EnumChildWindows", "ptr", hWnd, "ptr", CallbackCreate(EnumChildWindows, "F"), "uint", 0)
                if TrueWindow != 0
                    break
                if A_TickCount - startTime > timeout
                    break
                Sleep(1000 / 24)
            }
            hWnd := TrueWindow
        }

        return hWnd

        EnumChildWindows(hwnd) {
            if WinGetProcessName(hwnd) != "ApplicationFrameHost.exe" {
                TrueWindow := hwnd
                return false
            }
            return true
        }
    }

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
                callBack(0, iniFile, value, dic, key)  ; 若有回调函数则处理值并存储
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
    static RegExMatchAll(str, pattern, &matches?, &groups?, startPos := 1) {
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
}