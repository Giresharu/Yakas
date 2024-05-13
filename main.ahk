#Requires AutoHotkey v2.0

; if !A_IsAdmin {
;     try {
;         if A_IsCompiled
;             Run '*RunAs "' A_ScriptFullPath '" /restart'
;         else
;             Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
;     }
; }

#Include Lib\Setting\KBLSwitchSetting.ahk
#Include Lib\Hotkey\HotKeyPlus.ahk
#Include lib\KBL\KBLTool.ahk
#Include lib\KBL\KBLManager.ahk
#Include lib\Util\WinEvent.ahk


iniFile := "setting.ini"
languageCodeFile := "languageCode"
FileEncoding("UTF-8")
Initialize()

Return

Initialize() {
    KBLSwitchSetting.Initialize(iniFile)
    KBLTool.Initialize()
    KBLManager.Initialize()
}
