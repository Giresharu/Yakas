#Requires AutoHotkey v2.0

#Include Lib\Setting\YetAnotherKBLSwitchSetting.ahk
#Include Lib\Hotkey\HotKeyPlus.ahk
#Include lib\KBL\KBLTool.ahk
#Include lib\KBL\KBLSwitcher.ahk

iniFile := "setting.ini"
languageCodeFile := "languageCode"

FileEncoding("UTF-8")
Initialize()



globalSwitcher := KBLSwitcher(0,setting.KBLSwitcher["0"])
Key := globalSwitcher.setting.Key
condition :=  globalSwitcher.setting.condition

; key := CheckKey(key)
HotkeyPlus("~" Key, Test
    , condition.NeedRelease, condition.HoldTime, condition.ReverseHold)

Return

Initialize() {
    global setting := YetAnotherKBLSwitchSetting.FromINI(iniFile)
    KBLTool.Initialize()
}

Test() {
    globalSwitcher.NextLayout()
}