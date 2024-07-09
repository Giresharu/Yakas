; YetAnotherKBLAutoSwitch
; Ver 0.0.2a

#Requires AutoHotkey v2.0
#Include lib\Util\RunTask.ahk
RunAsTask()

#SingleInstance Force

#Include lib\Setting\GlobalSetting.ahk
#Include Lib\Setting\KBLSwitchSetting.ahk
#Include lib\Setting\ProcessSetting.ahk
#Include lib\Setting\ToolTipSetting.ahk
#Include Lib\Hotkey\HotKeyPlus.ahk
#Include lib\KBL\KBLTool.ahk
#Include lib\KBL\KBLManager.ahk
#Include lib\Util\WinEvent.ahk
#Include lib\Gui\ToolTip.ahk

Util.SetStartUp()

iniFile := "setting.ini"
languageCodeFile := "languageCode"
FileEncoding("UTF-8")

global onExitCallbacks := Array()
OnExit OnExitApp

GlobalSetting.Initialize(iniFile)
KBLSwitchSetting.Initialize(iniFile)
ProcessSetting.Initialize(iniFile)
ToolTipSetting.Initialize(iniFile)
KBLTool.Initialize()
KBLManager.Initialize()

A_TrayMenu.Delete()
A_TrayMenu.Add("打开配置目录", (n, p, m) => Run(A_ScriptDir))
; A_TrayMenu.Add("打开 Window Spy", (n, p, m) => Run(A_ScriptDir "\Window Spy.exe"))
A_TrayMenu.Add("打开语言首选项", OpenLanguageSetting)
A_TrayMenu.Add("退出", (n, p, m) => ExitApp())

Return

OnExitApp(exitReason, exitCode) {
    for i, callback in onExitCallbacks {
        callback.Call(exitReason, exitCode)
    }
}

OpenLanguageSetting(n, p, m) {
    try {
        Run("ms-settings:regionlanguage")
    } catch {
        Run("rundll32.exe shell32.dll`,Control_RunDLL input.dll")
    }
}