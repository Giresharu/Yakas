#Requires AutoHotkey v2.0

#Include lib\Setting\SystemSetting.ahk
#Include Lib\Setting\KBLSwitchSetting.ahk
#Include lib\Setting\ProcessSetting.ahk
#Include lib\Setting\ToolTipSetting.ahk
#Include Lib\Hotkey\HotKeyPlus.ahk
#Include lib\KBL\KBLTool.ahk
#Include lib\KBL\KBLManager.ahk
#Include lib\Util\WinEvent.ahk
#Include lib\Gui\ToolTip.ahk

iniFile := "setting.ini"
languageCodeFile := "languageCode"
FileEncoding("UTF-8")
Initialize()

Return

Initialize() {
    SystemSetting.Initialize(iniFile)
    KBLSwitchSetting.Initialize(iniFile)
    ProcessSetting.Initialize(iniFile)
    ToolTipSetting.Initialize(iniFile)
    KBLTool.Initialize()
    KBLManager.Initialize()
}