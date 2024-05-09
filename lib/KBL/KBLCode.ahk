; 废弃

KBLCode := Map()
; GetAllKeyboardLayouts()

ReadLanguageCodeFile() {
    codes := Map()
    file := FileRead("LanguagCode", "UTF-8")
    Loop Parse, file, "`n", "`r"
    {
        strs := StrSplit(A_LoopField, "=")
        key := Trim(strs[1], " ")
        value := Trim(strs[2], " ")

        codes[value] := key ; 因为要查询的是代码，所以 key 和 value 互换
    }
    return codes
}

GetAllKeyboardLayouts() {
    codes := ReadLanguageCodeFile()
    errorCodes := Array()

    Loop Reg, "HKEY_CURRENT_USER\Keyboard Layout\Preload", "V"
    {
        languageCode := RegRead()

        try {
            key := codes[languageCode]
            KBLCode[key] := "0x" languageCode
        } catch Error as e {
            errorCodes.Push(languageCode)
        }

    }

    if (errorCodes.Length > 0) {
        str := ""
        Loop errorCodes.Length
        {
            str := str "`n" errorCodes[A_Index]
        }
        MsgBox("`n注册表 HKEY_CURRENT_USER\Keyboard Layout\Preload 中包含未知的键盘布局代码:" str " `n请将此错误提交至仓库 Issue。`n程序将在无视此键盘布局的情况下运行。", "未知的键盘布局代码", 32)
        ; TODO 自动打开 Issue 页面按钮
        ; TODO 提供按键忽略当前未知的键盘布局，下次在 Loop 时直接跳过
    }

    return
}

SetKeyboardLayout(language) {

    try {
        code := KBLCode[language]
    } catch Error as e {
        MsgBox("未发现键盘布局" language " , 本机上似乎没有这个语言的键盘布局。", "未发现键盘布局", 16)
        throw e
    }

    gl_Active_IMEwin_id := GetIMEwinid()
    title := WinGetTitle(gl_Active_IMEwin_id)
    ;TODO 考虑自动上屏如何实现
    errorLevel := SendMessage(0x50, , code, , gl_Active_IMEwin_id, , , , 1000)
    Sleep(50)
    ;TODO 根据用户设置，自动设置默认的IME状态
    SetIMEState(0, gl_Active_IMEwin_id)

    Return errorLevel
}

; 切换输入法自身的状态（如中英文假名全角半角等
SetIMEState(setSts, win_id) {
    errorLevel := SendMessage(0x283, 0x001, 0, , win_id, , , , 1000)
    CONVERSIONMODE := 2046 & errorLevel, CONVERSIONMODE += setSts
    SendMessage(0x283, 0x002, CONVERSIONMODE, , win_id, , , , 1000)
    errorLevel := SendMessage(0x283, 0x006, setSts, , win_id, , , , 1000)
    Return errorLevel
}

; 获得当前输入法的窗口句柄
GetIMEwinid() {
    ; 考虑是否应该先尝试 GetId 失败后再去尝试找焦点
    If WinActive("ahk_class ConsoleWindowClass") {
        win_id := WinGetID(, "ahk_exe" "conhost.exe")
    } Else If WinActive("ahk_group focus_control_ahk_group") {
        controller := ControlGetFocus("A")
        If (controller = "")
            win_id := WinGetID("A")
        Else
            win_id := ControlGetHwnd(controller)
    } Else
        win_id := WinGetID("A")
    global ImmGetDefaultIMEWnd := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", "imm32", "Ptr"), "AStr", "ImmGetDefaultIMEWnd", "Ptr") ; 获取 ImmGetDefaultIMEWnd 的句柄
    IMEwin_id := DllCall(ImmGetDefaultIMEWnd, "Uint", win_id, "Uint")
    Return IMEwin_id
}